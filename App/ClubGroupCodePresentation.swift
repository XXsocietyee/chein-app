import SwiftUI
import UIKit

/// Display the original bounded inline PNG. CLB-group-code-01: the MP sheet saves the code to the album
/// ("有些玩法要把码打印出来贴在站点上"); the share sheet's 存储图像 does that here. No renewal or redemption.
@MainActor struct ClubGroupCodePresentation: View {
    let value: ClubGovernanceGroupCode
    let current: Bool
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        TimelineView(.periodic(from: value.receivedAt, by: 1)) { timeline in
            if current, scenePhase == .active, value.isActive(at: timeline.date) {
                if let bytes = value.inlinePNG, let image = UIImage(data: bytes) {
                    // Mini `club-game-code-sheet` card: code on white inside an ink card, then 保存.
                    VStack(spacing: Theme.Space.s2) {
                        Text("club.gov.codeAvailable").cyText(.cardTitle)
                        CYClubGameCodeCard(state: .ready, name: nil) {
                            Image(uiImage: image).interpolation(.none).resizable().scaledToFit()
                                .accessibilityLabel(Text("groupCode.image", tableName: "ClubGroupCodeDisplay"))
                                .privacySensitive().accessibilityIdentifier("club.gov.groupCode")
                        }
                        Text("club.gov.codeExpires \(Text(value.expiresAt, style: .timer))")
                            .cyText(.meta).monospacedDigit()
                        ShareLink(item: Image(uiImage: image),
                                  preview: SharePreview(Text("groupCode.image", tableName: "ClubGroupCodeDisplay"), image: Image(uiImage: image))) {
                            Label("club.groupCode.save", systemImage: "square.and.arrow.down")
                                .frame(minHeight: CYSpacing.minTouchTarget)
                        }
                        .accessibilityHint(Text("club.groupCode.save.hint"))
                        .accessibilityIdentifier("club.groupCode.save")
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
