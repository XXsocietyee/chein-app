import SwiftUI
import MapKit

/// design-r2-social P13 / P11: pages a card answer in the transcript opens. `MessagingHistoryView` owns the
/// one `navigationDestination(item:)`, so no destination lives inside a row.
enum MessagingCardRoute: Hashable {
    /// MP `onCardBtn` → `/topic/<id>`: the card's typed topic destination.
    case topic(Int)
    /// mp-nav r3, MP `system-card-target.js`: activity notices / cards open `pages/activity/detail/index`,
    /// community cards `pages/square/detail/index` (navigateTo, pushed above the chat).
    case activity(Int)
    case squarePost(Int)
    /// System review cards (MP 「查看生成时记录」) open the message detail, which owns the review sheet.
    case detail(messageID: Int)
    /// A group poll message opens the poll itself (vote / results) in one tap.
    case poll(messageID: Int)
}

/// mp-nav r3 (MP im/chat/index.wxml:64-91, index.js:1077-1094): what one tap on a card bubble opens.
/// Route and signup cards open `pages/topic/index/index?id=`; a location card with valid coordinates opens
/// navigation (MP `openAddress`). Anything else keeps the message detail page.
enum MessagingCardTap {
    static func topicID(_ message: MessagingMessage) -> Int? {
        guard let card = message.card, card.kind == .route || card.kind == .signup,
              let id = card.topicID, id > 0 else { return nil }
        return id
    }
    static func mapItem(_ message: MessagingMessage) -> MKMapItem? {
        guard let card = message.card, card.kind == .location,
              let latitude = card.latitude, let longitude = card.longitude else { return nil }
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        guard CLLocationCoordinate2DIsValid(coordinate) else { return nil }
        let item = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        item.name = card.title
        return item
    }
}

/// One-tap answers under a card message, the way the MP chat draws `genericButtons` inside the card
/// (`im/chat/index.wxml:135-137`). Answers are the MP's own buttons and only navigate, as `onCardBtn` does.
/// The first non-reject answer is prominent; the rest are quieter. Side by side when they fit, stacked when not.
struct MessagingInlineCardAnswers: View {
    let message: MessagingMessage
    let isOwn: Bool
    let isNotice: Bool
    /// Session-local record of the answer the viewer picked; drawn as a quiet system line under the card.
    let chosenLabel: String?
    let onAction: (IMCardAction) -> Void
    @ScaledMetric(relativeTo: .caption) private var avatarSize: CGFloat = 28

    static func hasAnswers(_ message: MessagingMessage) -> Bool {
        message.isPayloadVisible && !IMCardAction.displayed(for: message).isEmpty
    }

    var body: some View {
        let actions = IMCardAction.displayed(for: message)
        let primaryIndex = actions.firstIndex { !$0.isReject }
        VStack(alignment: isOwn ? .trailing : .leading, spacing: 6) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { answerButtons(actions, primaryIndex: primaryIndex) }
                VStack(alignment: .leading, spacing: 8) { answerButtons(actions, primaryIndex: primaryIndex) }
            }
            if let chosenLabel {
                MessagingQuietSystemLine(symbol: "checkmark.circle") {
                    Text("r2social.chat.chose \(chosenLabel)")
                }
                .accessibilityIdentifier("messaging.card.choiceLine.\(message.id)")
            }
        }
        .padding(.leading, isOwn || isNotice ? 0 : avatarSize + 8)
        .frame(maxWidth: .infinity, alignment: isOwn ? .trailing : .leading)
        .accessibilityIdentifier("messaging.card.inlineAnswers.\(message.id)")
    }

    @ViewBuilder private func answerButtons(_ actions: [IMCardAction], primaryIndex: Int?) -> some View {
        ForEach(Array(actions.enumerated()), id: \.offset) { index, action in
            if index == primaryIndex {
                Button { onAction(action) } label: { answerTitle(action.label) }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .controlSize(.small)
            } else {
                Button(role: action.isReject ? .destructive : nil) { onAction(action) } label: { answerTitle(action.label) }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .controlSize(.small)
            }
        }
    }

    @ViewBuilder private func answerTitle(_ label: String) -> some View {
        let shown = label.trimmingCharacters(in: .whitespacesAndNewlines)
        if label.hasPrefix("im.full.") { Text(LocalizedStringKey(label)).fixedSize(horizontal: false, vertical: true) }
        else { Text(verbatim: shown.isEmpty ? "—" : shown).fixedSize(horizontal: false, vertical: true) }
    }

    /// The label recorded in the quiet line. Only a real choice (two or more MP buttons) is recorded,
    /// and only the MP's own button text, never the app's generic 「查看详情」 fallback.
    static func choiceLabel(_ action: IMCardAction, in message: MessagingMessage) -> String? {
        guard IMCardAction.displayed(for: message).count > 1, !action.label.hasPrefix("im.full.") else { return nil }
        let shown = action.label.trimmingCharacters(in: .whitespacesAndNewlines)
        return shown.isEmpty ? nil : shown
    }
}

/// One tap from a group poll message to the poll, and once the viewer has voted, a quiet line with
/// their choice (read from the poll the coordinator already holds; no extra request).
struct MessagingInlinePollAnswer: View {
    let message: MessagingMessage
    let isOwn: Bool
    let isNotice: Bool
    let votedOption: String?
    let onOpen: () -> Void
    @ScaledMetric(relativeTo: .caption) private var avatarSize: CGFloat = 28

    var body: some View {
        VStack(alignment: isOwn ? .trailing : .leading, spacing: 6) {
            Button(action: onOpen) {
                Label {
                    Text(LocalizedStringKey(votedOption == nil ? "r2social.poll.vote" : "r2social.poll.results"))
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "chart.bar.xaxis")
                }
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.small)
            .accessibilityIdentifier("poll.inlineEntry.\(message.id)")
            if let votedOption {
                MessagingQuietSystemLine(symbol: "checkmark.circle") {
                    Text("r2social.poll.voted \(votedOption)")
                }
                .accessibilityIdentifier("poll.votedLine.\(message.id)")
            }
        }
        .padding(.leading, isOwn || isNotice ? 0 : avatarSize + 8)
        .frame(maxWidth: .infinity, alignment: isOwn ? .trailing : .leading)
    }
}

/// A quiet system line in the transcript: small, secondary, centred, wraps in any language (P13, P12).
struct MessagingQuietSystemLine<Content: View>: View {
    let symbol: String
    @ViewBuilder let content: () -> Content
    var body: some View {
        Label {
            content()
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: symbol).accessibilityHidden(true)
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}
