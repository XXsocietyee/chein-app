import Foundation
import Observation

/// An independent allowlisted public projection. Never decode private topic/node models here.
public struct PublicTopicTemplateDetail: Decodable, Equatable, Identifiable {
    public let id: Int
    public let name: String?
    public let subtitle: String?
    public let description: String?
    public let imgUrl: String?
    /// Backend public catalog and detail durations are integral seconds.
    public let totalTime: Int?
    public let totalMileage: Decimal?
    public let locationCount: Int?
    public let templateCount: Int?
    public let templateStatus: String?
    public let version: String?
    public let mode: String?
    public let addressName: String?
    public let playerPromise: String?
    public let author: String?
    /// Trimmed server `finishMedalName`. Nil means the 通关勋章 block stays hidden.
    /// The topic title and `finishMedalImg` are not a name.
    public let finishMedalName: String?
    public let viewerIsMerchant: Bool
    public let viewerIsPublisher: Bool
    public let chapters: [PublicTemplateChapter]
    public let games: [PublicTemplateGame]
    /// U02-01 / §23.3 optional delivery facts. Malformed or absent -> nil; the detail itself still loads.
    public let contentDelivery: TopicTemplateContentDelivery?
    /// `Number(info.isOfficial) === 1`: JSON `1`, `"1"`, or `true`.
    public let isOfficial: Bool
    enum CodingKeys: String, CodingKey {
        case id, name, subtitle, description, imgUrl, totalTime, totalMileage, locationCount, templateCount
        case templateStatus, version, mode, addressName, playerPromise, author, finishMedalName
        case viewerIsMerchant, viewerIsPublisher, chapters, games, contentDelivery, isOfficial
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        guard id > 0 else { throw APIError.malformedResponse }
        name = try c.decodeIfPresent(String.self, forKey: .name)
        subtitle = try c.decodeIfPresent(String.self, forKey: .subtitle)
        description = try c.decodeIfPresent(String.self, forKey: .description)
        imgUrl = try c.decodeIfPresent(String.self, forKey: .imgUrl)
        totalTime = try c.decodeIfPresent(Int.self, forKey: .totalTime)
        totalMileage = try c.decodeIfPresent(Decimal.self, forKey: .totalMileage)
        locationCount = try PublicTemplateRouteCount.decode(from: c, forKey: .locationCount)
        templateCount = try c.decodeIfPresent(Int.self, forKey: .templateCount)
        templateStatus = try c.decodeIfPresent(String.self, forKey: .templateStatus)
        version = try c.decodeIfPresent(String.self, forKey: .version)
        mode = try c.decodeIfPresent(String.self, forKey: .mode)
        addressName = try c.decodeIfPresent(String.self, forKey: .addressName)
        playerPromise = try c.decodeIfPresent(String.self, forKey: .playerPromise)
        author = try c.decodeIfPresent(String.self, forKey: .author)
        finishMedalName = Self.completionMedalName(c)
        let merchantViewer = try c.decodeIfPresent(Bool.self, forKey: .viewerIsMerchant) ?? false
        let publisherViewer = try c.decodeIfPresent(Bool.self, forKey: .viewerIsPublisher) ?? false
        viewerIsMerchant = merchantViewer
        viewerIsPublisher = publisherViewer
        let canViewRecruitment = merchantViewer || publisherViewer
        let decoded = try c.decodeIfPresent([PublicTemplateChapter].self, forKey: .chapters) ?? []
        // Defense in depth: never display a recruit block without an explicit server viewer flag.
        chapters = decoded.map { $0.withRecruitment(canViewRecruitment) }
        games = try c.decodeIfPresent([PublicTemplateGame].self, forKey: .games) ?? []
        contentDelivery = (try? c.decodeIfPresent(TopicTemplateContentDelivery.self, forKey: .contentDelivery)) ?? nil
        isOfficial = Self.officialFlag(c)
        guard Set(chapters.map(\.id)).count == chapters.count,
              Set(games.map(\.id)).count == games.count,
              [totalTime, templateCount].compactMap({ $0 }).allSatisfy({ $0 >= 0 })
        else { throw APIError.malformedResponse }
    }

    private static func officialFlag(_ c: KeyedDecodingContainer<CodingKeys>) -> Bool {
        if let flag = try? c.decode(Bool.self, forKey: .isOfficial) { return flag }
        if let number = try? c.decode(Int.self, forKey: .isOfficial) { return number == 1 }
        if let text = try? c.decode(String.self, forKey: .isOfficial) {
            return text.trimmingCharacters(in: .whitespacesAndNewlines) == "1"
        }
        return false
    }

    /// Read-only name from the same public detail. Missing, null, blank, and non-strings stay absent.
    private static func completionMedalName(_ c: KeyedDecodingContainer<CodingKeys>) -> String? {
        guard let raw = try? c.decode(String.self, forKey: .finishMedalName) else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

public struct PublicTemplateChapter: Decodable, Equatable, Identifiable {
    public let id: Int
    public let name: String?
    public let description: String?
    public let nodeCount: Int?
    public let nodes: [PublicTemplateNode]
    public let routeShape: [PublicTemplateShapePoint]
    public private(set) var recruitStatus: PublicTemplateRecruitment?
    enum CodingKeys: String, CodingKey { case id, name, description, nodeCount, nodes, routeShape, recruitStatus }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        name = try c.decodeIfPresent(String.self, forKey: .name)
        description = try c.decodeIfPresent(String.self, forKey: .description)
        nodeCount = try c.decodeIfPresent(Int.self, forKey: .nodeCount)
        nodes = try c.decodeIfPresent([PublicTemplateNode].self, forKey: .nodes) ?? []
        routeShape = try c.decodeIfPresent([PublicTemplateShapePoint].self, forKey: .routeShape) ?? []
        recruitStatus = try c.decodeIfPresent(PublicTemplateRecruitment.self, forKey: .recruitStatus)
        guard id > 0, nodeCount.map({ $0 >= 0 }) ?? true else { throw APIError.malformedResponse }
    }
    fileprivate func withRecruitment(_ allowed: Bool) -> Self {
        var copy = self
        if !allowed { copy.recruitStatus = nil }
        return copy
    }
}

/// No ID is published for nodes. Position is a presentation key, never a private-node identity.
public struct PublicTemplateNode: Decodable, Equatable {
    public let name: String?
    public let addressName: String?
    public let imgUrl: String?
    public let interactionType: String?
    public let hookTeaser: String?
    /// Mini-program stop pill: `gameTitle`, else `game`. Blank stays nil.
    public let game: String?
    /// Optional server icon. The mini-program draws its own art when this is absent.
    public let gameIcon: String?
    /// Minutes from `gameDuration`, else `duration`. Missing or unusable stays nil.
    public let duration: Int?
    enum CodingKeys: String, CodingKey {
        case name, addressName, imgUrl, interactionType, hookTeaser
        case game, gameTitle, gameIcon, duration, gameDuration
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decodeIfPresent(String.self, forKey: .name)
        addressName = try c.decodeIfPresent(String.self, forKey: .addressName)
        imgUrl = try c.decodeIfPresent(String.self, forKey: .imgUrl)
        interactionType = try c.decodeIfPresent(String.self, forKey: .interactionType)
        hookTeaser = try c.decodeIfPresent(String.self, forKey: .hookTeaser)
        game = Self.plain(c, .gameTitle) ?? Self.plain(c, .game)
        gameIcon = Self.plain(c, .gameIcon)
        duration = Self.minutes(c, .gameDuration) ?? Self.minutes(c, .duration)
    }
    private static func plain(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> String? {
        guard let raw = try? c.decode(String.self, forKey: key) else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
    /// Whole positive minutes only. A bad type does not fail the node.
    private static func minutes(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> Int? {
        if let value = try? c.decode(Int.self, forKey: key), value > 0 { return value }
        if let raw = try? c.decode(String.self, forKey: key),
           let value = Int(raw.trimmingCharacters(in: .whitespacesAndNewlines)), value > 0 { return value }
        if let value = try? c.decode(Double.self, forKey: key), value.isFinite, value > 0, value == value.rounded(.towardZero),
           value <= Double(Int.max) { return Int(value) }
        return nil
    }
}
public struct PublicTemplateGame: Decodable, Equatable, Identifiable {
    public let id: Int
    public let title: String?
    public let imgUrl: String?
    public let players: String?
    public let duration: Int?
    public let difficulty: String?
    public let interactionType: String?
    enum CodingKeys: String, CodingKey { case id, title, imgUrl, players, duration, difficulty, interactionType }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        guard id > 0 else { throw APIError.malformedResponse }
        title = try c.decodeIfPresent(String.self, forKey: .title)
        imgUrl = try c.decodeIfPresent(String.self, forKey: .imgUrl)
        players = try c.decodeIfPresent(String.self, forKey: .players)
        duration = try c.decodeIfPresent(Int.self, forKey: .duration)
        difficulty = try c.decodeIfPresent(String.self, forKey: .difficulty)
        interactionType = try c.decodeIfPresent(String.self, forKey: .interactionType)
    }
}
/// Relative silhouette only. Reject coordinates outside the server's normalized projection.
public struct PublicTemplateShapePoint: Decodable, Equatable {
    public let x: Double
    public let y: Double
    enum CodingKeys: String, CodingKey { case x, y }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        x = try c.decode(Double.self, forKey: .x); y = try c.decode(Double.self, forKey: .y)
        guard x.isFinite, y.isFinite, (0...1).contains(x), (0...1).contains(y) else { throw APIError.malformedResponse }
    }
}
/// Aggregate status only; no applicant identity, terms mutation, or application action.
public struct PublicTemplateRecruitment: Decodable, Equatable {
    public let state: String?
    public let isOpen: Bool?
    public let maxMerchant: Int?
    public let currentOfferCount: Int?
    public let pendingApplicationCount: Int?
    public let approvedApplicationCount: Int?
    public let activeOfferCount: Int?
    public let remainingMerchantCount: Int?
}

/// Memory-only request owner. Session owner invalidates synchronously for account, role,
/// credential or realm changes; an old completion (including an old failure) cannot repopulate it.
@MainActor @Observable
public final class PublicTopicTemplateCoordinator {
    public let id: Int
    public private(set) var value: PublicTopicTemplateDetail?
    public private(set) var error: Error?
    public private(set) var isLoading = false
    public private(set) var isInvalidated = false
    @ObservationIgnored private var generation: UInt64 = 0
    @ObservationIgnored private let read: @MainActor (Int) async throws -> PublicTopicTemplateDetail
    @ObservationIgnored private let onUnauthorized: @MainActor () -> Void
    public init(id: Int, onUnauthorized: @escaping @MainActor () -> Void = {},
                read: @escaping @MainActor (Int) async throws -> PublicTopicTemplateDetail) {
        self.id = id; self.read = read; self.onUnauthorized = onUnauthorized
    }
    public func clear() {
        generation &+= 1; value = nil; error = nil; isLoading = false
    }
    public func invalidate() {
        generation &+= 1; isInvalidated = true; value = nil; error = nil; isLoading = false
    }
    public func load() async {
        guard !isInvalidated else { return }
        generation &+= 1
        let captured = generation
        value = nil; error = nil; isLoading = true
        defer { if generation == captured { isLoading = false } }
        do {
            guard id > 0 else { throw APIError.invalidRequest }
            let result = try await read(id)
            guard generation == captured, !isInvalidated, !Task.isCancelled else { return }
            guard result.id == id else { throw APIError.malformedResponse }
            value = result
        } catch {
            guard generation == captured, !isInvalidated, !Task.isCancelled else { return }
            if !(error is CancellationError) {
                self.error = error
                // Session expiration is a side effect, so fence it with the same
                // generation as the visible result. Stale/dismissed reads cannot log out.
                if error as? APIError == .unauthorized { onUnauthorized() }
            }
        }
    }
}

public struct PublicTemplateViewerContext: Equatable {
    public let accountID: Int?
    public let role: String?
    public let realm: String
    public let revision: UInt64
    public init(accountID: Int?, role: String?, realm: String, revision: UInt64) {
        self.accountID = accountID; self.role = role; self.realm = realm; self.revision = revision
    }
}

/// Scope is independent of template ID. No disk cache or cross-account reuse.
/// Idle coordinators past `maximumCoordinators` are dropped, oldest first. A coordinator that is
/// still loading stays, so an on-screen load is not restarted to make room.
@MainActor public final class PublicTemplateDetailOwner {
    public static let maximumCoordinators = 32
    public private(set) var epoch = UUID()
    private var context: PublicTemplateViewerContext?
    private var entries: [Int: PublicTopicTemplateCoordinator] = [:]
    /// Oldest first. A repeat visit moves that id to the end.
    private var recent: [Int] = []
    public init() {}
    public func synchronize(_ next: PublicTemplateViewerContext) {
        guard context != next else { return }
        invalidate(); context = next
    }
    public func invalidate() {
        epoch = UUID(); entries.values.forEach { $0.invalidate() }; entries.removeAll(); recent.removeAll(); context = nil
    }
    public func coordinator(id: Int, onUnauthorized: @escaping @MainActor () -> Void = {},
                            read: @escaping @MainActor (Int) async throws -> PublicTopicTemplateDetail) -> PublicTopicTemplateCoordinator {
        if let existing = entries[id] {
            note(id)
            evictIdle(protecting: id)
            return existing
        }
        let next = PublicTopicTemplateCoordinator(id: id, onUnauthorized: onUnauthorized, read: read)
        entries[id] = next
        note(id)
        evictIdle(protecting: id)
        return next
    }
    private func note(_ id: Int) {
        recent.removeAll { $0 == id }
        recent.append(id)
    }
    /// Drops the oldest idle coordinator until the map fits. Loading owners and `protected` stay.
    private func evictIdle(protecting protected: Int) {
        var deferred: [Int] = []
        while entries.count > Self.maximumCoordinators, let oldest = recent.first {
            if oldest == protected { break }
            recent.removeFirst()
            guard let coordinator = entries[oldest] else { continue }
            if coordinator.isLoading {
                deferred.append(oldest)
                continue
            }
            entries[oldest] = nil
            coordinator.invalidate()
        }
        if !deferred.isEmpty { recent.insert(contentsOf: deferred, at: 0) }
    }
}
