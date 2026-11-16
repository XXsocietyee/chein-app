import SwiftUI

@MainActor private final class ClubChatViewModel: ObservableObject {
    @Published var phase: ClubChatPhase = .idle
    let owner: ClubChatCoordinator
    init(_ owner: ClubChatCoordinator) { self.owner = owner }
    func observe() { owner.onChange = { [weak self] in self?.phase = self?.owner.visiblePhase ?? .stale }; phase = owner.visiblePhase }
}
@MainActor struct SessionClubChatView: View {
    let clubID: Int
    @ObservedObject var session: AppSession
    var body: some View {
        Group {
            if let owner = session.clubChatCoordinator(clubID: clubID) {
                ClubChatEntryView(owner: owner, session: session)
            } else {
                ClubChatUnavailableView()
            }
        }
    }
}
@MainActor private struct ClubChatEntryView: View {
    @StateObject private var model: ClubChatViewModel
    @ObservedObject var session: AppSession
    @State private var conversation: MessagingConversation?
    /// `session.messagingReader` builds a new reader on every access. Passing it straight into the
    /// history made every re-render of this page (the push itself runs `suspend()` → `onChange`, and
    /// any AppSession publish) a new reader identity, so the history restarted its read and the
    /// composer stayed locked on 请先成功加载此会话 while the user typed and tapped Send (F-09).
    /// Keep one reader per issuance, exactly as the messaging home does.
    @StateObject private var readerOwner = SessionMessagingHomeReaderOwner()
    @Environment(\.cyPalette) private var palette
    init(owner: ClubChatCoordinator, session: AppSession) { _model = StateObject(wrappedValue: ClubChatViewModel(owner)); self.session = session }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CYSpacing.lg) {
                CYHeroHeader("club.chat.title", subtitle: "club.chat.explanation")
                if !model.owner.service.isConfigured {
                    Text("club.chat.disabled")
                        .font(CYTypography.body)
                        .foregroundStyle(palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("club.chat.disabled")
                }
                phaseStatus
                enterButton
                    .disabled(!model.owner.canEnter)
                    .accessibilityIdentifier("club.chat.enter")
            }
            .padding(.horizontal, CYSpacing.pageHorizontal)
            .padding(.vertical, CYSpacing.lg)
        }
        .cyDomainPageBackground()
        .privacySensitive()
        .accessibilityIdentifier("club.chat.screen")
        .onAppear { model.observe() }
        .onDisappear { model.owner.suspend() }
        .onChange(of: model.owner.isCurrent) { _, current in if !current { conversation = nil } }
        .navigationDestination(isPresented: Binding(get: { conversation != nil && model.owner.isCurrent }, set: { if !$0 { conversation = nil } })) {
            if let conversation, model.owner.isCurrent {
                MessagingHistoryView(conversationID: conversation.id, conversation: conversation, reader: readerOwner.reader(for: session),
                    sender: session.messageSender(for: conversation.id), mediaReader: session.socialMessageMediaReader, expanded: session.imExpandedNavigation).id(session.messagingViewIdentity)
            }
        }
        .cyDomainScreen(.player)
    }
    @ViewBuilder private var enterButton: some View {
        if model.phase == .unknown {
            CYPillButton("club.chat.retry", systemImage: "arrow.clockwise") { enter() }
        } else {
            CYPillButton("club.chat.enter", systemImage: "bubble.left.and.bubble.right") { enter() }
        }
    }
    private func enter() {
        Task { await model.owner.enter(); if case .ready(let row) = model.owner.visiblePhase { conversation = row } }
    }
    @ViewBuilder private var phaseStatus: some View {
        switch model.phase {
        case .entering:
            CYSkeleton().accessibilityLabel(Text("club.chat.loading"))
        case .unknown:
            Text("club.chat.unknown")
                .font(CYTypography.body)
                .foregroundStyle(palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("club.chat.unknown")
        case .rejected:
            Text("club.chat.rejected")
                .font(CYTypography.body)
                .foregroundStyle(palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        case .stale:
            Text("poll.stale")
                .font(CYTypography.body)
                .foregroundStyle(palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        default:
            EmptyView()
        }
    }
}

/// One title, no enter action: chat is not available for this session.
@MainActor private struct ClubChatUnavailableView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CYSpacing.lg) {
                CYHeroHeader("club.chat.title", subtitle: "club.chat.disabled")
            }
            .padding(.horizontal, CYSpacing.pageHorizontal)
            .padding(.vertical, CYSpacing.lg)
        }
        .cyDomainPageBackground()
        .cyDomainScreen(.player)
    }
}
