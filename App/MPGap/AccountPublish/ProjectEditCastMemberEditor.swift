import PhotosUI
import SwiftUI
import UIKit

/// What the 角色 list opens: an existing role (edit) or a fresh one (add, joins the list only on 完成).
struct ProjectEditCastEditTarget: Identifiable {
    let member: TopicCastMemberDraft
    let isNew: Bool
    var id: String { member.id }
}

/// MP `publish/fabu/cast-sheet.wxml` second sheet 编辑角色 (theme-cast.js `_openMember` / `saveCastMember`), stacked on
/// the 角色 sheet: face → 名字* → 一句话身份 → 声音 → 颜色 → 你知道的 → 结局台词 → 删除角色.
/// 完成 stays tappable like the MP (#871): a problem shows in red under its section instead.
/// Avatar: MP `pickCastAvatar` (one photo → upload → `avatarUrl`), only when the editor has an approved image upload.
/// Voice: preset picker, then MP `toggleCastRecord` 用自己的声音录 (record → upload → `voice = {mode: record, url}`),
/// only when the editor has an approved audio upload; a recording made on the MP is kept either way.
struct ProjectEditCastMemberEditor: View {
    let target: ProjectEditCastEditTarget
    /// Other roles in the cast, for the MP duplicate-name rule.
    let others: [TopicCastMemberDraft]
    let chapters: [ProjectEditChapter]
    let onPreviewVoice: ((TopicCastMemberDraft) -> Void)?
    let onSave: (TopicCastMemberDraft) -> Void
    let onDelete: () -> Void
    /// nil hides 上传头像 (no approved upload in this editor, e.g. read-only or signed out).
    let avatarUpload: ProjectEditCastAvatarUpload?
    /// nil hides 用自己的声音录 (no approved audio upload in this editor).
    let voiceUpload: ProjectEditCastVoiceUpload?

    @Environment(\.dismiss) private var dismiss
    @State private var member: TopicCastMemberDraft
    @State private var issue: Issue?
    @State private var confirmingDelete = false
    @State private var avatarItem: PhotosPickerItem?
    @State private var avatarPreview: UIImage?
    @State private var avatarTask: Task<Void, Never>?
    @State private var uploadingAvatar = false
    @StateObject private var recorder = ProjectEditCastVoiceRecorder()
    @State private var voiceTask: Task<Void, Never>?
    @State private var uploadingVoice = false

    enum Issue: Equatable {
        case nameMissing
        case nameTaken(String)
        case clueEmpty(Int)
        /// MP 无法选择图片，请重试
        case avatarUnreadable
        /// MP 头像上传失败，请重试
        case avatarFailed
        /// MP 还在上传，请稍候再点完成
        case avatarUploading
        /// MP 录音没有开始，请检查麦克风权限
        case voiceNotStarted
        /// MP 录音太短，请再录一次
        case voiceTooShort
        /// MP 录音上传失败，请重试
        case voiceFailed
    }

    init(target: ProjectEditCastEditTarget, others: [TopicCastMemberDraft], chapters: [ProjectEditChapter],
         onPreviewVoice: ((TopicCastMemberDraft) -> Void)?,
         onSave: @escaping (TopicCastMemberDraft) -> Void, onDelete: @escaping () -> Void,
         avatarUpload: ProjectEditCastAvatarUpload? = nil, voiceUpload: ProjectEditCastVoiceUpload? = nil) {
        self.avatarUpload = avatarUpload
        self.voiceUpload = voiceUpload
        self.target = target
        self.others = others
        self.chapters = chapters
        self.onPreviewVoice = onPreviewVoice
        self.onSave = onSave
        self.onDelete = onDelete
        self._member = State(initialValue: target.member)
    }

    private var clueChapters: [(value: ProjectEditJSON, number: Int, name: String)] {
        ProjectEditCastConfig.clueChapters(chapters)
    }

    var body: some View {
        NavigationStack {
            Form {
                faceSection
                nameSection
                voiceSection
                colorSection
                cluesSection
                endingSection
                if !target.isNew {
                    Section {
                        Button(role: .destructive) { confirmingDelete = true } label: {
                            Text("castMember.delete").frame(maxWidth: .infinity)
                        }
                        .accessibilityIdentifier("projectEdit.castMember.delete")
                    }
                }
            }
            .cyPageTitle("castMember.title")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { stopUploads(); dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("fixr8.common.done") { save() }
                        .accessibilityIdentifier("projectEdit.castMember.done")
                }
            }
            .onChange(of: avatarItem) { _, item in
                guard let item else { return }
                avatarItem = nil
                startAvatarUpload(item)
            }
            .onDisappear { stopUploads() }
            .confirmationDialog(deleteTitle, isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("castMember.delete", role: .destructive) {
                    onDelete()
                    dismiss()
                }
                Button("common.cancel", role: .cancel) {}
            }
        }
    }

    private var deleteTitle: Text {
        let name = member.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? Text("castMember.deleteConfirm \(Text("castMember.untitled"))") : Text("castMember.deleteConfirm \(name)")
    }

    // MARK: Sections (MP order)

    /// MP `cast-avatar`: the face (photo, or the initial on the role colour) with 上传头像 / 更换头像 under it.
    @ViewBuilder private var faceSection: some View {
        Section {
            VStack(spacing: CYSpacing.sm) {
                ProjectEditCastFace(name: member.name, colorHex: member.colorHex, size: .large,
                                    imageURL: member.avatarURL, localImage: avatarPreview)
                if avatarUpload != nil {
                    PhotosPicker(selection: $avatarItem, matching: .images) {
                        Label(member.avatarURL == nil ? LocalizedStringKey("castMember.avatar.upload") : LocalizedStringKey("castMember.avatar.change"),
                              systemImage: "camera")
                    }
                    .buttonStyle(.bordered)
                    .disabled(uploadingAvatar)
                    .accessibilityIdentifier("projectEdit.castMember.avatar")
                    if uploadingAvatar {
                        ProgressView { Text("castMember.avatar.uploading") }
                            .font(.footnote)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .listRowBackground(Color.clear)
        } footer: {
            if let text = avatarIssueText {
                Text(text)
                    .foregroundStyle(CYColor.dangerText)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var avatarIssueText: LocalizedStringKey? {
        switch issue {
        case .avatarUnreadable: return "castMember.avatar.unreadable"
        case .avatarFailed: return "castMember.avatar.failed"
        case .avatarUploading: return "castMember.avatar.stillUploading"
        default: return nil
        }
    }

    private var isAvatarIssue: Bool { avatarIssueText != nil }

    /// MP `pickCastAvatar` + `_startCastUpload('avatar', …)`: a new pick replaces a running upload; the reference is
    /// written only after the server returns it, and 取消 / closing the sheet drops the upload (MP `_abortCastUploads`).
    private func startAvatarUpload(_ item: PhotosPickerItem) {
        guard let avatarUpload else { return }
        avatarTask?.cancel()
        uploadingAvatar = true
        if isAvatarIssue { issue = nil }
        avatarTask = Task { @MainActor in
            let bytes = try? await item.loadTransferable(type: Data.self)
            if Task.isCancelled { return }
            guard let bytes, let image = try? RetainedImageSanitizer.sanitize(bytes) else {
                uploadingAvatar = false
                issue = .avatarUnreadable
                return
            }
            do {
                let reference = try await avatarUpload.upload(image)
                if Task.isCancelled { return }
                guard let saved = ProjectEditCastConfig.savableAvatar(reference) else { throw ProjectStoryImageFailure.invalidResponse }
                member.avatarURL = saved
                avatarPreview = UIImage(data: image.jpeg)
                uploadingAvatar = false
                if isAvatarIssue { issue = nil }
            } catch {
                if Task.isCancelled { return }
                uploadingAvatar = false
                issue = .avatarFailed
            }
        }
    }

    @ViewBuilder private var nameSection: some View {
        Section {
            TextField("castMember.namePlaceholder", text: $member.name)
                .onChange(of: member.name) { _, value in
                    if value.count > ProjectEditCastConfig.nameMax { member.name = String(value.prefix(ProjectEditCastConfig.nameMax)) }
                    if issue == .nameMissing || isNameIssue { issue = nil }
                }
                .accessibilityIdentifier("projectEdit.castMember.name")
        } header: {
            Text("castMember.name")
        } footer: {
            switch issue {
            case .nameMissing:
                Text("castMember.nameRequired").foregroundStyle(CYColor.dangerText)
            case .nameTaken(let name):
                Text("castMember.nameTaken \(name)").foregroundStyle(CYColor.dangerText)
            default:
                EmptyView()
            }
        }
        Section {
            TextField("castMember.identityPlaceholder", text: $member.roleTitle, axis: .vertical)
                .onChange(of: member.roleTitle) { _, value in
                    if value.count > ProjectEditCastConfig.identityMax { member.roleTitle = String(value.prefix(ProjectEditCastConfig.identityMax)) }
                }
        } header: {
            Text("fixr8.cast.identity")
        }
    }

    private var isNameIssue: Bool {
        if case .nameTaken = issue { return true }
        return false
    }

    @ViewBuilder private var voiceSection: some View {
        Section {
            Picker(selection: Binding(get: { member.voiceID ?? (member.voiceRecordingURL == nil ? "none" : "record") },
                                      set: { value in
                                          guard value != "record" else { return }
                                          member.voiceID = value == "none" ? nil : value
                                          member.voiceRecordingURL = nil
                                      })) {
                ForEach(ProjectEditCastConfig.voicePresets, id: \.value) { preset in
                    Text(LocalizedStringKey(preset.labelKey)).tag(preset.value)
                }
                Text("fixr8.cast.voice.none").tag("none")
                if member.voiceRecordingURL != nil {
                    Text("castMember.voice.own").tag("record")
                }
            } label: {
                Text("fixr8.cast.voice")
            }
            if let onPreviewVoice, member.voiceID != nil {
                Button {
                    onPreviewVoice(member)
                } label: {
                    Label("fixr8.cast.preview", systemImage: "play.fill")
                }
                .buttonStyle(.borderless)
            }
            if voiceUpload != nil {
                recordRow
            }
        } footer: {
            if let text = voiceIssueText {
                Text(text)
                    .foregroundStyle(CYColor.dangerText)
            }
        }
    }

    /// MP cast-sheet.wxml:107-110: 用自己的声音录 / 录音中，点一下停止, with 已录好 on the right once uploaded.
    private var recordRow: some View {
        Button { toggleRecord() } label: {
            HStack(spacing: CYSpacing.sm) {
                Label {
                    Text(recorder.isRecording ? LocalizedStringKey("castMember.voice.recording") : LocalizedStringKey("castMember.voice.record"))
                        .foregroundStyle(recorder.isRecording ? CYColor.dangerText : Color.primary)
                } icon: {
                    Image(systemName: recorder.isRecording ? "stop.circle.fill" : "mic")
                        .foregroundStyle(recorder.isRecording ? CYColor.dangerText : Color.accentColor)
                        .symbolEffect(.pulse, isActive: recorder.isRecording)
                }
                Spacer(minLength: CYSpacing.xs)
                if uploadingVoice {
                    ProgressView { Text("castMember.voice.uploading") }
                        .font(.footnote)
                } else if member.voiceRecordingURL != nil && !recorder.isRecording {
                    Text("castMember.voice.recorded")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .disabled(uploadingVoice)
        .accessibilityLabel(recorder.isRecording ? Text("castMember.voice.stopLabel") : Text("castMember.voice.record"))
        .accessibilityIdentifier("projectEdit.castMember.record")
    }

    private var voiceIssueText: LocalizedStringKey? {
        switch issue {
        case .voiceNotStarted: return "castMember.voice.notStarted"
        case .voiceTooShort: return "castMember.voice.tooShort"
        case .voiceFailed: return "castMember.voice.failed"
        default: return nil
        }
    }

    private var isVoiceIssue: Bool { voiceIssueText != nil }

    /// MP `toggleCastRecord`: tap starts a take, tap again stops and keeps it; the take uploads right away and
    /// `voice` becomes `{mode: record, url}` only after the server returns the reference (MP `_onCastRecStop`).
    private func toggleRecord() {
        guard let voiceUpload else { return }
        if recorder.isRecording {
            recorder.stop(discard: false)
            return
        }
        if isVoiceIssue { issue = nil }
        Task { @MainActor in
            await recorder.start { result in
                switch result {
                case .success(let audio):
                    startVoiceUpload(audio, with: voiceUpload)
                case .failure(let failure):
                    issue = failure == .tooShort ? .voiceTooShort : (failure == .notStarted ? .voiceNotStarted : .voiceFailed)
                }
            }
        }
    }

    private func startVoiceUpload(_ audio: ProjectStorySelectedAudio, with voiceUpload: ProjectEditCastVoiceUpload) {
        voiceTask?.cancel()
        uploadingVoice = true
        voiceTask = Task { @MainActor in
            do {
                let reference = try await voiceUpload.upload(audio)
                if Task.isCancelled { return }
                guard let saved = ProjectEditCastConfig.savableAvatar(reference) else { throw ProjectStoryImageFailure.invalidResponse }
                member.voiceRecordingURL = saved
                member.voiceID = nil
                uploadingVoice = false
                if isVoiceIssue { issue = nil }
            } catch {
                if Task.isCancelled { return }
                uploadingVoice = false
                issue = .voiceFailed
            }
        }
    }

    /// MP `_stopCastRecording(true)` + `_abortCastUploads` when the sheet closes.
    private func stopUploads() {
        avatarTask?.cancel()
        voiceTask?.cancel()
        recorder.stop(discard: true)
    }

    @ViewBuilder private var colorSection: some View {
        Section {
            HStack(spacing: CYSpacing.md) {
                ForEach(Array(ProjectEditCastConfig.colors.enumerated()), id: \.offset) { index, hex in
                    Button {
                        member.colorHex = hex
                    } label: {
                        Circle()
                            .fill(ProjectEditCastFace.color(for: hex))
                            .frame(width: 32, height: 32)
                            .overlay {
                                if member.colorHex == hex {
                                    Image(systemName: "checkmark")
                                        .font(.footnote.weight(.bold))
                                        .foregroundStyle(.white)
                                }
                            }
                            .frame(width: CYSpacing.minTouchTarget, height: CYSpacing.minTouchTarget)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("castMember.colorNumber \(index + 1)"))
                    .accessibilityAddTraits(member.colorHex == hex ? .isSelected : [])
                }
            }
        } header: {
            Text("castMember.color")
        }
    }

    @ViewBuilder private var cluesSection: some View {
        Section {
            ForEach(Array(member.clues.indices), id: \.self) { index in
                VStack(alignment: .leading, spacing: CYSpacing.xs) {
                    TextField("castMember.cluePlaceholder", text: clueText(index), axis: .vertical)
                    Picker(selection: clueChapter(index)) {
                        Text("castMember.clue.atStart").tag("")
                        ForEach(clueChapters, id: \.number) { option in
                            chapterLabel(number: option.number, name: option.name).tag(chapterTag(option.value))
                        }
                        if let current = member.clues[index].chapterID, !clueChapters.contains(where: { $0.value == current }) {
                            Text("castMember.clue.chapterGone").tag(chapterTag(current))
                        }
                    } label: {
                        Label("castMember.clue.unlock", systemImage: "lock")
                    }
                    if issue == .clueEmpty(index) {
                        Text("castMember.clue.empty \(index + 1)").font(.footnote).foregroundStyle(CYColor.dangerText)
                    }
                }
            }
            .onDelete { offsets in
                member.clues.remove(atOffsets: offsets)
                issue = nil
            }
            if member.clues.count < ProjectEditCastConfig.maxClues {
                Button {
                    member.clues.append(TopicCastClueDraft(text: ""))
                } label: {
                    Label("castMember.addClue", systemImage: "plus")
                }
                .accessibilityIdentifier("projectEdit.castMember.addClue")
            }
        } header: {
            Text("castMember.clues")
        } footer: {
            Text("castMember.clue.footer \(ProjectEditCastConfig.maxClues) \(ProjectEditCastConfig.clueMax)")
        }
    }

    @ViewBuilder private var endingSection: some View {
        Section {
            endingRow("castMember.ending.low", placeholder: "castMember.ending.lowPlaceholder", text: $member.endingLow)
            endingRow("castMember.ending.mid", placeholder: "castMember.ending.midPlaceholder", text: $member.endingMid)
            endingRow("castMember.ending.high", placeholder: "castMember.ending.highPlaceholder", text: $member.endingHigh)
        } header: {
            Text("castMember.ending")
        }
    }

    private func endingRow(_ band: LocalizedStringKey, placeholder: LocalizedStringKey, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            Text(band).font(.subheadline).foregroundStyle(.secondary)
            TextField(placeholder, text: text, axis: .vertical)
                .onChange(of: text.wrappedValue) { _, value in
                    if value.count > ProjectEditCastConfig.endingLineMax { text.wrappedValue = String(value.prefix(ProjectEditCastConfig.endingLineMax)) }
                }
        }
    }

    // MARK: Helpers

    private func chapterLabel(number: Int, name: String) -> Text {
        name.isEmpty ? Text("castMember.clue.chapterNumber \(number)") : Text("castMember.clue.chapter \(number) \(name)")
    }

    private func chapterTag(_ value: ProjectEditJSON) -> String {
        if let number = value.integer { return "n:\(number)" }
        return "s:\(value.text ?? "")"
    }

    private func clueText(_ index: Int) -> Binding<String> {
        Binding(get: { member.clues.indices.contains(index) ? member.clues[index].text : "" },
                set: { value in
                    guard member.clues.indices.contains(index) else { return }
                    member.clues[index].text = String(value.prefix(ProjectEditCastConfig.clueMax))
                    if issue == .clueEmpty(index) { issue = nil }
                })
    }

    private func clueChapter(_ index: Int) -> Binding<String> {
        Binding(get: {
            guard member.clues.indices.contains(index), let value = member.clues[index].chapterID else { return "" }
            return chapterTag(value)
        }, set: { tag in
            guard member.clues.indices.contains(index) else { return }
            if tag.isEmpty {
                member.clues[index].chapterID = nil
            } else if let hit = clueChapters.first(where: { chapterTag($0.value) == tag }) {
                member.clues[index].chapterID = hit.value
            }
        })
    }

    /// MP `memberIssues` (story-cast.js) for the fields this page edits, first problem only.
    private func save() {
        if recorder.isRecording {
            recorder.stop(discard: false)
        }
        if uploadingAvatar || uploadingVoice {
            issue = .avatarUploading
            return
        }
        let name = member.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty {
            issue = .nameMissing
            return
        }
        if others.contains(where: { $0.id != member.id && $0.name.trimmingCharacters(in: .whitespacesAndNewlines) == name }) {
            issue = .nameTaken(name)
            return
        }
        if let empty = member.clues.firstIndex(where: { $0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            issue = .clueEmpty(empty)
            return
        }
        var saved = member
        saved.name = name
        if saved.colorHex == nil {
            let used = others.compactMap(\.colorHex)
            saved.colorHex = ProjectEditCastConfig.colors.first { !used.contains($0) } ?? ProjectEditCastConfig.colors.first
        }
        onSave(saved)
        dismiss()
    }
}

/// MP `cast-face`: the role's colour disc with the first character of its name (`initialOf`).
struct ProjectEditCastFace: View {
    enum Size { case medium, large }
    let name: String
    let colorHex: String?
    let size: Size
    /// MP story-cast.js `shownAvatar`: only an `https://` photo is drawn; `media-asset:` ids keep the initial.
    var imageURL: String? = nil
    /// The photo just picked in 编辑角色 (MP `avatarPreview`), shown before the saved URL loads.
    var localImage: UIImage? = nil

    @ScaledMetric(relativeTo: .body) private var mediumSide: CGFloat = 36
    @ScaledMetric(relativeTo: .largeTitle) private var largeSide: CGFloat = 72

    var body: some View {
        let side = size == .large ? largeSide : mediumSide
        Circle()
            .fill(Self.color(for: colorHex))
            .frame(width: side, height: side)
            .overlay {
                Text(verbatim: initial)
                    .font(size == .large ? .title.weight(.semibold) : .headline)
                    .foregroundStyle(.white)
            }
            .overlay { photo }
            .clipShape(Circle())
            .accessibilityHidden(true)
    }

    @ViewBuilder private var photo: some View {
        if let localImage {
            Image(uiImage: localImage)
                .resizable()
                .scaledToFill()
                .accessibilityHidden(true)
        } else if let remoteURL {
            AsyncImage(url: remoteURL) { phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .scaledToFill()
                }
            }
        }
    }

    private var remoteURL: URL? {
        guard let imageURL, imageURL.hasPrefix("https://") else { return nil }
        return URL(string: imageURL)
    }

    private var initial: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.first.map { String($0).uppercased() } ?? "?"
    }

    /// The six MP contract colours (story-cast.js COLORS) shown as their system-colour counterparts.
    static func color(for hex: String?) -> Color {
        guard let hex, let index = ProjectEditCastConfig.colors.firstIndex(of: hex) else { return .gray }
        let system: [Color] = [.red, .blue, .green, .pink, .orange, .gray]
        return system[index]
    }
}

/// MP theme-cast.js `pickCastAvatar` upload: one sanitized photo → the editor's approved `api/common/uploadOSS`
/// (`ProjectStoryImageUploading`, the same path as story pictures) → the returned reference for `avatarUrl`.
public struct ProjectEditCastAvatarUpload {
    public let upload: @MainActor (RetainedSelectedImage) async throws -> String

    public init(upload: @escaping @MainActor (RetainedSelectedImage) async throws -> String) {
        self.upload = upload
    }

    /// nil when the editor cannot upload (read-only, no session, no approved picker): 上传头像 is not shown.
    @MainActor static func make(_ model: ProjectEditModel) -> ProjectEditCastAvatarUpload? {
        guard !model.coordinator.isReadOnly, let source = model.coordinator.storyImageSource,
              let session = model.coordinator.session,
              source.isCurrent(session: session), source.permitsPicker(session: session) else { return nil }
        return ProjectEditCastAvatarUpload { image in
            guard source.isCurrent(session: session) else { throw ProjectStoryImageFailure.changedContext }
            return try await source.upload(image, attemptID: UUID(), session: session).reference
        }
    }
}
