import SwiftUI
import UIKit

/// Display the original bounded inline PNG. CLB-group-code-01: the MP sheet saves the code to the album
/// ("有些玩法要把码打印出来贴在站点上"); the share sheet's 存储图像 does that here. No renewal or redemption.
@MainActor struct ClubGroupCodePresentation: View {
    let value: ClubGovernanceGroupCode
    let current: Bool
    /// CLB-group-code-03 (fix-r3-club-b): re-issue in place once the code has expired. Nil while busy.
    var onReissue: (() -> Void)? = nil
    @Environment(\.scenePhase) private var scenePhase
    @State private var savedBrightness: CGFloat?
    @State private var autoReissuedFor: Date?
    private var autoReissueKey: String {
        "\(value.expiresAt.timeIntervalSince1970)|\(current)|\(scenePhase == .active)|\(onReissue != nil)"
    }
    var body: some View {
        TimelineView(.periodic(from: value.receivedAt, by: 1)) { timeline in
            if current, scenePhase == .active, value.isActive(at: timeline.date) {
                if let bytes = value.inlinePNG, let image = UIImage(data: bytes) {
                    // Mini `club-game-code-sheet` card: code on white inside an ink card, then 保存.
                    VStack(spacing: CYSpacing.sm) {
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
                VStack(alignment: .leading, spacing: CYSpacing.sm) {
                    Label("club.gov.expiredCode", systemImage: "clock.badge.exclamationmark")
                        .accessibilityIdentifier("club.gov.expiredCode")
                    if let onReissue {
                        CYPillButton("clubR3b.groupCode.reissue", style: .primary, systemImage: "arrow.clockwise", action: onReissue)
                            .accessibilityIdentifier("club.groupCode.reissue")
                    } else {
                        Text("club.gov.expiredCode.hint").cyText(.bodyCompact).foregroundStyle(.secondary)
                    }
                }
            }
        }
        // CLB-group-code-03 (fix-r3-club-b round 2), MP L08-070/071: one timer re-issues the code 30 s before it
        // expires; coming back to the foreground with 30 s or less left re-issues at once. The task restarts on
        // every new code and every scene change, and never runs in the background (MP onHide clears the timer).
        // A re-issue does not void the old code (L08-071); the button above stays as the manual path.
        .task(id: autoReissueKey) {
            // One automatic re-issue per code: a failed issue leaves the manual 重新出码 button, never a retry loop.
            guard current, scenePhase == .active, onReissue != nil, autoReissuedFor != value.expiresAt else { return }
            let lead = value.expiresAt.timeIntervalSinceNow - 30
            try? await Task.sleep(nanoseconds: UInt64(max(1, lead) * 1_000_000_000))
            guard !Task.isCancelled, current, scenePhase == .active, let onReissue else { return }
            autoReissuedFor = value.expiresAt
            onReissue()
        }
        // CLB-group-code-08 (fix-r3-club-b): full brightness while staff scan the code; restored on leave.
        .onAppear {
            guard savedBrightness == nil else { return }
            savedBrightness = UIScreen.main.brightness
            UIScreen.main.brightness = 1
        }
        .onDisappear {
            if let savedBrightness { UIScreen.main.brightness = savedBrightness }
            savedBrightness = nil
        }
    }
}
