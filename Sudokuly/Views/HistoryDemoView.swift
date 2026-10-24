#if DEBUG && targetEnvironment(simulator)
import SwiftUI

struct HistoryDemoView: View {
    let choose: (HistoryDemoAction) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Make a little history.")
                            .font(AppFont.text(27, weight: .bold)).tracking(-1)
                        Text("Preview with Sudokuly Player. These examples stay in memory for this run.")
                            .font(AppFont.text(13)).foregroundStyle(Palette.muted).lineSpacing(3)
                    }
                    section("HISTORY") {
                        row("Six sample games", subtitle: "All levels and all three outcomes", symbol: "clock.arrow.circlepath", id: "demo-samples") { choose(.samples) }
                        row("A fresh page", subtitle: "Clear this session’s history", symbol: "square.grid.3x3", id: "demo-empty") { choose(.empty) }
                    }
                    section("RESULTS") {
                        row("Puzzle solved", subtitle: "Complete a Medium puzzle", symbol: "trophy", id: "demo-won") { choose(.result(.won)) }
                        row("Three mistakes", subtitle: "Use all three attempts", symbol: "heart.slash", id: "demo-mistakes") { choose(.result(.mistakes)) }
                        row("Time’s up", subtitle: "Reach the puzzle’s time limit", symbol: "timer", id: "demo-timedOut") { choose(.result(.timedOut)) }
                    }
                }
                .padding(24)
            }
            .background(Palette.paper.ignoresSafeArea()).foregroundStyle(Palette.ink)
            .navigationTitle("Demo scenarios").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.font(AppFont.text(14, weight: .semibold))
                }
            }
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(AppFont.text(10, weight: .semibold)).tracking(1.5).foregroundStyle(Palette.muted)
            VStack(spacing: 0, content: content).background(.white, in: RoundedRectangle(cornerRadius: 25))
        }
    }

    private func row(_ title: String, subtitle: String, symbol: String, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 15) {
                Image(systemName: symbol).font(.system(size: 20, weight: .light)).frame(width: 28)
                VStack(alignment: .leading, spacing: 5) {
                    Text(title).font(AppFont.text(15, weight: .semibold))
                    Text(subtitle).font(AppFont.text(11)).foregroundStyle(Palette.muted)
                }
                Spacer()
                Image(systemName: "arrow.up.right").font(.system(size: 12))
            }
            .foregroundStyle(Palette.ink).padding(19).frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle()).accessibilityIdentifier(id)
    }
}
#endif
