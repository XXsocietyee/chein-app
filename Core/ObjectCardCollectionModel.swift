import Foundation
import Observation

@MainActor @Observable public final class ObjectCardCollectionModel {
    public private(set) var collection: ObjectCardCollection?
    public private(set) var category: ObjectCardCategory = .all
    public private(set) var loading = false
    public private(set) var failed = false
    public private(set) var loadedScope: UUID?
    /// Mini-program `readAccess`: a 403 is 当前账号无法查看, not a retryable load failure.
    public private(set) var access: CollectionReadAccess?
    /// Last honest count. Starts unknown. A withheld list total stays unknown and is never stored as 0.
    public private(set) var totalFact: ObjectCardTotalFact = .unknown
    /// Cards from a 200 list whose total was withheld. Not published as a counted collection.
    public private(set) var withheldCards: [ObjectCard] = []
    private var generation: UInt64 = 0
    public init() {}

    /// Loading, empty, error, and unknown are distinct. Ready is a known total with at least one card.
    public var phase: ObjectCardAlbumPhase {
        if loading { return .loading }
        if failed { return .error }
        switch totalFact {
        case .unknown:
            return .unknown
        case .known:
            guard let collection else { return .unknown }
            return collection.cards.isEmpty ? .empty : .ready
        }
    }

    /// Em dash while the count is unknown. A server literal, including 0, is its decimal text.
    public var totalText: String { totalFact.text }

    public func invalidate() {
        generation &+= 1
        collection = nil
        category = .all
        loading = false
        failed = false
        loadedScope = nil
        access = nil
        totalFact = .unknown
        withheldCards = []
    }
    public func cancel() { generation &+= 1; loading = false }
    public func load(category next: ObjectCardCategory, reader: any ObjectCardReading) async {
        let scope = reader.scope
        if loadedScope != scope { invalidate() }
        guard !loading else { return }
        generation &+= 1; let captured = generation
        loading = true; failed = false; access = nil
        defer { if generation == captured { loading = false } }
        do {
            let result = try await reader.list(category: next)
            guard !Task.isCancelled, captured == generation, scope == reader.scope else { return }
            collection = result
            category = next
            loadedScope = scope
            totalFact = .known(result.total)
            withheldCards = []
        } catch let unknown as ObjectCardTotalUnknown {
            guard !Task.isCancelled, captured == generation, scope == reader.scope else { return }
            // Do not keep the previous number: it was not reported for this response.
            collection = nil
            category = next
            loadedScope = scope
            failed = false
            access = nil
            totalFact = .unknown
            withheldCards = unknown.cards
        } catch {
            guard !Task.isCancelled, !(error is CancellationError), captured == generation, scope == reader.scope else { return }
            failed = true; loadedScope = scope; access = CollectionReadAccess(error)
            // A failed filter retains the last successful filter and collection.
        }
    }
}
