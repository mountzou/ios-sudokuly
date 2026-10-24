import SwiftUI

/// Shared rendering for the app's outline icons, using the supplied 24 × 24 SVG paths.
struct AppSymbol: View {
    let symbol: String
    let size: CGFloat
    var weight: Font.Weight = .regular

    var body: some View {
        if let outline = OutlineSymbol(systemName: symbol) {
            outline
                .stroke(style: StrokeStyle(lineWidth: size * 1.5 / 24, lineCap: .round, lineJoin: .round))
                .frame(width: size, height: size)
                .accessibilityHidden(true)
        } else {
            Image(systemName: symbol)
                .font(.system(size: size, weight: weight))
        }
    }
}

private enum OutlineSymbol: Shape {
    case pause, close, play

    init?(systemName: String) {
        switch systemName {
        case "pause", "pause.fill", "pause.circle", "pause.circle.fill": self = .pause
        case "xmark", "xmark.circle", "xmark.circle.fill": self = .close
        case "play", "play.fill", "play.circle", "play.circle.fill": self = .play
        default: return nil
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        switch self {
        case .pause:
            path.move(to: CGPoint(x: 15.75, y: 5.25))
            path.addLine(to: CGPoint(x: 15.75, y: 18.75))
            path.move(to: CGPoint(x: 8.25, y: 5.25))
            path.addLine(to: CGPoint(x: 8.25, y: 18.75))
        case .close:
            path.move(to: CGPoint(x: 6, y: 18))
            path.addLine(to: CGPoint(x: 18, y: 6))
            path.move(to: CGPoint(x: 6, y: 6))
            path.addLine(to: CGPoint(x: 18, y: 18))
        case .play:
            path.move(to: CGPoint(x: 5.25, y: 5.653))
            path.addCurve(to: CGPoint(x: 6.917, y: 4.667),
                          control1: CGPoint(x: 5.25, y: 4.797),
                          control2: CGPoint(x: 6.167, y: 4.255))
            path.addLine(to: CGPoint(x: 18.457, y: 11.014))
            addSVGArc(to: CGPoint(x: 18.457, y: 12.986), radius: 1.125, path: &path)
            path.addLine(to: CGPoint(x: 6.917, y: 19.333))
            addSVGArc(to: CGPoint(x: 5.25, y: 18.347), radius: 1.125, path: &path)
            path.addLine(to: CGPoint(x: 5.25, y: 5.653))
            path.closeSubpath()
        }
        let scale = min(rect.width, rect.height) / 24
        return path.applying(CGAffineTransform(a: scale, b: 0, c: 0, d: scale,
                                              tx: rect.midX - 12 * scale, ty: rect.midY - 12 * scale))
    }

    /// The play SVG's circular arcs both use large-arc=0 and sweep=1.
    private func addSVGArc(to end: CGPoint, radius: CGFloat, path: inout Path) {
        guard let start = path.currentPoint else { return }
        let dx = end.x - start.x
        let dy = end.y - start.y
        let distance = hypot(dx, dy)
        let offset = sqrt(radius * radius - distance * distance / 4) / distance
        let center = CGPoint(x: (start.x + end.x) / 2 - dy * offset,
                             y: (start.y + end.y) / 2 + dx * offset)
        path.addArc(center: center, radius: radius,
                    startAngle: .radians(Double(atan2(start.y - center.y, start.x - center.x))),
                    endAngle: .radians(Double(atan2(end.y - center.y, end.x - center.x))),
                    clockwise: false)
    }
}
