import AppKit
import ClaudeUsageCore
import Network

/// Owns the NSStatusItem: polls usage, redraws the item, flips the window on click,
/// and shows a details menu on right click.
final class StatusController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let client = UsageClient()
    private static let cacheKey = "snapshot"

    private var window: UsageWindow = {
        UserDefaults.standard.string(forKey: "window").flatMap(UsageWindow.init(rawValue:)) ?? .fiveHour
    }()
    private var snapshot: UsageSnapshot? = {
        UserDefaults.standard.data(forKey: cacheKey).flatMap { try? JSONDecoder().decode(UsageSnapshot.self, from: $0) }
    }()
    private var plan: String?
    private var lastError: String?
    private var consecutiveRateLimits = 0
    private var consecutiveFailures = 0
    private let pathMonitor = NWPathMonitor()
    private var networkWasReachable = true
    private var fetchTimer: Timer?
    private var tickTimer: Timer?


    override init() {
        super.init()
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(clicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.imagePosition = .imageOnly

        redraw()
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(refresh), name: NSWorkspace.didWakeNotification, object: nil)
        // Countdown and staleness are computed locally, so redraw every minute regardless of fetches.
        tickTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in self?.redraw() }
        tickTimer?.tolerance = 5
        // At login the app usually starts before the network is up. Refresh as soon as it appears.
        pathMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                guard let self else { return }
                let reachable = path.status == .satisfied
                if reachable && !self.networkWasReachable { self.refresh() }
                self.networkWasReachable = reachable
            }
        }
        pathMonitor.start(queue: DispatchQueue(label: "network-path"))
        refresh()
    }

    // MARK: Data

    @objc private func refresh() {
        fetchTimer?.invalidate()
        Task { @MainActor in
            var retryAfter: TimeInterval?
            do {
                let creds = try CredentialsStore.load()
                plan = creds.subscriptionType
                let fresh = try await client.fetch(credentials: creds)
                snapshot = fresh
                lastError = nil
                consecutiveRateLimits = 0
                consecutiveFailures = 0
                if let data = try? JSONEncoder().encode(fresh) {
                    UserDefaults.standard.set(data, forKey: Self.cacheKey)
                }
            } catch let UsageClientError.rateLimited(after) {
                consecutiveRateLimits += 1
                consecutiveFailures = 0
                retryAfter = after
                lastError = UsageClientError.rateLimited(retryAfter: after).localizedDescription
            } catch {
                consecutiveFailures += 1
                lastError = error.localizedDescription
            }
            redraw()
            scheduleNextFetch(retryAfter: retryAfter)
        }
    }

    private func scheduleNextFetch(retryAfter: TimeInterval?) {
        let delay = consecutiveFailures > 0
            ? RefreshPolicy.retryDelay(consecutiveFailures: consecutiveFailures)
            : RefreshPolicy.nextDelay(consecutiveRateLimits: consecutiveRateLimits, retryAfter: retryAfter)
        fetchTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in self?.refresh() }
        fetchTimer?.tolerance = 10
    }

    private func redraw() {
        let state: StatusItemState
        var stale = false
        if let snapshot {
            state = .usage(snapshot, window: window, now: Date())
            stale = RefreshPolicy.isStale(fetchedAt: snapshot.fetchedAt)
        } else if let lastError {
            state = .error(lastError, window: window)
        } else {
            state = .loading(window: window)
        }
        statusItem.button?.image = StatusItemRenderer.render(state, stale: stale)
    }

    private func describe(_ w: UsageWindow, in snapshot: UsageSnapshot) -> String {
        let l = snapshot.limit(for: w)
        guard let reset = l.resetsAtOptional else { return "\(w.title): \(UsageFormatting.percentText(l.utilization)) used" }
        return "\(w.title): \(UsageFormatting.percentText(l.utilization)) used · resets in \(UsageFormatting.remaining(until: reset, window: w)) (\(UsageFormatting.resetClock(reset)))"
    }

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
            if let lastError { menu.addItem(disabled("Couldn't refresh: \(lastError)")) }
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
