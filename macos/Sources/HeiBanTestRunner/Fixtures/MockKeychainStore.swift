import Foundation
import HeiBanCore

/// 既有檢查使用的記憶體替身，不能作為正式登入／雲端實作。
public final class MockKeychainStore: KeychainStore {
    private var storage: [String: Data] = [:]

    public init() {}

    public func save(key: String, data: Data) -> Bool {
        storage[key] = data
        return true
    }

    public func load(key: String) -> Data? {
        return storage[key]
    }

    public func delete(key: String) -> Bool {
        storage.removeValue(forKey: key)
        return true
    }

    public func clearAll() {
        storage.removeAll()
    }
}
