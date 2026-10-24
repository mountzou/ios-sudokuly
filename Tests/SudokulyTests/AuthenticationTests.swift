#if canImport(UIKit)
import XCTest
import AuthenticationServices
import GoogleSignIn
@testable import Sudokuly

final class AuthenticationTests: XCTestCase {
    func testOnlyRequestedProvidersAreAllowed() {
        XCTAssertTrue(AuthenticationSession.allowsAccount(isAnonymous: false, providerIDs: ["google.com"]))
        XCTAssertTrue(AuthenticationSession.allowsAccount(isAnonymous: false, providerIDs: ["apple.com"]))
        XCTAssertFalse(AuthenticationSession.allowsAccount(isAnonymous: true, providerIDs: ["google.com"]))
        XCTAssertFalse(AuthenticationSession.allowsAccount(isAnonymous: false, providerIDs: ["password"]))
        XCTAssertFalse(AuthenticationSession.allowsAccount(isAnonymous: false, providerIDs: []))
    }

    func testNonceIsFreshAndHashMatchesSHA256() throws {
        let nonces = try (0..<100).map { _ in try AuthenticationSession.makeNonce() }
        XCTAssertEqual(Set(nonces).count, 100)
        XCTAssertTrue(nonces.allSatisfy { $0.count == 64 && $0.allSatisfy(\.isHexDigit) })
        XCTAssertEqual(AuthenticationSession.hashNonce("abc"), "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }

    func testProviderCancellationIsNotAnAuthenticationError() {
        XCTAssertTrue(AuthenticationSession.isCancellation(ASAuthorizationError(.canceled)))
        XCTAssertTrue(AuthenticationSession.isCancellation(NSError(domain: kGIDSignInErrorDomain, code: GIDSignInError.canceled.rawValue)))
        XCTAssertFalse(AuthenticationSession.isCancellation(NSError(domain: "unrelated", code: -1)))
    }

    @MainActor
    func testMissingConfigurationFailsClosed() async {
        let session = AuthenticationSession(isConfigured: false)
        XCTAssertNil(session.account)
        XCTAssertFalse(session.isRestoring)
        XCTAssertNotNil(session.configurationError)
        await session.signInWithGoogle()
        await session.signInWithApple()
        XCTAssertNil(session.account)
        XCTAssertFalse(session.isBusy)
    }
}
#endif
