import SwiftUI

struct SettingsView: View {
    var onOpenGuideDestination: ((SocialGuideDestination) -> Void)? = nil
    @EnvironmentObject private var session: AppSession
    @StateObject private var profileOwner = ProfileSettingsProfileOwner()
    @State private var favoritesOwner = ProfileSettingsFavoritesOwner()
    @AppStorage(AppLanguage.storageKey) private var storedLanguage = RegionalLaunchConfiguration.language(nil).rawValue
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
#if DEBUG
    /// Design fixtures only: stub signed-in identity and search text injected into the real page.
    struct DesignOverride { var nickname = "Mia Chen"; var level = 7; var query = "" }
    var designOverride: DesignOverride?
#endif

    private var accountInfo: (nickname: String, level: Int)? {
#if DEBUG
        if let designOverride { return (designOverride.nickname, designOverride.level) }
#endif
        return session.account.map { ($0.nickname, $0.level) }
    }

    @ViewBuilder private var accountHeader: some View {
        Section {
            if let info = accountInfo {
                if let route = profileOwner.route(.current(session)) {
                    NavigationLink(value: route) { SettingsAccountCard(nickname: info.nickname, level: info.level, tappable: true) }
                        .accessibilityIdentifier("settingsNative.openProfile")
                } else {
                    SettingsAccountCard(nickname: info.nickname, level: info.level, tappable: false)
                }
            } else {
                Label { Text("member.settings.signedOut", tableName: "MemberProfile") } icon: { Image(systemName: "person.crop.circle") }
                    .accessibilityIdentifier("settingsNative.profileSignedOut")
            }
        }
        .listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
    }

    private var language: Binding<AppLanguage> {
        Binding(get: { RegionalLaunchConfiguration.language(storedLanguage) },
                set: { storedLanguage = $0.rawValue })
    }

    var body: some View {
        NavigationStack {
            Group {
            if !query.trimmingCharacters(in: .whitespaces).isEmpty {
                SettingsSearchResults(query: query, session: session, language: language)
            } else {
            Form {
                // Mini-program pages/shezhi order: 个人资料, 成为俱乐部主理人/成为商家, 城瘾玩法, 我的收藏.
                accountHeader
                SettingsIdentityApplicationEntries(session: session).environment(\.settingsTileTint, SettingsTint.orange)
                Section {
                    NavigationLink {
                        ProfileGuideHost(reader: session.makeProfileGuideReader(),
                            makeArticleReader: { session.makeProfileGuideArticleReader($0) },
                            onOpenDestination: onOpenGuideDestination, templateReader: session)
                            .id(session.socialAccountReader.identity)
                    } label: { Label("social.guide.title", systemImage: "questionmark.circle") }
                        .accessibilityIdentifier("settings.playGuide")
                }
                .environment(\.settingsTileTint, SettingsTint.teal)
                ProfileSettingsFavoritesEntry(session: session, owner: favoritesOwner).environment(\.settingsTileTint, SettingsTint.pink)
                SettingsPrivacyLocationEntry(session: session).environment(\.settingsTileTint, SettingsTint.green)
                Section {
                    NativeNotificationPermissionEntry()
                    NativeChannelNotificationSettingsEntry(session: session)
                } header: {
                    Text("notification.global.title", tableName: "NativeChannelNotification")
                }
                .environment(\.settingsTileTint, SettingsTint.red)
                UsageConsentReadSettingsEntry(session: session).environment(\.settingsTileTint, SettingsTint.indigo)
                Section {
                    LabeledContent { Text(verbatim:RegionalLaunchConfiguration.market?.rawValue ?? "—").accessibilityIdentifier("region.market.value") } label: { Text("region.market") }
                }
                Section {
                    Picker("settings.language", selection: language) {
                        Text("language.system").tag(AppLanguage.system)
                        Text(verbatim: "English").tag(AppLanguage.english)
                        Text(verbatim: "简体中文").tag(AppLanguage.simplifiedChinese)
                    }
                    .pickerStyle(.menu)
                } footer: {
                    Text("settings.languageNotice")
                }
                .environment(\.settingsTileTint, SettingsTint.blue)
                MemberScoreAppealSettingsEntry(session: session).environment(\.settingsTileTint, SettingsTint.purple)
                SettingsInvoiceEntry(session: session).environment(\.settingsTileTint, SettingsTint.purple)
                NPCChatDataReadSettingsEntry(session: session).environment(\.settingsTileTint, SettingsTint.indigo)
                SettingsSupportSafetyEntry().environment(\.settingsTileTint, SettingsTint.teal)
                SettingsSupportSections(market: session.operationalMarket, complianceCoordinator: session.accountComplianceCoordinator)
                SettingsSignOutEntry(session: session) { dismiss() }
            }
            .labelStyle(SettingsTileLabelStyle())
            }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: Text("settings.search.prompt"))
            .scrollContentBackground(.hidden)
            .cyDomainPageBackground()
            .listSectionSpacing(.custom(20))
            .modifier(ProfileSettingsProfileNavigation(session: session, owner: profileOwner))
            .modifier(ProfileSettingsFavoritesNavigation(session: session, owner: favoritesOwner))
            .appNavigationTitle("settings.title")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("action.done") { dismiss() }
                }
            }
        }
        .onAppear {
            profileOwner.appear()
#if DEBUG
            if let q = designOverride?.query, query.isEmpty { query = q }
#endif
        }
        .onDisappear { profileOwner.retire() }
        .modifier(ProfileSettingsFavoritesLifecycle(session: session, owner: favoritesOwner))
        // Explicitly update sheets as well as the app root when preference changes.
        .modifier(AppLanguageEnvironment(stored: storedLanguage))
    }
}

/// One sheet presentation can hand a mode action back to its root only once,
/// after dismissal. Old dismissal callbacks cannot consume a newer request.
struct SettingsGuideHandoff {
    private(set) var presentation = UUID()
    private var active = false
    private var pending: (() -> Void)?
    mutating func begin() -> Bool {
        guard !active, pending == nil else { return false }
        presentation = UUID(); active = true; return true
    }
    mutating func request(_ id: UUID, action: @escaping () -> Void) -> Bool {
        guard active, id == presentation, pending == nil else { return false }
        active = false; pending = action; return true
    }
    mutating func finish(_ id: UUID) -> (() -> Void)? {
        guard id == presentation else { return nil }
        active = false
        let action = pending; pending = nil
        return action
    }
}


/// Muted iOS Settings tile colours: one hue per group of rows, never neon.
enum SettingsTint {
    static let blue = Color(red: 0.04, green: 0.52, blue: 1.0)
    static let green = Color(red: 0.19, green: 0.72, blue: 0.35)
    static let orange = Color(red: 1.0, green: 0.58, blue: 0.0)
    static let red = Color(red: 1.0, green: 0.27, blue: 0.23)
    static let pink = Color(red: 1.0, green: 0.31, blue: 0.48)
    static let purple = Color(red: 0.69, green: 0.32, blue: 0.87)
    static let indigo = Color(red: 0.35, green: 0.34, blue: 0.84)
    static let teal = Color(red: 0.19, green: 0.69, blue: 0.78)
    static let gray = Color(red: 0.56, green: 0.56, blue: 0.58)
}
private struct SettingsTileTintKey: EnvironmentKey { static let defaultValue: Color = SettingsTint.gray }
extension EnvironmentValues {
    var settingsTileTint: Color {
        get { self[SettingsTileTintKey.self] }
        set { self[SettingsTileTintKey.self] = newValue }
    }
}

/// Account header card: art backdrop, initial avatar, name, level. Image-led like the Phantom and Instagram settings headers.
struct SettingsAccountCard: View {
    let nickname: String
    let level: Int
    let tappable: Bool
    var body: some View {
        HStack(spacing: CYSpacing.lg) {
            Text(verbatim: String(nickname.trimmingCharacters(in: .whitespaces).prefix(1)).uppercased())
                .font(.system(.title, design: .rounded, weight: .bold)).foregroundStyle(.white)
                .frame(width: 60, height: 60)
                .background(Circle().fill(.white.opacity(0.22)))
                .overlay(Circle().strokeBorder(.white.opacity(0.5), lineWidth: 1.5))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: nickname.isEmpty ? "—" : nickname).font(.system(.title3, weight: .semibold)).foregroundStyle(.white)
                    .lineLimit(2)
                Text("settings.account.subtitle \(level)").font(.subheadline).foregroundStyle(.white.opacity(0.85))
            }
            Spacer(minLength: 0)
            if tappable { Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.white.opacity(0.8)).accessibilityHidden(true) }
        }
        .padding(CYSpacing.lg)
        .background {
            ZStack {
                CYCoverArt(seed: "account-" + nickname, symbol: "person", showsDebugLabel: false, showsGlyph: false)
                LinearGradient(colors: [.black.opacity(0.05), .black.opacity(0.45)], startPoint: .top, endPoint: .bottom)
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .accessibilityElement(children: .combine)
    }
}

/// Search results: a flat list of the destinations that can be opened without extra context.
/// Matches the title, an English or Chinese keyword, or the destination group.
private struct SettingsSearchResults: View {
    let query: String
    let session: AppSession
    let language: Binding<AppLanguage>
    @Environment(\.locale) private var locale
    private struct Entry: Identifiable {
        let id: String; let key: String; let symbol: String; let tint: Color; let words: String
    }
    private let entries = [
        Entry(id: "sound", key: "settingsNative.sound.title", symbol: "speaker.wave.2.fill", tint: SettingsTint.pink, words: "sound haptics vibration audio 声音 触感 震动"),
        Entry(id: "agreement", key: "settingsNative.legal.user_agreement", symbol: "doc.text.fill", tint: SettingsTint.gray, words: "terms user agreement legal 协议 条款"),
        Entry(id: "privacy", key: "settingsNative.legal.privacy_policy", symbol: "hand.raised.fill", tint: SettingsTint.blue, words: "privacy policy data 隐私 政策"),
        Entry(id: "about", key: "settingsNative.about.title", symbol: "info.circle.fill", tint: SettingsTint.gray, words: "about version build 关于 版本"),
        Entry(id: "marketing", key: "compliance.marketing", symbol: "megaphone.fill", tint: SettingsTint.orange, words: "marketing consent promotions coupons 营销 偏好 授权"),
        Entry(id: "roam", key: "compliance.roam", symbol: "location.fill", tint: SettingsTint.green, words: "roam location consent tracking 漫游 定位 授权"),
        Entry(id: "close", key: "compliance.cancellation", symbol: "person.crop.circle.badge.minus", tint: SettingsTint.red, words: "close delete deregister account 注销 删除 账号"),
        Entry(id: "language", key: "settings.language", symbol: "globe", tint: SettingsTint.blue, words: "language english chinese 语言 中文"),
    ]
    private func title(_ e: Entry) -> String { appLocalized(String.LocalizationValue(stringLiteral: e.key), locale: locale) }
    private var matches: [Entry] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        return entries.filter { title($0).lowercased().contains(q) || $0.words.lowercased().contains(q) }
    }
    var body: some View {
        Form {
            if matches.isEmpty {
                ContentUnavailableView.search(text: query).listRowBackground(Color.clear)
            } else {
                Section {
                    ForEach(matches) { e in row(e) }
                } header: { Text("settings.search.results") }
            }
        }
        .scrollContentBackground(.hidden)
        .labelStyle(SettingsTileLabelStyle())
    }
    @ViewBuilder private func row(_ e: Entry) -> some View {
        let label = Label(LocalizedStringKey(e.key), systemImage: e.symbol).environment(\.settingsTileTint, e.tint)
        switch e.id {
        case "sound": NavigationLink { SettingsSoundPreferencesView(store: SettingsLocalSoundStore()) } label: { label }
        case "agreement": NavigationLink { SettingsLegalDocumentView(type: .userAgreement, market: session.operationalMarket, reader: session.legalReader) } label: { label }
        case "privacy": NavigationLink { SettingsLegalDocumentView(type: .privacyPolicy, market: session.operationalMarket, reader: session.legalReader) } label: { label }
        case "about": NavigationLink { SettingsAboutView(market: session.operationalMarket, appInformation: .current(), legalReader: session.legalReader) } label: { label }
        case "marketing", "roam", "close":
            if let c = session.accountComplianceCoordinator {
                NavigationLink {
                    AccountComplianceSheet(coordinator: c, destination: e.id == "marketing" ? .marketing : (e.id == "roam" ? .roam : .cancellation),
                                           market: session.operationalMarket, legalReader: session.legalReader, showsCloseButton: false)
                } label: { label }
            } else { label }
        default:
            Picker(selection: language) {
                Text("language.system").tag(AppLanguage.system)
                Text(verbatim: "English").tag(AppLanguage.english)
                Text(verbatim: "简体中文").tag(AppLanguage.simplifiedChinese)
            } label: { label }
            .pickerStyle(.menu)
        }
    }
}
