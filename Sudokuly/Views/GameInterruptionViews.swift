import SwiftUI

struct GamePauseView: View {
    let resume: () -> Void

    var body: some View {
        GameInterruptionView(title: "Your game has been paused.",
                             message: "Take a breath.\nYour puzzle can wait.", titleID: "pause-title",
                             illustration: "PauseMeditation") {
            PrimaryButton(title: "Continue game", symbol: nil, action: resume)
                .accessibilityIdentifier("resume")
        }
    }
}

struct LeaveGameConfirmationView: View {
    let keepPlaying: () -> Void
    let leaveGame: () -> Void

    var body: some View {
        GameInterruptionView(title: "Leave this puzzle?",
                             message: "This game won’t be saved.\nA fresh puzzle will be waiting for you.",
                             titleID: "leave-confirmation-title", illustration: "LeaveDoorway") {
            PrimaryButton(title: "Continue game", symbol: nil, action: keepPlaying)
                .accessibilityIdentifier("keep-playing")
            Button(action: leaveGame) {
                Text("Leave game")
                    .font(AppFont.text(16, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 58)
                    .foregroundStyle(Palette.ink)
                    .background(Palette.paper, in: Capsule())
            }
            .buttonStyle(PressStyle())
            .accessibilityIdentifier("confirm-leave")
        }
    }
}

private struct GameInterruptionView<Actions: View>: View {
    let title: String
    let message: String
    let titleID: String
    let illustration: String
    @ViewBuilder let actions: () -> Actions

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.white.opacity(0.94).ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 22) {
                        IllustratedMessageHeader(illustration: illustration, title: title,
                                                 message: message, titleID: titleID)
                        VStack(spacing: 12, content: actions)
                            .padding(.top, 12)
                    }
                    .padding(.vertical, 40)
                    .modifier(IllustratedContentWidth())
                    .frame(maxWidth: .infinity, minHeight: geometry.size.height)
                }
                .scrollIndicators(.hidden)
            }
        }
    }
}
