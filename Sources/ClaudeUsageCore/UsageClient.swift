import Foundation

public enum UsageClientError: LocalizedError {
    case unauthorized
    case http(Int, String)
    case transport(Error)

    public var errorDescription: String? {
        switch self {
        case .unauthorized: return "Claude Code session expired. Run `claude` to sign in again."
        case .http(let code, let body): return "Usage API returned HTTP \(code): \(body.prefix(200))"
        case .transport(let e): return e.localizedDescription
        }
    }
}

/// Fetches rate-limit utilization for the signed-in Claude Code user.
public struct UsageClient {
    public static let endpoint = URL(string: "https://api.anthropic.com/api/oauth/usage")!

    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func fetch(credentials: ClaudeCredentials) async throws -> UsageSnapshot {
        var req = URLRequest(url: Self.endpoint)
        req.httpMethod = "GET"
        req.setValue("Bearer \(credentials.accessToken)", forHTTPHeaderField: "Authorization")
        req.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("ClaudeUsageBar/1.0", forHTTPHeaderField: "User-Agent")
        req.timeoutInterval = 15

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: req)
        } catch {
            throw UsageClientError.transport(error)
        }
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        switch code {
        case 200..<300:
            return try UsageSnapshot.decode(data)
        case 401, 403:
            throw UsageClientError.unauthorized
        default:
            throw UsageClientError.http(code, String(decoding: data, as: UTF8.self))
        }
    }
}
