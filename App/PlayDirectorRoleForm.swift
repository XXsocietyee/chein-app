import SwiftUI
import QuestifyCore

/// MP `pages/club/components/club-director-role-sheet` (D6, topic-detail wxml:372-401; director.js:121-160, 311-334,
/// 1062-1224; index.js:919-933): 角色分配 · 成员 → 选择成员 (same team once one is picked) → 分配角色 → 角色接管
/// (confirmed roles) → 确认分配. Picking a 角色接管 row asks 接管给 (same-team members without a role) and a
/// required 接管原因 (200 字), then 确认接管 / 取消接管.
enum PlayDirectorRoles {
    static let reasonLimit = 200

    struct Member: Identifiable, Equatable {
        var id: String { String(teamID) + ":" + String(memberID) }
        let teamID: Int
        let memberID: Int
        let name: String?
        let roleCode: String?
        let roleName: String?
        let confirmed: Bool
    }

    struct Option: Identifiable, Equatable {
        var id: String { code }
        let code: String
        let label: String
    }

    /// director.js:121-138 `roleView` + 147-160 `roleMemberRows`: members with both ids; one team once a member is picked.
    static func members(_ projection: PlayDirectorProjection, teamID: Int? = nil) -> [Member] {
        projection.roles.compactMap { row in
            guard let team = row["teamId"].integer, let member = row["memberId"].integer else { return nil }
            if let teamID, teamID > 0, team != teamID { return nil }
            let code = PlayDirectorProjection.roleCode(row).flatMap { $0.isEmpty ? nil : $0 }
            let status = (row["confirmationStatus"].text ?? row["status"].text ?? "").uppercased()
            return Member(teamID: team, memberID: member,
                          name: text(row, ["memberName", "name"]),
                          roleCode: code,
                          roleName: text(row, ["roleName", "roleLabel"]) ?? code,
                          confirmed: code != nil && status == "CONFIRMED")
        }
    }

    /// director.js:113-119 `roleOptionView`.
    static func options(_ projection: PlayDirectorProjection) -> [Option] {
        projection.roleOptions.compactMap { row in
            guard let code = PlayDirectorProjection.roleCode(row), !code.isEmpty else { return nil }
            return Option(code: code, label: text(row, ["roleName", "name", "label"]) ?? code)
        }
    }

    /// index.js:919-933: 角色接管 lists confirmed roles only.
    static func takeoverSources(_ projection: PlayDirectorProjection) -> [Member] {
        members(projection).filter(\.confirmed)
    }

    /// director.js:1167-1171: same team, not the source, no role yet.
    static func takeoverTargets(_ projection: PlayDirectorProjection, source: Member) -> [Member] {
        members(projection, teamID: source.teamID).filter { $0.memberID != source.memberID && $0.roleCode == nil }
    }

    /// director.js:1144-1147.
    static func assignPayload(teamID: Int, memberID: Int, roleCode: String) -> [String: PlayWireValue]? {
        guard teamID > 0, memberID > 0, !roleCode.isEmpty else { return nil }
        return ["teamId": .int(teamID), "assignments": .array([.object(["memberId": .int(memberID), "roleCode": .string(roleCode)])])]
    }

    /// director.js:317-334 `takeoverPayload`: a confirmed source, a role-less same-team target, a 1-200 字 reason.
    static func takeoverPayload(_ projection: PlayDirectorProjection, source: Member, targetMemberID: Int, reason: String) -> [String: PlayWireValue]? {
        let trimmed = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard source.confirmed, !trimmed.isEmpty, trimmed.count <= reasonLimit,
              takeoverTargets(projection, source: source).contains(where: { $0.memberID == targetMemberID }) else { return nil }
        return ["teamId": .int(source.teamID), "sourceMemberId": .int(source.memberID),
                "targetMemberId": .int(targetMemberID), "reason": .string(trimmed)]
    }

    private static func text(_ value: PlayWireValue, _ keys: [String]) -> String? {
        for key in keys {
            if let text = value[key].text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty { return text }
        }
        return nil
    }
}

/// The role sections of `PlayDirectorCommandEditor`; the editor keeps the review → confirm → submit path.
@MainActor struct PlayDirectorRoleSections: View {
    let projection: PlayDirectorProjection
    let canTakeover: Bool
    @Binding var teamID: Int
    @Binding var memberID: Int
    @Binding var roleCode: String
    @Binding var takeoverSource: String
    @Binding var takeoverTarget: Int
    @Binding var reason: String

    var body: some View {
        Section {
            ForEach(PlayDirectorRoles.members(projection, teamID: teamID)) { member in
                memberRow(member)
            }
        } header: {
            Text("playx.director.role.members")
        }
        let options = PlayDirectorRoles.options(projection)
        if !options.isEmpty {
            Section {
                Picker("playx.director.role.assign", selection: $roleCode) {
                    ForEach(options) { option in
                        Text(verbatim: option.label).tag(option.code)
                    }
                }
                .labelsHidden()
                .cyAdaptiveSegmented()
                .accessibilityIdentifier("playx.director.role.options")
            } header: {
                Text("playx.director.role.assign")
            }
        }
        let sources = canTakeover ? PlayDirectorRoles.takeoverSources(projection) : []
        if !sources.isEmpty {
            Section {
                ForEach(sources) { source in
                    takeoverRow(source)
                }
                if let source = sources.first(where: { $0.id == takeoverSource }) {
                    takeoverFields(source)
                }
            } header: {
                Text("playx.director.role.takeover")
            }
        }
    }

    private func memberRow(_ member: PlayDirectorRoles.Member) -> some View {
        let on = member.teamID == teamID && member.memberID == memberID
        return Button {
            pick(member)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    memberName(member).foregroundStyle(.primary)
                    roleLine(member).font(.footnote).foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                if on {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)
                }
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
        .accessibilityIdentifier("playx.director.role.member.\(member.id)")
    }

    private func takeoverRow(_ source: PlayDirectorRoles.Member) -> some View {
        let on = source.id == takeoverSource
        return Button {
            openTakeover(source)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    memberName(source).foregroundStyle(.primary)
                    roleLine(source).font(.footnote).foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Image(systemName: on ? "checkmark" : "arrow.left.arrow.right")
                    .foregroundStyle(on ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
        .accessibilityIdentifier("playx.director.role.takeover.\(source.id)")
    }

    @ViewBuilder private func takeoverFields(_ source: PlayDirectorRoles.Member) -> some View {
        let targets = PlayDirectorRoles.takeoverTargets(projection, source: source)
        if targets.isEmpty {
            Text("playx.director.role.noTargets").foregroundStyle(.secondary)
        } else {
            Picker("playx.director.role.takeoverTo", selection: $takeoverTarget) {
                ForEach(targets) { target in
                    memberName(target).tag(target.memberID)
                }
            }
            .accessibilityIdentifier("playx.director.role.takeoverTo")
            TextField("playx.director.role.reasonPlaceholder", text: $reason, axis: .vertical)
                .lineLimit(2...5)
                .accessibilityIdentifier("playx.director.role.reason")
                .onChange(of: reason) { _, newValue in
                    if newValue.count > PlayDirectorRoles.reasonLimit {
                        reason = String(newValue.prefix(PlayDirectorRoles.reasonLimit))
                    }
                }
            Button("playx.director.role.cancelTakeover", role: .cancel) { takeoverSource = "" }
                .accessibilityIdentifier("playx.director.role.cancelTakeover")
        }
    }

    @ViewBuilder private func memberName(_ member: PlayDirectorRoles.Member) -> some View {
        if let name = member.name { Text(verbatim: name) } else { Text("playx.director.role.memberFallback") }
    }

    @ViewBuilder private func roleLine(_ member: PlayDirectorRoles.Member) -> some View {
        if let name = member.roleName, member.roleCode != nil {
            Text(verbatim: name)
        } else {
            Text("playx.director.role.unassigned")
        }
    }

    /// director.js:1070-1100 `openRoleRow`: the member's current role is preselected, else the first option.
    private func pick(_ member: PlayDirectorRoles.Member) {
        teamID = member.teamID
        memberID = member.memberID
        let options = PlayDirectorRoles.options(projection)
        if let code = member.roleCode, options.contains(where: { $0.code == code }) {
            roleCode = code
        } else {
            roleCode = options.first?.code ?? ""
        }
    }

    /// director.js:1150-1190 `openTakeoverRole`: the first same-team role-less member is preselected.
    private func openTakeover(_ source: PlayDirectorRoles.Member) {
        takeoverSource = source.id
        takeoverTarget = PlayDirectorRoles.takeoverTargets(projection, source: source).first?.memberID ?? 0
        reason = ""
    }
}
