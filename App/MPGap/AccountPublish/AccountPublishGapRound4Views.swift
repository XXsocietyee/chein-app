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
                    .cyText(.body)
                Button(AccountPublishRound4Copy.lineDividerLabel, action: onInsertDividerLine)
                    .cyText(.body)
            } header: {
                Text(verbatim: "对白与分割线").cyText(.sectionTitle)
            }

            Section {
                TextField(AccountPublishRound4Copy.branchQuestionPlaceholder, text: $branch.question)
                    .cyText(.body)
                ForEach($branch.options) { $option in
                    TextField("accountPublish.round4.optionLabel", text: $option.label)
                        .cyText(.body)
                }
                if branch.options.count < 3 {
                    Button(AccountPublishRound4Copy.addBranchOption) {
                        branch.options.append(ProjectEditBranchOptionDraft())
                    }
                    .cyText(.body)
                }
            } header: {
                Text(verbatim: ProjectEditExtraStoryBlockKind.branch.title).cyText(.sectionTitle)
            }

            Section {
                Stepper("画廊列数：\(gallery.columns)", value: $gallery.columns, in: 1...4)
                    .cyText(.body)
            } header: {
                Text(verbatim: ProjectEditExtraStoryBlockKind.gallery.title).cyText(.sectionTitle)
            }
        }
    }
}

/// Mount hook for `ProjectEditView` (`C-F5`):
/// Cast editor sheet with add/remove roles + voice preview action.
public struct ProjectEditGapCastEditorSheet: View {
    @Binding public var members: [TopicCastMemberDraft]
    /// nil hides 试听 (owner decision 2026-11-24 #7: no live cast calls; the MP also hides it when TTS is off).
    public let onPreviewVoice: ((TopicCastMemberDraft) -> Void)?
    @Environment(\.dismiss) private var dismiss

    public init(
        members: Binding<[TopicCastMemberDraft]>,
        onPreviewVoice: ((TopicCastMemberDraft) -> Void)?
    ) {
        self._members = members
        self.onPreviewVoice = onPreviewVoice
    }

    public var body: some View {
        NavigationStack {
            List {
                if members.isEmpty {
                    Text("fixr8.cast.empty").cyText(.meta).foregroundStyle(CYColor.textSecondary)
                }
                ForEach($members) { $member in
                    VStack(alignment: .leading, spacing: CYSpacing.xs) {
                        TextField("fixr8.cast.name", text: $member.name)
                            .cyText(.cardTitle)
                            .onChange(of: member.name) { _, value in
                                if value.count > ProjectEditCastConfig.nameMax { member.name = String(value.prefix(ProjectEditCastConfig.nameMax)) }
                            }
                        TextField("fixr8.cast.identity", text: $member.roleTitle, axis: .vertical)
                            .cyText(.meta)
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
                        .cyText(.body)
                        if let onPreviewVoice, member.voiceID != nil {
                            Button("fixr8.cast.preview") { onPreviewVoice(member) }
                                .buttonStyle(CYPillButtonStyle(style: .secondary, fullWidth: false, compact: true))
                        }
                    }
                    .padding(.vertical, CYSpacing.xs)
                }
                .onDelete { offsets in
                    members.remove(atOffsets: offsets)
                }
                if members.count < ProjectEditCastConfig.maxCast {
                    Button("fixr8.cast.add") {
                        members.append(TopicCastMemberDraft(id: ProjectEditCastConfig.freshID(existing: members), name: "", roleTitle: ""))
                    }
                    .cyText(.body)
                    .accessibilityIdentifier("projectEdit.cast.add")
                } else {
                    Text("fixr8.cast.max \(ProjectEditCastConfig.maxCast)").cyText(.meta).foregroundStyle(CYColor.textSecondary)
                }
            }
            .cyPageTitle("fixr8.cast.list")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("fixr8.common.done") { dismiss() }
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
                .cyText(.body)
            Toggle(AccountPublishRound4Copy.endingChapterToggle, isOn: $settings.isEndingChapter)
                .cyText(.body)
            Toggle(AccountPublishRound4Copy.staffOpeningToggle, isOn: $settings.staffOpening)
                .cyText(.body)
        }
    }
}

/// Mount hook for `TemplateAuthoringView` (`C-T3`):
/// `状态不好时松一点`, `可触发的结果`, `扫完回复`, and `from=citynode` mode row.
public struct TemplateAuthoringGapRound4Section: View {
    @Binding public var draft: TemplateAuthoringRound4Draft

    public init(draft: Binding<TemplateAuthoringRound4Draft>) {
        self._draft = draft
    }

    public var body: some View {
        Group {
            if draft.isCityNodeMode {
                Section {
                    LabeledContent("templateAuthor.round4.playForm", value: draft.cityNodeModeLabel)
                        .cyText(.body)
                }
            }

            Section {
                Toggle(TemplateAuthoringExtraCopy.relaxOnLowHP, isOn: $draft.relaxOnLowHP)
                    .cyText(.body)
                if draft.relaxOnLowHP {
                    Picker("templateAuthor.round4.relaxLevel", selection: $draft.relaxLevel) {
                        ForEach(AccountPublishRound4Copy.relaxLevels, id: \.self) { level in
                            Text(verbatim: level).tag(level)
                        }
                    }
                    .cyText(.body)
                }
            }

            Section {
                Toggle(TemplateAuthoringExtraCopy.scanReply, isOn: $draft.scanReplyEnabled)
                    .cyText(.body)
                if draft.scanReplyEnabled {
                    TextField("templateAuthor.round4.scanReplyPrompt", text: $draft.scanReplyText, axis: .vertical)
                        .lineLimit(2...4)
                        .cyText(.body)
                }
            }

            if !draft.triggerableOutcomes.isEmpty {
                Section {
                    ForEach(draft.triggerableOutcomes, id: \.self) { outcome in
                        Text(verbatim: outcome)
                            .cyText(.body)
                            .foregroundStyle(CYColor.textSecondary)
                    }
                } header: {
                    Text(verbatim: TemplateAuthoringExtraCopy.triggerableOutcomes).cyText(.sectionTitle)
                }
            }
        }
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
                .cyText(.body)
        }
        .alert(Text("fixr8.team.saveImage"), isPresented: $showPrivacyAlert) {
            Button("common.cancel", role: .cancel) {}
            Button("fixr8.team.saveImage.allow") { onSaveConfirmed() }
        } message: {
            Text("fixr8.team.saveImage.privacy")
        }
    }
}
