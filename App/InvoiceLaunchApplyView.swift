import SwiftUI

/// Captures the selected original inputs on the submit tap, before queuing a task.
/// This is not a permission or receipt; the presentation/service still authorize and journal.
struct InvoiceLaunchApplyIntent {
    let titleID: Int64
    let orderIDs: [Int64]
    let identityRevision: UUID
    init(titleID: Int64, selected: Set<Int64>, identityRevision: UUID) {
        self.titleID = titleID; orderIDs = selected.sorted(); self.identityRevision = identityRevision
    }
    @MainActor func submit(currentRevision: UUID,
                           operation: (Int64, [Int64]) async -> Bool) async -> Bool {
        guard !Task.isCancelled, currentRevision == identityRevision else { return false }
        return await operation(titleID, orderIDs)
    }
}

@MainActor struct InvoiceLaunchApplyView: View {
    @ObservedObject var model: InvoiceLaunchPresentation
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.scenePhase) private var scenePhase
    @State private var titleID: Int64?
    @State private var selected = Set<Int64>()
    @State private var choosingTitle = false
    @State private var toastMessage: LocalizedStringKey?
    @State private var toastTone: CYToastTone = .warning
    private var title: InvoiceLaunchTitle? { model.overview?.titles.first { $0.id == titleID } }
    /// Host switches only. A missing read stays hidden. Apply stays off unless the existing permit is on.
    private var applyPage: InvoiceLaunchApplyPage {
        let capability = InvoiceLaunchApplyCapability(readsEnabled: model.overview != nil || model.busy, mutationsEnabled: model.allows(.apply))
        guard let overview = model.overview else {
            return model.busy ? .loading(capability: capability) : .hidden()
        }
        return InvoiceLaunchApplyPage.project(titles: overview.titles, orders: overview.eligibleOrders, unresolved: model.unresolved, capability: capability)
    }
    private var canSubmit: Bool {
        model.allows(.apply) && title != nil && !selected.isEmpty && selected.count <= 50
            && selected.isSubset(of: Set(model.overview?.eligibleOrders.map(\.orderId) ?? []))
    }
    var body: some View {
        List {
            InvoiceLaunchStateSection(model: model, sessionTitle: "u9cde.invoice.login.apply")
            if let overview = model.overview, !applyPage.hidden {
                Section {
                    Button { choosingTitle = true } label: {
                        LabeledContent { Text(verbatim: title?.titleName ?? "—") } label: { invoiceText("chooseTitle") }
                    }.disabled(!model.allows(.apply))
                } header: { invoiceText("titles") }
                if overview.eligibleOrders.isEmpty {
                    Section { invoiceText("noOrders") } header: { invoiceText("orders") }
                } else {
                    ForEach(InvoiceIssuerSelectionGuard.group(orders: overview.eligibleOrders)) { group in
                        Section {
                            ForEach(group.orders, id: \.orderId) { order in
                                Toggle(isOn: Binding(
                                    get: { selected.contains(order.orderId) },
                                    set: { _ in
                                        switch InvoiceIssuerSelectionGuard.toggle(
                                            order: order,
                                            in: overview.eligibleOrders,
                                            currentlySelected: selected
                                        ) {
                                        case .updated(let next):
                                            selected = next
                                        case .rejectedUnenabledIssuer(let msg):
                                            toastTone = .info
                                            toastMessage = LocalizedStringKey(MemberPopupCopy.text(msg, "Issuer not enabled for invoicing yet", locale: locale))
                                        case .rejectedMixedIssuers(let msg):
                                            toastTone = .warning
                                            toastMessage = LocalizedStringKey(MemberPopupCopy.text(msg, "Orders from different issuers must be applied separately", locale: locale))
                                        }
                                    }
                                )) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(verbatim: order.orderTitle ?? InvoiceLaunchApplyPage.unknownDisplay)
                                        Text(verbatim: applyAmount(order))
                                    }
                                }
                                .disabled(!model.allows(.apply) || (!selected.contains(order.orderId) && selected.count >= 50))
                                .accessibilityIdentifier("invoice.select.\(order.orderId)")
                            }
                        } header: {
                            Text(verbatim: group.issuerTitle)
                        }
                    }
                }
                LabeledContent { Text(selected.count, format: .number) } label: { invoiceText("selectedCount") }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if model.overview != nil, applyPage.showsApplyAction {
                CYFooterBar {
                    CYPillButton("submit", style: .primary, tableName: "InvoiceLaunchUI") {
                        guard let titleID, canSubmit else { return }
                        let intent = InvoiceLaunchApplyIntent(titleID: titleID, selected: selected,
                            identityRevision: model.identityRevision)
                        Task {
                            if await intent.submit(currentRevision: model.identityRevision, operation: { title, orders in
                                await model.apply(titleID: title, orderIDs: orders)
                            }) { dismiss() }
                        }
                    }
                    .disabled(!canSubmit).accessibilityIdentifier("invoice.submit")
                }
            }
        }
        .cyPushedChrome(domain: .player)
        .cyDomainPageBackground()
        .navigationTitle(invoiceText("apply")).listStyle(.insetGrouped)
        .onChange(of: model.identityRevision) { _, _ in titleID = nil; selected = []; choosingTitle = false; dismiss() }
        .sheet(isPresented: $choosingTitle) {
            titlePicker
                .cyPlayerSheetGlass()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { titleID = nil; selected = []; choosingTitle = false }
        }
        .cyToast(message: $toastMessage, tone: toastTone)
    }
    private var titlePicker: some View {
        CYSheetContainer(title: MemberPopupCopy.table("chooseTitle", table: "InvoiceLaunchUI", locale: locale), onClose: { choosingTitle = false }) {
            VStack(spacing: CYSpacing.sm) {
                ForEach(model.overview?.titles ?? [], id: \.id) { candidate in
                    Button {
                        titleID = candidate.id
                        choosingTitle = false
                    } label: {
                        HStack {
                            Text(verbatim: candidate.titleName)
                                .font(CYTypography.body)
                                .foregroundStyle(CYColor.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: CYSpacing.sm)
                            if candidate.id == titleID {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(CYColor.brand)
                            }
                        }
                        .padding(CYSpacing.md)
                        .frame(maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget, alignment: .leading)
                        .background(CYColor.sheetCard, in: RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(!model.allows(.apply))
                }
            }
            .padding(.bottom, CYSpacing.lg)
        }
        .cyDomainSheet(detents: [.half, .full])
    }
    private func applyAmount(_ order: InvoiceLaunchOrder) -> String {
        let line = applyPage.lines.first { $0.orderID == order.orderId }
        if line?.amount.literal == nil { return line?.amount.displayText ?? InvoiceLaunchApplyPage.unknownDisplay }
        return invoiceAmount(order.amount, locale: locale)
    }
}
