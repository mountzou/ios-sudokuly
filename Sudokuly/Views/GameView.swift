import SwiftUI
import Combine

struct GameView: View {
    @ObservedObject var model: GameViewModel
    @State private var showLeaveConfirmation = false
    @State private var showFinalLeaveConfirmation = false
    private let timer = Timer.publish(every: 0.2, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            if let session = model.session {
                ScrollView {
                    VStack(spacing: 12) {
                        HStack {
                            CircleIcon(symbol: "xmark", label: "Leave game") {
                                model.pause()
                                showLeaveConfirmation = model.isPaused
                            }
                            .accessibilityIdentifier("leave-game")
                            Spacer()
                            HStack(spacing: 5) {
                                Image(systemName: "timer").font(.system(size: 13))
                                Text(clockText(session.remaining))
                                    .font(AppFont.text(13, weight: .semibold))
                                    .monospacedDigit()
                            }
                            .foregroundStyle(session.remaining <= 60 ? Palette.error : Palette.ink)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("Time remaining")
                            .accessibilityValue(clockText(session.remaining))
                            .accessibilityIdentifier("timer")
                            Spacer()
                            CircleIcon(symbol: "pause", label: "Pause game", action: model.pause)
                                .accessibilityIdentifier("pause")
                        }
                        .padding(.bottom, 12)

                        VStack(spacing: 9) {
                            HStack {
                                HStack(spacing: 6) {
                                    ForEach(0..<3) { index in
                                        Image(systemName: index < 3 - session.mistakes ? "heart.fill" : "heart")
                                            .font(.system(size: 15))
                                            .foregroundStyle(index < 3 - session.mistakes ? Palette.ink : Palette.ink.opacity(0.2))
                                    }
                                }
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel("Mistakes")
                                .accessibilityValue("\(session.mistakes) of 3")
                                .accessibilityIdentifier("mistakes")
                                .frame(maxWidth: .infinity, alignment: .leading)
                                Text(session.puzzle.difficulty.title)
                                    .font(AppFont.text(11, weight: .semibold))
                                    .padding(.horizontal, 12).padding(.vertical, 7)
                                    .background(Palette.paper, in: Capsule())
                                HStack(spacing: 6) {
                                    ForEach(0..<3) { index in
                                        Image(systemName: index < session.hintsRemaining ? "lightbulb.fill" : "lightbulb")
                                            .font(.system(size: 15))
                                            .frame(width: 17)
                                    }
                                }
                                .foregroundStyle(Palette.ink)
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel("Hints remaining")
                                .accessibilityValue("\(session.hintsRemaining) of 3")
                                .accessibilityIdentifier("hints-remaining")
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                            SudokuBoard(session: session, select: model.select)
                        }

                        VStack(spacing: 4) {
                            Text(model.message)
                                .font(AppFont.text(11))
                                .foregroundStyle(Palette.muted)
                                .frame(minHeight: 16)
                                .multilineTextAlignment(.center)
                            keypad(session)
                        }

                        HStack(spacing: 12) {
                            tool("lightbulb", title: "Hint", active: false,
                                 enabled: session.canUseHint, action: model.useHint)
                                .accessibilityIdentifier("hint")
                                .accessibilityLabel("Hint")
                                .accessibilityValue("\(session.hintsRemaining) remaining")
                                .accessibilityHint("Fill the selected cell with the correct number.")
                            tool("pencil.tip", title: "Notes", active: session.isNotesMode, enabled: true, action: model.toggleNotes)
                                .accessibilityIdentifier("notes")
                                .accessibilityValue(session.isNotesMode ? "On" : "Off")
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                    .frame(maxWidth: 470)
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
                .blur(radius: model.isPaused ? 10 : 0)
                .allowsHitTesting(!model.isPaused)
                .accessibilityHidden(model.isPaused)
            }

            if model.isPaused {
                if showLeaveConfirmation {
                    LeaveGameConfirmationView(keepPlaying: keepPlaying) {
                        showFinalLeaveConfirmation = true
                    }
                } else {
                    GamePauseView(resume: keepPlaying)
                }
            }
        }
        .onReceive(timer) { _ in model.tick() }
        .alert("Leave without saving?", isPresented: $showFinalLeaveConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Leave game", role: .destructive) {
                showLeaveConfirmation = false
                model.goHome()
            }
        } message: {
            Text("All progress in this puzzle will be lost. You won’t be able to resume it.")
        }
    }

    private func keepPlaying() {
        showLeaveConfirmation = false
        model.resume()
    }

    private func keypad(_ session: GameSession) -> some View {
        VStack(spacing: 5) {
            HStack(spacing: 0) { ForEach(1...5, id: \.self) { digit in digitButton(digit, session: session) } }
            HStack(spacing: 0) {
                ForEach(6...9, id: \.self) { digit in digitButton(digit, session: session) }
                Button(action: model.erase) {
                    Image(systemName: "delete.left")
                        .font(.system(size: 22, weight: .regular))
                        .frame(maxWidth: .infinity, minHeight: 59)
                        .foregroundStyle(Palette.ink)
                }
                .buttonStyle(PressStyle())
                .disabled(!session.canEdit)
                .accessibilityLabel("Erase cell")
                .accessibilityIdentifier("erase")
            }
        }
    }

    private func digitButton(_ digit: Int, session: GameSession) -> some View {
        let complete = session.board.filter { $0 == digit }.count == 9 &&
            session.board.indices.filter { session.board[$0] == digit }.allSatisfy { session.puzzle.solution[$0] == digit }
        return Button { model.enter(digit) } label: {
            Text(String(digit))
                .font(AppFont.text(33, weight: .medium, scaled: false))
                .frame(maxWidth: .infinity, minHeight: 59)
                .foregroundStyle(Palette.ink.opacity(complete ? 0.18 : 1))
        }
        .buttonStyle(PressStyle())
        .disabled(!session.canEdit || complete)
        .accessibilityLabel(session.isNotesMode ? "Note \(digit)" : "Enter \(digit)")
        .accessibilityIdentifier("digit-\(digit)")
    }

    private func tool(_ symbol: String, title: String, active: Bool, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: symbol).font(.system(size: 16, weight: .medium))
                Text(title).font(AppFont.text(13, weight: .semibold))
                if active { Circle().frame(width: 4, height: 4) }
            }
            .frame(maxWidth: .infinity, minHeight: 49)
            .foregroundStyle(active ? .white : Palette.ink.opacity(enabled ? 1 : 0.3))
            .background(active ? Palette.ink : Palette.paper, in: Capsule())
        }
        .buttonStyle(PressStyle())
        .disabled(!enabled)
    }
}
