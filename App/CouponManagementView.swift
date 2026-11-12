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
    @State private var creating = false
    init(coordinator: CouponManagementCoordinator, sessionKey: CouponManagementSession?, isSourceVisible: Bool = false) {
        _model = StateObject(wrappedValue: CouponManagementScreenModel(coordinator)); self.sessionKey = sessionKey; self.isSourceVisible = isSourceVisible
    }
    var body: some View {
        Group {
            if !isSourceVisible { ContentUnavailableView("couponManagement.unavailable", systemImage: "ticket") }
            else if sessionKey == nil { ContentUnavailableView("couponManagement.signIn", systemImage: "person.crop.circle") }
            else {
                List {
                    CouponManagementNotice(model: model, surface: .list)
                    if model.core.canRecoverCommands {
                        Button("couponManagement.checkPendingResults") { model.run { await model.core.recoverPendingCommands() } }
                            .disabled(model.working).accessibilityIdentifier("couponManagement.recover")
                    }
                    Text("couponManagement.chinaTime").font(.footnote).foregroundStyle(.secondary)
                    if model.working || model.core.loading { ProgressView("couponManagement.loading") }
                    // A failed read is an error notice above, not an empty list.
                    else if model.core.rows.isEmpty, model.core.issue == nil {
                        ContentUnavailableView("couponManagement.empty", systemImage: "ticket")
                            .listRowBackground(Color.clear)
                    }
                    ForEach(model.core.rows) { row in
                        NavigationLink {
                            CouponManagementDetailView(model: model, id: row.id)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(row.name ?? appLocalized("couponManagement.coupon", locale: locale)).font(.headline)
                                Text(LocalizedStringKey(row.typeKey)).font(.subheadline)
                                // Mini-program coupon list row: description (fallback copy) and remaining stock.
                                if let text = row.description, !text.isEmpty { Text(verbatim: text).font(.caption) }
                                else { Text("couponManagement.noDescription").font(.caption).foregroundStyle(.secondary) }
                                // Unknown remaining stock is an em dash; a literal 0 stays 0.
                                LabeledContent("couponManagement.remaining", value: CouponInfoCount.display(row.remaining)).font(.caption)
                                if row.state != .active { Text(LocalizedStringKey(row.state.key)).font(.caption) }
                                Text("\(CouponValidityTime.display(row.startTime) ?? "—") – \(CouponValidityTime.display(row.endTime) ?? "—")").font(.caption).foregroundStyle(.secondary)
                            }.padding(.vertical, 4)
                        }.accessibilityIdentifier("couponManagement.definition.\(row.id.value)")
                    }
                }
                .refreshable { await model.core.load(); model.revision += 1 }
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
        .scrollContentBackground(.hidden)
        .background(CYColor.bgPage)
        .navigationTitle("couponManagement.title")
        .task(id: sessionKey) {
            model.synchronize(); creating = false
            if isSourceVisible, sessionKey != nil { await model.core.load(); model.revision += 1 }
        }
        .sheet(isPresented: $creating) { NavigationStack { CouponManagementEditor(model: model) } }
        .onChange(of: sessionKey) { _, _ in creating = false; model.synchronize() }
        .onChange(of: isSourceVisible) { _, visible in if !visible { creating = false; model.core.leave(); model.revision += 1 } }
    }
}
private enum CouponManagementNoticeSurface: String { case list, detail, editor }
@MainActor private struct CouponManagementNotice: View {
    @ObservedObject var model: CouponManagementScreenModel
    let surface: CouponManagementNoticeSurface
    var body: some View {
        Section {
            if model.core.canSimulate { Text("couponManagement.synthetic").font(.footnote).foregroundStyle(.secondary) }
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
@MainActor private struct CouponManagementDetailView: View {
    @Environment(\.locale) private var locale
    @ObservedObject var model: CouponManagementScreenModel
    let id: CouponDefinitionID
    var body: some View {
        List {
            CouponManagementNotice(model: model, surface: .detail)
            if let row = model.core.rows.first(where: { $0.id == id }) {
                Section {
                    Text(row.name ?? appLocalized("couponManagement.coupon", locale: locale)).font(.title2)
                    Text(row.description?.isEmpty == false ? row.description! : appLocalized("couponManagement.noDescription", locale: locale))
                    LabeledContent("couponManagement.status") { Text(LocalizedStringKey(row.state.key)) }
                    LabeledContent("couponManagement.type") { Text(LocalizedStringKey(row.typeKey)) }
                    LabeledContent("couponManagement.start", value: CouponValidityTime.display(row.startTime) ?? "—")
                    LabeledContent("couponManagement.end", value: CouponValidityTime.display(row.endTime) ?? "—")
                    Text("couponManagement.chinaTime").font(.footnote)
                }
                if let code = row.publishedBatchCode {
                    Section("couponManagement.batchCode.title") {
                        Text(verbatim: code).font(.body.monospaced()).privacySensitive()
                            .accessibilityIdentifier("couponManagement.batchCode.value")
                    }.accessibilityIdentifier("couponManagement.batchCode.section")
                }
                Section("couponManagement.counts") {
                    count("couponManagement.published", row.publishCount)
                    count("couponManagement.received", row.receiveCount)
                    count("couponManagement.used", row.useCount)
                    count("couponManagement.remaining", row.remaining)
                    count("couponManagement.perLimit", row.perLimit)
                    LabeledContent("couponManagement.amount", value: CouponInfoAmount.from(row.amount).displayText)
                    LabeledContent("couponManagement.currency", value: row.currency ?? "—")
                }
                Section {
                    Text("couponManagement.stopPolicy").font(.footnote)
                    if row.state.canStop {
                        Button("couponManagement.reviewStop", role: .destructive) { model.run { await model.core.prepareStop(id) } }
                            .disabled(model.working || !model.core.canReviewStop).accessibilityIdentifier("couponManagement.stop.review")
                    }
                }
                if let review = model.core.review { CouponManagementReviewSection(model: model, review: review) }
            } else if model.working { ProgressView("couponManagement.loading") }
            else { Text("couponManagement.unavailable") }
        }
        .merchantM02Page()
        .navigationTitle("couponManagement.detail")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { model.run { await model.core.load() } } label: { Label("couponManagement.refresh", systemImage: "arrow.clockwise") }
                    .disabled(model.working)
            }
        }
        .task { await model.core.load(); model.revision += 1 }
        .onDisappear { model.cancelReview() }
    }
    private func count(_ key: LocalizedStringKey, _ value: Int?) -> some View { LabeledContent(key, value: CouponInfoCount.display(value)) }
}
@MainActor private struct CouponManagementEditor: View {
    @ObservedObject var model: CouponManagementScreenModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
                    Button(LocalizedStringKey(key)) { model.run { await model.core.recoverPendingCommands() } }
                        .disabled(model.working).accessibilityIdentifier("couponManagement.editor.recover")
                }
                if let form = page.form { CouponInfoSettingsReadOnlySection(form: form) }
            case .error, .empty, .loading:
                CouponInfoSettingsStateSection(page: page)
                if let key = page.retryKey {
                    Button(LocalizedStringKey(key)) { model.run { await model.core.load() } }
                        .disabled(model.working).accessibilityIdentifier("couponManagement.editor.retry")
                }
            case nil:
                Text("couponManagement.unavailable").foregroundStyle(.secondary)
                    .accessibilityIdentifier("couponManagement.editor.hidden")
            }
        }
        .environment(\.timeZone, CouponValidityTime.timeZone)
        .environment(\.calendar, CouponValidityTime.calendar)
        .merchantM02Page()
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("couponManagement.create")
        .interactiveDismissDisabled(model.core.draft.dirty || model.working)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("couponManagement.cancel") { if model.core.draft.dirty { discard = true } else { dismiss() } }.disabled(model.working) } }
        .confirmationDialog("couponManagement.discardTitle", isPresented: $discard, titleVisibility: .visible) {
            Button("couponManagement.discard", role: .destructive) { model.core.discardDraft(); model.revision += 1; dismiss() }
            Button("couponManagement.keepEditing", role: .cancel) {}
        }
        .sheet(item: $rangeEditor, onDismiss: {
            // Mini-program toast 时间设置完成 after a confirmed range, shown inline instead of a toast.
            if let baseline = rangeBaseline, baseline != rangeDates, model.core.draft.startTime != nil, model.core.draft.endTime != nil {
                withAnimation(CYMotion.resolve(CYMotion.standard, reduceMotion: reduceMotion)) { rangeCompleted = true }
            }
            rangeBaseline = nil
        }) { editor in NavigationStack { CouponValidityRangeEditor(model: editor) } }
        .onChange(of: model.core.session) { _, _ in closeRangeEditor() }
        .onChange(of: model.revision) { _, _ in closeRangeEditor() }
        .onDisappear { closeRangeEditor(); model.cancelReview() }
    }
    @ViewBuilder private func fields(_ page: CouponInfoSettingsPage) -> some View {
        Section("couponManagement.details") {
            TextField("couponManagement.name", text: binding(\.name)).accessibilityIdentifier("couponManagement.name")
            TextField("couponManagement.description", text: binding(\.description), axis: .vertical).lineLimit(2...6)
            Picker("couponManagement.type", selection: binding(\.couponType)) {
                Text("couponManagement.chooseType").tag(Int?.none)
                ForEach(0..<4) { type in Text(LocalizedStringKey(CouponManagementDraft.typeKey(type))).tag(Optional(type)) }
            }.accessibilityIdentifier("couponManagement.type")
            TextField("couponManagement.quantity", text: binding(\.quantity)).keyboardType(.numberPad).accessibilityIdentifier("couponManagement.quantity")
        }.disabled(model.working)
        Section("couponManagement.dates") {
            Text("couponManagement.chinaTime").font(.footnote)
            if let start = model.core.draft.startTime {
                LabeledContent("couponManagement.start", value: CouponValidityTime.display(start))
            }
            if let end = model.core.draft.endTime {
                LabeledContent("couponManagement.end", value: CouponValidityTime.display(end))
            }
            // PORT-5: mini-program shows the validity span next to the picked range, not only inside the sheet.
            if let span = CouponValiditySpan.make(start: model.core.draft.startTime, end: model.core.draft.endTime) {
                CouponValiditySpanBadge(span: span)
            }
            if rangeCompleted {
                Label("couponManagement.range.completed", systemImage: "checkmark.circle.fill")
                    .font(.footnote).foregroundStyle(CYColor.successText)
                    .transition(.opacity)
                    .accessibilityIdentifier("couponManagement.range.completed")
            }
            Button("couponManagement.range.edit") {
                closeRangeEditor(); rangeCompleted = false; rangeBaseline = rangeDates
                rangeEditor = CouponValidityRangeEditorModel.make(screen: model)
            }.disabled(model.core.session == nil).accessibilityIdentifier("couponManagement.range.open")
        }.disabled(model.working)
        if let blocker = model.core.draft.blocker { Text(LocalizedStringKey(blocker)).foregroundStyle(.secondary) }
        // Shown only with the existing publish grant on a new definition; an edit never publishes and nothing saves.
        if page.publishGranted, page.editingID == nil {
            Button("couponManagement.reviewPublish") { model.run { await model.core.preparePublish() } }
                .disabled(model.working || !page.showsPublishAction).accessibilityIdentifier("couponManagement.publish.review")
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
                if case .loading = page.phase { ProgressView(LocalizedStringKey(key)) }
                else { Text(LocalizedStringKey(key)).foregroundStyle(.secondary) }
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
                Button(LocalizedStringKey(model.core.canSimulate ? "couponManagement.simulate" : "couponManagement.publishConfirm")) { model.run { await model.core.confirm(review) } }
                    .buttonStyle(.questifyPrimary)
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
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
