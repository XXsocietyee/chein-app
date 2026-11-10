import SwiftUI

/// Host remains alive while its independently retained original-result destination is on screen.
@MainActor struct CityTaskHistoryRuntimeHostView: View {
    @EnvironmentObject private var session: AppSession
    @Bindable var owner: CityTaskHistoryRuntimeOwner
    let revision: UInt64
    var body: some View {
        Group {
            if owner.isCurrent, let controller = owner.controller {
                CityTaskHistoryView(controller: controller)
            } else {
                CityTaskHistoryUnavailable()
            }
        }
        .themeDomain(.player)
        .cyDomainPageBackground()
        .onAppear { owner.synchronize() }
        .onChange(of: session.currentRuntimeDependencyContext) { _, _ in owner.synchronize() }
        .onChange(of: revision) { _, _ in owner.synchronize() }
        // Child handles foreground/disappearance. Retiring here would incorrectly destroy original-result navigation.
    }
}

/// Disabled read. The live history screen already draws `cityHistory.title`; this state uses that same single hero.
@MainActor private struct CityTaskHistoryUnavailable: View {
    @Environment(\.cyPalette) private var palette
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CYSpacing.lg) {
                CYHeroHeader(
                    "cityHistory.title",
                    subtitle: "cityHistory.status.disabled",
                    tableName: "CityTaskHistory",
                    titleIdentifier: "city.history.disabled"
                ) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.largeTitle)
                        .foregroundStyle(palette.textSecondary)
                        .accessibilityHidden(true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, CYSpacing.pageHorizontal)
            .padding(.vertical, CYSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
