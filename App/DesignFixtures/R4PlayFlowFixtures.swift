#if DEBUG
import SwiftUI

/// ui/r4-play-flow fixtures (synthetic copy, labelled FIXTURE in the title):
/// - `--design-fixture r4-play-hud`: the play HUD (401:4731) over the map scaffold: 下一站 card with the arrow at
///   45°, 180 m, 用时 23:10 · 线索 3 / 6; the run primary; 提示 + 队伍 + 背包. 转向 turns the arrow by 15° steps.
/// - `--design-fixture r4-play-hud-unknown`: no fix and no compass: no arrow, no distance, the caption only.
/// - `--design-fixture r4-report-unscored`: 战报 (204:15044) for an unscored run with no elapsed time: one stat,
///   本局不计分 once as the subtitle.
enum R4PlayFlowFixtures {
    @MainActor static func make(_ name: String) -> AnyView? {
        switch name {
        case "r4-play-hud": return wrap(R4PlayHUDFixture(known: true))
        case "r4-play-hud-unknown": return wrap(R4PlayHUDFixture(known: false))
        case "r4-report-unscored": return wrap(NavigationStack { R4ReportFixture() })
        default: return nil
        }
    }

    @MainActor private static func wrap<V: View>(_ view: V) -> AnyView {
        AnyView(view.themeDomain(.player).cyDomainPageBackground().preferredColorScheme(.dark))
    }
}

private struct R4PlayHUDFixture: View {
    let known: Bool
    @State private var degrees: Double = 45

    var body: some View {
        NavigationStack {
            CYMapScaffold(detent: .medium, map: { CYMapPlaceholder() }, controls: {
                Text(verbatim: "Play HUD · FIXTURE").font(CYTypography.label).foregroundStyle(.white)
            }, floating: {
                VStack(spacing: CYSpacing.md) {
                    PlayHUDNextStopCard(stop: PlayHUDNextStop(
                        name: "老麦咖啡馆",
                        distanceText: known ? "180 m" : nil,
                        arrowDegrees: known ? degrees : nil,
                        elapsedText: "23:10",
                        clues: (3, 6)))
                    CYPillButton("playx.run.pause", systemImage: "pause.fill") {}
                    PlayHUDBar(onHint: {}, onBackpack: {}, team: {
                        Button {} label: { Image(systemName: "bubble.left.and.bubble.right") }
                            .accessibilityLabel(Text("ingame.channel.team"))
                    })
                }
                .padding(.horizontal, CYSpacing.lg)
            }, panel: {
                List {
                    Button("转向 +15° · FIXTURE") { degrees += 15 }.accessibilityIdentifier("r4.hud.turn")
                    Button("转向 −15° · FIXTURE") { degrees -= 15 }
                }
                .scrollContentBackground(.hidden)
            })
            .navigationTitle(Text("playx.title"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct R4ReportFixture: View {
    var body: some View {
        JourneyReportView(
            phase: .ready(JourneyReport(
                legacy: false, result: .legitimate, dateLabel: "2026-11-21", nodesText: "6/6", elapsedText: nil, score: nil,
                rank: nil, rankBasisCount: nil, penaltyText: nil, rewardItems: 2, runID: "run-r4", topicID: "88",
                activityID: nil, coverURL: nil, nodes: [], finished: true, inProgress: false)),
            memory: .loading, rank: JourneyRankState(), shareURL: nil, topicName: "老洋房的门牌 · FIXTURE", hasSeats: false,
            onRetry: {}, onSignIn: {}, onLoadMemory: {}, onLoadRank: {}, onRankScope: { _ in }, onRankPeriod: { _ in },
            onOpenSettle: {}, onOpenSeats: {})
    }
}
#endif
