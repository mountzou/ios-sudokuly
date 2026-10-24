import SwiftUI

struct IllustratedContentWidth: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 32)
            .frame(maxWidth: 450)
    }
}

struct IllustratedMessageHeader: View {
    let illustration: String
    let title: String
    let message: String
    let titleID: String
    var messageID: String? = nil
    var titleSize: CGFloat = 30
    var titleWeight: UIFont.Weight = .bold
    var titleTracking: CGFloat = -1.1
    var messageSize: CGFloat = 14
    var titleMessageSpacing: CGFloat = 22

    var body: some View {
        VStack(spacing: 22) {
            Image(illustration)
                .resizable()
                .scaledToFit()
                .frame(width: 160, height: 160)
                .accessibilityHidden(true)
            VStack(spacing: titleMessageSpacing) {
                Text(title)
                    .font(AppFont.text(titleSize, weight: titleWeight)).tracking(titleTracking)
                    .frame(maxWidth: .infinity)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier(titleID)
                Text(message)
                    .font(AppFont.text(messageSize)).foregroundStyle(Palette.muted)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier(messageID ?? "\(titleID)-message")
            }
        }
        .multilineTextAlignment(.center)
        .foregroundStyle(Palette.ink)
        .frame(maxWidth: .infinity)
    }
}
