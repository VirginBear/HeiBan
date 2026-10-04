import Foundation
import Security

public protocol KeychainStore: AnyObject {
    func save(key: String, data: Data) -> Bool
    func load(key: String) -> Data?
    func delete(key: String) -> Bool
    func clearAll()
}

public final class MacOSKeychainStore: KeychainStore {
    private let service: String

    public init(service: String = "app.heiban.auth") {
        self.service = service
    }

    public func save(key: String, data: Data) -> Bool {
        delete(key: key)
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    public func load(key: String) -> Data? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            return nil
        }
        return data
    }

    public func delete(key: String) -> Bool {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    public func clearAll() {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service
        ]
        SecItemDelete(query as CFDictionary)
    }
}

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
