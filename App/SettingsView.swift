import SwiftUI

struct SettingsView: View {
    var onOpenGuideDestination: ((SocialGuideDestination) -> Void)? = nil
    /// mp-nav r3: true when the page is pushed onto a host stack (a pages/shezhi/shezhi link landing on 首页):
    /// no second stack, no 完成 (system back), and the profile row pushes by view, since the host path is `[AppRoute]`.
    var isPushed: Bool = false
    @EnvironmentObject private var session: AppSession
    @StateObject private var profileOwner = ProfileSettingsProfileOwner()
    @State private var favoritesOwner = ProfileSettingsFavoritesOwner()
    @AppStorage(AppLanguage.storageKey) private var storedLanguage = RegionalLaunchConfiguration.language(nil).rawValue
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var showsSignIn = false
    /// Fresh `POST /api/user/info`. Nil until that read returns. The page does not paint a role from the cached session.
    @State private var accountAccess: SettingsAccountProfileAccess?
    @State private var accountProfileLoading = true
    /// Nickname from `settingsProfileForm`. Phone is not stored here.
    @State private var contractNickname: String?
    /// Level is not on the contract. Kept from the signed-in account only after that read succeeds.
    @State private var contractLevel: Int?
#if DEBUG
    /// Design fixtures only: stub signed-in identity and search text injected into the real page.
    struct DesignOverride { var nickname = "Mia Chen"; var level = 7; var query = "" }
    var designOverride: DesignOverride?
#endif

    private var accountInfo: (nickname: String, level: Int)? {
#if DEBUG
        if let designOverride { return (designOverride.nickname, designOverride.level) }
#endif
        guard readyAccountProfile != nil, let nickname = contractNickname, !nickname.isEmpty else { return nil }
        return (nickname, contractLevel ?? 0)
    }

    private var readyAccountProfile: SettingsAccountProfile? {
        if case .ready(let profile) = accountAccess { return profile }
        return nil
    }
    private var showsAccountCard: Bool {
#if DEBUG
        if designOverride != nil { return accountInfo != nil }
#endif
        return readyAccountProfile != nil && accountInfo != nil
    }
    private var showsSignedOut: Bool {
#if DEBUG
        if designOverride != nil { return false }
#endif
        if accountProfileLoading { return false }
        if case .signedOut = accountAccess { return true }
        return accountAccess == nil && session.account == nil
    }

    @ViewBuilder private var accountHeader: some View {
        Section {
            if showsAccountCard, let info = accountInfo {
                if let route = profileOwner.route(.current(session)) {
                    // MP shezhi.wxml:14: the merchant row (品牌中心) carries icon_lc_store; players keep the initial avatar.
                    if !isPushed {
                        NavigationLink(value: route) { SettingsAccountCard(nickname: info.nickname, level: info.level, tappable: true,
                                                                           brandMark: route.access.target == .brand) }
                            .accessibilityIdentifier("settingsNative.openProfile")
                    } else {
                        NavigationLink {
                            ProfileSettingsProfileSessionDestination(session: session, route: route, owner: profileOwner)
                        } label: {
                            SettingsAccountCard(nickname: info.nickname, level: info.level, tappable: true, brandMark: route.access.target == .brand)
                        }
                        .accessibilityIdentifier("settingsNative.openProfile")
                    }
                } else {
                    SettingsAccountCard(nickname: info.nickname, level: info.level, tappable: false)
                }
            } else if showsSignedOut {
                // B-SZ-04: the MP signed-out row starts sign-in.
                Button { showsSignIn = true } label: {
                    Label { Text("member.settings.signedOut", tableName: "MemberProfile") } icon: { AccountPublishMPGlyph(MPAsset.FeatureIcon.iconQaPerson) }
                }
                .accessibilityIdentifier("settingsNative.profileSignedOut")
            }
            // pages/shezhi: `SettingsHomePage` phases beyond signed-in/out. Loading and error say so; an unknown
            // role or market says so instead of falling through to the player rows.
            switch homeFacts.phase {
            case .loading, .unknown:
                settingsPhaseLabel
            case .error:
                if homeFacts.retriesProfileOnTap {
                    Button { Task { await refreshAccountProfile() } } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(verbatim: SettingsAccountProfileClient.deniedCopy)
                                    .foregroundStyle(.primary)
                                Text(verbatim: SettingsAccountProfileClient.deniedRetry)
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                        } icon: {
                            AccountPublishMPGlyph(MPAsset.FeatureIcon.iconQaPerson).accessibilityHidden(true)
                        }
                    }
                    // B-SZ-09: a second tap while the read is in flight is dropped; the system list row is 44 pt.
                    .disabled(accountProfileLoading)
                    .accessibilityIdentifier(homeFacts.accessibilityIdentifier)
                } else {
                    settingsPhaseLabel
                }
            case .empty, .ready:
                EmptyView()
            }
        }
    }

    private var settingsPhaseLabel: some View {
        Label {
            Text(LocalizedStringKey(homeFacts.copyKey), tableName: "MemberProfile")
        } icon: {
            Image(systemName: homeFacts.phase == .loading ? "hourglass" : homeFacts.phase == .error ? "exclamationmark.triangle" : "questionmark.circle")
                .accessibilityHidden(true)
        }
        .foregroundStyle(.secondary)
        .accessibilityAddTraits(homeFacts.phase == .loading ? .updatesFrequently : .isStaticText)
        .accessibilityIdentifier(homeFacts.accessibilityIdentifier)
    }

    /// Role and denial come from `AccountPublishMPContract.settingsAccess`, not the cached session account.
    private var homeFacts: SettingsHomePage.Facts {
#if DEBUG
        if designOverride != nil { return SettingsHomePage.facts(session: .signedIn(role: "player"), market: session.operationalMarket ?? .china) }
#endif
        let fact: SettingsHomePage.SessionFact
        if accountProfileLoading || accountAccess == nil {
            fact = SettingsHomePage.sessionFact(loading: true, failed: false, role: nil)
        } else {
            switch accountAccess {
            case .ready(let profile):
                fact = SettingsHomePage.sessionFact(loading: false, failed: false, role: profile.role)
            case .denied:
                fact = SettingsHomePage.sessionFact(loading: false, failed: false, role: nil, accessDenied: true)
            case .signedOut:
                fact = SettingsHomePage.sessionFact(loading: false, failed: false, role: nil)
            case .failed:
                fact = SettingsHomePage.sessionFact(loading: false, failed: true, role: nil)
            case nil:
                fact = SettingsHomePage.sessionFact(loading: true, failed: false, role: nil)
            }
        }
        return SettingsHomePage.facts(session: fact, market: session.operationalMarket)
    }

    private func refreshAccountProfile() async {
#if DEBUG
        if designOverride != nil {
            accountAccess = .ready(SettingsAccountProfile(role: "player", isClubLeader: false))
            accountProfileLoading = false
            return
        }
#endif
        accountProfileLoading = true
        defer { accountProfileLoading = false }
        guard let memberID = session.account?.id, memberID > 0,
              let token = session.token, AuthRequestBuilder.isValidToken(token),
              let api = session.regionalConfiguration?.apiConfiguration else {
            accountAccess = session.account == nil ? .signedOut : .failed
            contractNickname = nil
            contractLevel = nil
            return
        }
        do {
            let request = try AccountPublishMPContract.userInfoRequest(baseURL: api.baseURL, memberID: String(memberID), token: token)
            let (data, status) = try await session.runtimeHTTPTransport.send(request)
            switch AccountPublishMPContract.settingsAccess(status: status, body: data) {
            case .signedOut:
                accountAccess = .signedOut
                contractNickname = nil
                contractLevel = nil
            case .denied:
                accountAccess = .denied
                contractNickname = nil
                contractLevel = nil
            case .failed:
                accountAccess = .failed
                contractNickname = nil
                contractLevel = nil
            case .ready(let read):
                let form = AccountPublishMPContract.settingsProfileForm(from: data)
                let home = AccountPublishMPContract.homeAccount(from: data)
                let leader = home?.isClubLeader == true || read.role == "club"
                accountAccess = .ready(SettingsAccountProfile(role: read.role, isClubLeader: leader))
                let nickname = form?.nickname.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                contractNickname = nickname.isEmpty ? nil : nickname
                contractLevel = session.account?.level
            }
        } catch {
            accountAccess = .failed
            contractNickname = nil
            contractLevel = nil
        }
    }

    private var language: Binding<AppLanguage> {
        Binding(get: { RegionalLaunchConfiguration.language(storedLanguage) },
                set: { storedLanguage = $0.rawValue })
    }

    var body: some View {
        SettingsPageStack(embedded: !isPushed) {
            Group {
            if !query.trimmingCharacters(in: .whitespaces).isEmpty {
                SettingsSearchResults(query: query, session: session, language: language)
            } else {
            Form {
                // Mini-program pages/shezhi order: 个人资料, 成为俱乐部主理人/成为商家, 城瘾玩法, 我的收藏.
                accountHeader
                SettingsIdentityApplicationEntries(session: session, profile: readyAccountProfile).environment(\.settingsTileTint, SettingsTint.orange)
                Section {
                    NavigationLink {
                        ProfileGuideHost(reader: session.makeProfileGuideReader(),
                            makeArticleReader: { session.makeProfileGuideArticleReader($0) },
                            onOpenDestination: onOpenGuideDestination, templateReader: session)
                            .id(session.socialAccountReader.identity)
                    } label: { Label { Text("social.guide.title") } icon: { AccountPublishMPGlyph(MPAsset.FeatureIcon.iconLcCompass) } }
                        .accessibilityIdentifier("settings.playGuide")
                }
                .environment(\.settingsTileTint, SettingsTint.teal)
                ProfileSettingsFavoritesEntry(session: session, owner: favoritesOwner).environment(\.settingsTileTint, SettingsTint.pink)
                // B-SZ-15-r7: MP shezhi 邀请与收益 (players only) right after 我的收藏; same promo binding as 我的.
                SettingsInvitePromoEntry().environment(\.settingsTileTint, SettingsTint.orange)
                // r11 B-SZ-10: MP pages/shezhi/shezhi.wxml:20-35 — 隐私与定位, AI 对话记录, 营销消息与优惠券, 帖文处置与申诉,
                // 投诉建议, 我的申诉, 发票, 用户服务协议, 账号注销, 关于 (legal → 注销 → 关于 inside SettingsSupportSections).
                // App-only rows (notifications, usage consent, region, language, safety, merchant tools) follow 关于; 退出 last (:42-47).
                SettingsPrivacyLocationEntry(session: session).environment(\.settingsTileTint, SettingsTint.green)
                // mp-mine r3: personal location sharing sits with 隐私与定位 (moved here from 我的).
                Section {
                    NavigationLink { PersonalLocationShareEntry(recipientId: nil) } label: {
                        Label { Text("personalLocationShare.title.management", tableName: "PersonalLocationShare") } icon: { Image(systemName: "location") }
                    }
                    .accessibilityIdentifier("settings.personalLocationShare")
                }
                .environment(\.settingsTileTint, SettingsTint.green)
                NPCChatDataReadSettingsEntry(session: session).environment(\.settingsTileTint, SettingsTint.indigo)
                AccountComplianceMarketingSettingsEntry(coordinator: session.accountComplianceCoordinator, market: session.operationalMarket)
                SettingsPostGovernanceEntry(session: session).environment(\.settingsTileTint, SettingsTint.red)
                // MP V1-P53 (B-SZ-01): 投诉建议 sits in Settings, after 帖文处置与申诉.
                Section { ProfileComplaintPreparationLink(session: session) }
                    .environment(\.settingsTileTint, SettingsTint.teal)
                MemberScoreAppealSettingsEntry(session: session).environment(\.settingsTileTint, SettingsTint.indigo)
                // mp-mine r3: 我的举报 (MP report-mine, the page 我的申诉 copies) follows 我的申诉; moved here from 我的.
                Section {
                    NavigationLink { SquareReportProgressView(session: session) } label: {
                        Label { Text("report.history.title", tableName: "MemberReportProgress") } icon: { Image(systemName: "flag") }
                    }
                    .accessibilityIdentifier("settings.reportMine")
                }
                .environment(\.settingsTileTint, SettingsTint.red)
                SettingsInvoiceEntry(session: session).environment(\.settingsTileTint, SettingsTint.indigo)
                SettingsSupportSections(market: session.operationalMarket, complianceCoordinator: session.accountComplianceCoordinator)
                    .hidingNPCChatDataEntry() // B-SZ-03: 「AI 对话记录」 above is the one NPC chat data row.
                    .hidingMarketingEntry() // r11 B-SZ-10: 营销消息与优惠券 sits after AI 对话记录 above.
                    .followingMPShezhiOrder() // mp-settings r3: 用户服务协议 → 账号注销 → 关于, nothing between them.
                // mp-mine r3: app-only rows moved from 我的 (no MP 我的 row): teams, then support tickets.
                Section {
                    NavigationLink { SessionTeamHomeView() } label: {
                        Label("team.title", systemImage: "person.3")
                    }
                    .accessibilityIdentifier("settings.teams")
                }
                .environment(\.settingsTileTint, SettingsTint.blue)
                SupportTicketReadEntry(session: session).environment(\.settingsTileTint, SettingsTint.teal)
                // mp-settings r3: app-only creator rows (no MP shezhi row) follow the MP list instead of splitting
                // 成为商家 from 城瘾玩法 (shezhi.wxml:19-20).
                AccountRoleSections(gatesCreatorByCapability: true).environment(\.settingsTileTint, SettingsTint.orange)
                Section {
                    NativeNotificationPermissionEntry()
                    NativeChannelNotificationSettingsEntry(session: session)
                } header: {
                    Text("notification.global.title", tableName: "NativeChannelNotification")
                }
                .environment(\.settingsTileTint, SettingsTint.red)
                // Backend contract 20:40: no 同意记录 row. The MP shezhi list has none and /api/compliance/usage-records is not
                // served; the agreement on record is read through /api/compliance/consents/latest (registration, deregistration and checkout checks).
                Section {
                    LabeledContent { Text(verbatim: SettingsHomePage.marketText(RegionalLaunchConfiguration.storefrontMarket ?? session.operationalMarket)).accessibilityIdentifier("region.market.value") } label: { Text("region.market") }
                }
                Section {
                    Picker("settings.language", selection: language) {
                        Text("language.system").tag(AppLanguage.system)
                        Text(verbatim: "English").tag(AppLanguage.english)
                        Text(verbatim: "简体中文").tag(AppLanguage.simplifiedChinese)
                    }
                    .pickerStyle(.navigationLink)
                } footer: {
                    Text("settings.languageNotice")
                }
                .environment(\.settingsTileTint, SettingsTint.blue)
                SettingsSupportSafetyEntry().environment(\.settingsTileTint, SettingsTint.teal)
                // B-SZ-13 MP-first: MP shezhi.wxml has no 商家工具 row for players (only 成为商家, :19); merchants keep it.
                if PlayerLaunch.merchantCenterEnabled && session.account?.effectiveRole == "merchant" { Section { // Lane G
                    NavigationLink {
                        BeGapMerchantHubView()
                    } label: {
                        Label { Text("beGap.hub.title", tableName: "BeGapMerchant") } icon: { Image(systemName: "storefront") }
                    }
                    .accessibilityIdentifier("settings.beGapMerchant")
                }
                .environment(\.settingsTileTint, SettingsTint.teal) }
                SettingsSignOutEntry(session: session) { dismiss() }
            }
            .labelStyle(SettingsTileLabelStyle())
            }
            }
            .cySheet(isPresented: $showsSignIn) { Group { LoginView(intent: .player) }.presentationDetents([.large]).presentationDragIndicator(.visible) }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: Text("settings.search.prompt"))
            .modifier(ProfileSettingsProfileNavigation(session: session, owner: profileOwner))
            .modifier(ProfileSettingsFavoritesNavigation(session: session, owner: favoritesOwner))
            .appNavigationTitle("settings.title")
            .navigationBarTitleDisplayMode(.inline)
            .cyHideTabBar()
            .toolbar {
                if !isPushed {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("action.done") { dismiss() }
                    }
                }
            }
        }
        .onAppear {
            profileOwner.appear()
            Task { await refreshAccountProfile() }
#if DEBUG
            if let q = designOverride?.query, query.isEmpty { query = q }
#endif
        }
        .onChange(of: session.account?.id) { _, _ in Task { await refreshAccountProfile() } }
        .onDisappear {
            // Pushed: onDisappear also fires when a row pushes on top; the owner leaves with the page when it is popped.
            if !isPushed { profileOwner.retire() }
        }
        .themeDomain(.player)
        .modifier(ProfileSettingsFavoritesLifecycle(session: session, owner: favoritesOwner))
        // Explicitly update sheets as well as the app root when preference changes.
        .modifier(AppLanguageEnvironment(stored: storedLanguage))
    }
}

/// Settings in a sheet owns its stack; pushed onto a host stack it does not (no nested bar).
private struct SettingsPageStack<Content: View>: View {
    let embedded: Bool
    @ViewBuilder var content: Content
    var body: some View {
        if embedded { NavigationStack { content } } else { content }
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


/// iOS Settings tile colours: one system hue per group (they adapt to Light/Dark and Increase Contrast).
enum SettingsTint {
    static let blue = Color.blue
    static let green = Color.green
    static let orange = Color.orange
    static let red = Color.red
    static let pink = Color.pink
    static let indigo = Color.indigo
    static let teal = Color.teal
    static let gray = Color.gray
}
private struct SettingsTileTintKey: EnvironmentKey { static let defaultValue: Color = SettingsTint.gray }
extension EnvironmentValues {
    var settingsTileTint: Color {
        get { self[SettingsTileTintKey.self] }
        set { self[SettingsTileTintKey.self] = newValue }
    }
}

/// Account header row, as the Apple Account row at the top of iOS Settings: round initial avatar, name, level.
struct SettingsAccountCard: View {
    let nickname: String
    let level: Int
    let tappable: Bool
    /// Merchant view: MP `icon_lc_store` in place of the initial.
    var brandMark = false
    @Environment(\.locale) private var locale
    /// a11y-dt r3: the initial is `.title`, so the 60 pt circle grows with it instead of clipping at AX sizes.
    @ScaledMetric(relativeTo: .title) private var avatar: CGFloat = 60
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Group {
                if brandMark {
                    MPAsset.FeatureIcon.iconLcStore.resizable().scaledToFit().padding(16)
                } else {
                    Text(verbatim: String(nickname.trimmingCharacters(in: .whitespaces).prefix(1)).uppercased())
                }
            }
                .font(.title.weight(.semibold)).foregroundStyle(.secondary)
                .frame(width: avatar, height: avatar)
                .background(.quaternary, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                PageTemplateVoiceOver.spoken(nickname.isEmpty ? "\u{2014}" : nickname, locale: locale).font(.title3.weight(.semibold)).foregroundStyle(.primary)
                    .cyWrapText()
                Text("settings.account.subtitle \(level)").font(.subheadline).foregroundStyle(.secondary)
                    .cyWrapText()
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(tappable ? .isButton : .isStaticText)
    }
}

/// Search results: a flat list of the destinations that can be opened without extra context.
/// Matches the title, an English or Chinese keyword, or the destination group.
private struct SettingsSearchResults: View {
    let query: String
    let session: AppSession
    let language: Binding<AppLanguage>
    @Environment(\.locale) private var locale
    @State private var sheetDestination: ComplianceDestination?
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
        .labelStyle(SettingsTileLabelStyle())
        .cySheet(item: $sheetDestination) { destination in Group {
            if let c = session.accountComplianceCoordinator {
                AccountComplianceSheetStack(coordinator: c, destination: destination, market: session.operationalMarket, legalReader: session.legalReader)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        }
    }
    @ViewBuilder private func row(_ e: Entry) -> some View {
        let label = Label(LocalizedStringKey(e.key), systemImage: e.symbol).environment(\.settingsTileTint, e.tint)
        switch e.id {
        case "sound": NavigationLink { SettingsSoundPreferencesView(store: SettingsLocalSoundStore()) } label: { label }
        case "agreement": NavigationLink { SettingsLegalDocumentView(type: .userAgreement, market: session.operationalMarket, reader: session.legalReader) } label: { label }
        case "privacy": NavigationLink { SettingsLegalDocumentView(type: .privacyPolicy, market: session.operationalMarket, reader: session.legalReader) } label: { label }
        case "about": NavigationLink { SettingsAboutView(market: session.operationalMarket, appInformation: .current(), legalReader: session.legalReader) } label: { label }
        case "marketing":
            if let c = session.accountComplianceCoordinator {
                NavigationLink {
                    AccountComplianceSheet(coordinator: c, destination: .marketing,
                                           market: session.operationalMarket, legalReader: session.legalReader, showsCloseButton: false)
                } label: { label }
            } else { label }
        case "roam", "close":
            // B-DR-07: the search result opens the same sheet as the Settings row (AccountComplianceSettingsSection), not a push.
            if session.accountComplianceCoordinator != nil {
                Button { sheetDestination = e.id == "roam" ? .roam : .cancellation } label: {
                    HStack {
                        label
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                    }
                }
                .foregroundStyle(.primary)
                .accessibilityIdentifier("settings.search.\(e.id)")
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

/// B-SZ-15-r7: MP `pages/shezhi` 邀请与收益 row (shezhi.wxml:22, js:165). Shown only when the host injected the
/// journey promo binding and the viewer is not a merchant; nil binding hides it (capability absent ⇒ hidden).
@MainActor private struct SettingsInvitePromoEntry: View {
    @Environment(\.mpParity) private var bindings
    var body: some View {
        if bindings.journeyPromo != nil, !bindings.isMerchant {
            Section {
                NavigationLink { MPParityDestination(route: .journeyPromo) } label: {
                    Label { Text("mp.account.promo") } icon: { AccountPublishMPGlyph(MPAsset.FeatureIcon.iconLcGift) }
                }
                .accessibilityIdentifier("settings.invitePromo")
            }
        }
    }
}
