import SwiftUI

/// OWN-D-07.e: which purposes hold location on this device now, each with a stop action
/// (`mp:pages/privacy/index.js:396-403` `syncRoamCollection`, `mp:pages/shezhi/components/privacy-sheet/index.js:85`).
/// Stopping here ends that session's location at once; the roam walk pauses on its next pulse. Withdrawing the
/// roam consent on the server stays the existing roam action, which also revokes the hold.
@MainActor struct SessionLocationHoldsSection: View {
    @ObservedObject var tracker: SessionBackgroundLocationTracker = .shared
    var body: some View {
        let ledger = tracker.ledger
        let purposes = ledger.activePurposes
        Section {
            if purposes.isEmpty {
                Text("privacy.location.holds.none").cyText(.bodyCompact).foregroundStyle(CYColor.textSecondary)
                    .accessibilityIdentifier("privacy.location.holds.none")
            }
            ForEach(purposes, id: \.self) { purpose in
                HStack(alignment: .center, spacing: CYSpacing.sm) {
                    VStack(alignment: .leading, spacing: 2) {
                        Label(LocalizedStringKey("privacy.location.holds." + purpose.rawValue), systemImage: "location.fill")
                            .cyText(.bodyCompact).foregroundStyle(CYColor.textPrimary)
                        if purpose == .roam, ledger.isBackground {
                            Text("privacy.location.holds.background").cyText(.meta).foregroundStyle(CYColor.textSecondary)
                        }
                    }
                    Spacer(minLength: 0)
                    CYPillButton("privacy.location.holds.stop", style: .secondary, fullWidth: false, compact: true) { ledger.revoke(purpose) }
                        .accessibilityIdentifier("privacy.location.holds.stop." + purpose.rawValue)
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("privacy.location.holds." + purpose.rawValue)
            }
        } header: { Text("privacy.location.holds.title") } footer: { Text("privacy.location.holds.footer") }
    }
}
