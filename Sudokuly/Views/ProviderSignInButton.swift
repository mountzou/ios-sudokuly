import SwiftUI

struct ProviderSignInButton: View {
    enum Provider {
        case google, apple

        var title: String { self == .google ? "Sign in with Google" : "Sign in with Apple" }
        var identifier: String { self == .google ? "sign-in-google" : "sign-in-apple" }
    }

    let provider: Provider
    let action: () -> Void
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                logo
                    .frame(width: 20, height: 20)
                    .accessibilityHidden(true)
                // Both providers reserve the widest label, as in Flytly.
                ZStack(alignment: .leading) {
                    Text(Provider.apple.title).hidden().accessibilityHidden(true)
                    Text(Provider.google.title).hidden().accessibilityHidden(true)
                    Text(provider.title)
                }
                .font(AppFont.relativeText(17, weight: .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .foregroundStyle(provider == .apple ? Color.white : Palette.ink)
            .background(provider == .apple ? Color.black : Color.white,
                        in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(provider == .google ? Color.gray.opacity(0.5) : .clear, lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 12))
            .opacity(isEnabled ? 1 : 0.5)
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel(provider.title)
        .accessibilityIdentifier(provider.identifier)
    }

    @ViewBuilder
    private var logo: some View {
        if provider == .google {
            Image("GoogleSignInMark")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 18, height: 18)
        } else {
            Image(systemName: "apple.logo")
                .resizable()
                .scaledToFit()
        }
    }
}
