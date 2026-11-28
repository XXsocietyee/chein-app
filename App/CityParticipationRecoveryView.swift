import SwiftUI

/// Explicitly injected original-request recovery only. Not reachable from production composition.
/// Future host MUST change identityVersion on account/credential/permission changes, and own its model.
@MainActor struct CityParticipationRecoveryView: View {
    @Bindable var model: CityParticipationCommandRecovery
    let identityVersion: UInt64
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.cyPalette) private var palette

    var body: some View {
        List {
            Section {
                CYHeroHeader("参与请求恢复") {
                    Cloud07Cover(seed: "city-participation-recovery", symbol: "arrow.counterclockwise")
                }
            }
            .listRowInsets(rowInsets)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            Section {
                state
                if model.busy {
                    VStack(alignment: .leading, spacing: CYSpacing.sm) {
                        Text("正在查询原请求")
                            .cyText(.body)
                            .foregroundStyle(palette.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        CYSkeleton().accessibilityHidden(true)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(Text("正在查询原请求"))
                }
            }
            .listRowInsets(rowInsets)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
        .listStyle(.insetGrouped)
        .cyGroupedSurface()
        .accessibilityIdentifier("city.participation.recovery")
        .cyHaptic(.impactMedium, trigger: model.busy, where: CYHapticTransition.turnedOn)
        .task { if scenePhase == .active { model.open() } }
        .onChange(of: identityVersion) { _, _ in model.identityChanged() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { model.open() } else { model.close() } }
        .onDisappear { model.close() }
    }

    private var rowInsets: EdgeInsets {
        EdgeInsets(top: CYSpacing.md, leading: CYSpacing.pageHorizontal, bottom: CYSpacing.md, trailing: CYSpacing.pageHorizontal)
    }

    @ViewBuilder private var state: some View {
        switch model.display {
        case .hidden:
            EmptyView()
        case .unavailable:
            CYNoteBanner(text: Text("参与恢复暂不可用，已保存的请求不会重发。"), symbol: "lock.fill", tone: .warning)
        case .empty:
            CYNoteBanner(text: Text("没有待确认的参与请求。"), symbol: "tray", tone: .neutral)
        case .storageBlocked:
            CYNoteBanner(text: Text("无法核实本地请求，请保留记录。不会发起新请求。"), symbol: "externaldrive.badge.exclamationmark", tone: .danger)
        case .unknown:
            CYNoteBanner(text: Text("原请求结果尚未确认。请查询原结果，不要重复提交。"), symbol: "questionmark.circle", tone: .warning)
            CYPillButton("查询原结果", systemImage: "arrow.clockwise") { Task { await model.recheck() } }
                .disabled(model.busy)
                .accessibilityLabel(Text("查询原结果"))
                .accessibilityIdentifier("city.participation.recheckOriginal")
        case .complete(let status):
            CYNoteBanner(
                text: Text(LocalizedStringKey(status == 200 ? "原参与请求已完成。" : "原参与请求未获接受。")),
                symbol: status == 200 ? "checkmark.circle.fill" : "xmark.circle.fill",
                tone: status == 200 ? .success : .danger
            )
            Text("原记录已保留；此页面不会开启游戏或再次提交。")
                .cyText(.body)
                .foregroundStyle(palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
