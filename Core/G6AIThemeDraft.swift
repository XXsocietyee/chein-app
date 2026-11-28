import Foundation

/// Port of the V2 simple-publish AI draft (`pages/publish/simple/index.js` + `pages/publish/utils/ai-theme-draft-journal.js`).
/// prepare → execute → result, with one durable identity per member. An unconfirmed answer is only read back,
/// never silently re-prepared. Starting over while the original is unknown needs an explicit confirmation.
public enum G6AIThemeDraft {
    public static let states = ["PREPARED", "PROCESSING", "UNKNOWN", "SUCCEEDED", "FAILED"]
    public static let stages = ["PREPARE_UNCONFIRMED", "PREPARED", "EXECUTE_UNCONFIRMED", "KNOWN"]
    static let viewFields: Set<String> = ["contextAvailable", "executeBefore", "productType", "reasonCode", "replayed", "requestId",
                                          "result", "resultAvailable", "resultExpiresAt", "state"]
    static let itemFields: Set<String> = ["createdAt", "cursor", "executeBefore", "prepareKey", "productType", "reasonCode",
                                          "requestId", "resultExpiresAt", "state"]

    public static func isUUID(_ value: String) -> Bool {
        let parts = value.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.map(\.count) == [8, 4, 4, 4, 12] else { return false }
        return value.unicodeScalars.allSatisfy { $0 == "-" || lowerHex($0) }
    }

    /// `td2_` plus 32 lowercase hex digits.
    public static func isServerID(_ value: String) -> Bool {
        guard value.hasPrefix("td2_") else { return false }
        let tail = value.dropFirst(4)
        return tail.count == 32 && tail.unicodeScalars.allSatisfy(lowerHex)
    }

    public static func isReason(_ value: String) -> Bool {
        guard let first = value.unicodeScalars.first, (65...90).contains(first.value), value.unicodeScalars.count <= 80 else { return false }
        return value.unicodeScalars.allSatisfy { (65...90).contains($0.value) || (48...57).contains($0.value) || $0 == "_" }
    }

    /// A positive Long cursor carried as a string. A JSON number is refused (it may already have lost precision).
    public static func cursor(_ value: Any?) -> String? {
        guard let text = value as? String, (1...19).contains(text.count), text.first != "0",
              text.allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
        if text.count == 19, text > "9223372036854775807" { return nil }
        return text
    }

    /// A UTC instant: a `T` separator and a trailing `Z`. Offsets (`+08:00`, `+00:00`) and a space separator are refused.
    public static func instant(_ value: Any?) -> Date? {
        guard let text = value as? String, text.hasSuffix("Z"), !text.contains("+"),
              let separator = text.firstIndex(of: "T"), text.distance(from: text.startIndex, to: separator) >= 8,
              !text[text.index(after: separator)...].dropLast().contains("-") else { return nil }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        fractional.timeZone = TimeZone(secondsFromGMT: 0)
        if let date = fractional.date(from: text) { return date }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        plain.timeZone = TimeZone(secondsFromGMT: 0)
        return plain.date(from: text)
    }

    static func older(_ left: String, than right: String) -> Bool {
        left.count < right.count || (left.count == right.count && left < right)
    }

    private static func lowerHex(_ scalar: Unicode.Scalar) -> Bool {
        (48...57).contains(scalar.value) || (97...102).contains(scalar.value)
    }

    static func isNull(_ value: Any?) -> Bool { value == nil || value is NSNull }
}

/// One validated V2 view (`_acceptAiView` shape check). Any extra or missing key rejects the whole view.
public struct G6AIThemeDraftView: Equatable, Sendable {
    public let requestID: String?
    public let state: String
    public let reasonCode: String?
    public let productType: Int?
    public let replayed: Bool
    public let contextAvailable: Bool
    public let resultAvailable: Bool
    public let executeBefore: Date?
    public let resultExpiresAt: Date?
    public let resultJSON: Data?

    public init?(_ value: Any?) {
        guard let body = value as? [String: Any], Set(body.keys) == G6AIThemeDraft.viewFields,
              let state = body["state"] as? String, G6AIThemeDraft.states.contains(state),
              let replayed = Self.bool(body["replayed"]), let context = Self.bool(body["contextAvailable"]),
              let resultAvailable = Self.bool(body["resultAvailable"]) else { return nil }
        let productType: Int?
        if G6AIThemeDraft.isNull(body["productType"]) { productType = nil }
        else if let type = G6JSON.integer(body["productType"]), type == 1 || type == 2 { productType = type }
        else { return nil }
        let reason: String?
        if G6AIThemeDraft.isNull(body["reasonCode"]) { reason = nil }
        else if let text = body["reasonCode"] as? String, G6AIThemeDraft.isReason(text) { reason = text }
        else { return nil }
        guard let execute = Self.optionalInstant(body["executeBefore"]), let expires = Self.optionalInstant(body["resultExpiresAt"]) else { return nil }
        let request: String?
        if G6AIThemeDraft.isNull(body["requestId"]) { request = nil }
        else if let text = body["requestId"] as? String { request = text }
        else { return nil }
        let result = body["result"]
        if resultAvailable {
            guard state == "SUCCEEDED", let object = result as? [String: Any] else { return nil }
            resultJSON = G6JSON.data(object)
        } else {
            guard G6AIThemeDraft.isNull(result) else { return nil }
            resultJSON = nil
        }
        requestID = request
        self.state = state
        reasonCode = reason
        self.productType = productType
        self.replayed = replayed
        contextAvailable = context
        self.resultAvailable = resultAvailable
        executeBefore = execute.value
        resultExpiresAt = expires.value
    }

    private struct Wrapped { let value: Date? }

    private static func optionalInstant(_ value: Any?) -> Wrapped? {
        if G6AIThemeDraft.isNull(value) { return Wrapped(value: nil) }
        guard let date = G6AIThemeDraft.instant(value) else { return nil }
        return Wrapped(value: date)
    }

    private static func bool(_ value: Any?) -> Bool? {
        guard let number = value as? NSNumber, CFGetTypeID(number as CFTypeRef) == CFBooleanGetTypeID() else { return nil }
        return number.boolValue
    }
}

/// The durable identity (`ai-theme-draft-journal.js` `valid`, `allowsUpdate`).
public struct G6AIThemeDraftRecord: Codable, Equatable, Sendable {
    public var version: Int
    public var memberId: String
    public var prepareKey: String?
    public var requestId: String?
    public var stage: String
    public var state: String?
    public var reasonCode: String?
    public var createdAt: Int64

    public init(memberId: String, prepareKey: String?, requestId: String?, stage: String, state: String?, reasonCode: String?, createdAt: Int64) {
        version = 2
        self.memberId = memberId
        self.prepareKey = prepareKey
        self.requestId = requestId
        self.stage = stage
        self.state = state
        self.reasonCode = reasonCode
        self.createdAt = createdAt
    }

    public var terminal: Bool { state == "SUCCEEDED" || state == "FAILED" }

    public static func key(member: String) -> String? {
        guard let first = member.first, first != "0", member.allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
        return "ai_theme_draft_v2:m" + member + ":active"
    }

    public func valid(member: String) -> Bool {
        guard version == 2, memberId == member, Self.key(member: member) != nil, createdAt >= 0,
              G6AIThemeDraft.stages.contains(stage) else { return false }
        if let state, !G6AIThemeDraft.states.contains(state) { return false }
        if let reasonCode, !G6AIThemeDraft.isReason(reasonCode) { return false }
        guard let requestId else {
            return prepareKey.map(G6AIThemeDraft.isUUID) == true && stage == "PREPARE_UNCONFIRMED" && state == nil
        }
        if G6AIThemeDraft.isServerID(requestId) {
            return prepareKey.map(G6AIThemeDraft.isUUID) == true && state != nil && stage != "PREPARE_UNCONFIRMED"
        }
        return G6AIThemeDraft.isUUID(requestId) && prepareKey == nil && stage == "KNOWN" && state != nil && state != "PREPARED"
    }

    public static func allowsUpdate(from previous: G6AIThemeDraftRecord, to next: G6AIThemeDraftRecord) -> Bool {
        if previous.prepareKey != next.prepareKey {
            return previous.terminal && next.requestId == nil && next.stage == "PREPARE_UNCONFIRMED" && next.state == nil
        }
        if previous.createdAt != next.createdAt || (previous.requestId != nil && previous.requestId != next.requestId) { return false }
        if previous.terminal { return next.state == previous.state }
        return !((previous.state == "PROCESSING" || previous.state == "UNKNOWN") && next.state == "PREPARED")
    }
}

/// Journal load outcome, as in `journal.load`.
public enum G6AIThemeDraftJournalLoad: Equatable, Sendable {
    case absent
    case ready(G6AIThemeDraftRecord)
    case corrupt
}

public struct G6AIThemeDraftJournal {
    private let store: any JourneyRequestStoring

    public init(store: any JourneyRequestStoring) { self.store = store }

    public func load(member: String) -> G6AIThemeDraftJournalLoad {
        guard let key = G6AIThemeDraftRecord.key(member: member) else { return .corrupt }
        guard let text = store.read(key), !text.isEmpty else { return .absent }
        guard let record = try? JSONDecoder().decode(G6AIThemeDraftRecord.self, from: Data(text.utf8)),
              record.valid(member: member) else { return .corrupt }
        return .ready(record)
    }

    /// Writes `next` only when it is valid and a legal update of `expected`. Reads back before reporting success.
    @discardableResult
    public func save(member: String, _ next: G6AIThemeDraftRecord, expected: G6AIThemeDraftRecord?) -> Bool {
        guard let key = G6AIThemeDraftRecord.key(member: member), next.valid(member: member) else { return false }
        if let expected {
            guard expected.valid(member: member), G6AIThemeDraftRecord.allowsUpdate(from: expected, to: next) else { return false }
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(next) else { return false }
        store.write(key, String(decoding: data, as: UTF8.self))
        return load(member: member) == .ready(next)
    }

    /// `beginConfirmedNewAction`: replace an unknown or unconfirmed original only after the member confirmed.
    @discardableResult
    public func beginConfirmedNew(member: String, _ next: G6AIThemeDraftRecord, replacing previous: G6AIThemeDraftRecord) -> Bool {
        guard let key = G6AIThemeDraftRecord.key(member: member), next.valid(member: member), previous.valid(member: member),
              previous.state == "UNKNOWN" || (previous.requestId == nil && previous.stage == "PREPARE_UNCONFIRMED"),
              next.requestId == nil, next.stage == "PREPARE_UNCONFIRMED", next.prepareKey != previous.prepareKey else { return false }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(next) else { return false }
        store.write(key, String(decoding: data, as: UTF8.self))
        return load(member: member) == .ready(next)
    }
}

/// One validated recovery page (`_loadAiRecovery`). Nil means the history cannot be trusted.
public struct G6AIThemeDraftRecoveryPage: Equatable, Sendable {
    public struct Item: Equatable, Sendable, Identifiable {
        public var id: String { requestID }
        public let cursor: String
        public let prepareKey: String
        public let requestID: String
        public let state: String
        public let reasonCode: String?
        public let productType: Int?
        public let createdAtText: String
    }

    public let items: [Item]
    public let nextCursor: String?

    public init?(_ value: Any?, before: String?) {
        guard let body = value as? [String: Any], Set(body.keys) == ["items", "nextCursor"],
              let rows = body["items"] as? [Any], rows.count <= 20 else { return nil }
        let next: String?
        if G6AIThemeDraft.isNull(body["nextCursor"]) { next = nil }
        else if let cursor = G6AIThemeDraft.cursor(body["nextCursor"]) { next = cursor }
        else { return nil }
        var previous = before
        var requests: Set<String> = []
        var keys: Set<String> = []
        var items: [Item] = []
        for row in rows {
            guard let item = row as? [String: Any], Set(item.keys) == G6AIThemeDraft.itemFields,
                  let cursor = G6AIThemeDraft.cursor(item["cursor"]) else { return nil }
            if let previous, !G6AIThemeDraft.older(cursor, than: previous) { return nil }
            guard let prepareKey = item["prepareKey"] as? String, G6AIThemeDraft.isUUID(prepareKey),
                  let request = item["requestId"] as? String, G6AIThemeDraft.isServerID(request),
                  let state = item["state"] as? String, G6AIThemeDraft.states.contains(state),
                  let created = item["createdAt"] as? String, G6AIThemeDraft.instant(created) != nil,
                  G6AIThemeDraft.instant(item["executeBefore"]) != nil,
                  !requests.contains(request), !keys.contains(prepareKey) else { return nil }
            let productType: Int?
            if G6AIThemeDraft.isNull(item["productType"]) { productType = nil }
            else if let type = G6JSON.integer(item["productType"]), type == 1 || type == 2 { productType = type }
            else { return nil }
            let reason: String?
            if G6AIThemeDraft.isNull(item["reasonCode"]) { reason = nil }
            else if let text = item["reasonCode"] as? String, G6AIThemeDraft.isReason(text) { reason = text }
            else { return nil }
            let expires = item["resultExpiresAt"]
            if !G6AIThemeDraft.isNull(expires), G6AIThemeDraft.instant(expires) == nil { return nil }
            if state == "SUCCEEDED", G6AIThemeDraft.instant(expires) == nil { return nil }
            previous = cursor
            requests.insert(request)
            keys.insert(prepareKey)
            let minute = String(created.replacingOccurrences(of: "T", with: " ").prefix(16))
            items.append(Item(cursor: cursor, prepareKey: prepareKey, requestID: request, state: state, reasonCode: reason,
                              productType: productType, createdAtText: minute))
        }
        if let next, items.count != 20 || next != previous { return nil }
        self.items = items
        nextCursor = next
    }
}

/// What one explicit AI action ended with. Only `.succeeded` carries a draft body.
public enum G6AIThemeDraftOutcome: Equatable, Sendable {
    case succeeded(requestID: String, resultJSON: Data)
    case succeededResultExpired
    case succeededResultUnavailable
    case failed
    case unknown
    case processing
    case prepareUnconfirmed
    case contextUnavailable
    case modeMismatch
    case networkUnconfirmed
    case notConfirmed
    case storage
    case needsConfirmation
    case invalidInput
}

/// The page's AI lane without the view. One instance per sheet keeps the in-memory prepare snapshot,
/// so "continue the original" can resend the same prepare body only while the original input is still here.
@MainActor public final class G6AIThemeDraftFlow {
    private struct Snapshot: Equatable { let member: String; let prepareKey: String; let idea: String; let productType: Int }

    private let source: G6CapabilitySource
    private let journal: G6AIThemeDraftJournal
    private let member: @MainActor () -> String?
    private let token: @MainActor () -> String?
    private let now: () -> Date
    private let makeUUID: () -> String
    private var snapshot: Snapshot?

    public init(source: G6CapabilitySource, store: any JourneyRequestStoring, member: @escaping @MainActor () -> String?,
                token: @escaping @MainActor () -> String?, now: @escaping () -> Date = Date.init,
                makeUUID: @escaping () -> String = { UUID().uuidString.lowercased() }) {
        self.source = source
        journal = G6AIThemeDraftJournal(store: store)
        self.member = member
        self.token = token
        self.now = now
        self.makeUUID = makeUUID
    }

    /// The saved identity, if any. `.corrupt` blocks every new action.
    public func current() -> G6AIThemeDraftJournalLoad {
        guard let member = member() else { return .corrupt }
        return journal.load(member: member)
    }

    /// True when the saved identity is unknown or its prepare is unconfirmed: a new draft needs explicit confirmation.
    public var canConfirmNew: Bool {
        guard case .ready(let record) = current() else { return false }
        return record.state == "UNKNOWN" || (record.requestId == nil && record.stage == "PREPARE_UNCONFIRMED")
    }

    /// `generateAiPlan` / `retryAiPlan`. A non-terminal original is read back (or its prepare resent with the same key).
    public func run(idea: String, productType: Int, confirmedNew: Bool = false) async -> G6AIThemeDraftOutcome {
        guard let member = member(), let token = token(), AuthRequestBuilder.isValidToken(token) else { return .storage }
        let text = idea.trimmingCharacters(in: .whitespacesAndNewlines)
        let loaded = journal.load(member: member)
        var pending: G6AIThemeDraftRecord?
        switch loaded {
        case .corrupt: return .storage
        case .absent: pending = nil
        case .ready(let record): pending = record
        }
        if let record = pending, !record.terminal {
            if confirmedNew, canConfirmNew {
                guard !text.isEmpty, [1, 2].contains(productType) else { return .invalidInput }
                let next = G6AIThemeDraftRecord(memberId: member, prepareKey: makeUUID(), requestId: nil, stage: "PREPARE_UNCONFIRMED",
                                                state: nil, reasonCode: nil, createdAt: millis())
                guard journal.beginConfirmedNew(member: member, next, replacing: record), let key = next.prepareKey else { return .storage }
                snapshot = Snapshot(member: member, prepareKey: key, idea: text, productType: productType)
                return await prepare(next, member: member, token: token)
            }
            if record.requestId == nil, let snapshot, snapshot.member == member, snapshot.prepareKey == record.prepareKey {
                return await prepare(record, member: member, token: token)
            }
            if record.state == "PREPARED", let request = record.requestId, G6AIThemeDraft.isServerID(request) {
                return await readBack(record, member: member, token: token, allowExecute: true)
            }
            return await readBack(record, member: member, token: token, allowExecute: false)
        }
        guard !text.isEmpty, [1, 2].contains(productType) else { return .invalidInput }
        let next = G6AIThemeDraftRecord(memberId: member, prepareKey: makeUUID(), requestId: nil, stage: "PREPARE_UNCONFIRMED",
                                        state: nil, reasonCode: nil, createdAt: millis())
        guard journal.save(member: member, next, expected: pending), let key = next.prepareKey else { return .storage }
        snapshot = Snapshot(member: member, prepareKey: key, idea: text, productType: productType)
        return await prepare(next, member: member, token: token)
    }

    private func prepare(_ record: G6AIThemeDraftRecord, member: String, token: String) async -> G6AIThemeDraftOutcome {
        guard let snapshot, snapshot.prepareKey == record.prepareKey else { return .notConfirmed }
        let envelope: G6Envelope
        do {
            envelope = try await source.aiDraftPrepare(prepareKey: snapshot.prepareKey, idea: snapshot.idea,
                                                       productType: snapshot.productType, token: token)
        } catch {
            return .networkUnconfirmed
        }
        if envelope.netFail { return .networkUnconfirmed }
        return await accept(envelope, record: record, member: member, token: token,
                            mayExecute: envelope.ok && envelope.httpStatus == 200, originalMode: snapshot.productType)
    }

    private func readBack(_ record: G6AIThemeDraftRecord, member: String, token: String, allowExecute: Bool) async -> G6AIThemeDraftOutcome {
        let envelope: G6Envelope
        do {
            envelope = try await source.aiDraftRequest(requestID: record.requestId, prepareKey: record.requestId == nil ? record.prepareKey : nil, token: token)
        } catch {
            return .networkUnconfirmed
        }
        if envelope.netFail { return .networkUnconfirmed }
        let mode = snapshot.flatMap { $0.prepareKey == record.prepareKey ? $0.productType : nil }
        return await accept(envelope, record: record, member: member, token: token, mayExecute: allowExecute, originalMode: mode)
    }

    private func accept(_ envelope: G6Envelope, record: G6AIThemeDraftRecord, member: String, token: String,
                        mayExecute: Bool, originalMode: Int?) async -> G6AIThemeDraftOutcome {
        guard let view = G6AIThemeDraftView(envelope.data) else { return .notConfirmed }
        if let mode = view.productType, let originalMode, mode != originalMode { return .modeMismatch }
        guard let request = view.requestID else {
            guard record.requestId == nil, view.state == "UNKNOWN", view.reasonCode == "AI_DRAFT_PREPARE_UNCONFIRMED" else { return .notConfirmed }
            return .prepareUnconfirmed
        }
        if let saved = record.requestId {
            guard saved == request else { return .notConfirmed }
        } else {
            guard G6AIThemeDraft.isServerID(request) else { return .notConfirmed }
        }
        if G6AIThemeDraft.isServerID(request) {
            guard view.executeBefore != nil else { return .notConfirmed }
            if view.state == "SUCCEEDED", view.resultExpiresAt == nil { return .notConfirmed }
        }
        if record.terminal, record.state != view.state { return .notConfirmed }
        var next = record
        next.requestId = request
        next.state = view.state
        next.reasonCode = view.reasonCode
        next.stage = view.state == "PREPARED" ? "PREPARED" : "KNOWN"
        guard journal.save(member: member, next, expected: record) else { return .storage }
        switch view.state {
        case "SUCCEEDED":
            if view.resultAvailable, let result = view.resultJSON { return .succeeded(requestID: request, resultJSON: result) }
            return view.reasonCode == "AI_DRAFT_RESULT_EXPIRED" ? .succeededResultExpired : .succeededResultUnavailable
        case "FAILED": return .failed
        case "UNKNOWN": return .unknown
        case "PROCESSING": return .processing
        default:
            guard mayExecute else { return .contextUnavailable }
            return await execute(next, view: view, member: member, token: token, originalMode: originalMode)
        }
    }

    private func execute(_ record: G6AIThemeDraftRecord, view: G6AIThemeDraftView, member: String, token: String,
                         originalMode: Int?) async -> G6AIThemeDraftOutcome {
        guard let request = record.requestId, G6AIThemeDraft.isServerID(request), record.state == "PREPARED",
              view.contextAvailable, let deadline = view.executeBefore, deadline > now() else { return .contextUnavailable }
        var next = record
        next.stage = "EXECUTE_UNCONFIRMED"
        guard journal.save(member: member, next, expected: record) else { return .storage }
        let envelope: G6Envelope
        do {
            envelope = try await source.aiDraftExecute(requestID: request, token: token)
        } catch {
            return .networkUnconfirmed
        }
        if envelope.netFail { return .networkUnconfirmed }
        return await accept(envelope, record: next, member: member, token: token, mayExecute: false, originalMode: originalMode)
    }

    private func millis() -> Int64 { Int64(now().timeIntervalSince1970 * 1000) }
}
