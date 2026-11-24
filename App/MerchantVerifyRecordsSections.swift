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
    @State private var bucket: MerchantVerifyRecordsParity.Bucket = .verified
    @Environment(\.locale) private var locale

    private var rows: [MerchantVerifyRecordsParity.Row] { records.filter { $0.kind == .verification }.map(MerchantVerifyRecordsParity.row) }
    private var truncated: Bool { (total ?? 0) > records.count }

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
