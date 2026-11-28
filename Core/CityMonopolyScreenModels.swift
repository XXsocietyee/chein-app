import Foundation
import Combine

// MARK: - Haptic moments (spec §5)

/// Primitive cues the app's haptics map (`CYHaptics`) can play.
public enum CityMonopolyHapticCue: String, Equatable, Sendable {
    case selection, success, warning, error, impactLight, impactMedium, impactHeavy, impactRigid
}

/// One cue and its delay after the previous cue. Every delay after the first is at least
/// 120 ms, the haptics map's cooldown (and `MotionAndHapticInteractionCheck` floor).
public struct CityMonopolyHapticStep: Equatable, Sendable {
    public let cue: CityMonopolyHapticCue
    public let delayMs: Int

    public init(_ cue: CityMonopolyHapticCue, after delayMs: Int = 0) {
        self.cue = cue; self.delayMs = delayMs
    }
}

/// Spec §5 feedback moments. Core Haptics patterns (the claim rumble) and the 80 ms d20 tumble are
/// approximated with the existing generator cues at ≥120 ms spacing. Decay reminders have no haptic.
public enum CityMonopolyHapticEvent: Equatable, Sendable {
    case claimSucceeded
    /// One selection per passed check (distance, accuracy, dwell, photo), then a warning if any failed.
    case presenceChecks(passed: Int, failed: Bool)
    case presenceCheckFailed
    case rentCountUp(points: Int64)
    case takeoverWon
    case takeoverLost
    case propertyLost
    case defenseHeld
    case upgraded
    case districtControl
    case attributeLevelUp
    case titleUnlocked

    public static let minimumIntervalMs = 120

    public var steps: [CityMonopolyHapticStep] {
        switch self {
        case .claimSucceeded:
            // ① flag drop (transient) ② rumble omitted ③ success at 0.45 s.
            return [.init(.impactHeavy), .init(.success, after: 450)]
        case .presenceChecks(let passed, let failed):
            let ticks = (0..<min(max(passed, 0), 4)).map { CityMonopolyHapticStep(.selection, after: $0 == 0 ? 0 : 150) }
            return failed ? ticks + [.init(.warning, after: ticks.isEmpty ? 0 : 150)] : ticks
        case .presenceCheckFailed:
            return [.init(.warning)]
        case .rentCountUp(let points):
            let ticks = Int(min(12, max(0, points / 10)))
            guard ticks > 0 else { return [] }
            return (0..<ticks).map { CityMonopolyHapticStep(.selection, after: $0 == 0 ? 0 : 120) } + [.init(.impactLight, after: 120)]
        case .takeoverWon:
            return Self.tumble + [.init(.impactHeavy, after: 240), .init(.success, after: 200)]
        case .takeoverLost:
            return Self.tumble + [.init(.impactHeavy, after: 240), .init(.error, after: 200)]
        case .propertyLost:
            return [.init(.warning)]
        case .defenseHeld:
            return [.init(.impactRigid), .init(.impactRigid, after: 120), .init(.success, after: 150)]
        case .upgraded, .attributeLevelUp:
            return [.init(.impactMedium), .init(.success, after: 150)]
        case .districtControl:
            return [.init(.success), .init(.impactHeavy, after: 300)]
        case .titleUnlocked:
            return [.init(.impactHeavy), .init(.success, after: 150)]
        }
    }

    /// Decelerating d20 tumble ticks.
    private static let tumble: [CityMonopolyHapticStep] = [
        .init(.impactLight), .init(.impactLight, after: 120), .init(.impactLight, after: 140), .init(.impactLight, after: 170)
    ]
}

/// A fresh value per emitted event so SwiftUI `onChange` fires for repeats.
public struct CityMonopolyHapticTicket: Equatable, Sendable {
    public let id: UUID
    public let event: CityMonopolyHapticEvent

    public init(_ event: CityMonopolyHapticEvent, id: UUID = UUID()) {
        self.event = event; self.id = id
    }
}

// MARK: - Display formatting

public enum CityMonopolyFormat {
    /// "120 积分" / "120 pts". The only currency on City screens is points.
    public static func points(_ value: Int64, chinese: Bool) -> String {
        chinese ? "\(value) 积分" : "\(value) pts"
    }

    /// Coarse countdown: days+hours, hours+minutes, or minutes.
    public static func countdown(seconds: Int64, chinese: Bool) -> String {
        let total = max(0, seconds)
        let days = total / 86_400, hours = (total % 86_400) / 3_600, minutes = (total % 3_600) / 60
        if days > 0 { return chinese ? "\(days)天\(hours)小时" : "\(days)d \(hours)h" }
        if hours > 0 { return chinese ? "\(hours)小时\(minutes)分" : "\(hours)h \(minutes)m" }
        return chinese ? "\(minutes)分" : "\(minutes)m"
    }

    /// "×1.40"
    public static func multiplier(_ value: Double) -> String {
        "×" + String(format: "%.2f", value)
    }
}

// MARK: - Presence preflight (spec §2.2, shown before the server decides)

public struct CityPresenceCheck: Equatable, Identifiable, Sendable {
    public enum Kind: String, Equatable, Sendable { case distance, accuracy, dwell, photo }
    public let kind: Kind
    public let passed: Bool
    public let detailZh: String
    public let detailEn: String

    public var id: String { kind.rawValue }
    public func detail(chinese: Bool) -> String { chinese ? detailZh : detailEn }
}

public enum CityPresencePreflight {
    public static let claimRadiusM = 40.0
    public static let maxAccuracyM = 25.0
    public static let dwellMinSamples = 3
    public static let dwellMinSpanS = 60.0
    public static let dwellMaxSpreadM = 80.0

    /// Distance in metres between two GCJ-02/WGS-84 points (haversine).
    public static func distanceM(_ a: RoamCoordinate, _ b: RoamCoordinate) -> Double {
        let r = 6_371_000.0
        let dLat = (b.latitude - a.latitude) * .pi / 180
        let dLng = (b.longitude - a.longitude) * .pi / 180
        let h = sin(dLat / 2) * sin(dLat / 2)
            + cos(a.latitude * .pi / 180) * cos(b.latitude * .pi / 180) * sin(dLng / 2) * sin(dLng / 2)
        return 2 * r * asin(min(1, sqrt(h)))
    }

    /// Distance, accuracy and dwell checks for `fixes` (oldest first) against `anchor`; the photo
    /// check is added when `requirePhoto`. Hints only: the server re-checks everything.
    public static func evaluate(fixes: [RoamDeviceFix], anchor: RoamCoordinate?, requirePhoto: Bool, hasPhoto: Bool) -> [CityPresenceCheck] {
        var checks: [CityPresenceCheck] = []
        let latest = fixes.last
        if let anchor, let latest {
            let distance = distanceM(latest.coordinate, anchor)
            let shown = Int(distance.rounded())
            checks.append(.init(kind: .distance, passed: distance <= claimRadiusM,
                detailZh: distance <= claimRadiusM ? "距离 \(shown) m" : "距离 \(shown) m，需要 ≤ \(Int(claimRadiusM)) m，再走近一些",
                detailEn: distance <= claimRadiusM ? "Distance \(shown) m" : "Distance \(shown) m, needs ≤ \(Int(claimRadiusM)) m; move closer"))
        }
        if let latest {
            let accuracy = Int(latest.accuracyMeters.rounded())
            let ok = latest.accuracyMeters <= maxAccuracyM
            checks.append(.init(kind: .accuracy, passed: ok,
                detailZh: ok ? "定位精度 \(accuracy) m" : "定位精度 \(accuracy) m，需要 ≤ \(Int(maxAccuracyM)) m，走到开阔处",
                detailEn: ok ? "Accuracy \(accuracy) m" : "Accuracy \(accuracy) m, needs ≤ \(Int(maxAccuracyM)) m; move to open sky"))
        }
        let span = fixes.count >= 2 ? fixes.last!.measuredAt.timeIntervalSince(fixes.first!.measuredAt) : 0
        let spread = anchor.map { anchor in fixes.map { distanceM($0.coordinate, anchor) }.max() ?? 0 } ?? 0
        let dwellOK = fixes.count >= dwellMinSamples && span >= dwellMinSpanS && spread <= dwellMaxSpreadM
        checks.append(.init(kind: .dwell, passed: dwellOK,
            detailZh: dwellOK ? "驻留 \(Int(span)) s，\(fixes.count) 个样本"
                : "驻留 \(Int(span)) s / \(fixes.count) 个样本，需要 ≥ \(Int(dwellMinSpanS)) s、≥ \(dwellMinSamples) 个样本且都在 \(Int(dwellMaxSpreadM)) m 内",
            detailEn: dwellOK ? "Dwell \(Int(span)) s, \(fixes.count) samples"
                : "Dwell \(Int(span)) s / \(fixes.count) samples, needs ≥ \(Int(dwellMinSpanS)) s, ≥ \(dwellMinSamples) samples within \(Int(dwellMaxSpreadM)) m"))
        if requirePhoto {
            checks.append(.init(kind: .photo, passed: hasPhoto,
                detailZh: hasPhoto ? "照片已拍摄" : "需要用 App 相机现场拍照",
                detailEn: hasPhoto ? "Photo ready" : "Take a photo with the in-app camera"))
        }
        return checks
    }

    /// Server evidence from the collected fixes (oldest first). Returns nil without a fix.
    public static func evidence(fixes: [RoamDeviceFix], photoAssetId: String? = nil) -> CityTerritoryEvidence? {
        guard let latest = fixes.last else { return nil }
        let samples = fixes.map { fix in
            CityTerritoryLocationSample(t: Int64((fix.measuredAt.timeIntervalSince1970 * 1000).rounded()),
                lat: fix.coordinate.latitude, lng: fix.coordinate.longitude, hAcc: fix.accuracyMeters)
        }
        return CityTerritoryEvidence(photoAssetId: photoAssetId,
            capturedAt: Int64((latest.measuredAt.timeIntervalSince1970 * 1000).rounded()),
            lat: latest.coordinate.latitude, lng: latest.coordinate.longitude, hAcc: latest.accuracyMeters,
            samples: samples)
    }
}

// MARK: - Territory screen model

public enum CityTerritoryActionKind: String, Equatable, Sendable {
    case claim, upgrade, challenge
}

public struct CityPendingTerritoryQuote: Equatable, Sendable {
    public let kind: CityTerritoryActionKind
    public let propertyId: String
    public let quote: CityTerritoryQuote
}

/// Drives the City Monopoly numbers on the merged territory screen: points balance, season HUD,
/// territory layer (tier / level / protection / decay), deed card, revenue, quotes and commands.
@MainActor public final class CityMonopolyTerritoryModel: ObservableObject {
    /// The member's points (积分): the one currency every price and rent is paid in.
    @Published public private(set) var pointsBalance: Int64?
    @Published public private(set) var season: CitySeasonCurrent?
    @Published public private(set) var map: CityTerritoryMapResponse?
    @Published public private(set) var revenue: CityRevenuePage?
    @Published public private(set) var seasonBoard: CitySeasonLeaderboard?
    @Published public private(set) var card: CityTerritoryPropertyCard?
    @Published public private(set) var scoutedDC: [String: Int] = [:]
    @Published public private(set) var pendingQuote: CityPendingTerritoryQuote?
    @Published public private(set) var lastResult: CityTerritoryCommandResult?
    @Published public private(set) var issueCode: String?
    @Published public private(set) var busy = false
    @Published public private(set) var haptic: CityMonopolyHapticTicket?

    private let service: any CityMonopolyReading
    private let pointsSource: (@MainActor () async -> Int64?)?
    private var knownMine: Set<String>?
    private var knownControl: [String: CityDistrictControl] = [:]

    /// `pointsSource` reads the member's points balance (the growth center in the app).
    public init(service: any CityMonopolyReading, pointsSource: (@MainActor () async -> Int64?)? = nil) {
        self.service = service
        self.pointsSource = pointsSource
    }

    /// Properties held by the viewer on the current layer.
    public var mine: [CityTerritoryProperty] { map?.properties.filter(\.isMine) ?? [] }

    /// HUD holding count / limit: the season's numbers first, the layer and rule table otherwise.
    public func holdings(exploreLevel: Int? = nil) -> (count: Int, limit: Int) {
        let count = season?.holdingCount ?? mine.count
        let limit = season?.holdingLimit ?? CityMonopolyRules.holdingLimit(exploreLevel: exploreLevel ?? 0)
        return (count, limit)
    }

    /// Server property for a merged-territory item, matched by property id.
    public func property(id: String?) -> CityTerritoryProperty? {
        guard let id else { return nil }
        return map?.properties.first { $0.propertyId == id }
    }

    /// District control per district from the layer (fogged tiles still count toward the total).
    public static func districtControl(_ properties: [CityTerritoryProperty]) -> [String: CityDistrictControl] {
        var totals: [String: (mine: Int, all: Int)] = [:]
        for property in properties {
            guard let district = property.districtId else { continue }
            var entry = totals[district] ?? (mine: 0, all: 0)
            entry.all += 1
            if property.isMine { entry.mine += 1 }
            totals[district] = entry
        }
        return totals.mapValues { CityDistrictControl(ownedShare: $0.all == 0 ? 0 : Double($0.mine) / Double($0.all)) }
    }

    public func reload() async {
        await reload(commandBalance: nil)
    }

    /// `commandBalance` is the balance a claim, upgrade, challenge, scout or shield just returned.
    /// GET /territory/points wins when it answers. On 404 the command balance is kept, and the
    /// wallet source is not allowed to paint the pre-charge number back over it.
    private func reload(commandBalance: Int64?) async {
        issueCode = nil
        if let summary = try? await service.pointsSummary(), let balance = summary.balance {
            pointsBalance = balance
        } else if let commandBalance {
            pointsBalance = commandBalance
        } else if let pointsSource {
            let balance = await pointsSource()
            if let balance { pointsBalance = balance }
        }
        do { season = try await service.seasonCurrent() } catch { record(error) }
        // Today's pending / available rent for the HUD; the count-up haptic plays only on an explicit open.
        let page = try? await service.revenue(cursor: nil, day: nil)
        if let page { revenue = page }
        do {
            let layer = try await service.territoryMap(bbox: nil, zoom: nil)
            absorb(layer)
        } catch { record(error) }
    }

    public func loadRevenue() async {
        do {
            let page = try await service.revenue(cursor: nil, day: nil)
            revenue = page
            emit(.rentCountUp(points: (page.todayPending ?? 0) + (page.todayAvailable ?? 0)))
        } catch { record(error) }
    }

    public func loadSeasonBoard(scope: CitySeasonScope = .solo) async {
        do { seasonBoard = try await service.seasonLeaderboard(scope: scope, seasonId: season?.seasonId) } catch { record(error) }
    }

    public func openCard(propertyId: String) async {
        do {
            let loaded = try await service.property(propertyId)
            card = loaded
            if loaded.holder?.isMe == true, let estimate = loaded.estimatedYield { emit(.rentCountUp(points: estimate)) }
        } catch { record(error) }
    }

    public func closeCard() { card = nil }

    public func requestQuote(_ kind: CityTerritoryActionKind, propertyId: String, fix: RoamDeviceFix?) async {
        guard !busy else { return }
        busy = true; defer { busy = false }
        issueCode = nil
        let request = CityTerritoryQuoteRequest(propertyId: propertyId, lat: fix?.coordinate.latitude,
            lng: fix?.coordinate.longitude, hAcc: fix?.accuracyMeters)
        do {
            let quote: CityTerritoryQuote
            switch kind {
            case .claim: quote = try await service.claimQuote(request)
            case .upgrade: quote = try await service.upgradeQuote(request)
            case .challenge: quote = try await service.challengeQuote(request)
            }
            pendingQuote = CityPendingTerritoryQuote(kind: kind, propertyId: propertyId, quote: quote)
            if let dc = quote.dc { scoutedDC[propertyId] = dc }
        } catch {
            record(error)
        }
    }

    public func cancelQuote() { pendingQuote = nil }

    /// Confirms the pending quote with presence evidence from `fixes` (oldest first).
    @discardableResult
    public func confirm(fixes: [RoamDeviceFix], photoAssetId: String? = nil) async -> CityTerritoryCommandResult? {
        guard !busy, let pending = pendingQuote else { return nil }
        guard let evidence = CityPresencePreflight.evidence(fixes: fixes, photoAssetId: photoAssetId) else {
            issueCode = "LOCATION_REQUIRED"
            emit(.presenceCheckFailed)
            return nil
        }
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
            pendingQuote = nil
            if let event = Self.hapticEvent(for: pending.kind, result: result) { emit(event) }
            await reload(commandBalance: result.balance)
            return result
        } catch {
            record(error)
            emit(.presenceCheckFailed)
            return nil
        }
    }

    public func scout(propertyId: String) async {
        guard !busy else { return }
        busy = true; defer { busy = false }
        do {
            let result = try await service.scout(CityPropertyActionRequest(propertyId: propertyId, expectedVersion: card?.version))
            scoutedDC[propertyId] = result.dc
            if let balance = result.balance { pointsBalance = balance }
            if let summary = try? await service.pointsSummary(), let balance = summary.balance { pointsBalance = balance }
        } catch { record(error) }
    }

    public func shield(propertyId: String) async {
        guard !busy else { return }
        busy = true; defer { busy = false }
        do {
            let result = try await service.shield(CityPropertyActionRequest(propertyId: propertyId, expectedVersion: card?.version))
            emit(.defenseHeld)
            await reload(commandBalance: result.balance)
        } catch { record(error) }
    }

    public static func hapticEvent(for kind: CityTerritoryActionKind, result: CityTerritoryCommandResult) -> CityMonopolyHapticEvent? {
        switch (kind, result.kind) {
        case (.claim, .applied): return .claimSucceeded
        case (.upgrade, .applied): return .upgraded
        case (.challenge, .challengerWon), (.challenge, .applied): return .takeoverWon
        case (.challenge, .challengerLost): return .takeoverLost
        case (_, .rejected): return .presenceCheckFailed
        default: return nil
        }
    }

    private func absorb(_ layer: CityTerritoryMapResponse) {
        let nowMine = Set(layer.properties.filter(\.isMine).compactMap(\.propertyId))
        let control = Self.districtControl(layer.properties)
        if let knownMine, !knownMine.subtracting(nowMine).isEmpty {
            emit(.propertyLost)
        } else if knownMine != nil, control.contains(where: { district, value in
            value != .none && (knownControl[district].map { Self.rank($0) < Self.rank(value) } ?? true)
        }) {
            emit(.districtControl)
        }
        knownMine = nowMine
        knownControl = control
        map = layer
    }

    private static func rank(_ control: CityDistrictControl) -> Int {
        switch control {
        case .none: return 0
        case .majority: return 1
        case .monopoly: return 2
        }
    }

    private func emit(_ event: CityMonopolyHapticEvent) {
        guard !event.steps.isEmpty else { return }
        haptic = CityMonopolyHapticTicket(event)
    }

    private func record(_ error: Error) {
        guard issueCode == nil else { return }
        switch error {
        case RoamTerritoryError.rejected(_, let code, _): issueCode = code
        case RoamTerritoryError.unauthorized: issueCode = "UNAUTHORIZED"
        case RoamTerritoryError.malformed: issueCode = "MALFORMED"
        case RoamTerritoryError.notCurrent: issueCode = "NOT_CURRENT"
        default: issueCode = "UNAVAILABLE"
        }
    }
}

// MARK: - Attributes v2 model (profile)

/// Six attributes, archetype and titles for the viewer's own profile.
@MainActor public final class MemberAttributesModel: ObservableObject {
    @Published public private(set) var attributes: MemberAttributesResponse?
    @Published public private(set) var loading = false
    @Published public private(set) var issueCode: String?
    @Published public private(set) var haptic: CityMonopolyHapticTicket?

    private let service: any CityMonopolyReading

    public init(service: any CityMonopolyReading) {
        self.service = service
    }

    /// Owned titles; when the server sends no list, the equipped title alone.
    public var titles: [MemberTitle] { attributes?.titles ?? [] }

    public func load() async {
        guard !loading else { return }
        loading = true; defer { loading = false }
        do {
            let loaded = try await service.memberAttributes()
            if let previous = attributes, let event = Self.hapticEvent(previous: previous, current: loaded) { haptic = CityMonopolyHapticTicket(event) }
            attributes = loaded
            issueCode = nil
        } catch RoamTerritoryError.rejected(_, let code, _) {
            issueCode = code
        } catch {
            issueCode = "UNAVAILABLE"
        }
    }

    public func equip(titleCode: String?) async {
        guard !loading else { return }
        do {
            _ = try await service.equipTitle(MemberTitleEquipRequest(titleCode: titleCode))
            await load()
        } catch RoamTerritoryError.rejected(_, let code, _) {
            issueCode = code
        } catch {
            issueCode = "UNAVAILABLE"
        }
    }

    /// A new title beats a level-up; nothing on the first load.
    public static func hapticEvent(previous: MemberAttributesResponse, current: MemberAttributesResponse) -> CityMonopolyHapticEvent? {
        let before = Set((previous.titles ?? []).map(\.code))
        if (current.titles ?? []).contains(where: { !before.contains($0.code) }) { return .titleUnlocked }
        let levels = Dictionary(previous.attrs.map { ($0.key, $0.level) }, uniquingKeysWith: { lhs, _ in lhs })
        if current.attrs.contains(where: { row in levels[row.key].map { row.level > $0 } ?? false }) { return .attributeLevelUp }
        return nil
    }
}
