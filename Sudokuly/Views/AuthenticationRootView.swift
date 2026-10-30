import SwiftUI

struct AuthenticationRootView: View {
    @Environment(AuthenticationSession.self) private var authentication

    var body: some View {
        Group {
            if authentication.isRestoring || isLoadingPreview {
                VStack(spacing: 24) {
                    BrandMark()
                    MetaballLoadingView()
                        .frame(width: 32, height: 32)
                        .frame(height: 20)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Loading")
                }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Palette.paper.ignoresSafeArea())
            } else if let account = authentication.account {
                RootView(ownerID: account.id, registeredAt: account.registeredAt,
                         isDemo: isHistoryDemo, usesCloudHistory: !authentication.isTesting).id(account.id)
            } else {
                SignInView()
            }
        }
    }

    private var isLoadingPreview: Bool {
        #if DEBUG && targetEnvironment(simulator)
        return authentication.isTesting && ProcessInfo.processInfo.arguments.contains("--loading-preview")
        #else
        return false
        #endif
    }

    private var isHistoryDemo: Bool {
        #if DEBUG && targetEnvironment(simulator)
        return authentication.isTesting && ProcessInfo.processInfo.arguments.contains("--history-demo")
        #else
        return false
        #endif
    }
}
