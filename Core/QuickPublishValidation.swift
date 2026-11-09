import Foundation

/// Specific, bilingual reasons a quick-publish draft cannot be handed to the professional editor.
/// Mirrors the rule in `QuickPublishDraft.professionalSeed` (title, at least one stop, every stop named and
/// map-confirmed); `professionalSeed` stays the single authority, this only explains the refusal.
public enum QuickPublishIssue: Equatable {
    case titleMissing
    case noStops
    case stopNameMissing(index: Int)
    case placeUnconfirmed(index: Int)

    public var message: String {
        switch self {
        case .titleMissing: return W8Text.t("请先填写路线名称", "Enter a route name first")
        case .noStops: return W8Text.t("至少添加一个站点", "Add at least one stop")
        case .stopNameMissing(let index): return W8Text.t("第 \(index) 站还没有名称", "Stop \(index) needs a name")
        case .placeUnconfirmed(let index): return W8Text.t("请在地图上确认第 \(index) 站的位置", "Confirm the location of stop \(index) on the map")
        }
    }
}

public enum QuickPublishValidation {
    /// Issues in reading order; empty exactly when `professionalSeed` would accept the draft.
    public static func issues(_ draft: QuickPublishDraft) -> [QuickPublishIssue] {
        var result: [QuickPublishIssue] = []
        if draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { result.append(.titleMissing) }
        if draft.nodes.isEmpty { result.append(.noStops) }
        for (offset, node) in draft.nodes.enumerated() {
            if node.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { result.append(.stopNameMissing(index: offset + 1)) }
            if node.confirmedPlace == nil { result.append(.placeUnconfirmed(index: offset + 1)) }
        }
        return result
    }
}

/// Read model for `pages/publish/simple/index`.
/// Home is the existing `PublishingRead.capability` contract (`api/publish/home`).
/// Quota is the existing `PublishingRead.aiQuota` contract (`api/ai/theme/draft/quota`),
/// and only an explicit `.publishingAIQuota` grant may read it. `.publishingRead` does not imply that grant.
/// A missing grant stays hidden. This type does not call `api/ai/theme/draft`, does not publish,
/// and does not change whether either route is live.
public struct QuickPublishSimplePageGrant: Equatable {
    public let features: Set<BusinessRuntimeFeature>
    public init(features: Set<BusinessRuntimeFeature>) { self.features = features }
    public var canReadHome: Bool { features.contains(.publishingRead) }
    public var canReadQuota: Bool { features.contains(.publishingAIQuota) }
}

public enum QuickPublishSimpleFetch: Equatable {
    case pending
    case failed
    case value(ProjectEditJSON)
}

public enum QuickPublishSimpleCount: Equatable {
    case unknown
    case value(Int)

    /// Unknown, null, a missing key, the token UNKNOWN, a numeric string, and a non-integer stay an em dash.
    public static let unknownText = "—"

    public var text: String {
        switch self {
        case .unknown: return Self.unknownText
        case .value(let number): return String(number)
        }
    }

    /// A server literal, including 0. Unknown is nil and is never reported as 0.
    public var literal: Int? {
        if case .value(let number) = self { return number }
        return nil
    }

    public static func parse(_ value: ProjectEditJSON?) -> Self {
        guard let number = value?.integer, number >= 0 else { return .unknown }
        return .value(number)
    }
}

public enum QuickPublishSimplePageCopy {
    public static let loading = "publishModes.quick.loading"
    public static let empty = "publishModes.quick.emptyState"
    public static let loadFailed = "publishModes.quick.loadFailed"
    public static let unknown = "publishModes.quick.unknownValue"
    public static let hidden = "publishModes.quick.hiddenState"
}

public enum QuickPublishSimplePageAccessibility {
    public static let aiOpen = "contextPublish.ai.open"
    public static let name = "publishModes.quick.name"
    public static let addStop = "publishModes.quick.add"
    public static let continueEditor = "publishModes.quick.continue"
    public static let loading = "publishModes.quick.loading"
    public static let empty = "publishModes.quick.empty"
    public static let error = "publishModes.quick.error"
    public static let unknown = "publishModes.quick.unknown"
    public static let ready = "publishModes.quick.ready"
    public static let hidden = "publishModes.quick.hidden"
    public static let quota = "publishModes.quick.quota"
    public static let heroTitle = "publishModes.quick.heroTitle"
    public static let kickerCity = "publishModes.quick.kicker.city"
    public static let kickerFree = "publishModes.quick.kicker.free"
    public static let aiNote = "publishModes.quick.aiNote"
    public static let all = [
        aiOpen, name, addStop, continueEditor, loading, empty, error, unknown, ready, hidden, quota, heroTitle, kickerCity, kickerFree, aiNote
    ]
}

public struct QuickPublishSimplePageSnapshot: Equatable {
    public enum Phase: Equatable {
        case hidden
        case loading
        case empty
        case error
        case unknown
        case ready
    }

    public let phase: Phase
    public let showsPage: Bool
    public let showsAIQuota: Bool
    public let quotaRemaining: QuickPublishSimpleCount
    public let quotaLimit: QuickPublishSimpleCount
    public let themesRemaining: QuickPublishSimpleCount
    public let messageKey: String?

    public var accessibilityIdentifier: String {
        switch phase {
        case .hidden: return QuickPublishSimplePageAccessibility.hidden
        case .loading: return QuickPublishSimplePageAccessibility.loading
        case .empty: return QuickPublishSimplePageAccessibility.empty
        case .error: return QuickPublishSimplePageAccessibility.error
        case .unknown: return QuickPublishSimplePageAccessibility.unknown
        case .ready: return QuickPublishSimplePageAccessibility.ready
        }
    }

    public var quotaRemainingText: String { showsAIQuota ? quotaRemaining.text : QuickPublishSimpleCount.unknownText }
    public var quotaLimitText: String { showsAIQuota ? quotaLimit.text : QuickPublishSimpleCount.unknownText }
    public var themesRemainingText: String {
        switch phase {
        case .empty, .ready, .unknown: return themesRemaining.text
        case .hidden, .loading, .error: return QuickPublishSimpleCount.unknownText
        }
    }
}

public enum QuickPublishSimplePageContract {
    public static let home = PublishingRead.capability
    public static let quota = PublishingRead.aiQuota
    public static let homePath = "api/publish/home"
    public static let quotaPath = "api/ai/theme/draft/quota"
    /// Generation stays on the existing draft flow. This page model never requests it.
    public static let unusedThemeDraftPath = "api/ai/theme/draft"
}

public enum QuickPublishSimplePageModel {
    public static func make(grant: QuickPublishSimplePageGrant, home: QuickPublishSimpleFetch, quota: QuickPublishSimpleFetch, draft: QuickPublishDraft) -> QuickPublishSimplePageSnapshot {
        guard grant.canReadHome else { return concealed(phase: .hidden) }
        switch home {
        case .pending:
            return concealed(phase: .loading)
        case .failed:
            return concealed(phase: .error)
        case .value(let payload):
            guard let body = payload.object else { return concealed(phase: .error) }
            if let flag = body["permission"]?.object?["canSimplePublish"] {
                switch flag {
                case .bool(false): return concealed(phase: .hidden)
                case .bool(true): break
                default: return concealed(phase: .error)
                }
            }
            let themes = QuickPublishSimpleCount.parse(body["quota"]?.object?["themesRemaining"])
            guard grant.canReadQuota else {
                return finish(themes: themes, remaining: .unknown, limit: .unknown, showsAIQuota: false, quotaUnknown: false, draft: draft)
            }
            switch quota {
            case .pending:
                return concealed(phase: .loading)
            case .failed:
                return concealed(phase: .error)
            case .value(let quotaPayload):
                guard let object = quotaPayload.object, case .bool(let limited)? = object["limited"] else { return concealed(phase: .error) }
                let remaining = QuickPublishSimpleCount.parse(object["remaining"])
                let limit = QuickPublishSimpleCount.parse(object["limit"])
                return finish(themes: themes, remaining: remaining, limit: limit, showsAIQuota: true, quotaUnknown: quotaIsUnknown(limited: limited, object: object, remaining: remaining, limit: limit), draft: draft)
            }
        }
    }

    public static func allowsQuotaRead(grant: QuickPublishSimplePageGrant, home: ProjectEditJSON) -> Bool {
        guard grant.canReadHome, grant.canReadQuota, let body = home.object else { return false }
        if let flag = body["permission"]?.object?["canSimplePublish"] {
            if case .bool(true) = flag { return true }
            return false
        }
        return true
    }

    private static func quotaIsUnknown(limited: Bool, object: [String: ProjectEditJSON], remaining: QuickPublishSimpleCount, limit: QuickPublishSimpleCount) -> Bool {
        if limited, remaining.literal == nil { return true }
        if let raw = object["remaining"], raw != .null, remaining.literal == nil { return true }
        if let raw = object["limit"], raw != .null, limit.literal == nil { return true }
        return false
    }

    private static func finish(themes: QuickPublishSimpleCount, remaining: QuickPublishSimpleCount, limit: QuickPublishSimpleCount, showsAIQuota: Bool, quotaUnknown: Bool, draft: QuickPublishDraft) -> QuickPublishSimplePageSnapshot {
        let blank = draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && draft.nodes.isEmpty
        let phase: QuickPublishSimplePageSnapshot.Phase
        let message: String?
        if themes.literal == nil || quotaUnknown {
            phase = .unknown
            message = QuickPublishSimplePageCopy.unknown
        } else if blank {
            phase = .empty
            message = QuickPublishSimplePageCopy.empty
        } else {
            phase = .ready
            message = nil
        }
        return .init(phase: phase, showsPage: true, showsAIQuota: showsAIQuota, quotaRemaining: remaining, quotaLimit: limit, themesRemaining: themes, messageKey: message)
    }

    private static func concealed(phase: QuickPublishSimplePageSnapshot.Phase) -> QuickPublishSimplePageSnapshot {
        let message: String?
        switch phase {
        case .loading: message = QuickPublishSimplePageCopy.loading
        case .error: message = QuickPublishSimplePageCopy.loadFailed
        case .hidden: message = QuickPublishSimplePageCopy.hidden
        case .empty, .unknown, .ready: message = nil
        }
        let showsPage = phase == .error
        return .init(phase: phase, showsPage: showsPage, showsAIQuota: false, quotaRemaining: .unknown, quotaLimit: .unknown, themesRemaining: .unknown, messageKey: message)
    }
}

@MainActor public final class QuickPublishSimplePageCoordinator {
    public private(set) var snapshot: QuickPublishSimplePageSnapshot
    private let grant: QuickPublishSimplePageGrant
    private let read: (PublishingRead) async throws -> ProjectEditJSON
    private var generation = 0

    public init(grant: QuickPublishSimplePageGrant, read: @escaping (PublishingRead) async throws -> ProjectEditJSON) {
        self.grant = grant
        self.read = read
        snapshot = QuickPublishSimplePageModel.make(grant: grant, home: .pending, quota: .pending, draft: .init())
    }

    public func load(draft: QuickPublishDraft) async {
        generation += 1
        let stamp = generation
        guard grant.canReadHome else {
            snapshot = QuickPublishSimplePageModel.make(grant: grant, home: .pending, quota: .pending, draft: draft)
            return
        }
        snapshot = QuickPublishSimplePageModel.make(grant: grant, home: .pending, quota: .pending, draft: draft)
        let home: QuickPublishSimpleFetch
        do { home = .value(try await read(.capability)) } catch { home = .failed }
        guard stamp == generation else { return }
        var quota: QuickPublishSimpleFetch = .pending
        if case .value(let payload) = home, QuickPublishSimplePageModel.allowsQuotaRead(grant: grant, home: payload) {
            do { quota = .value(try await read(.aiQuota)) } catch { quota = .failed }
        }
        guard stamp == generation else { return }
        snapshot = QuickPublishSimplePageModel.make(grant: grant, home: home, quota: quota, draft: draft)
    }
}

#if DEBUG
/// Synthetic payloads for the quick-publish read model. Debug builds only. No host, token, or account secret.
public enum QuickPublishSimplePageFixture {
    public static let homeReadyJSON = #"{"role":"player","permission":{"canSimplePublish":true},"quota":{"themesRemaining":3}}"#
    public static let homeImplicitPermissionJSON = #"{"role":"player","quota":{"themesRemaining":3}}"#
    public static let homeMalformedPermissionJSON = #"{"role":"player","permission":{"canSimplePublish":"yes"},"quota":{"themesRemaining":3}}"#
    public static let homeDeniedJSON = #"{"role":"player","permission":{"canSimplePublish":false},"quota":{"themesRemaining":0}}"#
    public static let homeMissingThemesJSON = #"{"role":"player","permission":{"canSimplePublish":true},"quota":{}}"#
    public static let homeZeroThemesJSON = #"{"role":"player","permission":{"canSimplePublish":true},"quota":{"themesRemaining":0}}"#
    public static let quotaReadyJSON = #"{"limited":true,"remaining":2,"limit":4}"#
    public static let quotaZeroJSON = #"{"limited":true,"remaining":0,"limit":4}"#
    public static let quotaUnlimitedJSON = #"{"limited":false,"remaining":null,"limit":null}"#
    public static let quotaUnknownJSON = #"{"limited":true,"remaining":"UNKNOWN","limit":4}"#
    public static let quotaNumericStringJSON = #"{"limited":true,"remaining":"2","limit":4}"#
    public static let quotaFractionJSON = #"{"limited":true,"remaining":1.5,"limit":4}"#

    public static func decode(_ json: String) -> ProjectEditJSON {
        (try? JSONDecoder().decode(ProjectEditJSON.self, from: Data(json.utf8))) ?? .null
    }
}
#endif
