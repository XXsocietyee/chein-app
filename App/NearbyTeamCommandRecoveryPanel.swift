import SwiftUI

/// What the MP `team-recovery-panel` lists: team ids with an unknown-outcome command, or the storage read error.
enum NearbyTeamCommandRecovery: Equatable {
    case idle
    case loaded([Int])
    case failed

    static func read(_ source: (() throws -> [Int])?) -> NearbyTeamCommandRecovery {
        guard let source else { return .idle }
        do { return .loaded(try source()) } catch { return .failed }
    }
    /// MP `wx:if="{{teamCommandError || teamCommandRows.length}}"`: nothing at all when there is nothing to confirm.
    var isVisible: Bool {
        switch self {
        case .idle: return false
        case .loaded(let ids): return !ids.isEmpty
        case .failed: return true
        }
    }
}

/// MP `subpackageRoam/utils/team-recovery-panel.wxml` on 我的队伍 / 附近队伍 (my-teams wxml:16, nearby wxml:271):
/// one card per team whose command result is unknown, with the MP read error and 重新读取记录. 查询结果 opens that
/// team's page, which owns the original request (query / retry / abort share its key and fields, C-D12).
struct NearbyTeamCommandRecoveryPanel: View {
    let state: NearbyTeamCommandRecovery
    let reload: () -> Void
    let open: (Int) -> Void

    var body: some View {
        if state.isVisible {
            GroupBox { content }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("nearby.commands")
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("nearby.commands.title")
                .cyText(.cardTitle).foregroundStyle(CYColor.textPrimary)
                .accessibilityAddTraits(.isHeader)
            switch state {
            case .failed:
                Label("nearby.commands.storageError", systemImage: "exclamationmark.triangle")
                    .cyText(.meta).foregroundStyle(CYColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("nearby.commands.storageError")
                Button("nearby.commands.reload", action: reload)
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("nearby.commands.reload")
            case .loaded(let ids):
                ForEach(ids, id: \.self) { id in
                    VStack(alignment: .leading, spacing: 6) {
                        Text("nearby.commands.row").cyText(.body).foregroundStyle(CYColor.textPrimary)
                        Text("nearby.commands.message")
                            .cyText(.meta).foregroundStyle(CYColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Button("nearby.commands.query") { open(id) }
                            .buttonStyle(.bordered)
                            .accessibilityIdentifier("nearby.commands.query.\(id)")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                Text("nearby.commands.abortNote")
                    .cyText(.meta).foregroundStyle(CYColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            case .idle:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
