import SwiftUI

struct ResultView: View {
    let session: GameSession
    let outcome: GameOutcome
    @ObservedObject var history: GameHistoryStore
    let recordID: UUID?
    let finish: () -> Void
    let showHistory: () -> Void

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                content
                    .frame(maxWidth: .infinity, minHeight: outcome == .won ? geometry.size.height : 0)
            }
            .scrollIndicators(.hidden)
        }
        .foregroundStyle(Palette.ink)
        .accessibilityIdentifier("result-\(outcome.rawValue)")
    }

    private var content: some View {
        VStack(spacing: 20) {
            if outcome != .won {
                BrandMark(small: true).padding(.top, 16)
            }

            GameResultHeader(outcome: outcome, titleIdentifier: "result-title")

            VStack(spacing: 22) {
                if outcome != .won {
                    MiniBoard(board: session.board)
                        .frame(width: 140, height: 140)
                        .accessibilityHidden(true)
                }
                GameResultStats(difficulty: session.puzzle.difficulty, duration: session.elapsed, mistakes: session.mistakes)
            }
            .padding(.vertical, 20)
            .background(.white, in: RoundedRectangle(cornerRadius: 28))

            VStack(spacing: 8) {
                if outcome != .won {
                    Label(recordID.map { history.resultMessage(for: $0) } ?? "Adding to your history…",
                          systemImage: recordID.map { history.pendingIDs.contains($0) } == true ? "icloud.and.arrow.up" : "checkmark.circle")
                        .font(AppFont.text(11)).foregroundStyle(Palette.muted).multilineTextAlignment(.center)
                        .accessibilityIdentifier("result-recorded")
                }
                if history.saveError != nil {
                    Button("Retry saving", action: history.retry).font(AppFont.text(12, weight: .semibold))
                        .frame(minHeight: 44).accessibilityIdentifier("history-retry-save")
                }
                PrimaryButton(title: "Back to home", action: finish)
                    .accessibilityIdentifier("finish")
                Button("View history", action: showHistory)
                    .font(AppFont.text(13, weight: .semibold))
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("result-history")
            }
            if outcome != .won {
                Text("There’s always a fresh start.")
                    .font(AppFont.text(11))
                    .foregroundStyle(Palette.muted)
                    .padding(.bottom, 12)
            }
        }
        .padding(.vertical, outcome == .won ? 24 : 0)
        .modifier(IllustratedContentWidth())
    }

}

extension GameOutcome {
    var illustration: String {
        switch self {
        case .won: "VictoryCelebration"
        case .mistakes: "PauseMeditation"
        case .timedOut: "HistoryThinking"
        }
    }
    var label: String {
        switch self { case .won: "Solved"; case .mistakes: "Three mistakes"; case .timedOut: "Time’s up" }
    }
    var symbol: String {
        switch self { case .won: "trophy"; case .mistakes: "heart.slash"; case .timedOut: "timer" }
    }
    var eyebrow: String {
        switch self { case .won: "PUZZLE COMPLETE"; case .mistakes: "THREE MISTAKES"; case .timedOut: "TIME’S UP" }
    }
    var title: String {
        switch self { case .won: "Beautifully\nsolved."; case .mistakes: "A pause.\nA fresh start."; case .timedOut: "Good things\ntake practice." }
    }
    var detail: String {
        switch self {
        case .won: "Every number, right where it belongs.\nTake this little win with you."
        case .mistakes: "Three wrong turns. Plenty learned.\nYour next puzzle is a new beginning."
        case .timedOut: "The clock reached zero.\nCome back with a fresh perspective."
        }
    }
}

struct GameResultHeader: View {
    let outcome: GameOutcome
    let titleIdentifier: String
    var showsIllustration = true

    var body: some View {
        IllustratedMessageHeader(illustration: outcome.illustration, title: outcome.title,
                                 message: outcome.detail, titleID: titleIdentifier,
                                 showsIllustration: showsIllustration)
    }
}

struct GameResultStats: View {
    let difficulty: Difficulty
    let duration: TimeInterval
    let mistakes: Int

    var body: some View {
        HStack(spacing: 0) {
            stat("LEVEL", value: difficulty.title)
            Rectangle().fill(Palette.line).frame(width: 1, height: 30)
            stat("TIME", value: clockText(duration))
            Rectangle().fill(Palette.line).frame(width: 1, height: 30)
            stat("MISTAKES", value: "\(mistakes) / 3")
        }
    }

    private func stat(_ label: String, value: String) -> some View {
        VStack(spacing: 7) {
            Text(label).font(AppFont.text(8, weight: .semibold)).tracking(1.2).foregroundStyle(Palette.muted)
            Text(value).font(AppFont.text(14, weight: .semibold)).monospacedDigit()
        }
        .frame(maxWidth: .infinity)
    }
}
