import SwiftUI

struct SudokuBoard: View {
    let session: GameSession
    let select: (Int) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var mistakeTriggers = [Int](repeating: 0, count: 81)

    var body: some View {
        GeometryReader { geometry in
            let side = geometry.size.width / 9
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(side), spacing: 0), count: 9), spacing: 0) {
                ForEach(0..<81, id: \.self) { index in
                    let shouldAnimateMistake = !reduceMotion && isIncorrect(index)
                    Button { select(index) } label: {
                        ZStack {
                            background(for: index)
                            ZStack {
                                if session.board[index] != 0 {
                                    Text(String(session.board[index]))
                                        .font(AppFont.text(side * 0.57, weight: session.puzzle.givens[index] != 0 ? .semibold : .medium, scaled: false))
                                        .foregroundStyle(foreground(for: index))
                                } else if !session.notes[index].isEmpty {
                                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 3), spacing: 0) {
                                        ForEach(1...9, id: \.self) { digit in
                                            Text(session.notes[index].contains(digit) ? String(digit) : " ")
                                                .font(AppFont.text(side * 0.22, weight: .medium, scaled: false))
                                                .foregroundStyle(session.selected == index ? .white : Palette.muted)
                                        }
                                    }
                                    .padding(3)
                                }
                            }
                            .keyframeAnimator(initialValue: CGFloat.zero, trigger: mistakeTriggers[index]) { content, offset in
                                content.offset(x: shouldAnimateMistake ? offset : 0)
                            } keyframes: { _ in
                                LinearKeyframe(-4, duration: 0.045)
                                LinearKeyframe(4, duration: 0.065)
                                LinearKeyframe(-3, duration: 0.06)
                                LinearKeyframe(3, duration: 0.06)
                                LinearKeyframe(-1.5, duration: 0.05)
                                LinearKeyframe(0, duration: 0.07)
                            }
                        }
                        .frame(width: side, height: side)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Row \(index / 9 + 1), column \(index % 9 + 1)")
                    .accessibilityValue(accessibilityValue(index))
                    .accessibilityAddTraits(session.selected == index ? [.isSelected] : [])
                    .accessibilityIdentifier("cell-\(index)")
                }
            }
            GridLines().stroke(Palette.line, lineWidth: 0.8).allowsHitTesting(false)
            GridLines(majorOnly: true).stroke(Palette.ink.opacity(0.27), lineWidth: 1.2).allowsHitTesting(false)
        }
        .aspectRatio(1, contentMode: .fit)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 13))
        .overlay(RoundedRectangle(cornerRadius: 13).strokeBorder(Palette.ink, lineWidth: 2))
        .accessibilityIdentifier("sudoku-board")
        .onChange(of: session.mistakes) { previous, current in
            guard current > previous, !reduceMotion, let index = session.selected else { return }
            mistakeTriggers[index] += 1
        }
    }

    private func isIncorrect(_ index: Int) -> Bool {
        session.board[index] != 0 && session.board[index] != session.puzzle.solution[index]
    }

    private func background(for index: Int) -> Color {
        if session.selected == index { return Palette.ink }
        if session.board[index] != 0 && session.board[index] != session.puzzle.solution[index] {
            return Palette.error.opacity(0.10)
        }
        guard let selected = session.selected else { return .white }
        if session.board[selected] != 0 && session.board[index] == session.board[selected] {
            return Palette.ink.opacity(0.12)
        }
        if SudokuGenerator.peers(of: selected).contains(index) { return Palette.paper }
        return .white
    }

    private func foreground(for index: Int) -> Color {
        if session.selected == index { return .white }
        if session.board[index] != session.puzzle.solution[index] { return Palette.error }
        return session.puzzle.givens[index] != 0 ? Palette.ink : Palette.muted
    }

    private func accessibilityValue(_ index: Int) -> String {
        let value = session.board[index]
        if value == 0 {
            return session.notes[index].isEmpty ? "Empty" : "Notes: " + session.notes[index].sorted().map(String.init).joined(separator: ", ")
        }
        if session.puzzle.givens[index] != 0 { return "\(value), given" }
        return "\(value), \(value == session.puzzle.solution[index] ? "correct" : "incorrect")"
    }
}

struct GridLines: Shape {
    var majorOnly = false
    func path(in rect: CGRect) -> Path {
        var path = Path()
        for index in 1..<9 where !majorOnly || index.isMultiple(of: 3) {
            let x = rect.width * CGFloat(index) / 9
            let y = rect.height * CGFloat(index) / 9
            path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: rect.height))
            path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: rect.width, y: y))
        }
        return path
    }
}

struct MiniBoard: View {
    let board: [Int]
    var body: some View {
        Canvas { context, size in
            let side = size.width / 9
            for index in board.indices where board[index] != 0 {
                let text = Text(String(board[index]))
                    .font(AppFont.text(side * 0.62, weight: .medium, scaled: false))
                    .foregroundStyle(Palette.ink.opacity(0.65))
                context.draw(text, at: CGPoint(x: (CGFloat(index % 9) + 0.5) * side, y: (CGFloat(index / 9) + 0.5) * side))
            }
        }
        .background(.white)
        .overlay(GridLines().stroke(Palette.line, lineWidth: 0.5))
        .overlay(GridLines(majorOnly: true).stroke(Palette.ink.opacity(0.20), lineWidth: 0.7))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Palette.ink, lineWidth: 1.4))
        .aspectRatio(1, contentMode: .fit)
    }
}
