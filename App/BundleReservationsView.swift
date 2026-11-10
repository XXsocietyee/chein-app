import SwiftUI

/// T-10. Rows in the server's order (the server returns them by start time); the client does not re-sort and does
/// not interpret `startAt` against the device clock. Display only: no cancel or reserve control lives here
/// (cancel is IWP-1, reserve is the existing launch flow).
@MainActor struct BundleReservationsView: View {
    let order: BundleOrderReadModel
    private let table = BundleOrderStatusPresentation.table
    private func text(_ key: String) -> Text { Text(LocalizedStringKey(key), tableName: table) }
    var body: some View {
        Form {
            Section { CYHeroHeader(verbatim: W8Text.t("我的预约", "Reservations")) }.e1HeroRow()
            if order.isLegacy {
                text("order.legacy")
            } else if order.reservations.isEmpty {
                CYEmptyState(systemImage: "calendar", "reservations.empty", tableName: table, messageIdentifier: "bundle.reservations.empty")
                    .listRowBackground(Color.clear)
            } else {
                Section {
                    ForEach(order.reservations, id: \.id) { row in
                        HStack(spacing: CYSpacing.md) {
                            CYRowIcon(systemImage: "calendar.badge.clock")
                            VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                                if let key = BundleOrderStatusPresentation.reservationStatusKey(row) { text(key).font(CYTypography.cardTitle) }
                                else { Text(verbatim: row.status).font(CYTypography.cardTitle) }
                                Text(verbatim: row.startAt).font(CYTypography.numericBody)
                                Text(verbatim: row.id.text).font(CYTypography.meta).foregroundStyle(CYColor.textTertiary).textSelection(.enabled)
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .cyGroupedSurface()
        .cyHeroScreen()
    }
}
