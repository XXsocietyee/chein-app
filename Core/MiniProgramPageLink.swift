import Foundation

/// A mini-program page path plus its query, accepted only for pages that have a native screen.
///
/// Parsing classifies a link and grants nothing: the host maps it to its parity route, and that screen keeps its own
/// sign-in, capability and confirmation gating (money stays off). Unknown pages, unknown or repeated keys, a missing
/// required key, a non-canonical id, a value over 512 UTF-16 code units or a control character reject the whole link.
public struct MiniProgramPageLink: Equatable, Sendable {
    /// Page path without the leading slash, for example `subpackageMember/market/gift/index`.
    public let page: String
    public let query: [String: String]

    public struct Rule: Equatable, Sendable {
        public let allowed: Set<String>
        public let required: Set<String>
        /// Keys whose value must be a positive canonical decimal id.
        public let ids: Set<String>
    }

    /// Every mini-program page the native parity router opens (`MPParityRoute(miniProgramPath:query:)`).
    /// `subpackagePass/reveal/index` takes no query: paid reveal facts in a link would be unverified, so they stay off.
    public static let reviewedPages: [String: Rule] = [
        "subpackageA/pages/video-bounty/index": .init(allowed: ["campaignKey", "topicId"], required: [], ids: ["topicId"]),
        "subpackageMember/market/passes/index": .init(allowed: ["tab"], required: [], ids: []),
        "subpackageMember/market/pass/index": .init(allowed: ["id"], required: ["id"], ids: []),
        "subpackageMember/market/gift/index": .init(allowed: ["token"], required: ["token"], ids: []),
        "subpackageMember/market/membership/index": .init(allowed: [], required: [], ids: []),
        "subpackageMember/market/library/index": .init(allowed: ["kind"], required: [], ids: []),
        "subpackagePass/reveal/index": .init(allowed: [], required: [], ids: []),
        "subpackageJourney/pages/landing/index": .init(allowed: ["k", "t", "aid", "tid"], required: ["k", "t"], ids: ["aid", "tid"]),
        "subpackageJourney/pages/seats/index": .init(allowed: ["registrationId"], required: ["registrationId"], ids: ["registrationId"]),
        "subpackageJourney/pages/promo/index": .init(allowed: [], required: [], ids: []),
        "subpackageJourney/pages/report/index": .init(allowed: ["activityId", "topicId", "runId", "topicName", "registrationId"],
                                                      required: [], ids: ["activityId", "topicId", "runId", "registrationId"]),
        "subpackageJourney/pages/settle/index": .init(allowed: ["activityId", "topicId", "runId", "topicName", "registrationId"],
                                                      required: [], ids: ["activityId", "topicId", "runId", "registrationId"]),
    ]

    public init?(path: String, query: [String: String]) {
        let page = path.hasPrefix("/") ? String(path.dropFirst()) : path
        guard let rule = Self.reviewedPages[page] else { return nil }
        // Empty values are absent (the mini-program reads `options.x || ''`).
        let present = query.filter { !$0.value.isEmpty }
        guard Set(query.keys).isSubset(of: rule.allowed), rule.required.isSubset(of: Set(present.keys)) else { return nil }
        for (key, value) in present {
            guard value.utf16.count <= 512, value.unicodeScalars.allSatisfy({ $0.value >= 32 && $0.value != 127 }) else { return nil }
            if rule.ids.contains(key), Self.positiveID(value) == nil { return nil }
        }
        if page == "subpackageJourney/pages/landing/index", !["r", "g", "s"].contains(present["k"] ?? "") { return nil }
        self.page = page
        self.query = present
    }

    /// Query items as a URL carries them: each name once, every item with a value.
    public init?(path: String, items: [URLQueryItem]) {
        guard Set(items.map(\.name)).count == items.count, items.allSatisfy({ $0.value != nil }) else { return nil }
        self.init(path: path, query: Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value!) }))
    }

    /// `chein://mp/<page path>?<query>`: the custom-scheme form of a mini-program page link.
    public init?(cheinURL url: URL) {
        guard url.absoluteString.utf8.count <= 2048,
              let c = URLComponents(url: url, resolvingAgainstBaseURL: false),
              c.scheme?.lowercased() == CheinDeepLink.scheme, c.host?.lowercased() == "mp",
              c.user == nil, c.password == nil, c.port == nil, c.fragment == nil,
              c.path.hasPrefix("/") else { return nil }
        self.init(path: c.path, items: c.queryItems ?? [])
    }

    /// A referral, gift or seat landing (`chein://landing?k=…`) opens the same journey landing page.
    public init(journey intake: JourneyLinkIntake) {
        let kind: String
        switch intake.kind {
        case .referral: kind = "r"
        case .gift: kind = "g"
        case .seat: kind = "s"
        }
        var query = ["k": kind, "t": intake.token]
        if let id = intake.activityID { query["aid"] = String(id) }
        if let id = intake.topicID { query["tid"] = String(id) }
        page = "subpackageJourney/pages/landing/index"
        self.query = query
    }

    private static func positiveID(_ text: String) -> Int? {
        guard text.utf8.count <= 18, text.utf8.allSatisfy({ (48...57).contains($0) }),
              let value = Int(text), value > 0, String(value) == text else { return nil }
        return value
    }
}
