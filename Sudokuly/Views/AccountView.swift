import SwiftUI

struct AccountView: View {
    @Environment(AuthenticationSession.self) private var authentication
    @Environment(\.dismiss) private var dismiss
    @State private var confirmDelete = false
    @State private var confirmSignOut = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                CircleIcon(symbol: "chevron.left", label: "Back to home") { dismiss() }
                    .accessibilityIdentifier("account-back")
                Text("Account")
                    .font(AppFont.text(16, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .accessibilityAddTraits(.isHeader)
                Color.clear.frame(width: 46, height: 46).accessibilityHidden(true)
            }
            .padding(.top, 12).padding(.horizontal, 24)
            .frame(maxWidth: 480).frame(maxWidth: .infinity)

            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 25) {
                        Image("AccountProfile")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 160, height: 160)
                            .accessibilityHidden(true)
                        if let account = authentication.account {
                            VStack(spacing: 8) {
                                Text(account.name ?? "Your account")
                                    .font(AppFont.text(25, weight: .bold)).tracking(-0.8)
                                if let email = account.email {
                                    Text(email)
                                        .font(AppFont.text(13)).foregroundStyle(Palette.muted)
                                        .accessibilityIdentifier("account-email")
                                }
                            }
                        }
                        PrimaryButton(title: "Sign out", symbol: "rectangle.portrait.and.arrow.right") { confirmSignOut = true }
                            .accessibilityIdentifier("sign-out")
                        Button("Delete account") { confirmDelete = true }
                            .font(AppFont.text(13, weight: .medium)).foregroundStyle(Palette.error)
                            .frame(minHeight: 44)
                            .accessibilityIdentifier("delete-account")
                        Link(destination: AppLinks.privacyPolicy) {
                            HStack(spacing: 6) {
                                Text("Privacy Policy")
                                    .font(AppFont.text(13, weight: .medium))
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 11, weight: .medium))
                                    .accessibilityHidden(true)
                            }
                            .foregroundStyle(Palette.muted)
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                        }
                        .accessibilityIdentifier("account-privacy-policy")
                        .accessibilityHint("Opens in your browser")
                        if authentication.isBusy { ProgressView().tint(Palette.ink) }
                        if let error = authentication.errorMessage {
                            Text(error).font(AppFont.text(12)).foregroundStyle(Palette.error).multilineTextAlignment(.center)
                        }
                    }
                    .padding(28)
                    .frame(maxWidth: 470)
                    .frame(maxWidth: .infinity, minHeight: geometry.size.height)
                }
            }
        }
        .disabled(authentication.isBusy)
        .background(Palette.paper.ignoresSafeArea())
        .foregroundStyle(Palette.ink)
        .toolbar(.hidden, for: .navigationBar)
        .alert("Sign out?", isPresented: $confirmSignOut) {
            Button("Cancel", role: .cancel) { }
            Button("Sign out", role: .destructive) { authentication.signOut() }
        } message: { Text("You can sign back in with Apple or Google whenever you’re ready.") }
        .alert("Delete your account?", isPresented: $confirmDelete) {
            Button("Cancel", role: .cancel) { }
            Button("Delete account", role: .destructive) { Task { await authentication.deleteAccount() } }
        } message: {
            Text("Your sudokuly account and game history will be permanently deleted. You may need to confirm with Apple or Google first.")
        }
    }
}
