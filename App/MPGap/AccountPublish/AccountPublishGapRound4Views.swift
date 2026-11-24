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
                    TextField("选项文案", text: $option.label)
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
    public let onPreviewVoice: (TopicCastMemberDraft) -> Void
    @Environment(\.dismiss) private var dismiss

    public init(
        members: Binding<[TopicCastMemberDraft]>,
        onPreviewVoice: @escaping (TopicCastMemberDraft) -> Void
    ) {
        self._members = members
        self.onPreviewVoice = onPreviewVoice
    }

    public var body: some View {
        NavigationStack {
            List {
                ForEach($members) { $member in
                    VStack(alignment: .leading, spacing: CYSpacing.xs) {
                        TextField("角色名", text: $member.name).cyText(.cardTitle)
                        TextField("身份/简介", text: $member.roleTitle).cyText(.meta)
                        Button("试听音色") {
                            onPreviewVoice(member)
                        }
                        .buttonStyle(CYPillButtonStyle(style: .secondary, fullWidth: false, compact: true))
                    }
                    .padding(.vertical, CYSpacing.xs)
                }
                .onDelete { offsets in
                    members.remove(atOffsets: offsets)
                }
                Button("添加角色") {
                    members.append(TopicCastMemberDraft(id: UUID().uuidString, name: "", roleTitle: ""))
                }
                .cyText(.body)
            }
            .cyPageTitle(verbatim: "编辑角色")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { dismiss() }
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
                    LabeledContent("玩法形态", value: draft.cityNodeModeLabel)
                        .cyText(.body)
                }
            }

            Section {
                Toggle(TemplateAuthoringExtraCopy.relaxOnLowHP, isOn: $draft.relaxOnLowHP)
                    .cyText(.body)
                if draft.relaxOnLowHP {
                    Picker("松一点程度", selection: $draft.relaxLevel) {
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
                    TextField("输入扫完后的回复", text: $draft.scanReplyText, axis: .vertical)
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
            Label(AccountPublishRound4Copy.saveInviteImage, systemImage: "square.and.arrow.down")
                .cyText(.body)
        }
        .alert(AccountPublishRound4Copy.saveInviteImage, isPresented: $showPrivacyAlert) {
            Button("取消", role: .cancel) {}
            Button("允许并保存") { onSaveConfirmed() }
        } message: {
            Text(verbatim: AccountPublishRound4Copy.saveInvitePrivacyNote)
        }
    }
}
