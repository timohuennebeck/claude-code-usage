import AppKit
import ClaudeUsageCore

/// Owns the NSStatusItem: polls usage, redraws the item, flips the window on click,
/// shows a details menu on right click, and a hover card with the model breakdown.
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

    private let popover = NSPopover()
    private let popoverView = UsagePopoverView(frame: .zero)
    private var hoverOpen: DispatchWorkItem?
    private var hoverClose: DispatchWorkItem?
    private let hoverDelay: TimeInterval = 0.4
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

        let vc = NSViewController()
        vc.view = popoverView
        popover.contentViewController = vc
        popover.behavior = .transient
        popover.animates = false
        popover.appearance = NSAppearance(named: .darkAqua)

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
        if popover.isShown { popoverView.update(snapshot: snapshot, error: lastError, plan: plan) }
    }

    // MARK: Hover card

    override func mouseEntered(with event: NSEvent) {
        hoverClose?.cancel()
        if event.trackingArea?.owner as? NSView == nil, isOverItem() { hovered = true }
        guard !popover.isShown, statusItem.menu == nil else { return }
        let work = DispatchWorkItem { [weak self] in self?.showPopover() }
        hoverOpen = work
        DispatchQueue.main.asyncAfter(deadline: .now() + hoverDelay, execute: work)
    }

    override func mouseExited(with event: NSEvent) {
        hoverOpen?.cancel()
        if !isOverItem() { hovered = false }
        scheduleClose()
    }

    private func isOverItem() -> Bool {
        guard let button = statusItem.button, let window = button.window else { return false }
        return button.convert(button.bounds, to: nil).contains(window.convertPoint(fromScreen: NSEvent.mouseLocation))
    }

    private func showPopover() {
        guard let button = statusItem.button, !popover.isShown else { return }
        popoverView.update(snapshot: snapshot, error: lastError, plan: plan)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        // Close once the pointer has left both the item and the card.
        popover.contentViewController?.view.window?.acceptsMouseMovedEvents = true
        if let view = popover.contentViewController?.view, view.trackingAreas.isEmpty {
            view.addTrackingArea(NSTrackingArea(
                rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self, userInfo: nil))
        }
    }

    private func scheduleClose() {
        hoverClose?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.popover.isShown else { return }
            let mouse = NSEvent.mouseLocation
            let overCard = self.popover.contentViewController?.view.window?.frame.contains(mouse) ?? false
            let overItem = self.statusItem.button?.window?.frame.contains(mouse) ?? false
            if !overCard && !overItem { self.popover.performClose(nil) }
        }
        hoverClose = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
    }

    private func closePopover() {
        hoverOpen?.cancel()
        hoverClose?.cancel()
        if popover.isShown { popover.performClose(nil) }
    }

    private func describe(_ w: UsageWindow, in snapshot: UsageSnapshot) -> String {
        let l = snapshot.limit(for: w)
        guard let reset = l.resetsAtOptional else { return "\(w.title): \(UsageFormatting.percentText(l.utilization)) used" }
        return "\(w.title): \(UsageFormatting.percentText(l.utilization)) used · resets in \(UsageFormatting.remaining(until: reset, window: w)) (\(UsageFormatting.resetClock(reset)))"
    }

    // MARK: Interaction

    @objc private func clicked(_ sender: Any?) {
        closePopover()
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
