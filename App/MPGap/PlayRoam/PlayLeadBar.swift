import SwiftUI

/// mp-journey r3: MP `pages/play/index` top stack 带领行进条 (`.leadbar`) and its retry twin (`.leadbar-retry`).
/// In progress: 到场 n/N 人 · chapter, then 队长带领中 · 工具在更多 (leader) or 队长带队中; ended: 本场已结束 · 你完成了 d/t 站.
/// A failed team-progress read shows 网络状态暂未刷新 · 点击重试 instead.
struct PlayLeadBar: View {
    @Bindable var model: PlayExperienceCoordinator

    var body: some View {
        if model.leadReadFailed {
            Button {
                Task { await model.probeLead(context: model.interactionContext) }
            } label: {
                Label("playx.leadBar.retry", systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.borderless)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.regularMaterial)
            .accessibilityIdentifier("playx.leadBar.retry")
        } else if let lead = model.lead, lead.showsLeadBar {
            bar(lead)
        }
    }

    private func bar(_ lead: PlayLeadProgress) -> some View {
        HStack(spacing: 8) {
            Circle().fill(lead.ended ? Color.secondary : Color.green).frame(width: 8, height: 8)
                .accessibilityHidden(true)
            left(lead)
                .font(.footnote.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
            Spacer(minLength: 8)
            if !lead.ended {
                Text(lead.isLeader ? "playx.leadBar.leader" : "playx.leadBar.member")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.regularMaterial)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("playx.leadBar")
    }

    @ViewBuilder private func left(_ lead: PlayLeadProgress) -> some View {
        if lead.ended {
            let done = model.snapshot?.displayedDoneCount ?? 0
            let total = model.snapshot?.result.total ?? model.snapshot?.visibleNodes.count ?? 0
            Text("playx.leadBar.ended \(done) \(total)")
        } else {
            let arrived = Text("playx.leadBar.arrived \(lead.arrived ?? 0) \(lead.total ?? lead.members.count)")
            if let chapter = lead.chapterName, !chapter.isEmpty {
                arrived + Text(verbatim: " · " + chapter)
            } else {
                arrived
            }
        }
    }
}
