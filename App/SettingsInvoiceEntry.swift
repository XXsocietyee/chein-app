import SwiftUI

/// Reuses the normal account reader and its original-request recovery.
/// A missing real read approval hides this entry. Invoice writes show only under the G2 player grant.
@MainActor struct SettingsInvoiceEntry: View {
    @ObservedObject var session: AppSession
    var body: some View {
        if let invoice = session.makeInvoiceLaunchPresentation() {
            Section {
                NavigationLink {
                    InvoiceLaunchSessionHistory(session: session, model: invoice)
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

/// FIN-11-7: 我的发票 from 我的 / 设置 keeps a working 登录 when the session lapses on the page
/// (MP invoice/index.wxml:11-12 offers 微信登录).
@MainActor struct InvoiceLaunchSessionHistory: View {
    @ObservedObject var session: AppSession
    let model: InvoiceLaunchPresentation
    @State private var login = false
    var body: some View {
        InvoiceLaunchHistoryView(model: model, onSignIn: { login = true })
            .sheet(isPresented: $login) { Group { LoginView(intent: .player).environmentObject(session) }.presentationDetents([.large]).presentationDragIndicator(.visible) }
            .onChange(of: session.sessionRevision) { _, _ in login = false }
    }
}
