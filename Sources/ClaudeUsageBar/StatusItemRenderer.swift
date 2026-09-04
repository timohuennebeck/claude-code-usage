import AppKit
import ClaudeUsageCore

/// What the menu bar item shows. Rendered to an NSImage so the status button handles
/// clicks and appearance changes for us.
enum StatusItemState {
    case loading(window: UsageWindow)
    case usage(UsageSnapshot, window: UsageWindow, now: Date)
    case error(String, window: UsageWindow)
}

enum StatusItemRenderer {
    // Layout in points, from the design (logo 13, bar 36×4, 12pt medium text).
    // Window indicator, page-control style: the active window is a short pill, the other a dot.
    private static let height: CGFloat = 22
    private static let logoSize: CGFloat = 13
    private static let barSize = CGSize(width: 36, height: 4)
    private static let dotSize: CGFloat = 4
    private static let activeDotWidth: CGFloat = 8
    private static let dotGap: CGFloat = 3
    private static let gap: CGFloat = 7
    private static let textGap: CGFloat = 4
    private static let font = NSFont.systemFont(ofSize: 12, weight: .medium)

    static let logo: NSImage? = {
        let url = Bundle.main.url(forResource: "logo-white", withExtension: "png")
            ?? Bundle.module.url(forResource: "logo-white", withExtension: "png")
        return url.flatMap { NSImage(contentsOf: $0) }
    }()

    /// `stale` dims the whole item to signal the numbers may be out of date.
    static func render(_ state: StatusItemState, stale: Bool = false) -> NSImage {
        let image = render(state)
        guard stale else { return image }
        return NSImage(size: image.size, flipped: false) { rect in
            image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 0.5)
            return true
        }
    }

    private static func render(_ state: StatusItemState) -> NSImage {
        let pieces = pieces(for: state)
        // Slots are sized to the wider of the two windows so flipping 5h/7d never shifts the layout.
        let (percentSlot, detailSlot) = slotWidths(for: state, current: pieces)
        var width: CGFloat = logoSize + gap + barSize.width + gap
        width += percentSlot + textGap + detailSlot
        width += gap + activeDotWidth + dotSize + dotGap + 1 // 1pt so the last dot is not clipped

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

            // Percent right-aligned in its slot, detail left-aligned in its slot.
            pieces.percent.draw(at: NSPoint(x: x + percentSlot - pieces.percent.width, y: midY - pieces.percent.height / 2))
            x += percentSlot + textGap
            pieces.detail.draw(at: NSPoint(x: x, y: midY - pieces.detail.height / 2))
            x += detailSlot + gap

            // Window indicator: left = 5h, right = 7d. Active one is a pill.
            for window in UsageWindow.allCases {
                let active = window == pieces.activeWindow
                let w = active ? activeDotWidth : dotSize
                (active ? Palette.foreground : Palette.inactiveDot).setFill()
                let rect = NSRect(x: x, y: midY - dotSize / 2, width: w, height: dotSize)
                NSBezierPath(roundedRect: rect, xRadius: dotSize / 2, yRadius: dotSize / 2).fill()
                x += w + dotGap
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

    private static func slotWidths(for state: StatusItemState, current: Pieces) -> (CGFloat, CGFloat) {
        guard case .usage(let snapshot, _, let now) = state else {
            return (current.percent.width, current.detail.width)
        }
        var percent = current.percent.width
        var detail = current.detail.width
        for w in UsageWindow.allCases {
            let other = pieces(for: .usage(snapshot, window: w, now: now))
            percent = max(percent, other.percent.width)
            detail = max(detail, other.detail.width)
        }
        return (percent, detail)
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
        case .usage(let snapshot, let window, let now):
            let limit = snapshot.limit(for: window)
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
