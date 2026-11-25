import SwiftUI

/// Read-only detail of the server-projected record. Only routes may link to an existing topic host.
/// POI/stamp object IDs are never reinterpreted as topic IDs or used to invent another API.
@MainActor struct RoamMonthlyRecapDetailView: View {
    @Environment(\.themeDomain) private var domain
    let model: RoamMonthlyRecapCoordinator
    let presentation: RoamMonthlyRecapPresentation
    var routeDestination: ((String) -> AnyView)? = nil
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
                                Text(verbatim: presentation.record.occurredAt)
                            } label: { Text(verbatim: localized("occurredAt")) }
                            Text(verbatim: localized("shanghai")).cyText(.meta).foregroundStyle(.secondary)
                        }
                        if let topicID = presentation.topicID, let routeDestination {
                            NavigationLink {
                                // A visible detail can outlive the parent's rendered body during sign-out.
                                if scenePhase == .active && model.isCurrent(presentation) { routeDestination(topicID) }
                                else { unavailable }
                            } label: { Label("roam.tools.anniversary.openRoute", systemImage: "map") }
                                .background { RoamHostedAccessibilityAnchor(identifier: "roam.tools.recap.detail.openRoute") }
                                .accessibilityIdentifier("roam.tools.recap.detail.openRoute")
                        }
                    }.cyGroupedSurface()
                } else { unavailable }
            }
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
    private var unavailable: some View {
        CYEmptyState(systemImage: "exclamationmark.circle", "topic.unavailable")
            .accessibilityIdentifier("roam.tools.recap.detail.unavailable")
    }
}
