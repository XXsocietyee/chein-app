import SwiftUI

/// Position of a message inside a run of consecutive messages from the same sender.
enum ChatGroupPosition { case single, first, middle, last
    var showsTail: Bool { self == .single || self == .last }
}

/// Sent bubbles use the domain primary fill (inverted solid). Restricted accent stays off chat.
enum CYChat {
    static let sent = CYColor.actionPrimaryBg
    static let onSent = CYColor.actionPrimaryFg
}

/// Presentation only. IM, node NPC and merchant NPC keep their own models and authority.
/// The caller supplies sender truth and metadata; this view never infers delivery/read state.
/// iMessage-style: sent = accent fill (trailing), received = elevated grey (leading), consecutive messages
/// from one sender group with tight inner corners and share one timestamp.
struct ChatMessageBubble<Sender: View, Content: View>: View {
    let isOwn: Bool
    var timestamp: String? = nil
    var position: ChatGroupPosition = .single
    @ViewBuilder let sender: () -> Sender
    @ViewBuilder let content: () -> Content
    @Environment(\.dynamicTypeSize) private var typeSize
    private var shape: UnevenRoundedRectangle {
        let big: CGFloat = 20, small: CGFloat = 6
        let topInner = position == .middle || position == .last
        let bottomInner = position == .first || position == .middle
        // Inner corners are the ones facing the neighbouring bubble, on the sender's side.
        let tl = isOwn ? big : (topInner ? small : big), bl = isOwn ? big : (bottomInner ? small : big)
        let tr = isOwn ? (topInner ? small : big) : big, br = isOwn ? (bottomInner ? small : big) : big
        return UnevenRoundedRectangle(topLeadingRadius: tl, bottomLeadingRadius: bl, bottomTrailingRadius: br, topTrailingRadius: tr, style: .continuous)
    }
    var body: some View {
        VStack(alignment: isOwn ? .trailing : .leading, spacing: Theme.Space.s1) {
            sender().cyText(.meta, weight: .semibold).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            content()
                .cyText(.body)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(isOwn ? CYChat.onSent : CYColor.textPrimary)
                .environment(\.imPreviewInk, isOwn ? .sent : .page)
                .padding(.horizontal, Theme.Space.s3 + 2).padding(.vertical, Theme.Space.s2 + 1)
                .background(isOwn ? CYChat.sent : CYColor.bgRaised, in: shape)
            if let timestamp, !timestamp.isEmpty {
                Text(verbatim: timestamp).cyText(.caption).foregroundStyle(.secondary)
                    .padding(.horizontal, Theme.Space.s1)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        // Leave an opposite-side gutter, but give accessibility text the full width.
        .padding(isOwn ? .leading : .trailing, typeSize.isAccessibilitySize ? 0 : 48)
        .frame(maxWidth: .infinity, alignment: isOwn ? .trailing : .leading)
        // One VoiceOver stop per message, read in order: sender, text, time.
        .accessibilityElement(children: .combine)
    }
}
