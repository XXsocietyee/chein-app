import SwiftUI

/// Player entry beside the search map. It renders `SideQuestPlayerFlow` and does not open a page,
/// add a marker, or send an accept. Production passes the closed snapshot, whose count is an em dash.
struct SideQuestPlayerEntry: View {
    var snapshot = SideQuestPlayerFlow.production

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            Text("mapCore.entry.merchantSideQuests", tableName: "MapCoreEntry")
                .font(CYTypography.cardTitle)
                .foregroundStyle(CYColor.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Text("mapCore.availability.pendingBackend", tableName: "MapCoreEntry")
                .font(CYTypography.meta)
                .foregroundStyle(CYColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(verbatim: snapshot.totalText)
                .font(CYTypography.meta)
                .foregroundStyle(CYColor.textSecondary)
                .accessibilityIdentifier("sideQuestPlayer.total")
            ForEach(snapshot.rows) { row in
                rowBody(row)
            }
        }
        .frame(maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("sideQuestPlayer.entry")
    }

    private func rowBody(_ row: SideQuestPlayerFlow.RowPresentation) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.xxs) {
            Text(verbatim: row.titleText)
                .font(CYTypography.body)
                .foregroundStyle(CYColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text(verbatim: row.capacityText)
                .font(CYTypography.meta)
                .foregroundStyle(CYColor.textSecondary)
            Text(verbatim: row.rewardText)
                .font(CYTypography.meta)
                .foregroundStyle(CYColor.textSecondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("sideQuestPlayer.row.\(row.id)")
    }
}
