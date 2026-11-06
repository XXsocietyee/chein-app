import Foundation
import Observation

public struct ModSettlementSelection: Identifiable, Hashable {
    public let id = UUID()
    public let settlementID: String, scope: UUID, minimumVersion: Int64
    init(record: ModSettlementRecord, scope: UUID) { settlementID = record.id; self.scope = scope; minimumVersion = record.version }
}
@Observable @MainActor public final class ModSettlementBrowser {
    public let reader: ModSettlementReader
    public private(set) var overview: ModSettlementOverview?
    public private(set) var issue: ModSettlementIssue?
    public private(set) var loading = false
    public private(set) var loadedScope: UUID?
    public private(set) var hasMore = false
    public private(set) var loadingMore = false
    private var generation: UInt64 = 0
    public init(reader: ModSettlementReader) { self.reader = reader }
    public var visibleOverview: ModSettlementOverview? { loadedScope == reader.scope ? overview : nil }
    public func invalidate() { generation &+= 1; overview = nil; issue = nil; loading = false; loadedScope = nil; hasMore = false; loadingMore = false }
    public func refresh() async {
        invalidate(); let attempt = generation, scope = reader.scope; loading = true
        defer { if generation == attempt { loading = false } }
        do {
            let value = try await reader.overview(expectedScope: scope)
            guard !Task.isCancelled, generation == attempt, reader.scope == scope else { return }
            overview = value; loadedScope = scope; hasMore = value.records.count == ModSettlementReader.pageLimit
        } catch {
            guard !Task.isCancelled, generation == attempt, reader.scope == scope else { return }
            issue = ModSettlementIssue(error); loadedScope = scope
        }
    }
    public func loadMore() async {
        guard !loading, !loadingMore, hasMore, loadedScope == reader.scope,
              let previous = overview, let last = previous.records.last else { return }
        let attempt = generation, scope = reader.scope
        loadingMore = true; issue = nil
        defer { if generation == attempt { loadingMore = false } }
        do {
            let rows = try await reader.page(before: last.id, expectedScope: scope)
            guard !Task.isCancelled, generation == attempt, reader.scope == scope else { return }
            let known = Set(previous.records.map(\.id))
            guard rows.allSatisfy({ !known.contains($0.id) && ($0.createdAt < last.createdAt || ($0.createdAt == last.createdAt && $0.id < last.id)) }) else { throw ModSettlementIssue.malformed }
            overview = ModSettlementOverview(records: previous.records + rows, qualification: previous.qualification, readAt: Date())
            hasMore = rows.count == ModSettlementReader.pageLimit
        } catch {
            guard !Task.isCancelled, generation == attempt, reader.scope == scope else { return }
            issue = ModSettlementIssue(error) // Retain prior original rows; a failed page is not an empty ledger.
        }
    }
    public func select(_ record: ModSettlementRecord) -> ModSettlementSelection? {
        guard !loading, loadedScope == reader.scope, visibleOverview?.records.contains(record) == true else { return nil }
        return ModSettlementSelection(record: record, scope: reader.scope)
    }
}
@Observable @MainActor public final class ModSettlementDetailModel {
    public let reader: ModSettlementReader, selection: ModSettlementSelection
    public private(set) var record: ModSettlementRecord?
    public private(set) var issue: ModSettlementIssue?
    public private(set) var loading = false
    public private(set) var readAt: Date?
    private var minimumVersion: Int64
    private var generation: UInt64 = 0
    public init(reader: ModSettlementReader, selection: ModSettlementSelection) {
        self.reader = reader; self.selection = selection; minimumVersion = selection.minimumVersion
    }
    public var visibleRecord: ModSettlementRecord? { reader.scope == selection.scope ? record : nil }
    public func invalidate() { generation &+= 1; record = nil; issue = nil; loading = false; readAt = nil }
    public func refresh() async {
        invalidate(); let attempt = generation; loading = true
        defer { if generation == attempt { loading = false } }
        do {
            let value = try await reader.detail(id: selection.settlementID, expectedScope: selection.scope, minimumVersion: minimumVersion)
            guard !Task.isCancelled, attempt == generation, reader.scope == selection.scope else { return }
            record = value; minimumVersion = value.version; readAt = Date()
        } catch {
            guard !Task.isCancelled, attempt == generation else { return }
            issue = reader.scope == selection.scope ? ModSettlementIssue(error) : .stale
        }
    }
}
