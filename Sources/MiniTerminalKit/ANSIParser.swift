import Foundation

enum ParserState {
    case normal
    case escape
    case csi(buffer: String)
    case osc(buffer: String)
    case oscEscape(buffer: String)
}

enum ANSIEvent {
    case printable(Character)
    case newline
    case carriageReturn
    case backspace
    case tab

    case saveCursor
    case restoreCursor

    case cursorUp(Int)
    case cursorDown(Int)
    case cursorForward(Int)
    case cursorBack(Int)
    case cursorPosition(row: Int, column: Int)

    case eraseDisplay(Int)
    case eraseLine(Int)

    case sgr([Int])

    case ignored
}

final class ANSIParser {
    private var state: ParserState = .normal
    private var pendingCarriageReturns: Int = 0

    func reset() {
        state = .normal
        pendingCarriageReturns = 0
    }

    func feed(_ string: String, emit: (ANSIEvent) -> Void) {
        for scalar in string.unicodeScalars {
            consume(scalar, emit: emit)
        }
    }

    private func consume(_ scalar: UnicodeScalar, emit: (ANSIEvent) -> Void) {
        switch state {
        case .normal:
            consumeNormal(scalar, emit: emit)

        case .escape:
            consumeEscape(scalar, emit: emit)

        case .csi(let buffer):
            if isCSIFinalByte(scalar) {
                parseCSI(buffer: buffer, final: Character(scalar), emit: emit)
                state = .normal
            } else {
                state = .csi(buffer: buffer + String(scalar))
            }

        case .osc(let buffer):
            if scalar.value == 0x07 {
                emit(.ignored)
                state = .normal
            } else if scalar.value == 0x1B {
                state = .oscEscape(buffer: buffer)
            } else {
                state = .osc(buffer: buffer + String(scalar))
            }

        case .oscEscape(let buffer):
            if scalar == "\\" {
                emit(.ignored)
                state = .normal
            } else {
                state = .osc(buffer: buffer + "\u{001B}" + String(scalar))
            }
        }
    }

    private func consumeNormal(_ scalar: UnicodeScalar, emit: (ANSIEvent) -> Void) {
        switch scalar.value {
        case 0x0D:
            // CR
            pendingCarriageReturns += 1

        case 0x0A:
            // LF.
            // LF, CRLF and CRCRLF become exactly one terminal newline.
            pendingCarriageReturns = 0
            emit(.newline)

        case 0x1B:
            flushPendingCarriageReturn(emit: emit)
            state = .escape

        case 0x08:
            flushPendingCarriageReturn(emit: emit)
            emit(.backspace)

        case 0x09:
            flushPendingCarriageReturn(emit: emit)
            emit(.tab)

        default:
            flushPendingCarriageReturn(emit: emit)
            emit(.printable(Character(scalar)))
        }
    }

    private func flushPendingCarriageReturn(emit: (ANSIEvent) -> Void) {
        guard pendingCarriageReturns > 0 else {
            return
        }

        emit(.carriageReturn)
        pendingCarriageReturns = 0
    }

    private func consumeEscape(_ scalar: UnicodeScalar, emit: (ANSIEvent) -> Void) {
        switch scalar {
        case "[":
            state = .csi(buffer: "")

        case "]":
            state = .osc(buffer: "")

        case "s":
            emit(.saveCursor)
            state = .normal

        case "u":
            emit(.restoreCursor)
            state = .normal

        default:
            emit(.ignored)
            state = .normal
        }
    }

    private func isCSIFinalByte(_ scalar: UnicodeScalar) -> Bool {
        scalar.value >= 0x40 && scalar.value <= 0x7E
    }

    private func parseCSI(buffer: String, final: Character, emit: (ANSIEvent) -> Void) {
        if buffer.hasPrefix("?") {
            emit(.ignored)
            return
        }

        let params = parseParams(buffer)

        switch final {
        case "A":
            emit(.cursorUp(param(params, 0, default: 1)))

        case "B":
            emit(.cursorDown(param(params, 0, default: 1)))

        case "C":
            emit(.cursorForward(param(params, 0, default: 1)))

        case "D":
            emit(.cursorBack(param(params, 0, default: 1)))

        case "H", "f":
            let row = param(params, 0, default: 1)
            let column = param(params, 1, default: 1)
            emit(.cursorPosition(row: row, column: column))

        case "J":
            emit(.eraseDisplay(param(params, 0, default: 0)))

        case "K":
            emit(.eraseLine(param(params, 0, default: 0)))

        case "m":
            emit(.sgr(params.isEmpty ? [0] : params))

        case "s":
            emit(.saveCursor)

        case "u":
            emit(.restoreCursor)

        case "n":
            emit(.ignored)

        default:
            emit(.ignored)
        }
    }

    private func parseParams(_ buffer: String) -> [Int] {
        guard !buffer.isEmpty else {
            return []
        }

        return buffer
            .split(separator: ";", omittingEmptySubsequences: false)
            .map { Int($0) ?? 0 }
    }

    private func param(_ params: [Int], _ index: Int, default defaultValue: Int) -> Int {
        guard index < params.count else {
            return defaultValue
        }

        let value = params[index]
        return value == 0 ? defaultValue : value
    }
}
