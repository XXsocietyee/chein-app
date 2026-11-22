import SwiftUI

/// Player entry beside the search map. It renders `SideQuestPlayerFlow` and does not open a page,
/// add a marker, or send an accept. Production passes the closed snapshot, whose count is an em dash.
struct SideQuestPlayerEntry: View {
    var snapshot = SideQuestPlayerFlow.production

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            Text("mapCore.entry.merchantSideQuests", tableName: "MapCoreEntry")
                .cyText(.cardTitle)
                .foregroundStyle(CYColor.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Text("mapCore.availability.pendingBackend", tableName: "MapCoreEntry")
                .cyText(.meta)
                .foregroundStyle(CYColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(verbatim: snapshot.totalText)
                .cyText(.meta)
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
                .cyText(.body)
                .foregroundStyle(CYColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text(verbatim: row.capacityText)
                .cyText(.meta)
                .foregroundStyle(CYColor.textSecondary)
            Text(verbatim: row.rewardText)
                .cyText(.meta)
                .foregroundStyle(CYColor.textSecondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("sideQuestPlayer.row.\(row.id)")
    }
}
