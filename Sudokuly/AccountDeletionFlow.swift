/// Keeps the Firebase session alive until cloud cleanup and provider revocation finish.
@MainActor
struct AccountDeletionFlow {
    enum Provider { case google, apple }
    enum Failure: Error { case accountChanged }

    let ownerID: String
    let provider: Provider
    let currentUserID: () -> String?
    let reauthenticate: () async throws -> Void
    let revokeAccess: () async throws -> Void
    let deleteHistory: () async throws -> Void
    let clearPendingResults: () throws -> Void
    let deleteIdentity: () async throws -> Void
    let finishSignOut: () -> Void

    func run() async throws {
        try verifyAccount()
        try await reauthenticate()
        try verifyAccount()
        // Google disconnect revokes its tokens and signs out of Google, not Firebase.
        // Fail before removing history if the provider cannot confirm revocation.
        if provider == .google {
            try await revokeAccess()
            try verifyAccount()
        }
        try await deleteHistory()
        try verifyAccount()
        try clearPendingResults()
        // Preserve the existing Apple cleanup/revocation order.
        if provider == .apple {
            try await revokeAccess()
            try verifyAccount()
        }
        try await deleteIdentity()
        finishSignOut()
    }

    private func verifyAccount() throws {
        guard currentUserID() == ownerID else { throw Failure.accountChanged }
    }
}
