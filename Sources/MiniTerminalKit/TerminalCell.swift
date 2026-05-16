import Foundation

public enum TerminalColor: Equatable, Sendable {
    case black
    case red
    case green
    case yellow
    case blue
    case magenta
    case cyan
    case white

    case brightBlack
    case brightRed
    case brightGreen
    case brightYellow
    case brightBlue
    case brightMagenta
    case brightCyan
    case brightWhite
}

public struct TerminalStyle: Equatable, Sendable {
    public var bold: Bool
    public var inverse: Bool
    public var foreground: TerminalColor?
    public var background: TerminalColor?

    public init(
        bold: Bool = false,
        inverse: Bool = false,
        foreground: TerminalColor? = nil,
        background: TerminalColor? = nil
    ) {
        self.bold = bold
        self.inverse = inverse
        self.foreground = foreground
        self.background = background
    }

    public static let normal = TerminalStyle()
}

public struct TerminalCell: Equatable, Sendable {
    public var character: Character
    public var style: TerminalStyle

    public init(
        character: Character = " ",
        style: TerminalStyle = .normal
    ) {
        self.character = character
        self.style = style
    }
}
