import Foundation
import Security

public struct ClaudeCredentials: Equatable {
    public let accessToken: String
    public let expiresAt: Date?
    public let subscriptionType: String?

    public func isExpired(at now: Date = Date()) -> Bool {
        guard let expiresAt else { return false }
        return now >= expiresAt
    }

    private struct Wire: Decodable {
        struct OAuth: Decodable {
            let accessToken: String
            let expiresAt: Double?
            let subscriptionType: String?
        }
        let claudeAiOauth: OAuth
    }

    public static func decode(_ data: Data) throws -> ClaudeCredentials {
        let wire = try JSONDecoder().decode(Wire.self, from: data)
        return ClaudeCredentials(
            accessToken: wire.claudeAiOauth.accessToken,
            expiresAt: wire.claudeAiOauth.expiresAt.map { Date(timeIntervalSince1970: $0 / 1000) },
            subscriptionType: wire.claudeAiOauth.subscriptionType
        )
    }
}

public enum CredentialsError: LocalizedError {
    case notFound
    case unreadable(String)

    public var errorDescription: String? {
        switch self {
        case .notFound: return "No Claude Code login found. Run `claude` and sign in."
        case .unreadable(let why): return "Could not read Claude Code credentials: \(why)"
        }
    }
}

/// Reads the OAuth token Claude Code stores on this machine.
/// Order: macOS Keychain item "Claude Code-credentials", then ~/.claude/.credentials.json.
public enum CredentialsStore {
    public static let keychainService = "Claude Code-credentials"

    public static func load() throws -> ClaudeCredentials {
        if let data = keychainBlob() {
            return try ClaudeCredentials.decode(data)
        }
        let file = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/.credentials.json")
        if let data = try? Data(contentsOf: file) {
            do { return try ClaudeCredentials.decode(data) }
            catch { throw CredentialsError.unreadable(error.localizedDescription) }
        }
        throw CredentialsError.notFound
    }

    private static func keychainBlob() -> Data? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: keychainService,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else { return nil }
        return item as? Data
    }
}
