import XCTest
@testable import MiniTerminalKit

@MainActor
final class MiniTerminalKitTests: XCTestCase {

    func testPlainText() {
        let terminal = TerminalEmulator(rows: 3, columns: 10)
        terminal.feed("hello")

        XCTAssertEqual(
            String(terminal.screen.plainTextLines()[0].prefix(5)),
            "hello"
        )
    }

    func testCarriageReturnOverwrite() {
        let terminal = TerminalEmulator(rows: 3, columns: 10)
        terminal.feed("hello\rX")

        XCTAssertEqual(
            String(terminal.screen.plainTextLines()[0].prefix(5)),
            "Xello"
        )
    }

    func testSplitEscapeSequenceAcrossChunks() {
        let terminal = TerminalEmulator(rows: 5, columns: 10)

        terminal.feed("\u{001B}[")
        terminal.feed("2;3")
        terminal.feed("H")
        terminal.feed("Z")

        XCTAssertEqual(terminal.screen.cells[1][2].character, "Z")
    }

    func testClearScreenAndHome() {
        let terminal = TerminalEmulator(rows: 3, columns: 10)

        terminal.feed("hello")
        terminal.feed("\u{001B}[H\u{001B}[J")
        terminal.feed("top")

        XCTAssertEqual(
            String(terminal.screen.plainTextLines()[0].prefix(3)),
            "top"
        )
    }

    func testSGRBold() {
        let terminal = TerminalEmulator(rows: 2, columns: 10)

        terminal.feed("\u{001B}[1mX\u{001B}[0mY")

        XCTAssertTrue(terminal.screen.cells[0][0].style.bold)
        XCTAssertFalse(terminal.screen.cells[0][1].style.bold)
    }

    func testScrollbackOnNewlineOverflow() {
        let terminal = TerminalEmulator(rows: 2, columns: 10)

        terminal.feed("one\n")
        terminal.feed("two\n")
        terminal.feed("three")

        XCTAssertFalse(terminal.scrollback.isEmpty)
        XCTAssertTrue(terminal.visiblePlainTextLines.joined(separator: "\n").contains("one"))
        XCTAssertTrue(terminal.visiblePlainTextLines.joined(separator: "\n").contains("three"))
    }

    func testClearScreenDoesNotCreateScrollback() {
        let terminal = TerminalEmulator(rows: 3, columns: 10)

        terminal.feed("hello")
        terminal.feed("\u{001B}[H\u{001B}[2J")

        XCTAssertTrue(terminal.scrollback.isEmpty)
    }

    func testTopLikeOutput() {
        let terminal = TerminalEmulator(rows: 5, columns: 40)

        terminal.feed("\u{001B}[s\u{001B}[999C\u{001B}[999B\u{001B}[6n\u{001B}[u")
        terminal.feed("\u{001B}[H\u{001B}[J")
        terminal.feed("Tasks: 477 total\n")
        terminal.feed("\u{001B}[7m PID USER CPU CMD \u{001B}[0m\n")
        terminal.feed("\u{001B}[1m 5733 shell top \u{001B}[m")
        terminal.feed("\u{001B}[H\u{001B}[J")
        terminal.feed("Tasks: 478 total\n")

        XCTAssertTrue(terminal.screen.plainTextLines()[0].contains("Tasks: 478"))
        XCTAssertTrue(terminal.scrollback.isEmpty)
    }
}
