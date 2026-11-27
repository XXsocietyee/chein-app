import SwiftUI

/// Mount hook for `ProjectEditDetailForms` (`C-F1`):
/// Editors for `branch`, `gallery` (1-4 grid), `line` divider, and dialogue `speaker`.
public struct ProjectEditGapRichStoryBlocksSection: View {
    @Binding public var branch: ProjectEditBranchBlockDraft
    @Binding public var gallery: ProjectEditGalleryBlockDraft
    @Binding public var dialogueSpeaker: String
    public let onInsertDividerLine: () -> Void

    public init(
        branch: Binding<ProjectEditBranchBlockDraft>,
        gallery: Binding<ProjectEditGalleryBlockDraft>,
        dialogueSpeaker: Binding<String>,
        onInsertDividerLine: @escaping () -> Void
    ) {
        self._branch = branch
        self._gallery = gallery
        self._dialogueSpeaker = dialogueSpeaker
        self.onInsertDividerLine = onInsertDividerLine
    }

    public var body: some View {
        Group {
            Section {
                TextField(AccountPublishRound4Copy.speakerPlaceholder, text: $dialogueSpeaker)
                Button(AccountPublishRound4Copy.lineDividerLabel, action: onInsertDividerLine)
            } header: {
                Text("i18nR3.dialogueAndDividers")
            }

            Section {
                TextField(AccountPublishRound4Copy.branchQuestionPlaceholder, text: $branch.question)
                ForEach($branch.options) { $option in
                    TextField("accountPublish.round4.optionLabel", text: $option.label)
                }
                if branch.options.count < 3 {
                    Button(AccountPublishRound4Copy.addBranchOption) {
                        branch.options.append(ProjectEditBranchOptionDraft())
                    }
                }
            } header: {
                Text(verbatim: ProjectEditExtraStoryBlockKind.branch.title)
            }

            Section {
                Stepper("画廊列数：\(gallery.columns)", value: $gallery.columns, in: 1...4)
            } header: {
                Text(verbatim: ProjectEditExtraStoryBlockKind.gallery.title)
            }
        }
    }
}

/// Mount hook for `ProjectEditView` (`C-F5`):
/// Cast editor sheet with add/remove roles + voice preview action.
public struct ProjectEditGapCastEditorSheet: View {
    @Binding public var members: [TopicCastMemberDraft]
    @Binding public var player: ProjectEditCastPlayer
    /// nil hides 试听 (owner decision 2026-11-24 #7: no live cast calls; the MP also hides it when TTS is off).
    public let onPreviewVoice: ((TopicCastMemberDraft) -> Void)?
    @Environment(\.dismiss) private var dismiss

    public init(
        members: Binding<[TopicCastMemberDraft]>,
        player: Binding<ProjectEditCastPlayer>,
        onPreviewVoice: ((TopicCastMemberDraft) -> Void)?
    ) {
        self._members = members
        self._player = player
        self.onPreviewVoice = onPreviewVoice
    }

    public var body: some View {
        NavigationStack {
            List {
                playerSection
                if members.isEmpty {
                    Text("fixr8.cast.empty").foregroundStyle(.secondary)
                }
                ForEach($members) { $member in
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("fixr8.cast.name", text: $member.name)
                            .onChange(of: member.name) { _, value in
                                if value.count > ProjectEditCastConfig.nameMax { member.name = String(value.prefix(ProjectEditCastConfig.nameMax)) }
                            }
                        TextField("fixr8.cast.identity", text: $member.roleTitle, axis: .vertical)
                            .font(.subheadline)
                            .onChange(of: member.roleTitle) { _, value in
                                if value.count > ProjectEditCastConfig.identityMax { member.roleTitle = String(value.prefix(ProjectEditCastConfig.identityMax)) }
                            }
                        Picker(selection: Binding(get: { member.voiceID ?? "none" },
                                                  set: { member.voiceID = $0 == "none" ? nil : $0 })) {
                            ForEach(ProjectEditCastConfig.voicePresets, id: \.value) { preset in
                                Text(LocalizedStringKey(preset.labelKey)).tag(preset.value)
                            }
                            Text("fixr8.cast.voice.none").tag("none")
                        } label: {
                            Text("fixr8.cast.voice")
                        }
                        if let onPreviewVoice, member.voiceID != nil {
                            Button("fixr8.cast.preview") { onPreviewVoice(member) }
                                .buttonStyle(.bordered)
                        }
                    }
                }
                .onDelete { offsets in
                    members.remove(atOffsets: offsets)
                }
                .onMove { source, destination in
                    members.move(fromOffsets: source, toOffset: destination)
                }
                if members.count < ProjectEditCastConfig.maxCast {
                    Button("fixr8.cast.add") {
                        members.append(TopicCastMemberDraft(id: ProjectEditCastConfig.freshID(existing: members), name: "", roleTitle: ""))
                    }
                    .accessibilityIdentifier("projectEdit.cast.add")
                } else {
                    Text("fixr8.cast.max \(ProjectEditCastConfig.maxCast)").foregroundStyle(.secondary)
                }
            }
            .cyPageTitle("fixr8.cast.title")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("fixr8.common.done") { dismiss() }
                }
                if !members.isEmpty {
                    ToolbarItem(placement: .topBarLeading) { EditButton() }
                }
            }
        }
    }

    /// MP cast-sheet `#cast-player` card, first in the sheet: 玩家起名, 玩家身份, then its identities (max 4).
    @ViewBuilder private var playerSection: some View {
        Section {
            Toggle(isOn: $player.playerName) { Label("castPlayer.name", systemImage: "person.text.rectangle") }
            Toggle(isOn: $player.playerIdentity) { Label("castPlayer.identity", systemImage: "star") }
            if player.playerIdentity {
                ForEach($player.identities) { $identity in
                    VStack(alignment: .leading, spacing: CYSpacing.xs) {
                        TextField("castPlayer.identityTitle", text: $identity.title)
                            .onChange(of: identity.title) { _, value in
                                if value.count > ProjectEditCastConfig.identityTitleMax { identity.title = String(value.prefix(ProjectEditCastConfig.identityTitleMax)) }
                            }
                        TextField("castPlayer.identitySub", text: $identity.sub)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .onChange(of: identity.sub) { _, value in
                                if value.count > ProjectEditCastConfig.identitySubMax { identity.sub = String(value.prefix(ProjectEditCastConfig.identitySubMax)) }
                            }
                    }
                }
                .onDelete { offsets in
                    player.identities.remove(atOffsets: offsets)
                }
                if player.identities.count < ProjectEditCastConfig.maxIdentities {
                    Button {
                        let key = ProjectEditCastConfig.freshIdentityKey(existing: player.identities)
                        player.identities.append(ProjectEditCastIdentity(id: key, title: "", sub: ""))
                    } label: { Label("castPlayer.addIdentity", systemImage: "plus") }
                        .accessibilityIdentifier("projectEdit.cast.addIdentity")
                }
            }
        } footer: {
            if player.playerIdentity {
                if player.identities.isEmpty {
                    Text("castPlayer.needIdentity").foregroundStyle(.red)
                } else if player.identities.count >= ProjectEditCastConfig.maxIdentities {
                    Text("castPlayer.identityMax \(ProjectEditCastConfig.maxIdentities)")
                }
            }
        }
    }
}

/// Mount hook for `ProjectEditView` / `ProjectEditDetailForms` (`C-F7`):
/// `添加序章` button + `结局章` / `由工作人员开幕` toggles.
public struct ProjectEditGapChapterExtrasSection: View {
    @Binding public var settings: ProjectEditChapterSettingsDraft
    public let onAddPrologue: () -> Void

    public init(settings: Binding<ProjectEditChapterSettingsDraft>, onAddPrologue: @escaping () -> Void) {
        self._settings = settings
        self.onAddPrologue = onAddPrologue
    }

    public var body: some View {
        Section {
            Button(AccountPublishRound4Copy.addPrologue, action: onAddPrologue)
            Toggle(AccountPublishRound4Copy.endingChapterToggle, isOn: $settings.isEndingChapter)
            Toggle(AccountPublishRound4Copy.staffOpeningToggle, isOn: $settings.staffOpening)
        }
    }
}

/// `C-T3` (r9): mounted in `TemplateAuthoringView` beside `TemplateAuthoringCompletionFields`.
/// MP pages/publish/temp/index.wxml:108-118 (参与方式 → 扫完回复, r5-editor.js `toggleScanReply`),
/// :973-975 (状态不好时松一点, index.js `_writeRelax` / `toggleRelax` / `onRelaxPick`)
/// and :986 (可触发的结果, `node-outcome-contract.js`, not `outcomeRules`).
/// 状态不好时松一点 writes through `setLowHPRelax`. 扫完回复 writes through `setScanReplyEnabled`.
/// citynode 玩法形态 has `TemplateAuthoringContract.TemplateCityNodeInteraction` and `authoringFrom`,
/// but the personal author-request pipe cannot post `/api/merchant/city-node/template/submit` (C-T3c).
/// The picker stays off this screen so a city-node draft is not saved as a personal template.
@MainActor struct TemplateAuthoringGapRound4Section: View {
    /// mp-r3-publish: MP temp/index.wxml:1213 puts 参与方式 right after 玩法 and before 玩法设置, while the low-HP
    /// relax and 可触发的结果 rows belong after the settings. The editor renders each part at its MP position.
    enum Part { case all, participation, afterSettings }
    @ObservedObject var model: TemplateAuthoringModel
    let part: Part

    init(model: TemplateAuthoringModel, part: Part = .all) {
        self.model = model
        self.part = part
    }

    /// MP r5-editor.js:25: participation is 扫码 when `scan.enabled` or `validationMethod === 4`.
    private var isScanParticipation: Bool {
        model.draft.advanced.enabled("scan") || model.draft.validationMethod == .scan
    }
    private var scanReplyOn: Bool {
        (model.draft.advanced.value["scan"]?.object?["kind"]?.string ?? "TEXT") != "NONE"
    }
    private var scanKind: String { model.draft.advanced.value["scan"]?.object?["kind"]?.string ?? "TEXT" }
    private var relaxConfiguration: TemplateLowHPPresetConfiguration { TemplateLowHPPresetConfiguration(model.draft.advanced) }
    private var scanReplyBinding: Binding<Bool> {
        Binding(get: { scanReplyOn }, set: { on in
            guard model.canEdit else { return }
            var draft = model.draft
            draft.advanced.setScanReplyEnabled(on)
            model.draft = draft
            model.changed()
        })
    }
    private var scanReplyText: Binding<String> {
        Binding(get: { model.draft.advanced.text("scan", "reply") }, set: { text in
            guard model.canEdit else { return }
            var draft = model.draft
            // MP maxlength="200" on the reply textarea.
            draft.advanced.set("scan", "reply", .string(String(text.prefix(200))))
            model.draft = draft
            model.changed()
        })
    }
    /// MP `toggleRelax`: on = the first preset, off = remove the editor variant.
    private var relaxOn: Binding<Bool> {
        Binding(get: { !relaxConfiguration.selectedID.isEmpty }, set: { on in
            applyRelax(on ? (relaxConfiguration.options.first?.id ?? "") : "")
        })
    }
    private var relaxPick: Binding<String> {
        Binding(get: { relaxConfiguration.selectedID }, set: { applyRelax($0) })
    }
    private func applyRelax(_ selection: String) {
        guard model.canEdit, relaxConfiguration.isSupported else { return }
        var draft = model.draft
        if selection.isEmpty {
            // setLowHPRelax only writes a row. Off removes that editor variant and leaves other rules.
            guard let next = relaxConfiguration.applying("") else { return }
            draft.advanced = next
        } else if let option = relaxConfiguration.options.first(where: { $0.id == selection }) {
            draft.advanced.setLowHPRelax(path: option.field.rawValue, delta: option.operation)
            guard draft.advanced.rootCreatorIssues.isEmpty else { return }
        } else { return }
        model.draft = draft
        model.changed()
    }
    private var triggerableOutcomes: TemplateTriggerableOutcomes.Result { TemplateTriggerableOutcomes.extract(model.draft) }
    @ViewBuilder private func outcomeLabel(_ label: TemplateTriggerableOutcomes.Label) -> some View {
        switch label {
        case .authored(let text):
            Text(verbatim: text).foregroundStyle(.secondary)
        case .completed:
            Text("templateAuthor.outcome.completed").foregroundStyle(.secondary)
        case .d20Success:
            Text("templateAuthor.outcome.d20Success").foregroundStyle(.secondary)
        case .d20Failure:
            Text("templateAuthor.outcome.d20Failure").foregroundStyle(.secondary)
        case .unnamed:
            Text("templateAuthor.outcome.unnamed").foregroundStyle(.secondary)
        }
    }

    var body: some View {
        Group {
            if part != .afterSettings, isScanParticipation {
                Section {
                    Toggle("fixr9.ap.template.scanReply", isOn: scanReplyBinding)
                        .accessibilityIdentifier("templateAuthor.scanReply")
                    if scanReplyOn && scanKind == "TEXT" {
                        TextField("templateAuthor.round4.scanReplyPrompt", text: scanReplyText, axis: .vertical)
                            .lineLimit(2...6)
                            .accessibilityIdentifier("templateAuthor.scanReply.text")
                    }
                } header: {
                    Text("fixr9.ap.template.participation")
                }
            }
            if part != .participation, !relaxConfiguration.options.isEmpty && relaxConfiguration.isSupported {
                Section {
                    Toggle("fixr9.ap.template.relaxOnLowHP", isOn: relaxOn)
                        .accessibilityIdentifier("templateAuthor.relaxOnLowHP")
                    if !relaxConfiguration.selectedID.isEmpty {
                        Picker("templateAuthor.round4.relaxLevel", selection: relaxPick) {
                            ForEach(relaxConfiguration.options) { option in
                                Text("\(Text(LocalizedStringKey(option.field.labelKey))) \(option.operation)").tag(option.id)
                            }
                        }
                        .accessibilityIdentifier("templateAuthor.relaxLevel")
                    }
                }
            }
            if part != .participation, !model.draft.advanced.enabled("album") {
                Section {
                    ForEach(triggerableOutcomes.items) { item in
                        outcomeLabel(item.label)
                    }
                    ForEach(triggerableOutcomes.issues) { issue in
                        switch issue.code {
                        case .invalidCode:
                            Text("templateAuthor.outcome.invalidCode").font(.footnote).foregroundStyle(.red)
                        case .duplicateCode:
                            Text("templateAuthor.outcome.duplicateCode").font(.footnote).foregroundStyle(.red)
                        }
                    }
                } header: {
                    Text("fixr9.ap.template.outcomes")
                }
            }
        }
        .disabled(!model.canEdit)
    }
}

/// Mount hook for `TeamHomeView` (`C-D11-r7`):
/// Save invite card image button with in-page privacy gate confirmation.
public struct TeamDetailGapSaveInviteImageRow: View {
    public let onSaveConfirmed: () -> Void
    @State private var showPrivacyAlert = false

    public init(onSaveConfirmed: @escaping () -> Void) {
        self.onSaveConfirmed = onSaveConfirmed
    }

    public var body: some View {
        Button {
            showPrivacyAlert = true
        } label: {
            Label("fixr8.team.saveImage", systemImage: "square.and.arrow.down")
        }
        .alert(Text("fixr8.team.saveImage"), isPresented: $showPrivacyAlert) {
            Button("common.cancel", role: .cancel) {}
            Button("fixr8.team.saveImage.allow") { onSaveConfirmed() }
        } message: {
            Text("fixr8.team.saveImage.privacy")
        }
    }
}
