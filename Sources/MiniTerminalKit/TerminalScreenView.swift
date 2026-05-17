import SwiftUI
import UIKit

public struct TerminalScreenView: UIViewRepresentable {
    @ObservedObject private var emulator: TerminalEmulator

    private let fontSize: CGFloat
    private let showsScrollback: Bool
    private let scrollTrigger: Int

    private let padding: CGFloat = 8

    public init(
        emulator: TerminalEmulator,
        fontSize: CGFloat = 14,
        showsScrollback: Bool = true,
        scrollTrigger: Int = 0
    ) {
        self.emulator = emulator
        self.fontSize = fontSize
        self.showsScrollback = showsScrollback
        self.scrollTrigger = scrollTrigger
    }

    public func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.backgroundColor = .black
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.alwaysBounceVertical = true
        scrollView.alwaysBounceHorizontal = true
        scrollView.showsVerticalScrollIndicator = true
        scrollView.showsHorizontalScrollIndicator = true
        scrollView.keyboardDismissMode = .interactive

        let label = UILabel()
        label.backgroundColor = .black
        label.numberOfLines = 0
        label.lineBreakMode = .byClipping
        label.isUserInteractionEnabled = false

        scrollView.addSubview(label)

        context.coordinator.label = label
        context.coordinator.lastScrollTrigger = -1

        return scrollView
    }

    public func updateUIView(_ scrollView: UIScrollView, context: Context) {
        guard let label = context.coordinator.label else { return }

        label.attributedText = terminalText()
        label.sizeToFit()

        let labelSize = label.bounds.size

        label.frame = CGRect(
            x: padding,
            y: padding,
            width: labelSize.width,
            height: labelSize.height
        )

        scrollView.contentSize = CGSize(
            width: max(scrollView.bounds.width + 1, labelSize.width + padding * 2),
            height: max(scrollView.bounds.height + 1, labelSize.height + padding * 2)
        )

        let shouldScroll =
            !context.coordinator.didInitialScroll ||
            context.coordinator.lastScrollTrigger != scrollTrigger

        context.coordinator.lastScrollTrigger = scrollTrigger

        guard shouldScroll else { return }

        context.coordinator.didInitialScroll = true

        DispatchQueue.main.async {
            scrollToBottomLeft(scrollView)

            DispatchQueue.main.async {
                scrollToBottomLeft(scrollView)
            }
        }
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    public final class Coordinator {
        var label: UILabel?
        var lastScrollTrigger: Int = -1
        var didInitialScroll = false
    }

    private var rows: [[TerminalCell]] {
        let source = showsScrollback ? emulator.visibleCells : emulator.screen.cells
        return source.trimmingTrailingEmptyRows()
    }

    private func terminalText() -> NSAttributedString {
        let result = NSMutableAttributedString()

        for rowIndex in rows.indices {
            result.append(attributedLine(rows[rowIndex]))

            if rowIndex < rows.count - 1 {
                result.append(NSAttributedString(string: "\n"))
            }
        }

        return result
    }

    private func attributedLine(_ cells: [TerminalCell]) -> NSAttributedString {
        let result = NSMutableAttributedString()

        for cell in cells {
            let font = UIFont.monospacedSystemFont(
                ofSize: fontSize,
                weight: cell.style.bold ? .bold : .regular
            )

            result.append(
                NSAttributedString(
                    string: String(cell.character),
                    attributes: [
                        .font: font,
                        .foregroundColor: uiColorForeground(for: cell.style),
                        .backgroundColor: uiColorBackground(for: cell.style)
                    ]
                )
            )
        }

        return result
    }

    private func uiColorForeground(for style: TerminalStyle) -> UIColor {
        if style.inverse {
            return uiColor(style.background) ?? .black
        }

        return uiColor(style.foreground) ?? .white
    }

    private func uiColorBackground(for style: TerminalStyle) -> UIColor {
        if style.inverse {
            return uiColor(style.foreground) ?? .white
        }

        return uiColor(style.background) ?? .black
    }

    private func uiColor(_ color: TerminalColor?) -> UIColor? {
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

private func scrollToBottomLeft(_ scrollView: UIScrollView) {
    scrollView.layoutIfNeeded()

    let maxY = max(
        0,
        scrollView.contentSize.height - scrollView.bounds.height
    )

    scrollView.setContentOffset(
        CGPoint(x: 0, y: maxY),
        animated: false
    )
}

private extension Array where Element == [TerminalCell] {
    func trimmingTrailingEmptyRows() -> [[TerminalCell]] {
        var result = self

        while let last = result.last, last.isTerminalEmptyRow {
            result.removeLast()
        }

        return result.isEmpty ? [[]] : result
    }
}

private extension Array where Element == TerminalCell {
    var isTerminalEmptyRow: Bool {
        allSatisfy { cell in
            cell.character == " " || cell.character == "\0"
        }
    }
}
