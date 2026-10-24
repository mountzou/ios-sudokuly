import Foundation

/// The committed date never depends on an animation completion callback.
struct ActivityDatePicker {
    enum Axis { case undecided, horizontal, vertical }

    private(set) var day: Date
    private(set) var offset: Double = 0
    private(set) var isDragging = false
    private(set) var axis: Axis = .undecided

    init(day: Date) { self.day = day }

    mutating func beginHorizontalDrag() {
        // UIKit may report zero translation when a recognized pan first begins.
        isDragging = true
        axis = .horizontal
        offset = 0
    }

    mutating func drag(x: Double, y: Double, spacing: Double, calendar: Calendar, bounds: ClosedRange<Date>) {
        guard x.isFinite, y.isFinite, spacing.isFinite, spacing > 0 else { return }
        if !isDragging {
            isDragging = true
            axis = .undecided
            offset = 0
        }
        // Lock the axis once, so a slightly diagonal lift cannot undo a horizontal swipe.
        if axis == .undecided { axis = abs(x) > abs(y) ? .horizontal : .vertical }
        guard axis == .horizontal else { return }
        let neighbor = calendar.date(byAdding: .day, value: x > 0 ? -1 : 1, to: day) ?? day
        offset = bounds.contains(neighbor) ? min(spacing, max(-spacing, x)) : 0
    }

    mutating func endDrag(x: Double, predicted: Double, spacing: Double,
                          calendar: Calendar, bounds: ClosedRange<Date>) {
        guard isDragging else { return }
        let step = axis == .horizontal ? DailyActivity.pickerStep(translation: x, predicted: predicted, spacing: spacing) : 0
        let destination = calendar.date(byAdding: .day, value: step, to: day) ?? day
        if bounds.contains(destination) {
            day = destination
            // Rebase the cells without moving their current on-screen positions.
            offset += Double(step) * spacing
        }
        isDragging = false
        axis = .undecided
    }

    mutating func settle() { offset = 0 }

    mutating func cancelDrag() {
        isDragging = false
        axis = .undecided
        offset = 0
    }

    mutating func center(_ day: Date, bounds: ClosedRange<Date>) {
        guard bounds.contains(day) else { return }
        self.day = day
        cancelDrag()
    }
}
