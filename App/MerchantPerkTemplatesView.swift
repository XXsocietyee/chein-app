import SwiftUI

/// Native `pages/merchant/decor/perks`: standing perk templates (list, add, delete).
/// Writes run only through the injected coordinator; a gated build says "not available yet".
@MainActor struct MerchantPerkTemplatesView: View {
    @Bindable var model: MerchantPerkTemplatesCoordinator
    @State private var draft = MerchantPerkTemplateDraft()
    @State private var showingForm = false
    @State private var confirmingDiscard = false
    @State private var pendingDelete: MerchantPerkTemplateRow?
    @State private var validEndEnabled = false
    @State private var validEndDate = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()

    var body: some View {
        content
            .appNavigationTitle("merchant.perks.title")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("merchant.perks.add") { openForm() }
                        .disabled(model.phase != .ready || model.isBusy)
                        .accessibilityIdentifier("merchant.perks.add")
                }
            }
            .task { if model.phase == .idle { await model.load() } }
            .refreshable { await model.load() }
            .sheet(isPresented: $showingForm) { formSheet }
            .confirmationDialog("merchant.perks.delete.title", isPresented: deleteDialogPresented, titleVisibility: .visible) {
                if let row = pendingDelete {
                    Button("merchant.perks.delete.confirm", role: .destructive) {
                        pendingDelete = nil
                        Task { await model.delete(id: row.id) }
                    }
                }
                Button("action.cancel", role: .cancel) { pendingDelete = nil }
            } message: { Text("merchant.perks.delete.message") }
    }

    private var deleteDialogPresented: Binding<Bool> {
        Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })
    }

    @ViewBuilder private var content: some View {
        switch model.phase {
        case .idle, .loading:
            ProgressView("merchant.perks.loading").frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityIdentifier("merchant.perks.loading")
        case .signedOut:
            ContentUnavailableView("merchant.perks.signedOut", systemImage: "person.crop.circle.badge.exclamationmark")
        case .permissionDenied:
            ContentUnavailableView {
                Label("merchant.perks.permission.title", systemImage: "lock")
            } description: { Text("merchant.perks.permission.detail") } actions: {
                Button("merchant.perks.retry") { Task { await model.load() } }.frame(minHeight: 44)
            }.accessibilityIdentifier("merchant.perks.permission")
        case .failed:
            ContentUnavailableView {
                Label("merchant.perks.failed.title", systemImage: "exclamationmark.triangle")
            } description: { Text("merchant.perks.failed.detail") } actions: {
                Button("merchant.perks.retry") { Task { await model.load() } }.frame(minHeight: 44)
                    .accessibilityIdentifier("merchant.perks.retry")
            }.accessibilityIdentifier("merchant.perks.failed")
        case .ready:
            List {
                if model.action != .idle { Section { actionBanner } }
                if model.refreshing { Section { ProgressView("merchant.perks.refreshing") } }
                if model.rows.isEmpty {
                    Section {
                        CYEmptyStateView(systemImage: "gift", title: "merchant.perks.empty")
                            .accessibilityIdentifier("merchant.perks.empty")
                    }
                }
                ForEach(model.rows) { row in rowView(row) }
            }.accessibilityIdentifier("merchant.perks.list")
        }
    }

    @ViewBuilder private var actionBanner: some View {
        switch model.action {
        case .idle: EmptyView()
        case .saving: ProgressView("merchant.perks.saving")
        case .deleting: ProgressView("merchant.perks.deleting")
        case .saved: bannerText("merchant.perks.saved", tint: CYColor.successText)
        case .deleted: bannerText("merchant.perks.deleted", tint: CYColor.successText)
        case .unconfirmed: bannerText("merchant.perks.unconfirmed", tint: CYColor.warningText)
        case .invalid: bannerText("merchant.perks.invalid", tint: CYColor.dangerText)
        case .notAvailableYet: bannerText("merchant.perks.notAvailable", tint: CYColor.textSecondary)
        case .permissionDenied: bannerText("merchant.perks.permission.detail", tint: CYColor.dangerText)
        case .failed: bannerText("merchant.perks.actionFailed", tint: CYColor.dangerText)
        }
    }

    private func bannerText(_ key: LocalizedStringKey, tint: Color) -> some View {
        HStack {
            Text(key).font(CYTypography.bodyCompact).foregroundStyle(tint)
            Spacer()
            Button("action.close") { model.dismissAction() }.font(CYTypography.meta).frame(minHeight: CYSpacing.minTouchTarget)
        }
        .accessibilityElement(children: .combine).accessibilityIdentifier("merchant.perks.banner")
    }

    private func typeKey(_ index: Int?) -> LocalizedStringKey {
        switch index {
        case 0?: return "merchant.perks.type.gift"
        case 1?: return "merchant.perks.type.coupon"
        case 2?: return "merchant.perks.type.discount"
        default: return "merchant.perks.type.unknown"
        }
    }

    private func fact(_ key: LocalizedStringKey, _ value: String) -> some View {
        HStack(spacing: 4) { Text(key); Text(verbatim: value) }
    }

    private func rowView(_ row: MerchantPerkTemplateRow) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(verbatim: row.name).font(CYTypography.cardTitle).foregroundStyle(CYColor.textPrimary)
                Spacer()
                if row.usable {
                    Text(typeKey(row.typeIndex)).font(CYTypography.caption)
                        .foregroundStyle(CYColor.accentText)
                        .padding(.horizontal, CYSpacing.sm).padding(.vertical, CYSpacing.xxs)
                        .background(CYColor.accentSoft, in: Capsule())
                } else {
                    Text("merchant.perks.expired").font(CYTypography.caption)
                        .foregroundStyle(CYColor.warningText)
                        .padding(.horizontal, CYSpacing.sm).padding(.vertical, CYSpacing.xxs)
                        .background(CYColor.warningSoft, in: Capsule())
                }
            }
            HStack(spacing: 12) {
                if let retail = row.retailValue { fact("merchant.perks.retail", NSDecimalNumber(decimal: retail).stringValue) }
                if let cost = row.unitCost { fact("merchant.perks.cost", NSDecimalNumber(decimal: cost).stringValue) }
                if let quota = row.quota { fact("merchant.perks.quota", String(quota)) }
                if let end = row.validEnd { fact("merchant.perks.validUntil", end) }
            }.font(CYTypography.meta).foregroundStyle(CYColor.textSecondary)
        }
        .accessibilityElement(children: .combine)
        .swipeActions {
            Button("merchant.perks.delete", role: .destructive) { pendingDelete = row }
                .disabled(model.isBusy)
        }
        .accessibilityAction(named: Text("merchant.perks.delete")) { pendingDelete = row }
    }

    private func openForm() {
        draft = MerchantPerkTemplateDraft(); validEndEnabled = false
        model.dismissAction()
        showingForm = true
    }

    private var formSheet: some View {
        NavigationStack {
            Form {
                Picker("merchant.perks.form.type", selection: $draft.typeIndex) {
                    Text("merchant.perks.type.gift").tag(0)
                    Text("merchant.perks.type.coupon").tag(1)
                    Text("merchant.perks.type.discount").tag(2)
                }
                TextField("merchant.perks.form.name", text: $draft.name)
                TextField("merchant.perks.form.retail", text: $draft.retailValue).keyboardType(.decimalPad)
                TextField("merchant.perks.form.cost", text: $draft.unitCost).keyboardType(.decimalPad)
                TextField("merchant.perks.form.quota", text: $draft.quota).keyboardType(.numberPad)
                Toggle("merchant.perks.form.hasValidity", isOn: $validEndEnabled)
                if validEndEnabled {
                    DatePicker("merchant.perks.form.validEnd", selection: $validEndDate, in: MerchantPerkValidityDraft.minimum(now: Date())..., displayedComponents: .date)
                        .environment(\.timeZone, MerchantPerkValidityDraft.timeZone).environment(\.calendar, MerchantPerkValidityDraft.calendar)
                }
                if let field = MerchantPerkTemplateFormPort.firstInvalidField(draft, validEnd: validEndEnabled ? Self.wire(validEndDate) : "", now: Date()),
                   MerchantPerkTemplateFormPort.isDirty(draft, validEndEnabled: validEndEnabled) {
                    Text(LocalizedStringKey("merchant.perks.form.hint." + field.rawValue)).font(.footnote).foregroundStyle(.secondary)
                        .accessibilityIdentifier("merchant.perks.form.hint")
                }
                if !model.canWrite(.deleteTemplate(id: 1)) {
                    Text("merchant.perks.notAvailable").font(.footnote).foregroundStyle(.secondary)
                }
            }
            .appNavigationTitle("merchant.perks.form.title")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action.cancel") {
                        if MerchantPerkTemplateFormPort.isDirty(draft, validEndEnabled: validEndEnabled) { confirmingDiscard = true } else { showingForm = false }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("merchant.perks.form.save") { submit() }
                        .disabled(!formReady || model.isBusy)
                        .accessibilityIdentifier("merchant.perks.form.save")
                }
            }
        }
        .presentationDetents([.medium, .large])
        .interactiveDismissDisabled(MerchantPerkTemplateFormPort.isDirty(draft, validEndEnabled: validEndEnabled))
        .confirmationDialog("merchant.perks.discard.title", isPresented: $confirmingDiscard, titleVisibility: .visible) {
            Button("merchant.perks.discard.confirm", role: .destructive) { showingForm = false }
            Button("merchant.perks.discard.keep", role: .cancel) {}
        }
    }

    private var formReady: Bool {
        var value = draft
        value.validEnd = validEndEnabled ? Self.wire(validEndDate) : ""
        return value.canSave
    }

    private static func wire(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func submit() {
        var value = draft
        value.validEnd = validEndEnabled ? Self.wire(validEndDate) : ""
        showingForm = false
        Task { await model.save(value) }
    }
}

/// Factory so the host wires the screen without editing the session or composition root.
@MainActor enum MerchantPerkTemplatesFactory {
    static func makeCoordinator(reader: any CoopFlowReading, executor: (any CoopFlowExecuting)?) -> MerchantPerkTemplatesCoordinator {
        MerchantPerkTemplatesCoordinator(reader: reader, executor: executor)
    }
    static func makeView(coordinator: MerchantPerkTemplatesCoordinator) -> some View {
        MerchantPerkTemplatesView(model: coordinator)
    }
}
