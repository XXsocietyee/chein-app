import SwiftUI

/// MP `pages/club/components/club-director-broadcast-sheet` (topic-detail wxml:403-412, director.js:1226-1367):
/// 发给 N 人 → 范围 全部/队伍/角色 → target rows (N 人 · 已选/选择) → 内容* (50 字) → 发送给 N 人.
/// Group mode only: the per-person avatar strip sends `targetType: MEMBERS`, which `PlayDirectorCommand` does not admit.
enum PlayDirectorBroadcastAudience {
    static let contentLimit = 50

    struct Target: Identifiable {
        let id: String
        let label: String
        let memberCount: Int?
    }

    /// director.js:190 `broadcastTargets`.
    static func targets(_ targetType: String, projection: PlayDirectorProjection) -> [Target] {
        if targetType == "TEAM" {
            return projection.teams.compactMap { team in
                guard let id = team["teamId"].integer else { return nil }
                let name = team["name"].text ?? team["teamName"].text ?? "#\(id)"
                return Target(id: String(id), label: name, memberCount: team["memberCount"].integer)
            }
        }
        if targetType == "ROLE" {
            return projection.roleOptions.compactMap { role in
                guard let code = PlayDirectorProjection.roleCode(role), !code.isEmpty else { return nil }
                let label = role["roleName"].text ?? role["label"].text ?? code
                return Target(id: code, label: label, memberCount: roleCount(code, roles: projection.roles))
            }
        }
        return []
    }

    /// director.js:223 `broadcastRecipientCount`: nil when the server did not send every count (never shown as 0).
    static func recipientCount(_ targetType: String, selectedID: String, projection: PlayDirectorProjection) -> Int? {
        if targetType == "TEAM" {
            return targets("TEAM", projection: projection).first { $0.id == selectedID }?.memberCount
        }
        if targetType == "ROLE" {
            return roleCount(selectedID, roles: projection.roles)
        }
        let teams = projection.teams
        if teams.isEmpty { return nil }
        var sum = 0
        for team in teams {
            guard let count = team["memberCount"].integer else { return nil }
            sum += count
        }
        return sum
    }

    /// director.js:202 `roleRecipientCount`: players without a team have no role and are not counted.
    static func roleCount(_ code: String, roles: [PlayWireValue]) -> Int? {
        let rows = roles.filter { $0["teamId"].integer != nil }
        if rows.isEmpty { return nil }
        let aggregates = rows.allSatisfy { PlayDirectorProjection.roleCode($0) != nil && $0["memberCount"].integer != nil }
        if aggregates {
            var sum = 0
            for row in rows where PlayDirectorProjection.roleCode(row) == code {
                sum += row["memberCount"].integer ?? 0
            }
            return sum
        }
        let assigned = rows.allSatisfy { PlayDirectorProjection.roleCode($0) != nil && $0["memberId"].integer != nil }
        if !assigned { return nil }
        let ids = rows.filter { PlayDirectorProjection.roleCode($0) == code }.compactMap { $0["memberId"].integer }
        return Set(ids).count
    }

    /// director.js:1256 team suffix: 全部 → all teams, 队伍 → 1 队, 角色 → none.
    static func teamCount(_ targetType: String, projection: PlayDirectorProjection) -> Int? {
        if targetType == "ALL" { return projection.teams.count }
        if targetType == "TEAM" { return 1 }
        return nil
    }
}

/// The broadcast sections of `PlayDirectorCommandEditor`; the editor keeps the review → confirm → submit path.
@MainActor struct PlayDirectorBroadcastSections: View {
    let projection: PlayDirectorProjection
    @Binding var targetType: String
    @Binding var teamID: Int
    @Binding var roleCode: String
    @Binding var content: String

    var body: some View {
        Section {
            LabeledContent("playx.director.broadcast.to") { countText }
                .accessibilityIdentifier("playx.director.broadcast.count")
        }
        Section("playx.director.broadcast.scope") {
            Picker("playx.director.broadcast.scope", selection: $targetType) {
                Text("playx.director.broadcast.scope.all").tag("ALL")
                Text("playx.director.broadcast.scope.team").tag("TEAM")
                Text("playx.director.broadcast.scope.role").tag("ROLE")
            }
            .labelsHidden()
            .cyAdaptiveSegmented()
            .accessibilityIdentifier("playx.director.broadcast.scopePicker")
            ForEach(targetRows) { target in
                targetRow(target)
            }
        }
        .onChange(of: targetType) { _, newValue in selectFirst(newValue) }
        .onAppear { selectFirst(targetType) }
        Section {
            TextField("playx.director.broadcast.placeholder", text: $content, axis: .vertical)
                .lineLimit(3...6)
                .accessibilityIdentifier("playx.director.broadcast.content")
                .onChange(of: content) { _, newValue in
                    if newValue.count > PlayDirectorBroadcastAudience.contentLimit {
                        content = String(newValue.prefix(PlayDirectorBroadcastAudience.contentLimit))
                    }
                }
        } header: {
            Text("playx.director.broadcast.content")
        } footer: {
            HStack {
                Spacer()
                Text("playx.director.broadcast.length \(content.count) \(PlayDirectorBroadcastAudience.contentLimit)")
                    .monospacedDigit()
            }
        }
    }

    private var targetRows: [PlayDirectorBroadcastAudience.Target] {
        if targetType == "ALL" { return [] }
        return PlayDirectorBroadcastAudience.targets(targetType, projection: projection)
    }

    private var selectedID: String {
        if targetType == "TEAM" { return String(teamID) }
        if targetType == "ROLE" { return roleCode }
        return ""
    }

    @ViewBuilder private var countText: some View {
        let count = PlayDirectorBroadcastAudience.recipientCount(targetType, selectedID: selectedID, projection: projection)
        let teams = PlayDirectorBroadcastAudience.teamCount(targetType, projection: projection)
        if let count, let teams {
            Text("playx.director.broadcast.peopleTeams \(count) \(teams)").monospacedDigit()
        } else if let count {
            Text("playx.director.broadcast.people \(count)").monospacedDigit()
        } else if targetType == "ALL" {
            Text("playx.director.broadcast.allPlayers")
        } else {
            Text("playx.director.broadcast.pending")
        }
    }

    private func targetRow(_ target: PlayDirectorBroadcastAudience.Target) -> some View {
        let on = target.id == selectedID
        return Button {
            select(target.id)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: target.label).foregroundStyle(.primary)
                    if let count = target.memberCount {
                        Text("playx.director.broadcast.people \(count)").font(.footnote).foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 8)
                if on {
                    Label("playx.director.broadcast.selected", systemImage: "checkmark")
                        .labelStyle(.titleAndIcon)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.tint)
                } else {
                    Text("playx.director.broadcast.pick").font(.subheadline).foregroundStyle(.secondary)
                }
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
        .accessibilityIdentifier("playx.director.broadcast.target.\(target.id)")
    }

    private func select(_ id: String) {
        if targetType == "TEAM" { teamID = Int(id) ?? 0 }
        if targetType == "ROLE" { roleCode = id }
    }

    /// director.js:1229 `_setBroadcastTargetType`: switching the scope selects its first target.
    private func selectFirst(_ type: String) {
        guard type != "ALL" else { return }
        let rows = PlayDirectorBroadcastAudience.targets(type, projection: projection)
        if rows.contains(where: { $0.id == selectedID }) { return }
        if let first = rows.first { select(first.id) }
    }
}
