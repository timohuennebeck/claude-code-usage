import Foundation

public enum UsageWindow: String, CaseIterable, Codable {
    case fiveHour
    case sevenDay

    public var label: String {
        switch self {
        case .fiveHour: return "5h"
        case .sevenDay: return "7d"
        }
    }

    public var title: String {
        switch self {
        case .fiveHour: return "5-hour limit"
        case .sevenDay: return "7-day limit"
        }
    }

    public var toggled: UsageWindow {
        self == .fiveHour ? .sevenDay : .fiveHour
    }
}

public enum UsageSeverity: Equatable {
    case normal
    case approaching
    case critical

    public init(utilization: Double) {
        if utilization >= 85 {
            self = .critical
        } else if utilization >= 60 {
            self = .approaching
        } else {
            self = .normal
        }
    }
}

public struct UsageLimit: Equatable {
    /// Percent used, 0...100.
    public let utilization: Double
    public let resetsAtOptional: Date?

    public init(utilization: Double, resetsAt: Date?) {
        self.utilization = min(max(utilization, 0), 100)
        self.resetsAtOptional = resetsAt
    }

    /// Reset date, falling back to the distant past when the API sends none.
    public var resetsAt: Date { resetsAtOptional ?? .distantPast }

    public var severity: UsageSeverity { UsageSeverity(utilization: utilization) }
}

public struct UsageSnapshot: Equatable {
    public let fiveHour: UsageLimit
    public let sevenDay: UsageLimit
    public let fetchedAt: Date

    public init(fiveHour: UsageLimit, sevenDay: UsageLimit, fetchedAt: Date = Date()) {
        self.fiveHour = fiveHour
        self.sevenDay = sevenDay
        self.fetchedAt = fetchedAt
    }

    public func limit(for window: UsageWindow) -> UsageLimit {
        switch window {
        case .fiveHour: return fiveHour
        case .sevenDay: return sevenDay
        }
    }

    // MARK: Decoding

    private struct Wire: Decodable {
        struct Bucket: Decodable {
            let utilization: Double?
            let resets_at: String?
        }
        let five_hour: Bucket?
        let seven_day: Bucket?
    }

    public static func decode(_ data: Data, fetchedAt: Date = Date()) throws -> UsageSnapshot {
        let wire = try JSONDecoder().decode(Wire.self, from: data)
        func limit(_ b: Wire.Bucket?) -> UsageLimit {
            UsageLimit(
                utilization: b?.utilization ?? 0,
                resetsAt: b?.resets_at.flatMap(ISO8601.parse)
            )
        }
        return UsageSnapshot(
            fiveHour: limit(wire.five_hour),
            sevenDay: limit(wire.seven_day),
            fetchedAt: fetchedAt
        )
    }
}

enum ISO8601 {
    private static let withFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let plain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static func parse(_ s: String) -> Date? {
        withFraction.date(from: s) ?? plain.date(from: s)
    }
}
