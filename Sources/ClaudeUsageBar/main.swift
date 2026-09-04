import AppKit
import ClaudeUsageCore

// `ClaudeUsageBar --raw` prints the raw usage JSON.
if CommandLine.arguments.contains("--raw") {
    let semaphore = DispatchSemaphore(value: 0)
    Task {
        defer { semaphore.signal() }
        do {
            let data = try await UsageClient().fetchRaw(credentials: try CredentialsStore.load())
            print(String(decoding: data, as: UTF8.self))
        } catch { fputs("error: \(error.localizedDescription)\n", stderr); exit(1) }
    }
    semaphore.wait()
    exit(0)
}

// `ClaudeUsageBar --check` prints the current usage to stdout and exits.
if CommandLine.arguments.contains("--check") {
    let semaphore = DispatchSemaphore(value: 0)
    Task {
        defer { semaphore.signal() }
        do {
            let creds = try CredentialsStore.load()
            let snap = try await UsageClient().fetch(credentials: creds)
            for window in UsageWindow.allCases {
                let l = snap.limit(for: window)
                let reset = l.resetsAtOptional.map { UsageFormatting.remaining(until: $0, window: window) } ?? "?"
                print("\(window.label): \(UsageFormatting.percentText(l.utilization)) used, resets in \(reset) (\(l.resetsAtOptional.map(UsageFormatting.resetClock) ?? "unknown"))")
            }
            if let plan = creds.subscriptionType { print("plan: \(plan)") }
        } catch {
            fputs("error: \(error.localizedDescription)\n", stderr)
            exit(1)
        }
    }
    semaphore.wait()
    exit(0)
}

// `ClaudeUsageBar --render <dir>` writes the item at the design's four states as 2x PNGs.
if let i = CommandLine.arguments.firstIndex(of: "--render"), i + 1 < CommandLine.arguments.count {
    let dir = URL(fileURLWithPath: CommandLine.arguments[i + 1])
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let now = Date()
    let states: [(String, StatusItemState)] = [
        ("5h-19", .usage(UsageLimit(utilization: 19, resetsAt: now.addingTimeInterval(2 * 3600 + 41 * 60)), window: .fiveHour, now: now)),
        ("5h-68", .usage(UsageLimit(utilization: 68, resetsAt: now.addingTimeInterval(1 * 3600 + 12 * 60)), window: .fiveHour, now: now)),
        ("5h-91", .usage(UsageLimit(utilization: 91, resetsAt: now.addingTimeInterval(24 * 60)), window: .fiveHour, now: now)),
        ("7d-66", .usage(UsageLimit(utilization: 66, resetsAt: now.addingTimeInterval(4 * 86400 + 4 * 3600)), window: .sevenDay, now: now)),
        ("loading", .loading(window: .fiveHour)),
        ("error", .error("offline", window: .fiveHour)),
    ]
    for (name, state) in states {
        var image = StatusItemRenderer.render(state)
        NSAppearance(named: .darkAqua)?.performAsCurrentDrawingAppearance { image = StatusItemRenderer.render(state) }
        let size = image.size
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width * 2), pixelsHigh: Int(size.height * 2),
                                   bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                   colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        rep.size = size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSColor(srgbRed: 10/255, green: 10/255, blue: 11/255, alpha: 1).setFill()
        NSRect(origin: .zero, size: size).fill()
        NSAppearance(named: .darkAqua)?.performAsCurrentDrawingAppearance { image.draw(in: NSRect(origin: .zero, size: size)) }
        NSGraphicsContext.restoreGraphicsState()
        try? rep.representation(using: .png, properties: [:])?.write(to: dir.appendingPathComponent("\(name).png"))
    }
    print("rendered \(states.count) states to \(dir.path)")
    exit(0)
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
