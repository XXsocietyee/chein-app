import SwiftUI

@MainActor struct ApprovedReleasePublicationConfirmationView: View {
    @Environment(\.locale) private var locale
    let original: ApprovedTopicReleasePublishFlow.Confirmation
    let cancel: (ApprovedTopicReleasePublishFlow.Confirmation) -> Void
    let confirm: (ApprovedTopicReleasePublishFlow.Confirmation) -> Void
    var body: some View {
        NavigationStack {
            Form {
                CYHeroHeader(verbatim: String(localized: LocalizedStringResource("approvedRelease.confirmTitle", defaultValue: "Publish this version?", locale: locale)))
                    .listRowBackground(Color.clear).listRowInsets(EdgeInsets())
                ApprovedReleaseSummarySection(prepared: original.prepared, identifierPrefix: "approvedRelease.confirm")
                Section {
                    CYPillButton(verbatim: String(localized: LocalizedStringResource("approvedRelease.confirmCreate", defaultValue: "Publish", locale: locale))) { confirm(original) }
                        .accessibilityIdentifier("approvedRelease.confirm.create")
                }
            }
            .p04LifecycleSurface()
            .cyHeroScreen()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: LocalizedStringResource("approvedRelease.confirmCancel", defaultValue: "Cancel", locale: locale))) { cancel(original) }
                        .accessibilityIdentifier("approvedRelease.confirm.cancel")
                }
            }
        }
        .preferredColorScheme(.dark)
        .onDisappear { cancel(original) }
    }
}
