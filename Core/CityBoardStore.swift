import Foundation
import Combine

// City Monopoly board store for the map-first 漫游 root, the property sheets, the claim and
// challenge flows, 我的地盘 and the 首页 rail (design hand-off N1, skill-r2 §3.2).
// It joins the two live reads the server offers today:
//   • `GET /api/roam/territory/nearby` – every space on the map (open board points and roam POIs),
//   • `GET /api/city-game/territory/map` – the held monopoly layer (holder, level, protection, decay;
//     district and tier only under fog),
// plus the 积分 HUD (`/territory/points`), the season and today's rent. Every amount is 积分.
// Nothing here invents a value: a field the server does not send stays nil and the view hides it.

/// One place on the City board, as the deed and the map show it.
public struct CityPlace: Identifiable, Equatable {
    public enum Ownership: String, Equatable, Sendable {
        /// Nobody holds it: claimable.
        case open
        /// The viewer holds it.
        case mine
        /// Another player holds it.
        case other
        /// Under fog: the viewer has not lit this tile, so only district and tier are known.
        case fogged
    }

    public let id: String
    public let title: String?
    public let coordinate: RoamCoordinate
    public let territoryId: String?
    public let poiId: Int64?
    public let boardId: String?
    public let pointId: String?
    public let districtId: String?
    /// 1…6: the district colour on the deed band, the map cells and the district chip; 0 = no district.
    public let districtIndex: Int
    public let tier: CityMonopolyTier?
    public let level: Int
    public let ownership: Ownership
    public let holderName: String?
    public let protectedUntil: Date?
    public let decay: CityDecayState?
    public let photoURL: String?
    public let radiusM: Int
    public let distanceM: Double?
    public let invested: Int64?
    /// fix/city-gaps-r3 (live on TEST): the server's district name and deed serial. Nil when the server has no district
    /// row (or only the placeholder seed) or issued no serial: the band falls back to "街区 N" and no serial is shown.
    public let districtName: String?
    public let deedSerial: Int?

    public init(id: String, title: String?, coordinate: RoamCoordinate, territoryId: String? = nil, poiId: Int64? = nil,
                boardId: String? = nil, pointId: String? = nil, districtId: String? = nil, districtIndex: Int = 0,
                tier: CityMonopolyTier? = nil, level: Int = 0, ownership: Ownership, holderName: String? = nil,
                protectedUntil: Date? = nil, decay: CityDecayState? = nil, photoURL: String? = nil, radiusM: Int = 80,
                distanceM: Double? = nil, invested: Int64? = nil, districtName: String? = nil, deedSerial: Int? = nil) {
        self.districtName = districtName.flatMap { $0.trimmingCharacters(in: .whitespaces).isEmpty ? nil : $0 }
        self.deedSerial = deedSerial
        self.id = id; self.title = title; self.coordinate = coordinate; self.territoryId = territoryId; self.poiId = poiId
        self.boardId = boardId; self.pointId = pointId; self.districtId = districtId; self.districtIndex = districtIndex
        self.tier = tier; self.level = level; self.ownership = ownership; self.holderName = holderName
        self.protectedUntil = protectedUntil; self.decay = decay; self.photoURL = photoURL; self.radiusM = radiusM
        self.distanceM = distanceM; self.invested = invested
    }

    public func isProtected(now: Date) -> Bool { protectedUntil.map { $0 > now } ?? false }
    public var isWeathered: Bool { decay == .weathered || decay == .decaying }

    /// Rent one visit earns at this level (no district, time or weather bonus). Nil without a tier.
    public var rentPerVisit: Int64? {
        tier.map { CityMonopolyRules.rent(tier: $0, level: level, weathered: isWeathered) }
    }

    /// The claim price for an open place by its tier; nil until the server names the tier (the quote does).
    public var claimPrice: Int64? { ownership == .open ? tier?.claimCost : nil }

    /// Max-level ladder of the live server: 插旗 Lv0 → 前哨 Lv1 → 据点 Lv2 → 地标旗 Lv3.
    public var canUpgrade: Bool { ownership == .mine && level < CityMonopolyLevel.maxLevel }

    /// Challenge fee preview `max(30, 0.5 × invested)`; the quote is the authority.
    public var challengeFeePreview: Int64? {
        guard ownership == .other else { return nil }
        let invested = invested ?? tier.map { CityMonopolyRules.invested(tier: $0, level: level) }
        return invested.map { CityMonopolyRules.challengeFee(invested: $0) }
    }

    /// The command target the live quote route reads.
    public func quoteRequest(_ kind: CityTerritoryActionKind, fix: RoamDeviceFix?) -> CityTerritoryQuoteRequest {
        CityTerritoryQuoteRequest(propertyId: territoryId ?? id, lat: fix?.coordinate.latitude, lng: fix?.coordinate.longitude,
                                  hAcc: fix?.accuracyMeters,
                                  territoryId: kind == .claim ? nil : territoryId,
                                  poiId: kind == .claim ? poiId : nil,
                                  boardId: kind == .claim && pointId != nil ? boardId : nil,
                                  pointId: kind == .claim && boardId != nil ? pointId : nil)
    }

    /// Metres from `from`, or the server's distance when no fix is known.
    public func distance(from: RoamCoordinate?) -> Double? {
        from.map { CityPresencePreflight.distanceM($0, coordinate) } ?? distanceM
    }
}

/// Geohash (base-32) decoding to the cell centre: fogged tiles arrive with their `geohash7` only.
public enum CityGeohash {
    private static let alphabet = Array("0123456789bcdefghjkmnpqrstuvwxyz")

    public static func center(_ hash: String) -> RoamCoordinate? {
        guard !hash.isEmpty, hash.count <= 12 else { return nil }
        var lat = (-90.0, 90.0), lng = (-180.0, 180.0)
        var even = true
        for character in hash.lowercased() {
            guard let value = alphabet.firstIndex(of: character) else { return nil }
            for bit in stride(from: 4, through: 0, by: -1) {
                let on = (value >> bit) & 1 == 1
                if even {
                    let mid = (lng.0 + lng.1) / 2
                    if on { lng.0 = mid } else { lng.1 = mid }
                } else {
                    let mid = (lat.0 + lat.1) / 2
                    if on { lat.0 = mid } else { lat.1 = mid }
                }
                even.toggle()
            }
        }
        return RoamCoordinate(latitude: (lat.0 + lat.1) / 2, longitude: (lng.0 + lng.1) / 2)
    }
}

/// The district colour slot for each district id: stable (sorted) and in 1…6.
public enum CityDistrictSlots {
    public static func slots(for ids: [String?]) -> [String: Int] {
        let distinct = Set(ids.compactMap { $0 }.filter { !$0.isEmpty }).sorted()
        var out: [String: Int] = [:]
        for (index, id) in distinct.enumerated() { out[id] = index % 6 + 1 }
        return out
    }
}

/// fix/city-gaps-r3: `districts[]` from the map and nearby reads, looked up by board + district (or district alone).
public struct CityDistrictBook {
    private var byBoard: [String: CityDistrictInfo] = [:]
    private var byDistrict: [String: CityDistrictInfo] = [:]

    public init(_ districts: [CityDistrictInfo]) {
        for info in districts {
            guard let id = info.districtId, !id.isEmpty else { continue }
            if let board = info.boardId { byBoard[board + "|" + id] = byBoard[board + "|" + id] ?? info }
            byDistrict[id] = byDistrict[id] ?? info
        }
    }

    public func info(_ districtId: String?, board: String?) -> CityDistrictInfo? {
        guard let districtId, !districtId.isEmpty else { return nil }
        if let board, let hit = byBoard[board + "|" + districtId] { return hit }
        return byDistrict[districtId]
    }

    /// A name worth showing: not blank, and not the migration's placeholder seed (the district id itself).
    public static func usable(_ name: String?, districtId: String?) -> String? {
        guard let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
        if let districtId, trimmed.caseInsensitiveCompare(districtId) == .orderedSame { return nil }
        return trimmed
    }
}

/// Live `/api/roam/territory/nearby` read for the store (the App wires the reviewed service).
public typealias CityNearbyRead = @MainActor (RoamCoordinate) async throws -> RoamTerritoryNearbyResponse

@MainActor public final class CityBoardStore: ObservableObject {
    public enum Phase: Equatable {
        case idle
        case loading
        case loaded
        /// The read failed with this server error code.
        case failed(String)
        /// No CITY lease in this build or for this viewer: the City layer is hidden.
        case unavailable
    }

    @Published public private(set) var phase: Phase = .idle
    @Published public private(set) var places: [CityPlace] = []
    @Published public private(set) var points: CityPointsSummary?
    @Published public private(set) var season: CitySeasonCurrent?
    @Published public private(set) var revenue: CityRevenuePage?
    @Published public private(set) var pendingQuote: CityPendingTerritoryQuote?
    @Published public private(set) var lastResult: CityTerritoryCommandResult?
    @Published public private(set) var issueCode: String?
    @Published public private(set) var busy = false
    @Published public private(set) var haptic: CityMonopolyHapticTicket?
    /// Places the viewer held on the previous load and no longer holds (taken or released).
    @Published public private(set) var lost: [CityPlace] = []
    /// The coordinate the last load was centred on.
    @Published public private(set) var center: RoamCoordinate?

    private let service: (any CityMonopolyReading)?
    private let nearby: CityNearbyRead?
    private let memberID: Int64?
    private var knownMine: Set<String>?

    public init(service: (any CityMonopolyReading)?, nearby: CityNearbyRead?, memberID: Int64? = nil) {
        self.service = service; self.nearby = nearby; self.memberID = memberID
        if service == nil && nearby == nil { phase = .unavailable }
    }

    public var isAvailable: Bool { phase != .unavailable }
    public var mine: [CityPlace] { places.filter { $0.ownership == .mine } }
    /// Today's rent (pending + available), from the server.
    public var todayRent: Int64? {
        guard let revenue else { return nil }
        return (revenue.todayPending ?? 0) + (revenue.todayAvailable ?? 0)
    }
    public var holdings: (count: Int, limit: Int)? {
        if let points, let count = points.holdings, let limit = points.holdingLimit { return (count, limit) }
        if let season, let count = season.holdingCount, let limit = season.holdingLimit { return (count, limit) }
        return phase == .loaded ? (mine.count, CityMonopolyRules.holdingBase) : nil
    }

    public func place(id: String?) -> CityPlace? {
        guard let id else { return nil }
        return places.first { $0.id == id || $0.territoryId == id }
    }

    // MARK: Reads

    public func load(center: RoamCoordinate, radiusMeters: Double = 3_000) async {
        guard service != nil || nearby != nil else { phase = .unavailable; return }
        if places.isEmpty { phase = .loading }
        self.center = center
        issueCode = nil
        var spaces: [RoamTerritoryItem] = []
        var layer: [CityTerritoryProperty] = []
        var districts: [CityDistrictInfo] = []
        var failure: String?
        if let nearby {
            do {
                let response = try await nearby(center)
                spaces = response.items; districts += response.districts
            } catch { failure = Self.code(error) }
        }
        if let service {
            do {
                let map = try await service.territoryMap(bounds: CityMapBounds(center: center, radiusMeters: radiusMeters))
                layer = map.properties; districts += map.districts
            } catch { failure = failure ?? Self.code(error) }
            if let summary = try? await service.pointsSummary() { points = summary }
            if let current = try? await service.seasonCurrent() { season = current }
            if let page = try? await service.revenue(cursor: nil, day: nil) { revenue = page }
        }
        let merged = Self.merge(spaces: spaces, layer: layer, memberID: memberID, center: center, districts: districts)
        let nowMine = Set(merged.filter { $0.ownership == .mine }.compactMap(\.territoryId))
        if let knownMine, !knownMine.subtracting(nowMine).isEmpty {
            // Only places still inside this window count: a place outside it simply was not read.
            let gone = knownMine.subtracting(nowMine)
            let left = places.filter { place in
                (place.territoryId.map(gone.contains) ?? false) && CityPresencePreflight.distanceM(center, place.coordinate) < radiusMeters * 0.9
            }
            if !left.isEmpty { lost = left; emit(.propertyLost) }
        }
        knownMine = nowMine
        places = merged
        if merged.isEmpty, let failure { phase = .failed(failure) } else { phase = .loaded }
        if let failure, !merged.isEmpty { issueCode = failure }
    }

    public func card(for place: CityPlace) async -> CityTerritoryPropertyCard? {
        guard let service, let territoryId = place.territoryId else { return nil }
        return try? await service.property(territoryId)
    }

    /// Deep link (the cityTerritory inbox card): the place for a territory id. When the current window does not hold it,
    /// the property read gives its coordinate and the board reloads around it. Nil when the server no longer knows it.
    public func locate(territoryId: String) async -> CityPlace? {
        if let known = place(id: territoryId) { return known }
        guard let service, let card = try? await service.property(territoryId),
              let lat = card.lat, let lng = card.lng, let coordinate = RoamCoordinate(latitude: lat, longitude: lng) else { return nil }
        await load(center: coordinate)
        return place(id: territoryId) ?? place(id: card.propertyId)
    }

    public func loadRevenue() async {
        guard let service else { return }
        do {
            let page = try await service.revenue(cursor: nil, day: nil)
            revenue = page
            emit(.rentCountUp(points: (page.todayPending ?? 0) + (page.todayAvailable ?? 0)))
        } catch { issueCode = Self.code(error) }
    }

    // MARK: Quote → confirm (§2.2, §2.7)

    public func quote(_ kind: CityTerritoryActionKind, place: CityPlace, fix: RoamDeviceFix?) async {
        guard let service, !busy else { return }
        busy = true; defer { busy = false }
        issueCode = nil
        let request = place.quoteRequest(kind, fix: fix)
        do {
            let quote: CityTerritoryQuote
            switch kind {
            case .claim: quote = try await service.claimQuote(request)
            case .upgrade: quote = try await service.upgradeQuote(request)
            case .challenge: quote = try await service.challengeQuote(request)
            }
            pendingQuote = CityPendingTerritoryQuote(kind: kind, propertyId: place.territoryId ?? place.id, quote: quote)
        } catch {
            issueCode = Self.code(error)
        }
    }

    public func cancelQuote() { pendingQuote = nil; issueCode = nil }
    public func acknowledgeLost() { lost = [] }
    public func clearResult() { lastResult = nil }

    /// Confirms the pending quote with presence evidence (fixes oldest first) and, for a claim, the
    /// in-app camera photo. The server re-checks everything and answers with reasons on a rejection.
    @discardableResult
    public func confirm(fixes: [RoamDeviceFix], photoAssetId: String? = nil) async -> CityTerritoryCommandResult? {
        guard let service, !busy, let pending = pendingQuote else { return nil }
        guard let base = CityPresencePreflight.evidence(fixes: fixes, photoAssetId: photoAssetId) else {
            issueCode = "LOCATION_REQUIRED"
            emit(.presenceCheckFailed)
            return nil
        }
        let evidence = CityTerritoryEvidence(photoAssetId: base.photoAssetId, capturedAt: base.capturedAt, lat: base.lat, lng: base.lng,
            hAcc: base.hAcc, samples: base.samples, inAppCamera: photoAssetId == nil ? nil : true,
            captureLat: photoAssetId == nil ? nil : base.lat, captureLng: photoAssetId == nil ? nil : base.lng)
        busy = true; defer { busy = false }
        issueCode = nil
        let command = CityTerritoryCommandRequest(propertyId: pending.propertyId, quoteId: pending.quote.quoteId,
            quoteHash: pending.quote.quoteHash, expectedVersion: pending.quote.version, evidence: evidence)
        do {
            let result: CityTerritoryCommandResult
            switch pending.kind {
            case .claim: result = try await service.claim(command)
            case .upgrade: result = try await service.upgrade(command)
            case .challenge: result = try await service.challenge(command)
            }
            lastResult = result
            if result.kind != .rejected { pendingQuote = nil }
            if let event = CityMonopolyTerritoryModel.hapticEvent(for: pending.kind, result: result) { emit(event) }
            // The command's `balance` is the charge. Apply it before the reload so a 404 on
            // GET /territory/points keeps this HUD (holdings, pending, season) with the new balance.
            noteChargedBalance(result.balance)
            if let center, result.kind != .rejected { await load(center: center) }
            return result
        } catch {
            issueCode = Self.code(error)
            emit(.presenceCheckFailed)
            return nil
        }
    }

    /// Shield (+12 h, 60 积分). Returns the new protection end on success.
    public func shield(_ place: CityPlace) async -> Date? {
        guard let service, let territoryId = place.territoryId, !busy else { return nil }
        busy = true; defer { busy = false }
        do {
            let result = try await service.shield(CityPropertyActionRequest(propertyId: territoryId))
            emit(.defenseHeld)
            noteChargedBalance(result.balance)
            if let center { await load(center: center) }
            return (result.protectedUntil ?? result.shieldUntil)?.date
        } catch {
            issueCode = Self.code(error)
            return nil
        }
    }

    /// Scout (10 积分): reveals the defence class.
    public func scout(_ place: CityPlace) async -> Int? {
        guard let service, let territoryId = place.territoryId, !busy else { return nil }
        busy = true; defer { busy = false }
        do {
            let result = try await service.scout(CityPropertyActionRequest(propertyId: territoryId))
            noteChargedBalance(result.balance)
            if let summary = try? await service.pointsSummary() { points = summary }
            return result.dc
        } catch {
            issueCode = Self.code(error)
            return nil
        }
    }

    // MARK: Merge

    public static func merge(spaces: [RoamTerritoryItem], layer: [CityTerritoryProperty], memberID: Int64?,
                             center: RoamCoordinate?, districts: [CityDistrictInfo] = []) -> [CityPlace] {
        let slots = CityDistrictSlots.slots(for: layer.map(\.districtId) + spaces.map(\.districtId))
        let book = CityDistrictBook(districts)
        /// Colour slot: the place's own `district.cN` key, else the board's `districts[]` entry, else the client slot.
        func slot(_ district: String?, board: String?, token: String?) -> Int {
            CityDistrictInfo.slot(index: nil, token: token) ?? book.info(district, board: board)?.colorSlot
                ?? district.flatMap { slots[$0] } ?? 0
        }
        func name(_ district: String?, board: String?, own: String?...) -> String? {
            for candidate in own { if let usable = CityDistrictBook.usable(candidate, districtId: district) { return usable } }
            return CityDistrictBook.usable(book.info(district, board: board)?.name, districtId: district)
        }
        var byTerritory: [String: CityTerritoryProperty] = [:]
        var byPoint: [String: CityTerritoryProperty] = [:]
        var byPoi: [Int64: CityTerritoryProperty] = [:]
        for property in layer where !property.isFogged {
            if let id = property.propertyId { byTerritory[id] = property }
            if let board = property.boardId, let point = property.pointId { byPoint[board + "|" + point] = property }
            if let poi = property.poiId { byPoi[poi] = property }
        }
        var used = Set<String>()
        var out: [CityPlace] = []
        for item in spaces {
            guard let coordinate = RoamCoordinate(latitude: item.latitude, longitude: item.longitude) else { continue }
            let held = item.territoryId.flatMap { byTerritory[$0] }
                ?? item.boardId.flatMap { board in item.pointId.flatMap { byPoint[board + "|" + $0] } }
                ?? item.poiId.flatMap { byPoi[$0] }
            if let id = held?.propertyId { used.insert(id) }
            let ownership: CityPlace.Ownership
            if let held { ownership = held.isMine ? .mine : .other }
            else if item.claimed || item.ownerMemberId != nil {
                ownership = (memberID != nil && item.ownerMemberId == memberID) ? .mine : .other
            } else { ownership = .open }
            let district = held?.districtId ?? item.districtId
            let board = item.boardId ?? held?.boardId
            out.append(CityPlace(
                id: item.territoryId ?? held?.propertyId ?? item.id,
                title: held?.title ?? item.title,
                coordinate: coordinate,
                territoryId: held?.propertyId ?? item.territoryId,
                poiId: item.poiId ?? held?.poiId, boardId: item.boardId ?? held?.boardId, pointId: item.pointId ?? held?.pointId,
                districtId: district,
                districtIndex: slot(district, board: board, token: held?.districtColorToken ?? item.districtColorToken),
                tier: held?.tier ?? item.tier, level: held?.lvl ?? item.upgradeLevel ?? 0, ownership: ownership,
                holderName: held?.holder?.maskedName ?? item.ownerNickname,
                protectedUntil: (held?.protectedUntil?.date) ?? item.protectedUntilMillis.map { Date(timeIntervalSince1970: TimeInterval($0) / 1000) },
                decay: held?.decay ?? CityDecayState(wire: item.decayState),
                photoURL: item.claimPhotoUrl, radiusM: item.radiusM,
                distanceM: center.map { CityPresencePreflight.distanceM($0, coordinate) } ?? item.distanceM,
                invested: held?.invested, districtName: name(district, board: board, own: held?.districtName, item.districtName),
                deedSerial: held?.deedSerial ?? item.deedSerial))
        }
        for property in layer {
            if let id = property.propertyId, used.contains(id) { continue }
            let coordinate: RoamCoordinate?
            if let lat = property.lat, let lng = property.lng { coordinate = RoamCoordinate(latitude: lat, longitude: lng) }
            else { coordinate = property.geohash7.flatMap(CityGeohash.center) }
            guard let coordinate else { continue }
            let ownership: CityPlace.Ownership = property.isFogged ? .fogged : (property.isMine ? .mine : .other)
            out.append(CityPlace(
                id: property.propertyId ?? ("fog-" + (property.geohash7 ?? property.id)),
                title: property.title, coordinate: coordinate, territoryId: property.propertyId,
                poiId: property.poiId, boardId: property.boardId, pointId: property.pointId,
                districtId: property.districtId,
                districtIndex: slot(property.districtId, board: property.boardId, token: property.districtColorToken),
                tier: property.tier, level: property.lvl ?? 0, ownership: ownership, holderName: property.holder?.maskedName,
                protectedUntil: property.protectedUntil?.date, decay: property.decay,
                distanceM: center.map { CityPresencePreflight.distanceM($0, coordinate) }, invested: property.invested,
                districtName: name(property.districtId, board: property.boardId, own: property.districtName),
                deedSerial: property.isFogged ? nil : property.deedSerial))
        }
        return out.sorted { ($0.distanceM ?? .infinity, $0.id) < ($1.distanceM ?? .infinity, $1.id) }
    }

    /// Writes the server's post-charge balance into the HUD and keeps every other field.
    /// A later successful `pointsSummary` replaces the whole summary; a 404 leaves this one.
    private func noteChargedBalance(_ balance: Int64?) {
        guard let balance else { return }
        if let points {
            self.points = CityPointsSummary(balance: balance, pending: points.pending, holdings: points.holdings,
                holdingLimit: points.holdingLimit, seasonId: points.seasonId, earnedSeason: points.earnedSeason,
                spentSeason: points.spentSeason)
        } else {
            self.points = CityPointsSummary(balance: balance)
        }
    }

    private func emit(_ event: CityMonopolyHapticEvent) {
        guard !event.steps.isEmpty else { return }
        haptic = CityMonopolyHapticTicket(event)
    }

    static func code(_ error: Error) -> String {
        switch error {
        case RoamTerritoryError.rejected(_, let code, _): return code
        case RoamTerritoryError.unauthorized: return "UNAUTHORIZED"
        case RoamTerritoryError.malformed: return "MALFORMED"
        case RoamTerritoryError.notCurrent: return "NOT_CURRENT"
        default: return "UNAVAILABLE"
        }
    }
}

// MARK: - Copy for server reasons (claim / challenge rejections, §2.2)

public enum CityReasonCopy {
    /// One plain sentence per server reason code, with the way forward. Unknown codes fall back to the code.
    public static func text(_ code: String, chinese: Bool) -> String {
        switch code.uppercased() {
        case "TOO_FAR", "DISTANCE", "OUT_OF_RANGE": return chinese ? "离地点太远，走到 40 m 内再试。" : "Too far away. Get within 40 m and try again."
        case "ACCURACY", "LOW_ACCURACY", "ACCURACY_TOO_LOW": return chinese ? "定位不够准，走到开阔处再试。" : "Location is not precise enough. Move to open sky."
        case "DWELL", "DWELL_TOO_SHORT", "NOT_ENOUGH_SAMPLES": return chinese ? "需要在原地停留 1 分钟。" : "Stay in place for one minute."
        case "PHOTO_REQUIRED": return chinese ? "需要用 App 相机现场拍一张照片。" : "Take a photo with the in-app camera."
        case "PHOTO_HASH_MISSING", "PHOTO_REUSED", "PHOTO_STOLEN": return chinese ? "这张照片无法通过校验，请现场重拍。" : "This photo did not pass the check. Take a new one on the spot."
        case "APP_ATTEST_REQUIRED": return chinese ? "这台设备无法完成设备校验，换一台 iPhone 再试。" : "This device cannot pass the device check. Try on an iPhone."
        case "ACCOUNT_LEVEL_TOO_LOW": return chinese ? "账号等级到 Lv3 才能圈地，先去漫游升级。" : "Reach account Lv3 to claim. Roam to level up."
        case "ACCOUNT_TOO_NEW": return chinese ? "注册满 3 天后才能圈地。" : "Accounts can claim after 3 days."
        case "PHONE_REQUIRED": return chinese ? "先绑定手机号。" : "Link a phone number first."
        case "INSUFFICIENT_POINTS": return chinese ? "积分不够。" : "Not enough points."
        case "HOLDING_LIMIT": return chinese ? "已到持有上限，放掉一块地再圈。" : "You hold the maximum. Release one first."
        case "DAILY_CLAIM_LIMIT", "CLAIMS_PER_DAY": return chinese ? "今天的圈地次数用完了，明天再来。" : "No claims left today. Come back tomorrow."
        case "ALREADY_HELD": return chinese ? "这里刚被人圈下了。" : "Someone just claimed this place."
        case "CHALLENGE_REQUIRED": return chinese ? "这里已有主人，可以发起挑战。" : "This place has a holder. You can challenge."
        case "PROTECTED": return chinese ? "保护期内，暂不能挑战。" : "Protected for now."
        case "QUIET_HOURS", "OUTSIDE_HOURS", "TIME_WINDOW": return chinese ? "06:00–23:00 之间才能圈地。" : "Claims open 06:00–23:00."
        case "SAFETY_BLOCKED": return chinese ? "这片街区因天气暂停，注意安全。" : "This district is paused for safety."
        case "SIMULATED_LOCATION", "SPOOF": return chinese ? "检测到模拟定位，无法提交。" : "Simulated location detected."
        case "FOG_LOCKED", "NOT_LIT": return chinese ? "先走过去点亮这块迷雾。" : "Walk there to clear the fog first."
        case "QUOTE_EXPIRED", "RULES_CHANGED": return chinese ? "报价已过期，请重新报价。" : "The quote expired. Get a new one."
        case "LOCATION_REQUIRED": return chinese ? "没有拿到定位，打开定位后再试。" : "No location fix. Turn on location and try again."
        case "SHIELD_COOLDOWN": return chinese ? "护盾冷却中，每块地 7 天只能开一次。" : "Shield cooling down: once per place every 7 days."
        case "MAX_LEVEL": return chinese ? "已是最高等级。" : "Already at the top level."
        case "NOT_OWNER": return chinese ? "这块地已经不是你的了。" : "You no longer hold this place."
        case "UNAUTHORIZED": return chinese ? "登录已过期，请重新登录。" : "Signed out. Sign in again."
        default: return chinese ? "暂时无法完成（\(code)）。" : "Could not complete (\(code))."
        }
    }
}
