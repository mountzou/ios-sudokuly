#if canImport(UIKit)
import XCTest
import FirebaseAuth
import GoogleSignIn
@testable import Sudokuly

@MainActor
final class AccountDeletionTests: XCTestCase {
    func testGoogleDeletionRevokesAccessBeforeRemovingDataAndIdentity() async {
        let backend = DeletionBackend()
        let session = backend.session()

        await session.deleteAccount()

        XCTAssertEqual(backend.calls, [.reauthenticate, .revoke, .history, .pending, .identity, .signOut])
        XCTAssertFalse(backend.googleConnected)
        XCTAssertFalse(backend.identityExists)
        XCTAssertEqual(backend.historyCount, 0)
        XCTAssertEqual(backend.pendingCount, 0)
        XCTAssertNil(session.account)
        XCTAssertNil(session.errorMessage)
        XCTAssertFalse(session.isBusy)
    }

    func testDisconnectFailurePreservesDataAndSessionThenCanBeRetried() async {
        let backend = DeletionBackend()
        backend.failingStep = .revoke
        let session = backend.session()

        await session.deleteAccount()

        XCTAssertEqual(backend.calls, [.reauthenticate, .revoke])
        XCTAssertTrue(backend.googleConnected)
        XCTAssertTrue(backend.identityExists)
        XCTAssertEqual(backend.historyCount, 3)
        XCTAssertEqual(backend.pendingCount, 1)
        XCTAssertNotNil(session.account)
        XCTAssertNotNil(session.errorMessage)
        XCTAssertFalse(session.isBusy)

        backend.failingStep = nil
        await session.deleteAccount()

        XCTAssertEqual(backend.calls.filter { $0 == .reauthenticate }.count, 2)
        XCTAssertEqual(backend.calls.filter { $0 == .revoke }.count, 2)
        XCTAssertEqual(backend.calls.filter { $0 == .identity }.count, 1)
        XCTAssertFalse(backend.googleConnected)
        XCTAssertFalse(backend.identityExists)
        XCTAssertNil(session.account)
        XCTAssertNil(session.errorMessage)
    }

    func testCancelledReauthenticationDoesNotRevokeOrDeleteAnything() async {
        let backend = DeletionBackend()
        backend.failingStep = .reauthenticate
        backend.error = NSError(domain: kGIDSignInErrorDomain, code: GIDSignInError.canceled.rawValue)
        let session = backend.session()

        await session.deleteAccount()

        XCTAssertEqual(backend.calls, [.reauthenticate])
        XCTAssertTrue(backend.googleConnected)
        XCTAssertTrue(backend.identityExists)
        XCTAssertEqual(backend.historyCount, 3)
        XCTAssertEqual(backend.pendingCount, 1)
        XCTAssertNotNil(session.account)
        XCTAssertNil(session.errorMessage)
        XCTAssertFalse(session.isBusy)
    }

    func testDifferentGoogleAccountCannotRevokeAccessOrDeleteData() async {
        let backend = DeletionBackend()
        backend.failingStep = .reauthenticate
        backend.error = NSError(domain: AuthErrorDomain, code: AuthErrorCode.userMismatch.rawValue)
        let session = backend.session()

        await session.deleteAccount()

        XCTAssertEqual(backend.calls, [.reauthenticate])
        XCTAssertTrue(backend.identityExists)
        XCTAssertEqual(backend.historyCount, 3)
        XCTAssertEqual(backend.pendingCount, 1)
        XCTAssertNotNil(session.account)
        XCTAssertEqual(session.errorMessage, "Use the same account to confirm this action.")
    }

    func testPartialCleanupFailuresKeepIdentityAndAllowFreshAuthorizationOnRetry() async {
        for step in [DeletionBackend.Step.history, .pending, .identity] {
            let backend = DeletionBackend()
            backend.failingStep = step
            let session = backend.session()

            await session.deleteAccount()

            XCTAssertFalse(backend.googleConnected, "Revocation has already succeeded at \(step)")
            XCTAssertTrue(backend.identityExists, "Do not lose cleanup access at \(step)")
            XCTAssertNotNil(session.account)
            XCTAssertNotNil(session.errorMessage)
            XCTAssertFalse(session.isBusy)
            XCTAssertFalse(backend.calls.contains(.signOut))

            backend.failingStep = nil
            await session.deleteAccount()

            XCTAssertEqual(backend.calls.filter { $0 == .reauthenticate }.count, 2)
            XCTAssertEqual(backend.calls.filter { $0 == .revoke }.count, 2)
            XCTAssertFalse(backend.identityExists)
            XCTAssertFalse(backend.googleConnected)
            XCTAssertEqual(backend.historyCount, 0)
            XCTAssertEqual(backend.pendingCount, 0)
            XCTAssertNil(session.account)
            XCTAssertNil(session.errorMessage)
        }
    }

    func testAccountChangesDuringAwaitedStepsStopFurtherCleanup() async {
        for step in [DeletionBackend.Step.reauthenticate, .revoke, .history] {
            let backend = DeletionBackend()
            backend.changeAccountAfter = step
            let session = backend.session()

            await session.deleteAccount()

            XCTAssertEqual(backend.calls.last, step)
            XCTAssertEqual(backend.currentID, "another-account")
            XCTAssertTrue(backend.identityExists)
            XCTAssertEqual(backend.pendingCount, 1)
            XCTAssertFalse(backend.calls.contains(.identity))
            XCTAssertFalse(backend.calls.contains(.signOut))
            XCTAssertNotNil(session.account)
            XCTAssertEqual(session.errorMessage, "Use the same account to confirm this action.")
            XCTAssertFalse(session.isBusy)
        }
    }

    func testAlreadyChangedAccountStopsBeforeAuthorization() async {
        let backend = DeletionBackend()
        backend.currentID = "another-account"
        let session = backend.session()

        await session.deleteAccount()

        XCTAssertTrue(backend.calls.isEmpty)
        XCTAssertTrue(backend.identityExists)
        XCTAssertNotNil(session.errorMessage)
        XCTAssertFalse(session.isBusy)
    }

    func testInFlightDisconnectCannotBeSkippedOrStartedTwice() async {
        let backend = DeletionBackend()
        let entered = expectation(description: "Disconnect awaiting provider response")
        var continuation: CheckedContinuation<Void, Never>?
        backend.waitForRevocation = {
            await withCheckedContinuation {
                continuation = $0
                entered.fulfill()
            }
        }
        let session = backend.session()
        let deletion = Task { await session.deleteAccount() }
        await fulfillment(of: [entered], timeout: 3)

        XCTAssertTrue(session.isBusy)
        XCTAssertNotNil(session.account)
        XCTAssertEqual(backend.historyCount, 3)
        await session.deleteAccount()
        session.signOut()
        XCTAssertNotNil(session.account)
        XCTAssertEqual(backend.calls, [.reauthenticate, .revoke])

        continuation?.resume()
        await deletion.value

        XCTAssertEqual(backend.calls.filter { $0 == .revoke }.count, 1)
        XCTAssertEqual(backend.calls.filter { $0 == .identity }.count, 1)
        XCTAssertNil(session.account)
        XCTAssertFalse(session.isBusy)
    }

    func testAppleRetainsItsExistingCleanupThenRevocationOrder() async throws {
        let backend = DeletionBackend()
        try await backend.flow(provider: .apple).run()
        XCTAssertEqual(backend.calls, [.reauthenticate, .history, .pending, .revoke, .identity, .signOut])
        XCTAssertFalse(backend.identityExists)
    }

    func testMissingConfigurationCannotStartDeletion() async {
        let backend = DeletionBackend()
        let session = AuthenticationSession(isConfigured: false, deletionFlow: backend.flow())
        await session.deleteAccount()
        XCTAssertTrue(backend.calls.isEmpty)
        XCTAssertFalse(session.isBusy)
        XCTAssertNotNil(session.configurationError)
    }
}

/// In-memory service boundaries; session error/busy handling and flow are production code.
@MainActor
private final class DeletionBackend {
    enum Step { case reauthenticate, revoke, history, pending, identity, signOut }
    let ownerID = "sudokuly-ui-test"
    var currentID: String? = "sudokuly-ui-test"
    var googleConnected = true
    var identityExists = true
    var historyCount = 3
    var pendingCount = 1
    var calls: [Step] = []
    var failingStep: Step?
    var changeAccountAfter: Step?
    var waitForRevocation: (() async -> Void)?
    var error: Error = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)

    func session() -> AuthenticationSession {
        AuthenticationSession(isConfigured: false, testScenario: "signed-in", deletionFlow: flow())
    }

    func perform(_ step: Step) throws {
        calls.append(step)
        if failingStep == step { throw error }
        if changeAccountAfter == step { currentID = "another-account" }
    }

    func flow(provider: AccountDeletionFlow.Provider = .google) -> AccountDeletionFlow {
        AccountDeletionFlow(ownerID: ownerID, provider: provider, currentUserID: { self.currentID },
            reauthenticate: {
                try self.perform(.reauthenticate)
                self.googleConnected = true // A retry obtains fresh provider authorization.
            }, revokeAccess: {
                try self.perform(.revoke)
                await self.waitForRevocation?()
                self.googleConnected = false
            }, deleteHistory: {
                try self.perform(.history)
                self.historyCount = 0
            }, clearPendingResults: {
                try self.perform(.pending)
                self.pendingCount = 0
            }, deleteIdentity: {
                try self.perform(.identity)
                self.identityExists = false
                self.currentID = nil
            }, finishSignOut: { self.calls.append(.signOut) })
    }
}
#endif
