import SwiftUI

@MainActor struct ApprovedReleasePublicationConfirmationView: View {
    @Environment(\.locale) private var locale
    @State private var primaryPulse = 0
    let original: ApprovedTopicReleasePublishFlow.Confirmation
    let cancel: (ApprovedTopicReleasePublishFlow.Confirmation) -> Void
    let confirm: (ApprovedTopicReleasePublishFlow.Confirmation) -> Void
    var body: some View {
        NavigationStack {
            Form {
                Cloud02ScreenHeader(title: "approvedRelease.confirmTitle", seed: "approved-release-confirm", symbol: "paperplane")
                    .cloud02GutterRow()
                ApprovedReleaseSummarySection(prepared: original.prepared, identifierPrefix: "approvedRelease.confirm")
                Section {
                    Cloud02ActionButton(title: "approvedRelease.confirmCreate", identifier: "approvedRelease.confirm.create", systemImage: "paperplane.fill", primary: true) {
                        primaryPulse += 1
                        confirm(original)
                    }
                    .cloud02GutterRow()
                }
            }
            .p04LifecycleSurface()
            .cyHeroScreen()
            .cyDomainPageBackground()
            .cyHaptic(.impactMedium, trigger: primaryPulse)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: LocalizedStringResource("approvedRelease.confirmCancel", defaultValue: "Cancel", locale: locale))) { cancel(original) }
                        .accessibilityIdentifier("approvedRelease.confirm.cancel")
                }
            }
        }
        .themeDomain(.player)
        .onDisappear { cancel(original) }
    }
}
