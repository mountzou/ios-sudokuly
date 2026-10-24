import AuthenticationServices
import CryptoKit
import FirebaseAuth
import FirebaseCore
import GoogleSignIn
import Observation
import Security
import UIKit

struct SignedInAccount: Equatable, Sendable {
    let id: String
    let name: String?
    let email: String?
    let providerIDs: [String]

    var providerLabel: String {
        providerIDs.compactMap { provider in
            switch provider { case "google.com": "Google"; case "apple.com": "Apple"; default: nil }
        }.joined(separator: ", ")
    }
}

@Observable @MainActor
final class AuthenticationSession {
    private(set) var account: SignedInAccount?
    private(set) var isRestoring = true
    private(set) var isBusy = false
    private(set) var configurationError: String?
    var errorMessage: String?
    @ObservationIgnored private var listener: AuthStateDidChangeListenerHandle?
    @ObservationIgnored private var signInAuthorization: AppleAuthorizationFlow?
    @ObservationIgnored private var deletionAuthorization: AppleAuthorizationFlow?
    @ObservationIgnored private let deletionFlow: AccountDeletionFlow?
    #if DEBUG && targetEnvironment(simulator)
    @ObservationIgnored private var testScenario: String?
    var isTesting: Bool { testScenario != nil }
    #else
    var isTesting: Bool { false }
    #endif

    static func configureFirebase() -> Bool {
        if FirebaseApp.app() != nil { return true }
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let options = FirebaseOptions(contentsOfFile: path),
              options.bundleID == Bundle.main.bundleIdentifier,
              options.projectID == "sudokuly-970a3" else { return false }
        FirebaseApp.configure(options: options)
        return true
    }

    init(isConfigured: Bool, testScenario: String? = nil, deletionFlow: AccountDeletionFlow? = nil) {
        self.deletionFlow = deletionFlow
        #if DEBUG && targetEnvironment(simulator)
        self.testScenario = testScenario
        if let testScenario {
            if testScenario == "signed-in" { account = Self.testAccount(provider: "google.com") }
            isRestoring = false
            return
        }
        #endif
        guard isConfigured else {
            configurationError = "Sign-in is unavailable in this build. Please contact support."
            isRestoring = false
            return
        }
        listener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            let snapshot = Self.snapshot(user)
            Task { @MainActor [weak self] in
                self?.account = snapshot
                self?.isRestoring = false
            }
        }
    }

    nonisolated static func allowsAccount(isAnonymous: Bool, providerIDs: [String]) -> Bool {
        !isAnonymous && providerIDs.contains { ["apple.com", "google.com"].contains($0) }
    }

    nonisolated private static func snapshot(_ user: User?) -> SignedInAccount? {
        guard let user, allowsAccount(isAnonymous: user.isAnonymous, providerIDs: user.providerData.map(\.providerID)) else { return nil }
        return SignedInAccount(id: user.uid, name: user.displayName, email: user.email,
                               providerIDs: user.providerData.map(\.providerID))
    }

    func signInWithGoogle() async {
        guard !isBusy, configurationError == nil else { return }
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        #if DEBUG && targetEnvironment(simulator)
        if testScenario != nil { await simulateSignIn(provider: "google.com"); return }
        #endif
        do {
            let result = try await googleAuthorization()
            guard let token = result.user.idToken?.tokenString else { throw SignInError.missingToken }
            let credential = GoogleAuthProvider.credential(withIDToken: token, accessToken: result.user.accessToken.tokenString)
            _ = try await Auth.auth().signIn(with: credential)
        } catch { report(error) }
    }

    func signInWithApple() async {
        guard !isBusy, configurationError == nil else { return }
        isBusy = true
        errorMessage = nil
        defer { signInAuthorization = nil; isBusy = false }
        #if DEBUG && targetEnvironment(simulator)
        if testScenario != nil { await simulateSignIn(provider: "apple.com"); return }
        #endif
        do {
            guard let window = Self.presenter?.view.window else { throw SignInError.unavailable }
            let nonce = try Self.makeNonce()
            let flow = AppleAuthorizationFlow(window: window)
            signInAuthorization = flow
            let apple = try await flow.authorize(nonce: Self.hashNonce(nonce))
            guard let data = apple.identityToken, let token = String(data: data, encoding: .utf8)
            else { throw SignInError.missingToken }
            let credential = OAuthProvider.appleCredential(withIDToken: token, rawNonce: nonce, fullName: apple.fullName)
            _ = try await Auth.auth().signIn(with: credential)
        } catch { report(error) }
    }

    func signOut() {
        guard !isBusy, configurationError == nil else { return }
        #if DEBUG && targetEnvironment(simulator)
        if testScenario != nil { account = nil; errorMessage = nil; return }
        #endif
        do {
            try Auth.auth().signOut()
            GIDSignIn.sharedInstance.signOut()
            account = nil
            errorMessage = nil
        } catch { report(error) }
    }

    func deleteAccount() async {
        guard !isBusy, configurationError == nil else { return }
        isBusy = true
        errorMessage = nil
        defer { isBusy = false; deletionAuthorization = nil }
        #if DEBUG && targetEnvironment(simulator)
        if testScenario != nil && deletionFlow == nil { account = nil; return }
        #endif
        do {
            guard let flow = try deletionFlow ?? makeDeletionFlow() else { return }
            try await flow.run()
            account = nil
        } catch { report(error) }
    }

    private func makeDeletionFlow() throws -> AccountDeletionFlow? {
        guard let user = Auth.auth().currentUser else { return nil }
        let provider: AccountDeletionFlow.Provider
        if user.providerData.contains(where: { $0.providerID == "apple.com" }) { provider = .apple }
        else if user.providerData.contains(where: { $0.providerID == "google.com" }) { provider = .google }
        else { throw SignInError.unavailable }
        var appleRevocationCode: String?
        return AccountDeletionFlow(ownerID: user.uid, provider: provider, currentUserID: {
            Auth.auth().currentUser?.uid
        }, reauthenticate: { [self] in
            if provider == .apple {
                guard let window = Self.presenter?.view.window else { throw SignInError.unavailable }
                let nonce = try Self.makeNonce()
                let flow = AppleAuthorizationFlow(window: window)
                deletionAuthorization = flow
                let apple = try await flow.authorize(nonce: Self.hashNonce(nonce))
                guard let data = apple.identityToken, let token = String(data: data, encoding: .utf8),
                      let codeData = apple.authorizationCode, let code = String(data: codeData, encoding: .utf8)
                else { throw SignInError.missingToken }
                let credential = OAuthProvider.appleCredential(withIDToken: token, rawNonce: nonce, fullName: apple.fullName)
                try await reauthenticate(user, credential: credential)
                guard Auth.auth().currentUser?.uid == user.uid else { throw SignInError.unavailable }
                appleRevocationCode = code
            } else {
                let result = try await googleAuthorization(hint: user.email)
                guard let token = result.user.idToken?.tokenString else { throw SignInError.missingToken }
                let credential = GoogleAuthProvider.credential(withIDToken: token, accessToken: result.user.accessToken.tokenString)
                try await reauthenticate(user, credential: credential)
            }
        }, revokeAccess: { [self] in
            if provider == .google {
                // The picker may offer another account: never revoke its grant.
                guard let googleID = user.providerData.first(where: { $0.providerID == "google.com" })?.uid,
                      GIDSignIn.sharedInstance.currentUser?.userID == googleID else {
                    throw AccountDeletionFlow.Failure.accountChanged
                }
                try await disconnectGoogle()
            } else {
                guard let appleRevocationCode else { throw SignInError.missingToken }
                try await Auth.auth().revokeToken(withAuthorizationCode: appleRevocationCode)
            }
        }, deleteHistory: {
            try await FirestoreGameHistoryRepository().deleteAccountHistory(ownerID: user.uid)
        }, clearPendingResults: {
            try GameHistoryOutbox(ownerID: user.uid).replace([])
        }, deleteIdentity: { [self] in
            try await deleteFirebaseUser(user)
        }, finishSignOut: {
            GIDSignIn.sharedInstance.signOut()
        })
    }

    private func disconnectGoogle() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            GIDSignIn.sharedInstance.disconnect { error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume() }
            }
        }
    }

    private func googleAuthorization(hint: String? = nil) async throws -> GIDSignInResult {
        guard let clientID = FirebaseApp.app()?.options.clientID, let presenter = Self.presenter else { throw SignInError.unavailable }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        return try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter, hint: hint)
    }

    // Firebase 12's User isn't Sendable. Its callback API keeps the SDK object
    // on the calling actor while continuations carry only success or an error.
    private func reauthenticate(_ user: User, credential: AuthCredential) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            user.reauthenticate(with: credential) { _, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume() }
            }
        }
    }

    private func deleteFirebaseUser(_ user: User) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            user.delete { error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume() }
            }
        }
    }

    nonisolated static func makeNonce() throws -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else { throw SignInError.unavailable }
        return bytes.map { String(format: "%02x", $0) }.joined()
    }

    nonisolated static func hashNonce(_ nonce: String) -> String {
        SHA256.hash(data: Data(nonce.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    nonisolated static func isCancellation(_ error: Error) -> Bool {
        if (error as? ASAuthorizationError)?.code == .canceled { return true }
        let nsError = error as NSError
        return nsError.domain == kGIDSignInErrorDomain && nsError.code == GIDSignInError.canceled.rawValue
    }

    private func report(_ error: Error) {
        guard !Self.isCancellation(error) else { return }
        if error is AccountDeletionFlow.Failure {
            errorMessage = "Use the same account to confirm this action."
            return
        }
        if let authCode = AuthErrorCode(rawValue: (error as NSError).code) {
            switch authCode {
            case .networkError: errorMessage = "Check your connection and try again."
            case .accountExistsWithDifferentCredential: errorMessage = "This email uses another sign-in method. Use the method you signed in with before."
            case .userDisabled: errorMessage = "This account is unavailable. Please contact support."
            case .userMismatch: errorMessage = "Use the same account to confirm this action."
            case .requiresRecentLogin: errorMessage = "Please sign in again to confirm this action."
            default: errorMessage = "We couldn’t finish that. Please try again."
            }
        } else { errorMessage = "We couldn’t finish that. Please try again." }
    }

    private static var presenter: UIViewController? {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first { $0.activationState == .foregroundActive }
        var controller = scene?.windows.first(where: \.isKeyWindow)?.rootViewController
        while let presented = controller?.presentedViewController { controller = presented }
        return controller
    }

    #if DEBUG && targetEnvironment(simulator)
    private static func testAccount(provider: String) -> SignedInAccount {
        SignedInAccount(id: "sudokuly-ui-test", name: "Sudokuly Player", email: "player@example.test", providerIDs: [provider])
    }
    private func simulateSignIn(provider: String) async {
        await Task.yield()
        if testScenario == "error" { errorMessage = "Check your connection and try again." }
        else { account = Self.testAccount(provider: provider) }
    }
    #endif

    private enum SignInError: Error { case missingToken, unavailable }
}

@MainActor
private final class AppleAuthorizationFlow: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private let window: UIWindow
    private var continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>?
    private var controller: ASAuthorizationController?

    init(window: UIWindow) { self.window = window }

    func authorize(nonce: String) async throws -> ASAuthorizationAppleIDCredential {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.fullName, .email]
            request.nonce = nonce
            let controller = ASAuthorizationController(authorizationRequests: [request])
            self.controller = controller
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor { window }
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            finish(.failure(ASAuthorizationError(.invalidResponse))); return
        }
        finish(.success(credential))
    }
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) { finish(.failure(error)) }
    private func finish(_ result: Result<ASAuthorizationAppleIDCredential, Error>) {
        continuation?.resume(with: result)
        continuation = nil
        controller = nil
    }
}
