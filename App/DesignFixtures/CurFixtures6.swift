#if DEBUG
import SwiftUI

/// Handovers 59–62. DEBUG hosts for the error sentences, permission primers, compliance pages,
/// and search filters those commits added. Each name mounts the real view. A missing value is an
/// em dash. A decoded 0 stays 0. Money stays closed on `www.chengyinhub.com` through `ReviewedAreaSwitch`.
/// `--design-fixture cur6-<name>[-zh]`. The table is `docs/release/receipts/ui-cur-fixtures-6.md`.
enum CurFixtures6 {
    @MainActor static func make(_ name: String) -> AnyView? {
        let zh = name.hasSuffix("-zh")
        let base = zh ? String(name.dropLast(3)) : name
        let locale = Locale(identifier: zh ? "zh-Hans" : "en")
        switch base {
        case "cur6-errors": return wrap(Cur6ErrorLab(), locale)
        case "cur6-permit-location": return wrap(Cur6PermitLab(kind: .location, denied: false), locale)
        case "cur6-permit-location-denied": return wrap(Cur6PermitLab(kind: .location, denied: true), locale)
        case "cur6-permit-camera": return wrap(Cur6PermitLab(kind: .camera, denied: false), locale)
        case "cur6-permit-camera-denied": return wrap(Cur6PermitLab(kind: .camera, denied: true), locale)
        case "cur6-permit-notification": return wrap(Cur6PermitLab(kind: .notification, denied: false), locale)
        case "cur6-permit-notification-denied": return wrap(Cur6PermitLab(kind: .notification, denied: true), locale)
        case "cur6-permit-photos": return wrap(Cur6PermitLab(kind: .photos, denied: false), locale)
        case "cur6-permit-photos-denied": return wrap(Cur6PermitLab(kind: .photos, denied: true), locale)
        case "cur6-invite-unknown": return wrap(Cur6InviteLab(presentation: .unknown, offersSettings: false), locale)
        case "cur6-invite-denied": return wrap(Cur6InviteLab(presentation: .off, offersSettings: true), locale)
        case "cur6-gate": return wrap(UsageConsentGateView(market: .china, onAgree: {}, onDecline: {}, legalReader: SettingsBundledLegalReader()), locale)
        case "cur6-privacy": return wrap(NavigationStack { PrivacyProtectionView(market: .china, policy: Cur6Consent.pending(), legalReader: SettingsBundledLegalReader()) }, locale)
        case "cur6-privacy-granted": return wrap(NavigationStack { PrivacyProtectionView(market: .china, policy: Cur6Consent.granted(), legalReader: SettingsBundledLegalReader()) }, locale)
        case "cur6-privacy-location": return wrap(NavigationStack { SettingsPrivacyLocationView(mediaReader: Cur6EmptyMedia(), compliance: nil, market: .china, legalReader: SettingsBundledLegalReader()) }, locale)
        case "cur6-agreement": return wrap(NavigationStack { SettingsLegalDocumentView(type: .userAgreement, market: .china, reader: SettingsBundledLegalReader()) }, locale)
        case "cur6-cancellation-notice": return wrap(NavigationStack { SettingsLegalDocumentView(type: .cancellationNotice, market: .china, reader: SettingsBundledLegalReader()) }, locale)
        case "cur6-privacy-policy-missing": return wrap(NavigationStack { SettingsLegalDocumentView(type: .privacyPolicy, market: .china, reader: SettingsBundledLegalReader()) }, locale)
        case "cur6-deregister-pending": return wrap(NavigationStack { AccountComplianceSheet(designModel: Cur6Compliance.deregister(step: .pending, json: #"{"status":"PENDING","blockers":[]}"#), destination: .cancellation, market: .china, legalReader: SettingsBundledLegalReader()) }, locale)
        case "cur6-deregister-cooling": return wrap(NavigationStack { AccountComplianceSheet(designModel: Cur6Compliance.deregister(step: .pending, json: #"{"status":"PENDING","executeAfter":"2099-01-01 00:00:00","blockers":[]}"#), destination: .cancellation, market: .china, legalReader: SettingsBundledLegalReader()) }, locale)
        case "cur6-deregister-ended": return wrap(NavigationStack { AccountComplianceSheet(designModel: Cur6Compliance.deregister(step: .pending, json: #"{"status":"PENDING","executeAfter":"2000-01-01 00:00:00","blockers":[]}"#), destination: .cancellation, market: .china, legalReader: SettingsBundledLegalReader()) }, locale)
        case "cur6-deregister-unknown": return wrap(NavigationStack { AccountComplianceSheet(designModel: Cur6Compliance.deregister(step: .unknown, json: #"{"status":"UNKNOWN","blockers":[]}"#), destination: .cancellation, market: .china, legalReader: SettingsBundledLegalReader()) }, locale)
        case "cur6-chat-export": return wrap(Cur6ChatExport(filled: true), locale)
        case "cur6-chat-export-empty": return wrap(Cur6ChatExport(filled: false), locale)
        case "cur6-search-list": return wrap(Cur6Search.list(zero: false), locale)
        case "cur6-search-list-zero": return wrap(Cur6Search.list(zero: true), locale)
        case "cur6-search-map": return wrap(Cur6Search.map(kind: .popular), locale)
        case "cur6-search-map-empty": return wrap(Cur6Search.map(kind: .empty), locale)
        case "cur6-search-map-failed": return wrap(Cur6Search.map(kind: .failed), locale)
        case "cur6-shelf-topics": return wrap(NavigationStack { DiscoveryTemplateBrowserView(reader: Cur6ShelfReader(mode: .topics)) }, locale)
        case "cur6-shelf-topics-empty": return wrap(NavigationStack { DiscoveryTemplateBrowserView(reader: Cur6ShelfReader(mode: .emptyTopics)) }, locale)
        case "cur6-shelf-topics-failed": return wrap(NavigationStack { DiscoveryTemplateBrowserView(reader: Cur6ShelfReader(mode: .failed)) }, locale)
        case "cur6-shelf-games": return wrap(NavigationStack { DiscoveryTemplateBrowserView(reader: Cur6ShelfReader(mode: .games), startOnGames: true) }, locale)
        case "cur6-shelf-games-empty": return wrap(NavigationStack { DiscoveryTemplateBrowserView(reader: Cur6ShelfReader(mode: .emptyGames), startOnGames: true) }, locale)
        case "cur6-shelf-off": return wrap(NavigationStack { DiscoveryTemplateBrowserView(reader: Cur6ShelfReader(mode: .off)) }, locale)
        default: return nil
        }
    }

    @MainActor private static func wrap<V: View>(_ view: V, _ locale: Locale) -> AnyView {
        AnyView(view.environment(\.locale, locale).themeDomain(.player).cyDomainPageBackground().themeDomain(.player).preferredColorScheme(.dark))
    }
}

private struct Cur6ErrorLab: View {
    @Environment(\.locale) private var locale

    static let codes = [
        "501", "601",
        "ADVANCED_FIRST", "ANSWER_WRONG", "ARRIVE_ACCURACY_INVALID", "ARRIVE_ACCURACY_LOW", "ARRIVE_ACCURACY_MISSING",
        "ARRIVE_COORD_NOT_CONFIGURED", "ARRIVE_FIRST", "ARRIVE_GUARD_SPEED", "ARRIVE_GUARD_THROTTLE", "ARRIVE_GUARD_WINDOW_DISTANCE",
        "ARRIVE_LOCATION_INVALID", "ARRIVE_LOCATION_MISSING", "ARRIVE_LOCATION_STALE", "ARRIVE_NOT_RECORDED", "ARRIVE_TOO_FAR",
        "CASH_CLOSED", "CHAPTER_REDEEMED", "CONFIG_INVALID", "EVENT_UNKNOWN", "FEATURE_CLOSED", "GUILD_FORBIDDEN",
        "INTENT_ACTION_REUSED", "INTENT_INPUT_INVALID", "INTENT_PENDING", "INTENT_SCOPE_DENIED", "INTENT_SESSION_ENDED",
        "INTENT_SESSION_MISMATCH", "INTENT_STALE_STATE", "INVALID_INPUT", "NODE_DELISTED", "NODE_NOT_FOUND", "NOT_CONFIRM", "NOT_FOUND",
        "PUZZLE_STATE_UNAVAILABLE", "REVISION_CONFLICT", "ROUTE_EGG_OFFLINE", "ROUTE_LOCKED",
        "SCAN_CODE_AMBIGUOUS", "SCAN_CODE_EXPIRED", "SCAN_CODE_INVALID", "SCAN_CODE_NODE_MISMATCH", "SCAN_CODE_USED",
        "SENSOR_REJECTED", "STORE_SCAN_REQUIRED", "TASK_REQUIRED", "TEAM_LEAD_REQUIRED",
        "WEBHOOK_BODY_INVALID", "WEBHOOK_BODY_TOO_LARGE", "WEBHOOK_CHANGE_INVALID", "WEBHOOK_CHANNEL_UNAVAILABLE",
        "WEBHOOK_CONTENT_BLOCKED", "WEBHOOK_CRYPTO_UNAVAILABLE", "WEBHOOK_ENDPOINT_PAUSED", "WEBHOOK_FORBIDDEN",
        "WEBHOOK_INBOUND_UNAVAILABLE", "WEBHOOK_IP_NOT_ALLOWED", "WEBHOOK_NONCE_INVALID", "WEBHOOK_NOT_FOUND", "WEBHOOK_PAUSED",
        "WEBHOOK_RATE_LIMITED", "WEBHOOK_REPLAYED", "WEBHOOK_RESULT_UNKNOWN", "WEBHOOK_SECRET_UNRECOVERABLE",
        "WEBHOOK_SIGNATURE_INVALID", "WEBHOOK_TIMESTAMP_OUT_OF_WINDOW", "UNKNOWN"
    ]

    var body: some View {
        let language: BackendErrorLanguage = locale.identifier.lowercased().hasPrefix("zh") ? .zhHans : .en
        let host = ReviewedAreaSwitch.productionAPIHost
        let money = ReviewedAreaSwitch.moneyPayments(apiHost: host)
        let payoutOpen = ReviewedAreaSwitch.payout(apiHost: host)
        let writes = ReviewedAreaSwitch.merchantWrites(apiHost: host)
        let password = ReviewedAreaSwitch.passwordLogin(apiHost: host)
        let featurePaid = BackendErrorCatalog.paymentSucceeded(code: "FEATURE_CLOSED", moneyPaymentsOpen: money, payoutOpen: payoutOpen, merchantWritesOpen: writes, passwordLoginOpen: password)
        let cashPaid = BackendErrorCatalog.paymentSucceeded(code: "CASH_CLOSED", moneyPaymentsOpen: money, payoutOpen: payoutOpen, merchantWritesOpen: writes, passwordLoginOpen: password)
        List {
            Section {
                row("blank", BackendErrorCatalog.playerFacing(code: nil, language: language))
                row("0", BackendErrorCatalog.playerFacing(code: "0", language: language))
                row("unknown", BackendErrorCatalog.playerFacing(code: "unknown", language: language))
                row("message-0", BackendErrorCatalog.playerFacing(code: nil, message: "0", language: language))
                row("message-unknown", BackendErrorCatalog.playerFacing(code: nil, message: "unknown", language: language))
                row("途中彩蛋已下线", BackendErrorCatalog.playerFacing(code: nil, message: "途中彩蛋已下线", language: language))
                row("WEBHOOK_CONTEXT_UNAVAILABLE", BackendErrorCatalog.playerFacing(code: "WEBHOOK_CONTEXT_UNAVAILABLE", language: language))
            }
            Section {
                ForEach(Self.codes, id: \.self) { code in
                    row(code, BackendErrorCatalog.playerFacing(code: code, language: language))
                }
            }
            Section {
                Text(verbatim: "\(host) money=\(money) payout=\(payoutOpen) writes=\(writes) password=\(password)")
                    .font(CYTypography.meta)
                    .accessibilityIdentifier("cur6.error.area")
                Text(verbatim: "FEATURE_CLOSED \(featurePaid)")
                    .font(CYTypography.body)
                    .accessibilityIdentifier("cur6.error.featureClosed")
                Text(verbatim: "CASH_CLOSED \(cashPaid)")
                    .font(CYTypography.body)
                    .accessibilityIdentifier("cur6.error.cashClosed")
                Text(verbatim: BackendErrorCatalog.playerFacing(code: "FEATURE_CLOSED", language: language))
                Text(verbatim: BackendErrorCatalog.playerFacing(code: "CASH_CLOSED", language: language))
            }
        }
        .accessibilityIdentifier("cur6.errors")
    }

    private func row(_ label: String, _ sentence: String) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.xxs) {
            Text(verbatim: label).font(CYTypography.meta).foregroundStyle(CYColor.textSecondary)
            Text(verbatim: sentence).font(CYTypography.body)
        }
        .accessibilityIdentifier("cur6.error.\(label)")
    }
}

private struct Cur6PermitLab: View {
    let kind: CYPermissionPromptKind
    let denied: Bool
    @Environment(\.locale) private var locale
    @State private var lastAction = "none"

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.lg) {
            Spacer()
            CYPermissionPrimer(kind: kind, denied: denied, locale: locale, onPrimary: { lastAction = "primary" }, onSecondary: { lastAction = "secondary" })
            Text(verbatim: "Offline example · \(lastAction)").font(CYTypography.meta).foregroundStyle(CYColor.textSecondary)
                .accessibilityIdentifier("cur6.permit.lastAction")
            Spacer()
        }
        .padding(CYSpacing.pageHorizontal)
        .accessibilityIdentifier("cur6.permit.\(kind.rawValue)")
    }
}

@MainActor private final class Cur6InviteBinding: IMInviteReminderBinding {
    let isEnabled: Bool
    let presentation: IMInviteReminderPresentation
    let offersSettings: Bool
    init(presentation: IMInviteReminderPresentation, offersSettings: Bool) {
        self.presentation = presentation
        self.isEnabled = presentation.isEnabled
        self.offersSettings = offersSettings
    }
    func reload() async {}
    func setEnabled(_ on: Bool) async -> Bool { false }
}

private struct Cur6InviteLab: View {
    let presentation: IMInviteReminderPresentation
    let offersSettings: Bool
    var body: some View {
        List {
            IMInviteReminderToggle()
        }
        .environment(\.imInviteReminder, Cur6InviteBinding(presentation: presentation, offersSettings: offersSettings))
        .accessibilityIdentifier("cur6.invite")
    }
}

private enum Cur6Consent {
    static func pending() -> UsageConsentPolicy { UsageConsentPolicy(storage: MemoryUsageConsentStorage()) }
    static func granted() -> UsageConsentPolicy {
        let storage = MemoryUsageConsentStorage()
        try? UsageConsentPolicy(storage: storage).agree(agreementChecked: true)
        return UsageConsentPolicy(storage: storage)
    }
}

@MainActor private final class Cur6EmptyMedia: OwnMediaReading {
    let scope = UUID()
    let isSignedIn = false
    let isAvailable = false
    func page(before cursor: Int64?) async throws -> OwnMediaPage { throw APIError.notConfigured }
}

private final class Cur6Transport: HTTPTransport, @unchecked Sendable {
    func send(_ request: URLRequest) async throws -> (Data, Int) { throw URLError(.notConnectedToInternet) }
}

@MainActor private enum Cur6Compliance {
    static func deregister(step: ComplianceStep, json: String) -> ComplianceViewModel {
        let base = URL(string: "https://fixture.example")!
        let config = try! APIConfiguration(baseURL: base)
        let transport = Cur6Transport()
        let journal = ComplianceFileJournal(url: FileManager.default.temporaryDirectory.appendingPathComponent("cur6-compliance-\(UUID().uuidString).json"))
        let service = AccountComplianceService(configuration: config, transport: transport, journal: journal, current: { nil }, token: { nil })
        let coordinator = AccountComplianceCoordinator(
            service: service,
            auth: AuthChannelService(configuration: config, transport: transport),
            effects: DormantComplianceRoamEffects(),
            current: { nil },
            invalidateSession: { _ in }
        )
        let model = ComplianceViewModel(coordinator, isDeregistration: true)
        var state = ComplianceState()
        state.step = step
        state.localCancellationConsent = .none
        state.status = try? JSONDecoder().decode(ComplianceDeregistration.self, from: Data(json.utf8))
        model.state = state
        return model
    }
}

private struct Cur6ChatExport: View {
    let filled: Bool
    @Environment(\.locale) private var locale
    var body: some View {
        List {
            if filled, let loaded = Cur6Chat.sample {
                NPCChatDataExportButton(data: loaded)
                Text(verbatim: NPCChatDataExportButton.readable(loaded, locale: locale))
                    .font(CYTypography.body)
                    .accessibilityIdentifier("cur6.chat.readable")
            } else {
                NPCChatDataExportButton(data: nil)
                Text(verbatim: "—").accessibilityIdentifier("cur6.chat.empty")
            }
        }
        .accessibilityIdentifier("cur6.chat")
    }
}

private enum Cur6Chat {
    static var sample: NPCChatData? {
        let json = #"{"code":200,"data":{"retentionDays":0,"records":[{"id":1,"userId":7,"userMsg":"夜路","npcReply":"留神","createTime":null},{"id":2,"userId":7,"userMsg":"几点","npcReply":"","createTime":0}]}}"#
        return try? NPCChatData.decode(Data(json.utf8), expectedAccountID: 7)
    }
}

@MainActor private enum Cur6Search {
    enum MapKind { case popular, empty, failed }

    static func list(zero: Bool) -> some View {
        let price: Double? = zero ? 0.0 : nil
        let filter = GlobalSearchQuery(keyword: "西湖", minimumPrice: price, maximumPrice: price)
        return SearchMapFilterSheet(filter: filter, categories: categories, categoryFailed: false, categoryLoaded: true, apply: { _ in })
    }

    static func map(kind: MapKind) -> some View {
        let failed = kind == .failed
        let rows = kind == .popular ? categories : []
        let retry: (() -> Void)? = failed ? {} : nil
        let loaded = kind == .empty || kind == .popular
        return SearchMapFilterSheet(
            filter: GlobalSearchQuery(keyword: "西湖"),
            categories: rows,
            categoryFailed: failed,
            categoryLoaded: loaded,
            retryCategories: retry,
            tag: "茶",
            cityRole: "向导",
            sortType: SearchMapSortChoice.popular.rawValue,
            applyCityOptions: { _, _, _ in },
            apply: { _ in }
        )
    }

    private static var categories: [DiscoveryCategory] {
        let json = #"[{"id":11,"categoryName":"City walks","type":4},{"id":12,"categoryName":"Stories","type":4}]"#
        return (try? JSONDecoder().decode([DiscoveryCategory].self, from: Data(json.utf8))) ?? []
    }
}

@MainActor final class Cur6ShelfReader: DiscoveryReading {
    enum Mode { case topics, emptyTopics, failed, games, emptyGames, off }
    let mode: Mode
    var isConfigured: Bool { mode != .off }

    init(mode: Mode) { self.mode = mode }

    func discoveryBanners() async throws -> [DiscoveryBanner] { [] }
    func discoveryCategories(type: Int?) async throws -> [DiscoveryCategory] { [] }
    func discoveryTemplateHome() async throws -> DiscoveryTemplateHome {
        try gate()
        let json = mode == .games ? Self.homeJSON : "{}"
        return try JSONDecoder().decode(DiscoveryTemplateHome.self, from: Data(json.utf8))
    }
    func discoveryPlayTemplates(keyword: String, packType: DiscoveryPackType?) async throws -> [DiscoveryPlayTemplate] {
        try gate()
        let json = (mode == .games) ? Self.gamesJSON : "[]"
        let rows = try JSONDecoder().decode([DiscoveryPlayTemplate].self, from: Data(json.utf8))
        return rows.filter { (packType == nil || $0.pack == packType) && (keyword.isEmpty || $0.title.localizedCaseInsensitiveContains(keyword)) }
    }
    func discoveryTopicTemplates() async throws -> [DiscoveryTopicTemplate] {
        try gate()
        let json = (mode == .topics || mode == .games) ? Self.topicsJSON : (mode == .emptyTopics ? Self.hiddenOnlyJSON : "[]")
        return try JSONDecoder().decode([DiscoveryTopicTemplate].self, from: Data(json.utf8))
    }
    func discoveryTopicTemplateDetail(id: Int) async throws -> PublicTopicTemplateDetail { throw APIError.notConfigured }
    func discoveryPlayTemplate(id: Int) async throws -> DiscoveryPlayTemplate { throw APIError.notConfigured }

    private func gate() throws {
        if mode == .off { throw APIError.notConfigured }
        if mode == .failed { throw APIError.httpStatus(503) }
    }

    static let topicsJSON = #"[{"id":1,"name":"风味巡游","subtitle":"Sample shelf topic","chapterCount":2,"locationCount":3,"totalTime":1800,"templateStatus":"VERIFIED"},{"id":2,"name":"风味巡游·夜市","subtitle":"","chapterCount":1,"locationCount":1,"totalTime":4000,"templateStatus":"VERIFIED"},{"id":3,"name":"城市藏宝猎人","subtitle":"","chapterCount":0,"locationCount":0,"totalTime":0,"templateStatus":"VERIFIED"},{"id":4,"name":"生活不掉线","subtitle":""},{"id":5,"name":"野生邻居观察局","subtitle":"hidden","totalTime":90}]"#
    static let hiddenOnlyJSON = #"[{"id":5,"name":"野生邻居观察局","subtitle":"hidden","totalTime":90}]"#
    static let gamesJSON = #"[{"id":2,"title":"闭眼味觉师","players":"单人","duration":0,"packType":0},{"id":9,"title":"闭眼味觉师","players":"单人","duration":0,"packType":0},{"id":4,"title":"街角谜题","players":"双人","duration":5,"packType":0},{"id":8,"title":"G12｜不应出现","players":"单人","duration":1,"packType":0},{"id":6,"title":"Notice the city","duration":45,"packType":1}]"#
    static let homeJSON = #"{"total":0,"hotList":[{"id":9,"title":"闭眼味觉师","players":"单人","duration":0,"packType":0},{"id":4,"title":"街角谜题","players":"双人","duration":5,"packType":0}]}"#
}
#endif
