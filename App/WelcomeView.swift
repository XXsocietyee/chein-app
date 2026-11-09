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
                VStack(alignment: .leading, spacing: 20) {
                    Image(systemName: "map")
                        .font(.title2.weight(.semibold))
                        .frame(width: 56, height: 56)
                        .background(Color(uiColor: .secondarySystemFill), in: Circle())
                        .accessibilityHidden(true)
                    Text("welcome.title")
                        .font(CYTypography.display)
                        .foregroundStyle(CYColor.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    if let key = WelcomeSessionPresentation.upgradeNoticeKey(errorKey: session.errorKey, accountID: session.account?.id) {
                        Label(LocalizedStringKey(key), systemImage: "arrow.up.circle")
                            .accessibilityIdentifier("welcome.upgradeRequired")
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 32)
                .frame(maxWidth: 620, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 12) {
                    roleButton(.player, title: "role.player", detail: "role.player.detail", symbol: "figure.walk", primary: true)
                    roleButton(.merchant, title: "role.merchant", detail: "role.merchant.detail", symbol: "storefront")
                    HStack(spacing: 24) {
                        NavigationLink { OwnerDraftGuestView() } label: { Label("ownerDraft.title", systemImage: "doc.on.doc") }
                            .accessibilityIdentifier("ownerDraft.guestEntry")
                        if let onBrowse {
                            Button("welcome.browse", action: onBrowse)
                                .accessibilityIdentifier("welcome.browse")
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, onBrowse == nil ? 84 : 16) // clear the floating tab bar when shown as the Me tab
                .padding(.top, 12)
                .frame(maxWidth: 620)
                .frame(maxWidth: .infinity)
                .background(.bar)
            }
            .appNavigationTitle("Questify")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { LanguageSwitcher() }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("settings.title", systemImage: "gearshape") { destination = .settings }
                        .accessibilityIdentifier("welcome.settings")
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

    private func roleButton(_ role: RegistrationIntent, title: LocalizedStringKey,
                            detail: LocalizedStringKey, symbol: String, primary: Bool = false) -> some View {
        Button { destination = .login(role) } label: {
            HStack(alignment: .top, spacing: 16) {
                Image(systemName: symbol).font(.title2).accessibilityHidden(true)
                // Title only: ui-spec allows no subtitle captions under rows.
                Text(title).font(CYTypography.cardTitle)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary).accessibilityHidden(true)
            }
            .foregroundStyle(primary ? Color(uiColor: .systemBackground) : .primary)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .modifier(WelcomeRoleSurface(primary: primary))
        }
        // One primary action per screen: players register first; merchants are the quiet secondary.
        .buttonStyle(QuestifyCardButtonStyle())
        .accessibilityIdentifier("welcome.\(role.rawValue)")
    }
}

private struct WelcomeRoleSurface: ViewModifier {
    let primary: Bool
    func body(content: Content) -> some View {
        if primary {
            content.padding(16).background(QuestifyPalette.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        } else {
            content.questifyCardSurface()
        }
    }
}

#Preview("English") { WelcomeView().environmentObject(AppSession()).environment(\.locale, Locale(identifier: "en")) }
#Preview("简体中文 · Large type") {
    WelcomeView().environmentObject(AppSession()).environment(\.locale, Locale(identifier: "zh-Hans"))
        .environment(\.dynamicTypeSize, .accessibility3)
}
#Preview("Dark") { WelcomeView().environmentObject(AppSession()).preferredColorScheme(.dark) }
