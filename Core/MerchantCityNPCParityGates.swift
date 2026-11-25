import Foundation

/// w2-19 gates for the merchant city node, station, cooperation center, store character and
/// player store-day surfaces. Every write switch defaults off; only injected offline DEBUG
/// fixtures may exercise the confirm / request-ID / readback paths.
public struct MerchantCityNPCParityGates: Equatable {
    public var cityNodeWrites = false
    public var stationCommands = false
    public var storeCharacterSaves = false
    public var storeVoiceEnrollment = false
    public var storeDayProofWrites = false
    public var storeDayConsentWrites = false
    /// Reform plan v9 W04/W05: theme NPC binding, scoped knowledge and merchant AI drafts stay dormant.
    public var themeNPCBinding = false
    public var merchantAIDrafts = false
    public init() {}
    public static var disabled: Self { Self() }
    /// Owner 2026-11-25 MP-first rule: the writes the MP merchant pages send, with the server's
    /// permission check deciding. Store-day proof/consent and the W04/W05 reform scopes stay off.
    /// - city node: pages/merchant/citynode/index.js:318,360,483; citynode/create/index.js:397
    /// - game node: utils/game-session-client.js:395,516 (pages/merchant/game-node)
    /// - store character: pages/merchant/decor/ai-npc/index.js:533,744,942,1150
    public static var mpFirst: Self {
        var gates = Self()
        // City-node claim/cancel/offline/save is `MerchantCoopLiveWrites.cityNode`. Station commands stay off.
        gates.storeCharacterSaves = true; gates.storeVoiceEnrollment = true
        return gates
    }
    /// Per-market endpoint allowlist for these writes (MP-first, owner 2026-11-25). A gate flag must
    /// also be on; `.disabled` still never dispatches.
    public static var reviewedEndpoints: [RegionalMarket: Set<String>] { [.china: mpFirstChinaEndpoints] }
    public static let mpFirstChinaEndpoints: Set<String> = [
        "api/merchant/city-node/claim", "api/merchant/city-node/claim/cancel",
        "api/merchant/city-node/offline", "api/merchant/city-node/save",
        "api/merchant/npc/save", "api/merchant/decor/save", "api/merchant/npc/voice/enroll", "api/merchant/npc/voice/reset",
        "api/compliance/consents"
    ]
    public func allows(_ path: String, market: RegionalMarket) -> Bool {
        Self.reviewedEndpoints[market]?.contains(path) == true
    }
}
