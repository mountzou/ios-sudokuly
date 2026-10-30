import AppKit
import Foundation

// Export the existing code-drawn icon, without changing the bundled AppIcon.
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let output = root.appendingPathComponent(CommandLine.arguments.dropFirst().first ?? "Design/IconComposer/sudokuly-v1")
let sourceURL = root.appendingPathComponent("Sudokuly/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
let source = NSBitmapImageRep(data: try Data(contentsOf: sourceURL))!
let size = 1024
let side: CGFloat = 135
let gap: CGFloat = 30
let radius: CGFloat = 23
let start: CGFloat = (CGFloat(size) - side * 3 - gap * 2) / 2
let background = NSColor.white
let dark = NSColor(calibratedWhite: 0.12, alpha: 1)
let muted = NSColor(calibratedWhite: 0.77, alpha: 1)
let bounds = NSRect(x: 0, y: 0, width: size, height: size)

for directory in ["SVG", "PNG", "Reference"] {
    try FileManager.default.createDirectory(at: output.appendingPathComponent(directory), withIntermediateDirectories: true)
}

func isMuted(_ row: Int, _ column: Int) -> Bool {
    (row == 0 && column == 2) || (row == 2 && column == 0)
}

func tilePath(_ row: Int, _ column: Int) -> NSBezierPath {
    let rect = NSRect(x: start + CGFloat(column) * (side + gap),
                      y: start + CGFloat(2 - row) * (side + gap), width: side, height: side)
    return NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}

func render(_ drawing: () -> Void) -> NSBitmapImageRep {
    let image = NSImage(size: bounds.size)
    image.lockFocus()
    NSColor.clear.setFill()
    bounds.fill(using: .copy)
    drawing()
    image.unlockFocus()
    return NSBitmapImageRep(data: image.tiffRepresentation!)!
}

func drawBackground() {
    background.setFill()
    NSBezierPath(rect: bounds).fill()
}

func drawTiles(mutedOnly: Bool? = nil) {
    for row in 0..<3 {
        for column in 0..<3 {
            let light = isMuted(row, column)
            if let selected = mutedOnly, selected != light { continue }
            (light ? muted : dark).setFill()
            tilePath(row, column).fill()
        }
    }
}

func writePNG(_ bitmap: NSBitmapImageRep, _ relative: String) throws {
    precondition(bitmap.pixelsWide == size && bitmap.pixelsHigh == size)
    try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent(relative))
}

// Use the actual source palette, avoiding calibrated-color conversion in SVG readers.
func sourceHex(_ x: Int, _ y: Int) -> String {
    precondition(source.bitsPerPixel == 32 && source.samplesPerPixel == 4 && !source.isPlanar)
    let offset = y * source.bytesPerRow + x * 4
    let p = source.bitmapData! + offset
    return String(format: "#%02X%02X%02X", p[0], p[1], p[2])
}

func number(_ n: CGFloat) -> String { String(format: "%.8g", Double(n)) }
func point(_ p: NSPoint) -> String { "\(number(p.x)) \(number(1024 - p.y))" }

// Export AppKit's actual Bezier control points rather than approximating the corners.
func svgPath(_ path: NSBezierPath) -> String {
    var result: [String] = []
    let points = UnsafeMutablePointer<NSPoint>.allocate(capacity: 3)
    defer { points.deallocate() }
    for index in 0..<path.elementCount {
        switch path.element(at: index, associatedPoints: points) {
        case .moveTo: result.append("M \(point(points[0]))")
        case .lineTo: result.append("L \(point(points[0]))")
        case .curveTo: result.append("C \(point(points[0])) \(point(points[1])) \(point(points[2]))")
        case .closePath: result.append("Z")
        default: preconditionFailure("Unexpected path element")
        }
    }
    return result.joined(separator: " ")
}

func writeSVG(_ name: String, _ mutedOnly: Bool) throws {
    let hex = mutedOnly ? sourceHex(650, 300) : sourceHex(300, 300)
    var paths: [String] = []
    for row in 0..<3 {
        for column in 0..<3 where isMuted(row, column) == mutedOnly {
            paths.append("  <path d=\"\(svgPath(tilePath(row, column)))\" fill=\"\(hex)\"/>")
        }
    }
    let svg = """
    <svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
    \(paths.joined(separator: "\n"))
    </svg>

    """
    try svg.write(to: output.appendingPathComponent("SVG/\(name).svg"), atomically: true, encoding: .utf8)
}

let bg = render { drawBackground() }
let darkLayer = render { drawTiles(mutedOnly: false) }
let mutedLayer = render { drawTiles(mutedOnly: true) }
let flat = render { drawBackground(); drawTiles() }
let recomposed = render {
    for bitmap in [bg, darkLayer, mutedLayer] {
        NSImage(cgImage: bitmap.cgImage!, size: bounds.size).draw(in: bounds)
    }
}

try writePNG(bg, "Reference/00-background.png")
try writePNG(darkLayer, "PNG/01-dark-tiles.png")
try writePNG(mutedLayer, "PNG/02-light-tiles.png")
try writePNG(recomposed, "Reference/recomposed-flat.png")
try Data(contentsOf: sourceURL).write(to: output.appendingPathComponent("Reference/original-app-icon.png"))
try writeSVG("01-dark-tiles", false)
try writeSVG("02-light-tiles", true)

func compare(_ lhs: NSBitmapImageRep, _ rhs: NSBitmapImageRep) -> [String: Int] {
    precondition(lhs.pixelsWide == size && rhs.pixelsWide == size)
    precondition(lhs.pixelsHigh == size && rhs.pixelsHigh == size)
    precondition(lhs.samplesPerPixel == 4 && rhs.samplesPerPixel == 4)
    var changed = 0
    var maximum = 0
    for y in 0..<size {
        for x in 0..<size {
            var pixelChanged = false
            for c in 0..<4 {
                let a = Int(lhs.bitmapData![y * lhs.bytesPerRow + x * 4 + c])
                let b = Int(rhs.bitmapData![y * rhs.bytesPerRow + x * 4 + c])
                let delta = abs(a - b)
                maximum = max(maximum, delta)
                pixelChanged = pixelChanged || delta > 0
            }
            if pixelChanged { changed += 1 }
        }
    }
    return ["changedPixels": changed, "maximumChannelDifferenceOutOf255": maximum]
}

let flatCheck = compare(source, flat)
let compositeCheck = compare(source, recomposed)
// Fail if geometry/palette has drifted. One level allows 8-bit alpha rounding.
precondition(flatCheck["maximumChannelDifferenceOutOf255"]! <= 1, "Source geometry or palette drifted")
precondition(compositeCheck["maximumChannelDifferenceOutOf255"]! <= 1, "Layer composition drifted")
let manifest: [String: Any] = [
    "source": sourceURL.path,
    "canvas": ["width": size, "height": size],
    "backgroundSRGB": sourceHex(0, 0),
    "darkSRGB": sourceHex(300, 300),
    "lightSRGB": sourceHex(650, 300),
    "tileSize": Int(side), "gap": Int(gap), "cornerRadius": Int(radius), "outerMargin": Double(start),
    "foregroundLayers": ["SVG/01-dark-tiles.svg", "SVG/02-light-tiles.svg"],
    "sourceRedrawComparison": flatCheck,
    "pngRecompositionComparison": compositeCheck,
    "note": "Flat source layers only. Liquid Glass effects are configured in Icon Composer."
]
try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys])
    .write(to: output.appendingPathComponent("manifest.json"))
print("Exported: \(output.path)")
print("Source redraw: \(flatCheck)")
print("PNG recomposition: \(compositeCheck)")
