import AppKit
import CoreText

let size = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()
NSColor.white.setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: size, height: size)).fill()
let side: CGFloat = 135
let gap: CGFloat = 30
let start: CGFloat = (1024 - side * 3 - gap * 2) / 2
for row in 0..<3 {
    for column in 0..<3 {
        let muted = row == 0 && column == 2 || row == 2 && column == 0
        NSColor(calibratedWhite: muted ? 0.77 : 0.12, alpha: 1).setFill()
        let rect = NSRect(x: start + CGFloat(column) * (side + gap), y: start + CGFloat(2 - row) * (side + gap), width: side, height: side)
        NSBezierPath(roundedRect: rect, xRadius: 23, yRadius: 23).fill()
    }
}
image.unlockFocus()
let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "Sudokuly/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png"))
let fonts = CTFontManagerCreateFontDescriptorsFromURL(URL(fileURLWithPath: "Sudokuly/Resources/Fonts/ClarityCity-Variable.ttf") as CFURL) as! [CTFontDescriptor]
for descriptor in fonts {
    print("Bundled font:", CTFontDescriptorCopyAttribute(descriptor, kCTFontNameAttribute)!)
}
