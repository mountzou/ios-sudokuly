import SwiftUI
import UIKit

/// Adapted from Flytly's loader, based on beUI's MIT-licensed Loader motion reference.
/// See Resources/Licenses/beUI.txt.
struct MetaballLoadingView: UIViewRepresentable {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    func makeUIView(context: Context) -> MetaballLayerView { MetaballLayerView() }

    func updateUIView(_ view: MetaballLayerView, context: Context) {
        view.configure(reduceMotion: reduceMotion, active: scenePhase == .active)
    }
}

final class MetaballLayerView: UIView {
    private let ink = CALayer()
    private let silhouette = CALayer()
    private var configuration: (reduced: Bool, active: Bool)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        ink.mask = silhouette
        layer.addSublayer(ink)
        ink.backgroundColor = UIColor(Palette.ink).cgColor
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        ink.frame = bounds
        silhouette.frame = ink.bounds
        CATransaction.commit()
    }

    func configure(reduceMotion: Bool, active: Bool) {
        guard configuration?.reduced != reduceMotion || configuration?.active != active else { return }
        configuration = (reduceMotion, active)
        silhouette.removeAllAnimations()
        ink.removeAllAnimations()
        silhouette.contents = MetaballFrames.still
        guard active else { return }
        if reduceMotion {
            let pulse = CABasicAnimation(keyPath: "opacity")
            pulse.fromValue = 0.4
            pulse.toValue = 1
            pulse.duration = 0.8
            pulse.autoreverses = true
            pulse.repeatCount = .infinity
            ink.add(pulse, forKey: "pulse")
        } else {
            // Render the cached cycle off the main thread so authentication can finish promptly.
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                let frames = MetaballFrames.images
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.configuration?.active == true,
                          self.configuration?.reduced == false else { return }
                    let motion = CAKeyframeAnimation(keyPath: "contents")
                    motion.values = frames
                    motion.duration = 1.6
                    motion.calculationMode = .discrete
                    motion.repeatCount = .infinity
                    self.silhouette.add(motion, forKey: "metaballs")
                }
            }
        }
    }
}

private enum MetaballFrames {
    static let still = image(frame: 12)
    // One cached 60 fps cycle, rendered at 3x for a 32-point loader.
    static let images: [CGImage] = (0..<96).map { image(frame: $0) }

    private static func image(frame: Int) -> CGImage {
        let phase = Double(frame) / 48
        let curve = UnitCurve.bezier(startControlPoint: UnitPoint(x: 0.77, y: 0),
                                    endControlPoint: UnitPoint(x: 0.175, y: 1))
        let progress = phase < 1 ? curve.value(at: phase) : 1 - curve.value(at: phase - 1)
        let side = 96
        let offset = Double(side) * 0.27125 * (1 - 2 * progress)
        let radius = Double(side) * 0.15
        let sigma = Double(side) * 0.05
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        for y in 0..<side {
            for x in 0..<side {
                let dx = Double(x) + 0.5 - Double(side) / 2
                let dy = Double(y) + 0.5 - Double(side) / 2
                let first = 0.5 * erfc((hypot(dx - offset, dy) - radius) / (sigma * sqrt(2)))
                let second = 0.5 * erfc((hypot(dx + offset, dy) - radius) / (sigma * sqrt(2)))
                let alpha = UInt8(min(1, max(0, (first + second) * 20 - 8)) * 255)
                let index = (y * side + x) * 4
                for component in 0..<4 { pixels[index + component] = alpha }
            }
        }
        let provider = CGDataProvider(data: Data(pixels) as CFData)!
        return CGImage(width: side, height: side, bitsPerComponent: 8, bitsPerPixel: 32,
                       bytesPerRow: side * 4, space: CGColorSpaceCreateDeviceRGB(),
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)!
    }
}
