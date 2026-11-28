import Foundation

// City Monopoly + attributes v2 (CITY-MONOPOLY-SPEC v1.0, owner ruling 2026-11-15).
// ONE currency: member points (积分). Every amount the spec writes as 城币 (claim price, rent,
// upgrade, challenge fee, shield, scout, visitor reward) is points here. The app never models a
// separate city coin. The server stays authoritative for every number; these tables only label
// what the server returns and preview it (quotes, DC, win chance) before the player confirms.

// MARK: - Flexible scalar wires

/// A server instant sent either as epoch milliseconds or as an ISO-8601 string.
public struct CityMonopolyInstant: Decodable, Equatable, Sendable {
    public let millis: Int64

    public init(millis: Int64) { self.millis = millis }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(Int64.self) {
            millis = value
            return
        }
        if let value = try? container.decode(Double.self), value.isFinite {
            millis = Int64(value)
            return
        }
        let text = try container.decode(String.self)
        if let value = Int64(text) {
            millis = value
            return
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: text) {
            millis = Int64((date.timeIntervalSince1970 * 1000).rounded())
            return
        }
        formatter.formatOptions = [.withInternetDateTime]
        guard let date = formatter.date(from: text) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unrecognised instant")
        }
        millis = Int64((date.timeIntervalSince1970 * 1000).rounded())
    }

    public var date: Date { Date(timeIntervalSince1970: TimeInterval(millis) / 1000) }

    /// Whole seconds left before this instant (never negative).
    public func secondsRemaining(now: Date) -> Int64 {
        max(0, Int64((date.timeIntervalSince(now)).rounded(.down)))
    }
}

/// A label sent either as a plain string (code or display name) or as an object such as
/// `{code, name, level}`. Used for archetype, equipped title and next unlock, whose exact
/// wire shape the spec does not fix.
public struct CityMonopolyLabel: Decodable, Equatable, Sendable {
    public let code: String?
    public let name: String?
    public let level: Int?
    public let category: String?

    public init(code: String?, name: String?, level: Int? = nil, category: String? = nil) {
        self.code = code; self.name = name; self.level = level; self.category = category
    }

    private enum CodingKeys: String, CodingKey {
        case code, key, titleCode, name, label, title, effect, level, category
    }

    public init(from decoder: Decoder) throws {
        if let single = try? decoder.singleValueContainer(), let text = try? single.decode(String.self) {
            code = text; name = nil; level = nil; category = nil
            return
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = try container.decodeIfPresent(String.self, forKey: .code)
            ?? container.decodeIfPresent(String.self, forKey: .titleCode)
            ?? container.decodeIfPresent(String.self, forKey: .key)
        name = try container.decodeIfPresent(String.self, forKey: .name)
            ?? container.decodeIfPresent(String.self, forKey: .label)
            ?? container.decodeIfPresent(String.self, forKey: .title)
            ?? container.decodeIfPresent(String.self, forKey: .effect)
        level = try container.decodeIfPresent(Int.self, forKey: .level)
        category = try container.decodeIfPresent(String.self, forKey: .category)
    }

    /// Server display name first, then the client title/archetype table, then the raw code.
    public func display(chinese: Bool) -> String {
        if let name, !name.isEmpty { return name }
        if let code, let title = MemberAttributeRules.titleName(code: code, chinese: chinese) { return title }
        if let code, let archetype = MemberArchetype(rawValue: code.lowercased()) { return archetype.name(chinese: chinese) }
        return code ?? "—"
    }
}

// MARK: - Tiers and numbers (§2.1–§2.10, all amounts in points)

/// Property tier T1–T4 (§2.1). Decodes `1...4` or `"T1"..."T4"`.
public enum CityMonopolyTier: Int, CaseIterable, Decodable, Equatable, Sendable {
    case t1 = 1, t2 = 2, t3 = 3, t4 = 4

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(Int.self), let tier = CityMonopolyTier(rawValue: value) {
            self = tier
            return
        }
        let text = try container.decode(String.self).uppercased()
        guard let tier = CityMonopolyTier(rawValue: Int(text.dropFirst(text.hasPrefix("T") ? 1 : 0)) ?? 0) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unknown tier")
        }
        self = tier
    }

    public var code: String { "T\(rawValue)" }

    public func name(chinese: Bool) -> String {
        switch self {
        case .t1: return chinese ? "街角" : "Corner"
        case .t2: return chinese ? "小店" : "Shop"
        case .t3: return chinese ? "名店" : "Famous shop"
        case .t4: return chinese ? "地标" : "Landmark"
        }
    }

    /// Claim price in points.
    public var claimCost: Int64 { [60, 120, 240, 400][rawValue - 1] }
    /// Base rent per eligible visit in points.
    public var baseYield: Int64 { [3, 5, 8, 12][rawValue - 1] }
    /// Season-score holding weight per held day.
    public var holdingDayWeight: Double { [1, 1.5, 2, 3][rawValue - 1] }
}

/// Upgrade level names Lv0–Lv3 (§2.3).
public enum CityMonopolyLevel {
    public static let maxLevel = 3

    public static func name(_ level: Int, chinese: Bool) -> String {
        switch level {
        case 0: return chinese ? "插旗" : "Flag"
        case 1: return chinese ? "前哨" : "Outpost"
        case 2: return chinese ? "据点" : "Stronghold"
        case 3: return chinese ? "地标旗" : "Landmark flag"
        default: return "Lv\(level)"
        }
    }
}

/// District control used by rent set bonus and challenge DC (§2.4, §2.7).
public enum CityDistrictControl: String, Equatable, Sendable {
    case none = "NONE", majority = "MAJORITY", monopoly = "MONOPOLY"

    public init(ownedShare: Double) {
        if ownedShare >= 1 { self = .monopoly } else if ownedShare >= 0.5 { self = .majority } else { self = .none }
    }

    public var setBonus: Double {
        switch self {
        case .none: return 1.0
        case .majority: return 1.2
        case .monopoly: return 1.5
        }
    }

    public var dcBonus: Int {
        switch self {
        case .none: return 0
        case .majority: return 1
        case .monopoly: return 2
        }
    }
}

/// Holder-absence decay (§2.8). Wire values `OK / WEATHERED / DECAYING` (plus `RELEASED` locally).
public enum CityDecayState: String, Equatable, Sendable {
    case ok = "OK", weathered = "WEATHERED", decaying = "DECAYING", released = "RELEASED"

    public init?(wire: String?) {
        guard let wire else { return nil }
        self.init(rawValue: wire.uppercased())
    }

    public func label(chinese: Bool) -> String {
        switch self {
        case .ok: return chinese ? "正常" : "Normal"
        case .weathered: return chinese ? "风化" : "Weathered"
        case .decaying: return chinese ? "失修" : "Decaying"
        case .released: return chinese ? "已释放" : "Released"
        }
    }
}

/// Season phase (§2.10).
public enum CitySeasonPhase: String, Equatable, Sendable {
    case opening = "OPENING", regular = "REGULAR", finale = "FINALE", frozen = "FROZEN", settling = "SETTLING"

    public init?(wire: String?) {
        guard let wire else { return nil }
        self.init(rawValue: wire.uppercased())
    }

    /// Day 1–3 opening, 4–21 regular, 22–28 finale.
    public init?(seasonDay: Int) {
        switch seasonDay {
        case 1...3: self = .opening
        case 4...21: self = .regular
        case 22...CityMonopolyRules.seasonLengthDays: self = .finale
        default: return nil
        }
    }

    public func label(chinese: Bool) -> String {
        switch self {
        case .opening: return chinese ? "开城" : "Opening"
        case .regular: return chinese ? "常规" : "Regular"
        case .finale: return chinese ? "决战周" : "Finale week"
        case .frozen: return chinese ? "已冻结" : "Frozen"
        case .settling: return chinese ? "结算中" : "Settling"
        }
    }
}

/// Client copy of the frozen config (§6.1). Preview only: the server prices and decides.
public enum CityMonopolyRules {
    public static let currency = "POINTS"
    public static let upgradeCostFactor: [Double] = [0.5, 0.8, 1.2]
    public static let yieldMultiplier: [Double] = [1.0, 1.4, 1.8, 2.4]
    public static let dcBonusPerLevel = 2
    public static let multiplierCap = 4.0
    public static let charmYieldPerLevel = 0.002
    public static let weatheredYieldFactor = 0.5
    public static let ownerSoftThreshold: Int64 = 200
    public static let ownerOverRate = 0.5
    public static let ownerOverMax: Int64 = 100
    public static let perPropertyDailyVisits = 20
    public static let visitorDailyYieldingCheckins = 10
    public static let visitorReward: Int64 = 2
    public static let claimsPerDay = 3
    public static let upgradesPerDay = 2
    public static let challengesPerDay = 3
    public static let holdingBase = 9
    public static let holdingMax = 12
    public static let holdingExploreLevels = [15, 30, 45]
    public static let protectionAfterClaimHours = 24
    public static let protectionAfterClaimFinaleHours = 12
    public static let protectionAfterDefenseHours = 12
    public static let protectionAfterTakeoverHours = 24
    public static let shieldCost: Int64 = 60
    public static let shieldHours = 12
    public static let shieldMaxTotalHours = 48
    public static let scoutCost: Int64 = 10
    public static let challengeFeeRate = 0.5
    public static let challengeFeeMin: Int64 = 30
    public static let finaleChallengeDiscount = 0.25
    public static let revengeDiscount = 0.5
    public static let defenderCompOnWin = 0.40
    public static let defenderCompOnLoss = 0.30
    public static let challengeModCap = 6
    public static let challengeDCMax = 20
    public static let seasonLengthDays = 28
    public static let stipend: Int64 = 300

    /// Upgrade price from `fromLevel` to `fromLevel + 1`; nil at max level.
    public static func upgradeCost(tier: CityMonopolyTier, fromLevel: Int) -> Int64? {
        guard upgradeCostFactor.indices.contains(fromLevel) else { return nil }
        return Int64((Double(tier.claimCost) * upgradeCostFactor[fromLevel]).rounded())
    }

    /// Claim price plus every upgrade paid up to `level`.
    public static func invested(tier: CityMonopolyTier, level: Int) -> Int64 {
        let capped = min(max(level, 0), CityMonopolyLevel.maxLevel)
        return (0..<capped).reduce(tier.claimCost) { $0 + (upgradeCost(tier: tier, fromLevel: $1) ?? 0) }
    }

    public static func levelMultiplier(_ level: Int) -> Double {
        yieldMultiplier[min(max(level, 0), yieldMultiplier.count - 1)]
    }

    /// Rent time band in Asia/Shanghai (§2.4): 23:00–06:00 yields nothing.
    public static func timeBand(hour: Int) -> Double {
        switch hour {
        case 6..<10: return 1.1
        case 10..<17: return 1.0
        case 17..<21: return 1.2
        case 21..<23: return 1.0
        default: return 0
        }
    }

    /// `round(base × min(cap, U × S × T × W × B × (1 + 0.002 × charm)))`, halved while weathered.
    public static func rent(tier: CityMonopolyTier, level: Int, district: CityDistrictControl = .none,
                             timeBand: Double = 1.0, environment: Double = 1.0, teamBonus: Bool = false,
                             ownerCharmLevel: Int = 0, weathered: Bool = false) -> Int64 {
        let product = levelMultiplier(level) * district.setBonus * timeBand * environment
            * (teamBonus ? 1.1 : 1.0) * (1 + charmYieldPerLevel * Double(min(max(ownerCharmLevel, 0), 50)))
        let raw = Double(tier.baseYield) * min(multiplierCap, product) * (weathered ? weatheredYieldFactor : 1)
        return Int64(raw.rounded())
    }

    /// Owner daily soft threshold `T = 200 + min(100, 2 × charm)`.
    public static func ownerDailyThreshold(charmLevel: Int) -> Int64 {
        ownerSoftThreshold + min(100, 2 * Int64(max(charmLevel, 0)))
    }

    /// Owner daily hard cap `T + 100`.
    public static func ownerDailyMax(charmLevel: Int) -> Int64 {
        ownerDailyThreshold(charmLevel: charmLevel) + ownerOverMax
    }

    /// Points granted for one more raw rent when `alreadyGranted` was booked today:
    /// 100% up to T, 50% beyond, never above T + 100.
    public static func ownerGrant(raw: Int64, alreadyGranted: Int64, charmLevel: Int) -> Int64 {
        let threshold = ownerDailyThreshold(charmLevel: charmLevel)
        let hardMax = ownerDailyMax(charmLevel: charmLevel)
        guard raw > 0, alreadyGranted < hardMax else { return 0 }
        let full = max(0, min(raw, threshold - alreadyGranted))
        let over = raw - full
        let halved = Int64((Double(over) * ownerOverRate).rounded(.down))
        return min(full + halved, hardMax - alreadyGranted)
    }

    /// Personal holding limit: 9, +1 at explore Lv15/30/45, at most 12.
    public static func holdingLimit(exploreLevel: Int) -> Int {
        min(holdingMax, holdingBase + holdingExploreLevels.filter { exploreLevel >= $0 }.count)
    }

    /// Challenge fee `max(30, 0.5 × invested)`, −25% in finale week, −50% revenge for the former owner.
    public static func challengeFee(invested: Int64, finale: Bool = false, revenge: Bool = false) -> Int64 {
        var fee = Double(max(challengeFeeMin, Int64((Double(invested) * challengeFeeRate).rounded())))
        if finale { fee *= 1 - finaleChallengeDiscount }
        if revenge { fee *= 1 - revengeDiscount }
        return Int64(fee.rounded())
    }

    /// `DC = 10 + 2×lvl + 2×[recent owner visit] + district − 2×[weathered]`, at most 20.
    public static func challengeDC(level: Int, ownerVisitedRecently: Bool, district: CityDistrictControl, weathered: Bool) -> Int {
        let dc = 10 + dcBonusPerLevel * max(level, 0) + (ownerVisitedRecently ? 2 : 0) + district.dcBonus - (weathered ? 2 : 0)
        return min(challengeDCMax, dc)
    }

    /// `mod = task(0–2) + insight(+1 @15, +2 @35) + warmup + assists`, capped at 6.
    public static func challengeMod(taskScore: Int, insightLevel: Int, assists: Int, warmup: Bool = false,
                                    staminaLevel: Int = 0, charmLevel: Int = 0) -> Int {
        let insight = insightLevel >= 35 ? 2 : (insightLevel >= 15 ? 1 : 0)
        let assistCap = charmLevel >= 30 ? 3 : 2
        let warm = warmup && staminaLevel >= 20 ? 1 : 0
        let total = min(max(taskScore, 0), 2) + insight + min(max(assists, 0), assistCap) + warm
        return min(challengeModCap, total)
    }

    /// d20 + mod ≥ DC wins; a natural 20 always wins and a natural 1 always loses.
    public static func challengerWins(roll: Int, mod: Int, dc: Int) -> Bool {
        if roll == 20 { return true }
        if roll == 1 { return false }
        return roll + mod >= dc
    }

    /// Win chance in whole percent (§2.7 table).
    public static func winChancePercent(dc: Int, mod: Int) -> Int {
        (1...20).filter { challengerWins(roll: $0, mod: mod, dc: dc) }.count * 5
    }

    /// Defender compensation and burned remainder for a settled challenge.
    public static func feeSplit(fee: Int64, challengerWon: Bool) -> (defender: Int64, burned: Int64) {
        let defender = Int64((Double(fee) * (challengerWon ? defenderCompOnWin : defenderCompOnLoss)).rounded(.down))
        return (defender, fee - defender)
    }

    /// Lore grace days: +1 at Lv20, +2 at Lv40.
    public static func decayGraceDays(loreLevel: Int) -> Int { loreLevel >= 40 ? 2 : (loreLevel >= 20 ? 1 : 0) }

    /// Decay from days since the holder's last visit (§2.8).
    public static func decayState(daysSinceOwnerVisit days: Int, loreLevel: Int = 0) -> CityDecayState {
        let grace = decayGraceDays(loreLevel: loreLevel)
        if days < 7 + grace { return .ok }
        if days < 14 + grace { return .weathered }
        if days < 21 + grace { return .decaying }
        return .released
    }

    /// Level steps lost to decay: 1 on day 14 (+grace), then 1 more every 3 days.
    public static func decayLevelDrops(daysSinceOwnerVisit days: Int, loreLevel: Int = 0) -> Int {
        let start = 14 + decayGraceDays(loreLevel: loreLevel)
        guard days >= start else { return 0 }
        return 1 + (days - start) / 3
    }

    /// Protection hours granted after a claim (12 h in finale week).
    public static func claimProtectionHours(phase: CitySeasonPhase?) -> Int {
        phase == .finale ? protectionAfterClaimFinaleHours : protectionAfterClaimHours
    }

    /// Scout is free from lore Lv10.
    public static func scoutCost(loreLevel: Int) -> Int64 { loreLevel >= 10 ? 0 : scoutCost }

    /// Rerolls per day from luck: 1 at Lv10, 2 at Lv25.
    public static func rerollsPerDay(luckLevel: Int) -> Int { luckLevel >= 25 ? 2 : (luckLevel >= 10 ? 1 : 0) }
}

// MARK: - Territory wires (§6.2)

public struct CityTerritoryHolder: Decodable, Equatable, Sendable {
    public let maskedName: String?
    public let archetype: CityMonopolyLabel?
    public let title: CityMonopolyLabel?
    public let isMe: Bool?
    public let isMyTeam: Bool?
}

/// One property on the territory layer. Under fog only `districtId` and `tier` are sent.
public struct CityTerritoryProperty: Decodable, Equatable, Identifiable, Sendable {
    public let propertyId: String?
    public let pointId: String?
    public let geohash7: String?
    public let tier: CityMonopolyTier?
    public let districtId: String?
    public let colorToken: String?
    public let status: String?
    public let lvl: Int?
    public let holder: CityTerritoryHolder?
    public let protectedUntil: CityMonopolyInstant?
    public let decayState: String?
    /// Live `wire()` fields: the place, its anchor and its numbers (absent under fog).
    public let title: String?
    public let lat: Double?
    public let lng: Double?
    public let poiId: Int64?
    public let boardId: String?
    public let invested: Int64?
    public let baseYield: Int64?
    public let levelMultiplier: Double?
    /// fix/city-gaps-r3 (live on TEST): the district's display name and colour key (also on fogged items) and the deed
    /// serial (`地契 · No. N`, visible items only). Nil when the server has no district row or issued no serial.
    public let districtName: String?
    public let districtColorToken: String?
    public let deedSerial: Int?

    public var id: String { propertyId ?? pointId ?? geohash7 ?? "\(districtId ?? "?")-\(tier?.code ?? "?")" }
    /// The player has not lit this tile: holder, level and protection stay hidden.
    public var isFogged: Bool { propertyId == nil && pointId == nil }
    public var decay: CityDecayState? { CityDecayState(wire: decayState) }
    public var isMine: Bool { holder?.isMe == true }
}

/// fix/city-gaps-r3: one board district (`districts[]` on the map and nearby reads). Names and colours are public board
/// metadata. `colorIndex` is N for a `district.cN` token and nil otherwise (the client then keeps its own slot).
public struct CityDistrictInfo: Decodable, Equatable, Sendable {
    public let boardId: String?
    public let districtId: String?
    public let name: String?
    public let colorToken: String?
    public let colorIndex: Int?
    public let ownableCount: Int?
    public let safetyBlocked: Bool?

    public init(boardId: String? = nil, districtId: String?, name: String?, colorToken: String? = nil, colorIndex: Int? = nil,
                ownableCount: Int? = nil, safetyBlocked: Bool? = nil) {
        self.boardId = boardId; self.districtId = districtId; self.name = name; self.colorToken = colorToken
        self.colorIndex = colorIndex; self.ownableCount = ownableCount; self.safetyBlocked = safetyBlocked
    }

    /// The colour slot 1…6 for this district: `colorIndex`, else the N of a `district.cN` token; nil = keep the client slot.
    public var colorSlot: Int? { CityDistrictInfo.slot(index: colorIndex, token: colorToken) }

    /// `district.c3` → 3. Values outside 1…6 wrap into the six band colours; anything else is nil.
    public static func slot(index: Int?, token: String?) -> Int? {
        if let index, index > 0 { return (index - 1) % 6 + 1 }
        guard let token = token?.trimmingCharacters(in: .whitespaces).lowercased(), token.hasPrefix("district.c"),
              let n = Int(token.dropFirst("district.c".count)), n > 0 else { return nil }
        return (n - 1) % 6 + 1
    }
}

public struct CityTerritoryMapResponse: Decodable, Equatable, Sendable {
    public let boardId: String?
    public let seasonId: String?
    public let currency: String?
    public let properties: [CityTerritoryProperty]
    /// fix/city-gaps-r3: district metadata for every board in the result; empty on older servers.
    public let districts: [CityDistrictInfo]

    private enum CodingKeys: String, CodingKey { case boardId, seasonId, currency, properties, items, districts }

    /// Accepts a bare array or an object with `properties` / `items`.
    public init(from decoder: Decoder) throws {
        if let single = try? decoder.singleValueContainer(), let list = try? single.decode([CityTerritoryProperty].self) {
            boardId = nil; seasonId = nil; currency = nil; properties = list; districts = []
            return
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        boardId = try container.decodeIfPresent(String.self, forKey: .boardId)
        seasonId = try container.decodeIfPresent(String.self, forKey: .seasonId)
        currency = try container.decodeIfPresent(String.self, forKey: .currency)
        properties = try container.decodeIfPresent([CityTerritoryProperty].self, forKey: .properties)
            ?? container.decodeIfPresent([CityTerritoryProperty].self, forKey: .items) ?? []
        districts = (try? container.decodeIfPresent([CityDistrictInfo].self, forKey: .districts)) ?? []
    }
}

/// `GET /api/city-game/territory/property/{propertyId}`: deed card with rent breakdown.
public struct CityTerritoryPropertyCard: Decodable, Equatable, Sendable {
    public let propertyId: String
    public let title: String?
    public let tier: CityMonopolyTier?
    public let lvl: Int?
    public let status: String?
    public let districtId: String?
    public let holder: CityTerritoryHolder?
    public let protectedUntil: CityMonopolyInstant?
    public let shieldUntil: CityMonopolyInstant?
    public let lastOwnerVisitAt: CityMonopolyInstant?
    public let decayState: String?
    public let deedPhotoUrl: String?
    /// The live server's names for the deed photo and the week's visits.
    public let deedPhoto: String?
    public let visitsThisWeek: Int?
    public let lat: Double?
    public let lng: Double?
    public let levelMultiplier: Double?
    /// Present only after the viewer scouted this property.
    public let dc: Int?
    public let weeklyVisits: Int?
    public let invested: Int64?
    public let baseYield: Int64?
    public let estimatedYield: Int64?
    public let challengesToday: Int?
    public let version: Int64?
    /// Rent multiplier breakdown, keyed as the server names them (e.g. `U`, `S_set`, `T_time`).
    public let multipliers: [String: Double]?
    /// fix/city-gaps-r3: district name and colour key, and the deed serial; nil when not issued.
    public let districtName: String?
    public let districtColorToken: String?
    public let deedSerial: Int?

    public var decay: CityDecayState? { CityDecayState(wire: decayState) }
    /// The claim photo, whichever name the server used.
    public var photoURL: String? { [deedPhoto, deedPhotoUrl].compactMap { $0 }.first { !$0.isEmpty } }
    public var visits: Int? { visitsThisWeek ?? weeklyVisits }
}

public struct CityChallengeTask: Decodable, Equatable, Sendable {
    public let taskId: String?
    public let kind: String?
    public let title: String?
}

/// Claim / upgrade / challenge quote. Prices are points.
public struct CityTerritoryQuote: Decodable, Equatable, Sendable {
    public let quoteId: String
    public let quoteHash: String
    public let propertyId: String?
    public let cost: Int64?
    public let fee: Int64?
    public let protectionHours: Int?
    public let expiresAt: CityMonopolyInstant?
    public let dc: Int?
    public let task: CityChallengeTask?
    public let toLevel: Int?
    public let currency: String?
    public let version: Int64?

    /// The points the confirm will charge (claim/upgrade `cost`, challenge `fee`).
    public var price: Int64? { cost ?? fee }
}

public struct CityTerritoryQuoteRequest: Encodable, Equatable, Sendable {
    public let propertyId: String
    public let lat: Double?
    public let lng: Double?
    public let hAcc: Double?
    /// Live server keys (`ApiCityMonopolyController`): a claim names its space by `poiId` or
    /// `boardId` + `pointId`; upgrade and challenge name the held territory by `territoryId`.
    public let territoryId: String?
    public let poiId: Int64?
    public let boardId: String?
    public let pointId: String?

    public init(propertyId: String, lat: Double? = nil, lng: Double? = nil, hAcc: Double? = nil,
                territoryId: String? = nil, poiId: Int64? = nil, boardId: String? = nil, pointId: String? = nil) {
        self.propertyId = propertyId; self.lat = lat; self.lng = lng; self.hAcc = hAcc
        self.territoryId = territoryId; self.poiId = poiId; self.boardId = boardId; self.pointId = pointId
    }
}

public struct CityTerritoryLocationSample: Codable, Equatable, Sendable {
    public let t: Int64
    public let lat: Double
    public let lng: Double
    public let hAcc: Double

    public init(t: Int64, lat: Double, lng: Double, hAcc: Double) {
        self.t = t; self.lat = lat; self.lng = lng; self.hAcc = hAcc
    }
}

/// Presence evidence (§2.2). Upgrade and challenge omit the photo.
public struct CityTerritoryEvidence: Encodable, Equatable, Sendable {
    public let photoAssetId: String?
    public let capturedAt: Int64
    public let lat: Double
    public let lng: Double
    public let hAcc: Double
    public let samples: [CityTerritoryLocationSample]
    public let simulated: Bool
    public let attestAssertion: String?
    public let merchantQr: String?
    /// The photo was taken by the in-app camera (§2.2), with the fix at the shutter.
    public let inAppCamera: Bool?
    public let captureLat: Double?
    public let captureLng: Double?

    public init(photoAssetId: String? = nil, capturedAt: Int64, lat: Double, lng: Double, hAcc: Double,
                samples: [CityTerritoryLocationSample], simulated: Bool = false,
                attestAssertion: String? = nil, merchantQr: String? = nil,
                inAppCamera: Bool? = nil, captureLat: Double? = nil, captureLng: Double? = nil) {
        self.photoAssetId = photoAssetId; self.capturedAt = capturedAt; self.lat = lat; self.lng = lng
        self.hAcc = hAcc; self.samples = samples; self.simulated = simulated
        self.attestAssertion = attestAssertion; self.merchantQr = merchantQr
        self.inAppCamera = inAppCamera; self.captureLat = captureLat; self.captureLng = captureLng
    }
}

/// Write body shared by claim / upgrade / challenge commands. `requestId` is an upper-case UUID.
public struct CityTerritoryCommandRequest: Encodable, Equatable, Sendable {
    public let requestId: String
    public let propertyId: String
    public let quoteId: String
    public let quoteHash: String
    public let expectedVersion: Int64?
    public let evidence: CityTerritoryEvidence

    public init(requestId: String = UUID().uuidString, propertyId: String, quoteId: String, quoteHash: String,
                expectedVersion: Int64? = nil, evidence: CityTerritoryEvidence) {
        self.requestId = requestId; self.propertyId = propertyId; self.quoteId = quoteId
        self.quoteHash = quoteHash; self.expectedVersion = expectedVersion; self.evidence = evidence
    }
}

/// One challenge modifier, sent as a bare integer or `{source, value}`.
public struct CityChallengeModifier: Decodable, Equatable, Sendable {
    public let source: String?
    public let value: Int

    private enum CodingKeys: String, CodingKey { case source, kind, value }

    public init(source: String?, value: Int) { self.source = source; self.value = value }

    public init(from decoder: Decoder) throws {
        if let single = try? decoder.singleValueContainer(), let number = try? single.decode(Int.self) {
            source = nil; value = number
            return
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        source = try container.decodeIfPresent(String.self, forKey: .source) ?? container.decodeIfPresent(String.self, forKey: .kind)
        value = try container.decode(Int.self, forKey: .value)
    }
}

public struct CityChallengeFeeSplit: Decodable, Equatable, Sendable {
    public let fee: Int64?
    public let defender: Int64?
    public let burned: Int64?
    public let refund: Int64?
    /// The live server names the defender's share `defenderComp`.
    public let defenderComp: Int64?

    public var toDefender: Int64? { defender ?? defenderComp }
}

public enum CityTerritoryOutcomeKind: Equatable, Sendable {
    case applied, challengerWon, challengerLost, rejected, pendingReview, unknown

    public init(wire: String) {
        switch wire.uppercased() {
        case "APPLIED", "SUCCESS", "OK", "CLAIMED", "UPGRADED", "COMMITTED": self = .applied
        case "WON", "WIN", "CHALLENGER_WON", "TAKEOVER": self = .challengerWon
        case "LOST", "LOSS", "CHALLENGER_LOST", "DEFENDED": self = .challengerLost
        case "REJECTED", "DENIED", "FAILED", "BLOCKED": self = .rejected
        case "PENDING", "PENDING_REVIEW", "REVIEW": self = .pendingReview
        default: self = .unknown
        }
    }
}

/// Claim / upgrade / challenge command result. Challenge fills the d20 fields.
public struct CityTerritoryCommandResult: Decodable, Equatable, Sendable {
    public let outcome: String
    public let reasons: [String]?
    public let property: CityTerritoryProperty?
    /// Points balance after the charge.
    public let balance: Int64?
    public let roll: Int?
    public let nat: Int?
    public let mods: [CityChallengeModifier]?
    public let dc: Int?
    public let total: Int?
    public let feeSplit: CityChallengeFeeSplit?
    public let protectionHours: Int?
    public let idempotentReplay: Bool?

    public var kind: CityTerritoryOutcomeKind { CityTerritoryOutcomeKind(wire: outcome) }
    /// `TASK_FAILED`: the on-site task failed, the challenge ended and half the fee came back.
    public var taskFailed: Bool { outcome.uppercased() == "TASK_FAILED" }
    /// The modifier sum the server added to the roll.
    public var modifierTotal: Int { (mods ?? []).reduce(0) { $0 + $1.value } }

    private enum CodingKeys: String, CodingKey {
        case outcome, reasons, property, balance, roll, nat, mods, dc, total, feeSplit, protectionHours, idempotentReplay
    }

    public init(outcome: String, reasons: [String]? = nil, property: CityTerritoryProperty? = nil, balance: Int64? = nil,
                roll: Int? = nil, nat: Int? = nil, mods: [CityChallengeModifier]? = nil, dc: Int? = nil, total: Int? = nil,
                feeSplit: CityChallengeFeeSplit? = nil, protectionHours: Int? = nil, idempotentReplay: Bool? = nil) {
        self.outcome = outcome; self.reasons = reasons; self.property = property; self.balance = balance
        self.roll = roll; self.nat = nat; self.mods = mods; self.dc = dc; self.total = total
        self.feeSplit = feeSplit; self.protectionHours = protectionHours; self.idempotentReplay = idempotentReplay
    }

    /// `mods` arrives as a list or, from the live server, as `{"task":1,"insight":0,…}`.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        outcome = try c.decode(String.self, forKey: .outcome)
        reasons = try c.decodeIfPresent([String].self, forKey: .reasons)
        property = try c.decodeIfPresent(CityTerritoryProperty.self, forKey: .property)
        balance = try c.decodeIfPresent(Int64.self, forKey: .balance)
        roll = try c.decodeIfPresent(Int.self, forKey: .roll)
        nat = try? c.decodeIfPresent(Int.self, forKey: .nat)
        if let list = try? c.decodeIfPresent([CityChallengeModifier].self, forKey: .mods) {
            mods = list
        } else if let map = try? c.decodeIfPresent([String: Int].self, forKey: .mods) {
            mods = map.keys.sorted().map { CityChallengeModifier(source: $0, value: map[$0] ?? 0) }
        } else {
            mods = nil
        }
        dc = try c.decodeIfPresent(Int.self, forKey: .dc)
        total = try c.decodeIfPresent(Int.self, forKey: .total)
        feeSplit = try? c.decodeIfPresent(CityChallengeFeeSplit.self, forKey: .feeSplit)
        protectionHours = try c.decodeIfPresent(Int.self, forKey: .protectionHours)
        idempotentReplay = try c.decodeIfPresent(Bool.self, forKey: .idempotentReplay)
    }
}

public struct CityScoutResult: Decodable, Equatable, Sendable {
    public let propertyId: String?
    public let territoryId: String?
    public let dc: Int
    public let cost: Int64?
    public let balance: Int64?
}

public struct CityShieldResult: Decodable, Equatable, Sendable {
    public let propertyId: String?
    public let shieldUntil: CityMonopolyInstant?
    public let protectedUntil: CityMonopolyInstant?
    public let cost: Int64?
    public let balance: Int64?
}

public struct CityPropertyActionRequest: Encodable, Equatable, Sendable {
    public let requestId: String
    public let propertyId: String
    public let expectedVersion: Int64?

    public init(requestId: String = UUID().uuidString, propertyId: String, expectedVersion: Int64? = nil) {
        self.requestId = requestId; self.propertyId = propertyId; self.expectedVersion = expectedVersion
    }

    private enum CodingKeys: String, CodingKey { case requestId, propertyId, territoryId, expectedVersion }

    /// The live scout / shield routes read `territoryId`; the wire property id is that territory id.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(requestId, forKey: .requestId)
        try container.encode(propertyId, forKey: .propertyId)
        try container.encode(propertyId, forKey: .territoryId)
        try container.encodeIfPresent(expectedVersion, forKey: .expectedVersion)
    }
}

/// Rent ledger state: pending at once, available after the 03:00 risk batch, void on clawback.
public enum CityYieldState: String, Equatable, Sendable {
    case pending = "PENDING", available = "AVAILABLE", void = "VOID"
}

public struct CityYieldEvent: Decodable, Equatable, Identifiable, Sendable {
    public let eventId: String?
    public let visitorMasked: String?
    public let propertyId: String?
    public let base: Int64?
    public let multipliers: [String: Double]?
    public let granted: Int64
    public let capReason: String?
    public let state: String
    public let createdAt: CityMonopolyInstant?

    public var id: String { eventId ?? "\(propertyId ?? "?")-\(createdAt?.millis ?? 0)-\(visitorMasked ?? "")" }
    public var yieldState: CityYieldState? { CityYieldState(rawValue: state.uppercased()) }
}

/// `GET /api/city-game/territory/revenue`: owner rent (points) with caps and their reasons.
public struct CityRevenuePage: Decodable, Equatable, Sendable {
    public let events: [CityYieldEvent]
    public let todayPending: Int64?
    public let todayAvailable: Int64?
    public let threshold: Int64?
    public let nextCursor: String?
}

/// `GET /api/city-game/season/current`.
public struct CitySeasonCurrent: Decodable, Equatable, Sendable {
    public let seasonId: String
    public let phase: String?
    public let dayIndex: Int?
    public let startsAt: CityMonopolyInstant?
    public let endsAt: CityMonopolyInstant?
    public let freezesAt: CityMonopolyInstant?
    public let myScore: Double?
    public let myRank: Int?
    public let participants: Int?
    public let holdingCount: Int?
    public let holdingLimit: Int?
    /// The live server sends the season day as `day`.
    public let day: Int?

    public var seasonDay: Int? { dayIndex ?? day }
    public var seasonPhase: CitySeasonPhase? {
        CitySeasonPhase(wire: phase) ?? seasonDay.flatMap { CitySeasonPhase(seasonDay: $0) }
    }
}

/// `GET /api/city-game/territory/points`: the 积分 HUD (balance, pending rent, holdings). No wallet.
public struct CityPointsSummary: Decodable, Equatable, Sendable {
    public let currency: String?
    public let balance: Int64?
    public let pending: Int64?
    public let seasonId: String?
    public let earnedSeason: Int64?
    public let spentSeason: Int64?
    public let holdings: Int?
    public let holdingLimit: Int?

    public init(balance: Int64?, pending: Int64? = nil, holdings: Int? = nil, holdingLimit: Int? = nil,
                seasonId: String? = nil, earnedSeason: Int64? = nil, spentSeason: Int64? = nil) {
        currency = "POINTS"; self.balance = balance; self.pending = pending; self.seasonId = seasonId
        self.earnedSeason = earnedSeason; self.spentSeason = spentSeason; self.holdings = holdings; self.holdingLimit = holdingLimit
    }
}

/// A map viewport for the live territory layer (`minLat`…`maxLng`, each side ≤ 0.5°).
public struct CityMapBounds: Equatable, Sendable {
    public let minLat: Double
    public let minLng: Double
    public let maxLat: Double
    public let maxLng: Double

    /// Clamps the span to the server's 0.5° limit around the centre.
    public init(minLat: Double, minLng: Double, maxLat: Double, maxLng: Double) {
        let cLat = (minLat + maxLat) / 2, cLng = (minLng + maxLng) / 2
        let hLat = min(0.249, max(0.0005, abs(maxLat - minLat) / 2)), hLng = min(0.249, max(0.0005, abs(maxLng - minLng) / 2))
        self.minLat = max(-90, cLat - hLat); self.maxLat = min(90, cLat + hLat)
        self.minLng = max(-180, cLng - hLng); self.maxLng = min(180, cLng + hLng)
    }

    public init(center: RoamCoordinate, radiusMeters: Double) {
        let dLat = radiusMeters / 111_320
        let dLng = radiusMeters / (111_320 * max(0.2, cos(center.latitude * .pi / 180)))
        self.init(minLat: center.latitude - dLat, minLng: center.longitude - dLng,
                  maxLat: center.latitude + dLat, maxLng: center.longitude + dLng)
    }

    public var isValid: Bool {
        [minLat, minLng, maxLat, maxLng].allSatisfy(\.isFinite) && maxLat > minLat && maxLng > minLng
            && maxLat - minLat <= 0.5 && maxLng - minLng <= 0.5
    }
}

public enum CitySeasonScope: String, CaseIterable, Sendable {
    case solo, team, club
}

public struct CitySeasonLeaderboardEntry: Decodable, Equatable, Identifiable, Sendable {
    public let rank: Int
    public let subjectId: String?
    public let name: String?
    public let score: Double
    public let isMe: Bool?

    public var id: String { "\(rank)-\(subjectId ?? name ?? "")" }
}

/// Top 10 plus two either side of the viewer.
public struct CitySeasonLeaderboard: Decodable, Equatable, Sendable {
    public let seasonId: String?
    public let scope: String?
    public let top: [CitySeasonLeaderboardEntry]
    public let around: [CitySeasonLeaderboardEntry]

    private enum CodingKeys: String, CodingKey { case seasonId, scope, top, entries, around, aroundMe }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        seasonId = try container.decodeIfPresent(String.self, forKey: .seasonId)
        scope = try container.decodeIfPresent(String.self, forKey: .scope)
        top = try container.decodeIfPresent([CitySeasonLeaderboardEntry].self, forKey: .top)
            ?? container.decodeIfPresent([CitySeasonLeaderboardEntry].self, forKey: .entries) ?? []
        around = try container.decodeIfPresent([CitySeasonLeaderboardEntry].self, forKey: .around)
            ?? container.decodeIfPresent([CitySeasonLeaderboardEntry].self, forKey: .aroundMe) ?? []
    }

    /// Top rows then the viewer window, without repeating a rank.
    public var rows: [CitySeasonLeaderboardEntry] {
        let ranks = Set(top.map(\.rank))
        return top + around.filter { !ranks.contains($0.rank) }
    }
}

/// Rent fields a visitor check-in may carry once the holder is paid (§6.2 `/api/roam/checkin` change).
/// The spec names the visitor reward `visitorCoins`; under the points ruling it is points.
public struct CityTerritoryVisitYield: Decodable, Equatable, Sendable {
    public let propertyId: String?
    public let holderMasked: String?
    public let yieldPoints: Int64?
    public let visitorPoints: Int64?
    public let ineligibleReason: String?
    public let capReason: String?

    private enum CodingKeys: String, CodingKey {
        case propertyId, holderMasked, yieldPoints = "yield", visitorPoints, visitorCoins, ineligibleReason, capReason
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        propertyId = try container.decodeIfPresent(String.self, forKey: .propertyId)
        holderMasked = try container.decodeIfPresent(String.self, forKey: .holderMasked)
        yieldPoints = try container.decodeIfPresent(Int64.self, forKey: .yieldPoints)
        visitorPoints = try container.decodeIfPresent(Int64.self, forKey: .visitorPoints)
            ?? container.decodeIfPresent(Int64.self, forKey: .visitorCoins)
        ineligibleReason = try container.decodeIfPresent(String.self, forKey: .ineligibleReason)
        capReason = try container.decodeIfPresent(String.self, forKey: .capReason)
    }
}

// MARK: - Attributes v2 (§3)

public enum MemberAttributeKey: String, CaseIterable, Decodable, Equatable, Sendable {
    case explore, stamina, insight, charm, luck, lore

    public func name(chinese: Bool) -> String {
        switch self {
        case .explore: return chinese ? "探索" : "Exploration"
        case .stamina: return chinese ? "体魄" : "Stamina"
        case .insight: return chinese ? "洞察" : "Insight"
        case .charm: return chinese ? "魅力" : "Charisma"
        case .luck: return chinese ? "运气" : "Luck"
        case .lore: return chinese ? "城识" : "Street-smarts"
        }
    }

    /// Daily soft cap S; the day's hard ceiling is 1.25 S.
    public var dailySoftCap: Int {
        switch self {
        case .explore: return 200
        case .stamina, .insight, .lore: return 150
        case .charm: return 120
        case .luck: return 40
        }
    }

    /// Title levels and names (§3.5).
    public var titles: [(level: Int, zh: String, en: String)] {
        switch self {
        case .explore: return [(10, "迷雾行者", "Fog Walker"), (25, "街巷猎人", "Alley Hunter"), (40, "城市制图师", "City Cartographer"), (50, "雾之尽头", "End of the Fog")]
        case .stamina: return [(10, "健步者", "Brisk Walker"), (25, "城市长跑者", "City Runner"), (40, "铁脚板", "Iron Feet"), (50, "不夜行者", "Night Walker")]
        case .insight: return [(10, "细节控", "Detail Hound"), (25, "侦探", "Detective"), (40, "真相猎手", "Truth Hunter"), (50, "城市解谜王", "City Puzzle King")]
        case .charm: return [(10, "好搭子", "Good Company"), (25, "局长", "Host"), (40, "人气王", "Crowd Favorite"), (50, "城市名片", "City Ambassador")]
        case .luck: return [(10, "小确幸", "Small Joys"), (20, "锦鲤", "Koi"), (30, "天选", "Chosen")]
        case .lore: return [(10, "街坊", "Neighbor"), (25, "老城通", "Old-town Guide"), (40, "城市百科", "City Almanac"), (50, "活地图", "Living Map")]
        }
    }
}

/// Display-only archetype from the top two attributes (§3.5).
public enum MemberArchetype: String, CaseIterable, Equatable, Sendable {
    case rover, walker, sleuth, convener, koi, local, polymath

    public init?(primary: MemberAttributeKey) {
        switch primary {
        case .explore: self = .rover
        case .stamina: self = .walker
        case .insight: self = .sleuth
        case .charm: self = .convener
        case .luck: self = .koi
        case .lore: self = .local
        }
    }

    public func name(chinese: Bool) -> String {
        switch self {
        case .rover: return chinese ? "漫游者" : "Rover"
        case .walker: return chinese ? "行脚客" : "Walker"
        case .sleuth: return chinese ? "侦探" : "Sleuth"
        case .convener: return chinese ? "召集人" : "Convener"
        case .koi: return chinese ? "锦鲤" : "Koi"
        case .local: return chinese ? "地头蛇" : "Local"
        case .polymath: return chinese ? "博物家" : "Polymath"
        }
    }
}

public enum MemberAttributeRules {
    public static let maxLevel = 50
    public static let luckMaxEffectiveLevel = 30
    public static let overSoftRate = 0.25

    /// AXP to go from `level` to `level + 1`: `round5(12 × L^1.25 × 1.075^max(0, L−25))`; nil at Lv50.
    public static func need(level: Int) -> Int? {
        guard (1..<maxLevel).contains(level) else { return nil }
        let raw = 12 * pow(Double(level), 1.25) * pow(1.075, Double(max(0, level - 25)))
        return Int((raw / 5).rounded()) * 5
    }

    /// Total AXP needed to reach `level` from Lv1.
    public static func cumulative(level: Int) -> Int {
        guard level > 1 else { return 0 }
        return (1..<min(level, maxLevel)).reduce(0) { $0 + (need(level: $1) ?? 0) }
    }

    /// Highest level whose cumulative AXP is covered, Lv1–Lv50.
    public static func level(forAXP axp: Int) -> Int {
        var level = 1
        var total = 0
        while level < maxLevel, let step = need(level: level), total + step <= axp {
            total += step
            level += 1
        }
        return level
    }

    /// `min(x, S) + 0.25 × min(max(x − S, 0), S)`: daily AXP after diminishing returns.
    public static func effectiveDailyAXP(raw: Int, softCap: Int) -> Int {
        let base = min(max(raw, 0), softCap)
        let over = min(max(raw - softCap, 0), softCap)
        return base + Int((Double(over) * overSoftRate).rounded(.down))
    }

    /// Title code `ATTR_{KEY}_{LV}` (badge code mirrors it).
    public static func titleCode(key: MemberAttributeKey, level: Int) -> String {
        "ATTR_\(key.rawValue.uppercased())_\(level)"
    }

    public static func titleName(code: String, chinese: Bool) -> String? {
        for key in MemberAttributeKey.allCases {
            for title in key.titles where titleCode(key: key, level: title.level) == code.uppercased() {
                return chinese ? title.zh : title.en
            }
        }
        return nil
    }

    /// Titles unlocked at `level` for `key`.
    public static func unlockedTitles(key: MemberAttributeKey, level: Int) -> [String] {
        key.titles.filter { level >= $0.level }.map { titleCode(key: key, level: $0.level) }
    }

    /// Archetype: highest attribute, or polymath when the six levels are within 20% of the top.
    public static func archetype(levels: [MemberAttributeKey: Int]) -> MemberArchetype? {
        let ordered = MemberAttributeKey.allCases.compactMap { key in levels[key].map { (key, $0) } }
        guard ordered.count == MemberAttributeKey.allCases.count,
              let top = ordered.max(by: { $0.1 < $1.1 }), let low = ordered.min(by: { $0.1 < $1.1 }), top.1 > 0 else { return nil }
        if Double(top.1 - low.1) / Double(top.1) <= 0.2 { return .polymath }
        return MemberArchetype(primary: top.0)
    }
}

/// One attribute row of `GET /api/member/attributes`.
public struct MemberAttributeRow: Decodable, Equatable, Identifiable, Sendable {
    public let key: String
    public let level: Int
    public let axp: Int64
    /// AXP still needed (or the step size) for the next level, as the server reports it; nil at Lv50.
    public let need: Int64?
    public let todayAxp: Int64?
    public let softCap: Int64?
    public let nextUnlock: CityMonopolyLabel?

    public var id: String { key }
    public var attribute: MemberAttributeKey? { MemberAttributeKey(rawValue: key.lowercased()) }

    /// Progress inside the current level as `(current, need)`. `axp` is read as lifetime AXP when it
    /// covers the level floor (`cum(level)`), otherwise as AXP already inside the level. Nil at Lv50.
    public var levelProgress: (current: Int64, need: Int64)? {
        guard let need, need > 0 else { return nil }
        let floor = Int64(MemberAttributeRules.cumulative(level: level))
        let inLevel = axp >= floor ? axp - floor : axp
        return (min(max(inLevel, 0), need), need)
    }

    /// AXP left before the next level.
    public var remainingToNextLevel: Int64? { levelProgress.map { $0.need - $0.current } }

    /// Luck stops having effects at Lv30 (later AXP only feeds the "koi" display).
    public var effectiveLevel: Int {
        attribute == .luck ? min(level, MemberAttributeRules.luckMaxEffectiveLevel) : level
    }
}

/// One owned title (`member_title`).
public struct MemberTitle: Decodable, Equatable, Identifiable, Sendable {
    public let code: String
    public let name: String?
    public let category: String?
    public let equipped: Bool?
    public let obtainedAt: CityMonopolyInstant?
    public var id: String { code }

    private enum CodingKeys: String, CodingKey { case code, titleCode, name, category, equipped, obtainedAt }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard let value = try container.decodeIfPresent(String.self, forKey: .code)
                ?? container.decodeIfPresent(String.self, forKey: .titleCode) else {
            throw DecodingError.keyNotFound(CodingKeys.code, .init(codingPath: container.codingPath, debugDescription: "title code"))
        }
        code = value
        name = try container.decodeIfPresent(String.self, forKey: .name)
        category = try container.decodeIfPresent(String.self, forKey: .category)
        equipped = try container.decodeIfPresent(Bool.self, forKey: .equipped)
        obtainedAt = try container.decodeIfPresent(CityMonopolyInstant.self, forKey: .obtainedAt)
    }

    public func display(chinese: Bool) -> String {
        if let name, !name.isEmpty { return name }
        return MemberAttributeRules.titleName(code: code, chinese: chinese) ?? code
    }
}

/// `GET /api/member/attributes`. `titles` is an app-side addition so equip has a list to choose
/// from; when the server omits it the screen shows only the equipped title.
public struct MemberAttributesResponse: Decodable, Equatable, Sendable {
    public let attrs: [MemberAttributeRow]
    public let archetype: CityMonopolyLabel?
    public let equippedTitle: CityMonopolyLabel?
    public let seasonDelta: [String: Double]?
    public let titles: [MemberTitle]?

    /// Rows in the spec's fixed order; unknown keys follow.
    public var orderedAttrs: [MemberAttributeRow] {
        let order = MemberAttributeKey.allCases.map(\.rawValue)
        return attrs.sorted { lhs, rhs in
            (order.firstIndex(of: lhs.key.lowercased()) ?? order.count) < (order.firstIndex(of: rhs.key.lowercased()) ?? order.count)
        }
    }

    public func level(of key: MemberAttributeKey) -> Int? {
        attrs.first { $0.attribute == key }?.level
    }
}

public struct MemberAttributeLedgerEntry: Decodable, Equatable, Identifiable, Sendable {
    public let id: Int64
    public let key: String
    public let raw: Int64
    public let eff: Int64
    public let source: String
    public let sourceId: String?
    public let day: String?
}

public struct MemberAttributeLedgerPage: Decodable, Equatable, Sendable {
    public let items: [MemberAttributeLedgerEntry]
    public let nextCursor: String?
}

public struct MemberTitleEquipRequest: Encodable, Equatable, Sendable {
    public let requestId: String
    /// nil takes the current title off.
    public let titleCode: String?

    public init(requestId: String = UUID().uuidString, titleCode: String?) {
        self.requestId = requestId; self.titleCode = titleCode
    }
}

public struct MemberTitleEquipReceipt: Decodable, Equatable, Sendable {
    public let equippedTitle: CityMonopolyLabel?
}
