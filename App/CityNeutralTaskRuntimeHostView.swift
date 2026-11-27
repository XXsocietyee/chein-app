import SwiftUI

/// Host remains alive while its independently retained original-result destination is on screen.
@MainActor struct CityNeutralTaskRuntimeHostView: View {
    @EnvironmentObject private var session: AppSession
    @Bindable var owner: CityNeutralTaskRuntimeOwner
    let revision: UInt64
    private let table = "CityNeutralTask"

    var body: some View {
        Group {
            if owner.isCurrent, let controller = owner.controller {
                CityNeutralTaskView(controller: controller)
            } else {
                unavailable
            }
        }
        .onAppear { owner.synchronize() }
        .onChange(of: session.currentRuntimeDependencyContext) { _, _ in owner.synchronize() }
        .onChange(of: revision) { _, _ in owner.synchronize() }
        // Child handles foreground/disappearance. Retiring here would incorrectly destroy original-result navigation.
        .cyDomainScreen(.game)
    }

    /// Approval is missing. One hero title, the existing disabled copy, no second bar title.
    private var unavailable: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CYSpacing.xl) {
                CYHeroHeader("cityNeutral.title", subtitle: "cityNeutral.status.disabled", tableName: table) {
                    Cloud07Cover(seed: "city-neutral-unavailable", symbol: "checklist")
                }
            }
            .padding(.horizontal, CYSpacing.pageHorizontal)
            .padding(.bottom, CYSpacing.xxl)
        }
        .cyDomainPageBackground()
    }
}

/// Generated cover for a screen with no photo. Height follows width, never a fixed text box.
struct Cloud07Cover: View {
    let seed: String
    let symbol: String
    var body: some View {
        Color.clear
            .aspectRatio(16.0 / 9.0, contentMode: .fit)
            .overlay {
                // mp-journey r3 (sweep 19:15, d2-city): the no-photo fallback is product art, not a debug placeholder.
                CYCoverArt(seed: seed, symbol: symbol, showsDebugLabel: false, cornerRadius: CYRadius.lg)
            }
            .clipShape(RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous))
            .accessibilityHidden(true)
    }
}
