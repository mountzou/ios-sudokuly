import AppKit

// Compose actual simulator screenshots into a review sheet; no UI mockups.
let image = NSImage(size: NSSize(width: 1300, height: 960))
image.lockFocus()
NSColor(calibratedWhite: 0.91, alpha: 1).setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: 1300, height: 960)).fill()
let names = [("home", "01  /  CHOOSE YOUR PACE"), ("game", "02  /  FIND YOUR FLOW"), ("result-won", "03  /  A LITTLE WIN")]
for (index, entry) in names.enumerated() {
    let x = CGFloat(37 + index * 418)
    let screenshot = NSImage(contentsOfFile: "Verification/\(entry.0).png")!
    screenshot.draw(in: NSRect(x: x, y: 66, width: 390, height: 844))
    let label = NSString(string: entry.1)
    label.draw(at: NSPoint(x: x, y: 28), withAttributes: [
        .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
        .foregroundColor: NSColor(calibratedWhite: 0.24, alpha: 1),
        .kern: 1.3
    ])
}
image.unlockFocus()
let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "Verification/preview.png"))
