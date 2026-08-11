import Foundation
import Security

public protocol SecretStoring: Sendable {
    func set(_ data: Data, for reference: String) async throws
    func data(for reference: String) async throws -> Data
    func remove(reference: String) async throws
}

public actor SharedKeychainStore: SecretStoring {
    public static let service = "com.yilinglabs.routeva.secrets"
    public static let accessGroupInfoKey = "RoutevaKeychainAccessGroup"

    private let serviceName: String
    private let accessGroup: String?

    public init(
        serviceName: String = SharedKeychainStore.service,
        accessGroup: String? = Bundle.main.object(
            forInfoDictionaryKey: SharedKeychainStore.accessGroupInfoKey
        ) as? String
    ) {
        self.serviceName = serviceName
        self.accessGroup = accessGroup
    }

    public func set(_ data: Data, for reference: String) throws {
        var query = baseQuery(reference: reference)
        SecItemDelete(query as CFDictionary)
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainStoreError.status(status) }
    }

    public func data(for reference: String) throws -> Data {
        var query = baseQuery(reference: reference)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else {
            if status == errSecItemNotFound { throw KeychainStoreError.notFound }
            throw KeychainStoreError.status(status)
        }
        guard let data = result as? Data else { throw KeychainStoreError.invalidData }
        return data
    }

    public func remove(reference: String) throws {
        let status = SecItemDelete(baseQuery(reference: reference) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainStoreError.status(status)
        }
    }

    private func baseQuery(reference: String) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: reference,
            kSecAttrSynchronizable as String: kCFBooleanFalse as Any,
        ]
        if let accessGroup, !accessGroup.isEmpty {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        return query
    }
}

public enum KeychainStoreError: Error, Equatable {
    case notFound
    case invalidData
    case status(OSStatus)
}
