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

/// One section of 申请开票: an opened issuer (`开票单位 · name`) or the trailing 暂不可申请 group (source render()).
struct InvoiceLaunchApplyGroup: Identifiable {
    let id: String
    let issuerID: Int64?
    let name: String
    let orders: [InvoiceLaunchOrder]
    var blocked: Bool { issuerID == nil }

    /// Opened issuers in source order, then every order without an opened issuer in one last group (FIN-13-6).
    static func make(_ orders: [InvoiceLaunchOrder]) -> [InvoiceLaunchApplyGroup] {
        let grouped = InvoiceIssuerSelectionGuard.group(orders: orders)
        var result: [InvoiceLaunchApplyGroup] = grouped.filter(\.isEnabled).map { group in
            let name = group.orders.lazy.compactMap { $0.issuerName?.trimmingCharacters(in: .whitespacesAndNewlines) }.first { !$0.isEmpty }
            return InvoiceLaunchApplyGroup(id: group.id, issuerID: group.issuerID, name: name ?? InvoiceLaunchApplyPage.unknownDisplay, orders: group.orders)
        }
        let blocked = grouped.filter { !$0.isEnabled }.flatMap(\.orders)
        if !blocked.isEmpty { result.append(InvoiceLaunchApplyGroup(id: "blocked", issuerID: nil, name: "", orders: blocked)) }
        return result
    }
}

@MainActor struct InvoiceLaunchApplyView: View {
    @ObservedObject var model: InvoiceLaunchPresentation
    var onSignIn: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.scenePhase) private var scenePhase
    @State private var titleID: Int64?
    @State private var selected = Set<Int64>()
    @State private var choosingTitle = false
    @State private var managingTitles = false
    @State private var addingTitle = false
    @State private var overMax = false
    @State private var toastMessage: LocalizedStringKey?
    @State private var toastTone: CYToastTone = .warning
    private static let maxOrders = 50
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
        model.allows(.apply) && title != nil && !selected.isEmpty && selected.count <= Self.maxOrders && !overMax
            && model.writeNotice == nil
            && selected.isSubset(of: Set(model.overview?.eligibleOrders.map(\.orderId) ?? []))
    }
    /// The issuer the current selection belongs to (source `_issuerId`).
    private var activeIssuer: Int64? {
        model.overview?.eligibleOrders.first { selected.contains($0.orderId) }?.issuerId
    }
    /// Display-only 总计 of the selected orders (source `total`). Never sent: the request carries ids only.
    /// Any selected amount that is not a server literal makes the total unknown ("—").
    private var totalText: String {
        let rows = (model.overview?.eligibleOrders ?? []).filter { selected.contains($0.orderId) }
        var sum = Decimal(0)
        for row in rows {
            guard let value = InvoiceLaunchApplyAmount.from(row.amount).literal else { return InvoiceLaunchApplyPage.unknownDisplay }
            sum += value
        }
        return invoiceAmount(sum, locale: locale)
    }
    var body: some View {
        List {
            InvoiceLaunchStateSection(model: model, sessionTitle: "u9cde.invoice.login.apply", onSignIn: onSignIn, loadFailedKey: "applyLoadFailed")
            if let overview = model.overview, !applyPage.hidden {
                Section {
                    if overview.titles.isEmpty {
                        // Source cy-inline-error 还没有发票抬头 · 新增抬头 (FIN-13-3).
                        VStack(alignment: .leading, spacing: CYSpacing.sm) {
                            invoiceText("noTitles").cyText(.bodyCompact).foregroundStyle(CYColor.textSecondary)
                            if model.allows(.saveTitle) {
                                CYPillButton("addTitle", style: .secondary, fullWidth: false, tableName: "InvoiceLaunchUI") { addingTitle = true }
                                    .accessibilityIdentifier("invoice.apply.addTitle")
                            }
                        }
                    } else {
                        Button { choosingTitle = true } label: {
                            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                                Text(verbatim: title?.titleName ?? InvoiceLaunchApplyPage.unknownDisplay)
                                    .cyText(.cardTitle).foregroundStyle(CYColor.textPrimary).cyWrapText()
                                if let title {
                                    Text(verbatim: invoiceTitleLine(title)).cyText(.meta).foregroundStyle(CYColor.textSecondary)
                                }
                            }
                            .frame(maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(!model.allows(.apply))
                        .accessibilityLabel(invoiceText("chooseTitleSheet"))
                        .accessibilityValue(Text(verbatim: title?.titleName ?? InvoiceLaunchApplyPage.unknownDisplay))
                    }
                } header: { invoiceText("titles") }
                if overview.eligibleOrders.isEmpty {
                    // MP: only `cy-empty title="暂无可开票订单"`, with no section title.
                    Section { invoiceText("noOrders") }
                } else {
                    ForEach(InvoiceLaunchApplyGroup.make(overview.eligibleOrders)) { group in
                        Section {
                            ForEach(group.orders, id: \.orderId) { order in
                                orderRow(order, in: overview.eligibleOrders, group: group)
                            }
                        } header: { groupHeader(group, orders: overview.eligibleOrders) }
                    }
                    // Source 开票金额: 已选订单 N 笔 + 总计 (FIN-13-1).
                    Section {
                        LabeledContent { Text(verbatim: "\(selected.count)").cyText(.numericBody) } label: { invoiceText("selectedCount") }
                        LabeledContent {
                            Text(verbatim: totalText).cyText(.numericBody).monospacedDigit()
                        } label: { invoiceText("total") }
                            .accessibilityIdentifier("invoice.apply.total")
                    } header: { invoiceText("amount") }
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if model.overview != nil, applyPage.showsApplyAction {
                CYFooterBar {
                    VStack(spacing: CYSpacing.sm) {
                        if overMax {
                            // Source 一次最多合并 50 笔订单 · 重新选择 (FIN-13-7).
                            InvoiceLaunchWriteNoticeView(notice: InvoiceLaunchWriteNotice(action: .apply, kind: .tooMany, code: nil), onReselect: reselect)
                        } else if let notice = model.writeNotice, notice.action == .apply {
                            // A refused apply keeps the page and the selection (FIN-13-2).
                            InvoiceLaunchWriteNoticeView(notice: notice, onReselect: reselect)
                        }
                        HStack(spacing: CYSpacing.md) {
                            VStack(alignment: .leading, spacing: 0) {
                                invoiceText("total").cyText(.meta).foregroundStyle(CYColor.textSecondary)
                                Text(verbatim: totalText).cyText(.numericBody).monospacedDigit().foregroundStyle(CYColor.textPrimary)
                            }
                            .accessibilityElement(children: .combine)
                            CYPillButton("submit", style: .primary, tableName: "InvoiceLaunchUI") {
                                guard let titleID, canSubmit else { return }
                                let intent = InvoiceLaunchApplyIntent(titleID: titleID, selected: selected,
                                    identityRevision: model.identityRevision)
                                Task {
                                    if await intent.submit(currentRevision: model.identityRevision, operation: { title, orders in
                                        await model.apply(titleID: title, orderIDs: orders)
                                    }) { dismiss() } else { keepValidSelection() }
                                }
                            }
                            .disabled(!canSubmit).accessibilityIdentifier("invoice.submit")
                        }
                    }
                }
            }
        }
        .cyPushedChrome(domain: .player)
        .cyDomainPageBackground()
        .cyPageTitle(verbatim: invoiceString("apply"))
        .listStyle(.insetGrouped)
        .onChange(of: model.identityRevision) { _, _ in titleID = nil; selected = []; choosingTitle = false; dismiss() }
        .onChange(of: model.overview?.titles) { _, _ in preselectTitle() }
        .onAppear { preselectTitle() }
        .sheet(isPresented: $choosingTitle) {
            titlePicker
                .themeDomain(.player)
                .cySheet()
        }
        .navigationDestination(isPresented: $managingTitles) { InvoiceLaunchTitlesView(model: model, onSignIn: onSignIn) }
        .navigationDestination(isPresented: $addingTitle) { InvoiceLaunchTitleEditor(model: model, title: nil) }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { titleID = nil; selected = []; choosingTitle = false }
            else { preselectTitle() }
        }
        .cyToast(message: $toastMessage, tone: toastTone)
    }

    /// Source picks the default title, else the first one, unless an original request is pending (FIN-13-3).
    private func preselectTitle() {
        guard let titles = model.overview?.titles, !model.unresolved else { return }
        if let titleID, titles.contains(where: { $0.id == titleID }) { return }
        titleID = titles.first(where: \.isDefault)?.id ?? titles.first?.id
    }
    /// Source `reselect`: clear the choice and the notice, then re-read eligible orders.
    private func reselect() {
        selected = []; overMax = false
        model.dismissWriteNotice()
        Task { await model.refresh() }
    }
    /// After a refused submit keep what is still eligible (source `_chosen` filter in loadOrders).
    private func keepValidSelection() {
        let eligible = Set(model.overview?.eligibleOrders.filter { ($0.issuerId ?? 0) > 0 }.map(\.orderId) ?? [])
        selected = selected.intersection(eligible)
    }

    @ViewBuilder private func groupHeader(_ group: InvoiceLaunchApplyGroup, orders: [InvoiceLaunchOrder]) -> some View {
        HStack {
            if group.blocked { invoiceText("blockedGroup") } else { Text("issuerGroup \(group.name)", tableName: "InvoiceLaunchUI") }
            Spacer(minLength: CYSpacing.sm)
            // Source 全选本单位: only for an opened issuer that matches the current selection (FIN-13-4).
            if let issuer = group.issuerID, activeIssuer == nil || activeIssuer == issuer, model.allows(.apply) {
                Button { pickAll(issuer: issuer, orders: orders) } label: { invoiceText("pickAll").cyText(.label) }
                    .buttonStyle(.plain).foregroundStyle(CYColor.brand)
                    .frame(minHeight: CYSpacing.minTouchTarget)
                    .accessibilityIdentifier("invoice.pickAll.\(issuer)")
            }
        }
    }

    private func pickAll(issuer: Int64, orders: [InvoiceLaunchOrder]) {
        if let activeIssuer, activeIssuer != issuer {
            toastTone = .warning
            toastMessage = LocalizedStringKey(MemberPopupCopy.text(InvoiceIssuerSelectionGuard.mixedIssuersMessage, "Orders from different issuers must be applied separately", locale: locale))
            return
        }
        let ids = orders.filter { $0.issuerId == issuer }.map(\.orderId)
        if ids.allSatisfy({ selected.contains($0) }) { selected = []; overMax = false }
        else if ids.count > Self.maxOrders { overMax = true }
        else { selected = Set(ids); overMax = false }
        model.dismissWriteNotice()
    }

    /// Checkbox row (source `aria-role="checkbox"`), dimmed when another issuer or an unopened one blocks it (FIN-13-5).
    private func orderRow(_ order: InvoiceLaunchOrder, in all: [InvoiceLaunchOrder], group: InvoiceLaunchApplyGroup) -> some View {
        let isOn = selected.contains(order.orderId)
        let blocked = group.blocked || (activeIssuer != nil && order.issuerId != activeIssuer)
        return Button { toggle(order, in: all) } label: {
            HStack(alignment: .center, spacing: CYSpacing.md) {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isOn ? CYColor.brand : CYColor.textTertiary)
                    .accessibilityHidden(true)
                Text(verbatim: orderName(order))
                    .cyText(.body).foregroundStyle(CYColor.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                Text(verbatim: applyAmount(order)).cyText(.numericBody).monospacedDigit().foregroundStyle(CYColor.textPrimary)
            }
            .frame(minHeight: CYSpacing.minTouchTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(blocked ? 0.4 : 1)
        // Blocked rows stay tappable so the tap can explain why (source toast).
        .disabled(!model.allows(.apply))
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .accessibilityIdentifier("invoice.select.\(order.orderId)")
    }

    private func toggle(_ order: InvoiceLaunchOrder, in all: [InvoiceLaunchOrder]) {
        if !selected.contains(order.orderId), (order.issuerId ?? 0) > 0, activeIssuer == nil || activeIssuer == order.issuerId,
           selected.count >= Self.maxOrders {
            overMax = true; return
        }
        switch InvoiceIssuerSelectionGuard.toggle(order: order, in: all, currentlySelected: selected) {
        case .updated(let next):
            selected = next; overMax = false
            model.dismissWriteNotice()
        case .rejectedUnenabledIssuer(let msg):
            toastTone = .info
            toastMessage = LocalizedStringKey(MemberPopupCopy.text(msg, "Issuer not enabled for invoicing yet", locale: locale))
        case .rejectedMixedIssuers(let msg):
            toastTone = .warning
            toastMessage = LocalizedStringKey(MemberPopupCopy.text(msg, "Orders from different issuers must be applied separately", locale: locale))
        }
    }

    /// Source `orderTitle · ticketName` (FIN-13-9).
    private func orderName(_ order: InvoiceLaunchOrder) -> String {
        let title = order.orderTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let ticket = order.ticketName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let head = title.isEmpty ? InvoiceLaunchApplyPage.unknownDisplay : title
        return ticket.isEmpty ? head : head + " · " + ticket
    }

    private var titlePicker: some View {
        CYSheetContainer(title: MemberPopupCopy.table("chooseTitleSheet", table: "InvoiceLaunchUI", locale: locale), onClose: { choosingTitle = false }) {
            VStack(spacing: CYSpacing.sm) {
                if (model.overview?.titles ?? []).isEmpty {
                    CYEmptyState(systemImage: "tray", "noTitles", tableName: "InvoiceLaunchUI")
                }
                ForEach(model.overview?.titles ?? [], id: \.id) { candidate in
                    Button {
                        titleID = candidate.id
                        choosingTitle = false
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                                Text(verbatim: candidate.titleName)
                                    .cyText(.body)
                                    .foregroundStyle(CYColor.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text(verbatim: invoiceTitleLine(candidate))
                                    .cyText(.meta).foregroundStyle(CYColor.textSecondary)
                            }
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
                    .accessibilityAddTraits(candidate.id == titleID ? .isSelected : [])
                }
                // Source footer 管理发票抬头 (FIN-13-8).
                CYPillButton("manageTitles", style: .primary, tableName: "InvoiceLaunchUI") {
                    choosingTitle = false; managingTitles = true
                }
                .accessibilityIdentifier("invoice.apply.manageTitles")
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
