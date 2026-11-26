import SwiftUI

@MainActor final class ClubRoleAssignmentReadModel: ObservableObject {
    struct Permit: Equatable { let context: ClubGovernanceReadContext; let visibility: UUID }
    @Published private(set) var options: ClubRoleAssignmentOptions?
    @Published private(set) var loading = false
    @Published private(set) var failure: ClubGovernanceFailure?
    private var bound: ClubGovernanceReadContext?
    private var loaded: ClubGovernanceReadContext?
    private var visibility: UUID?
    private var generation = UUID()
    private(set) var snapshotID = UUID()
    static func context(scope: ClubGovernanceScope, identity: ClubReadIdentity?, access: any ClubGovernanceAccess) -> ClubGovernanceReadContext {
        .init(operation: .roles, scope: scope, identity: identity, viewerRevision: 0,
              authorizationGeneration: access.authorizationGeneration, accessIdentity: ObjectIdentifier(access))
    }
    func bind(_ context: ClubGovernanceReadContext) {
        guard bound != context else { return }
        bound = context; visibility = nil; generation = UUID()
    }
    func activate(_ context: ClubGovernanceReadContext) -> Permit? {
        guard bound == context, !Task.isCancelled else { return nil }
        if visibility == nil {
            visibility = UUID(); generation = UUID(); snapshotID = UUID()
            loaded = nil; options = nil; loading = false; failure = nil
        }
        return permit(in: context)
    }
    func permit(in context: ClubGovernanceReadContext) -> Permit? {
        guard bound == context, let visibility else { return nil }
        return .init(context: context, visibility: visibility)
    }
    private func accepts(_ permit: Permit) -> Bool { bound == permit.context && visibility == permit.visibility }
    private func live(_ context: ClubGovernanceReadContext, access: any ClubGovernanceAccess) -> Bool {
        context.operation == .roles && (context.scope.clubID ?? 0) > 0 && context.identity?.isSignedIn == true &&
            access.isConfigured && context.identity == access.identity &&
            context.authorizationGeneration == access.authorizationGeneration && context.accessIdentity == ObjectIdentifier(access)
    }
    func accepted(_ context: ClubGovernanceReadContext, access: any ClubGovernanceAccess) -> ClubRoleAssignmentOptions? {
        guard permit(in: context) != nil, loaded == context, !loading, live(context, access: access) else { return nil }
        return options
    }
    func canSelect(_ options: ClubRoleAssignmentOptions, snapshotID: UUID, permit: Permit, access: any ClubGovernanceAccess) -> Bool {
        accepts(permit) && self.snapshotID == snapshotID && accepted(permit.context, access: access) == options
    }
    func canPrepare(scope: ClubGovernanceScope, identity: ClubReadIdentity?, access: any ClubGovernanceAccess,
                    memberID: String, roleCode: String) -> Bool {
        let context = Self.context(scope: scope, identity: identity, access: access)
        return accepted(context, access: access)?.contains(memberID: Int(memberID), roleCode: roleCode) == true
    }
    func leave(_ context: ClubGovernanceReadContext) {
        guard bound == context else { return }
        visibility = nil; generation = UUID(); snapshotID = UUID(); loaded = nil
        options = nil; loading = false; failure = nil
    }
    func load(_ permit: Permit, access: any ClubGovernanceAccess) async {
        guard accepts(permit), !Task.isCancelled else { return }
        guard live(permit.context, access: access) else {
            options = nil; loaded = nil; failure = access.identity?.isSignedIn == true ? .notConfigured : .signedOut
            loading = false; return
        }
        generation = UUID(); let request = generation
        snapshotID = UUID(); loaded = nil; options = nil; failure = nil; loading = true
        defer { if generation == request && accepts(permit) { loading = false } }
        func check() throws {
            guard accepts(permit), generation == request, live(permit.context, access: access), !Task.isCancelled else { throw CancellationError() }
        }
        do {
            try check()
            let roles = try await access.read(.roles, scope: permit.context.scope, options: [:], check: check)
            try check()
            guard roles.operation == .roles, roles.scope == permit.context.scope, roles.permissions != nil else { throw ClubGovernanceFailure.malformed }
            guard roles.permissions?.allows("ROLES", scope: permit.context.scope) == true else { throw ClubGovernanceFailure.forbidden }
            let members = try await access.read(.members, scope: permit.context.scope, options: [:], check: check)
            try check()
            guard members.permissions != nil else { throw ClubGovernanceFailure.malformed }
            guard members.permissions?.allows("ROLES", scope: permit.context.scope) == true else { throw ClubGovernanceFailure.forbidden }
            let projected = try ClubRoleAssignmentOptions(roles: roles, members: members, context: permit.context)
            loaded = permit.context; options = projected
        } catch {
            guard accepts(permit), generation == request, live(permit.context, access: access), !Task.isCancelled else { return }
            failure = error as? ClubGovernanceFailure ?? .malformed
        }
    }
}

/// Member / role selectors push inside the command sheet's NavigationStack (no nested sheet).
/// Choice is local; existing prepare/confirm owns every write gate.
@MainActor struct ClubRoleAssignmentPicker: View {
    let scope: ClubGovernanceScope
    let identity: ClubReadIdentity?
    let access: any ClubGovernanceAccess
    @ObservedObject var model: ClubRoleAssignmentReadModel
    @Binding var memberID: String
    @Binding var roleCode: String
    let canEdit: () -> Bool
    var applySelection: (String, String) -> Void = { _, _ in }
    @Environment(\.clubRoleActivityLabel) private var activityLabel
    @Environment(\.clubFocusMemberID) private var focusMemberID
    private var context: ClubGovernanceReadContext { ClubRoleAssignmentReadModel.context(scope: scope, identity: identity, access: access) }
    var body: some View {
        let expected = context
        let permit = model.permit(in: expected)
        // CLB-r10-nat-roles-01: each part is its own Form row (Group, not one VStack row), so each Picker pushes on its own.
        Group {
            VStack(alignment: .leading, spacing: 4) {
                // CLB-roles-02: name the scope, never the activity id (MC-044).
                if scope.activityID != nil {
                    Text("club.rolePicker.eventScopeOnly").cyText(.bodyCompact).accessibilityIdentifier("club.rolePicker.eventScope")
                    // CLB-roles-02: the session by its label (MP activitySubtitle), 未命名 when the entry did not carry one.
                    Group {
                        if let activityLabel { Text(verbatim: activityLabel) } else { Text("club.rolePicker.untitledSession") }
                    }
                    .cyText(.meta).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("club.rolePicker.eventLabel")
                } else { Text("club.rolePicker.clubScope").cyText(.bodyCompact) }
            }
            // CLB-G16 (MP roles js:195, 312): a `memberId` link starts with that member chosen, once the read has it.
            .onChange(of: model.options, initial: true) { _, _ in
                guard memberID.isEmpty, let focusMemberID, canEdit(),
                      let options = model.accepted(context, access: access),
                      options.members.contains(where: { $0.id == focusMemberID }) else { return }
                memberID = String(focusMemberID)
                applySelection(memberID, roleCode)
            }
            if model.loading || permit == nil { ProgressView("club.loading").accessibilityIdentifier("club.rolePicker.loading") }
            if permit != nil, let failure = model.failure {
                Label { Text(LocalizedStringKey(failure.localizationKey)).fixedSize(horizontal: false, vertical: true) } icon: {
                    Image(systemName: failure == .forbidden ? "lock.shield" : "exclamationmark.triangle").accessibilityHidden(true)
                }.accessibilityIdentifier("club.rolePicker.error")
            }
            if let options = model.accepted(expected, access: access), let permit {
                let readID = model.snapshotID
                if options.hasUnverifiedMembers { Text("club.rolePicker.unverified").cyText(.bodyCompact) }
                if options.members.isEmpty { Text("club.rolePicker.empty").accessibilityIdentifier("club.rolePicker.empty") }
                else {
                    // CLB-r10-nat-roles-01 (MP roles wxml:84-91 member / role pickers): one system `Picker(.navigationLink)`
                    // row each; the selection still passes canEdit + canSelect before it is written.
                    memberPicker(options, permit: permit, readID: readID)
                    rolePicker(options, permit: permit, readID: readID)
                }
            }
            if model.failure != .forbidden {
                Button {
                    guard canEdit(), let permit else { return }
                    Task { await model.load(permit, access: access) }
                } label: {
                    Text(LocalizedStringKey(model.failure == nil ? "club.gov.refresh" : "action.retry"))
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .disabled(model.loading || permit == nil).accessibilityIdentifier("club.rolePicker.reload")
            }
        }
    }
    private func memberPicker(_ options: ClubRoleAssignmentOptions, permit: ClubRoleAssignmentReadModel.Permit, readID: UUID) -> some View {
        Picker(selection: Binding(get: { memberID }, set: { picked in
            guard !picked.isEmpty, canEdit(), model.canSelect(options, snapshotID: readID, permit: permit, access: access) else { return }
            memberID = picked
            applySelection(picked, roleCode)
        })) {
            if !options.members.contains(where: { String($0.id) == memberID }) {
                Text("club.rolePicker.unselected").tag(memberID)
            }
            ForEach(options.members) { member in
                memberName(member).tag(String(member.id))
                    .accessibilityIdentifier("club.rolePicker.member.\(member.id)")
            }
        } label: { Text("club.rolePicker.member") }
        .pickerStyle(.navigationLink)
        .accessibilityIdentifier("club.rolePicker.openMembers")
    }
    private func rolePicker(_ options: ClubRoleAssignmentOptions, permit: ClubRoleAssignmentReadModel.Permit, readID: UUID) -> some View {
        Picker(selection: Binding(get: { roleCode }, set: { picked in
            guard !picked.isEmpty, canEdit(), model.canSelect(options, snapshotID: readID, permit: permit, access: access) else { return }
            roleCode = picked
            applySelection(memberID, picked)
        })) {
            if !options.roles.contains(where: { $0.code == roleCode }) {
                Text("club.rolePicker.unselected").tag(roleCode)
            }
            ForEach(options.roles) { role in
                VStack(alignment: .leading, spacing: 4) {
                    Text(verbatim: role.name)
                    Text(LocalizedStringKey(role.summaryKey)).font(.footnote).foregroundStyle(.secondary)
                }
                .tag(role.code)
                .accessibilityIdentifier("club.rolePicker.role.\(role.code)")
            }
        } label: { Text("club.rolePicker.role") }
        .pickerStyle(.navigationLink)
        .accessibilityIdentifier("club.rolePicker.openRoles")
    }
    private func memberName(_ member: ClubRoleAssignableMember) -> some View {
        // CLB-roles-03: the member's name only; a missing name reads 未命名, never 「用户 <id>」.
        // CLB-roles-03 (MP roles wxml:84-91): a monogram avatar leads each member row (the read carries no avatar URL).
        HStack(spacing: CYSpacing.sm) {
            ClubMPAvatar(url: QuestifyCardArtwork.safeURL(member.avatarURL), name: member.nickname ?? "", size: .sm)
                .accessibilityHidden(true)
            if let name = member.nickname { Text(verbatim: name) } else { Text("club.rolePicker.unnamed") }
        }
    }
}
