import SwiftUI

@MainActor final class CouponManagementScreenModel: ObservableObject {
    let core: CouponManagementCoordinator
    @Published var revision = 0
    @Published var working = false
    private var operationID: UUID?
    init(_ core: CouponManagementCoordinator) { self.core = core }
    func update(_ value: CouponManagementDraft) { core.change(value); revision += 1 }
    func run(_ work: @escaping () async -> Void) {
        guard !working else { return }
        let id = UUID(); operationID = id; working = true
        Task { await work(); guard operationID == id else { return }; working = false; revision += 1 }
    }
    func cancelReview() { operationID = nil; core.cancelReview(); working = false; revision += 1 }
    func synchronize() { operationID = nil; core.synchronize(); working = false; revision += 1 }
}
/// Add only at the existing merchant published-coupon entry. The host owns feature visibility.
@MainActor struct CouponManagementView: View {
    @Environment(\.locale) private var locale
    @StateObject private var model: CouponManagementScreenModel
    let sessionKey: CouponManagementSession?
    let isSourceVisible: Bool
    /// R7-MEM-10-1: `coupon/coupon?scope=MERCHANT` (merchant marketing) lists the shop's coupons; the bare page is the player's own list.
    let scope: CouponPublishListScope
    /// MKT-10-5 (MP `merchant-no-permission.js`): a merchant member gets 返回 on the refused state; anyone else gets 申请入驻.
    let isMerchantMember: Bool
    /// MKT-10-1: the merchant-scope 累计领取 / 累计核销 read. Nil (fixtures, player scope) shows no tiles.
    let loadSummary: (@MainActor () async -> MerchantCouponSummary?)?
    @State private var creating = false
    @State private var summary: MerchantCouponSummary?
    @State private var applyingMerchant = false
    @State private var detailItem: CouponManagementDetailItem?
    @Environment(\.dismiss) private var dismiss
    init(coordinator: CouponManagementCoordinator, sessionKey: CouponManagementSession?, isSourceVisible: Bool = false,
         scope: CouponPublishListScope = .merchant, isMerchantMember: Bool? = nil,
         loadSummary: (@MainActor () async -> MerchantCouponSummary?)? = nil) {
        _model = StateObject(wrappedValue: CouponManagementScreenModel(coordinator)); self.sessionKey = sessionKey; self.isSourceVisible = isSourceVisible
        self.scope = scope
        // MP `coupon.js:117`: the merchant scope counts as a merchant view.
        self.isMerchantMember = scope == .merchant || (isMerchantMember ?? false)
        self.loadSummary = scope == .merchant ? loadSummary : nil
    }
    var body: some View {
        Group {
            if !isSourceVisible { ContentUnavailableView("couponManagement.unavailable", systemImage: "ticket") }
            else if sessionKey == nil { ContentUnavailableView("couponManagement.signIn", systemImage: "person.crop.circle") }
            // MKT-10-5: a refused read is the MP no-permission state with one way out (coupon.wxml:10): 返回 for a
            // merchant member, 申请入驻 (`/pages/merchant/apply/index`) for anyone else.
            else if model.core.issue == .forbidden, model.core.rows.isEmpty, !model.core.loading, !model.working {
                ContentUnavailableView {
                    Label("couponManagement.denied", systemImage: "exclamationmark.triangle")
                } actions: {
                    Button(denyAction.title, action: denyAction.action)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .accessibilityIdentifier("couponManagement" + (isMerchantMember ? ".denied.back" : ".denied.apply"))
                }
                .accessibilityIdentifier("couponManagement.denied")
            }
            else {
                List {
                    CouponManagementNotice(model: model, surface: .list)
                    if model.core.canRecoverCommands {
                        Button("couponManagement.checkPendingResults") { model.run { await model.core.recoverPendingCommands() } }
                            .disabled(model.working).accessibilityIdentifier("couponManagement.recover")
                    }
                    Text("couponManagement.chinaTime").font(.footnote).foregroundStyle(.secondary)
                    // MKT-10-1 (BL-77): 累计领取 / 累计核销, merchant scope only; hidden with no coupons or a failed read.
                    if let summary {
                        MerchantCouponSummaryTilesView(summary: summary)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                            .accessibilityElement(children: .combine)
                            .accessibilityIdentifier("couponManagement.summary")
                    }
                    if model.working || model.core.loading { CYLoadingState() }
                    // A failed read is an error notice above, not an empty list.
                    else if model.core.rows.isEmpty, model.core.issue == nil {
                        ContentUnavailableView("couponManagement.empty", systemImage: "tray")
                    }
                    ForEach(model.core.rows) { row in
                        // MKT-10-3: MP coupon/coupon.wxml:46 opens 优惠券详情 in a `cy-sheet`, not a page.
                        Button {
                            detailItem = CouponManagementDetailItem(id: row.id)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(row.name ?? appLocalized("couponManagement.coupon", locale: locale))
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text(LocalizedStringKey(row.typeKey))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                // Mini-program coupon list row: description (fallback copy) and remaining stock.
                                if let text = row.description, !text.isEmpty {
                                    Text(verbatim: text).font(.subheadline).foregroundStyle(.primary)
                                } else {
                                    Text("couponManagement.noDescription").font(.subheadline).foregroundStyle(.secondary)
                                }
                                // Unknown remaining stock is an em dash; a literal 0 stays 0.
                                LabeledContent("couponManagement.remaining", value: CouponInfoCount.display(row.remaining))
                                    .font(.subheadline).monospacedDigit()
                                if row.state != .active {
                                    Label {
                                        Text(LocalizedStringKey(row.state.key))
                                    } icon: {
                                        Image(systemName: row.state == .invalidated || row.state == .stopped ? "xmark.circle.fill" : "minus.circle.fill")
                                            .foregroundStyle(row.state == .invalidated || row.state == .stopped ? Color.red : Color.secondary)
                                    }
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                }
                                Text("\(CouponValidityTime.display(row.startTime) ?? "—") – \(CouponValidityTime.display(row.endTime) ?? "—")")
                                    .font(.footnote)
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .foregroundStyle(.primary)
                        .accessibilityIdentifier("couponManagement.definition.\(row.id.value)")
                    }
                }
                .refreshable {
                    model.core.publishListScope = scope; await model.core.load(); model.revision += 1
                    await refreshSummary()
                }
                .toolbar {
                    // Hidden, not disabled, when publishing is not available for this account.
                    if model.core.canReviewPublish {
                        ToolbarItem(placement: .primaryAction) {
                            Button { creating = true } label: { Label("couponManagement.create", systemImage: "plus") }
                                .disabled(model.working).accessibilityIdentifier("couponManagement.create")
                        }
                    }
                }
            }
        }
        .merchantM02Page()
        // R8-MEM-10-2: MP coupon.js:115-121, theme-merchant only for a merchant view; the player's own list is dark.
        .themeDomain(isMerchantMember ? .merchant : .player)
        .cyPageTitle("couponManagement.title")
        .task(id: sessionKey) {
            model.synchronize(); creating = false
            model.core.publishListScope = scope
            summary = nil
            if isSourceVisible, sessionKey != nil {
                await model.core.load(); model.revision += 1
                await refreshSummary()
            }
        }
        .navigationDestination(isPresented: $applyingMerchant) {
            MPReviewedPageScreen(page: "pages/merchant/apply/index", query: [:])
        }
        .cySheet(item: $detailItem) { item in
            NavigationStack {
                CouponManagementDetailView(model: model, id: item.id, scope: scope)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("action.done") { detailItem = nil }
                                .accessibilityIdentifier("couponManagement.detail.done")
                        }
                    }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .cySheet(isPresented: $creating) {
            NavigationStack { CouponManagementEditor(model: model) }
                .themeDomain(.topicEditor)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .onChange(of: sessionKey) { _, _ in creating = false; detailItem = nil; model.synchronize() }
        .onChange(of: isSourceVisible) { _, visible in if !visible { creating = false; detailItem = nil; model.core.leave(); model.revision += 1 } }
    }
}
extension CouponManagementView {
    fileprivate var denyAction: (title: LocalizedStringKey, action: () -> Void) {
        // Lane G: 申请成为商家 is hidden in Release, so a player gets 返回 here too.
        if isMerchantMember || !PlayerLaunch.merchantCenterEnabled { return (title: LocalizedStringKey("couponManagement.back"), action: { dismiss() }) }
        return (title: LocalizedStringKey("couponManagement.forbidden.applyMerchant"), action: { applyingMerchant = true })
    }
    /// MP `loadSummary`: silent, merchant scope only, never blocks the list. A stale reply is dropped.
    fileprivate func refreshSummary() async {
        guard let loadSummary else { summary = nil; return }
        let key = sessionKey
        let value = await loadSummary()
        guard key == sessionKey, !Task.isCancelled else { return }
        summary = value
    }
}
private enum CouponManagementNoticeSurface: String { case list, detail, editor }
@MainActor private struct CouponManagementNotice: View {
    @ObservedObject var model: CouponManagementScreenModel
    let surface: CouponManagementNoticeSurface
    var body: some View {
        Section {
            if model.core.canSimulate { Text("couponManagement.synthetic").font(.subheadline).foregroundStyle(.secondary) }
            if model.core.recoveryFinished { Text("couponManagement.recoveryFinished") }
            if let issue = model.core.issue { Text(LocalizedStringKey(issue.messageKey)).accessibilityIdentifier("couponManagement.notice.\(surface.rawValue).issue") }
            if let issue = model.core.issue, case .server(let message) = issue { Text(message) }
            if let message = model.core.serverMessage { Text(message).accessibilityIdentifier("couponManagement.notice.\(surface.rawValue).serverMessage") }
            if model.core.simulated { Text("couponManagement.simulated") }
            if model.core.acknowledged {
                Text(LocalizedStringKey(model.core.verifiedRecord == nil ? "couponManagement.readbackPending" : "couponManagement.readbackVerified"))
                    .accessibilityIdentifier("couponManagement.notice.\(surface.rawValue).readback")
            }
        }
    }
}
/// MKT-10-3: the coupon the 优惠券详情 sheet shows.
private struct CouponManagementDetailItem: Identifiable {
    let id: CouponDefinitionID
}

@MainActor private struct CouponManagementDetailView: View {
    @Environment(\.locale) private var locale
    @ObservedObject var model: CouponManagementScreenModel
    let id: CouponDefinitionID
    let scope: CouponPublishListScope
    var body: some View {
        List {
            CouponManagementNotice(model: model, surface: .detail)
            if let row = model.core.rows.first(where: { $0.id == id }) {
                Section {
                    Text(row.name ?? appLocalized("couponManagement.coupon", locale: locale)).font(.title3.weight(.semibold))
                    Text(row.description?.isEmpty == false ? row.description! : appLocalized("couponManagement.noDescription", locale: locale))
                    LabeledContent("couponManagement.status") { Text(LocalizedStringKey(row.state.key)) }
                    LabeledContent("couponManagement.type") { Text(LocalizedStringKey(row.typeKey)) }
                    LabeledContent("couponManagement.start", value: CouponValidityTime.display(row.startTime) ?? "—")
                    LabeledContent("couponManagement.end", value: CouponValidityTime.display(row.endTime) ?? "—")
                    Text("couponManagement.chinaTime").font(.footnote).foregroundStyle(.secondary)
                }
                if let code = row.publishedBatchCode {
                    Section("couponManagement.batchCode.title") {
                        Text(verbatim: code).monospaced().privacySensitive()
                            .accessibilityIdentifier("couponManagement.batchCode.value")
                    }.accessibilityIdentifier("couponManagement.batchCode.section")
                }
                Section("couponManagement.counts") {
                    count("couponManagement.published", row.publishCount)
                    count("couponManagement.received", row.receiveCount)
                    count("couponManagement.used", row.useCount)
                    count("couponManagement.remaining", row.remaining)
                    count("couponManagement.perLimit", row.perLimit)
                    // Owner decision 9: two decimals through `MoneyDisplay`; unknown stays the em dash.
                    LabeledContent("couponManagement.amount", value: CouponInfoAmount.from(row.amount).literal.map { MoneyDisplay.plain($0) } ?? CouponInfoAmount.unknownDisplay)
                    LabeledContent("couponManagement.currency", value: row.currency ?? "—")
                }
                Section {
                    Text("couponManagement.stopPolicy").font(.subheadline).foregroundStyle(.secondary)
                    if row.state.canStop {
                        Button("couponManagement.reviewStop", role: .destructive) { model.run { await model.core.prepareStop(id) } }
                            .disabled(model.working || !model.core.canReviewStop).accessibilityIdentifier("couponManagement.stop.review")
                    }
                }
                if let review = model.core.review { CouponManagementReviewSection(model: model, review: review) }
            } else if model.working { ProgressView { Text("couponManagement.loading") }.frame(maxWidth: .infinity) }
            else { Text("couponManagement.unavailable") }
        }
        .merchantM02Page()
        .cyPageTitle("couponManagement.detail")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { model.run { model.core.publishListScope = scope; await model.core.load() } } label: { Label("couponManagement.refresh", systemImage: "arrow.clockwise") }
                    .disabled(model.working)
            }
        }
        .task { model.core.publishListScope = scope; await model.core.load(); model.revision += 1 }
        .onDisappear { model.cancelReview() }
        .themeDomain(.merchant)
    }
    private func count(_ key: LocalizedStringKey, _ value: Int?) -> some View { LabeledContent(key, value: CouponInfoCount.display(value)) }
}
@MainActor private struct CouponManagementEditor: View {
    @ObservedObject var model: CouponManagementScreenModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// verify-r2 N-01: this page applies the topicEditor domain to itself, so its own palette is that domain's.
    /// Reading `cyPalette` here gave the pushing NavigationStack's palette (the dark player shell).
    private var palette: CYDomainPalette { CYDomainPalette(.topicEditor) }
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var discard = false
    @State private var rangeEditor: CouponValidityRangeEditorModel?
    @State private var rangeBaseline: [Date?]?
    @State private var rangeCompleted = false
    /// couponInfo page model: create reads the existing publish grant and never saves an edit.
    private var page: CouponInfoSettingsPage {
        var unresolved = false
        if case .locked = model.core.issue { unresolved = true }
        return CouponInfoSettingsPage.project(
            sessionPresent: model.core.session != nil, editingID: nil, rows: nil, failure: nil,
            unresolved: unresolved, draft: model.core.draft,
            capability: CouponInfoSettingsCapability(canRead: model.core.canRead || model.core.canSimulate,
                                                     canSubmitPublish: model.core.canReviewPublish))
    }
    private func binding<T>(_ keyPath: WritableKeyPath<CouponManagementDraft, T>) -> Binding<T> {
        Binding(get: { model.core.draft[keyPath: keyPath] }, set: { value in var draft = model.core.draft; draft[keyPath: keyPath] = value; model.update(draft) })
    }
    private func closeRangeEditor() { rangeEditor?.cancel(); rangeEditor = nil }
    private var rangeDates: [Date?] { [model.core.draft.startTime, model.core.draft.endTime] }
    var body: some View {
        let page = self.page
        Form {
            CouponManagementNotice(model: model, surface: .editor)
            switch page.phase {
            case .ready:
                fields(page)
            case .unknown:
                // Unknown publish outcome: show the dash-filled form read-only and offer recovery, never a resend.
                CouponInfoSettingsStateSection(page: page)
                if model.core.canRecoverCommands, let key = page.recoveryKey {
                    Section {
                        Button(LocalizedStringKey(key)) { model.run { await model.core.recoverPendingCommands() } }
                            .disabled(model.working).accessibilityIdentifier("couponManagement.editor.recover")
                    }
                }
                if let form = page.form { CouponInfoSettingsReadOnlySection(form: form) }
            case .error, .empty, .loading:
                CouponInfoSettingsStateSection(page: page)
                if let key = page.retryKey {
                    Section {
                        Button(LocalizedStringKey(key)) { model.run { await model.core.load() } }
                            .disabled(model.working).accessibilityIdentifier("couponManagement.editor.retry")
                    }
                }
            case nil:
                Section {
                    ContentUnavailableView("couponManagement.unavailable", systemImage: "ticket")
                        .accessibilityIdentifier("couponManagement.editor.hidden")
                }
            }
        }
        .environment(\.timeZone, CouponValidityTime.timeZone)
        .environment(\.calendar, CouponValidityTime.calendar)
        .formStyle(.grouped)
        .themeDomain(.topicEditor)
        .scrollDismissesKeyboard(.interactively)
        .cyPageTitle("couponManagement.create")
        .interactiveDismissDisabled(model.core.draft.dirty || model.working)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("couponManagement.cancel") { if model.core.draft.dirty { discard = true } else { dismiss() } }
                    .disabled(model.working)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if page.phase == .ready, model.core.review == nil {
                // System bottom bar (toolbar material) with the one prominent action.
                VStack(spacing: 0) {
                    Divider()
                    let isAX = dynamicTypeSize.isAccessibilitySize
                    let layout = isAX ? AnyLayout(VStackLayout(spacing: 8)) : AnyLayout(HStackLayout(spacing: 8))
                    layout {
                        Button {
                            if model.core.draft.dirty { discard = true } else { dismiss() }
                        } label: {
                            Text("couponManagement.cancel").frame(maxWidth: isAX ? .infinity : nil)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .disabled(model.working)

                        if page.publishGranted, page.editingID == nil {
                            Button { model.run { await model.core.preparePublish() } } label: {
                                Text("couponManagement.reviewPublish").frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .disabled(model.working || !page.showsPublishAction)
                            .accessibilityIdentifier("couponManagement.publish.review")
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .background(.bar)
            }
        }
        .cySheet(isPresented: $discard) {
            MemberCouponDiscardConfirmSheet {
                discard = false
                model.core.discardDraft()
                model.revision += 1
                dismiss()
            }
        }
        .cySheet(item: $rangeEditor, onDismiss: {
            // Mini-program toast 时间设置完成 after a confirmed range, shown inline instead of a toast.
            if let baseline = rangeBaseline, baseline != rangeDates, model.core.draft.startTime != nil, model.core.draft.endTime != nil {
                rangeCompleted = true
            }
            rangeBaseline = nil
        }) { editor in
            NavigationStack { CouponValidityRangeEditor(model: editor) }
                .themeDomain(.topicEditor)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .onChange(of: model.core.session) { _, _ in closeRangeEditor() }
        .onChange(of: model.revision) { _, _ in closeRangeEditor() }
        .onDisappear { closeRangeEditor(); model.cancelReview() }
    }
    @ViewBuilder private func fields(_ page: CouponInfoSettingsPage) -> some View {
        // Mini-program couponInfo order: Name -> Date range -> Quantity + Type -> Description.
        Section("couponManagement.details") {
            TextField("couponManagement.name", text: binding(\.name))
                .submitLabel(.next)
                .accessibilityIdentifier("couponManagement.name")
        }.disabled(model.working)
        Section("couponManagement.dates") {
            Text("couponManagement.chinaTime")
                .font(.footnote)
                .foregroundStyle(.secondary)
            if let start = model.core.draft.startTime {
                LabeledContent("couponManagement.start") {
                    Text(verbatim: CouponValidityTime.display(start))
                        .monospacedDigit()
                }
            }
            if let end = model.core.draft.endTime {
                LabeledContent("couponManagement.end") {
                    Text(verbatim: CouponValidityTime.display(end))
                        .monospacedDigit()
                }
            }
            // PORT-5: mini-program shows the validity span next to the picked range, not only inside the sheet.
            if let span = CouponValiditySpan.make(start: model.core.draft.startTime, end: model.core.draft.endTime) {
                CouponValiditySpanBadge(span: span)
            }
            if rangeCompleted {
                Label {
                    Text("couponManagement.range.completed")
                } icon: {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(CYColor.successText)
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                    .accessibilityIdentifier("couponManagement.range.completed")
            }
            Button("couponManagement.range.edit") {
                closeRangeEditor(); rangeCompleted = false; rangeBaseline = rangeDates
                rangeEditor = CouponValidityRangeEditorModel.make(screen: model)
            }.disabled(model.core.session == nil).accessibilityIdentifier("couponManagement.range.open")
        }.disabled(model.working)
        Section {
            TextField("couponManagement.quantity", text: binding(\.quantity))
                .keyboardType(.numberPad)
                .monospacedDigit()
                .accessibilityIdentifier("couponManagement.quantity")
            Picker("couponManagement.type", selection: binding(\.couponType)) {
                Text("couponManagement.chooseType").tag(Int?.none)
                ForEach(0..<4) { type in Text(LocalizedStringKey(CouponManagementDraft.typeKey(type))).tag(Optional(type)) }
            }.accessibilityIdentifier("couponManagement.type")
            TextField("couponManagement.description", text: binding(\.description), axis: .vertical)
                .lineLimit(2...6)
        }.disabled(model.working)
        if let blocker = model.core.draft.blocker {
            Section {
                Label(LocalizedStringKey(blocker), systemImage: "exclamationmark.circle")
                    .font(.footnote)
                    .foregroundStyle(CYColor.dangerText)
            }
        }
        if let review = model.core.review { CouponManagementReviewSection(model: model, review: review) }
    }
}
/// Loading / empty / error / unknown copy straight from `CouponInfoSettingsPage.stateKey`.
private struct CouponInfoSettingsStateSection: View {
    let page: CouponInfoSettingsPage
    var body: some View {
        if let key = page.stateKey {
            Section {
                if case .loading = page.phase {
                    ProgressView { Text(LocalizedStringKey(key)) }
                        .frame(maxWidth: .infinity)
                } else {
                    Text(LocalizedStringKey(key))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }.accessibilityIdentifier("couponManagement.editor.state")
        }
    }
}
/// Server values for an unresolved definition. Unknown is an em dash; a literal 0 stays 0.
private struct CouponInfoSettingsReadOnlySection: View {
    let form: CouponInfoSettingsForm
    var body: some View {
        Section("couponManagement.details") {
            LabeledContent("couponManagement.name", value: form.nameText)
            LabeledContent("couponManagement.type") { typeText }
            LabeledContent("couponManagement.quantity", value: form.quantityText)
            LabeledContent("couponManagement.start", value: form.startText)
            LabeledContent("couponManagement.end", value: form.endText)
            LabeledContent("couponManagement.amount", value: form.amountText)
        }.accessibilityIdentifier("couponManagement.editor.readOnly")
    }
    @ViewBuilder private var typeText: some View {
        if form.typeText == CouponInfoAmount.unknownDisplay { Text(verbatim: form.typeText) }
        else { Text(LocalizedStringKey(form.typeText)) }
    }
}
@MainActor private struct CouponManagementReviewSection: View {
    @Environment(\.locale) private var locale
    @Environment(\.analyticsEventClient) private var analytics
    @ObservedObject var model: CouponManagementScreenModel
    let review: CouponManagementReview
    var body: some View {
        Section {
            switch review.intent {
            case .publish(let draft):
                LabeledContent("couponManagement.name", value: draft.name)
                if !draft.description.isEmpty { LabeledContent("couponManagement.description", value: draft.description) }
                LabeledContent("couponManagement.type") { Text(LocalizedStringKey(CouponManagementDraft.typeKey(draft.couponType))) }
                LabeledContent("couponManagement.quantity", value: draft.quantity)
                if let start = draft.startTime { LabeledContent("couponManagement.start") { Text(CouponValidityTime.display(start)) } }
                if let end = draft.endTime { LabeledContent("couponManagement.end") { Text(CouponValidityTime.display(end)) } }
                Button(LocalizedStringKey(model.core.canSimulate ? "couponManagement.simulate" : "couponManagement.publishConfirm")) {
                    let published: CouponManagementDraft?
                    if case .publish(let draft) = review.intent { published = draft } else { published = nil }
                    model.run {
                        await model.core.confirm(review)
                        guard let draft = published, let id = model.core.acknowledgedDefinitionID else { return }
                        var properties: [String: PlayWireValue] = [
                            "action": .string("coupon_publish"),
                            "name": .string(draft.name),
                            "publishCount": .integer(Int64(Int(draft.quantity) ?? 0)),
                        ]
                        if let type = draft.couponType { properties["couponType"] = .integer(Int64(type)) }
                        MiniProgramAnalytics.track(analytics, "coupon_verify", bizType: "coupon",
                            bizID: MiniProgramAnalytics.bizID(id.value), pagePath: "/subpackageMember/couponInfo/couponInfo", properties: properties)
                    }
                }
                    .fontWeight(.semibold)
                    .disabled(model.working || !model.core.canConfirm(review)).accessibilityIdentifier("couponManagement.confirm")
            case .stop(let row):
                Text("couponManagement.stopQuestion \(row.name ?? appLocalized("couponManagement.coupon", locale: locale))").font(.headline)
                Button(LocalizedStringKey(model.core.canSimulate ? "couponManagement.simulate" : "couponManagement.stopConfirm"), role: .destructive) { model.run { await model.core.confirm(review) } }
                    .disabled(model.working || !model.core.canConfirm(review)).accessibilityIdentifier("couponManagement.confirm")
            }
            Button("couponManagement.cancel") { model.cancelReview() }.disabled(model.working)
        } header: {
            Text("couponManagement.review").accessibilityIdentifier("couponManagement.review")
        }
    }
}
