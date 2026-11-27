import SwiftUI

/// Read-only detail of the server-projected record. Only routes may link to an existing topic host.
/// POI/stamp object IDs are never reinterpreted as topic IDs or used to invent another API.
@MainActor struct RoamMonthlyRecapDetailView: View {
    @Environment(\.themeDomain) private var domain
    let model: RoamMonthlyRecapCoordinator
    let presentation: RoamMonthlyRecapPresentation
    var routeDestination: ((String) -> AnyView)? = nil
    /// Same push as the route NavigationLink, for its hosted accessibility action (owned by the recap list).
    var routeOpened: Binding<Bool> = .constant(false)
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            Group {
                if scenePhase != .active { Color.clear }
                else if model.isCurrent(presentation) {
                    List {
                        Section {
                            Text(verbatim: presentation.record.title).cyText(.sheetTitle)
                            LabeledContent {
                                Text(verbatim: LocaleDisplay.civil(presentation.record.occurredAt, locale: locale))
                            } label: { Text(verbatim: localized("occurredAt")) }
                            Text(verbatim: localized("shanghai")).cyText(.meta).foregroundStyle(.secondary)
                        }
                        if let topicID = presentation.topicID, let routeDestination {
                            NavigationLink {
                                // A visible detail can outlive the parent's rendered body during sign-out.
                                if scenePhase == .active && model.isCurrent(presentation) { routeDestination(topicID) }
                                else { unavailable }
                            } label: { Label("roam.tools.anniversary.openRoute", systemImage: "map") }
                                .background {
                                    // The anchor had no action, so a hosted activation of this id was a silent no-op.
                                    RoamHostedAccessibilityAnchor(identifier: "roam.tools.recap.detail.openRoute", action: {
                                        guard scenePhase == .active, model.isCurrent(presentation) else { return }
                                        routeOpened.wrappedValue = true
                                    })
                                }
                                .accessibilityIdentifier("roam.tools.recap.detail.openRoute")
                        }
                    }.cyGroupedSurface()
                } else { unavailable }
            }
            .navigationDestination(isPresented: routeOpened) { routeTarget }
            .cyText(.body)   // TRECAP-3 residue
            .tint(Theme.Color.accent(in: domain))
            .scrollContentBackground(.hidden)
            .background(Theme.Color.bgPage(in: domain))
            .themeDomain(domain)
            .navigationTitle(localized("title")).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action.close") { guard scenePhase == .active else { return }; dismiss() }
                        .accessibilityIdentifier("roam.tools.recap.detail.close")
                }
            }
            .privacySensitive()
            .accessibilityIdentifier("roam.tools.recap.detail")
        }
        .cyDomainScreen(.player)
    }
    /// Resolve both the lookup language and formatting from the current app locale.
    private func localized(_ key: String) -> String {
        String(localized: LocalizedStringResource(
            String.LocalizationValue(stringLiteral: "roam.tools.recap.detail." + key),
            table: "RoamMonthlyRecap", locale: locale))
    }
    @ViewBuilder private var routeTarget: some View {
        if let topicID = presentation.topicID, let routeDestination, scenePhase == .active, model.isCurrent(presentation) {
            routeDestination(topicID)
        } else { unavailable }
    }
    private var unavailable: some View {
        CYEmptyState(systemImage: "exclamationmark.circle", "topic.unavailable")
            .accessibilityIdentifier("roam.tools.recap.detail.unavailable")
    }
}
