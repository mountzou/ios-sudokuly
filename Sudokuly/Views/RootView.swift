import SwiftUI

struct RootView: View {
    private enum Destination: Hashable { case account, history }

    @StateObject private var history: GameHistoryStore
    @StateObject private var model: GameViewModel
    private let registeredAt: Date?
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var navigationPath = NavigationPath()
    @State private var mistakeResultReady = false
    #if DEBUG && targetEnvironment(simulator)
    private let isDemo: Bool
    @State private var showDemo = false
    @State private var pendingDemoAction: HistoryDemoAction?
    #endif

    init(ownerID: String, registeredAt: Date?, isDemo: Bool = false, usesCloudHistory: Bool = false) {
        self.registeredAt = registeredAt
        var records: [GameRecord] = []
        #if DEBUG && targetEnvironment(simulator)
        self.isDemo = isDemo
        if isDemo { records = HistoryDemoData.records(ownerID: ownerID) }
        #endif
        let history = GameHistoryStore(ownerID: ownerID, records: records,
                                       repository: usesCloudHistory ? FirestoreGameHistoryRepository() : nil,
                                       pendingStorage: usesCloudHistory ? GameHistoryOutbox(ownerID: ownerID) : nil)
        _history = StateObject(wrappedValue: history)
        _model = StateObject(wrappedValue: GameViewModel(history: history))
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            gameContent
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: Destination.self) { destination in
                    switch destination {
                    case .account:
                        AccountView()
                    case .history:
                        HistoryView(history: history, registeredAt: registeredAt, close: { navigationPath.removeLast() })
                    }
                }
                .navigationDestination(for: GameRecord.self) { record in HistoryDetailView(record: record) }
        }
        .onChange(of: scenePhase) { _, phase in model.setAppActive(phase == .active) }
        .task(id: history.ownerID) { history.start() }
        .task(id: model.session?.outcome) {
            mistakeResultReady = false
            guard model.session?.outcome == .mistakes else { return }
            if !reduceMotion {
                // Let the final cell's 0.35-second shake finish before showing the result.
                do { try await Task.sleep(for: .milliseconds(400)) }
                catch { return }
            }
            guard !Task.isCancelled, model.session?.outcome == .mistakes else { return }
            mistakeResultReady = true
        }
        #if DEBUG && targetEnvironment(simulator)
        .sheet(isPresented: $showDemo, onDismiss: runDemoAction) {
            HistoryDemoView { action in
                pendingDemoAction = action
                showDemo = false
            }
        }
        #endif
    }

    private var gameContent: some View {
        ZStack {
            Palette.paper.ignoresSafeArea()
            if let session = model.session {
                if let outcome = displayedOutcome {
                    ResultView(session: session, outcome: outcome, history: history, recordID: model.completedGame?.id,
                               finish: model.goHome,
                               showHistory: { navigationPath.append(Destination.history) })
                        .transition(.opacity)
                } else {
                    GameView(model: model)
                        .transition(.opacity)
                }
            } else {
                HomeView(history: history, registeredAt: registeredAt, isGenerating: model.isGenerating, start: model.start,
                         showAccount: { navigationPath.append(Destination.account) },
                         showHistory: { navigationPath.append(Destination.history) },
                         showDemo: demoAction)
                    .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: model.session == nil)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: displayedOutcome)
    }

    private var displayedOutcome: GameOutcome? {
        guard let outcome = model.session?.outcome else { return nil }
        return outcome == .mistakes && !mistakeResultReady ? nil : outcome
    }

    private var demoAction: (() -> Void)? {
        #if DEBUG && targetEnvironment(simulator)
        if isDemo { return { showDemo = true } }
        #endif
        return nil
    }

    #if DEBUG && targetEnvironment(simulator)
    private func runDemoAction() {
        guard let action = pendingDemoAction else { return }
        pendingDemoAction = nil
        switch action {
        case .samples:
            history.replaceDemoRecords(HistoryDemoData.records(ownerID: history.ownerID))
            navigationPath.append(Destination.history)
        case .empty:
            history.replaceDemoRecords([])
            navigationPath.append(Destination.history)
        case .result(let outcome): model.previewResult(outcome)
        }
    }
    #endif
}
