import Foundation

public enum UsageFormatting {
    /// "2h 41m" for the 5h window; "4d 4h" for the 7d window once at least a day remains.
    public static func remaining(until reset: Date, now: Date = Date(), window: UsageWindow) -> String {
        let seconds = reset.timeIntervalSince(now)
        guard seconds > 0 else { return "now" }
        let totalMinutes = Int(seconds / 60)
        let days = totalMinutes / (24 * 60)
        let hours = (totalMinutes % (24 * 60)) / 60
        let minutes = totalMinutes % 60

        if window == .sevenDay && days >= 1 {
            return "\(days)d \(hours)h"
        }
        return "\(days * 24 + hours)h \(minutes)m"
    }

    public static func percentText(_ utilization: Double) -> String {
        "\(Int(utilization.rounded()))%"
    }

    public static func resetClock(_ reset: Date) -> String {
        let f = DateFormatter()
        f.locale = .current
        f.setLocalizedDateFormatFromTemplate("EEE d MMM HH:mm")
        return f.string(from: reset)
    }
}
