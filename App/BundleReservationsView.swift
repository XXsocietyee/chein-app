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
            if order.isLegacy {
                text("order.legacy")
            } else if order.reservations.isEmpty {
                CYEmptyState(systemImage: "calendar", "reservations.empty", tableName: table, messageIdentifier: "bundle.reservations.empty")
            } else {
                Section {
                    ForEach(order.reservations, id: \.id) { row in
                        VStack(alignment: .leading) {
                            if let key = BundleOrderStatusPresentation.reservationStatusKey(row) { text(key).font(.headline) }
                            else { Text(verbatim: row.status).font(.headline) }
                            Text(verbatim: row.startAt).monospacedDigit()
                            Text(verbatim: row.id.text).font(.caption).textSelection(.enabled)
                        }
                    }
                }
            }
        }
        .cyGroupedSurface()
    }
}
