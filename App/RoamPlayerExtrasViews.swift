import SwiftUI

/// BL-70 「谁在这儿打过卡」 avatar stack for a roam merchant card. Total 0 or any failure draws nothing.
struct RoamShopVisitorsStack: View {
    let source: RoamPlayerExtrasService.VisitorSource
    let visitors: RoamPlayerExtrasService.Visitors?

    var body: some View {
        if let visitors, visitors.total > 0 {
            HStack(spacing: CYSpacing.xs) {
                HStack(spacing: -CYSpacing.xs) {
                    ForEach(Array(visitors.faces.enumerated()), id: \.offset) { _, face in
                        AsyncImage(url: face) { image in image.resizable().scaledToFill() } placeholder: { Circle().fill(CYColor.textTertiary) }
                            .frame(width: CYSpacing.lg, height: CYSpacing.lg)
                            .clipShape(Circle())
                            .accessibilityHidden(true)
                    }
                }
                Text("roam.shop.visitors \(visitors.total)").cyText(.meta).foregroundStyle(CYColor.textSecondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("roam.shop.visitors.\(source.sourceType).\(source.sourceID)")
        }
    }
}

/// Loads visitors for a strip of cards at once (one request per source type), like `_loadShopStripVisitors`.
@MainActor final class RoamShopVisitorsModel: ObservableObject {
    @Published private(set) var visitors: [RoamPlayerExtrasService.VisitorSource: RoamPlayerExtrasService.Visitors] = [:]
    private var epoch = 0

    func load(_ sources: [RoamPlayerExtrasService.VisitorSource], client: PlayerCapabilityClient) async {
        epoch += 1
        let current = epoch
        let result = await RoamPlayerExtrasService(client: client).visitors(for: sources)
        guard current == epoch else { return }
        visitors = result
    }
}

/// `revokeShareSnapshots`: 「作废本人全部分享快照」. A failure leaves the pending mark so the next publish revokes first.
struct RoamShareRevokeRow: View {
    let client: PlayerCapabilityClient
    /// Per account, like `roam_share_revoke_pending:<owner>`; no account reads or writes no key.
    @AppStorage private var pending: Bool
    init(client: PlayerCapabilityClient, accountID: Int) {
        self.client = client
        _pending = AppStorage(wrappedValue: false, "roam.share.revokePending.\(accountID)")
    }
    @Environment(\.locale) private var locale
    @State private var busy = false
    @State private var confirming = false
    @State private var done = false

    var body: some View {
        Button(role: .destructive) { confirming = true } label: {
            Label(PlayerCapabilityCopy.text(done ? "已作废全部分享链接" : "作废我发出的全部分享链接",
                                            done ? "All share links revoked" : "Revoke all my share links", locale),
                  systemImage: done ? "checkmark.circle" : "link.badge.plus")
        }
        .disabled(busy)
        .accessibilityIdentifier("roam.share.revoke")
        .confirmationDialog(PlayerCapabilityCopy.text("作废后，已发出的分享链接都打不开", "Shared links will stop opening", locale),
                            isPresented: $confirming, titleVisibility: .visible) {
            Button(PlayerCapabilityCopy.text("全部作废", "Revoke all", locale), role: .destructive) { Task { await revoke() } }
        }
        .task { if pending { await revoke() } }
    }

    private func revoke() async {
        guard !busy else { return }
        busy = true; pending = true
        let ok = await RoamPlayerExtrasService(client: client).revokeShareSnapshots()
        if ok { pending = false; done = true }
        busy = false
    }
}

/// Finished-session archive (`_archiveFinishedRecords`): batches of ≤ 200 tiles; a batch leaves the pending
/// list only when the server confirms it. Returns the tiles still pending.
enum RoamSessionArchive {
    static func flush(_ pending: [RoamPlayerExtrasService.TileRecord], sessionID: Int, clientSessionKey: String?,
                      client: PlayerCapabilityClient) async -> [RoamPlayerExtrasService.TileRecord] {
        var remaining = pending
        let service = RoamPlayerExtrasService(client: client)
        while !remaining.isEmpty {
            let batch = Array(remaining.prefix(RoamPlayerExtrasService.recordBatchMax))
            guard (try? await service.archive(sessionID: sessionID, clientSessionKey: clientSessionKey, records: batch)) != nil else {
                return remaining
            }
            remaining.removeFirst(batch.count)
        }
        return remaining
    }
}
