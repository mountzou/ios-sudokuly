import SwiftUI

/// Sizes the illustration to three fifths of the upper half of the content viewport.
/// Fixed navigation and footer regions stay outside the viewport supplied by the caller.
struct IllustratedViewportLayout: Layout {
    let viewportHeight: CGFloat
    var maximumWidth: CGFloat = 470
    var horizontalInset: CGFloat = 28
    var illustrationSpacing: CGFloat = 25
    var bottomInset: CGFloat = 28

    private func contentWidth(_ width: CGFloat) -> CGFloat {
        max(0, min(maximumWidth, width) - horizontalInset * 2)
    }

    private func illustrationSize(_ width: CGFloat) -> CGFloat {
        min(contentWidth(width), viewportHeight * 0.5 * 3 / 5)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 390
        let content = subviews[1].sizeThatFits(.init(width: contentWidth(width), height: nil))
        let minimumHeight = viewportHeight * 0.5 + illustrationSpacing + content.height + bottomInset
        return CGSize(width: width, height: max(viewportHeight, minimumHeight))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let size = illustrationSize(bounds.width)
        let midpoint = bounds.minY + viewportHeight * 0.5
        subviews[0].place(at: CGPoint(x: bounds.midX, y: midpoint), anchor: .bottom,
                          proposal: .init(width: size, height: size))
        subviews[1].place(at: CGPoint(x: bounds.midX, y: midpoint + illustrationSpacing), anchor: .top,
                          proposal: .init(width: contentWidth(bounds.width), height: nil))
    }
}
