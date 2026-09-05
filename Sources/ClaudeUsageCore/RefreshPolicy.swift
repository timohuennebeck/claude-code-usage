import Foundation

/// How often to poll the usage endpoint. It rate-limits aggressively (60s polling gets
/// HTTP 429 with no Retry-After), so we poll slowly and back off exponentially on 429.
public enum RefreshPolicy {
    public static let baseInterval: TimeInterval = 300
    public static let maxInterval: TimeInterval = 1800
    /// After this long without a successful fetch the item is drawn dimmed.
    public static let staleAfter: TimeInterval = 900

    /// Delay before the next fetch given the number of consecutive rate-limit failures
    /// and the server's Retry-After (seconds) if it sent a useful one.
    public static func nextDelay(consecutiveRateLimits: Int, retryAfter: TimeInterval? = nil) -> TimeInterval {
        if let retryAfter, retryAfter > 0 {
            return min(max(retryAfter, baseInterval), maxInterval)
        }
        guard consecutiveRateLimits > 0 else { return baseInterval }
        let backoff = baseInterval * pow(2, Double(consecutiveRateLimits))
        return min(backoff, maxInterval)
    }

    /// Delay before retrying after a non-rate-limit failure (no network at login, keychain
    /// not ready, transient 5xx). Starts quick and backs off to the normal interval so a
    /// stale item recovers within seconds once the network is up, not five minutes later.
    public static func retryDelay(consecutiveFailures: Int) -> TimeInterval {
        guard consecutiveFailures > 0 else { return baseInterval }
        return min(15 * pow(2, Double(consecutiveFailures - 1)), baseInterval)
    }

    public static func isStale(fetchedAt: Date, now: Date = Date()) -> Bool {
        now.timeIntervalSince(fetchedAt) > staleAfter
    }
}
