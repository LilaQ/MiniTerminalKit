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

    func reset() {
        state = .normal
    }

    func feed(_ string: String, emit: (ANSIEvent) -> Void) {
        for char in string {
            consume(char, emit: emit)
        }
    }

    private func consume(_ char: Character, emit: (ANSIEvent) -> Void) {
        switch state {
        case .normal:
            switch char {
            case "\u{001B}":
                state = .escape
            case "\n":
                emit(.newline)
            case "\r":
                emit(.carriageReturn)
            case "\u{0008}":
                emit(.backspace)
            case "\t":
                emit(.tab)
            default:
                emit(.printable(char))
            }

        case .escape:
            switch char {
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

        case .csi(let buffer):
            if isCSIFinalByte(char) {
                parseCSI(buffer: buffer, final: char, emit: emit)
                state = .normal
            } else {
                state = .csi(buffer: buffer + String(char))
            }

        case .osc(let buffer):
            if char == "\u{0007}" {
                emit(.ignored)
                state = .normal
            } else if char == "\u{001B}" {
                state = .oscEscape(buffer: buffer)
            } else {
                state = .osc(buffer: buffer + String(char))
            }

        case .oscEscape(let buffer):
            if char == "\\" {
                emit(.ignored)
                state = .normal
            } else {
                state = .osc(buffer: buffer + "\u{001B}" + String(char))
            }
        }
    }

    private func isCSIFinalByte(_ char: Character) -> Bool {
        guard let scalar = char.unicodeScalars.first else {
            return false
        }

        return scalar.value >= 0x40 && scalar.value <= 0x7E
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
