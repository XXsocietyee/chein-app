import Foundation

/// Mini-program pages/shezhi shows "成为俱乐部主理人" and "成为商家" only to a signed-in
/// player view (`!isMerchantView && !isClubView`); the server role decides, never a local choice.
public enum SettingsIdentityApplications {
    public static func isOffered(toRole role: String?) -> Bool {
        guard let role else { return false }
        return role != "merchant" && role != "club"
    }
}

/// pages/shezhi/shezhi facts for the session and market the settings form already reads.
/// This type does not open a route and does not mark one live. A missing market, a missing
/// count, or a numeric string is an em dash. A literal integer 0 stays "0".
public enum SettingsHomePage {
    public static let unknownDisplay = "—"
    public static let routeMarkedLive = false
    public static let knownRoles: Set<String> = ["player", "merchant", "club"]

    public enum Phase: Equatable {
        case loading
        case empty
        case error
        case unknown
        case ready
    }

    public enum SessionFact: Equatable {
        case loading
        case failed
        case signedOut
        case signedIn(role: String)
    }

    public enum Copy {
        public static let loading = "settings.home.loading"
        public static let error = "settings.home.error"
        public static let unknown = "settings.home.unknown"
        public static let signedOut = "member.settings.signedOut"
        public static let title = "settings.title"
    }

    public struct Facts: Equatable {
        public let phase: Phase
        public let marketText: String
        public let roleText: String
        public let offersIdentityApplications: Bool
        public let showsSignOut: Bool
        public let copyKey: String
        public let accessibilityIdentifier: String
    }

    /// Loading wins over a failure. A nil role is signed out. The raw role is kept;
    /// an empty role is not rewritten to player.
    public static func sessionFact(loading: Bool, failed: Bool, role: String?) -> SessionFact {
        if loading { return .loading }
        if failed { return .failed }
        guard let role else { return .signedOut }
        return .signedIn(role: role)
    }

    public static func marketText(_ market: RegionalMarket?) -> String {
        market?.rawValue ?? unknownDisplay
    }

    /// Nil is unknown. A literal 0 stays "0".
    public static func countText(_ count: Int?) -> String {
        guard let count else { return unknownDisplay }
        return String(count)
    }

    /// A numeric string is not a JSON number. `"0"` and a blank string stay unknown.
    public static func countText(numericString _: String) -> String { unknownDisplay }

    public static func facts(session: SessionFact, market: RegionalMarket?) -> Facts {
        let marketText = marketText(market)
        switch session {
        case .loading:
            return hidden(phase: .loading, marketText: marketText, copyKey: Copy.loading,
                          accessibilityIdentifier: "settings.home.loading")
        case .failed:
            return hidden(phase: .error, marketText: marketText, copyKey: Copy.error,
                          accessibilityIdentifier: "settings.home.error")
        case .signedOut:
            return Facts(phase: .empty, marketText: marketText, roleText: unknownDisplay,
                         offersIdentityApplications: false, showsSignOut: false,
                         copyKey: Copy.signedOut, accessibilityIdentifier: "settingsNative.profileSignedOut")
        case .signedIn(let role):
            let trimmed = role.trimmingCharacters(in: .whitespacesAndNewlines)
            guard knownRoles.contains(trimmed) else {
                return Facts(phase: .unknown, marketText: marketText, roleText: unknownDisplay,
                             offersIdentityApplications: false, showsSignOut: true,
                             copyKey: Copy.unknown, accessibilityIdentifier: "settings.home.unknown")
            }
            let offers = SettingsIdentityApplications.isOffered(toRole: trimmed)
            if market == nil {
                return Facts(phase: .unknown, marketText: unknownDisplay, roleText: trimmed,
                             offersIdentityApplications: offers, showsSignOut: true,
                             copyKey: Copy.unknown, accessibilityIdentifier: "settings.home.unknown")
            }
            return Facts(phase: .ready, marketText: marketText, roleText: trimmed,
                         offersIdentityApplications: offers, showsSignOut: true,
                         copyKey: Copy.title, accessibilityIdentifier: "settings.home.ready")
        }
    }

    private static func hidden(phase: Phase, marketText: String, copyKey: String,
                               accessibilityIdentifier: String) -> Facts {
        Facts(phase: phase, marketText: marketText, roleText: unknownDisplay,
              offersIdentityApplications: false, showsSignOut: false,
              copyKey: copyKey, accessibilityIdentifier: accessibilityIdentifier)
    }
}

#if DEBUG
/// Synthetic roles only. Not a support address, filing number, or legal body.
public enum SettingsHomeFixtureData {
    public static let unknownDisplay = SettingsHomePage.unknownDisplay
    public static let playerRole = "player"
    public static let merchantRole = "merchant"
    public static let clubRole = "club"
    public static let unknownRole = "UNKNOWN"
    public static let numericRole = "0"
    public static let blankRole = "  "
}

/// Synthetic labels only. Not legal text.
public enum SettingsLegalAgreementFixtureData {
    public static let unknownDisplay = SettingsLegalAgreementPage.unknownDisplay

    public static let unknownShell = make(title: "", version: "", effectiveDate: "", intro: "", sections: [])

    public static let zeroSections = make(
        title: "fixture-title", version: "fixture-v0", effectiveDate: "fixture-date",
        intro: "fixture-intro", sections: []
    )

    public static let oneSection = make(
        title: "fixture-title", version: "fixture-v1", effectiveDate: "fixture-date",
        intro: "fixture-intro", sections: [.init(heading: "fixture-heading", body: "fixture-body")]
    )

    public static let blankVersion = make(
        title: "fixture-title", version: "  ", effectiveDate: "fixture-date",
        intro: "fixture-intro", sections: [.init(heading: "fixture-heading", body: "fixture-body")]
    )

    private static func make(title: String, version: String, effectiveDate: String, intro: String,
                             sections: [SettingsLegalSection]) -> SettingsLegalDocument {
        SettingsLegalDocument(
            type: .userAgreement, title: title, version: version, effectiveDate: effectiveDate,
            intro: intro, sections: sections, languageCode: "zh-Hans"
        )
    }
}
#endif

/// pages/shezhi/about/index. Projects the existing bundle facts and `SettingsPlayerCode`
/// contract. No player-code route is called: the source POST can generate a code.
public enum SettingsAboutMetadataPhase: Equatable {
    case loading
    case empty
    case error
    case unknown
    case ready(String)

    /// Missing, unread, and failed facts. Never a substitute version or the digit 0.
    public static let unknownText = "—"

    public var text: String {
        if case .ready(let value) = self { return value }
        return Self.unknownText
    }

    public static func fromBundle(_ value: String?) -> Self {
        guard let value else { return .unknown }
        return .ready(value)
    }
}

public enum SettingsAboutPlayerCodePhase: Equatable {
    case loading
    case empty
    case error
    case unknown
    case ready(SettingsPlayerCode)

    /// `POST /api/user/player-code` stays uninstalled. Nothing here marks a route live.
    public static let routeInstalled = false
    public static let routeMarkedLive = false

    public var imageURL: URL? {
        if case .ready(let code) = self { return code.imageURL }
        return nil
    }

    /// The mini program keeps the voucher in error until a real code exists.
    public static func production() -> Self { .error }

    /// Classify a `data` object from the existing contract. Nil is unknown.
    /// A blank or omitted `qr` is empty. `UNKNOWN`, null, and a non-string stay unknown.
    /// An unsafe or unusable string is error. Only `SettingsPlayerCode` becomes ready.
    public static func classify(dataObject: Data?) -> Self {
        guard let dataObject else { return .unknown }
        let trimmedBody = String(data: dataObject, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedBody?.lowercased() == "null" { return .unknown }
        guard let parsed = try? JSONSerialization.jsonObject(with: dataObject) else { return .error }
        if parsed is NSNull { return .unknown }
        guard let dictionary = parsed as? [String: Any] else { return .error }
        guard let raw = dictionary["qr"] else { return .empty }
        if raw is NSNull { return .unknown }
        guard let string = raw as? String else { return .unknown }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return .empty }
        if trimmed.uppercased() == "UNKNOWN" { return .unknown }
        guard let code = try? JSONDecoder().decode(SettingsPlayerCode.self, from: dataObject) else { return .error }
        return .ready(code)
    }
}

public struct SettingsAboutPageModel: Equatable {
    public let version: SettingsAboutMetadataPhase
    public let build: SettingsAboutMetadataPhase
    public let displayName: SettingsAboutMetadataPhase
    public let playerCode: SettingsAboutPlayerCodePhase
    public let contactPhone: String?

    public static let showsMerchantChoice = false
    public static let paymentEnabled = false
    public static let payoutEnabled = false
    public static let withdrawalEnabled = false
    public static let virtualGoodsEnabled = false

    public init(information: SettingsAppInformation, market: RegionalMarket?,
                playerCode: SettingsAboutPlayerCodePhase = .production()) {
        version = .fromBundle(information.version)
        build = .fromBundle(information.build)
        displayName = .fromBundle(information.displayName)
        self.playerCode = playerCode
        contactPhone = SettingsSourceContact.phone(market: market)
    }
}

/// pages/agreement/index facts for the bundled legal reader that already exists.
/// `api/agreement/get` is not in the reviewed route catalog, so this type never requests it
/// and does not mark it live. A missing number or a blank version or date is an em dash.
/// A loaded document with zero sections stays `"0"`.
public enum SettingsLegalAgreementPage {
    public static let unknownDisplay = "—"
    public static let hiddenAgreementGetPath = "api/agreement/get"
    public static let retryAccessibilityIdentifier = "settingsNative.legal.retry"
    public static let versionAccessibilityIdentifier = "settingsNative.legal.version"
    public static let sectionAccessibilityPrefix = "settingsNative.legal.section"

    public enum Phase: Equatable {
        case loading
        case empty(SettingsLegalMissingReason)
        case error
        case unknown
        case ready(SettingsLegalDocument)
    }

    public struct Facts: Equatable {
        public let phase: Phase
        public let versionText: String
        public let effectiveDateText: String
        public let sectionCountText: String
        public let accessibilityIdentifier: String
    }

    /// True while the reviewed catalog has no live `api/agreement/get` route.
    public static var agreementGetStaysHidden: Bool {
        ChinaReviewedRouteCapability.mark(for: "/" + hiddenAgreementGetPath) == nil
            && ChinaReviewedRouteCapability.admitsChinaProductionCall("/" + hiddenAgreementGetPath) == false
    }

    public static func countText(_ count: Int?) -> String {
        guard let count else { return unknownDisplay }
        return String(count)
    }

    public static func displayText(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? unknownDisplay : trimmed
    }

    public static func sectionAccessibilityIdentifier(index: Int) -> String {
        guard index >= 0 else { return sectionAccessibilityPrefix }
        return sectionAccessibilityPrefix + "." + String(index)
    }

    public static func facts(for state: SettingsLegalState) -> Facts {
        switch state {
        case .idle, .loading:
            return unknownFacts(phase: .loading, accessibilityIdentifier: "settingsNative.legal.loading")
        case .failed:
            return unknownFacts(phase: .error, accessibilityIdentifier: "settingsNative.legal.error")
        case .loaded(.missing(let reason)):
            return unknownFacts(phase: .empty(reason), accessibilityIdentifier: "settingsNative.legal.missing")
        case .loaded(.sourceDocument(let document)):
            if isUnknownShell(document) {
                return unknownFacts(phase: .unknown, accessibilityIdentifier: "settingsNative.legal.unknown")
            }
            return Facts(
                phase: .ready(document),
                versionText: displayText(document.version),
                effectiveDateText: displayText(document.effectiveDate),
                sectionCountText: countText(document.sections.count),
                accessibilityIdentifier: "settingsNative.legal.sourceNotice"
            )
        }
    }

    private static func unknownFacts(phase: Phase, accessibilityIdentifier: String) -> Facts {
        Facts(
            phase: phase,
            versionText: unknownDisplay,
            effectiveDateText: unknownDisplay,
            sectionCountText: countText(nil),
            accessibilityIdentifier: accessibilityIdentifier
        )
    }

    private static func isUnknownShell(_ document: SettingsLegalDocument) -> Bool {
        document.sections.isEmpty
            && displayText(document.title) == unknownDisplay
            && displayText(document.version) == unknownDisplay
            && displayText(document.effectiveDate) == unknownDisplay
            && displayText(document.intro) == unknownDisplay
    }
}
