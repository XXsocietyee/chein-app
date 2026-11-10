import Foundation

/// Mini-program pages/shezhi shows "成为俱乐部主理人" and "成为商家" only to a signed-in
/// player view (`!isMerchantView && !isClubView`); the server role decides, never a local choice.
public enum SettingsIdentityApplications {
    public static func isOffered(toRole role: String?) -> Bool {
        guard let role else { return false }
        return role != "merchant" && role != "club"
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

#if DEBUG
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
