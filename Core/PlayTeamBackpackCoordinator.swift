import Foundation

public struct PlayTeamBackpackItem: Equatable, Identifiable {
    public let id: String
    public let name: String?
    public let quantity: Int?
    public let usable: Bool
    public let discardable: Bool
}

public struct PlayTeamPendingItem: Equatable, Identifiable {
    public let id: String
    public let name: String?
    public let quantity: Int?
}

public struct PlayTeamBackpackCommandSnapshot: Equatable {
    public let revision: Int
    public let authorityEpoch: Int?
    public let actions: Set<String>
    public let allowDiscard: Bool
    public let items: [PlayTeamBackpackItem]
    public let pending: [PlayTeamPendingItem]

    public init(raw: PlayWireValue, activityID: Int) throws {
        guard raw["scope"].text == "TEAM", raw["activityId"].tolerantInteger == activityID else { throw PlayExperienceError.malformed }
        guard let revision = raw["revision"].integer, revision >= 0 else { throw PlayExperienceError.malformed }
        let storedEpoch = raw.object?["authorityEpoch"] ?? .null
        if storedEpoch != .null, storedEpoch.integer == nil || (storedEpoch.integer ?? 0) < 1 {
            throw PlayExperienceError.malformed
        }
        let epoch = storedEpoch.integer
        let actions = Set((raw["availableActions"].array ?? []).compactMap(\.text))
        let allowDiscard = raw["allowDiscard"].bool == true
        var items: [PlayTeamBackpackItem] = []
        for row in raw["contents"].array ?? [] {
            guard row["kind"].text == "ITEM", let id = row["id"].text, !id.isEmpty else { continue }
            let worn = row["worn"].bool == true
            let used = row["used"].bool == true
            let usable = row["stat"].text != nil && !worn && !used
            items.append(PlayTeamBackpackItem(id: id, name: Self.label(row["name"].text), quantity: row["quantity"].integer,
                                               usable: usable, discardable: allowDiscard && !worn))
        }
        var pending: [PlayTeamPendingItem] = []
        for (key, row) in raw["pending"].object ?? [:] {
            let id = row["itemId"].text ?? key
            guard !id.isEmpty else { continue }
            pending.append(PlayTeamPendingItem(id: id, name: Self.label(row["name"].text), quantity: row["quantity"].integer))
        }
        pending.sort { $0.id < $1.id }
        self.revision = revision
        self.authorityEpoch = epoch
        self.actions = actions
        self.allowDiscard = allowDiscard
        self.items = items
        self.pending = pending
    }

    private static func label(_ text: String?) -> String? {
        let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}

public protocol PlayTeamBackpackReading {
    @MainActor func projection(activityID: Int) async throws -> PlayTeamBackpackCommandSnapshot
}

public struct PlayTeamBackpackHTTP: PlayTeamBackpackReading {
    let service: PlayExperienceService
    let token: @MainActor () -> String?
    public init(service: PlayExperienceService, token: @escaping @MainActor () -> String?) {
        self.service = service
        self.token = token
    }
    public func projection(activityID: Int) async throws -> PlayTeamBackpackCommandSnapshot {
        guard activityID > 0, let token = token(), AuthRequestBuilder.isValidToken(token) else { throw APIError.unauthorized }
        let raw = try await service.request("api/game/session/view", query: ["activityId": String(activityID), "perspective": "PLAYER"],
                                            capability: .reads, token: token)
        return try PlayTeamBackpackCommandSnapshot(raw: raw, activityID: activityID)
    }
}

public enum PlayTeamCommandDisplayKind: Equatable {
    case blank, applied, failed, business, unknown, refused
}

public struct PlayTeamCommandDisplay: Equatable {
    public var kind: PlayTeamCommandDisplayKind
    public var outcome: String
    public var receiptID: String
    public var revision: String
    public var serverMessage: String?
    public var succeeded: Bool
    public static let blank = PlayTeamCommandDisplay(kind: .blank, outcome: PlayTeamCommandInterpretation.dash,
                                                      receiptID: PlayTeamCommandInterpretation.dash, revision: PlayTeamCommandInterpretation.dash,
                                                      serverMessage: nil, succeeded: false)
}

@available(macOS 14.0, *)
@MainActor @Observable public final class PlayTeamBackpackCoordinator {
    public private(set) var phase: Phase = .loading
    public private(set) var items: [PlayTeamBackpackItem] = []
    public private(set) var pending: [PlayTeamPendingItem] = []
    public private(set) var canUse = false
    public private(set) var canDiscard = false
    public private(set) var canReceive = false
    public private(set) var receipt = PlayTeamCommandDisplay.blank
    public private(set) var busy = false
    public enum Phase: Equatable { case loading, empty, failed, ready }
    private let activityID: Int
    private let reader: any PlayTeamBackpackReading
    private let client: PlayTeamItemCommandClient?
    private let token: @MainActor () -> String?
    private var revision = 0
    private var authorityEpoch: Int?
    private var generation: UInt64 = 0
    /// Unknown command results keep the request id that was sent. A later tap of the same action replays that id.
    private var openRequestIDs: [String: String] = [:]

    public init(activityID: Int, reader: any PlayTeamBackpackReading, client: PlayTeamItemCommandClient?, token: @escaping @MainActor () -> String?) {
        self.activityID = activityID
        self.reader = reader
        self.client = client
        self.token = token
    }

    public func reload() async {
        generation &+= 1
        let stamp = generation
        phase = .loading
        do {
            let snapshot = try await reader.projection(activityID: activityID)
            guard stamp == generation else { return }
            apply(snapshot)
        } catch {
            guard stamp == generation else { return }
            phase = .failed
            if items.isEmpty, pending.isEmpty {
                canUse = false
                canDiscard = false
                canReceive = false
            }
        }
    }

    public func present(_ answer: PlayTeamCommandAnswer) { receipt = Self.display(answer) }

    public func use(_ contentID: String) async { await send("ITEM_USE", contentID: contentID) }
    public func discard(_ contentID: String) async { await send("ITEM_DISCARD", contentID: contentID) }
    public func receive(_ contentID: String) async { await send("ITEM_RECEIVE", contentID: contentID) }

    private func apply(_ snapshot: PlayTeamBackpackCommandSnapshot) {
        revision = snapshot.revision
        authorityEpoch = snapshot.authorityEpoch
        items = snapshot.items
        pending = snapshot.pending
        canUse = snapshot.actions.contains("ITEM_USE")
        canDiscard = snapshot.actions.contains("ITEM_DISCARD") && snapshot.allowDiscard
        canReceive = snapshot.actions.contains("ITEM_RECEIVE")
        phase = snapshot.items.isEmpty && snapshot.pending.isEmpty ? .empty : .ready
    }

    private func send(_ action: String, contentID: String) async {
        guard !busy, phase == .ready || phase == .empty, !contentID.isEmpty else { return }
        busy = true
        defer { busy = false }
        guard let client, let token = token(), AuthRequestBuilder.isValidToken(token) else {
            receipt = Self.display(.refused)
            return
        }
        let slot = action + "\u{1f}" + contentID
        let requestID = openRequestIDs[slot].flatMap { PlayTeamItemCommandBody.validRequestID($0) ? $0 : nil }
            ?? "pg-theme-" + UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        let answer = await client.submit(activityID: activityID, action: action, contentID: contentID, revision: revision,
                                         authorityEpoch: authorityEpoch, requestID: requestID, token: token)
        if case .unknown = answer { openRequestIDs[slot] = requestID } else { openRequestIDs[slot] = nil }
        receipt = Self.display(answer)
    }

    private static func display(_ answer: PlayTeamCommandAnswer) -> PlayTeamCommandDisplay {
        let dash = PlayTeamCommandInterpretation.dash
        switch answer {
        case .applied(let receipt):
            return PlayTeamCommandDisplay(kind: .applied, outcome: receipt.outcome, receiptID: String(receipt.receiptID),
                                          revision: String(receipt.revision), serverMessage: nil, succeeded: true)
        case .failed(let receipt, let reason):
            return PlayTeamCommandDisplay(kind: .failed, outcome: receipt.outcome, receiptID: String(receipt.receiptID),
                                          revision: String(receipt.revision), serverMessage: reason.isEmpty ? nil : reason, succeeded: false)
        case .businessError(_, let message):
            return PlayTeamCommandDisplay(kind: .business, outcome: dash, receiptID: dash, revision: dash,
                                          serverMessage: message.isEmpty ? nil : message, succeeded: false)
        case .unknown:
            return PlayTeamCommandDisplay(kind: .unknown, outcome: dash, receiptID: dash, revision: dash, serverMessage: nil, succeeded: false)
        case .refused:
            return PlayTeamCommandDisplay(kind: .refused, outcome: dash, receiptID: dash, revision: dash, serverMessage: nil, succeeded: false)
        }
    }
}
