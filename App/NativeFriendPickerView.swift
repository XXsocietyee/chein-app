import SwiftUI

/// F31 explicit, bounded picker over the SAME original F16 partitions; no recommendation, contact discovery or automatic selection.
@MainActor struct NativeFriendPickerView: View {
    @Environment(\.cyPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let flow: any NativeFriendPickerSource
    @State private var search = ""
    private var visible: [NativeFriendPickerItem] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return query.isEmpty ? flow.items : flow.items.filter { $0.friend.displayName.localizedCaseInsensitiveContains(query) || $0.friend.nickname.localizedCaseInsensitiveContains(query) }
    }
    var body: some View {
        Section {
            HStack {
                Text("d7.friendPicker.selected \(flow.selected.count)")
                    .font(CYTypography.numericBody)
                    .foregroundStyle(palette.textSecondary)
                    .monospacedDigit()
                Spacer(minLength: CYSpacing.sm)
            }
            .accessibilityElement(children: .combine)
            Picker("d7.friendPicker.section", selection: Binding(get: { flow.section }, set: { next in search = ""; Task { await flow.chooseSection(next) } })) {
                Text("d7.friendPicker.together").tag(NativeFriendDirectorySection.together)
                Text("d7.friendPicker.recent").tag(NativeFriendDirectorySection.recent)
                Text("d7.friendPicker.all").tag(NativeFriendDirectorySection.all)
            }
            .pickerStyle(.segmented).labelsHidden()
            .disabled(flow.busy || flow.hasPickerReview)
            HStack(spacing: CYSpacing.sm) {
                Image(systemName: "magnifyingglass").foregroundStyle(palette.textTertiary).accessibilityHidden(true)
                TextField("d7.friendPicker.search", text: $search)
                    .font(CYTypography.body)
                    .disabled(flow.busy)
            }
            .frame(minHeight: CYSpacing.minTouchTarget)
            if flow.busy && visible.isEmpty {
                CYSkeleton().accessibilityLabel(Text("cy.state.loading"))
            }
            ForEach(visible) { row in
                let name = shownName(row)
                Button { flow.toggle(row) } label: {
                    HStack(spacing: CYSpacing.md) {
                        personArt(name)
                        VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                            Text(verbatim: name)
                                .font(CYTypography.cardTitle)
                                .foregroundStyle(palette.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                            if row.alreadyMember {
                                Text("d7.friendPicker.unavailable")
                                    .font(CYTypography.meta)
                                    .foregroundStyle(palette.textTertiary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        Spacer(minLength: CYSpacing.sm)
                        Image(systemName: flow.selected.contains(row) ? "checkmark.circle.fill" : "circle")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(flow.selected.contains(row) ? palette.textPrimary : palette.textTertiary)
                            .accessibilityHidden(true)
                    }
                    .frame(minHeight: CYSpacing.minTouchTarget)
                    .contentShape(Rectangle())
                }
                .modifier(FriendPickerSelectionTrait(selected: flow.selected.contains(row)))
                .disabled(!flow.canWrite || row.alreadyMember || (!flow.selected.contains(row) && flow.selected.count >= 10) || flow.hasPickerReview)
            }
            if visible.isEmpty && !flow.busy { CYEmptyState(systemImage: "person.2", "d7.friendPicker.empty") }
            CYPillButton("d7.friendPicker.next", systemImage: "arrow.right") { flow.prepareCreate() }
                .disabled(!flow.canWrite || flow.selected.isEmpty || flow.hasPickerReview)
                .listRowBackground(Color.clear)
        } header: {
            CYSectionHeader("d7.friendPicker.title")
        }
        .font(CYTypography.body)
        .onChange(of: flow.isCurrent) { _, valid in if !valid { search = "" } }
        .onDisappear { search = "" }
        .privacySensitive()
        .transaction { if reduceMotion { $0.disablesAnimations = true } }
        .tint(palette.brand)
    }
    private func shownName(_ row: NativeFriendPickerItem) -> String {
        let name = row.friend.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "—" : name
    }
    private func personArt(_ seed: String) -> some View {
        Color.clear
            .frame(width: 40, height: 40)
            .overlay { CYCoverArt(seed: seed == "—" ? "friend" : seed, symbol: "person.fill", showsDebugLabel: false) }
            .clipShape(RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous))
            .accessibilityHidden(true)
    }
}

private struct FriendPickerSelectionTrait: ViewModifier {
    let selected: Bool
    func body(content: Content) -> some View {
        if selected { content.accessibilityAddTraits(.isSelected) } else { content }
    }
}

/// Maps the team/channel invitation flows' fixed status sentences to short player copy.
/// The compared literals are the exact values those flows assign; anything else reads as a load failure.
func nativeFriendInviteIssueKey(_ issue: String) -> LocalizedStringKey {
    switch issue {
    case "原请求已记录；以下状态仍以当前原成员来源为准。", "已确认同一原请求；当前成员权限仍需单独读取。":
        return "d7.friendInvite.done"
    case "原请求已被拒绝；未替你重试或扩大资格。", "原请求已明确拒绝并回滚；没有自动重发或创建邀请。":
        return "d7.friendInvite.rejected"
    case "未发送；请重新读取当前资格后再确认。", "本次未发送。", "原请求未能可靠保存，本次未发送。",
         "原请求保护记录不可确认，未发送新操作。", "原请求保护记录暂不可确认，不发送新操作。":
        return "d7.friendInvite.notSent"
    case "原请求结果未知，保留同一请求，仅回读，不重发。", "原回执仍不可确认，保护记录继续保留，不重发。",
         "原操作结果未确认；保留同一请求，只回读，不重发。", "原记录仍为 UNKNOWN；不会改请求号或自动重发。",
         "原请求仍待核对；保护记录保留。", "原保护记录待核对。":
        return "d7.friendInvite.unknown"
    case "原好友或队长/成员来源已变化，未沿用旧名单。", "原好友分区/成员资格已变化或不可读，未用旧名单代替。":
        return "d7.friendInvite.changed"
    default:
        return "d7.friendInvite.loadFailure"
    }
}
