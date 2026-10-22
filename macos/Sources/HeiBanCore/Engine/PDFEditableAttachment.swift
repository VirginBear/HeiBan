import Foundation

/// A valid incremental PDF stream keeps the existing Mac/Windows marker discoverable.
/// Editable payload is the complete document, including hidden objects and other pages.
public enum PDFEditableAttachment {
    public static func append(to pdf: Data, document: HeiBanDocument) throws -> Data {
        let source = String(decoding: pdf, as: UTF8.self)
        func matches(_ pattern: String, _ text: String) -> [String] {
            guard
                let expression = try? NSRegularExpression(
                    pattern: pattern, options: .dotMatchesLineSeparators)
            else { return [] }
            return expression.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap {
                match in
                guard let range = Range(match.range(at: 1), in: text) else { return nil }
                return String(text[range])
            }
        }
        guard source.hasPrefix("%PDF-"), let previous = matches(#"startxref\s+(\d+)\s+%%EOF"#, source).last,
            let trailer = matches(#"trailer\s*<<(.*?)>>"#, source).last,
            let size = matches(#"/Size\s+(\d+)"#, trailer).first.flatMap(Int.init),
            let root = matches(#"/Root\s+(\d+\s+\d+\s+R)"#, trailer).first
        else {
            throw NSError(
                domain: "HeiBanPDF", code: 3, userInfo: [NSLocalizedDescriptionKey: "不支援的PDF交叉索引，未寫入輸出檔案"])
        }
        let info = matches(#"/Info\s+(\d+\s+\d+\s+R)"#, trailer).first.map { " /Info " + $0 } ?? ""
        let payload =
            "%HeiBanDocumentJSON-START%\n" + (try HeiBanDocumentCodec.encode(document)).base64EncodedString()
            + "\n%HeiBanDocumentJSON-END%\n"
        let entry =
            "\n\(size) 0 obj\n<< /Length \(payload.utf8.count) >>\nstream\n\(payload)endstream\nendobj\n"
        let offset = String(format: "%010lld", Int64(pdf.count + 1))
        let footer =
            "xref\n0 1\n0000000000 65535 f \n\(size) 1\n\(offset) 00000 n \ntrailer\n<< /Size \(size+1) /Root \(root)\(info) /Prev \(previous) >>\nstartxref\n\(pdf.count+entry.utf8.count)\n%%EOF\n"
        var result = pdf
        result.append(Data((entry + footer).utf8))
        return result
    }
}
