import SwiftUI

/// This view never reads the current /prepare response or initiates a publish/retry.
/// A saved intent remains unknown until its matching authoritative receipt is present.
@MainActor struct ApprovedReleaseSummaryResultView: View {
    @Environment(\.locale) private var locale
    @Environment(\.cyPalette) private var palette
    let original: ApprovedTopicReleasePublishFlow.ResultInspection
    let close: (ApprovedTopicReleasePublishFlow.ResultInspection) -> Void
    var body: some View {
        NavigationStack {
            Form {
                Cloud02ScreenHeader(title: "approvedRelease.history.title", tableName: "ApprovedReleaseHistory", seed: "approved-release-history", symbol: "clock.arrow.circlepath")
                    .cloud02GutterRow()
                Section {
                    Cloud02Note(key: "approvedRelease.history.scope", tableName: "ApprovedReleaseHistory", identifier: "approvedRelease.history.scope")
                        .cloud02GutterRow()
                    Text(verbatim: cloud02Known(original.record.command.requestID))
                        .cyText(.meta)
                        .foregroundStyle(palette.textSecondary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("approvedRelease.history.requestID")
                        .cloud02GutterRow()
                    if let receipt = original.record.receipt {
                        savedReceipt(receipt).cloud02GutterRow()
                    } else {
                        Cloud02Note(key: "approvedRelease.unconfirmed", identifier: "approvedRelease.history.unconfirmed")
                            .cloud02GutterRow()
                    }
                }
                // Historical media is metadata-only: no new media-read authority is inferred.
                ApprovedReleaseSummarySection(prepared: original.record.prepared, identifierPrefix: "approvedRelease.history")
            }
            .p04LifecycleSurface()
            .cyHeroScreen()
            .cyDomainPageBackground()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: LocalizedStringResource("approvedRelease.close", defaultValue: "Close", locale: locale))) { close(original) }
                        .accessibilityIdentifier("approvedRelease.history.close")
                }
            }
        }
        .themeDomain(.player)
        .onDisappear { close(original) }
    }

    private func savedReceipt(_ receipt: ApprovedTopicReleasePublicationReceipt) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            Text(verbatim: String(receipt.releaseID))
                .cyText(.dataXL)
                .monospacedDigit()
                .foregroundStyle(palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("approvedRelease.history.releaseID")
            Text(verbatim: cloud02Known(receipt.manifestHash))
                .cyText(.meta)
                .foregroundStyle(palette.textSecondary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("approvedRelease.history.receiptHash")
            HStack(alignment: .firstTextBaseline, spacing: CYSpacing.sm) {
                Image(systemName: receipt.currentlyApproved ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(receipt.currentlyApproved ? palette.success : palette.warning)
                    .accessibilityHidden(true)
                Text(verbatim: receipt.currentlyApproved
                    ? String(localized: LocalizedStringResource("approvedRelease.receiptApproved", defaultValue: "Approved at the last server check", locale: locale))
                    : String(localized: LocalizedStringResource("approvedRelease.receiptChanged", defaultValue: "The last server check did not confirm current approval", locale: locale)))
                    .cyText(.body)
                    .foregroundStyle(palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(CYSpacing.lg)
        .background(palette.bgElevated, in: RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous)
                .strokeBorder(palette.borderSubtle, lineWidth: 1)
                .allowsHitTesting(false)
        }
    }
}
