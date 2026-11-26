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
                Image(systemName: "arrow.right").font(.footnote).foregroundStyle(.tertiary).accessibilityHidden(true)
                column("projectSchedule.end", endDate)
            }
            if let days {
                Label(appLocalized("projectSchedule.span \(days)", locale: locale), systemImage: "calendar")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("projectSchedule.span")
            } else if let startDate, let endDate, endDate < startDate {
                Label("projectSchedule.endBeforeStart", systemImage: "exclamationmark.circle")
                    .font(.footnote).foregroundStyle(.red)
                    .accessibilityIdentifier("projectSchedule.endBeforeStart")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("projectSchedule.summary")
    }
    private func column(_ title: LocalizedStringKey, _ date: Date?) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.xxs) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(verbatim: date.map(format) ?? "—").font(.body).monospacedDigit()
                .foregroundStyle(date == nil ? Color.secondary : Color.primary)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    private func format(_ date: Date) -> String {
        date.formatted(.dateTime.locale(locale).month(.abbreviated).day().weekday(.abbreviated))
    }
}

/// Editor opened, but no project was read and nothing else explains why: offer a reload instead of a blank form.
struct ProjectEditNotLoadedState: View {
    let reload: () -> Void
    var body: some View {
        // C-F15-r7 (MP fabu wxml:24-38): 这份主题加载失败 with one full-width 重新加载.
        ContentUnavailableView {
            Label("fixr3.projectEdit.notLoaded", systemImage: "doc.badge.clock")
        } description: {
            Text("projectEdit.notLoaded.detail")
        } actions: {
            Button(action: reload) { Text("projectEdit.reload") }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityIdentifier("projectEdit.reload")
        }
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
                    .font(.footnote).foregroundStyle(.secondary)
            }
            switch phase {
            case .loading:
                Section { ProgressView().frame(maxWidth: .infinity).accessibilityIdentifier("projectNodeNPC.loading") }
            case .failed:
                Section {
                    ContentUnavailableView {
                        Label("projectNodeNPC.loadFailed", systemImage: "exclamationmark.triangle")
                    } actions: {
                        Button("projectEdit.reload") { Task { await load() } }
                    }
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
                                    .clipShape(.rect(cornerRadius: CYRadius.sm))
                                    .overlay(alignment: .bottomTrailing) {
                                        if form.presetID == preset.id {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(.white, Color.accentColor)
                                                .accessibilityHidden(true)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Text(LocalizedStringKey(preset.titleKey)))
                            .accessibilityAddTraits(form.presetID == preset.id ? .isSelected : [])
                            .accessibilityIdentifier("projectNodeNPC.preset." + preset.id)
                        }
                    }
                }
                Section {
                    TextField("projectNodeNPC.greeting.placeholder", text: $form.greeting, axis: .vertical).lineLimit(2...5)
                        .onChange(of: form.greeting) { _, value in if value.count > 255 { form.greeting = String(value.prefix(255)) } }
                        .accessibilityIdentifier("projectNodeNPC.greeting")
                } header: { Text("projectNodeNPC.greeting") } footer: { Text("projectNodeNPC.optional") }
                if saveFailed {
                    Section { Label("projectNodeNPC.saveFailed", systemImage: "exclamationmark.circle").foregroundStyle(.red) }
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
        .confirmationDialog(appLocalized("chapterStory.discardQuestion", locale: locale), isPresented: $confirmLeave, titleVisibility: .visible) {
            Button(appLocalized("chapterStory.discard", locale: locale), role: .destructive) { confirmLeave = false; dismiss() }
            Button(appLocalized("chapterStory.keepEditing", locale: locale), role: .cancel) { confirmLeave = false }
        }
        .alert(MerchantCloseCopy.text("节点NPC已保存", "Node NPC Saved", locale), isPresented: $showResultSheet) {
            Button(PlayCloseCopy.close(locale)) { showResultSheet = false }
                .accessibilityIdentifier("projectNodeNPC.result.close")
        } message: {
            Text(verbatim: MerchantCloseCopy.text("NPC设定已写入当前节点。", "NPC configuration saved to this node.", locale))
        }
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
            showResultSheet = true
        }
        catch { saveFailed = true; phase = .ready }
    }
}
