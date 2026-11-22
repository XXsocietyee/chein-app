import SwiftUI
import UIKit

/// Display the original bounded inline PNG only. No download, export, renewal or redemption.
@MainActor struct ClubGroupCodePresentation: View {
    let value: ClubGovernanceGroupCode
    let current: Bool
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        TimelineView(.periodic(from: value.receivedAt, by: 1)) { timeline in
            if current, scenePhase == .active, value.isActive(at: timeline.date) {
                if let bytes = value.inlinePNG, let image = UIImage(data: bytes) {
                    // Mini `club-game-code-sheet` card: code on white inside an ink card. Save stays hidden
                    // here (no onSave): this presentation is display-only by design.
                    VStack(spacing: Theme.Space.s2) {
                        Text("club.gov.codeAvailable").cyText(.cardTitle)
                        CYClubGameCodeCard(state: .ready, name: nil) {
                            Image(uiImage: image).interpolation(.none).resizable().scaledToFit()
                                .accessibilityLabel(Text("groupCode.image", tableName: "ClubGroupCodeDisplay"))
                                .privacySensitive().accessibilityIdentifier("club.gov.groupCode")
                        }
                        Text("club.gov.codeExpires \(Text(value.expiresAt, style: .timer))")
                            .font(.subheadline).monospacedDigit()
                    }.frame(maxWidth: .infinity)
                } else {
                    Text("groupCode.imageUnavailable", tableName: "ClubGroupCodeDisplay")
                }
            } else {
                VStack(alignment: .leading, spacing: Theme.Space.s2) {
                    Label("club.gov.expiredCode", systemImage: "clock.badge.exclamationmark")
                        .accessibilityIdentifier("club.gov.expiredCode")
                    // Mini-program re-issues automatically; native keeps issuance behind the reviewed command.
                    Text("club.gov.expiredCode.hint").cyText(.bodyCompact).foregroundStyle(.secondary)
                }
            }
        }
    }
}
