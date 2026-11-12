import SwiftUI

/// Successful club join or apply, in the membership row.
/// The seal drops, a lantern `CYBurst` plays (reward only; never the confetti palette), then the joined or pending chip.
/// Reduce Motion: no seal travel and no particles, only a short crossfade to that chip.
struct CYJoinReward: View {
    enum Kind: Equatable {
        case joined, pending

        var title: LocalizedStringKey {
            switch self {
            case .joined: return "club.membership.joined"
            case .pending: return "club.membership.pending"
            }
        }
        var symbol: String { self == .joined ? "checkmark" : "clock" }
        var tone: CYStatusTone { self == .joined ? .success : .warning }
    }

    enum Phase: Equatable { case landing, burst, chip }

    var kind: Kind
    var phase: Phase
    /// False once the moment has finished and only the chip should remain.
    var plays: Bool = true

    @QuestifyReduceMotion private var reduceMotion
    @State private var ring: CGFloat = 0

    private var dropped: Bool { phase != .landing }
    private var showMotion: Bool { plays && !reduceMotion }
    private var showChip: Bool { !plays || reduceMotion || phase == .chip }

    var body: some View {
        ZStack {
            if showMotion {
                seal
                    .opacity(phase == .chip ? 0 : 1)
                if phase != .landing {
                    CYBurst(origin: .center, count: 32, duration: 1.15, style: .dust, reach: 72,
                            colors: [CYNight.lantern, CYNight.lanternHot, .white])
                        .frame(maxWidth: .infinity)
                        .frame(height: 128)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            CYStatusChip(kind.title, tone: kind.tone, systemImage: kind.symbol)
                .opacity(showChip ? 1 : 0)
                .scaleEffect(showChip ? 1 : 0.92)
        }
        .frame(maxWidth: .infinity, minHeight: showMotion && phase != .chip ? 148 : 44)
        .animation(reduceMotion ? CYMotion.reduced : CYMotion.standard, value: phase)
        .animation(reduceMotion ? CYMotion.reduced : CYMotion.standard, value: plays)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(kind.title))
        .onAppear(perform: expandRing)
        .onChange(of: phase) { _, _ in expandRing() }
    }

    private func expandRing() {
        guard showMotion, phase == .burst, ring == 0 else { return }
        withAnimation(.easeOut(duration: 0.42)) { ring = 1 }
    }

    /// Rings stay on the landing spot. The face drops onto them.
    private var seal: some View {
        let side: CGFloat = 64
        return ZStack {
            Circle().fill(CYNight.glow(radius: side / 2))
                .frame(width: side * 1.7, height: side * 1.7)
                .opacity(dropped ? 0.95 : 0.3)
            Circle().strokeBorder(CYNight.lantern, lineWidth: 2.5)
                .frame(width: side, height: side)
                .scaleEffect(1 + 1.15 * ring)
                .opacity(ring > 0 ? 0.8 * (1 - ring) : 0)
            Circle().strokeBorder(CYNight.lanternHot, lineWidth: 1.25)
                .frame(width: side, height: side)
                .scaleEffect(1 + 1.15 * max(0, (ring - 0.18) / 0.82))
                .opacity(ring > 0.18 ? 0.5 * (1 - ring) : 0)
            ZStack {
                CYSerratedCircle(teeth: 32, depth: 0.055)
                    .fill(LinearGradient(colors: [CYNight.lanternHot, CYNight.lantern, CYNight.ember],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(CYSerratedCircle(teeth: 32, depth: 0.055).stroke(Color.white.opacity(0.35), lineWidth: 0.75))
                Circle().strokeBorder(CYNight.ink0.opacity(0.55), lineWidth: 2)
                    .padding(side * 0.19)
                Image(systemName: kind.symbol)
                    .font(.system(.title3, design: .rounded).weight(.heavy))
                    .foregroundStyle(CYNight.ink0.opacity(0.82))
            }
            .frame(width: side, height: side)
            .scaleEffect(dropped ? 1 : 1.14, anchor: .bottom)
            .offset(y: dropped ? 0 : -22)
        }
        .accessibilityHidden(true)
    }
}
