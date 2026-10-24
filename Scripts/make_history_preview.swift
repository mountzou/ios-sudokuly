import AppKit

// Compose captured simulator screens for review; these are not design mockups.
let image = NSImage(size: NSSize(width: 1300, height: 960))
image.lockFocus()
NSColor(calibratedWhite: 0.91, alpha: 1).setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: 1300, height: 960)).fill()
let screens = [("history-samples", "01  /  YOUR HISTORY"),
               ("history-detail-1", "02  /  GAME RECAP"),
               ("history-empty", "03  /  A FRESH PAGE")]
for (index, screen) in screens.enumerated() {
    let x = CGFloat(37 + index * 418)
    let screenshot = NSImage(contentsOfFile: "Verification/history/\(screen.0).png")!
    screenshot.draw(in: NSRect(x: x, y: 66, width: 390, height: 844))
    NSString(string: screen.1).draw(at: NSPoint(x: x, y: 28), withAttributes: [
        .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
        .foregroundColor: NSColor(calibratedWhite: 0.24, alpha: 1),
        .kern: 1.3
    ])
}
image.unlockFocus()
let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "Verification/history/preview.png"))
