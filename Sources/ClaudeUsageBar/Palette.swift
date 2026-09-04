import AppKit
import ClaudeUsageCore

/// Colors from the design. Pure white on a dark menu bar, pure black on a light one,
/// so the item reads like the system's own status icons (labelColor is only 85% alpha).
enum Palette {
    static let foreground = NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? .white : .black
    }
    /// Reset countdown: same weight as the percent, so it stays readable on busy wallpapers.
    static let secondary = foreground
    static let inactiveDot = foreground.withAlphaComponent(0.4)
    static let track = foreground.withAlphaComponent(0.3)
    static let amber = NSColor(srgbRed: 1.0, green: 0xB0 / 255, blue: 0x2B / 255, alpha: 1)
    static let red = NSColor(srgbRed: 1.0, green: 0x5A / 255, blue: 0x4F / 255, alpha: 1)

    static func bar(for severity: UsageSeverity) -> NSColor {
        switch severity {
        case .normal: return foreground
        case .approaching: return amber
        case .critical: return red
        }
    }

    static func percent(for severity: UsageSeverity) -> NSColor {
        severity == .critical ? red : foreground
    }
}
