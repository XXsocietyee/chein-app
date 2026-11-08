import Foundation
import Observation

/// View model for the bundle shelf (T-01). Holds only what the injected client returned.
@MainActor @Observable public final class BundleShelfModel {
    public enum State: Equatable { case idle, loading, loaded, unavailable, failed }

    public private(set) var state: State = .idle
    public private(set) var items: [BundleShelfItem] = []
    public private(set) var nextCursor: String?
    public private(set) var saleEnabled = false
    public private(set) var reservationEnabled = false
    /// True while the last page reported a cursor that has not been consumed yet.
    public var hasMore: Bool { state == .loaded && nextCursor != nil }

    @ObservationIgnored private let client: any BundleShelfClient
    @ObservationIgnored private let pageSize: Int
    @ObservationIgnored private var inFlight = false

    public init(client: any BundleShelfClient = UnavailableBundleShelfClient(), pageSize: Int = 20) {
        self.client = client
        self.pageSize = min(max(pageSize, 1), 50)
    }

    /// Reloads from the first page. A failure keeps nothing from a previous load.
    public func refresh() async {
        guard !inFlight else { return }
        inFlight = true; defer { inFlight = false }
        state = .loading
        do {
            let page = try await client.page(cursor: nil, limit: pageSize)
            items = Self.unique(page.items)
            nextCursor = Self.normalized(page.nextCursor, previous: nil)
            saleEnabled = page.saleEnabled ?? false
            reservationEnabled = page.reservationEnabled ?? false
            state = .loaded
        } catch {
            clear()
            state = (error as? BundleShelfFailure) == .unavailable ? .unavailable : .failed
        }
    }

    /// Fetches the next page. Does nothing once the server returned no cursor.
    public func loadMore() async {
        guard !inFlight, state == .loaded, let cursor = nextCursor else { return }
        inFlight = true; defer { inFlight = false }
        do {
            let page = try await client.page(cursor: cursor, limit: pageSize)
            let known = Set(items.map(\.topicId))
            items += Self.unique(page.items).filter { !known.contains($0.topicId) }
            // A server that echoes the same cursor would loop forever; treat it as the end.
            nextCursor = Self.normalized(page.nextCursor, previous: cursor)
            if let sale = page.saleEnabled { saleEnabled = sale }
            if let reserve = page.reservationEnabled { reservationEnabled = reserve }
        } catch {
            // Keep the rows already shown; the cursor stays so the caller may retry.
        }
    }

    private func clear() {
        items = []; nextCursor = nil; saleEnabled = false; reservationEnabled = false
    }

    private static func normalized(_ cursor: String?, previous: String?) -> String? {
        guard let cursor, !cursor.isEmpty, cursor != previous else { return nil }
        return cursor
    }

    private static func unique(_ rows: [BundleShelfItem]) -> [BundleShelfItem] {
        var seen = Set<FreeExploreLaunchID>()
        return rows.filter { seen.insert($0.topicId).inserted }
    }
}

/// Additive B-02 fields of `GET /catalog`. Every key is optional and decoded leniently so a missing or
/// reshaped extra never hides the legacy catalog. Compliance text is server-supplied only.
public struct BundleDetailExtras: Decodable, Equatable {
    public struct Compliance: Decodable, Equatable {
        public let agreementVersion: String?
        public let agreementUrl: String?
        public let declarations: [String]?
    }
    public struct Merchant: Decodable, Equatable {
        public let offerId: FreeExploreLaunchID
        public let merchantName: String?
        public let qualificationSummary: String?
    }
    public let compliance: Compliance?
    public let merchants: [Merchant]?
    public let price: FreeExploreLaunchDecimal?
    public let validityDays: Int?

    private enum Keys: String, CodingKey { case compliance, merchants, price, validityDays }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        compliance = try? c.decodeIfPresent(Compliance.self, forKey: .compliance)
        merchants = try? c.decodeIfPresent([Merchant].self, forKey: .merchants)
        price = try? c.decodeIfPresent(FreeExploreLaunchDecimal.self, forKey: .price)
        validityDays = try? c.decodeIfPresent(Int.self, forKey: .validityDays)
    }
}

/// Catalog plus additive extras, ready for `BundleDetailView`.
public struct BundleDetailContent: Equatable {
    public let catalog: FreeExploreLaunchCatalog
    public let extras: BundleDetailExtras?

    public init(catalog: FreeExploreLaunchCatalog, extras: BundleDetailExtras?) {
        self.catalog = catalog; self.extras = extras
    }

    /// Decodes one `catalog` data object into both the legacy and the additive view.
    public static func decode(_ data: Data) throws -> BundleDetailContent {
        let decoder = JSONDecoder()
        let catalog = try decoder.decode(FreeExploreLaunchCatalog.self, from: data)
        return BundleDetailContent(catalog: catalog, extras: try? decoder.decode(BundleDetailExtras.self, from: data))
    }

    /// Purchase UI may exist only when the server says the topic is on sale.
    public var showsPurchase: Bool { catalog.saleEnabled }
    public var showsNotOnSale: Bool { !catalog.saleEnabled }
    public var complianceDeclarations: [String] { extras?.compliance?.declarations?.filter { !$0.isEmpty } ?? [] }
    public var agreementURL: URL? {
        guard let text = extras?.compliance?.agreementUrl, let url = URL(string: text),
              url.scheme?.lowercased() == "https" else { return nil }
        return url
    }
    public var hasCompliance: Bool { !complianceDeclarations.isEmpty || agreementURL != nil }
}
