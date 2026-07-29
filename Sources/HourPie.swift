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
        title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: ""
    )
    private let clockwiseItem = NSMenuItem(
        title: "Clockwise", action: #selector(setClockwise), keyEquivalent: ""
    )
    private let anticlockwiseItem = NSMenuItem(
        title: "Anti-clockwise", action: #selector(setAnticlockwise), keyEquivalent: ""
    )
    private let borderItem = NSMenuItem(
        title: "Show Border", action: #selector(toggleBorder), keyEquivalent: ""
    )
    private let timeLabelItem = NSMenuItem(
        title: "Show Time", action: #selector(toggleTimeLabel), keyEquivalent: ""
    )
    private var colorItems: [NSMenuItem] = []
    private let customColorItem = NSMenuItem(
        title: "Custom…", action: #selector(pickCustomColor), keyEquivalent: ""
    )

    // MARK: - Settings (persisted in UserDefaults)

    private enum Keys {
        static let clockwise = "drainsClockwise"
        static let border = "showsBorder"
        static let color = "pieColorRGB"
        static let timeLabel = "showsTimeLabel"
    }

    static let presetColors: [(name: String, color: NSColor)] = [
        ("Red", .systemRed),
        ("White", .white),
        ("Blue", .systemBlue),
        ("Green", .systemGreen),
    ]

    private var drainsClockwise: Bool {
        get { UserDefaults.standard.object(forKey: Keys.clockwise) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: Keys.clockwise); tick() }
    }

    private var showsBorder: Bool {
        get { UserDefaults.standard.object(forKey: Keys.border) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: Keys.border); tick() }
    }

    private var showsTimeLabel: Bool {
        get { UserDefaults.standard.object(forKey: Keys.timeLabel) as? Bool ?? false }
        set { UserDefaults.standard.set(newValue, forKey: Keys.timeLabel); tick() }
    }

    private var pieColor: NSColor {
        get {
            guard let rgb = UserDefaults.standard.array(forKey: Keys.color) as? [Double],
                  rgb.count == 3
            else { return .systemRed }
            return NSColor(srgbRed: rgb[0], green: rgb[1], blue: rgb[2], alpha: 1)
        }
        set {
            let c = newValue.usingColorSpace(.sRGB) ?? .systemRed
            UserDefaults.standard.set(
                [c.redComponent, c.greenComponent, c.blueComponent], forKey: Keys.color
            )
            tick()
        }
    }

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        remainingItem.isEnabled = false
        launchAtLoginItem.target = self
        clockwiseItem.target = self
        anticlockwiseItem.target = self
        borderItem.target = self
        customColorItem.target = self

        let directionMenu = NSMenu()
        directionMenu.addItem(clockwiseItem)
        directionMenu.addItem(anticlockwiseItem)
        let directionItem = NSMenuItem(title: "Direction", action: nil, keyEquivalent: "")
        directionItem.submenu = directionMenu

        let colorMenu = NSMenu()
        for (index, preset) in Self.presetColors.enumerated() {
            let item = NSMenuItem(
                title: preset.name, action: #selector(setPresetColor(_:)), keyEquivalent: ""
            )
            item.target = self
            item.tag = index
            item.image = Self.swatchImage(color: preset.color)
            colorMenu.addItem(item)
            colorItems.append(item)
        }
        colorMenu.addItem(.separator())
        colorMenu.addItem(customColorItem)
        let colorItem = NSMenuItem(title: "Colour", action: nil, keyEquivalent: "")
        colorItem.submenu = colorMenu

        let settingsMenu = NSMenu()
        timeLabelItem.target = self
        settingsMenu.addItem(directionItem)
        settingsMenu.addItem(colorItem)
        settingsMenu.addItem(borderItem)
        settingsMenu.addItem(timeLabelItem)
        let settingsItem = NSMenuItem(title: "Settings", action: nil, keyEquivalent: "")
        settingsItem.submenu = settingsMenu

        let quitItem = NSMenuItem(
            title: "Quit HourPie", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"
        )
        menu.addItem(remainingItem)
        menu.addItem(.separator())
        menu.addItem(settingsItem)
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
        statusItem.button?.image = Self.pieImage(
            fraction: fraction,
            clockwise: drainsClockwise,
            color: pieColor,
            border: showsBorder
        )
        if showsTimeLabel, let button = statusItem.button {
            button.imagePosition = .imageLeft
            // Same face, size, and weight as the system menu bar clock,
            // with monospaced digits so the label doesn't jitter every second
            button.attributedTitle = NSAttributedString(
                string: String(format: " %d:%02d", remaining / 60, remaining % 60),
                attributes: [
                    .font: NSFont.monospacedDigitSystemFont(
                        ofSize: NSFont.menuBarFont(ofSize: 0).pointSize, weight: .regular
                    ),
                ]
            )
        } else {
            statusItem.button?.imagePosition = .imageOnly
            statusItem.button?.title = ""
        }
        statusItem.button?.toolTip = String(
            format: "%d:%02d left this hour", remaining / 60, remaining % 60
        )
    }

    // MARK: - Drawing

    /// A pie wedge for the remaining fraction of the hour. The wedge is the
    /// time left; the empty region is the time gone, growing from 12 o'clock
    /// in the chosen direction. Drawn in `color` with an optional outline
    /// ring. White gets a hairline contrast stroke so it stays visible on
    /// light menu bars even with the border off.
    static func pieImage(
        fraction: Double, clockwise: Bool, color: NSColor, border: Bool
    ) -> NSImage {
        let side: CGFloat = 18
        let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            let center = NSPoint(x: rect.midX, y: rect.midY)
            let radius = rect.width / 2 - 1.5

            if border {
                let ring = NSBezierPath(
                    ovalIn: NSRect(
                        x: center.x - radius, y: center.y - radius,
                        width: radius * 2, height: radius * 2
                    )
                )
                ring.lineWidth = 1.5
                color.setStroke()
                ring.stroke()
            }

            let clamped = max(0, min(1, fraction))
            if clamped > 0.0005 {
                let wedge = NSBezierPath()
                let inner = border ? radius - 2.5 : radius
                wedge.move(to: center)
                // AppKit angles run counterclockwise from 3 o'clock; the
                // wedge is anchored at 12 o'clock (90°). Sweeping the arc
                // clockwise makes the empty region grow anticlockwise, and
                // vice versa.
                if clockwise {
                    wedge.appendArc(
                        withCenter: center, radius: inner,
                        startAngle: 90, endAngle: 90 + 360 * clamped,
                        clockwise: false
                    )
                } else {
                    wedge.appendArc(
                        withCenter: center, radius: inner,
                        startAngle: 90, endAngle: 90 - 360 * clamped,
                        clockwise: true
                    )
                }
                wedge.close()
                color.setFill()
                wedge.fill()
                if isNearWhite(color) {
                    wedge.lineWidth = 0.5
                    NSColor.black.withAlphaComponent(0.35).setStroke()
                    wedge.stroke()
                }
            }
            return true
        }
        image.isTemplate = false
        return image
    }

    private static func isNearWhite(_ color: NSColor) -> Bool {
        guard let c = color.usingColorSpace(.sRGB) else { return false }
        return c.redComponent > 0.9 && c.greenComponent > 0.9 && c.blueComponent > 0.9
    }

    static func swatchImage(color: NSColor) -> NSImage {
        let image = NSImage(size: NSSize(width: 14, height: 14), flipped: false) { rect in
            let circle = NSBezierPath(ovalIn: rect.insetBy(dx: 1, dy: 1))
            color.setFill()
            circle.fill()
            NSColor.black.withAlphaComponent(0.25).setStroke()
            circle.lineWidth = 0.5
            circle.stroke()
            return true
        }
        return image
    }

    // MARK: - Menu

    func menuWillOpen(_ menu: NSMenu) {
        let remaining = secondsLeftInHour()
        remainingItem.title = String(
            format: "%d:%02d left this hour", remaining / 60, remaining % 60
        )
        launchAtLoginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        clockwiseItem.state = drainsClockwise ? .on : .off
        anticlockwiseItem.state = drainsClockwise ? .off : .on
        borderItem.state = showsBorder ? .on : .off
        timeLabelItem.state = showsTimeLabel ? .on : .off

        let current = pieColor.usingColorSpace(.sRGB)
        var matchedPreset = false
        for (index, item) in colorItems.enumerated() {
            let preset = Self.presetColors[index].color.usingColorSpace(.sRGB)
            let matches: Bool
            if let a = current, let b = preset {
                matches = abs(a.redComponent - b.redComponent) < 0.01
                    && abs(a.greenComponent - b.greenComponent) < 0.01
                    && abs(a.blueComponent - b.blueComponent) < 0.01
            } else {
                matches = false
            }
            item.state = matches ? .on : .off
            if matches { matchedPreset = true }
        }
        customColorItem.state = matchedPreset ? .off : .on
        customColorItem.image = matchedPreset ? nil : Self.swatchImage(color: pieColor)
    }

    @objc private func setClockwise() { drainsClockwise = true }
    @objc private func setAnticlockwise() { drainsClockwise = false }
    @objc private func toggleBorder() { showsBorder.toggle() }
    @objc private func toggleTimeLabel() { showsTimeLabel.toggle() }

    @objc private func setPresetColor(_ sender: NSMenuItem) {
        pieColor = Self.presetColors[sender.tag].color
    }

    @objc private func pickCustomColor() {
        let panel = NSColorPanel.shared
        panel.showsAlpha = false
        panel.color = pieColor
        panel.setTarget(self)
        panel.setAction(#selector(customColorChanged(_:)))
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    @objc private func customColorChanged(_ sender: NSColorPanel) {
        pieColor = sender.color
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
