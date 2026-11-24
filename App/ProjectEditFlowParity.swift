import SwiftUI

// Mini-program parity for the professional editor (pages/topic/components/cy/*), view layer only.
// Logic that does not exist yet is reached through the clearly named binding below; when it is
// absent the section is hidden (capability absent => hidden).

/// Read-only summary of the topic's start/end (mini-program `date-range-sheet`): both ends side by side,
/// the span badge only once both ends are real dates, and an inline error when the end is before the start.
struct ProjectEditScheduleSpan: View {
    let start: String
    let end: String
    @Environment(\.locale) private var locale
    private var startDate: Date? { ProjectEditDateSelection.date(start, ending: false) }
    private var endDate: Date? { ProjectEditDateSelection.date(end, ending: true) }
    private var days: Int? {
        guard let startDate, let endDate, endDate >= startDate else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? .current
        let from = calendar.startOfDay(for: startDate), to = calendar.startOfDay(for: endDate)
        return (calendar.dateComponents([.day], from: from, to: to).day ?? 0) + 1
    }
    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            HStack(spacing: CYSpacing.sm) {
                column("projectSchedule.start", startDate)
                Image(systemName: "arrow.right").font(.footnote).foregroundStyle(CYColor.textTertiary).accessibilityHidden(true)
                column("projectSchedule.end", endDate)
            }
            if let days {
                CYStatusChip(verbatim: appLocalized("projectSchedule.span \(days)", locale: locale))
                    .accessibilityIdentifier("projectSchedule.span")
            } else if let startDate, let endDate, endDate < startDate {
                Label("projectSchedule.endBeforeStart", systemImage: "exclamationmark.circle")
                    .cyText(.meta).foregroundStyle(CYColor.dangerText)
                    .accessibilityIdentifier("projectSchedule.endBeforeStart")
            }
        }
        .padding(.vertical, CYSpacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("projectSchedule.summary")
    }
    private func column(_ title: LocalizedStringKey, _ date: Date?) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.xxs) {
            Text(title).cyText(.meta).textCase(.uppercase).foregroundStyle(CYColor.textTertiary)
            Text(verbatim: date.map(format) ?? "—").cyText(.bodyMedium).monospacedDigit()
                .foregroundStyle(date == nil ? CYColor.textTertiary : CYColor.textPrimary)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(CYSpacing.md)
        .background(CYColor.textTertiary.opacity(0.08), in: RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous))
    }
    private func format(_ date: Date) -> String {
        date.formatted(.dateTime.locale(locale).month(.abbreviated).day().weekday(.abbreviated))
    }
}

/// Editor opened, but no project was read and nothing else explains why: offer a reload instead of a blank form.
struct ProjectEditNotLoadedState: View {
    let reload: () -> Void
    var body: some View {
        CYEmptyStateView(systemImage: "doc.badge.clock", title: "projectEdit.notLoaded",
                         description: "projectEdit.notLoaded.detail", actionTitle: "projectEdit.reload", action: reload)
            .frame(maxWidth: .infinity)
            .accessibilityIdentifier("projectEdit.notLoaded")
    }
}

// MARK: - Node NPC (mini-program `node-npc-form`)

/// Values the node NPC form edits. `presetID` refers to `MerchantNPCPresetAvatar.all`.
struct ProjectNodeNPCForm: Equatable {
    var name = ""
    var presetID: String?
    var greeting = ""
}

/// Binding the node NPC form needs from the logic layer (Cursor). Not implemented yet:
/// read the node's NPC, save it, and report the voice state. Until a host injects one the section is hidden.
@MainActor protocol ProjectNodeNPCAuthoring: AnyObject {
    func load(chapterID: String, nodeID: String) async throws -> ProjectNodeNPCForm?
    func save(_ form: ProjectNodeNPCForm, chapterID: String, nodeID: String) async throws
}

private struct ProjectNodeNPCAuthoringKey: EnvironmentKey {
    static let defaultValue: (any ProjectNodeNPCAuthoring)? = nil
}
extension EnvironmentValues {
    var projectNodeNPCAuthoring: (any ProjectNodeNPCAuthoring)? {
        get { self[ProjectNodeNPCAuthoringKey.self] }
        set { self[ProjectNodeNPCAuthoringKey.self] = newValue }
    }
}

/// Entry row on the node page; hidden when no authoring binding is injected.
@MainActor struct ProjectNodeNPCEntry: View {
    let chapterID: String
    let nodeID: String
    let nodeName: String
    let editable: Bool
    @Environment(\.projectNodeNPCAuthoring) private var authoring
    var body: some View {
        if let authoring {
            Section {
                NavigationLink {
                    ProjectNodeNPCFormView(authoring: authoring, chapterID: chapterID, nodeID: nodeID, nodeName: nodeName, editable: editable)
                } label: { Label("projectNodeNPC.title", systemImage: "person.crop.square") }
                    .accessibilityIdentifier("projectNodeNPC.open")
            } footer: { Text("projectNodeNPC.footer") }
        }
    }
}

/// Name (required), preset look, first line. Save stays disabled until a name exists; unsaved edits ask before leaving.
@MainActor struct ProjectNodeNPCFormView: View {
    let authoring: any ProjectNodeNPCAuthoring
    let chapterID: String
    let nodeID: String
    let nodeName: String
    let editable: Bool
    private enum Phase: Equatable { case loading, ready, saving, failed }
    @State private var phase: Phase = .loading
    @State private var form = ProjectNodeNPCForm()
    @State private var baseline = ProjectNodeNPCForm()
    @State private var saveFailed = false
    @State private var confirmLeave = false
    @State private var showResultSheet = false
    @State private var toastMessage: String?
    @Environment(\.locale) private var locale
    @Environment(\.dismiss) private var dismiss
    private var dirty: Bool { form != baseline }
    private var canSave: Bool {
        editable && phase == .ready && dirty && !form.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && form.presetID != nil
    }
    var body: some View {
        Form {
            Section {
                Text(verbatim: nodeName.isEmpty ? appLocalized("projectEdit.untitledNode", locale: locale) : nodeName)
                    .cyText(.meta).foregroundStyle(CYColor.textSecondary)
            }
            switch phase {
            case .loading:
                Section { CYSkeleton().accessibilityIdentifier("projectNodeNPC.loading") }
            case .failed:
                Section {
                    CYEmptyStateView(systemImage: "exclamationmark.triangle", title: "projectNodeNPC.loadFailed",
                                     actionTitle: "projectEdit.reload") { Task { await load() } }
                }
            case .ready, .saving:
                Section("projectNodeNPC.name") {
                    TextField("projectNodeNPC.name.placeholder", text: $form.name)
                        .onChange(of: form.name) { _, value in if value.count > 32 { form.name = String(value.prefix(32)) } }
                        .accessibilityIdentifier("projectNodeNPC.name")
                }
                Section("projectNodeNPC.look") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 64), spacing: CYSpacing.sm)], spacing: CYSpacing.sm) {
                        ForEach(MerchantNPCPresetAvatar.all) { preset in
                            Button { form.presetID = preset.id } label: {
                                MerchantNPCPresetArtwork(avatar: preset)
                                    .frame(width: 64, height: 64)
                                    .clipShape(RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous)
                                        .strokeBorder(form.presetID == preset.id ? CYColor.textPrimary : .clear, lineWidth: 3))
                            }
                            .buttonStyle(.cyPressable)
                            .accessibilityLabel(Text(LocalizedStringKey(preset.titleKey)))
                            .accessibilityAddTraits(form.presetID == preset.id ? .isSelected : [])
                            .accessibilityIdentifier("projectNodeNPC.preset." + preset.id)
                        }
                    }.padding(.vertical, CYSpacing.xs)
                }
                Section {
                    TextField("projectNodeNPC.greeting.placeholder", text: $form.greeting, axis: .vertical).lineLimit(2...5)
                        .onChange(of: form.greeting) { _, value in if value.count > 255 { form.greeting = String(value.prefix(255)) } }
                        .accessibilityIdentifier("projectNodeNPC.greeting")
                } header: { Text("projectNodeNPC.greeting") } footer: { Text("projectNodeNPC.optional") }
                if saveFailed {
                    Section { Label("projectNodeNPC.saveFailed", systemImage: "exclamationmark.circle").foregroundStyle(CYColor.dangerText) }
                }
            }
        }
        .disabled(!editable || phase == .saving)
        .appNavigationTitle("projectNodeNPC.title")
        .navigationBarTitleDisplayMode(.inline)
        // T&C §3: system back while clean; the guarded back asks before dropping typed NPC changes.
        .cyGuardedBack(when: dirty) { confirmLeave = true }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                if phase == .saving { ProgressView() }
                else { Button("projectNodeNPC.save") { Task { await save() } }.disabled(!canSave).accessibilityIdentifier("projectNodeNPC.save") }
            }
        }
        .interactiveDismissDisabled(dirty)
        .cyModalConfirm(
            isPresented: confirmLeave,
            title: appLocalized("chapterStory.discardQuestion", locale: locale),
            cancelTitle: appLocalized("chapterStory.keepEditing", locale: locale),
            confirmTitle: appLocalized("chapterStory.discard", locale: locale),
            isDestructive: true,
            onCancel: { confirmLeave = false },
            onConfirm: { confirmLeave = false; dismiss() }
        )
        .sheet(isPresented: $showResultSheet) {
            PlayCloseResultSheet(
                title: MerchantCloseCopy.text("节点NPC已保存", "Node NPC Saved", locale),
                message: MerchantCloseCopy.text("NPC设定已写入当前节点。", "NPC configuration saved to this node.", locale),
                detail: nil,
                closeIdentifier: "projectNodeNPC.result.close",
                onClose: { showResultSheet = false }
            )
            .themeDomain(.topicEditor)
        }
        .cyToast(verbatimMessage: $toastMessage)
        .task { await load() }
        .cyDomainScreen(.topicEditor)
    }
    private func load() async {
        phase = .loading
        do {
            let value = try await authoring.load(chapterID: chapterID, nodeID: nodeID) ?? .init()
            form = value; baseline = value; phase = .ready
        } catch { phase = .failed }
    }
    private func save() async {
        guard canSave else { return }
        phase = .saving; saveFailed = false
        do {
            try await authoring.save(form, chapterID: chapterID, nodeID: nodeID)
            baseline = form; phase = .ready
            toastMessage = MerchantCloseCopy.text("已保存", "Saved", locale)
            showResultSheet = true
        }
        catch { saveFailed = true; phase = .ready }
    }
}
