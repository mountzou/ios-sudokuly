import SwiftUI

enum Palette {
    static let ink = Color(red: 0.12, green: 0.13, blue: 0.12)
    static let muted = Color(red: 0.43, green: 0.44, blue: 0.43)
    static let paper = Color(red: 0.955, green: 0.955, blue: 0.945)
    static let line = Color.black.opacity(0.075)
    static let error = Color(red: 0.69, green: 0.24, blue: 0.22)
}

enum AppFont {
    static let postScriptName = "BricolageGrotesque-96ptExtraBold"

    static func relativeText(_ size: CGFloat, weight: Font.Weight = .regular,
                             relativeTo style: Font.TextStyle = .body) -> Font {
        .custom(postScriptName, size: size, relativeTo: style).weight(weight)
    }

    static func text(_ size: CGFloat, weight: UIFont.Weight = .regular, scaled: Bool = true) -> Font {
        let weighted = uiFont(size, weight: weight)
        return Font(scaled ? UIFontMetrics.default.scaledFont(for: weighted) : weighted)
    }

    static func uiFont(_ size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        let face: String
        switch weight {
        case .bold: face = "Bold"
        case .semibold: face = "SemiBold"
        case .medium: face = "Medium"
        default: face = "Regular"
        }
        // Use the bundled variable font's registered PostScript instance names.
        return UIFont(name: "\(postScriptName)_\(face)", size: size) ?? UIFont.systemFont(ofSize: size, weight: weight)
    }
}

struct BrandMark: View {
    var small = false
    var body: some View {
        HStack(spacing: 9) {
            Grid(horizontalSpacing: 2, verticalSpacing: 2) {
                ForEach(0..<3) { row in
                    GridRow {
                        ForEach(0..<3) { column in
                            RoundedRectangle(cornerRadius: 1.1)
                                .fill(Palette.ink.opacity(row == 0 && column == 2 || row == 2 && column == 0 ? 0.2 : 1))
                                .frame(width: small ? 4 : 5, height: small ? 4 : 5)
                        }
                    }
                }
            }
            Text("sudokuly")
                .font(AppFont.text(small ? 21 : 26, weight: .bold))
                .tracking(-1)
        }
        .foregroundStyle(Palette.ink)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("sudokuly")
    }
}

struct CircleIcon: View {
    let symbol: String
    let label: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            AppSymbol(symbol: symbol, size: 18, weight: .semibold)
                .frame(width: 46, height: 46)
                .background(Palette.paper, in: Circle())
                .foregroundStyle(Palette.ink)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

struct PrimaryButton: View {
    let title: String
    var symbol: String? = "arrow.right"
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack {
                Spacer()
                Text(title).font(AppFont.text(16, weight: .semibold))
                Spacer()
                if let symbol {
                    AppSymbol(symbol: symbol, size: 15, weight: .semibold)
                }
            }
            .padding(.horizontal, 22)
            .frame(minHeight: 58)
            .foregroundStyle(.white)
            .background(Palette.ink, in: Capsule())
        }
        .buttonStyle(PressStyle())
    }
}

struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.65 : 1)
    }
}

func clockText(_ seconds: TimeInterval) -> String {
    let value = max(0, Int(ceil(seconds)))
    return String(format: "%02d:%02d", value / 60, value % 60)
}
