import SwiftUI

/// Source pages/merchant/aftercare/index.wxml list row: title, "HH:mm · status", takeover tag,
/// activity line and right-aligned amount (muted "amount to be confirmed" when unknown).
struct MerchantAftercareRowLabel: View {
    let row: MerchantAftercareParity.ListRow
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private var toneColor: Color {
        switch row.tone { case .warning: return CYColor.warningText; case .success: return CYColor.successText; case .danger: return CYColor.dangerText; case .neutral: return CYColor.textTertiary }
    }
    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: CYSpacing.sm))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline))
        let metadataLayout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: CYSpacing.xs))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: CYSpacing.xs))
        layout {
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                Text(verbatim: row.isManualCase ? MerchantOpsCopy.text("merchantOps.aftercare.manualCase.title") + " " + row.title : row.title)
                    .cyText(.bodyMedium).foregroundStyle(CYColor.textPrimary)
                metadataLayout {
                    if let time = row.timeText { Text(verbatim: time + " ·").monospacedDigit().foregroundStyle(CYColor.textSecondary) }
                    Text(verbatim: MerchantOpsCopy.text(row.statusKey)).foregroundStyle(toneColor)
                    if row.isTakenOver { Text(verbatim: "· " + MerchantOpsCopy.text("merchantOps.aftercare.takenOver")).foregroundStyle(CYColor.textSecondary) }
                }.cyText(.meta)
                if let activity = row.activityTitle { Text(verbatim: activity).cyText(.meta).foregroundStyle(CYColor.textSecondary) }
            }
            if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: CYSpacing.sm) }
            if row.isManualCase { EmptyView() }
            else if let amount = row.amountDisplay { Text(verbatim: amount).cyText(.numericBody).monospacedDigit().foregroundStyle(CYColor.textPrimary) }
            else { Text(verbatim: MerchantOpsCopy.text("merchantOps.aftercare.amountPending")).cyText(.meta).foregroundStyle(CYColor.textSecondary) }
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("merchantOps.aftercare.row.\(row.id)")
    }
}

/// Day header with an optional total, shown above the first row of each request day.
struct MerchantAftercareDayHeader: View {
    let group: MerchantAftercareParity.DayGroup
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: CYSpacing.xs))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline))
        layout {
            Text(verbatim: Self.label(group.label)).cyText(.label)
            if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: CYSpacing.sm) }
            if let total = group.total { Text(verbatim: total).cyText(.numericBody).monospacedDigit() }
        }.foregroundStyle(CYColor.textSecondary).accessibilityIdentifier("merchantOps.aftercare.day.\(group.id)")
    }
    static func label(_ label: MerchantAftercareParity.DayLabel) -> String {
        switch label {
        case .today: return MerchantOpsCopy.text("merchantOps.aftercare.day.today")
        case .yesterday: return MerchantOpsCopy.text("merchantOps.aftercare.day.yesterday")
        case .sameYear(let month, let day): return MerchantOpsCopy.text("merchantOps.aftercare.day.monthDay %lld %lld", month, day)
        case .otherYear(let year, let month, let day): return MerchantOpsCopy.text("merchantOps.aftercare.day.yearMonthDay %lld %lld %lld", year, month, day)
        case .unknown: return MerchantOpsCopy.text("merchantOps.aftercare.day.unknown")
        }
    }
}

/// Source detail/index.js read-only line when the respond pills are hidden.
struct MerchantAftercareReadOnlyNote: View {
    let reason: MerchantAftercareParity.ReadOnlyReason
    var body: some View {
        Text(verbatim: MerchantOpsCopy.text(reason == .roleViewOnly ? "merchantOps.aftercare.readOnly.role" : "merchantOps.aftercare.readOnly.closed"))
            .cyText(.meta).foregroundStyle(CYColor.textTertiary).accessibilityIdentifier("merchantOps.aftercare.readOnly")
    }
}

/// Source pages/merchant/aftercare/detail (recordType=MANUAL_CASE): a read-only 人工退款工单 with the platform's
/// status and a two-step timeline. No amount and no merchant decision (the platform handles the refund).
struct MerchantManualCaseDetailView: View {
    let row: MerchantAftercareParity.ListRow
    private var completed: Bool { row.tone == .neutral }
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: CYSpacing.sm) {
                    Text(verbatim: MerchantOpsCopy.text("merchantOps.aftercare.manualCase.title") + " " + row.title)
                        .cyText(.cardTitle).foregroundStyle(CYColor.textPrimary)
                    CYStatusChip(verbatim: MerchantOpsCopy.text(row.statusKey), tone: completed ? .neutral : .warning)
                    Text(verbatim: MerchantOpsCopy.text("merchantOps.aftercare.manualCase.note"))
                        .cyText(.meta).foregroundStyle(CYColor.textSecondary)
                }
                .padding(.vertical, CYSpacing.xs)
                if let activity = row.activityTitle {
                    LabeledContent { Text(verbatim: activity) } label: { Text(verbatim: MerchantOpsCopy.text("merchantOps.aftercare.manualCase.activity")) }
                        .cyText(.body)
                }
            }
            Section {
                timelineNode(title: MerchantOpsCopy.text("merchantOps.aftercare.manualCase.requested"),
                             time: [row.dayKey, row.timeText].compactMap { $0 }.joined(separator: " "), done: true)
                timelineNode(title: MerchantOpsCopy.text(row.statusKey), time: nil, done: completed)
            } header: { Text(verbatim: MerchantOpsCopy.text("merchantOps.aftercare.manualCase.progress")) }
        }
        .navigationTitle(Text(verbatim: MerchantOpsCopy.text("merchantOps.aftercare.manualCase.title")))
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("merchantOps.aftercare.manualCase.\(row.id)")
    }
    private func timelineNode(title: String, time: String?, done: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: CYSpacing.md) {
            Image(systemName: done ? "checkmark.circle.fill" : "clock")
                .foregroundStyle(done ? CYColor.successText : CYColor.warningText)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                Text(verbatim: title).cyText(.body).foregroundStyle(CYColor.textPrimary)
                if let time, !time.isEmpty { Text(verbatim: time).cyText(.meta).monospacedDigit().foregroundStyle(CYColor.textTertiary) }
            }
        }
        .accessibilityElement(children: .combine)
    }
}
