#if DEBUG
import SwiftUI

/// e4 celebration + state kit (docs/release/motion-spec-celebration.md). Offline, synthetic, DEBUG only; mounted nowhere live.
/// `--design-fixture celebration-stamp | celebration-badge | celebration-roam | celebration-roam-unknown | celebration-queue`
/// plus `celebration-roam-route`, `celebration-badge-long`, `celebration-share-walk` and `celebration-share-badge`,
/// and `state-offline | state-server | state-empty | state-empty-compact`. Add `-zh` for Simplified Chinese copy
/// and `--uitesting-reduce-motion` for the fallback. The celebration fixtures log every haptic with its timestamp.
enum E4CelebrationFixtures {
    @MainActor static func make(_ name: String) -> AnyView? {
        let zh = name.hasSuffix("-zh")
        let base = zh ? String(name.dropLast(3)) : name
        let locale = Locale(identifier: zh ? "zh-Hans" : "en")
        switch base {
        case "celebration-stamp": return wrap(E4CelebrationLab(script: .stamp), locale)
        case "celebration-badge": return wrap(E4CelebrationLab(script: .badge), locale)
        case "celebration-roam": return wrap(E4CelebrationLab(script: .roam), locale)
        case "celebration-roam-unknown": return wrap(E4CelebrationLab(script: .roamUnknown), locale)
        case "celebration-queue": return wrap(E4CelebrationLab(script: .queue), locale)
        case "celebration-roam-route": return wrap(E4CelebrationLab(script: .roamRoute), locale)
        case "celebration-badge-long": return wrap(E4CelebrationLab(script: .badgeLong), locale)
        case "celebration-share-walk": return wrap(E4ShareSheetLab(walk: true), locale)
        case "celebration-share-badge": return wrap(E4ShareSheetLab(walk: false), locale)
        case "state-offline": return wrap(E4StateLab(mode: .offline), locale)
        case "state-server": return wrap(E4StateLab(mode: .server), locale)
        case "state-empty": return wrap(E4StateLab(mode: .empty), locale)
        case "state-empty-compact": return wrap(E4StateLab(mode: .emptyCompact), locale)
        default: return nil
        }
    }

    @MainActor private static func wrap<V: View>(_ view: V, _ locale: Locale) -> AnyView {
        AnyView(view.environment(\.locale, locale).themeDomain(.player).cyDomainPageBackground().themeDomain(.player).preferredColorScheme(.dark))
    }
}

// MARK: - Celebrations

private enum E4CelebrationScript { case stamp, badge, badgeLong, roam, roamUnknown, roamRoute, queue }

private struct E4CelebrationLab: View {
    let script: E4CelebrationScript
    @State private var center = CYCelebrationCenter()
    @State private var log: [String] = []
    @State private var run = 0
    @Environment(\.cyPalette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.lg) {
            Text(verbatim: "Offline example · celebration lab").font(CYTypography.meta).foregroundStyle(palette.textSecondary)
            CYPillButton(verbatim: "Replay", style: .secondary, fullWidth: false) { Task { await play() } }
                .accessibilityIdentifier("e4.celebration.replay")
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                ForEach(Array(log.enumerated()), id: \.offset) { _, line in
                    Text(verbatim: line).font(CYTypography.meta).monospacedDigit().foregroundStyle(palette.textSecondary)
                }
            }
            Spacer()
        }
        .padding(CYSpacing.pageHorizontal)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .cyCelebrations(center, onShare: { _ in log.append("share tapped") })
        .task {
            let started = ProcessInfo.processInfo.systemUptime
            center.haptics = { haptic in
                let t = ProcessInfo.processInfo.systemUptime - started
                log.append("\(t.formatted(.number.precision(.fractionLength(2)))) s  haptic \(String(describing: haptic))")
                haptic.play()
            }
            center.announcer = { text in log.append("announce: \(text)") }
            await play()
        }
    }

    private func play() async {
        run += 1
        let n = run
        switch script {
        case .stamp:
            center.enqueue(.stamp(CYStampPayload(id: "s\(n)", place: "Lantern Gate (example)")))
        case .badge:
            center.enqueue(.badge(CYBadgePayload(id: "b\(n)", name: "Night Walker", symbol: "moon.stars.fill")))
        case .roam:
            center.enqueue(.roamSummary(CYRoamSummaryPayload(id: "r\(n)", kilometers: 2.4, tiles: 31, stamps: 2)))
        case .roamUnknown:
            center.enqueue(.roamSummary(CYRoamSummaryPayload(id: "r\(n)", kilometers: nil, tiles: 31, stamps: 0)))
        case .roamRoute:
            center.enqueue(.roamSummary(CYRoamSummaryPayload(id: "r\(n)", kilometers: 2.4, tiles: 31, stamps: 2, route: E4PeakRoute.points)))
        case .badgeLong:
            center.enqueue(.badge(CYBadgePayload(id: "b\(n)", name: "Lantern Gate Night Walker of the Old Quarter (example)", symbol: "moon.stars.fill")))
        case .queue:
            // Arrive out of order, 25 ms apart: the stamp still plays first, then the badge, then the summary.
            center.enqueue(.roamSummary(CYRoamSummaryPayload(id: "r\(n)", kilometers: 2.4, tiles: 31, stamps: 2)))
            try? await Task.sleep(for: .milliseconds(25))
            center.enqueue(.badge(CYBadgePayload(id: "b\(n)", name: "Night Walker", symbol: "moon.stars.fill")))
            try? await Task.sleep(for: .milliseconds(25))
            center.enqueue(.stamp(CYStampPayload(id: "s\(n)", place: "Lantern Gate (example)")))
        }
    }
}

// MARK: - Share sheet + route

/// A synthetic loop, already normalised to the unit square. Fixture data only (DEBUG).
enum E4PeakRoute {
    static let points: [CGPoint] = (0...40).map { i in
        let t = Double(i) / 40 * 2 * .pi
        return CGPoint(x: 0.5 + 0.38 * cos(t) * (1 + 0.15 * sin(2 * t)), y: 0.5 + 0.34 * sin(t))
    }
}

/// The share sheet on its own, as the badge cover and the roam summary present it.
private struct E4ShareSheetLab: View {
    let walk: Bool
    @Environment(\.locale) private var locale
    var body: some View {
        if walk {
            let payload = CYRoamSummaryPayload(id: "fixture", kilometers: 2.4, tiles: 31, stamps: nil, route: E4PeakRoute.points)
            CYCelebrationShareSheet(
                content: CYCelebrationShare.walk(payload, locale: locale),
                routeContent: CYCelebrationShare.walk(payload, locale: locale, includeRoute: true))
        } else {
            CYCelebrationShareSheet(content: CYCelebrationShare.badge(CYBadgePayload(id: "fixture", name: "Night Walker", symbol: "moon.stars.fill"), locale: locale))
        }
    }
}

// MARK: - States

private struct E4StateLab: View {
    enum Mode { case offline, server, empty, emptyCompact }
    let mode: Mode
    @State private var taps = 0
    @Environment(\.locale) private var locale
    @Environment(\.cyPalette) private var palette

    var body: some View {
        ScrollView {
            VStack(spacing: CYSpacing.lg) {
                Text(verbatim: "Offline example · state lab · retry taps \(taps)").font(CYTypography.meta).foregroundStyle(palette.textSecondary)
                state
                if mode == .emptyCompact {
                    // The rest of the screen stays alive around an inline state.
                    CYListRow(verbatim: "Unknown balance", meta: "Unknown is a dash, never 0", trailing: .value(CYUnknown.count(nil)), card: true) {
                        CYRowIcon(systemImage: "wallet.pass")
                    }
                }
            }
            .padding(.horizontal, CYSpacing.pageHorizontal)
            .padding(.top, CYSpacing.lg)
        }
    }

    @ViewBuilder private var state: some View {
        let copy = CYKitCopy(locale: locale)
        switch mode {
        case .offline:
            CYStateView.offline(locale: locale) { taps += 1 }
        case .server:
            CYStateView.server(locale: locale) { taps += 1 }
        case .empty, .emptyCompact:
            CYStateView(
                content: .empty(
                    glyph: "book.closed",
                    title: copy("Your first stamp is waiting", "第一枚章在等你"),
                    body: copy("Walk somewhere new and stamp it.", "去个新地方，盖一枚"),
                    actionTitle: copy("Go", "走起"),
                    linkTitle: copy("Not now", "以后再说")
                ),
                onPrimary: { taps += 1 },
                onLink: { taps += 1 },
                compact: mode == .emptyCompact
            )
        }
    }
}
#endif
