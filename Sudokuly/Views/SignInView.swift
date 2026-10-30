import SwiftUI

struct SignInView: View {
    @Environment(AuthenticationSession.self) private var authentication
    @ScaledMetric(relativeTo: .body) private var versionFontSize: CGFloat = 11

    var body: some View {
        GeometryReader { geometry in
            let viewportHeight = geometry.size.height + geometry.safeAreaInsets.top + geometry.safeAreaInsets.bottom
            ScrollView {
                SignInViewportLayout(viewportHeight: viewportHeight, topInset: geometry.safeAreaInsets.top) {
                    Image("LoginSudoku")
                        .resizable()
                        .scaledToFit()
                        .accessibilityHidden(true)
                    loginContent
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            .ignoresSafeArea(edges: .bottom)
        }
        .background(Palette.paper.ignoresSafeArea())
        .foregroundStyle(Palette.ink)
    }

    private var loginContent: some View {
        VStack(spacing: 28) {
            VStack(spacing: 14) {
                Text("A cleaner\nway to Sudoku.")
                    .font(AppFont.relativeText(36, weight: .semibold, relativeTo: .largeTitle))
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("sign-in-headline")
                Text("Sign in to fill your first grid.")
                    .font(AppFont.relativeText(17))
                    .foregroundStyle(Palette.muted)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("sign-in-description")
            }
            VStack(spacing: 14) {
                ProviderSignInButton(provider: .apple) {
                    Task { await authentication.signInWithApple() }
                }
                ProviderSignInButton(provider: .google) {
                    Task { await authentication.signInWithGoogle() }
                }
            }
            .disabled(authentication.isBusy || authentication.configurationError != nil)
            if let error = authentication.configurationError ?? authentication.errorMessage {
                Text(error)
                    .font(AppFont.relativeText(15))
                    .foregroundStyle(Palette.error)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("auth-error")
            }
            VStack(spacing: 20) {
                VStack(spacing: 7) {
                    Text("By signing in, you acknowledge our")
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier("privacy-notice")
                    HStack(spacing: 4) {
                        Link(destination: AppLinks.privacyPolicy) {
                            HStack(spacing: 5) {
                                Text("Privacy Policy")
                                SignInExternalLinkIcon()
                                    .fill(Palette.muted)
                                    .frame(width: 12, height: 12)
                                    .accessibilityHidden(true)
                            }
                        }
                        .tint(Palette.muted)
                        .accessibilityIdentifier("sign-in-privacy-policy")
                        .accessibilityHint("Opens the privacy policy in your browser")
                        Text("terms.")
                            .accessibilityIdentifier("privacy-terms")
                    }
                }
                .font(AppFont.relativeText(13))

                Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—")")
                    .font(.system(size: versionFontSize, weight: .regular, design: .monospaced))
                    .accessibilityIdentifier("appVersion")
            }
            .foregroundStyle(Palette.muted)
        }
    }
}

/// Aligns the illustration's bottom with the screen midpoint, preserving room for sign-in content.
private struct SignInViewportLayout: Layout {
    let viewportHeight: CGFloat
    let topInset: CGFloat
    private let preferredLogoSize: CGFloat = 220
    private let gap: CGFloat = 24
    private var bottomInset: CGFloat { viewportHeight * 0.05 }

    private func footerWidth(_ width: CGFloat) -> CGFloat {
        min(420, max(0, width - 56))
    }

    private func logoSize(footerHeight: CGFloat) -> CGFloat {
        let available = viewportHeight - topInset - 24 - gap - footerHeight - bottomInset
        return min(preferredLogoSize, max(160, available))
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 390
        let footer = subviews[1].sizeThatFits(.init(width: footerWidth(width), height: nil))
        let logoSize = logoSize(footerHeight: footer.height)
        let minimumHeight = 24 + logoSize + gap + footer.height + bottomInset
        return CGSize(width: width, height: max(viewportHeight - topInset, minimumHeight))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let width = footerWidth(bounds.width)
        let footer = subviews[1].sizeThatFits(.init(width: width, height: nil))
        let logoSize = logoSize(footerHeight: footer.height)
        let footerTop = bounds.maxY - bottomInset - footer.height
        let preferredLogoBottom = bounds.minY + max(viewportHeight * 0.5 - topInset, 24 + logoSize)
        let logoBottom = min(preferredLogoBottom, footerTop - gap)
        subviews[0].place(at: CGPoint(x: bounds.midX, y: logoBottom), anchor: .bottom,
                          proposal: .init(width: logoSize, height: logoSize))
        subviews[1].place(at: CGPoint(x: bounds.midX, y: footerTop), anchor: .top,
                          proposal: .init(width: width, height: footer.height))
    }
}

private struct SignInExternalLinkIcon: Shape {
    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 24
        let origin = CGPoint(x: rect.midX - 12 * scale, y: rect.midY - 12 * scale)
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: origin.x + x * scale, y: origin.y + y * scale)
        }
        var arrow = Path()
        arrow.move(to: point(4, 20))
        arrow.addLine(to: point(20, 4))
        arrow.move(to: point(8, 4))
        arrow.addLine(to: point(20, 4))
        arrow.addLine(to: point(20, 16))
        return arrow.strokedPath(StrokeStyle(lineWidth: 3 * scale, lineCap: .butt, lineJoin: .round))
    }
}
