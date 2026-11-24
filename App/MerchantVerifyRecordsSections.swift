import SwiftUI

/// Source pages/merchant/verify-records (M-03 / BL-76): 已核销 / 已撤销 chip tabs with counts, day groups with an
/// "N 条" total, rows = station or store name, "HH:mm · status", topic. Reads finance/redemptions rows only.
enum MerchantVerifyRecordsParity {
    enum Bucket: String, CaseIterable, Hashable { case verified = "VERIFIED", reversed = "REVERSED" }
    struct Row: Identifiable, Equatable {
        let id: String
        let name: String?
        let topic: String?
        let bucket: Bucket
        let dateKey: String?
        let time: String?
    }
    struct Group: Identifiable, Equatable {
        let id: String
        let label: String?
        let rows: [Row]
    }
    static func row(_ record: MerchantBusinessRecord) -> Row {
        let fields = record.fields
        let occurred = fields.mbText("occurredAt")
        let name = fields.mbText("chapterName") ?? fields.mbText("storeName")
        return Row(id: record.id, name: name, topic: fields.mbText("topicName"),
                   bucket: fields.mbText("fulfillmentState") == "REVERSED" ? .reversed : .verified,
                   dateKey: occurred.flatMap { $0.count >= 10 ? String($0.prefix(10)) : nil },
                   time: occurred.flatMap { $0.count >= 16 ? String($0.dropFirst(11).prefix(5)) : nil })
    }
    static func groups(_ rows: [Row], bucket: Bucket) -> [Group] {
        var order: [String] = [], byKey: [String: [Row]] = [:]
        for row in rows where row.bucket == bucket {
            let key = row.dateKey ?? "unknown"
            if byKey[key] == nil { order.append(key) }
            byKey[key, default: []].append(row)
        }
        return order.map { Group(id: $0, label: $0 == "unknown" ? nil : $0, rows: byKey[$0] ?? []) }
    }
}

/// MC7-04-2 (verify-records/index.js:132-170): append the next finance/redemptions rows when the last row appears.
/// The first read is Core's 50-row `.verificationRecords`; later pages go through the existing 20-row
/// `.redemptions(filter: "all", page:)` read of the same endpoint and permission (merchant:verify:record:read).
/// The first appended page overlaps the 50 rows already shown; rows are de-duplicated by `recordKey`.
@MainActor final class MerchantVerifyRecordsPager: ObservableObject {
    static let pageSize = 20
    @Published private(set) var extra: [MerchantBusinessRecord] = []
    @Published private(set) var loading = false
    @Published private(set) var failed = false
    @Published private(set) var exhausted = false
    private var baseIDs: [String] = []
    @Published private(set) var nextPage = 1
    @Published private(set) var generation = 0
    /// Changes after a reset or an appended page, so a still-visible 正在加载更多… row asks for the next page.
    var loadToken: String { "\(generation)-\(nextPage)" }

    func reset(base: [MerchantBusinessRecord], hasMore: Bool) {
        let ids = base.map(\.id)
        guard ids != baseIDs || generation == 0 else { return }
        generation += 1
        baseIDs = ids
        extra = []; loading = false; failed = false
        exhausted = !hasMore
        nextPage = ids.count / Self.pageSize + 1
    }

    func loadMore(reader: any MerchantBusinessReading, total: Int?) async {
        guard !loading, !exhausted, generation > 0 else { return }
        loading = true; failed = false
        let ticket = generation, page = nextPage
        do {
            let snapshot = try await reader.snapshot(.redemptions(filter: "all", page: page), isCurrent: { [weak self] in
                self?.generation == ticket && !Task.isCancelled
            })
            guard ticket == generation else { return }
            var known = Set(baseIDs + extra.map(\.id))
            let pageRows = snapshot.document.rows.filter { $0.kind == .redemption }
            for row in pageRows where !known.contains(row.id) { extra.append(row); known.insert(row.id) }
            nextPage = page + 1
            let serverTotal = snapshot.document.total ?? total ?? 0
            exhausted = pageRows.count < Self.pageSize || baseIDs.count + extra.count >= serverTotal
        } catch {
            guard ticket == generation else { return }
            failed = !(error is CancellationError)
        }
        if ticket == generation { loading = false }
    }
}

struct MerchantVerifyRecordsSections: View {
    let records: [MerchantBusinessRecord]
    /// Server total; when it exceeds the loaded rows the counts read "n+" (MP `+` when truncated).
    let total: Int?
    /// Core `MerchantVerificationRecordPage.hasMore` for the first page.
    var hasMore: Bool = false
    /// The page's reader, for appending. Nil keeps the first page only.
    var reader: (any MerchantBusinessReading)? = nil
    @State private var bucket: MerchantVerifyRecordsParity.Bucket = .verified
    @StateObject private var pager = MerchantVerifyRecordsPager()
    @Environment(\.locale) private var locale

    private var loaded: [MerchantBusinessRecord] { records + pager.extra }
    private var rows: [MerchantVerifyRecordsParity.Row] {
        loaded.filter { $0.kind == .verification || $0.kind == .redemption }.map(MerchantVerifyRecordsParity.row)
    }
    private var truncated: Bool { (total ?? 0) > loaded.count }
    private var canAppend: Bool { reader != nil && truncated && !pager.exhausted }

    var body: some View {
        let all = rows
        let groups = MerchantVerifyRecordsParity.groups(all, bucket: bucket)
        Section {
            CYTabs(items: MerchantVerifyRecordsParity.Bucket.allCases.map { item in
                let count = all.filter { $0.bucket == item }.count
                let title = appLocalized(String.LocalizationValue("merchant.verifyRecords.tab." + item.rawValue), locale: locale)
                return CYTabItem(id: item, title: "\(title) \(count)\(truncated ? "+" : "")")
            }, selection: $bucket, variant: .chip)
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .accessibilityIdentifier("merchant.verifyRecords.tabs")
            .task(id: records.map(\.id)) { pager.reset(base: records, hasMore: hasMore) }
        }
        if groups.isEmpty {
            Section {
                CYEmptyStateView(systemImage: "checkmark.seal",
                                 title: bucket == .verified ? "merchant.verifyRecords.empty.VERIFIED" : "merchant.verifyRecords.empty.REVERSED")
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                    .accessibilityIdentifier("merchant.verifyRecords.empty")
            }
        } else {
            ForEach(groups) { group in
                Section {
                    ForEach(group.rows) { row in rowView(row) }
                } header: {
                    HStack {
                        if let label = group.label { Text(verbatim: label) } else { Text("merchant.verifyRecords.unknownDay") }
                        Spacer()
                        Text("merchant.verifyRecords.dayTotal \(group.rows.count)")
                    }
                    .cyText(.meta)
                    .foregroundStyle(CYColor.textSecondary)
                }
            }
            // MC7-04-3 (verify-records/index.wxml:81): 正在加载更多… while more pages exist (appends on appear),
            // 已经到底了 once every record is loaded.
            if canAppend, let reader {
                Section {
                    if pager.failed {
                        Button { Task { await pager.loadMore(reader: reader, total: total) } } label: {
                            Text("merchant.gate.reload").frame(maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget)
                        }
                        .accessibilityIdentifier("merchant.verifyRecords.loadMoreRetry")
                    } else {
                        HStack(spacing: CYSpacing.sm) {
                            ProgressView()
                            Text("merchant.list.loadingMore").cyText(.meta).foregroundStyle(CYColor.textSecondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget)
                        .listRowBackground(Color.clear)
                        .task(id: pager.loadToken) { await pager.loadMore(reader: reader, total: total) }
                        .accessibilityIdentifier("merchant.verifyRecords.loadingMore")
                    }
                }
            } else if !truncated || pager.exhausted {
                Section {
                    Text("merchant.list.end")
                        .cyText(.meta)
                        .foregroundStyle(CYColor.textTertiary)
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                        .accessibilityIdentifier("merchant.verifyRecords.listEnd")
                }
            }
        }
    }

    private func rowView(_ row: MerchantVerifyRecordsParity.Row) -> some View {
        HStack(alignment: .top, spacing: CYSpacing.md) {
            Image(systemName: row.bucket == .verified ? "checkmark.circle.fill" : "arrow.uturn.backward.circle")
                .foregroundStyle(row.bucket == .verified ? CYColor.successText : CYColor.textTertiary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                if let name = row.name { Text(verbatim: name).cyText(.bodyMedium).foregroundStyle(CYColor.textPrimary) }
                else { Text("merchant.verifyRecords.defaultName").cyText(.bodyMedium).foregroundStyle(CYColor.textPrimary) }
                if let topic = row.topic { Text(verbatim: topic).cyText(.meta).foregroundStyle(CYColor.textTertiary) }
            }
            Spacer(minLength: CYSpacing.sm)
            VStack(alignment: .trailing, spacing: CYSpacing.xs) {
                CYStatusChip(row.bucket == .verified ? "merchant.verifyRecords.tab.VERIFIED" : "merchant.verifyRecords.tab.REVERSED",
                             tone: row.bucket == .verified ? .success : .neutral)
                Text(verbatim: row.time ?? "—").cyText(.meta).monospacedDigit().foregroundStyle(CYColor.textTertiary)
            }
        }
        .frame(minHeight: CYSpacing.minTouchTarget)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("merchant.verifyRecords.row.\(row.id)")
    }
}
