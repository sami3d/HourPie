import AppKit

// HourPie app icon: white macOS squircle, clock face ticks, red pie at 75%
let S: CGFloat = 1024
let image = NSImage(size: NSSize(width: S, height: S), flipped: false) { _ in
    let ctx = NSGraphicsContext.current!.cgContext

    // Squircle background with soft drop shadow (macOS style: 100px margins)
    let bgRect = NSRect(x: 100, y: 100, width: 824, height: 824)
    let squircle = NSBezierPath(roundedRect: bgRect, xRadius: 185, yRadius: 185)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 24,
                  color: NSColor.black.withAlphaComponent(0.3).cgColor)
    NSColor.white.setFill()
    squircle.fill()
    ctx.restoreGState()

    // Subtle vertical gradient on the face
    ctx.saveGState()
    squircle.addClip()
    let gradient = NSGradient(
        starting: NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 1),
        ending: NSColor(srgbRed: 0.93, green: 0.93, blue: 0.945, alpha: 1)
    )!
    gradient.draw(in: bgRect, angle: -90)
    ctx.restoreGState()

    let center = NSPoint(x: S/2, y: S/2)
    let red = NSColor(srgbRed: 0.886, green: 0.153, blue: 0.145, alpha: 1)
    let dark = NSColor(srgbRed: 0.12, green: 0.12, blue: 0.13, alpha: 1)

    // Minute tick marks — long at the 5-minute positions, short between
    for i in 0..<60 {
        let angle = CGFloat(90) - CGFloat(i) * 6
        let rad = angle * .pi / 180
        let major = i % 5 == 0
        let outer: CGFloat = 344
        let inner: CGFloat = major ? 306 : 326
        let tick = NSBezierPath()
        tick.move(to: NSPoint(x: center.x + cos(rad) * inner, y: center.y + sin(rad) * inner))
        tick.line(to: NSPoint(x: center.x + cos(rad) * outer, y: center.y + sin(rad) * outer))
        tick.lineWidth = major ? 14 : 7
        tick.lineCapStyle = .round
        dark.withAlphaComponent(major ? 0.85 : 0.4).setStroke()
        tick.stroke()
    }

    // Red pie: 75% remaining, draining clockwise (empty quarter from 12 to 3)
    let fraction: CGFloat = 0.75
    let wedge = NSBezierPath()
    wedge.move(to: center)
    wedge.appendArc(withCenter: center, radius: 282,
                    startAngle: 90, endAngle: 90 + 360 * fraction, clockwise: false)
    wedge.close()
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -6), blur: 18,
                  color: NSColor.black.withAlphaComponent(0.25).cgColor)
    red.setFill()
    wedge.fill()
    ctx.restoreGState()

    // Center knob, like the Time Timer's
    let knob = NSBezierPath(ovalIn: NSRect(x: center.x - 52, y: center.y - 52, width: 104, height: 104))
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -4), blur: 10,
                  color: NSColor.black.withAlphaComponent(0.35).cgColor)
    NSColor.white.setFill()
    knob.fill()
    ctx.restoreGState()

    return true
}

let png = NSBitmapImageRep(data: image.tiffRepresentation!)!.representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: "icon_1024.png"))
print("written")
