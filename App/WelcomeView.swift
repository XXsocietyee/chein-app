import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject private var session: AppSession
    var onBrowse: (() -> Void)? = nil
    private enum Destination: Identifiable {
        case settings, login(RegistrationIntent)
        var id: String {
            switch self {
            case .settings: return "settings"
            case .login(let intent): return "login-" + intent.rawValue
            }
        }
    }
    @State private var destination: Destination?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CYSpacing.xl) {
                    WelcomeHero().padding(.top, CYSpacing.lg)
                    VStack(alignment: .leading, spacing: CYSpacing.md) {
                        Text("welcome.title")
                            .font(.system(.largeTitle, design: .rounded).weight(.heavy))
                            .foregroundStyle(CYColor.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                        Text("role.player.detail")
                            .font(CYTypography.body)
                            .foregroundStyle(CYColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let key = WelcomeSessionPresentation.upgradeNoticeKey(errorKey: session.errorKey, accountID: session.account?.id) {
                        Label(LocalizedStringKey(key), systemImage: "arrow.up.circle")
                            .font(CYTypography.bodyCompact)
                            .foregroundStyle(CYColor.textSecondary)
                            .accessibilityIdentifier("welcome.upgradeRequired")
                    }
                }
                .padding(.horizontal, CYSpacing.xxl)
                .padding(.top, CYSpacing.hero)
                .frame(maxWidth: 620, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .background(CYColor.bgPage)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: CYSpacing.md) {
                    // One primary action per screen: players register first; merchants are the outlined secondary.
                    roleButton(.player, title: "role.player", primary: true)
                    roleButton(.merchant, title: "role.merchant", primary: false)
                    if let onBrowse {
                        Button("welcome.browse", action: onBrowse)
                            .font(CYTypography.bodyCompact.weight(.semibold))
                            .foregroundStyle(CYColor.textSecondary)
                            .frame(minHeight: CYSpacing.minTouchTarget)
                            .accessibilityIdentifier("welcome.browse")
                    }
                }
                .padding(.horizontal, CYSpacing.xxl)
                .padding(.bottom, onBrowse == nil ? 84 : CYSpacing.lg) // clear the floating tab bar when shown as the Me tab
                .padding(.top, CYSpacing.md)
                .frame(maxWidth: 620)
                .frame(maxWidth: .infinity)
                .background(CYColor.bgPage)
            }
            .appNavigationTitle("Questify")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Language, saved drafts and settings live in one quiet menu.
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        NavigationLink { OwnerDraftGuestView() } label: { Label("ownerDraft.title", systemImage: "doc.on.doc") }
                            .accessibilityIdentifier("ownerDraft.guestEntry")
                        Button("settings.title", systemImage: "gearshape") { destination = .settings }
                            .accessibilityIdentifier("welcome.settings")
                        LanguageSwitcher()
                    } label: {
                        Image(systemName: "ellipsis.circle").accessibilityLabel(Text("settings.title"))
                    }
                    .accessibilityIdentifier("welcome.more")
                }
            }
            .sheet(item: $destination) { destination in
                switch destination {
                case .settings: SettingsView()
                case .login(let intent): LoginView(intent: intent)
                }
            }
        }
    }

    private func roleButton(_ role: RegistrationIntent, title: LocalizedStringKey, primary: Bool) -> some View {
        Button { destination = .login(role) } label: { Text(title) }
            .buttonStyle(RoleButtonStyle(primary: primary))
            .accessibilityIdentifier("welcome.\(role.rawValue)")
    }
}

/// Full-width pill: filled for the primary role, outlined for the secondary.
private struct RoleButtonStyle: ButtonStyle {
    let primary: Bool
    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: CYRadius.pill, style: .continuous)
        configuration.label
            .font(CYTypography.label)
            .foregroundStyle(primary ? CYColor.textOnAccent : CYColor.textPrimary)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(primary ? AnyShapeStyle(configuration.isPressed ? CYColor.accentPressed : CYColor.accent) : AnyShapeStyle(Color.clear), in: shape)
            .overlay(shape.strokeBorder(primary ? Color.clear : CYColor.borderStrong, lineWidth: 1.5))
            .shadow(color: .black.opacity(primary ? 0.3 : 0), radius: 10, y: 4)
            .contentShape(shape)
    }
}

#Preview("English") { WelcomeView().environmentObject(AppSession()).environment(\.locale, Locale(identifier: "en")) }
#Preview("简体中文 · Large type") {
    WelcomeView().environmentObject(AppSession()).environment(\.locale, Locale(identifier: "zh-Hans"))
        .environment(\.dynamicTypeSize, .accessibility3)
}
#Preview("Dark") { WelcomeView().environmentObject(AppSession()).preferredColorScheme(.dark) }


/// Decorative collage of three tilted place cards (placeholder tiles; real imagery replaces the symbols later).
private struct WelcomeHero: View {
    var body: some View {
        ZStack {
            tile("fork.knife", angle: -9, x: -86, y: 18, size: 150)
            tile("ticket", angle: 8, x: 92, y: 34, size: 138)
            tile("map", angle: -2, x: 0, y: -8, size: 176)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 250)
        .accessibilityHidden(true)
    }

    private func tile(_ symbol: String, angle: Double, x: CGFloat, y: CGFloat, size: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: CYRadius.xl, style: .continuous)
            .fill(CYColor.bgElevated)
            .overlay(RoundedRectangle(cornerRadius: CYRadius.xl, style: .continuous).strokeBorder(CYColor.borderStrong.opacity(0.5), lineWidth: 1))
            .overlay(Image(systemName: symbol).font(.system(size: size * 0.34, weight: .semibold)).foregroundStyle(CYColor.textPrimary.opacity(0.9)))
            .frame(width: size, height: size * 1.2)
            .rotationEffect(.degrees(angle))
            .offset(x: x, y: y)
            .shadow(color: .black.opacity(0.5), radius: 14, y: 8)
    }
}
