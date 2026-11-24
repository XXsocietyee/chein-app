import SwiftUI

/// Received records from bounded original offset reads, never an atomic ledger or payout authority.
struct WalletIncomeAnalysisSlice {
    enum Stop: Equatable { case end, budget, interrupted, changed, unverified }
    let rows: [WalletLedgerRow]
    let pagesRead: Int
    let stop: Stop
    var isPartial: Bool { stop == .interrupted || stop == .changed || stop == .unverified }
}

/// The first-party income endpoint is a table; the separate asset balance array is not used here.
struct WalletIncomeAnalysisAccumulator {
    /// R7-PC-D6-1 (MP analysis/index.js:41-77): pages of 200 until the oldest row leaves the six-month window.
    static let pageSize = WalletAnalysisPagingPolicy.mpPageSize
    static let pageBudget = 10
    /// First instant of the oldest month the chart shows; nil keeps the total-or-budget stop only.
    var cutoff: Date? = nil
    private(set) var rows: [WalletLedgerRow] = []
    private(set) var pagesRead = 0
    private var observedTotal: Int?
    enum InvalidPage: Error { case changed }

    mutating func append(_ page: WalletPage<WalletLedgerRow>, requestedPage: Int) throws -> WalletIncomeAnalysisSlice.Stop? {
        guard requestedPage == pagesRead + 1, requestedPage <= Self.pageBudget,
              page.page == requestedPage, page.pageSize == Self.pageSize,
              page.rows.count <= Self.pageSize, page.rows.allSatisfy({ $0.id > 0 }),
              Set(page.rows.map(\.id)).count == page.rows.count,
              zip(page.rows, page.rows.dropFirst()).allSatisfy({ $0.0.id > $0.1.id }),
              rows.last.map({ last in page.rows.first.map { $0.id < last.id } ?? true }) ?? true else {
            throw InvalidPage.changed
        }
        // Without the original total, the received first page can be shown as unverified,
        // but it cannot justify further offset requests or a confirmed empty account.
        guard let total = page.total else {
            if pagesRead == 0 { rows = page.rows; pagesRead = 1 }
            return .unverified
        }
        guard total >= 0, observedTotal.map({ $0 == total }) ?? true else { throw InvalidPage.changed }
        let offset = (requestedPage - 1) * Self.pageSize
        guard total >= offset, page.rows.count == min(Self.pageSize, total - offset) else { throw InvalidPage.changed }
        observedTotal = total
        rows.append(contentsOf: page.rows); pagesRead += 1
        if rows.count >= total { return .end }
        // Newest first: once a page reaches back past the window, older pages cannot change the chart.
        if let cutoff, !WalletAnalysisPagingPolicy.shouldContinue(pageItemCount: page.rows.count,
                                                                  oldestItemDate: Self.date(page.rows.last?.createTime),
                                                                  cutoffDate: cutoff) { return .end }
        if pagesRead == Self.pageBudget { return .budget }
        return nil
    }
    static func date(_ raw: String?) -> Date? {
        switch BeijingServerTime(raw) {
        case .instant(let date): return date
        case .calendarDay(let day):
            let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX")
            f.calendar = Calendar(identifier: .gregorian); f.timeZone = BeijingServerTime.beijing; f.dateFormat = "yyyy-MM-dd"
            return f.date(from: day)
        case .unknown: return nil
        }
    }
    /// Start of the month five months before `now`'s month (Beijing), matching the six chart months.
    static func sixMonthCutoff(now: Date) -> Date? {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = BeijingServerTime.beijing
        guard let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: now)) else { return nil }
        return cal.date(byAdding: .month, value: -5, to: monthStart)
    }
    func slice(_ stop: WalletIncomeAnalysisSlice.Stop) -> WalletIncomeAnalysisSlice {
        .init(rows: rows, pagesRead: pagesRead, stop: stop)
    }
}

/// Reader identity is separate from scope: replacing a same-owner reader retires the old display.
struct WalletIncomeAnalysisReadIdentity: Equatable {
    let reader: ObjectIdentifier
    let scope: WalletCommerceScope?
    @MainActor init(_ value: WalletCommerceReader) { reader = ObjectIdentifier(value); scope = value.scope }
}

@MainActor final class WalletIncomeAnalysisReader: ObservableObject {
    @Published private(set) var loading = false
    @Published private(set) var failed = false
    @Published private(set) var requiresLogin = false
    @Published private(set) var unavailable = false
    @Published private(set) var receivedCount = 0
    @Published private(set) var pagesRead = 0
    @Published private(set) var result: WalletIncomeAnalysisSlice?
    private var identity: WalletIncomeAnalysisReadIdentity?
    private var generation = UUID()
    private var task: Task<Void, Never>?

    /// Core page projection. A partial or empty-unverified slice is unknown, never a zero total.
    var pageModel: AssetCenterAnalysisPageModel {
        if loading { return AssetCenterAnalysisPageModel(.loading) }
        if failed { return AssetCenterAnalysisPageModel(.error) }
        if unavailable || requiresLogin { return AssetCenterAnalysisPageModel(.error) }
        guard let result else { return AssetCenterAnalysisPageModel(.loading) }
        if result.rows.isEmpty { return AssetCenterAnalysisPageModel(result.isPartial ? .unknown : .empty) }
        if result.isPartial { return AssetCenterAnalysisPageModel(.unknown) }
        return AssetCenterAnalysisPageModel(rows: result.rows)
    }

    func displayedResult(for reader: WalletCommerceReader) -> WalletIncomeAnalysisSlice? {
        guard !loading, reader.isConfigured, reader.scope != nil,
              identity == WalletIncomeAnalysisReadIdentity(reader) else { return nil }
        return result
    }


    /// Close, background and replacement cancel the whole sequence, not just late publication.
    func cancel() {
        generation = UUID(); task?.cancel(); task = nil
        result = nil; identity = nil; receivedCount = 0; pagesRead = 0
        loading = false; failed = false; requiresLogin = false; unavailable = false
    }

    func load(_ reader: WalletCommerceReader) async {
        guard !Task.isCancelled else { return }
        cancel()
        guard reader.isConfigured else { unavailable = true; return }
        guard let scope = reader.scope else { requiresLogin = true; return }
        let stamp = generation
        identity = WalletIncomeAnalysisReadIdentity(reader); loading = true
        let work = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.collect(reader, scope: scope, stamp: stamp)
        }
        task = work
        await withTaskCancellationHandler(operation: { await work.value }, onCancel: { work.cancel() })
        if generation == stamp { task = nil }
    }

    private func checkCurrent(_ reader: WalletCommerceReader, scope: WalletCommerceScope, stamp: UUID) throws {
        try Task.checkCancellation()
        guard generation == stamp, identity == WalletIncomeAnalysisReadIdentity(reader),
              reader.isConfigured, reader.scope == scope else { throw WalletCommerceSafetyError.staleSession }
    }

    private func collect(_ reader: WalletCommerceReader, scope: WalletCommerceScope, stamp: UUID) async {
        var accumulator = WalletIncomeAnalysisAccumulator()
        accumulator.cutoff = WalletIncomeAnalysisAccumulator.sixMonthCutoff(now: Date())
        defer { if generation == stamp { loading = false } }
        do {
            for pageNumber in 1...WalletIncomeAnalysisAccumulator.pageBudget {
                try checkCurrent(reader, scope: scope, stamp: stamp)
                // Each page re-enters the original reader and exact narrow route. No writer,
                // alternate endpoint, new grant, receipt recovery or transaction is involved.
                let page = try await reader.read {
                    try await $0.ledger(.income(.all), page: pageNumber,
                        pageSize: WalletIncomeAnalysisAccumulator.pageSize, token: $1)
                }
                try checkCurrent(reader, scope: scope, stamp: stamp)
                let stop = try accumulator.append(page, requestedPage: pageNumber)
                receivedCount = accumulator.rows.count; pagesRead = accumulator.pagesRead
                if let stop { result = accumulator.slice(stop); return }
            }
        } catch {
            guard generation == stamp else { return }
            if Task.isCancelled || error is CancellationError {
                cancel(); return
            }
            guard identity == WalletIncomeAnalysisReadIdentity(reader), reader.scope == scope,
                  error as? WalletCommerceSafetyError != .staleSession else {
                result = nil; receivedCount = 0; pagesRead = 0; unavailable = true; return
            }
            if error as? APIError == .unauthorized {
                result = nil; receivedCount = 0; pagesRead = 0; requiresLogin = true
            } else if WalletReadFailurePresentation.isUnavailable(error) || WalletReadFailurePresentation.isForbidden(error) {
                result = nil; receivedCount = 0; pagesRead = 0; unavailable = true
            } else if !accumulator.rows.isEmpty {
                let changed = error is WalletIncomeAnalysisAccumulator.InvalidPage || error as? APIError == .malformedResponse
                result = accumulator.slice(changed ? .changed : .interrupted)
            } else { failed = true }
        }
    }
}
