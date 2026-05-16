import SwiftUI

public struct TerminalScreenView: View {
    @ObservedObject private var emulator: TerminalEmulator
    private let fontSize: CGFloat
    private let showsScrollback: Bool

    public init(
        emulator: TerminalEmulator,
        fontSize: CGFloat = 14,
        showsScrollback: Bool = true
    ) {
        self.emulator = emulator
        self.fontSize = fontSize
        self.showsScrollback = showsScrollback
    }

    public var body: some View {
        ScrollView([.vertical, .horizontal]) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    Text(attributedLine(row))
                        .font(.system(size: fontSize, design: .monospaced))
                        .textSelection(.enabled)
                        .lineLimit(1)
                }
            }
            .padding(8)
        }
        .background(Color.black)
    }

    private var rows: [[TerminalCell]] {
        showsScrollback ? emulator.visibleCells : emulator.screen.cells
    }

    private func attributedLine(_ cells: [TerminalCell]) -> AttributedString {
        var result = AttributedString()

        for cell in cells {
            var piece = AttributedString(String(cell.character))
            piece.foregroundColor = foregroundColor(for: cell.style)
            piece.backgroundColor = backgroundColor(for: cell.style)
            piece.font = .system(
                size: fontSize,
                weight: cell.style.bold ? .bold : .regular,
                design: .monospaced
            )

            result += piece
        }

        return result
    }

    private func foregroundColor(for style: TerminalStyle) -> Color {
        if style.inverse {
            return .black
        }

        return color(style.foreground) ?? .white
    }

    private func backgroundColor(for style: TerminalStyle) -> Color {
        if style.inverse {
            return .white
        }

        return color(style.background) ?? .black
    }

    private func color(_ color: TerminalColor?) -> Color? {
        switch color {
        case .black: return .black
        case .red: return .red
        case .green: return .green
        case .yellow: return .yellow
        case .blue: return .blue
        case .magenta: return .purple
        case .cyan: return .cyan
        case .white: return .white

        case .brightBlack: return .gray
        case .brightRed: return .red
        case .brightGreen: return .green
        case .brightYellow: return .yellow
        case .brightBlue: return .blue
        case .brightMagenta: return .purple
        case .brightCyan: return .cyan
        case .brightWhite: return .white

        case .none: return nil
        }
    }
}
