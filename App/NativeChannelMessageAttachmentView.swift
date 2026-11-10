import SwiftUI

/// Delegates legal images to the original approved-origin/no-redirect media UI and reader.
/// Revocation/recall is rechecked by that reader and the current source, never local deletion.
@MainActor struct NativeChannelMessageAttachmentView: View {
    let snapshot: NativeChannelMessageSnapshot
    let reader: any SocialMessageMediaReading
    let expectedIdentity: MessagingReadIdentity
    let currentSnapshot: () -> NativeChannelMessageSnapshot?
    let permitsAccess: () -> Bool
    private var current: Bool { permitsAccess() && reader.identity == expectedIdentity && currentSnapshot() == snapshot && snapshot.status == 0 }
    private var showsExistingImage: Bool {
        guard current else { return false }
        if case .existingImage = NativeChannelMessageAttachmentAvailability.project(snapshot) { return true }
        return false
    }
    var body: some View {
        Group {
            if showsExistingImage {
                // The media screen already owns its one title. Do not stack a second hero on it.
                SocialMessageMediaView(message: snapshot.message, reader: reader, expectedIdentity: expectedIdentity,
                    isMessageCurrent: { current })
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: CYSpacing.lg) {
                        CYHeroHeader("attachment.open", tableName: "NativeChannelMessage") {
                            Color.clear
                                .aspectRatio(16.0 / 10.0, contentMode: .fit)
                                .overlay { CYCoverArt(seed: snapshot.id.rawValue, symbol: "doc") }
                                .clipShape(RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous))
                        }
                        CYEmptyState(systemImage: "doc.badge.ellipsis", "attachment.sourceRequired", tableName: "NativeChannelMessage")
                    }
                    .padding(.horizontal, CYSpacing.pageHorizontal)
                    .padding(.bottom, CYSpacing.xl)
                }
                .cyHeroScreen()
            }
        }
        .nativeChannelScreen()
        .background(CYColor.bgPage.ignoresSafeArea())
        .privacySensitive()
        .accessibilityIdentifier("ncm47.attachment")
    }
}
