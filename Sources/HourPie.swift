import AppKit
import ServiceManagement

// HourPie — a tiny menu bar clock that shows the current hour draining away
// as a pie, Time Timer style. The pie is full at :00 and empty at :59:59,
// then refills. Runs forever, like a clock.

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var timer: Timer?
    private let menu = NSMenu()
    private let remainingItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let launchAtLoginItem = NSMenuItem(
        title: "Launch at Login",
        action: #selector(toggleLaunchAtLogin),
        keyEquivalent: ""
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        remainingItem.isEnabled = false
        launchAtLoginItem.target = self
        let quitItem = NSMenuItem(
            title: "Quit HourPie",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        menu.addItem(remainingItem)
        menu.addItem(.separator())
        menu.addItem(launchAtLoginItem)
        menu.addItem(.separator())
        menu.addItem(quitItem)
        menu.delegate = self
        statusItem.menu = menu

        tick()
        let timer = Timer(timeInterval: 1.0, repeats: true) { _ in
            DispatchQueue.main.async { [weak self] in self?.tick() }
        }
        // .common so the icon keeps updating while menus are open
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer

        // Recompute immediately when the Mac wakes from sleep
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { _ in
            DispatchQueue.main.async { [weak self] in self?.tick() }
        }
    }

    // MARK: - Clock

    private func secondsLeftInHour(now: Date = Date()) -> Int {
        let parts = Calendar.current.dateComponents([.minute, .second], from: now)
        return 3600 - ((parts.minute ?? 0) * 60 + (parts.second ?? 0))
    }

    private func tick() {
        let remaining = secondsLeftInHour()
        let fraction = Double(remaining) / 3600.0
        statusItem.button?.image = Self.pieImage(fraction: fraction)

        let minutes = remaining / 60
        let seconds = remaining % 60
        statusItem.button?.toolTip = String(
            format: "%d:%02d left this hour", minutes, seconds
        )
    }

    // MARK: - Drawing

    /// A pie wedge for the remaining fraction of the hour, drawn clockwise
    /// from 12 o'clock inside a thin outline ring. Rendered as a template
    /// image so the menu bar tints it for light/dark mode automatically.
    static func pieImage(fraction: Double) -> NSImage {
        let side: CGFloat = 18
        let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            let center = NSPoint(x: rect.midX, y: rect.midY)
            let radius = rect.width / 2 - 1.5

            let ring = NSBezierPath(
                ovalIn: NSRect(
                    x: center.x - radius, y: center.y - radius,
                    width: radius * 2, height: radius * 2
                )
            )
            ring.lineWidth = 1.5
            NSColor.black.withAlphaComponent(0.9).setStroke()
            ring.stroke()

            let clamped = max(0, min(1, fraction))
            if clamped > 0.0005 {
                let wedge = NSBezierPath()
                let inner = radius - 2.5
                wedge.move(to: center)
                // AppKit angles are counterclockwise; sweep clockwise from
                // 12 o'clock (90°) so the pie drains like a Time Timer.
                wedge.appendArc(
                    withCenter: center, radius: inner,
                    startAngle: 90, endAngle: 90 - 360 * clamped,
                    clockwise: true
                )
                wedge.close()
                NSColor.black.setFill()
                wedge.fill()
            }
            return true
        }
        image.isTemplate = true
        return image
    }

    // MARK: - Menu

    func menuWillOpen(_ menu: NSMenu) {
        let remaining = secondsLeftInHour()
        remainingItem.title = String(
            format: "%d:%02d left this hour", remaining / 60, remaining % 60
        )
        launchAtLoginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSLog("Launch at login toggle failed: \(error)")
        }
    }
}

@main
struct HourPieApp {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}
