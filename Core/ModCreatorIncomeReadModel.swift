import Foundation
import Observation

public struct ModCreatorIncomeSelection: Identifiable, Hashable {
    public let id = UUID()
    public let orderKey: String, scope: UUID, minimumRevision: Int64
    init(fact: ModCreatorIncomeFact, scope: UUID) { orderKey = fact.orderKey; self.scope = scope; minimumRevision = fact.revision }
}
@MainActor @Observable public final class ModCreatorIncomeBrowser {
    public let reader: ModSettlementReader
    public private(set) var facts: [ModCreatorIncomeFact] = []
    public private(set) var loadedScope: UUID?
    public private(set) var nextCursor: String?
    public private(set) var readAt: Date?
    public private(set) var loading = false
    public private(set) var loadingMore = false
    public private(set) var issue: ModSettlementIssue?
    private var generation: UInt64 = 0
    private var cursors = Set<String>()
    public init(reader: ModSettlementReader) { self.reader = reader }
    public var hasCurrentPage: Bool { loadedScope == reader.scope }
    public var visibleFacts: [ModCreatorIncomeFact] { hasCurrentPage ? facts : [] }
    public func invalidate() {
        generation &+= 1; facts = []; loadedScope = nil; nextCursor = nil; readAt = nil
        loading = false; loadingMore = false; issue = nil; cursors = []
    }
    public func refresh() async {
        invalidate(); let ticket = generation, scope = reader.scope; loading = true
        defer { if generation == ticket { loading = false } }
        do {
            let page = try await reader.incomePage(expectedScope: scope)
            guard !Task.isCancelled, generation == ticket, reader.scope == scope else { return }
            facts = page.facts; loadedScope = scope; nextCursor = page.nextCursor; readAt = Date()
            if let cursor = page.nextCursor { cursors.insert(cursor) }
        } catch {
            guard !Task.isCancelled, generation == ticket, reader.scope == scope else { return }
            issue = ModSettlementIssue(error) // No empty-success or zero-income inference.
        }
    }
    public func more() async {
        guard !loading, !loadingMore, hasCurrentPage, let cursor = nextCursor else { return }
        let ticket = generation, scope = reader.scope; loadingMore = true; issue = nil
        defer { if generation == ticket { loadingMore = false } }
        do {
            let page = try await reader.incomePage(before: cursor, expectedScope: scope)
            guard !Task.isCancelled, generation == ticket, reader.scope == scope else { return }
            guard Set(facts.map(\.orderKey)).isDisjoint(with: page.facts.map(\.orderKey)),
                  page.nextCursor.map({ !cursors.contains($0) }) ?? true else { throw ModSettlementIssue.malformed }
            facts += page.facts; nextCursor = page.nextCursor; readAt = Date()
            if let cursor = page.nextCursor { cursors.insert(cursor) }
        } catch {
            guard !Task.isCancelled, generation == ticket, reader.scope == scope else { return }
            issue = ModSettlementIssue(error) // Retain previous original rows and retry the same cursor.
        }
    }
    public func select(_ fact: ModCreatorIncomeFact) -> ModCreatorIncomeSelection? {
        guard !loading, hasCurrentPage, facts.contains(fact) else { return nil }
        return .init(fact: fact, scope: reader.scope)
    }
}

@MainActor @Observable public final class ModCreatorIncomeDetailModel {
    public let reader: ModSettlementReader, selection: ModCreatorIncomeSelection
    public private(set) var current: ModCreatorIncomeFact?
    public private(set) var readAt: Date?
    public private(set) var revisions: [ModCreatorIncomeFact] = []
    public private(set) var nextBeforeRevision: Int64?
    public private(set) var loading = false
    public private(set) var loadingMore = false
    public private(set) var historyRead = false
    public private(set) var issue: ModSettlementIssue?
    public private(set) var historyIssue: ModSettlementIssue?
    private var generation: UInt64 = 0
    private var minimumRevision: Int64
    private var cursors = Set<Int64>()
    public init(reader: ModSettlementReader, selection: ModCreatorIncomeSelection) {
        self.reader = reader; self.selection = selection; minimumRevision = selection.minimumRevision
    }
    public var isCurrentScope: Bool { reader.scope == selection.scope }
    public var visibleCurrent: ModCreatorIncomeFact? { isCurrentScope ? current : nil }
    public func invalidate() {
        generation &+= 1; current = nil; readAt = nil; revisions = []; nextBeforeRevision = nil
        loading = false; loadingMore = false; historyRead = false; issue = nil; historyIssue = nil; cursors = []
    }
    public func refresh() async {
        invalidate(); let ticket = generation; loading = true
        defer { if generation == ticket { loading = false } }
        do {
            let fact = try await reader.incomeDetail(orderKey: selection.orderKey, expectedScope: selection.scope, minimumRevision: minimumRevision)
            guard !Task.isCancelled, generation == ticket, isCurrentScope else { return }
            current = fact; minimumRevision = fact.revision; readAt = Date()
            await history(anchor: fact, before: nil, ticket: ticket)
        } catch {
            guard !Task.isCancelled, generation == ticket else { return }
            issue = isCurrentScope ? ModSettlementIssue(error) : .stale
        }
    }
    public func retryHistory() async {
        guard !loading, !loadingMore, isCurrentScope, let fact = current else { return }
        let ticket = generation; loadingMore = true
        defer { if generation == ticket { loadingMore = false } }
        await history(anchor: fact, before: historyRead ? nextBeforeRevision : nil, ticket: ticket)
    }
    public func moreHistory() async {
        guard !loading, !loadingMore, isCurrentScope, let fact = current, let cursor = nextBeforeRevision else { return }
        let ticket = generation; loadingMore = true
        defer { if generation == ticket { loadingMore = false } }
        await history(anchor: fact, before: cursor, ticket: ticket)
    }
    private func history(anchor: ModCreatorIncomeFact, before: Int64?, ticket: UInt64) async {
        historyIssue = nil
        do {
            let page = try await reader.incomeRevisions(anchor: anchor, before: before, expectedScope: selection.scope)
            guard !Task.isCancelled, generation == ticket, isCurrentScope, current == anchor else { return }
            guard before == nil || Set(revisions.map(\.revision)).isDisjoint(with: page.revisions.map(\.revision)),
                  page.nextBeforeRevision.map({ !cursors.contains($0) }) ?? true else { throw ModSettlementIssue.malformed }
            revisions = before == nil ? page.revisions : revisions + page.revisions
            nextBeforeRevision = page.nextBeforeRevision; historyRead = true
            if let cursor = page.nextBeforeRevision { cursors.insert(cursor) }
        } catch {
            guard !Task.isCancelled, generation == ticket, isCurrentScope else { return }
            historyIssue = ModSettlementIssue(error) // Latest fact remains separately authoritative for its revision.
        }
    }
}
