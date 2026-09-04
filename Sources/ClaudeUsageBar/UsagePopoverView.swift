import AppKit
import ClaudeUsageCore

/// Hover card: both windows with bars and reset times, the weekly per-model
/// breakdown, and a plan/updated footer. Dark, like the design.
final class UsagePopoverView: NSView {
    static let width: CGFloat = 272

    private let stack = NSStackView()

    override init(frame: NSRect) {
        super.init(frame: frame)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 14, left: 14, bottom: 12, right: 14)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            widthAnchor.constraint(equalToConstant: Self.width),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func update(snapshot: UsageSnapshot?, error: String?, plan: String?, now: Date = Date()) {
        stack.views.forEach { $0.removeFromSuperview() }

        guard let snapshot else {
            add(label(error ?? "Loading usage…", size: 12, weight: .regular, color: Palette.secondary))
            return
        }

        for window in UsageWindow.allCases {
            add(row(title: window.title, limit: snapshot.limit(for: window), window: window, now: now))
        }

        if !snapshot.scoped.isEmpty {
            add(divider())
            add(label("WEEKLY BY MODEL", size: 10, weight: .semibold, color: Palette.muted, kern: 0.6))
            for scoped in snapshot.scoped {
                add(row(title: scoped.label, limit: scoped.limit, window: .sevenDay, now: now, compact: true))
            }
        }

        add(divider())
        let time = DateFormatter(); time.timeStyle = .short
        var footer = "Updated \(time.string(from: snapshot.fetchedAt))"
        if let plan { footer = "\(plan.capitalized) plan · " + footer }
        add(label(footer, size: 11, weight: .regular, color: Palette.muted))
    }

    // MARK: Building blocks

    private func add(_ view: NSView) {
        stack.addArrangedSubview(view)
        view.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -28).isActive = true
    }

    private func row(title: String, limit: UsageLimit, window: UsageWindow, now: Date, compact: Bool = false) -> NSView {
        let column = NSStackView()
        column.orientation = .vertical
        column.alignment = .leading
        column.spacing = compact ? 5 : 6

        let header = NSView()
        let titleLabel = label(title, size: compact ? 12 : 13, weight: .medium, color: Palette.foreground)
        let percent = label(UsageFormatting.percentText(limit.utilization), size: compact ? 12 : 13,
                            weight: .semibold, color: Palette.percent(for: limit.severity))
        percent.setContentCompressionResistancePriority(.required, for: .horizontal)
        percent.setContentHuggingPriority(.required, for: .horizontal)
        titleLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        for v in [titleLabel, percent] {
            v.translatesAutoresizingMaskIntoConstraints = false
            header.addSubview(v)
        }
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: header.leadingAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            percent.trailingAnchor.constraint(equalTo: header.trailingAnchor),
            percent.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: percent.leadingAnchor, constant: -8),
            header.heightAnchor.constraint(equalTo: percent.heightAnchor),
        ])
        column.addArrangedSubview(header)
        header.widthAnchor.constraint(equalTo: column.widthAnchor).isActive = true

        let bar = BarView()
        bar.fraction = CGFloat(limit.utilization / 100)
        bar.color = Palette.bar(for: limit.severity)
        column.addArrangedSubview(bar)
        bar.widthAnchor.constraint(equalTo: column.widthAnchor).isActive = true

        if let reset = limit.resetsAtOptional {
            let text = "Resets in \(UsageFormatting.remaining(until: reset, now: now, window: window)) · \(UsageFormatting.resetClock(reset))"
            column.addArrangedSubview(label(text, size: 11, weight: .regular, color: Palette.muted))
        } else if !compact {
            column.addArrangedSubview(label("No reset scheduled", size: 11, weight: .regular, color: Palette.muted))
        }
        return column
    }

    private func label(_ text: String, size: CGFloat, weight: NSFont.Weight, color: NSColor, kern: CGFloat = 0) -> NSTextField {
        let attributed = NSAttributedString(string: text, attributes: [
            .font: NSFont.systemFont(ofSize: size, weight: weight),
            .foregroundColor: color,
            .kern: kern,
        ])
        let field = NSTextField(labelWithAttributedString: attributed)
        field.usesSingleLineMode = true
        field.maximumNumberOfLines = 1
        field.lineBreakMode = .byTruncatingTail
        field.cell?.truncatesLastVisibleLine = true
        return field
    }

    private func divider() -> NSView {
        let line = NSBox()
        line.boxType = .separator
        return line
    }
}

/// Rounded 4pt track with a colored fill, same as the menu bar item's bar.
final class BarView: NSView {
    var fraction: CGFloat = 0 { didSet { needsDisplay = true } }
    var color: NSColor = Palette.foreground { didSet { needsDisplay = true } }

    override var intrinsicContentSize: NSSize { NSSize(width: NSView.noIntrinsicMetric, height: 4) }

    override func draw(_ dirtyRect: NSRect) {
        Palette.track.setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 2, yRadius: 2).fill()
        guard fraction > 0 else { return }
        let fill = NSRect(x: 0, y: 0, width: max(bounds.height, bounds.width * min(fraction, 1)), height: bounds.height)
        color.setFill()
        NSBezierPath(roundedRect: fill, xRadius: 2, yRadius: 2).fill()
    }
}
