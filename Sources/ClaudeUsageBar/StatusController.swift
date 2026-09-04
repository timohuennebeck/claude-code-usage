import AppKit
import ClaudeUsageCore

/// Owns the NSStatusItem: polls usage, redraws the item, flips the window on click,
/// shows a details menu on right click, and swaps percent for the window label on hover.
final class StatusController: NSResponder {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let client = UsageClient()
    private let pollInterval: TimeInterval = 60

    private var window: UsageWindow = {
        UserDefaults.standard.string(forKey: "window").flatMap(UsageWindow.init(rawValue:)) ?? .fiveHour
    }()
    private var snapshot: UsageSnapshot?
    private var plan: String?
    private var lastError: String?
    private var timer: Timer?

    private var hovered = false { didSet { if hovered != oldValue { redraw() } } }

    required init?(coder: NSCoder) { fatalError() }

    override init() {
        super.init()
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(clicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.imagePosition = .imageOnly
        button.addTrackingArea(NSTrackingArea(
            rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self, userInfo: nil))

        redraw()
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(refresh), name: NSWorkspace.didWakeNotification, object: nil)
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in self?.refresh() }
        timer?.tolerance = 5
        refresh()
    }

    // MARK: Data

    @objc private func refresh() {
        Task { @MainActor in
            do {
                let creds = try CredentialsStore.load()
                plan = creds.subscriptionType
                snapshot = try await client.fetch(credentials: creds)
                lastError = nil
            } catch {
                lastError = error.localizedDescription
            }
            redraw()
        }
    }

    private func redraw() {
        let state: StatusItemState
        if let snapshot {
            state = .usage(snapshot.limit(for: window), window: window, now: Date())
        } else if let lastError {
            state = .error(lastError, window: window)
        } else {
            state = .loading(window: window)
        }
        statusItem.button?.image = StatusItemRenderer.render(state, hovered: hovered)
    }

    private func describe(_ w: UsageWindow, in snapshot: UsageSnapshot) -> String {
        let l = snapshot.limit(for: w)
        guard let reset = l.resetsAtOptional else { return "\(w.title): \(UsageFormatting.percentText(l.utilization)) used" }
        return "\(w.title): \(UsageFormatting.percentText(l.utilization)) used · resets in \(UsageFormatting.remaining(until: reset, window: w)) (\(UsageFormatting.resetClock(reset)))"
    }

    // MARK: Hover

    override func mouseEntered(with event: NSEvent) { hovered = true }
    override func mouseExited(with event: NSEvent) { hovered = false }

    // MARK: Interaction

    @objc private func clicked(_ sender: Any?) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showMenu()
        } else {
            window = window.toggled
            UserDefaults.standard.set(window.rawValue, forKey: "window")
            redraw()
        }
    }

    private func showMenu() {
        let menu = NSMenu()
        if let snapshot {
            for w in UsageWindow.allCases {
                let item = NSMenuItem(title: describe(w, in: snapshot), action: #selector(selectWindow(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = w.rawValue
                item.state = w == window ? .on : .off
                menu.addItem(item)
            }
            for scoped in snapshot.scoped {
                menu.addItem(disabled("\(scoped.label) (7d): \(UsageFormatting.percentText(scoped.limit.utilization)) used"))
            }
            let f = DateFormatter(); f.timeStyle = .short
            menu.addItem(disabled("Updated \(f.string(from: snapshot.fetchedAt))"))
        } else {
            menu.addItem(disabled(lastError ?? "Loading…"))
        }
        menu.addItem(.separator())
        menu.addItem(withTitle: "Refresh", action: #selector(refresh), keyEquivalent: "r").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func selectWindow(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let w = UsageWindow(rawValue: raw) else { return }
        window = w
        UserDefaults.standard.set(w.rawValue, forKey: "window")
        redraw()
    }

    private func disabled(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }
}
