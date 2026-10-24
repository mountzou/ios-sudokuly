import SwiftUI

struct AuthenticationRootView: View {
    @Environment(AuthenticationSession.self) private var authentication

    var body: some View {
        Group {
            if authentication.isRestoring {
                VStack(spacing: 24) { BrandMark(); ProgressView().tint(Palette.ink) }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Palette.paper.ignoresSafeArea())
            } else if let account = authentication.account {
                RootView(ownerID: account.id, isDemo: isHistoryDemo, usesCloudHistory: !authentication.isTesting).id(account.id)
            } else {
                SignInView()
            }
        }
    }

    private var isHistoryDemo: Bool {
        #if DEBUG && targetEnvironment(simulator)
        return authentication.isTesting && ProcessInfo.processInfo.arguments.contains("--history-demo")
        #else
        return false
        #endif
    }
}
