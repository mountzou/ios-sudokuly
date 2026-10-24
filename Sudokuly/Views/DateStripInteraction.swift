import SwiftUI
import UIKit

/// Resolve direction before recognizing a pan, so the surrounding ScrollView keeps vertical drags.
struct DateStripInteraction: UIViewRepresentable {
    let began: () -> Void
    let changed: (CGSize) -> Void
    let ended: (CGSize, CGFloat) -> Void
    let cancelled: () -> Void
    let tapped: (CGFloat) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isAccessibilityElement = false
        view.accessibilityElementsHidden = true
        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.pan(_:)))
        pan.maximumNumberOfTouches = 1
        pan.delegate = context.coordinator
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tap(_:)))
        tap.require(toFail: pan)
        view.addGestureRecognizer(pan)
        view.addGestureRecognizer(tap)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) { context.coordinator.parent = self }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var parent: DateStripInteraction
        init(_ parent: DateStripInteraction) { self.parent = parent }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return true }
            let velocity = pan.velocity(in: pan.view)
            let direction = velocity == .zero ? pan.translation(in: pan.view) : velocity
            return abs(direction.x) > abs(direction.y)
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            gestureRecognizer is UIPanGestureRecognizer && otherGestureRecognizer.view is UIScrollView
        }

        @objc func pan(_ recognizer: UIPanGestureRecognizer) {
            let translation = recognizer.translation(in: recognizer.view)
            let size = CGSize(width: translation.x, height: translation.y)
            switch recognizer.state {
            case .began:
                parent.began()
                parent.changed(size)
            case .changed: parent.changed(size)
            case .ended:
                let predicted = translation.x + recognizer.velocity(in: recognizer.view).x * 0.12
                parent.ended(size, predicted)
            case .cancelled, .failed: parent.cancelled()
            default: break
            }
        }

        @objc func tap(_ recognizer: UITapGestureRecognizer) {
            guard recognizer.state == .ended else { return }
            parent.tapped(recognizer.location(in: recognizer.view).x)
        }
    }
}
