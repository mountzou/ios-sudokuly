import SwiftUI
import UIKit
import GoogleSignIn

@main
struct SudokulyApp: App {
    @State private var authentication: AuthenticationSession

    init() {
        // Keep every app screen scrollable without rubber-banding at its edges.
        UIScrollView.appearance().bounces = false
        let configured = AuthenticationSession.configureFirebase()
        var scenario: String?
        #if DEBUG && targetEnvironment(simulator)
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--game-testing") { scenario = "signed-in" }
        if arguments.contains("--auth-testing") { scenario = arguments.contains("--auth-scenario=error") ? "error" : "signed-out" }
        #endif
        _authentication = State(initialValue: AuthenticationSession(isConfigured: configured, testScenario: scenario))
    }

    var body: some Scene {
        WindowGroup {
            AuthenticationRootView()
                .environment(authentication)
                .environment(\.locale, AppFormatting.english)
                .preferredColorScheme(.light)
                .tint(Palette.ink)
                .onOpenURL { url in _ = GIDSignIn.sharedInstance.handle(url) }
        }
    }
}
