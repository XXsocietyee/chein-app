import Foundation

/// Display rules ported from mini-program `pages/topic/pricing` and `pages/topic/pricing/partner`.
/// Presentation only; the confirm write stays in the dormant `PublisherLifecycleCoordinator` review.
public enum TopicPricingXcx {
    private static func ceilInt(_ value: Decimal) -> Int {
        var input = value, output = Decimal()
        NSDecimalRound(&output, &input, 0, .up)
        return NSDecimalNumber(decimal: output).intValue
    }
    /// Source starting final price: `ceil(floor)`.
    public static func initialPrice(floor: Decimal) -> Int { ceilInt(floor) }
    /// Source slider maximum: max(ceil(floor)+100, ceil(floor*2), reference ? ceil(reference*1.5) : 0).
    public static func sliderMax(floor: Decimal, reference: Decimal?) -> Int {
        max(ceilInt(floor) + 100, ceilInt(floor * 2), reference.map { ceilInt($0 * Decimal(string: "1.5")!) } ?? 0)
    }
    public enum Delta: Equatable { case above(percent: Int), notAbove }
    /// Source delta vs. the city reference: round((value-ref)/ref*100); only shown with a positive reference and samples.
    public static func delta(price: Decimal, reference: Decimal?, sampleSize: Int?) -> Delta? {
        guard let reference, reference > 0, (sampleSize ?? 0) > 0 else { return nil }
        let ratio = NSDecimalNumber(decimal: (price - reference) / reference * 100).doubleValue
        let percent = Int(ratio.rounded())
        return percent > 0 ? .above(percent: percent) : .notAbove
    }
    public enum Terms: Equatable {
        case chapterPerk, chapterTraffic, chapterRevshare(fee: String?)
        case share(rate: String?), fixed(fee: String?), traffic
    }
    /// Source lineup terms text: chapter supply rows by `termsMode`, otherwise by `shareMode`.
    public static func terms(_ row: PublisherLineup) -> Terms {
        switch row.termsMode?.uppercased() {
        case "PERK"?: return .chapterPerk
        case "TRAFFIC"?: return .chapterTraffic
        case "REVSHARE"?: return .chapterRevshare(fee: twoDecimals(row.fixedFee))
        default: break
        }
        switch row.mode {
        case 1: return .share(rate: row.shareRate)
        case 2: return .fixed(fee: row.fixedFee)
        default: return .traffic
        }
    }
    public static func twoDecimals(_ raw: String?) -> String? {
        guard let raw, let value = Decimal(string: raw), !value.isNaN else { return nil }
        return String(format: "%.2f", NSDecimalNumber(decimal: value).doubleValue)
    }
    public enum Blocker: Equatable { case teamSize, phase, belowFloor }
    /// Source confirm gating: guided needs a team size > 0, the server must allow confirmation, price ≥ floor.
    public static func blocker(guided: Bool, teamSize: Int?, canConfirm: Bool?, price: Decimal?, floor: Decimal) -> Blocker? {
        if guided && (teamSize ?? 0) <= 0 { return .teamSize }
        if canConfirm == false { return .phase }
        guard let price, !price.isNaN, price >= floor else { return .belowFloor }
        return nil
    }
    /// Lineup rows tied to a chapter open the merchant project view; others open the partner terms page.
    public static func opensChapterProject(_ row: PublisherLineup) -> Bool { row.chapterID != nil }

    public enum LineupRowTarget: Equatable, Sendable {
        case chapterProject(topicID: Int, chapterID: Int, partnerID: Int)
        case partnerTerms(topicID: Int, partnerType: String, partnerID: Int)
    }

    public static let lineupLockedNote = "阵容已锁定，点开可查该合作方在本主题中的结算条款。"
    public static let partnerLockedNote = "阵容已锁定，以下为该合作方在本主题中的结算条款。"

    public static func lockedNote(forPartnerDetail: Bool = false) -> String {
        forPartnerDetail ? partnerLockedNote : lineupLockedNote
    }

    public static func rowTarget(topicID: Int, row: PublisherLineup) -> LineupRowTarget? {
        guard topicID > 0, row.partnerID > 0 else { return nil }
        if let chapterID = row.chapterID, chapterID > 0 {
            return .chapterProject(topicID: topicID, chapterID: chapterID, partnerID: row.partnerID)
        }
        let partnerType = row.type.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !partnerType.isEmpty else { return nil }
        return .partnerTerms(topicID: topicID, partnerType: partnerType, partnerID: row.partnerID)
    }

    /// Unknown money. A missing, blank, or non-numeric amount is this dash, never `0`.
    public static let unknownMoney = "—"
    /// This page is not on the player-first welcome. `WelcomeView.showsMerchantChoice` stays false.
    public static let includedInPlayerFirstEntry = false
    /// Existing preview contract. Not a new route.
    public static let previewRoute = "/api/topic/pricing/preview"
    /// Existing confirm contract. The host grant stays off; this does not enable it.
    public static let confirmRoute = "/api/topic/pricing/confirm"

    /// R7-PC-B4-3: MP `ticketFee` (pages/topic/pricing/index.js:489-495). Platform fee rounded to 0.01,
    /// take-home = price − fee, percent = round(rate×10000)/100. Nil without a rate or a positive price.
    public static func fee(price: Decimal, rate: Decimal?) -> (fee: Decimal, takeHome: Decimal, percent: Decimal)? {
        guard let rate, !rate.isNaN, !price.isNaN, price > 0 else { return nil }
        var rawFee = price * rate, fee = Decimal()
        NSDecimalRound(&fee, &rawFee, 2, .plain)
        var rawBasis = rate * 10000, basis = Decimal()
        NSDecimalRound(&basis, &rawBasis, 0, .plain)
        return (fee, price - fee, basis / 100)
    }

    /// R7-PC-B4-3: MP 平台服务费 text `¥fee（pct%）` and 预计到手 `¥takeHome` (index.js:494).
    public static func feeTexts(price: Decimal, rate: Decimal?) -> (fee: String, takeHome: String)? {
        guard let value = fee(price: price, rate: rate) else { return nil }
        let percent = NSDecimalNumber(decimal: value.percent).stringValue
        return ("¥" + moneyText(decimal: value.fee) + "（" + percent + "%）", "¥" + moneyText(decimal: value.takeHome))
    }

    /// Two-decimal money, or an em dash. A literal zero stays `"0.00"`.
    public static func moneyText(_ raw: String?) -> String {
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let trimmed, !trimmed.isEmpty, let formatted = twoDecimals(trimmed) else { return unknownMoney }
        return formatted
    }

    /// Two-decimal money, or an em dash. A literal zero stays `"0.00"`.
    public static func moneyText(decimal value: Decimal?) -> String {
        guard let value else { return unknownMoney }
        return moneyText(NSDecimalNumber(decimal: value).stringValue)
    }

    /// The page stays hidden when the existing preview route is not offered, and on the player-first entry.
    /// A nil base offers nothing. This does not mark a route live.
    public static func showsPage(baseURL: URL?, playerFirstEntry: Bool) -> Bool {
        guard includedInPlayerFirstEntry == false, playerFirstEntry == false else { return false }
        return ChinaReviewedRouteCapability.offersFeature(previewRoute, baseURL: baseURL)
    }

    /// Confirm stays hidden unless the page is shown and an existing pricing grant is already present.
    /// Passing `pricingGrantPresent: false` does not create that grant. Payment, payout, and withdrawal stay off.
    public static func showsConfirm(baseURL: URL?, playerFirstEntry: Bool, pricingGrantPresent: Bool) -> Bool {
        guard showsPage(baseURL: baseURL, playerFirstEntry: playerFirstEntry), pricingGrantPresent else { return false }
        return ChinaReviewedRouteCapability.offersFeature(confirmRoute, baseURL: baseURL)
    }

    /// Owner of a topic already in pricing (lifecycle 2), and only when the page itself is shown.
    /// A missing lifecycle is not zero and does not open the page.
    public static func showsEntry(owner: Bool, lifecycle: Int?, baseURL: URL?, playerFirstEntry: Bool) -> Bool {
        showsPage(baseURL: baseURL, playerFirstEntry: playerFirstEntry) && owner && lifecycle == 2
    }

    /// One read of the existing preview contract. `missingTopic` is the source empty state.
    public enum Read: Equatable {
        case idle
        case loading
        case missingTopic
        case failed
        case payload(ProjectEditJSON)
    }

    public enum Screen: Equatable, Sendable {
        case loading
        /// Source `cy-empty` for a link with no topic id. Not an error and not a zero price.
        case empty
        case error(Failure)
        /// No request is in flight, the link is valid, and neither a preview nor a failure arrived.
        case unknown
        case ready(Ready)

        public enum Failure: Equatable, Sendable {
            case load
            case incomplete
        }

        public struct Ready: Equatable, Sendable {
            public let floorText: String
            public let finalPriceText: String
            public let refreshing: Bool
            public let refreshFailed: Bool
            public let reference: Reference
            public let confirm: Authority
            public let canSubmit: Bool
            public let lineupEmpty: Bool

            public enum Reference: Equatable, Sendable {
                case insufficient
                case average(money: String, samples: Int)
            }

            /// `unknown` is a missing `canConfirm`. It is not `blocked` and it is not a zero.
            public enum Authority: Equatable, Sendable {
                case unknown
                case allowed
                case blocked
            }
        }
    }

    /// Classify the existing preview. A payload that cannot be priced is an error, not a floor of 0.
    /// A later failure keeps the previous floor instead of replacing it with 0.
    public static func screen(read: Read, kept: PublisherPricingPreview?, subtype: PublisherPriceSubtype, teamSize: Int?, price: Decimal?) -> Screen {
        switch read {
        case .missingTopic:
            return .empty
        case .loading:
            guard let kept else { return .loading }
            return ready(kept, subtype: subtype, teamSize: teamSize, price: price, refreshing: true, refreshFailed: false)
        case .failed:
            guard let kept else { return .error(.load) }
            return ready(kept, subtype: subtype, teamSize: teamSize, price: price, refreshing: false, refreshFailed: true)
        case .payload(let data):
            if let preview = try? PublisherPricingPreview(data) {
                return ready(preview, subtype: subtype, teamSize: teamSize, price: price, refreshing: false, refreshFailed: false)
            }
            guard let kept else { return .error(.incomplete) }
            return ready(kept, subtype: subtype, teamSize: teamSize, price: price, refreshing: false, refreshFailed: true)
        case .idle:
            guard let kept else { return .unknown }
            return ready(kept, subtype: subtype, teamSize: teamSize, price: price, refreshing: false, refreshFailed: false)
        }
    }

    private static func ready(_ preview: PublisherPricingPreview, subtype: PublisherPriceSubtype, teamSize: Int?, price: Decimal?, refreshing: Bool, refreshFailed: Bool) -> Screen {
        let offered = price ?? Decimal(initialPrice(floor: preview.minimum))
        let authority: Screen.Ready.Authority
        switch preview.canConfirm {
        case nil: authority = .unknown
        case true?: authority = .allowed
        case false?: authority = .blocked
        }
        let reference: Screen.Ready.Reference
        if let value = preview.reference, let samples = preview.sampleSize, samples > 0 {
            reference = .average(money: moneyText(decimal: value), samples: samples)
        } else {
            reference = .insufficient
        }
        let submit = blocker(guided: subtype == .guided, teamSize: teamSize, canConfirm: preview.canConfirm, price: offered, floor: preview.minimum) == nil
        return .ready(.init(floorText: moneyText(decimal: preview.minimum), finalPriceText: moneyText(decimal: offered),
                             refreshing: refreshing, refreshFailed: refreshFailed, reference: reference, confirm: authority,
                             canSubmit: submit, lineupEmpty: preview.lineup.isEmpty))
    }

    /// Partner share and fixed fee. Distinct from `moneyText`, which formats a topic price to two decimals.
    /// `UNKNOWN`, null, and a non-numeric string are an em dash, never 0. A literal 0 stays "0".
    public static func partnerMoneyText(_ raw: String?) -> String {
        guard let raw else { return unknownMoney }
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty || text.compare("UNKNOWN", options: .caseInsensitive) == .orderedSame { return unknownMoney }
        guard let value = Decimal(string: text, locale: Locale(identifier: "en_US_POSIX")), !value.isNaN else { return unknownMoney }
        return NSDecimalNumber(decimal: value).stringValue
    }

    public enum PartnerPhase: Equatable {
        case loading
        case empty(PublisherPartnerInspection)
        case error
        case unknown
        case ready(PublisherPartnerInspection)
    }

    /// Classifies the existing partner read. It does not open a route.
    /// Loading wins over a previous result. A failure is an error. No result and no failure is unknown.
    /// Empty means the profile has a loaded identity but none of the detail rows the page already shows.
    public static func partnerPreviewPhase(loading: Bool, inspection: PublisherPartnerInspection?, failed: Bool) -> PartnerPhase {
        if loading { return .loading }
        if failed { return .error }
        guard let inspection else { return .unknown }
        if partnerDetailIsEmpty(type: inspection.terms.type, profile: inspection.profile) { return .empty(inspection) }
        return .ready(inspection)
    }

    /// True when the partner page would show its empty-profile line. Name and description are not detail rows.
    public static func partnerDetailIsEmpty(type: String, profile: ProjectEditJSON) -> Bool {
        let object = profile.object ?? [:]
        if type == "club" {
            let city = factText(object["city"]) ?? factText(object["address"])
            return factText(object["leaderName"]) == nil && city == nil && factText(object["clubType"]) == nil
                && factText(object["memberCount"]) == nil && factText(object["levelText"]) == nil
        }
        return factText(object["sysCategoryList"]) == nil && factText(object["capacity"]) == nil
            && factText(object["suitActivityTypes"]) == nil && factText(object["availableTime"]) == nil
            && factText(object["chargeType"]) == nil && factText(object["demand"]) == nil
            && factText(object["businessTime"]) == nil && factText(object["address"]) == nil
    }

    /// Profile object the partner page already reads from `PublicMerchantHome`.
    /// Missing capacity is omitted, never stored as 0. `chargeType` is not on that contract and is not invented.
    public static func merchantPartnerProfile(_ home: PublicMerchantHome, ownerMemberID: Int) -> ProjectEditJSON {
        var fields: [String: ProjectEditJSON] = [
            "memberId": .number(Decimal(ownerMemberID)),
            "name": home.name.map(ProjectEditJSON.string) ?? .null,
            "description": home.description.map(ProjectEditJSON.string) ?? .null
        ]
        if let merchantID = home.id, merchantID > 0 { fields["id"] = .number(Decimal(merchantID)) }
        func text(_ key: String, _ value: String?) {
            guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return }
            fields[key] = .string(trimmed)
        }
        text("address", home.address)
        text("businessTime", home.businessTime)
        text("availableTime", home.availableTime)
        text("suitActivityTypes", home.suitActivityTypes)
        text("demand", home.demand)
        if let capacity = home.capacity { fields["capacity"] = .number(Decimal(capacity)) }
        let categories = (home.sysCategoryList ?? []).compactMap { item -> ProjectEditJSON? in
            guard let name = item.categoryName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else { return nil }
            return .object(["categoryName": .string(name)])
        }
        if !categories.isEmpty { fields["sysCategoryList"] = .array(categories) }
        return .object(fields)
    }

    /// Same flattening the partner page uses for a profile value. A missing value is nil, not "0".
    static func factText(_ value: ProjectEditJSON?) -> String? {
        guard let value else { return nil }
        if case .number(let number) = value { return NSDecimalNumber(decimal: number).stringValue }
        if let array = value.array {
            let parts = array.compactMap { factText($0) }
            return parts.isEmpty ? nil : parts.joined(separator: " · ")
        }
        if let object = value.object {
            return ["name", "title", "label", "address", "categoryName"].lazy.compactMap { object[$0]?.text }.first
        }
        guard let text = value.text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty, text != "null" else { return nil }
        return text
    }
}
