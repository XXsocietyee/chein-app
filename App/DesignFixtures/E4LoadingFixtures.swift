#if DEBUG
import SwiftUI

/// e4 loading-to-content choreography (docs/release/motion-spec-loading.md). Offline, timer-driven, no reader and no network:
/// `--design-fixture motion-lab-loading` loops first load (skeleton after 120 ms, held 350 ms, 0.20 s cross-fade,
/// 6-row stagger), a fast reload (50 ms: no skeleton), an in-screen tab swap and a rolling header stat.
enum E4LoadingFixtures {
    @MainActor static func make(_ name: String) -> AnyView? {
        switch name {
        case "motion-lab-loading":
            return AnyView(E4LoadingLab().themeDomain(.player).cyDomainPageBackground().themeDomain(.player).preferredColorScheme(.dark))
        default: return nil
        }
    }
}

private struct E4LoadingItem: Identifiable {
    let id: Int
    let title: String
    let detail: String
}

private struct E4LoadingLab: View {
    @State private var phase: CYPhase<[E4LoadingItem], Never> = .idle
    @State private var tab = 0
    @State private var total = 1234
    @State private var step = "start"
    @Environment(\.cyPalette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.lg) {
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                Text(verbatim: "Offline example · loading lab · \(step)").font(CYTypography.meta).foregroundStyle(palette.textSecondary)
                CYStatNumber(text: total.formatted(), rollsOnAppear: true)
            }
            .padding(.horizontal, CYSpacing.pageHorizontal)
            Picker(selection: $tab) {
                Text(verbatim: "Nearby").tag(0)
                Text(verbatim: "Following").tag(1)
            } label: { Text(verbatim: "Tab") }
            .pickerStyle(.segmented)
            .padding(.horizontal, CYSpacing.pageHorizontal)
            .allowsHitTesting(false)
            CYSegmentedContent(selection: tab, haptic: false) {
                ScrollView {
                    CYListChoreography(phase: phase, skeletonRows: 6, loadingLabel: "cy.state.loading", emptyMessage: "cy.state.loading") { item in
                        row(item)
                    }
                    .padding(.horizontal, CYSpacing.pageHorizontal)
                }
            }
        }
        .padding(.top, CYSpacing.lg)
        .task { await loop() }
    }

    private func row(_ item: E4LoadingItem) -> some View {
        CYCard {
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                Text(verbatim: item.title).font(CYTypography.bodyMedium).foregroundStyle(palette.textPrimary)
                Text(verbatim: item.detail).font(CYTypography.meta).foregroundStyle(palette.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func items(_ tab: Int) -> [E4LoadingItem] {
        (0..<12).map { E4LoadingItem(id: tab * 100 + $0, title: "\(tab == 0 ? "Nearby" : "Following") example \($0 + 1)", detail: "Offline example row") }
    }

    /// first load (700 ms) -> tab swap -> fast reload (50 ms, no skeleton) -> slow reload (700 ms) -> repeat.
    private func loop() async {
        while !Task.isCancelled {
            step = "first load"
            phase = .loading
            try? await Task.sleep(for: .milliseconds(700))
            phase = .loaded(items(tab)); total += 56
            try? await Task.sleep(for: .milliseconds(2600))
            step = "tab swap"
            tab = 1 - tab; phase = .loaded(items(tab)); total += 7
            try? await Task.sleep(for: .milliseconds(2200))
            step = "fast reload (no skeleton)"
            phase = .loading
            try? await Task.sleep(for: .milliseconds(50))
            phase = .loaded(items(tab)); total += 11
            try? await Task.sleep(for: .milliseconds(2200))
            step = "slow reload"
            phase = .loading
            try? await Task.sleep(for: .milliseconds(700))
            phase = .loaded(items(tab)); total += 120
            try? await Task.sleep(for: .milliseconds(2400))
        }
    }
}
#endif
