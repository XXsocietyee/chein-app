import SwiftUI

@MainActor private final class NativeFriendMetadataViewModel: ObservableObject {
    let flow: NativeFriendMetadataFlow
    init(_ flow: NativeFriendMetadataFlow, onApplied: @escaping () -> Void) {
        self.flow = flow; flow.onChange = { [weak self] in self?.objectWillChange.send() }; flow.onApplied = onApplied
    }
}

/// Opened only from a real row in the normal friends list. No numeric peer entry or parallel relationship store.
@MainActor struct NativeFriendMetadataView: View {
    @Environment(\.locale) private var locale
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var model: NativeFriendMetadataViewModel
    let nickname: String
    @State private var confirmingSettlement = false
    @State private var visit: UUID?
    @State private var visible = false
    @State private var settlementIdentity: NativeFriendMetadataFlow.PendingIdentity?
    @State private var remark = ""
    @State private var groupID: Int64?
    @State private var starred = false
    @State private var sharesProgress = false
    @State private var editingGroupID: Int64?
    @State private var groupName = ""
    @State private var position = 1
    @State private var deletingGroupID: Int64?
    @State private var destinationID: Int64?
    init(flow: NativeFriendMetadataFlow, nickname: String, onApplied: @escaping () -> Void = {}) {
        _model = StateObject(wrappedValue: NativeFriendMetadataViewModel(flow, onApplied: onApplied)); self.nickname = nickname
    }
    private var flow: NativeFriendMetadataFlow { model.flow }
    private enum Focus { case confirm, recover, remark, saveGroup, delete }
    /// One primary pill. A pending review wins, then recovery, then the group editor, then the remark review.
    private var focus: Focus? {
        if flow.review != nil { return .confirm }
        if flow.pending != nil { return .recover }
        if flow.isCurrent, !flow.groups.isEmpty, deletingGroupID != nil { return .delete }
        if flow.canPresentPeer, flow.metadata != nil { return .remark }
        if flow.isCurrent, !flow.groups.isEmpty { return .saveGroup }
        return nil
    }
    private func isPrimary(_ candidate: Focus) -> Bool {
        focus == candidate && candidate != .delete
    }
    var body: some View {
        Form {
            if flow.canPresentPeer { Section {
                Label(nickname, systemImage: "person.crop.circle")
            } }
            if flow.busy {
                ProgressView { Text("cy.state.loading") }
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("friendMeta.loading")
            }
            if !flow.isCurrent { notice("friendMeta.closed") }
            if let issue = flow.issue { notice(issue, symbol: "exclamationmark.triangle", identifier: "friendMeta.issue") }
            if flow.isCurrent, let recoveryIssue = flow.recoveryIssue { notice(recoveryIssue, identifier: "friendMeta.recoveryIssue") }
            if flow.pending != nil {
                Section {
                    if !flow.hasResolvedPending { notice("friendMeta.unknown") }
                    metaAction(flow.hasResolvedPending ? "friendMeta.retryCleanup" : "friendMeta.recover", prominent: isPrimary(.recover), enabled: flow.canRecover, identifier: "friendMeta.recover") {
                        performPresented { await flow.recover() }
                    }
                }
            }
            if flow.isCurrent, flow.resolvedIdentity != nil {
                if flow.didApply {
                    Label(localized("friendMeta.saved"), systemImage: "checkmark")
                        .foregroundStyle(CYColor.successText)
                        .accessibilityIdentifier("friendMeta.saved")
                } else {
                    Label(localized("friendMeta.notApplied"), systemImage: "circle")
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("friendMeta.notApplied")
                }
            }
            if let command = flow.review {
                Section {
                    reviewDetails(command)
                    metaAction("friendMeta.confirm", prominent: isPrimary(.confirm), enabled: flow.canConfirm, identifier: "friendMeta.confirm") {
                        performPresented { await flow.confirm(expected: command) }
                    }
                    metaAction("friendMeta.cancel", prominent: false, enabled: !flow.busy) { flow.cancelReview() }
                } header: { sectionTitle("friendMeta.reviewTitle") }
            }
            if flow.canPresentPeer && flow.metadata != nil {
                Section {
                    TextField(localized("d7.friendMeta.remarkPrompt"), text: $remark)
                        .textContentType(.nickname)
                        .submitLabel(.done)
                        .accessibilityIdentifier("friendMeta.remark")
                    metaAction("friendMeta.review", prominent: isPrimary(.remark), enabled: flow.canEdit, identifier: "friendMeta.review") {
                        flow.reviewMetadata(remark: remark, groupID: nil, starred: false)
                    }
                } header: { sectionTitle("friendMeta.preferences") }.disabled(!flow.canEdit)
                if !flow.groups.isEmpty {
                    Section {
                        Picker(localized("friendMeta.group"), selection: $groupID) {
                            text("friendMeta.defaultGroup").tag(Int64?.none)
                            ForEach(flow.groups.filter { $0.isDefault == 0 }) { group in groupLabel(group).tag(group.id) }
                        }
                        metaAction("friendMeta.review", prominent: false, enabled: flow.canAssignGroup) { flow.reviewAssignment(groupID) }
                    } header: { sectionTitle("friendMeta.group") }.disabled(!flow.canAssignGroup)
                }
                Section {
                    Toggle(isOn: $starred) { text("friendMeta.starred") }.accessibilityIdentifier("friendMeta.starred")
                    metaAction("friendMeta.review", prominent: false, enabled: flow.canEditStar, identifier: "friendMeta.reviewStar") { flow.reviewStar(starred) }
                }.disabled(!flow.canEditStar)
                Section {
                    Toggle(isOn: $sharesProgress) { text("d7.friendMeta.shareProgress") }
                    metaAction("friendMeta.review", prominent: false, enabled: flow.canEditProgress) { flow.reviewProgress(sharesProgress) }
                }.disabled(!flow.canEditProgress)
            }
            if flow.isCurrent && !flow.groups.isEmpty {
                Section {
                    ForEach(flow.groups) { group in
                        HStack {
                            groupLabel(group)
                            Spacer(minLength: 8)
                            if let count = group.friendCount {
                                Text("d7.friendMeta.friendCount \(count)", tableName: "NativeFriendMetadata")
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            } else {
                                Text(verbatim: "—")
                                    .foregroundStyle(.tertiary)
                            }
                            if group.isDefault == 0 {
                                Menu {
                                    Button { editingGroupID=group.id;groupName=group.name;position=group.position } label: {
                                        Label { text("friendMeta.rename") } icon: { Image(systemName: "pencil") }
                                    }
                                    Button(role: .destructive) { deletingGroupID=group.id;destinationID=nil } label: {
                                        Label { text("friendMeta.delete") } icon: { Image(systemName: "trash") }
                                    }
                                } label: {
                                    Image(systemName: "ellipsis.circle")
                                        .accessibilityLabel(Text("friendMeta.rename", tableName: "NativeFriendMetadata"))
                                }
                                .buttonStyle(.borderless)
                                .disabled(!flow.canManageGroups)
                            }
                        }
                    }
                } header: { sectionTitle("d7.friendMeta.myGroups") }
                Section {
                    TextField(localized("friendMeta.groupName"),text:$groupName).submitLabel(.done)
                    Stepper(value:$position,in:0...Int(Int32.max)) { Text("d7.friendMeta.order \(position)", tableName: "NativeFriendMetadata").monospacedDigit() }
                    metaAction(editingGroupID == nil ? "friendMeta.createGroup" : "friendMeta.saveGroup", prominent: isPrimary(.saveGroup), enabled: flow.canManageGroups) {
                        flow.reviewGroup(id:editingGroupID,name:groupName,position:position)
                    }
                    if editingGroupID != nil {
                        metaAction("friendMeta.newGroup", prominent: false, enabled: flow.canManageGroups) { editingGroupID=nil;groupName="";position=1 }
                    }
                } header: { sectionTitle(editingGroupID == nil ? "friendMeta.pendingGroupCreate" : "friendMeta.pendingGroupEdit") }
                    .disabled(!flow.canManageGroups)
                if let source=deletingGroupID {
                    Section {
                        groupNameLabel(source)
                        Picker(localized("friendMeta.moveTo"),selection:$destinationID) {
                            text("friendMeta.defaultGroup").tag(Int64?.none)
                            ForEach(flow.groups.filter { $0.isDefault == 0 && $0.id != source }) { group in groupLabel(group).tag(group.id) }
                        }
                        Button(role:.destructive) { flow.reviewDeleteGroup(id:source,moveTo:destinationID) } label: { text("friendMeta.reviewDelete") }
                        metaAction("friendMeta.cancel", prominent: false, enabled: flow.canManageGroups) { deletingGroupID=nil;destinationID=nil }
                    } header: { sectionTitle("friendMeta.delete") }.disabled(!flow.canManageGroups)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(Text(LocalizedStringKey(flow.peerID == 0 ? "friendMeta.recoveryEntry" : "friendMeta.title"), tableName: "NativeFriendMetadata"))
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("friendMeta.editor").privacySensitive()
        .transaction { if reduceMotion { $0.disablesAnimations = true } }
        .onAppear { visible = true }
        .task {
            // Removal already loads from .task. Gating this read on scenePhase == .active
            // drops it when a nested push is only .inactive, so the editor never becomes ready.
            visible = true
            guard scenePhase != .background else { return }
            visit = UUID()
            await flow.load()
            if visible { synchronize() }
        }
        .onChange(of: flow.metadata) { _, _ in synchronize() }
        .onChange(of: flow.groups) { _, _ in
            if let id = editingGroupID, !flow.groups.contains(where: { $0.id == id }) { editingGroupID = nil; groupName = "" }
            deletingGroupID = nil; destinationID = nil
        }
        .refreshable { if !flow.busy { performPresented { await flow.load() } } }
        .onDisappear { visible = false; retirePresentation() }
        .onChange(of: flow.isCurrent) { _, current in if !current { retirePresentation() } }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                guard visible else { return }
                visit = UUID()
                performPresented { await flow.load() }
            case .background:
                retirePresentation()
            case .inactive:
                break
            @unknown default:
                break
            }
        }
    }
    private func metaAction(_ key: String, prominent: Bool, enabled: Bool, identifier: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(LocalizedStringKey(key), tableName: "NativeFriendMetadata")
                .fontWeight(prominent ? .semibold : .regular)
        }
            .disabled(!enabled)
            .modifier(CYOptionalAccessibilityIdentifier(identifier: identifier))
    }
    private func sectionTitle(_ key: String) -> Text {
        text(key)
    }
    private func notice(_ key: String, symbol: String? = nil, identifier: String? = nil) -> some View {
        Label {
            text(key)
                .foregroundStyle(.secondary)
                .modifier(CYOptionalAccessibilityIdentifier(identifier: identifier))
        } icon: {
            if let symbol {
                Image(systemName: symbol)
                    .foregroundStyle(.orange)
                    .accessibilityHidden(true)
            }
        }
    }
    private func performPresented(_ action: @escaping @MainActor () async -> Void) {
        guard visible, scenePhase == .active, let capturedVisit = visit else { return }
        let capturedFlow = flow
        Task { @MainActor in
            guard visible, scenePhase == .active, visit == capturedVisit, flow === capturedFlow else { return }
            await action()
            guard visible, scenePhase == .active, visit == capturedVisit, flow === capturedFlow else { return }
            synchronize()
        }
    }
    private func retirePresentation() { visit = nil; clearDraft(); flow.invalidate() }
    private func clearDraft() { remark = ""; groupID = nil; starred = false; sharesProgress = false; groupName = ""; editingGroupID = nil; deletingGroupID = nil; destinationID = nil; confirmingSettlement = false; settlementIdentity = nil }
    private func synchronize() { if flow.peerID == 0 { if !flow.isCurrent { clearDraft() };return };guard flow.canPresentPeer, let value = flow.metadata else { clearDraft(); return }; remark = value.remark ?? ""; starred = value.starred == 1; sharesProgress = value.progressScope == 1; groupID = value.groupID }
    @ViewBuilder private func reviewDetails(_ command: NativeFriendMetadataCommand) -> some View {
        switch command.action {
        case .remark:
            if command.updatesRemark {
                LabeledContent { Text(verbatim: command.remark ?? localized("friendMeta.nicknameFallback")) } label: { text("friendMeta.remark") }
            }
            if let scope = command.progressScope {
                LabeledContent { text(scope == 1 ? "friendMeta.starredOn" : "friendMeta.starredOff") } label: { text("d7.friendMeta.shareProgress") }
            }
            if command.updatesGroup { LabeledContent { groupNameLabel(command.groupID) } label: { text("friendMeta.group") } }
            if let starred = command.starred {
                LabeledContent { text(starred == 1 ? "friendMeta.starredOn" : "friendMeta.starredOff") } label: { text("friendMeta.starred") }
            }
        case .groupSave:
            LabeledContent { Text(verbatim: command.name ?? "—") } label: { text("friendMeta.groupName") }
            LabeledContent { Text(verbatim: command.position.map(String.init) ?? "—").monospacedDigit() } label: { text("friendMeta.position") }
        case .groupDelete:
            LabeledContent { groupNameLabel(command.targetID) } label: { text("friendMeta.delete") }
            LabeledContent { groupNameLabel(command.groupID) } label: { text("friendMeta.moveTo") }
        }
    }
    @ViewBuilder private func groupNameLabel(_ id: Int64?) -> some View {
        if let group = flow.groups.first(where: { $0.id == id }) { groupLabel(group) } else { text("friendMeta.defaultGroup") }
    }
    @ViewBuilder private func groupLabel(_ group: NativeFriendMetadataGroup) -> some View {
        if group.isDefault == 1 { text("friendMeta.defaultGroup") } else { Text(verbatim: group.name.isEmpty ? "—" : group.name) }
    }
    private func localized(_ key: String) -> String {
        String(localized: LocalizedStringResource(String.LocalizationValue(stringLiteral: key), table: "NativeFriendMetadata", locale: locale))
    }
    private func text(_ key: String) -> Text { Text(LocalizedStringKey(key), tableName: "NativeFriendMetadata") }
}
