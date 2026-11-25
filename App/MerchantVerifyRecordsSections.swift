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

struct MerchantVerifyRecordsSections: View {
    let records: [MerchantBusinessRecord]
    /// Server total; when it exceeds the loaded rows the counts read "n+" (MP `+` when truncated).
    let total: Int?
    /// Called when the loaded page is still short of `total`. Nil keeps the first page as it is.
    var onNeedMore: (() -> Void)? = nil
    var loadingMore = false
    /// MC7-04-3 (round 3 re-apply): the last append failed; the footer becomes 重新加载.
    var loadFailed = false
    var onRetry: (() -> Void)? = nil
    /// No further page exists even though `total` says otherwise (server stopped short).
    var exhausted = false
    @State private var bucket: MerchantVerifyRecordsParity.Bucket = .verified
    @Environment(\.locale) private var locale

    private var rows: [MerchantVerifyRecordsParity.Row] { records.filter { $0.kind == .verification }.map(MerchantVerifyRecordsParity.row) }
    private var truncated: Bool { (total ?? 0) > records.count }

    var body: some View {
        let all = rows
        let groups = MerchantVerifyRecordsParity.groups(all, bucket: bucket)
        MerchantDeskManualCodeRow()
        Section {
            CYTabs(items: MerchantVerifyRecordsParity.Bucket.allCases.map { item in
                let count = all.filter { $0.bucket == item }.count
                let title = appLocalized(String.LocalizationValue("merchant.verifyRecords.tab." + item.rawValue), locale: locale)
                return CYTabItem(id: item, title: "\(title) \(count)\(truncated ? "+" : "")")
            }, selection: $bucket, variant: .chip)
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .accessibilityIdentifier("merchant.verifyRecords.tabs")
        }
        if groups.isEmpty {
            Section {
                CYEmptyState(systemImage: "tray",
                             bucket == .verified ? "merchant.verifyRecords.empty.VERIFIED" : "merchant.verifyRecords.empty.REVERSED")
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
            // MC7-04-3: a full page still short of total asks for the next `MerchantVerificationRecordPage`.
            // Stop when that page says there is nothing further. 已经到底了 once every record is loaded.
            if loadFailed, let onRetry {
                Section {
                    Button(action: onRetry) {
                        Text("merchant.gate.reload").frame(maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget)
                    }
                    .accessibilityIdentifier("merchant.verifyRecords.loadMoreRetry")
                }
            } else if truncated, !exhausted, let onNeedMore {
                Section {
                    HStack(spacing: CYSpacing.sm) {
                        ProgressView()
                        Text("merchant.list.loadingMore").cyText(.meta).foregroundStyle(CYColor.textSecondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget)
                    .listRowBackground(Color.clear)
                    // Re-asks after each appended page while the row stays visible (onAppear fires only once).
                    .task(id: records.count) { if !loadingMore { onNeedMore() } }
                    .accessibilityIdentifier("merchant.verifyRecords.loadingMore")
                }
            } else if !truncated || exhausted {
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

/// Appends verify-records pages. Page 1 is the snapshot from `.verificationRecords`. Later pages use
/// `verificationPage`. A reader that has not implemented paging leaves the first page in place.
@MainActor struct MerchantVerificationAppendList: View {
    let reader: any MerchantBusinessReading
    let snapshot: MerchantBusinessSnapshot
    @State private var extra: [MerchantBusinessRecord] = []
    @State private var page = 1
    @State private var hasMore: Bool
    @State private var loading = false
    @State private var stopped = false
    @State private var failed = false

    init(reader: any MerchantBusinessReading, snapshot: MerchantBusinessSnapshot) {
        self.reader = reader
        self.snapshot = snapshot
        _hasMore = State(initialValue: snapshot.document.hasMore)
    }

    private var records: [MerchantBusinessRecord] { snapshot.document.rows + extra }

    var body: some View {
        MerchantVerifyRecordsSections(records: records, total: snapshot.document.total,
                                      onNeedMore: hasMore && !stopped ? { Task { await more() } } : nil,
                                      loadingMore: loading,
                                      loadFailed: failed,
                                      onRetry: { failed = false; Task { await more() } },
                                      exhausted: !hasMore)
            .onChange(of: snapshot) { _, next in
                extra = []; page = 1; stopped = false; failed = false; loading = false; hasMore = next.document.hasMore
            }
    }

    private func more() async {
        guard hasMore, !loading, !stopped else { return }
        loading = true
        failed = false
        defer { loading = false }
        let next = page + 1
        do {
            let loaded = try await reader.verificationPage(next)
            let known = Set(records.map(\.id))
            extra += loaded.document.rows.filter { !known.contains($0.id) }
            page = next
            let collected = snapshot.document.rows.count + extra.count
            let total = loaded.document.total ?? snapshot.document.total ?? 0
            hasMore = MerchantVerificationRecordPage.hasMore(pageRowCount: loaded.document.rows.count, collected: collected, total: total)
        } catch let failure as MerchantBusinessFailure where failure == .disabled {
            stopped = true
            hasMore = false
        } catch is CancellationError {
            // Left the screen; the row asks again when it reappears.
        } catch {
            // Round 3 re-apply of MC7-04-3: a transient failure offers 重新加载 instead of silently stopping.
            failed = true
        }
    }
}

/// Classify-only manual code. The client is constructed with the gate off, so a valid code does not redeem.
struct MerchantDeskManualCodeAction {
    var resolve: @MainActor (String) async throws -> MerchantDeskManualRoute
}

private struct MerchantDeskManualCodeActionKey: EnvironmentKey {
    static let defaultValue: MerchantDeskManualCodeAction? = nil
}

extension EnvironmentValues {
    var merchantDeskManualCode: MerchantDeskManualCodeAction? {
        get { self[MerchantDeskManualCodeActionKey.self] }
        set { self[MerchantDeskManualCodeActionKey.self] = newValue }
    }
}

private struct MerchantDeskManualCodeRow: View {
    @Environment(\.merchantDeskManualCode) private var action
    @State private var code = ""
    @State private var note: String?

    var body: some View {
        if action != nil {
            Section {
                TextField(text: $code) { Text(verbatim: "核销码").cyText(.body) }
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("merchant.desk.manualCode")
                Button { Task { await submit() } } label: {
                    Text(verbatim: "识别核销码").cyText(.body).frame(maxWidth: .infinity, alignment: .leading)
                }
                .accessibilityIdentifier("merchant.desk.manualCode.classify")
                if let note {
                    Text(verbatim: note).cyText(.meta).foregroundStyle(CYColor.textSecondary)
                        .accessibilityIdentifier("merchant.desk.manualCode.note")
                }
            }
        }
    }

    private func submit() async {
        if let error = MerchantDeskManualCode.validationError(code) { note = error; return }
        guard let action else { return }
        do {
            switch try await action.resolve(code) {
            case .rejected(let message): note = message
            case .redirect(let message, _): note = message
            case .route: note = "已识别，未提交核销"
            }
        } catch let failure as MerchantBusinessFailure where failure == .disabled {
            note = "手动核销未开启"
        } catch {
            note = "未能识别核销码，请重试"
        }
    }
}
