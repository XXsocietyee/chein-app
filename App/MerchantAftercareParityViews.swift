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
                Text(verbatim: row.title).font(CYTypography.bodyMedium).foregroundStyle(CYColor.textPrimary)
                metadataLayout {
                    if let time = row.timeText { Text(verbatim: time + " ·").monospacedDigit().foregroundStyle(CYColor.textSecondary) }
                    Text(verbatim: MerchantOpsCopy.text(row.statusKey)).foregroundStyle(toneColor)
                    if row.isTakenOver { Text(verbatim: "· " + MerchantOpsCopy.text("merchantOps.aftercare.takenOver")).foregroundStyle(CYColor.textSecondary) }
                }.font(CYTypography.meta)
                if let activity = row.activityTitle { Text(verbatim: activity).font(CYTypography.caption).foregroundStyle(CYColor.textSecondary) }
            }
            if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: CYSpacing.sm) }
            if let amount = row.amountDisplay { Text(verbatim: amount).font(CYTypography.numericBody).monospacedDigit().foregroundStyle(CYColor.textPrimary) }
            else { Text(verbatim: MerchantOpsCopy.text("merchantOps.aftercare.amountPending")).font(CYTypography.caption).foregroundStyle(CYColor.textSecondary) }
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
            Text(verbatim: Self.label(group.label)).font(CYTypography.label)
            if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: CYSpacing.sm) }
            if let total = group.total { Text(verbatim: total).font(CYTypography.numericBody).monospacedDigit() }
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
            .font(CYTypography.meta).foregroundStyle(CYColor.textTertiary).accessibilityIdentifier("merchantOps.aftercare.readOnly")
    }
}
