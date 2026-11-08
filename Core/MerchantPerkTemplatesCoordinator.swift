import Foundation
import Observation

/// One standing-perk template row from `api/coop/perk-template/list` (source `pages/merchant/decor/perks`).
public struct MerchantPerkTemplateRow: Identifiable, Equatable {
    public let id: Int
    public let name: String
    /// 0 gift, 1 coupon, 2 discount (source `PERK_TYPES`).
    public let typeIndex: Int?
    public let retailValue: Decimal?
    public let unitCost: Decimal?
    public let quota: Int?
    public let validEnd: String?
    /// Source `isUsableTemplate`: a valid type, a positive retail value and a positive quota.
    public let usable: Bool
    public init?(_ value: CoopFlowJSON) {
        guard let id = value["id"].integer, id > 0, let name = value["name"].text,
              !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        self.id = id; self.name = name
        let type = value["perkType"].integer
        typeIndex = type.flatMap { (0...2).contains($0) ? $0 : nil }
        retailValue = CoopFlowMoney(value["retailValue"]).amount
        unitCost = CoopFlowMoney(value["unitCost"]).amount
        quota = value["quota"].integer
        validEnd = value["validEnd"].text.map { String($0.prefix(10)) }.flatMap { $0.isEmpty ? nil : $0 }
        usable = typeIndex != nil && (retailValue ?? 0) > 0 && (quota ?? 0) > 0
    }
}

/// Form values as typed. Validation mirrors the source: amounts are at most 8 integer and 2 decimal digits.
public struct MerchantPerkTemplateDraft: Equatable {
    public var typeIndex = 0
    public var name = ""
    public var retailValue = ""
    public var unitCost = ""
    public var quota = ""
    public var validEnd = ""
    public init() {}
    static func amount(_ text: String, allowZero: Bool) -> Decimal? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        let parts = trimmed.split(separator: ".", omittingEmptySubsequences: false)
        guard (1...2).contains(parts.count), parts[0].count >= 1, parts[0].count <= 8,
              parts.allSatisfy({ $0.allSatisfy { $0.isASCII && $0.isNumber } }) else { return nil }
        if parts.count == 2 { guard (1...2).contains(parts[1].count) else { return nil } }
        guard let value = Decimal(string: trimmed, locale: Locale(identifier: "en_US_POSIX")) else { return nil }
        return (allowZero ? value >= 0 : value > 0) ? value : nil
    }
    public var canSave: Bool { (try? template()) != nil }
    /// Throws `CoopFlowFailure.invalid` when a required field is missing or malformed.
    public func template() throws -> CoopFlowPerkTemplate {
        guard let retail = Self.amount(retailValue, allowZero: false) else { throw CoopFlowFailure.invalid("retailValue") }
        let costText = unitCost.trimmingCharacters(in: .whitespaces)
        var cost: Decimal?
        if !costText.isEmpty {
            guard let parsed = Self.amount(costText, allowZero: true) else { throw CoopFlowFailure.invalid("unitCost") }
            cost = parsed
        }
        let quotaText = quota.trimmingCharacters(in: .whitespaces)
        guard !quotaText.isEmpty, quotaText.allSatisfy({ $0.isASCII && $0.isNumber }), let count = Int(quotaText), count > 0 else {
            throw CoopFlowFailure.invalid("quota")
        }
        let end = validEnd.trimmingCharacters(in: .whitespaces)
        return try CoopFlowPerkTemplate(name: name, type: typeIndex, retailValue: retail, unitCost: cost, quota: count,
                                        validEnd: end.isEmpty ? nil : end)
    }
}

/// Standing perks list, create and delete through the injected cooperation reader/executor.
/// Success is shown only after the service returns success AND a fresh list read confirms the change.
@available(macOS 14.0, *)
@MainActor @Observable public final class MerchantPerkTemplatesCoordinator {
    public enum Phase: Equatable { case idle, loading, ready, permissionDenied, failed, signedOut }
    public enum Action: Equatable {
        case idle, saving, deleting(Int)
        case saved, deleted
        /// Server accepted the write but the refreshed list does not show it yet (source readback-pending).
        case unconfirmed
        case invalid, notAvailableYet, permissionDenied, failed
    }
    public private(set) var phase: Phase = .idle
    public private(set) var rows: [MerchantPerkTemplateRow] = []
    public private(set) var action: Action = .idle
    /// True while a refresh runs over an already-loaded list (source `refreshing`).
    public private(set) var refreshing = false
    private let reader: any CoopFlowReading
    private let executor: (any CoopFlowExecuting)?
    private let now: () -> Date
    private var generation: UInt64 = 0

    public init(reader: any CoopFlowReading, executor: (any CoopFlowExecuting)?, now: @escaping () -> Date) {
        self.reader = reader; self.executor = executor; self.now = now
    }
    /// Writes need an injected executor whose reviewed grant permits the exact operation.
    public convenience init(reader: any CoopFlowReading, executor: (any CoopFlowExecuting)?) {
        self.init(reader: reader, executor: executor, now: { Date() })
    }
    public func canWrite(_ operation: CoopFlowMutation) -> Bool { executor?.permitsDispatch(operation) == true }
    public var isBusy: Bool {
        switch action { case .saving, .deleting: return true; default: return false }
    }

    private static func isPermission(_ error: Error) -> Bool {
        if let flow = error as? CoopFlowFailure {
            switch flow {
            case .permission, .inactiveMerchant: return true
            case .server(let code, _): return code == 401 || code == 403
            default: return false
            }
        }
        return false
    }

    public func load() async {
        guard !(phase == .loading) else { return }
        guard let session = reader.session else { phase = .signedOut; rows = []; return }
        generation &+= 1; let stamp = generation
        let hadRows = phase == .ready
        if hadRows { refreshing = true } else { phase = .loading }
        defer { if stamp == generation { refreshing = false } }
        do {
            let result = try await reader.read(.templates)
            guard !Task.isCancelled, stamp == generation, reader.session == session else { return }
            guard let values = result.rows else { throw CoopFlowFailure.malformed }
            var parsed: [MerchantPerkTemplateRow] = []
            for value in values {
                guard let row = MerchantPerkTemplateRow(value) else { throw CoopFlowFailure.malformed }
                parsed.append(row)
            }
            guard Set(parsed.map(\.id)).count == parsed.count else { throw CoopFlowFailure.malformed }
            rows = parsed; phase = .ready
        } catch {
            guard !Task.isCancelled, stamp == generation, reader.session == session else { return }
            if Self.isPermission(error) { rows = []; phase = .permissionDenied }
            else if !hadRows { rows = []; phase = .failed }
            else { action = .failed }   // keep the last list, say the refresh failed
        }
    }

    public func save(_ draft: MerchantPerkTemplateDraft) async {
        guard !isBusy else { return }
        let template: CoopFlowPerkTemplate
        let operation: CoopFlowMutation
        do { template = try draft.template(); operation = .createTemplate(template); _ = try operation.body(now: now()) }
        catch { action = .invalid; return }
        guard let executor, executor.permitsDispatch(operation) else { action = .notAvailableYet; return }
        guard let session = reader.session else { phase = .signedOut; return }
        action = .saving
        do {
            let result = try await executor.execute(operation, session: session)
            guard !Task.isCancelled, reader.session == session else { action = .idle; return }
            guard let savedID = result["id"].integer, savedID > 0 else { action = .unconfirmed; await refreshQuietly(); return }
            await refreshQuietly()
            action = rows.contains(where: { $0.id == savedID }) ? .saved : .unconfirmed
        } catch {
            guard reader.session == session else { action = .idle; return }
            action = Self.failureAction(error)
        }
    }

    public func delete(id: Int) async {
        guard !isBusy, id > 0 else { return }
        let operation = CoopFlowMutation.deleteTemplate(id: id)
        guard let executor, executor.permitsDispatch(operation) else { action = .notAvailableYet; return }
        guard let session = reader.session else { phase = .signedOut; return }
        action = .deleting(id)
        do {
            _ = try await executor.execute(operation, session: session)
            guard !Task.isCancelled, reader.session == session else { action = .idle; return }
            await refreshQuietly()
            action = rows.contains(where: { $0.id == id }) ? .unconfirmed : .deleted
        } catch {
            guard reader.session == session else { action = .idle; return }
            action = Self.failureAction(error)
        }
    }

    public func dismissAction() { if !isBusy { action = .idle } }

    private static func failureAction(_ error: Error) -> Action {
        if let flow = error as? CoopFlowFailure, flow == .disabled { return .notAvailableYet }
        if isPermission(error) { return .permissionDenied }
        return .failed
    }
    /// Reads the list again; a failed refresh keeps the last list and the caller decides the outcome from it.
    private func refreshQuietly() async { await load() }
}
