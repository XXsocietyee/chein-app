import SwiftUI

/// Host remains alive while its independently retained original-result destination is on screen.
@MainActor struct CityOnsiteTaskRuntimeHostView: View {
    @EnvironmentObject private var session: AppSession
    let arrivalFactory: (@MainActor (CityReadBoard) -> CityArrivalEvidenceController)?
    @Bindable var owner: CityOnsiteTaskRuntimeOwner
    let revision: UInt64
    private let table = "CityOnsiteTask"

    var body: some View {
        Group {
            if owner.isCurrent, let controller = owner.controller {
                CityOnsiteTaskView(controller: controller, board: owner.board, arrivalFactory: arrivalFactory)
            } else {
                unavailable
            }
        }
        .onAppear { owner.synchronize() }
        .onChange(of: session.currentRuntimeDependencyContext) { _, _ in owner.synchronize() }
        .onChange(of: revision) { _, _ in owner.synchronize() }
        // Child handles foreground/disappearance. Retiring here would incorrectly destroy original-result navigation.
    }

    /// Approval is missing. One hero title, the existing disabled copy, no second bar title.
    private var unavailable: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CYSpacing.xl) {
                CYHeroHeader("cityOnsite.title", subtitle: "cityOnsite.status.disabled", tableName: table) {
                    Cloud07Cover(seed: "city-onsite-unavailable", symbol: "figure.walk")
                }
            }
            .padding(.horizontal, CYSpacing.pageHorizontal)
            .padding(.bottom, CYSpacing.xxl)
        }
        .cyDomainPageBackground()
    }
}
