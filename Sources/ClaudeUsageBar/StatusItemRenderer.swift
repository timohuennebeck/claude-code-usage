import AppKit
import ClaudeUsageCore

/// What the menu bar item shows. Rendered to an NSImage so the status button handles
/// clicks and appearance changes for us.
enum StatusItemState {
    case loading(window: UsageWindow)
    case usage(UsageLimit, window: UsageWindow, now: Date)
    case error(String, window: UsageWindow)
}

enum StatusItemRenderer {
    // Layout in points, from the design (logo 13, bar 36×4, 12pt medium text).
    // Window dots: the active one is larger and full-strength so it reads at a glance.
    private static let height: CGFloat = 22
    private static let logoSize: CGFloat = 13
    private static let barSize = CGSize(width: 36, height: 4)
    private static let activeDotSize: CGFloat = 6
    private static let inactiveDotSize: CGFloat = 4
    private static let dotGap: CGFloat = 3
    private static let gap: CGFloat = 7
    private static let textGap: CGFloat = 4
    private static let font = NSFont.systemFont(ofSize: 12, weight: .medium)

    static let logo: NSImage? = {
        let url = Bundle.main.url(forResource: "logo-white", withExtension: "png")
            ?? Bundle.module.url(forResource: "logo-white", withExtension: "png")
        return url.flatMap { NSImage(contentsOf: $0) }
    }()

    static func render(_ state: StatusItemState) -> NSImage {
        let pieces = pieces(for: state)
        var width: CGFloat = logoSize + gap + barSize.width + gap
        width += pieces.percent.width + textGap + pieces.detail.width
        width += gap + activeDotSize + inactiveDotSize + dotGap + 1 // 1pt so the last dot is not clipped

        let image = NSImage(size: NSSize(width: ceil(width), height: height), flipped: false) { rect in
            var x: CGFloat = 0
            let midY = rect.midY

            // Logo, tinted with the foreground color.
            if let logo {
                let logoRect = NSRect(x: x, y: midY - logoSize / 2, width: logoSize, height: logoSize)
                logo.draw(in: logoRect, from: .zero, operation: .sourceOver, fraction: 1)
                Palette.foreground.set()
                logoRect.fill(using: .sourceAtop)
            }
            x += logoSize + gap

            // Bar.
            let track = NSRect(x: x, y: midY - barSize.height / 2, width: barSize.width, height: barSize.height)
            Palette.track.setFill()
            NSBezierPath(roundedRect: track, xRadius: 2, yRadius: 2).fill()
            if pieces.fill > 0 {
                let fillWidth = max(barSize.height, track.width * pieces.fill)
                let fillRect = NSRect(x: track.minX, y: track.minY, width: fillWidth, height: track.height)
                pieces.barColor.setFill()
                NSBezierPath(roundedRect: fillRect, xRadius: 2, yRadius: 2).fill()
            }
            x += barSize.width + gap

            // Percent and detail text.
            pieces.percent.draw(at: NSPoint(x: x, y: midY - pieces.percent.height / 2))
            x += pieces.percent.width + textGap
            pieces.detail.draw(at: NSPoint(x: x, y: midY - pieces.detail.height / 2))
            x += pieces.detail.width + gap

            // Window dots: left = 5h, right = 7d. Active one is bigger.
            for window in UsageWindow.allCases {
                let active = window == pieces.activeWindow
                let size = active ? activeDotSize : inactiveDotSize
                (active ? Palette.foreground : Palette.inactiveDot).setFill()
                NSBezierPath(ovalIn: NSRect(x: x, y: midY - size / 2, width: size, height: size)).fill()
                x += size + dotGap
            }
            return true
        }
        image.isTemplate = false
        return image
    }

    private struct Pieces {
        let fill: CGFloat
        let barColor: NSColor
        let percent: NSAttributedString
        let detail: NSAttributedString
        let activeWindow: UsageWindow
    }

    private static func pieces(for state: StatusItemState) -> Pieces {
        switch state {
        case .loading(let window):
            return Pieces(fill: 0, barColor: Palette.foreground,
                          percent: text("—", Palette.foreground),
                          detail: text("· loading", Palette.secondary),
                          activeWindow: window)
        case .error(_, let window):
            return Pieces(fill: 0, barColor: Palette.foreground,
                          percent: text("—", Palette.foreground),
                          detail: text("· offline", Palette.secondary),
                          activeWindow: window)
        case .usage(let limit, let window, let now):
            let remaining = limit.resetsAtOptional.map { UsageFormatting.remaining(until: $0, now: now, window: window) } ?? "?"
            return Pieces(fill: CGFloat(limit.utilization / 100),
                          barColor: Palette.bar(for: limit.severity),
                          percent: text(UsageFormatting.percentText(limit.utilization), Palette.percent(for: limit.severity)),
                          detail: text("· \(remaining)", Palette.secondary),
                          activeWindow: window)
        }
    }

    private static func text(_ s: String, _ color: NSColor) -> NSAttributedString {
        NSAttributedString(string: s, attributes: [.font: font, .foregroundColor: color])
    }
}

private extension NSAttributedString {
    var width: CGFloat { ceil(size().width) }
    var height: CGFloat { size().height }
}
