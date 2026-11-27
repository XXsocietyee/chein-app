import SwiftUI

/// A static detail of an already-fetched message. The source declares no message-info
/// endpoint, so this never fabricates a fresh detail read. Optional card actions resolve
/// only into typed native destinations; arbitrary payload paths remain disabled.
@MainActor
struct MessagingMessageDetailView: View {
    let message: MessagingMessage
    let conversation: MessagingConversation?
    let reader: any MessagingReading
    let identity: MessagingReadIdentity?
    var mediaReader: (any SocialMessageMediaReading)? = nil
    var expanded: IMExpandedNavigationContext? = nil
    /// Resolve refreshed history by ID; a vanished row must not fall back to its old payload.
    var currentMessage: (() -> MessagingMessage?)? = nil
    private var currentSnapshot: MessagingMessage? {
        if let currentMessage { return currentMessage() }
        return message
    }
    @State private var selectedTopicID: Int?
    @State private var selectedReview: MessagingCardResult?
    @State private var selectedPage: MessagingDetailPage?
    var body: some View {
        cyDomainBody.cyDomainScreen(.player)
    }

    @ViewBuilder private var cyDomainBody: some View {
        Group {
            if identity != nil, reader.identity == identity, let message = currentSnapshot {
                List {
                    Section {
                        MessagingMessageContent(message: message).textSelection(.enabled)
                    } header: {
                        Text("messaging.message.content")
                    }
                    if message.isPayloadVisible, message.type == 2, let preview = expanded?.attachmentPreview?(message) {
                        Section {
                            NavigationLink {
                                NativeChannelAttachmentPreviewEntry(flow: preview, current: {
                                    reader.identity == identity && currentSnapshot == message && message.isPayloadVisible
                                })
                            } label: {
                                Label("messaging.attachment.open", systemImage: "paperclip")
                            }
                        }
                    }
                    if message.isPayloadVisible, message.type == 2, let mediaReader, let identity {
                        Section {
                            NavigationLink { SocialMessageMediaView(message: message, reader: mediaReader, expectedIdentity: identity,
                                isMessageCurrent: { reader.identity == identity && currentSnapshot == message && message.isPayloadVisible }) } label: {
                                Label("social.media.title", systemImage: "photo.on.rectangle.angled")
                            }.accessibilityIdentifier("messaging.message.preview")
                        }
                    }
                    if let ref = IMVoiceReference.read(message), let owner = expanded?.voiceCoordinator?(message.conversationID) {
                        Section {
                            NavigationLink { IMVoicePlaybackView(message: message, owner: owner, current: {
                                reader.identity == identity && currentSnapshot == message && message.isPayloadVisible
                            }) } label: { IMVoiceCardLabel(reference: ref) }
                        }
                    }
                    if let ref = IMFileReference.read(message), let owner = expanded?.fileCoordinator?(message.conversationID) {
                        Section {
                            NavigationLink { IMFilePreviewView(message: message, owner: owner, current: {
                                reader.identity == identity && currentSnapshot == message && message.isPayloadVisible
                            }) } label: { IMFileCardLabel(reference: ref) }
                        }
                    }
                    if let ref = IMVideoReference.read(message), let owner = expanded?.videoCoordinator?(message.conversationID) {
                        Section {
                            NavigationLink { IMVideoPlaybackView(message: message, owner: owner, current: {
                                reader.identity == identity && currentSnapshot == message && message.isPayloadVisible
                            }) } label: { IMVideoCardLabel(reference: ref) }
                        }
                    }
                    if message.isPayloadVisible, let reference = message.pollReference {
                        Section {
                            NavigationLink {
                                if currentSnapshot?.isPayloadVisible == true, currentSnapshot?.pollReference == reference,
                                   let owner = expanded?.pollCoordinator?(message.conversationID, reference) {
                                    if message.type == 9 {
                                        GroupPollOriginalResultView(owner: owner, reference: reference, current: {
                                            reader.identity == identity && currentSnapshot == message && message.isPayloadVisible
                                        })
                                    } else {
                                        GroupPollView(owner: owner, current: {
                                            reader.identity == identity && currentSnapshot == message && message.isPayloadVisible
                                                && owner.reference == reference && owner.scope.conversationID == message.conversationID
                                        })
                                    }
                                }
                                else { GroupPollUnavailableView() }
                            } label: {
                                Label("poll.openResults", systemImage: "chart.bar.xaxis")
                            }
                            .accessibilityIdentifier("poll.messageEntry")
                        }
                    }
                    if let notice = NativeChannelGovernanceNotice.parse(message: message, conversation: conversation, identity: identity) {
                        Section {
                            NavigationLink {
                                if reader.identity == identity, currentSnapshot == message,
                                   let destination = expanded?.channelGovernanceDestination?(notice) { destination }
                                else {
                                    ContentUnavailableView("messaging.governance.unavailable", systemImage: "exclamationmark.circle")
                                }
                            } label: {
                                Label("messaging.governance.open", systemImage: "doc.text.magnifyingglass")
                            }
                            .accessibilityIdentifier("channel.governance.originalNotice")
                        } header: {
                            Text("messaging.governance.section")
                        }
                    }
                    Section {
                        LabeledContent {
                            MessagingSenderName(message: message, conversation: conversation, accountID: identity?.accountID ?? 0)
                                .fixedSize(horizontal: false, vertical: true)
                        } label: {
                            Label("messaging.message.sender", systemImage: "person")
                        }
                        .accessibilityElement(children: .combine)
                        LabeledContent {
                            Text(verbatim: playerFactOrDash(message.createdAt))
                        } label: {
                            Label("messaging.message.created", systemImage: "clock")
                        }
                    } header: {
                        Text("messaging.message.details")
                    }
                    if message.isPayloadVisible, expanded != nil, !IMCardAction.displayed(for: message).isEmpty {
                        Section {
                            IMCardActionsView(message: message) { destination in
                                guard reader.identity == identity, currentSnapshot == message, message.isPayloadVisible else { return }
                                if let id = message.card?.broadcastID {
                                    let sender = reader as? MessagingSessionReader
                                    Task { await sender?.reportBroadcastClick(id: id) }
                                }
                                switch destination {
                                case .topic(let id): selectedTopicID = id
                                case .activity(let id): selectedPage = MessagingDetailPage(path: "pages/activity/detail/index", id: id)
                                case .squarePost(let id): selectedPage = MessagingDetailPage(path: "pages/square/detail/index", id: id)
                                case .review(let result): selectedReview = result
                                case .unsupported: break
                                }
                            }
                        } header: {
                            Text("messaging.card.actions")
                        }
                    }
                    if let card = message.card {
                        if let topicID = card.topicID {
                            Section {
                                // w2-20: source route/signup cards read their display fresh.
                                if let topicReader = expanded?.topicReader {
                                    IMRouteCardPreview(topicID: topicID, isSignup: card.kind == .signup, reader: topicReader)
                                }
                            }
                        }
                        if card.kind == .location, let latitude = card.latitude, let longitude = card.longitude {
                            Section { IMLocationCardMap(title: card.title, latitude: latitude, longitude: longitude) }
                        }
                        if expanded == nil, !card.buttonLabels.isEmpty {
                            Section {
                                ForEach(Array(card.buttonLabels.enumerated()), id: \.offset) { _, label in
                                    Text(verbatim: label)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            } header: {
                                Text("messaging.card.actions")
                            }
                        }
                        if message.senderID == 0, let result = card.result {
                            Section {
                                messageFact("messaging.card.outcome", result.outcome, symbol: "flag")
                                messageFact("messaging.card.reason", result.reason, symbol: "text.quote")
                                messageFact("messaging.card.followUp", result.followUp, symbol: "arrow.turn.down.right")
                            } header: {
                                Text("messaging.card.result")
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .accessibilityIdentifier("messaging.message.detail")
            } else {
                MessagingIssueView(issue: .init(APIError.unauthorized), identifier: "messaging.message.signedOut", retry: {})
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        .navigationDestination(item: $selectedTopicID) { id in
            if reader.identity == identity, currentSnapshot?.isPayloadVisible == true, let expanded { TopicDetailView(id: id, reader: expanded.topicReader) }
        }
        .navigationDestination(item: $selectedPage) { page in
            if reader.identity == identity, currentSnapshot?.isPayloadVisible == true, let view = expanded?.pageDestination?(page.path, page.id) { view }
        }
        .cySheet(isPresented: Binding(get: { selectedReview != nil }, set: { if !$0 { selectedReview = nil } })) {
            if reader.identity == identity, currentSnapshot?.isPayloadVisible == true, let result = selectedReview {
                NavigationStack {
                    List {
                        // Mini-program 「生成时记录」: 审核任务 # / 业务 # first, then the outcome as recorded.
                        if let task = result.taskID { LabeledContent { Text(verbatim: "#" + task) } label: { Label("mpd.review.task", systemImage: "number") } }
                        if let business = result.businessID { LabeledContent { Text(verbatim: "#" + business) } label: { Label("mpd.review.business", systemImage: "tag") } }
                        messageFact("messaging.card.outcome", result.outcome, symbol: "flag")
                        messageFact("messaging.card.reason", result.reason, symbol: "text.quote")
                        messageFact("messaging.card.followUp", result.followUp, symbol: "arrow.turn.down.right")
                        IMReviewCurrentRecordSection(taskID: result.taskID, cardTitle: currentSnapshot?.card?.title)
                    }
                    .listStyle(.insetGrouped)
                    .navigationTitle(Text("im.full.reviewResult")).navigationBarTitleDisplayMode(.inline)
                    .toolbar { Button("action.done") { selectedReview = nil } }
                }.privacySensitive()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
        .onChange(of: currentSnapshot) { _, _ in selectedTopicID = nil; selectedReview = nil; selectedPage = nil }
        .onChange(of: reader.identity) { _, _ in selectedTopicID = nil; selectedReview = nil; selectedPage = nil }
        .privacySensitive()
        .navigationTitle(Text("messaging.message.title")).navigationBarTitleDisplayMode(.inline)
    }

    private func messageFact(_ title: LocalizedStringKey, _ value: String?, symbol: String) -> some View {
        LabeledContent {
            Text(verbatim: playerFactOrDash(value))
        } label: {
            Label(title, systemImage: symbol)
        }
    }
}

struct MessagingMessageContent: View {
    let message: MessagingMessage
    /// Design pass P11: transcript rows hint that a card with answers opens them; the detail page shows the answers.
    var inTranscript = false
    var body: some View {
        if !message.isPayloadVisible {
            Label(LocalizedStringKey(message.status == .recalled ? "messaging.message.recalled" : "messaging.message.withheld"), systemImage: "eye.slash")
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("messaging.message.withheld")
        } else {
        switch message.type {
        case 1:
            if let text = message.content, !text.isEmpty {
                Text(verbatim: text)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            else {
                Text("messaging.message.noText")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        case 2:
            // Deliberately no AsyncImage/URLSession: external image fetches can disclose
            // the reader's IP or produce tracking side effects. Native placeholder only.
            Label("messaging.imagePlaceholder", systemImage: "photo").foregroundStyle(.secondary)
                .accessibilityIdentifier("messaging.message.image")
        case 3:
            if let card = message.card { MessagingCardContent(card: card, isTrustedSystem: message.senderID == 0, showsRespondHint: inTranscript) }
            else { Label("messaging.cardUnavailable", systemImage: "rectangle.slash").foregroundStyle(.secondary) }
        case 4:
            if message.pollReference != nil {
                VStack(alignment: .leading, spacing: 8) {
                    Label("poll.title", systemImage: "chart.bar.xaxis").font(.headline)
                }.accessibilityIdentifier("poll.messageCard")
            } else { Label("poll.invalidCard", systemImage: "exclamationmark.bubble").foregroundStyle(.secondary).accessibilityIdentifier("poll.invalidCard") }
        case 13:
            if let place = IMStaticLocation.read(message) { IMStaticLocationCardView(place: place) }
            else { Label("messaging.unsupported", systemImage: "questionmark.bubble").foregroundStyle(.secondary) }
        case 9:
            if message.pollReference != nil {
                Label("poll.openResults", systemImage: "chart.bar.xaxis").font(.headline)
            } else { Label("messaging.unsupported", systemImage: "questionmark.bubble").foregroundStyle(.secondary) }
        default:
            Label("messaging.unsupported", systemImage: "questionmark.bubble").foregroundStyle(.secondary)
        }
    }
    }
}

private struct MessagingCardContent: View {
    let card: MessagingCard
    /// Kept so the call site still records whether the sender is the trusted system account.
    let isTrustedSystem: Bool
    /// Design pass P11: in the transcript a card that carries answers says so, since the row opens the answers.
    var showsRespondHint = false
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .headline) private var tileSide: CGFloat = 36
    var body: some View {
        let _ = isTrustedSystem
        // Design pass P5: every card kind keeps one icon tile and tint, in the bubble and on the detail page alike.
        HStack(alignment: .top, spacing: 10) {
            if !typeSize.isAccessibilitySize {
                Image(systemName: symbol)
                    .font(.headline)
                    .foregroundStyle(tint)
                    .frame(width: tileSide, height: tileSide)
                    .background(tint.opacity(0.16), in: RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous))
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 6) {
                switch card.kind {
                case .location:
                    Text("messaging.card.location").font(.footnote.weight(.semibold)).foregroundStyle(tint)
                    if let title = card.title { Text(verbatim: title).font(.headline).fixedSize(horizontal: false, vertical: true) }
                    if let address = card.address { Text(verbatim: address).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
                case .route:
                    Text("messaging.card.route").font(.footnote.weight(.semibold)).foregroundStyle(tint)
                    if let title = card.title { Text(verbatim: title).font(.headline).fixedSize(horizontal: false, vertical: true) }
                case .signup:
                    Text("messaging.card.signup").font(.footnote.weight(.semibold)).foregroundStyle(tint)
                    if let title = card.title { Text(verbatim: title).font(.headline).fixedSize(horizontal: false, vertical: true) }
                case .generic:
                    if let title = card.title { Text(verbatim: title).font(.headline).fixedSize(horizontal: false, vertical: true) }
                    else { Text("messaging.card.notification").font(.headline).fixedSize(horizontal: false, vertical: true) }
                    if let subtitle = card.subtitle { Text(verbatim: subtitle).font(.body).fixedSize(horizontal: false, vertical: true) }
                    if let meta = card.meta { Text(verbatim: meta).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
                }
                if showsRespondHint, !card.buttonLabels.isEmpty {
                    Label("comp.social.card.respond", systemImage: "hand.tap")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tint)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("messaging.card.respondHint")
                }
            }
        }
        .accessibilityElement(children: .contain)
    }
    private var symbol: String {
        switch card.kind {
        case .location: return "mappin.and.ellipse"
        case .route: return "point.topleft.down.to.point.bottomright.curvepath"
        case .signup: return "ticket"
        case .generic: return card.buttonLabels.isEmpty ? "bell" : "envelope.open"
        }
    }
    private var tint: Color {
        switch card.kind {
        case .location: return .green
        case .route: return .blue
        case .signup: return .orange
        case .generic: return .secondary
        }
    }
}

/// mp-nav r3: an MP page a system card opens (`system-card-target.js`), pushed from the message detail.
struct MessagingDetailPage: Hashable {
    let path: String
    let id: Int
}
