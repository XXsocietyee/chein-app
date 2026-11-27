import SwiftUI

/// What the 角色 list opens: an existing role (edit) or a fresh one (add, joins the list only on 完成).
struct ProjectEditCastEditTarget: Identifiable {
    let member: TopicCastMemberDraft
    let isNew: Bool
    var id: String { member.id }
}

/// MP `publish/fabu/cast-sheet.wxml` second sheet 编辑角色 (theme-cast.js `_openMember` / `saveCastMember`), stacked on
/// the 角色 sheet: face → 名字* → 一句话身份 → 声音 → 颜色 → 你知道的 → 结局台词 → 删除角色.
/// 完成 stays tappable like the MP (#871): a problem shows in red under its section instead.
/// Not built natively: avatar upload and 用自己的声音录 (no cast uploads in the app yet); a value set on the MP is kept.
struct ProjectEditCastMemberEditor: View {
    let target: ProjectEditCastEditTarget
    /// Other roles in the cast, for the MP duplicate-name rule.
    let others: [TopicCastMemberDraft]
    let chapters: [ProjectEditChapter]
    let onPreviewVoice: ((TopicCastMemberDraft) -> Void)?
    let onSave: (TopicCastMemberDraft) -> Void
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var member: TopicCastMemberDraft
    @State private var issue: Issue?
    @State private var confirmingDelete = false

    enum Issue: Equatable {
        case nameMissing
        case nameTaken(String)
        case clueEmpty(Int)
    }

    init(target: ProjectEditCastEditTarget, others: [TopicCastMemberDraft], chapters: [ProjectEditChapter],
         onPreviewVoice: ((TopicCastMemberDraft) -> Void)?,
         onSave: @escaping (TopicCastMemberDraft) -> Void, onDelete: @escaping () -> Void) {
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
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("fixr8.common.done") { save() }
                        .accessibilityIdentifier("projectEdit.castMember.done")
                }
            }
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

    @ViewBuilder private var faceSection: some View {
        Section {
            HStack {
                Spacer()
                ProjectEditCastFace(name: member.name, colorHex: member.colorHex, size: .large)
                Spacer()
            }
            .listRowBackground(Color.clear)
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
                Text("castMember.nameRequired").foregroundStyle(.red)
            case .nameTaken(let name):
                Text("castMember.nameTaken \(name)").foregroundStyle(.red)
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
                Button {
                    onPreviewVoice(member)
                } label: {
                    Label("fixr8.cast.preview", systemImage: "play.fill")
                }
                .buttonStyle(.borderless)
            }
        }
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
                        Text("castMember.clue.empty \(index + 1)").font(.footnote).foregroundStyle(.red)
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
            .accessibilityHidden(true)
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
