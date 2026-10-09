import Foundation
import CoreGraphics

/// Coordinator for AGM-13: Native Editable Tables
public final class TableCoordinator {
    
    /// Creates a default table object with given rows and columns.
    public static func createDefaultTable(
        rows: Int = 3,
        cols: Int = 3,
        at origin: Point = Point(x: 100, y: 100)
    ) -> BoardObject {
        let validRows = max(1, rows)
        let validCols = max(1, cols)
        let colWidths = Array(repeating: 120.0, count: validCols)
        let rowHeights = (0..<validRows).map { $0 == 0 ? 40.0 : 36.0 }
        
        var cells: [TableCell] = []
        for r in 0..<validRows {
            for c in 0..<validCols {
                let isHeader = (r == 0)
                let sampleText: String
                if isHeader {
                    sampleText = "欄位 \(c + 1)"
                } else {
                    sampleText = "資料 \(r),\(c + 1)"
                }
                cells.append(
                    TableCell(
                        id: UUID().uuidString,
                        row: r,
                        col: c,
                        text: sampleText,
                        textColor: isHeader ? "#ffffff" : "#e2e8f0",
                        bgColor: isHeader ? "#334155" : (r % 2 == 1 ? "#1e293b" : "#0f172a"),
                        align: "center",
                        isHeader: isHeader
                    )
                )
            }
        }
        
        let tableData = TableData(
            rowCount: validRows,
            colCount: validCols,
            colWidths: colWidths,
            rowHeights: rowHeights,
            cells: cells
        )
        let dims = computeTotalDimensions(data: tableData)
        
        return BoardObject(
            type: "table",
            x: origin.x,
            y: origin.y,
            width: dims.width,
            height: dims.height,
            strokeColor: "#475569",
            fillColor: "#0f172a",
            strokeWidth: 1.0,
            tableData: tableData
        )
    }
    
    /// Computes total width and height of table based on column widths and row heights.
    public static func computeTotalDimensions(data: TableData) -> (width: Double, height: Double) {
        let w = data.colWidths.reduce(0.0, +)
        let h = data.rowHeights.reduce(0.0, +)
        return (max(100.0, w), max(40.0, h))
    }
    
    /// Inserts a new row into the table at index (or appends at the end if nil).
    public static func addRow(at index: Int? = nil, data: inout TableData) {
        let insertIndex = max(0, min(data.rowCount, index ?? data.rowCount))
        
        // Shift existing rows >= insertIndex
        for i in 0..<data.cells.count {
            if data.cells[i].row >= insertIndex {
                data.cells[i].row += 1
            }
        }
        
        // Insert row height
        let newHeight = 36.0
        if insertIndex < data.rowHeights.count {
            data.rowHeights.insert(newHeight, at: insertIndex)
        } else {
            data.rowHeights.append(newHeight)
        }
        
        // Insert new blank cells
        for c in 0..<data.colCount {
            data.cells.append(
                TableCell(
                    id: UUID().uuidString,
                    row: insertIndex,
                    col: c,
                    text: "",
                    textColor: "#e2e8f0",
                    bgColor: insertIndex % 2 == 1 ? "#1e293b" : "#0f172a",
                    align: "center",
                    isHeader: false
                )
            )
        }
        
        data.rowCount += 1
    }
    
    /// Deletes the row at index. Returns false if table only has 1 row.
    @discardableResult
    public static func deleteRow(at index: Int, data: inout TableData) -> Bool {
        guard data.rowCount > 1, index >= 0, index < data.rowCount else { return false }
        
        data.cells.removeAll { $0.row == index }
        for i in 0..<data.cells.count {
            if data.cells[i].row > index {
                data.cells[i].row -= 1
            }
        }
        
        if index < data.rowHeights.count {
            data.rowHeights.remove(at: index)
        }
        data.rowCount -= 1
        return true
    }
    
    /// Inserts a new column into the table at index (or appends if nil).
    public static func addColumn(at index: Int? = nil, data: inout TableData) {
        let insertIndex = max(0, min(data.colCount, index ?? data.colCount))
        
        // Shift existing cols >= insertIndex
        for i in 0..<data.cells.count {
            if data.cells[i].col >= insertIndex {
                data.cells[i].col += 1
            }
        }
        
        // Insert col width
        let newWidth = 120.0
        if insertIndex < data.colWidths.count {
            data.colWidths.insert(newWidth, at: insertIndex)
        } else {
            data.colWidths.append(newWidth)
        }
        
        // Insert new blank cells
        for r in 0..<data.rowCount {
            let isHeader = (r == 0)
            data.cells.append(
                TableCell(
                    id: UUID().uuidString,
                    row: r,
                    col: insertIndex,
                    text: isHeader ? "新欄位" : "",
                    textColor: isHeader ? "#ffffff" : "#e2e8f0",
                    bgColor: isHeader ? "#334155" : (r % 2 == 1 ? "#1e293b" : "#0f172a"),
                    align: "center",
                    isHeader: isHeader
                )
            )
        }
        
        data.colCount += 1
    }
    
    /// Deletes the column at index. Returns false if table only has 1 column.
    @discardableResult
    public static func deleteColumn(at index: Int, data: inout TableData) -> Bool {
        guard data.colCount > 1, index >= 0, index < data.colCount else { return false }
        
        data.cells.removeAll { $0.col == index }
        for i in 0..<data.cells.count {
            if data.cells[i].col > index {
                data.cells[i].col -= 1
            }
        }
        
        if index < data.colWidths.count {
            data.colWidths.remove(at: index)
        }
        data.colCount -= 1
        return true
    }
    
    public static func setColWidth(index: Int, width: Double, data: inout TableData) {
        guard index >= 0, index < data.colWidths.count else { return }
        data.colWidths[index] = max(40.0, width)
    }
    
    public static func setRowHeight(index: Int, height: Double, data: inout TableData) {
        guard index >= 0, index < data.rowHeights.count else { return }
        data.rowHeights[index] = max(24.0, height)
    }
    
    public static func setCellText(row: Int, col: Int, text: String, data: inout TableData) {
        if let idx = data.cells.firstIndex(where: { $0.row == row && $0.col == col }) {
            data.cells[idx].text = text
        } else {
            data.cells.append(TableCell(row: row, col: col, text: text))
        }
    }
    
    /// Merges rectangular cell range.
    public static func mergeCells(
        fromRow: Int,
        fromCol: Int,
        toRow: Int,
        toCol: Int,
        data: inout TableData
    ) {
        let minR = min(fromRow, toRow)
        let maxR = max(fromRow, toRow)
        let minC = min(fromCol, toCol)
        let maxC = max(fromCol, toCol)
        
        let rowSpan = maxR - minR + 1
        let colSpan = maxC - minC + 1
        
        guard let primaryIdx = data.cells.firstIndex(where: { $0.row == minR && $0.col == minC }) else {
            return
        }
        
        data.cells[primaryIdx].rowSpan = rowSpan
        data.cells[primaryIdx].colSpan = colSpan
        
        // Remove non-primary cells within merge rectangle
        data.cells.removeAll { cell in
            let inRange = cell.row >= minR && cell.row <= maxR && cell.col >= minC && cell.col <= maxC
            let isPrimary = (cell.row == minR && cell.col == minC)
            return inRange && !isPrimary
        }
    }
    
    /// Unmerges a merged cell and recreates individual placeholder cells.
    public static func unmergeCell(row: Int, col: Int, data: inout TableData) {
        guard let idx = data.cells.firstIndex(where: { $0.row == row && $0.col == col }) else { return }
        let rowSpan = data.cells[idx].rowSpan ?? 1
        let colSpan = data.cells[idx].colSpan ?? 1
        
        guard rowSpan > 1 || colSpan > 1 else { return }
        
        data.cells[idx].rowSpan = 1
        data.cells[idx].colSpan = 1
        
        for r in row..<(row + rowSpan) {
            for c in col..<(col + colSpan) {
                if r == row && c == col { continue }
                if !data.cells.contains(where: { $0.row == r && $0.col == c }) {
                    data.cells.append(
                        TableCell(
                            id: UUID().uuidString,
                            row: r,
                            col: c,
                            text: "",
                            textColor: "#e2e8f0",
                            bgColor: r % 2 == 1 ? "#1e293b" : "#0f172a",
                            align: "center",
                            isHeader: false
                        )
                    )
                }
            }
        }
    }
    
    /// Imports tabular data from TSV or CSV string.
    public static func importFromDelimitedText(
        _ text: String,
        delimiter: Character = "\t"
    ) -> TableData {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        guard !lines.isEmpty else {
            return TableData(rowCount: 1, colCount: 1, colWidths: [120.0], rowHeights: [36.0], cells: [TableCell(row: 0, col: 0, text: "")])
        }
        
        var parsedRows: [[String]] = []
        for line in lines {
            let parts = line.split(separator: delimiter, omittingEmptySubsequences: false)
                .map { String($0).trimmingCharacters(in: CharacterSet(charactersIn: "\" \t")) }
            parsedRows.append(parts)
        }
        
        let maxCols = parsedRows.map { $0.count }.max() ?? 1
        let rowCount = parsedRows.count
        let colCount = max(1, maxCols)
        
        let colWidths = Array(repeating: 120.0, count: colCount)
        let rowHeights = (0..<rowCount).map { $0 == 0 ? 40.0 : 36.0 }
        
        var cells: [TableCell] = []
        for r in 0..<rowCount {
            let rowData = parsedRows[r]
            for c in 0..<colCount {
                let cellVal = c < rowData.count ? rowData[c] : ""
                let isHeader = (r == 0)
                cells.append(
                    TableCell(
                        id: UUID().uuidString,
                        row: r,
                        col: c,
                        text: cellVal,
                        textColor: isHeader ? "#ffffff" : "#e2e8f0",
                        bgColor: isHeader ? "#334155" : (r % 2 == 1 ? "#1e293b" : "#0f172a"),
                        align: "center",
                        isHeader: isHeader
                    )
                )
            }
        }
        
        return TableData(
            rowCount: rowCount,
            colCount: colCount,
            colWidths: colWidths,
            rowHeights: rowHeights,
            cells: cells
        )
    }
    
    /// Exports table data to delimited string (TSV/CSV).
    public static func exportToCSV(data: TableData, delimiter: Character = "\t") -> String {
        var grid = Array(repeating: Array(repeating: "", count: data.colCount), count: data.rowCount)
        for cell in data.cells {
            if cell.row < data.rowCount && cell.col < data.colCount {
                grid[cell.row][cell.col] = cell.text
            }
        }
        
        return grid.map { row in
            row.map { val in
                if val.contains(delimiter) || val.contains("\"") || val.contains("\n") {
                    let escaped = val.replacingOccurrences(of: "\"", with: "\"\"")
                    return "\"\(escaped)\""
                }
                return val
            }.joined(separator: String(delimiter))
        }.joined(separator: "\n")
    }
}
