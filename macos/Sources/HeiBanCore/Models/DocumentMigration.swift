import Foundation

public enum DocumentMigrationError: Error, LocalizedError, Equatable {
    case unsupportedFutureVersion(found: String, supportedMax: String)
    case corruptedData(reason: String)
    case missingRequiredField(field: String)

    public var errorDescription: String? {
        switch self {
        case .unsupportedFutureVersion(let found, let supportedMax):
            return "不支援的文件格式版本：\(found) (本版本最高支援 \(supportedMax))"
        case .corruptedData(let reason):
            return "黑板檔案資料損壞或格式錯誤：\(reason)"
        case .missingRequiredField(let field):
            return "黑板檔案缺少必要欄位：\(field)"
        }
    }
}

public enum HeiBanDocumentCodec {
    public static let currentSchemaVersion = "1.0.0"
    public static let currentVersion = "1.0"
    public static let maxSupportedMajorVersion = 1

    /// 解碼並執行版本檢查與遷移
    public static func decode(from data: Data) throws -> HeiBanDocument {
        // 先以通用 JSON 物件檢查版本欄位
        guard let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw DocumentMigrationError.corruptedData(reason: "非有效 JSON 格式")
        }

        // 檢查 schemaVersion 或 legacy version
        let schemaVer = jsonObject["schemaVersion"] as? String
        let legacyVer = jsonObject["version"] as? String

        if let schemaVer {
            let parts = schemaVer.split(separator: ".").compactMap { Int($0) }
            if let major = parts.first, major > maxSupportedMajorVersion {
                throw DocumentMigrationError.unsupportedFutureVersion(found: schemaVer, supportedMax: currentSchemaVersion)
            }
        } else if let legacyVer {
            let parts = legacyVer.split(separator: ".").compactMap { Int($0) }
            if let major = parts.first, major > maxSupportedMajorVersion {
                throw DocumentMigrationError.unsupportedFutureVersion(found: legacyVer, supportedMax: currentVersion)
            }
        }

        // 正式解碼
        do {
            let decoder = JSONDecoder()
            var doc = try decoder.decode(HeiBanDocument.self, from: data)

            // 自動遷移：補齊 schemaVersion
            if doc.schemaVersion.isEmpty {
                doc.schemaVersion = currentSchemaVersion
            }
            if doc.version.isEmpty {
                doc.version = currentVersion
            }

            return doc
        } catch let decodingError as DecodingError {
            throw DocumentMigrationError.corruptedData(reason: decodingError.localizedDescription)
        } catch {
            throw DocumentMigrationError.corruptedData(reason: error.localizedDescription)
        }
    }

    /// 序列化黑板文件為 JSON Data
    public static func encode(_ document: HeiBanDocument, prettyPrinted: Bool = true) throws -> Data {
        let encoder = JSONEncoder()
        if prettyPrinted {
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        } else {
            encoder.outputFormatting = [.sortedKeys]
        }
        return try encoder.encode(document)
    }
}
