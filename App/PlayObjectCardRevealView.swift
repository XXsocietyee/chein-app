import SwiftUI

extension PlayKitScreen {
    @ViewBuilder var objectCardForm: some View {
        if let receipt = model.objectCardReceipt {
            PlayObjectCardRevealView(receipt: receipt, approvedHosts: approvedArtworkHosts,
                isCurrent: { model.isCurrent && model.objectCardReceipt == receipt })
                .id("\(receipt.sessionID):\(receipt.nodeID):\(receipt.version):\(receipt.card.id)")
        } else if model.phase == "submitting" {
            CYSkeleton(label: "playCard.processing").accessibilityIdentifier("playCard.processing")
        } else if raw["passed"].bool == true || raw["flagged"].bool == true {
            // Completion and minting are different server facts. A refresh or a
            // failed mint may have no card; do not manufacture a successful reveal.
            Label("playCard.noReceipt", systemImage: "rectangle.badge.questionmark")
                .accessibilityIdentifier("playCard.noReceipt")
            Text("playCard.noReceiptDetail").cyText(.meta).foregroundStyle(CYColor.textTertiary)
        } else {
            CYHeroHeader("playCard.capture")
            if raw["degraded"].bool == true { Text("playCard.degraded").accessibilityIdentifier("playCard.degraded") }
            ordinaryPhotoCheckForm
        }
    }
}

/// Shows only server-provided pixels and rotation frames through the existing
/// bounded image loader. A source photo is not presented as a generated 3D model.
@MainActor struct PlayObjectCardRevealView: View {
    let receipt: PlayObjectCardReceipt
    let approvedHosts: Set<String>
    let isCurrent: () -> Bool
    @State private var frame = 0
    @State private var scope = UUID()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var card: ObjectCard { receipt.card }
    private var media: (any ObjectCardImageLoading)? {
        let origins = Set(approvedHosts.compactMap { host -> String? in
            let origin = "https://" + host
            return ObjectCardMediaPolicy.origin(origin) == origin ? origin : nil
        })
        return origins.isEmpty ? nil : ObjectCardBoundedImageLoader(policy: .init(approvedOrigins: origins))
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if isCurrent() {
                Label("playCard.received", systemImage: "rectangle.portrait.on.rectangle.portrait")
                    .cyText(.sheetTitle).foregroundStyle(CYColor.textPrimary).accessibilityIdentifier("playCard.received")
                ObjectCardArtwork(url: card.frame(at: frame).isEmpty ? card.thumbnail : card.frame(at: frame), label: card.title,
                    media: media, expectedScope: scope, currentScope: { isCurrent() ? scope : UUID() })
                    .frame(maxWidth: .infinity, minHeight: 240)
                    .accessibilityAdjustableAction { direction in
                        guard isCurrent(), card.hasRotationFrames else { return }
                        switch direction { case .increment: move(1); case .decrement: move(-1); @unknown default: break }
                    }
                if card.hasRotationFrames {
                    HStack {
                        Button("objects.previous") { move(-1) }.accessibilityIdentifier("playCard.previous")
                        Spacer()
                        Text("\(frame + 1) / \(card.frames.count)").monospacedDigit().accessibilityLabel(Text("a11y.value.ofTotal \(Int(frame + 1)) \(Int(card.frames.count))"))
                        Spacer()
                        Button("objects.next") { move(1) }.accessibilityIdentifier("playCard.next")
                    }.buttonStyle(.cySecondary(fullWidth: false))
                }
                Text(verbatim: card.title).cyText(.cardTitle).foregroundStyle(CYColor.textPrimary).accessibilityIdentifier("playCard.title")
                if !card.caption.isEmpty { Text(verbatim: card.caption) }
                if !card.place.isEmpty { LabeledContent("objects.place", value: card.place) }
                LabeledContent("objects.style") { Text(card.cardStyle == "plain" ? "objects.plain" : "objects.foil") }
                if card.generating { Label("objects.generating", systemImage: "hourglass") }
                if card.generationStatus == "FAILED" { Text("playCard.framesUnavailable") }
                Text("playCard.collectionHint").cyText(.meta).foregroundStyle(CYColor.textTertiary)
            } else { Text("objects.sessionChanged") }
        }.frame(maxWidth: .infinity, alignment: .leading).cyDomainCard(radius: CYRadius.lg, padding: CYSpacing.lg)
            .privacySensitive().accessibilityIdentifier("playCard.reveal")
            .onDisappear { scope = UUID(); frame = 0 }
    }
    private func move(_ delta: Int) {
        guard isCurrent(), card.hasRotationFrames else { return }
        let next = ((frame + delta) % card.frames.count + card.frames.count) % card.frames.count
        if reduceMotion { frame = next } else { withAnimation(.easeOut(duration: 0.12)) { frame = next } }
    }
}
