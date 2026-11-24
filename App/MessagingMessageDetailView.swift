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
    var body: some View {
        cyDomainBody.cyDomainScreen(.player)
    }

    @ViewBuilder private var cyDomainBody: some View {
        Group {
            if identity != nil, reader.identity == identity, let message = currentSnapshot {
                List {
                    Section {
                        CYHeroHeader("messaging.message.title")
                    }.e1HeroRow()
                    Section {
                        MessagingMessageContent(message: message).textSelection(.enabled)
                    } header: {
                        CYSectionHeader("messaging.message.content")
                    }
                    .messageRow()
                    if message.isPayloadVisible, message.type == 2, let preview = expanded?.attachmentPreview?(message) {
                        Section {
                            NavigationLink {
                                NativeChannelAttachmentPreviewEntry(flow: preview, current: {
                                    reader.identity == identity && currentSnapshot == message && message.isPayloadVisible
                                })
                            } label: {
                                CYListRow("messaging.attachment.open", trailing: .none) { CYRowIcon(systemImage: "paperclip") }
                            }
                        }
                        .messageRow()
                    }
                    if message.isPayloadVisible, message.type == 2, let mediaReader, let identity {
                        Section {
                            NavigationLink { SocialMessageMediaView(message: message, reader: mediaReader, expectedIdentity: identity,
                                isMessageCurrent: { reader.identity == identity && currentSnapshot == message && message.isPayloadVisible }) } label: {
                                CYListRow("social.media.title", trailing: .none) { CYRowIcon(systemImage: "photo.on.rectangle.angled") }
                            }.accessibilityIdentifier("messaging.message.preview")
                        }
                        .messageRow()
                    }
                    if let ref = IMVoiceReference.read(message), let owner = expanded?.voiceCoordinator?(message.conversationID) {
                        Section {
                            NavigationLink { IMVoicePlaybackView(message: message, owner: owner, current: {
                                reader.identity == identity && currentSnapshot == message && message.isPayloadVisible
                            }) } label: { IMVoiceCardLabel(reference: ref) }.buttonStyle(E3PressStyle())
                        }
                        .messageRow()
                    }
                    if let ref = IMFileReference.read(message), let owner = expanded?.fileCoordinator?(message.conversationID) {
                        Section {
                            NavigationLink { IMFilePreviewView(message: message, owner: owner, current: {
                                reader.identity == identity && currentSnapshot == message && message.isPayloadVisible
                            }) } label: { IMFileCardLabel(reference: ref) }.buttonStyle(E3PressStyle())
                        }
                        .messageRow()
                    }
                    if let ref = IMVideoReference.read(message), let owner = expanded?.videoCoordinator?(message.conversationID) {
                        Section {
                            NavigationLink { IMVideoPlaybackView(message: message, owner: owner, current: {
                                reader.identity == identity && currentSnapshot == message && message.isPayloadVisible
                            }) } label: { IMVideoCardLabel(reference: ref) }.buttonStyle(E3PressStyle())
                        }
                        .messageRow()
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
                                CYListRow("poll.openResults", trailing: .none) { CYRowIcon(systemImage: "chart.bar.xaxis") }
                            }
                            .accessibilityIdentifier("poll.messageEntry")
                        }
                        .messageRow()
                    }
                    if let notice = NativeChannelGovernanceNotice.parse(message: message, conversation: conversation, identity: identity) {
                        Section {
                            NavigationLink {
                                if reader.identity == identity, currentSnapshot == message,
                                   let destination = expanded?.channelGovernanceDestination?(notice) { destination }
                                else {
                                    CYEmptyState(systemImage: "exclamationmark.circle", "messaging.governance.unavailable")
                                }
                            } label: {
                                CYListRow("messaging.governance.open", trailing: .none) { CYRowIcon(systemImage: "doc.text.magnifyingglass") }
                            }
                            .accessibilityIdentifier("channel.governance.originalNotice")
                        } header: {
                            CYSectionHeader("messaging.governance.section")
                        }
                        .messageRow()
                    }
                    Section {
                        HStack(alignment: .center, spacing: CYSpacing.md) {
                            CYRowIcon(systemImage: "person")
                            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                                Text("messaging.message.sender")
                                    .cyText(.meta)
                                    .foregroundStyle(CYColor.textSecondary)
                                MessagingSenderName(message: message, conversation: conversation, accountID: identity?.accountID ?? 0)
                                    .cyText(.cardTitle)
                                    .foregroundStyle(CYColor.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: CYSpacing.sm)
                        }
                        .frame(minHeight: CYSpacing.minTouchTarget)
                        .accessibilityElement(children: .combine)
                        CYListRow("messaging.message.created", trailing: .value(playerFactOrDash(message.createdAt))) {
                            CYRowIcon(systemImage: "clock")
                        }
                    } header: {
                        CYSectionHeader("messaging.message.details")
                    }
                    .messageRow()
                    if message.isPayloadVisible, expanded != nil, message.card != nil {
                        Section {
                            IMCardActionsView(message: message) { destination in
                                guard reader.identity == identity, currentSnapshot == message, message.isPayloadVisible else { return }
                                if let id = message.card?.broadcastID {
                                    let sender = reader as? MessagingSessionReader
                                    Task { await sender?.reportBroadcastClick(id: id) }
                                }
                                switch destination {
                                case .topic(let id): selectedTopicID = id
                                case .review(let result): selectedReview = result
                                case .unsupported: break
                                }
                            }
                        } header: {
                            CYSectionHeader("messaging.card.actions")
                        }
                        .messageRow()
                    }
                    if let card = message.card {
                        if let topicID = card.topicID {
                            Section {
                                // w2-20: source route/signup cards read their display fresh.
                                if let topicReader = expanded?.topicReader {
                                    IMRouteCardPreview(topicID: topicID, isSignup: card.kind == .signup, reader: topicReader)
                                }
                            }
                            .messageRow()
                        }
                        if card.kind == .location, let latitude = card.latitude, let longitude = card.longitude {
                            Section { IMLocationCardMap(title: card.title, latitude: latitude, longitude: longitude) }
                                .messageRow()
                        }
                        if expanded == nil, !card.buttonLabels.isEmpty {
                            Section {
                                ForEach(Array(card.buttonLabels.enumerated()), id: \.offset) { _, label in
                                    Text(verbatim: label)
                                        .cyText(.body)
                                        .foregroundStyle(CYColor.textPrimary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            } header: {
                                CYSectionHeader("messaging.card.actions")
                            }
                            .messageRow()
                        }
                        if message.senderID == 0, let result = card.result {
                            Section {
                                messageFact("messaging.card.outcome", result.outcome, symbol: "flag")
                                messageFact("messaging.card.reason", result.reason, symbol: "text.quote")
                                messageFact("messaging.card.followUp", result.followUp, symbol: "arrow.turn.down.right")
                            } header: {
                                CYSectionHeader("messaging.card.result")
                            }
                            .messageRow()
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .environment(\.defaultMinListRowHeight, 44)
                .cyGroupedSurface()
                .accessibilityIdentifier("messaging.message.detail")
            } else {
                VStack(alignment: .leading, spacing: CYSpacing.lg) {
                    CYHeroHeader("messaging.message.title")
                        .padding(.horizontal, CYSpacing.pageHorizontal)
                    MessagingIssueView(issue: .init(APIError.unauthorized), identifier: "messaging.message.signedOut", retry: {})
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(CYColor.bgPage.ignoresSafeArea())
            }
        }
        .navigationDestination(item: $selectedTopicID) { id in
            if reader.identity == identity, currentSnapshot?.isPayloadVisible == true, let expanded { TopicDetailView(id: id, reader: expanded.topicReader) }
        }
        .sheet(isPresented: Binding(get: { selectedReview != nil }, set: { if !$0 { selectedReview = nil } })) {
            if reader.identity == identity, currentSnapshot?.isPayloadVisible == true, let result = selectedReview {
                NavigationStack {
                    List {
                        Section { CYHeroHeader("im.full.reviewResult") }.e1HeroRow()
                        // Mini-program 「生成时记录」: 审核任务 # / 业务 # first, then the outcome as recorded.
                        if let task = result.taskID { CYListRow("mpd.review.task", trailing: .value("#" + task)) { CYRowIcon(systemImage: "number") } }
                        if let business = result.businessID { CYListRow("mpd.review.business", trailing: .value("#" + business)) { CYRowIcon(systemImage: "tag") } }
                        messageFact("messaging.card.outcome", result.outcome, symbol: "flag")
                        messageFact("messaging.card.reason", result.reason, symbol: "text.quote")
                        messageFact("messaging.card.followUp", result.followUp, symbol: "arrow.turn.down.right")
                        IMReviewCurrentRecordSection(taskID: result.taskID, cardTitle: currentSnapshot?.card?.title)
                    }
                    .listStyle(.insetGrouped)
                    .cyGroupedSurface()
                    .cyHeroScreen()
                    .toolbar { Button("action.done") { selectedReview = nil } }
                }.privacySensitive()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
        .onChange(of: currentSnapshot) { _, _ in selectedTopicID = nil; selectedReview = nil }
        .onChange(of: reader.identity) { _, _ in selectedTopicID = nil; selectedReview = nil }
        .privacySensitive()
        .cyHeroScreen()
    }

    private func messageFact(_ title: LocalizedStringKey, _ value: String?, symbol: String) -> some View {
        CYListRow(title, trailing: .value(playerFactOrDash(value))) { CYRowIcon(systemImage: symbol) }
    }
}

private extension View {
    func messageRow() -> some View {
        listRowInsets(EdgeInsets(top: CYSpacing.sm, leading: CYSpacing.pageHorizontal, bottom: CYSpacing.sm, trailing: CYSpacing.pageHorizontal))
    }
}

struct MessagingMessageContent: View {
    let message: MessagingMessage
    var body: some View {
        if !message.isPayloadVisible {
            Label(LocalizedStringKey(message.status == .recalled ? "messaging.message.recalled" : "messaging.message.withheld"), systemImage: "eye.slash")
                .cyText(.body)
                .foregroundStyle(CYColor.textSecondary)
                .accessibilityIdentifier("messaging.message.withheld")
        } else {
        switch message.type {
        case 1:
            if let text = message.content, !text.isEmpty {
                Text(verbatim: text)
                    .cyText(.body)
                    .foregroundStyle(CYColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            else {
                Text("messaging.message.noText")
                    .cyText(.body)
                    .foregroundStyle(CYColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        case 2:
            // Deliberately no AsyncImage/URLSession: external image fetches can disclose
            // the reader's IP or produce tracking side effects. Native placeholder only.
            CYImageCard("messaging.imagePlaceholder")
                .accessibilityIdentifier("messaging.message.image")
        case 3:
            if let card = message.card { MessagingCardContent(card: card, isTrustedSystem: message.senderID == 0) }
            else { Label("messaging.cardUnavailable", systemImage: "rectangle.slash").cyText(.body).foregroundStyle(CYColor.textSecondary) }
        case 4:
            if message.pollReference != nil {
                VStack(alignment: .leading, spacing: CYSpacing.sm) {
                    Label("poll.title", systemImage: "chart.bar.xaxis").cyText(.cardTitle).foregroundStyle(CYColor.textPrimary)
                }.accessibilityIdentifier("poll.messageCard")
            } else { Label("poll.invalidCard", systemImage: "exclamationmark.bubble").cyText(.body).foregroundStyle(CYColor.textSecondary).accessibilityIdentifier("poll.invalidCard") }
        case 13:
            if let place = IMStaticLocation.read(message) { IMStaticLocationCardView(place: place) }
            else { Label("messaging.unsupported", systemImage: "questionmark.bubble").cyText(.body).foregroundStyle(CYColor.textSecondary) }
        case 9:
            if message.pollReference != nil {
                Label("poll.openResults", systemImage: "chart.bar.xaxis").cyText(.cardTitle).foregroundStyle(CYColor.textPrimary)
            } else { Label("messaging.unsupported", systemImage: "questionmark.bubble").cyText(.body).foregroundStyle(CYColor.textSecondary) }
        default:
            Label("messaging.unsupported", systemImage: "questionmark.bubble").cyText(.body).foregroundStyle(CYColor.textSecondary)
        }
    }
    }
}

private struct MessagingCardContent: View {
    let card: MessagingCard
    /// Kept so the call site still records whether the sender is the trusted system account.
    let isTrustedSystem: Bool
    var body: some View {
        let _ = isTrustedSystem
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            switch card.kind {
            case .location:
                Label("messaging.card.location", systemImage: "mappin.and.ellipse").cyText(.cardTitle).foregroundStyle(CYColor.textPrimary)
                if let title = card.title { Text(verbatim: title).cyText(.body).foregroundStyle(CYColor.textPrimary).fixedSize(horizontal: false, vertical: true) }
                if let address = card.address { Text(verbatim: address).cyText(.meta).foregroundStyle(CYColor.textSecondary).fixedSize(horizontal: false, vertical: true) }
            case .route:
                Label("messaging.card.route", systemImage: "point.topleft.down.to.point.bottomright.curvepath").cyText(.cardTitle).foregroundStyle(CYColor.textPrimary)
                if let title = card.title { Text(verbatim: title).cyText(.body).foregroundStyle(CYColor.textPrimary).fixedSize(horizontal: false, vertical: true) }
            case .signup:
                Label("messaging.card.signup", systemImage: "ticket").cyText(.cardTitle).foregroundStyle(CYColor.textPrimary)
                if let title = card.title { Text(verbatim: title).cyText(.body).foregroundStyle(CYColor.textPrimary).fixedSize(horizontal: false, vertical: true) }
            case .generic:
                if let title = card.title { Text(verbatim: title).cyText(.cardTitle).foregroundStyle(CYColor.textPrimary).fixedSize(horizontal: false, vertical: true) }
                else { Text("messaging.card.notification").cyText(.cardTitle).foregroundStyle(CYColor.textPrimary).fixedSize(horizontal: false, vertical: true) }
                if let subtitle = card.subtitle { Text(verbatim: subtitle).cyText(.body).foregroundStyle(CYColor.textPrimary).fixedSize(horizontal: false, vertical: true) }
                if let meta = card.meta { Text(verbatim: meta).cyText(.meta).foregroundStyle(CYColor.textSecondary).fixedSize(horizontal: false, vertical: true) }
            }
        }
        .accessibilityElement(children: .contain)
    }
}
