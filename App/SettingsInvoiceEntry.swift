import SwiftUI

/// Reuses the normal account reader and its original-request recovery.
/// A missing real read approval hides this entry. Invoice writes show only under the G2 player grant.
@MainActor struct SettingsInvoiceEntry: View {
    @ObservedObject var session: AppSession
    var body: some View {
        if let invoice = session.makeInvoiceLaunchPresentation() {
            Section {
                NavigationLink {
                    InvoiceLaunchHistoryView(model: invoice)
                } label: {
                    Label { invoiceText("history") } icon: {
                        Image(systemName: "doc.text").accessibilityHidden(true)
                    }
                }
                .accessibilityIdentifier("settings.invoices")
                orderCenterLink
            }
        } else {
            Section { orderCenterLink }
        }
    }
    /// G2 order center lookup, shown only when the player grant carries `api/order-center/detail`.
    @ViewBuilder private var orderCenterLink: some View {
        if let service = CreatorEditorProduction.orderCenter(session: session) {
            NavigationLink { OrderCenterEntryView(model: OrderCenterEntryModel(service: service)) } label: {
                Label { Text("orderCenter.navigation", tableName: "CreatorEditorUI") } icon: {
                    Image(systemName: "list.bullet.rectangle").accessibilityHidden(true)
                }
            }
            .accessibilityIdentifier("settings.orderCenter")
        }
    }
}
