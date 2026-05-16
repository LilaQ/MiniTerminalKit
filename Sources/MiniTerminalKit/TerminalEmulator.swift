import Foundation
import Combine

@MainActor
public final class TerminalEmulator: ObservableObject {
    @Published public private(set) var screen: TerminalScreen
    @Published public private(set) var scrollback: [[TerminalCell]] = []
    @Published public private(set) var revision: Int = 0

    public var maxScrollbackLines: Int

    private let parser = ANSIParser()
    private var currentStyle: TerminalStyle = .normal
    private var pendingWrap: Bool = false

    private var savedCursorRow: Int = 0
    private var savedCursorColumn: Int = 0

    public init(
        rows: Int = 40,
        columns: Int = 120,
        maxScrollbackLines: Int = 5_000
    ) {
        self.screen = TerminalScreen(rows: rows, columns: columns)
        self.maxScrollbackLines = maxScrollbackLines
    }

    public var visibleCells: [[TerminalCell]] {
        scrollback + screen.cells
    }

    public var visiblePlainTextLines: [String] {
        visibleCells.map { row in
            String(row.map(\.character))
        }
    }

    public func plainText(showsScrollback: Bool = true) -> String {
        let rows = showsScrollback ? visibleCells : screen.cells

        return rows
            .map { row in
                String(row.map(\.character)).trimmingCharacters(in: .whitespaces)
            }
            .joined(separator: "\n")
    }

    public func feed(_ chunk: String) {
        parser.feed(chunk) { [weak self] event in
            self?.handle(event)
        }

        bumpRevision()
    }

    public func reset() {
        parser.reset()
        currentStyle = .normal
        pendingWrap = false
        savedCursorRow = 0
        savedCursorColumn = 0
        scrollback.removeAll()
        screen = TerminalScreen(rows: screen.rows, columns: screen.columns)

        bumpRevision()
    }

    public func clearScrollback() {
        scrollback.removeAll()
        bumpRevision()
    }

    public func resize(rows: Int, columns: Int) {
        let newRows = max(1, rows)
        let newColumns = max(1, columns)

        var newScreen = TerminalScreen(rows: newRows, columns: newColumns)

        let copyRows = min(screen.rows, newRows)
        let copyColumns = min(screen.columns, newColumns)

        for row in 0..<copyRows {
            for column in 0..<copyColumns {
                newScreen.cells[row][column] = screen.cells[row][column]
            }
        }

        newScreen.cursorRow = min(screen.cursorRow, newRows - 1)
        newScreen.cursorColumn = min(screen.cursorColumn, newColumns - 1)

        screen = newScreen
        pendingWrap = false

        bumpRevision()
    }

    private func bumpRevision() {
        revision &+= 1
    }

    private func handle(_ event: ANSIEvent) {
        switch event {
        case .printable(let char):
            put(char)

        case .newline:
            pendingWrap = false
            newline()

        case .carriageReturn:
            pendingWrap = false
            screen.cursorColumn = 0

        case .backspace:
            pendingWrap = false
            screen.cursorColumn = max(0, screen.cursorColumn - 1)

        case .tab:
            pendingWrap = false
            tab()

        case .saveCursor:
            savedCursorRow = screen.cursorRow
            savedCursorColumn = screen.cursorColumn

        case .restoreCursor:
            pendingWrap = false
            screen.cursorRow = clamp(savedCursorRow, 0, screen.rows - 1)
            screen.cursorColumn = clamp(savedCursorColumn, 0, screen.columns - 1)

        case .cursorUp(let count):
            pendingWrap = false
            screen.cursorRow = max(0, screen.cursorRow - count)

        case .cursorDown(let count):
            pendingWrap = false
            screen.cursorRow = min(screen.rows - 1, screen.cursorRow + count)

        case .cursorForward(let count):
            pendingWrap = false
            screen.cursorColumn = min(screen.columns - 1, screen.cursorColumn + count)

        case .cursorBack(let count):
            pendingWrap = false
            screen.cursorColumn = max(0, screen.cursorColumn - count)

        case .cursorPosition(let row, let column):
            pendingWrap = false
            screen.cursorRow = clamp(row - 1, 0, screen.rows - 1)
            screen.cursorColumn = clamp(column - 1, 0, screen.columns - 1)

        case .eraseDisplay(let mode):
            pendingWrap = false
            eraseDisplay(mode)

        case .eraseLine(let mode):
            pendingWrap = false
            eraseLine(mode)

        case .sgr(let params):
            applySGR(params)

        case .ignored:
            break
        }
    }

    private func put(_ char: Character) {
        if pendingWrap {
            pendingWrap = false
            newline()
        }

        guard screen.cursorRow >= 0,
              screen.cursorRow < screen.rows,
              screen.cursorColumn >= 0,
              screen.cursorColumn < screen.columns
        else {
            return
        }

        screen.cells[screen.cursorRow][screen.cursorColumn] = TerminalCell(
            character: char,
            style: currentStyle
        )

        if screen.cursorColumn == screen.columns - 1 {
            pendingWrap = true
        } else {
            screen.cursorColumn += 1
        }
    }

    private func newline() {
        if screen.cursorRow == screen.rows - 1 {
            scrollUp()
        } else {
            screen.cursorRow += 1
        }

        screen.cursorColumn = 0
    }

    private func tab() {
        if pendingWrap {
            pendingWrap = false
            newline()
        }

        let nextTab = ((screen.cursorColumn / 8) + 1) * 8
        screen.cursorColumn = min(nextTab, screen.columns - 1)
    }

    private func scrollUp() {
        if maxScrollbackLines > 0 {
            scrollback.append(screen.cells[0])

            if scrollback.count > maxScrollbackLines {
                let overflow = scrollback.count - maxScrollbackLines
                scrollback.removeFirst(overflow)
            }
        }

        if screen.rows > 1 {
            screen.cells.removeFirst()
            screen.cells.append(blankRow())
        } else {
            screen.cells[0] = blankRow()
        }
    }

    private func eraseDisplay(_ mode: Int) {
        switch mode {
        case 0:
            eraseLine(0)

            if screen.cursorRow + 1 < screen.rows {
                for row in (screen.cursorRow + 1)..<screen.rows {
                    clearRow(row)
                }
            }

        case 1:
            if screen.cursorRow > 0 {
                for row in 0..<screen.cursorRow {
                    clearRow(row)
                }
            }

            eraseLine(1)

        case 2:
            for row in 0..<screen.rows {
                clearRow(row)
            }

        default:
            break
        }
    }

    private func eraseLine(_ mode: Int) {
        switch mode {
        case 0:
            guard screen.cursorColumn < screen.columns else {
                return
            }

            for column in screen.cursorColumn..<screen.columns {
                screen.cells[screen.cursorRow][column] = TerminalCell(style: currentStyle)
            }

        case 1:
            for column in 0...screen.cursorColumn {
                screen.cells[screen.cursorRow][column] = TerminalCell(style: currentStyle)
            }

        case 2:
            clearRow(screen.cursorRow)

        default:
            break
        }
    }

    private func clearRow(_ row: Int) {
        guard row >= 0 && row < screen.rows else {
            return
        }

        screen.cells[row] = blankRow()
    }

    private func blankRow() -> [TerminalCell] {
        Array(
            repeating: TerminalCell(character: " ", style: currentStyle),
            count: screen.columns
        )
    }

    private func applySGR(_ params: [Int]) {
        for param in params {
            switch param {
            case 0:
                currentStyle = .normal

            case 1:
                currentStyle.bold = true

            case 22:
                currentStyle.bold = false

            case 7:
                currentStyle.inverse = true

            case 27:
                currentStyle.inverse = false

            case 30...37:
                currentStyle.foreground = color8(param - 30, bright: false)

            case 39:
                currentStyle.foreground = nil

            case 40...47:
                currentStyle.background = color8(param - 40, bright: false)

            case 49:
                currentStyle.background = nil

            case 90...97:
                currentStyle.foreground = color8(param - 90, bright: true)

            case 100...107:
                currentStyle.background = color8(param - 100, bright: true)

            default:
                break
            }
        }
    }

    private func color8(_ value: Int, bright: Bool) -> TerminalColor? {
        switch (value, bright) {
        case (0, false): return .black
        case (1, false): return .red
        case (2, false): return .green
        case (3, false): return .yellow
        case (4, false): return .blue
        case (5, false): return .magenta
        case (6, false): return .cyan
        case (7, false): return .white

        case (0, true): return .brightBlack
        case (1, true): return .brightRed
        case (2, true): return .brightGreen
        case (3, true): return .brightYellow
        case (4, true): return .brightBlue
        case (5, true): return .brightMagenta
        case (6, true): return .brightCyan
        case (7, true): return .brightWhite

        default:
            return nil
        }
    }

    private func clamp(_ value: Int, _ lower: Int, _ upper: Int) -> Int {
        min(max(value, lower), upper)
    }
}
