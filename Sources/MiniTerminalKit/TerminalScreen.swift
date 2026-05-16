import Foundation

public struct TerminalScreen: Equatable, Sendable {
    public var rows: Int
    public var columns: Int
    public var cells: [[TerminalCell]]
    public var cursorRow: Int
    public var cursorColumn: Int

    public init(rows: Int, columns: Int) {
        let safeRows = max(1, rows)
        let safeColumns = max(1, columns)

        self.rows = safeRows
        self.columns = safeColumns
        self.cursorRow = 0
        self.cursorColumn = 0
        self.cells = Array(
            repeating: Array(repeating: TerminalCell(), count: safeColumns),
            count: safeRows
        )
    }

    public func plainTextLines() -> [String] {
        cells.map { row in
            String(row.map(\.character))
        }
    }
}
