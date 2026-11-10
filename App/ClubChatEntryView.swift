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
            if let owner = session.clubChatCoordinator(clubID: clubID) { ClubChatEntryView(owner: owner, session: session) }
            else { CYEmptyState(systemImage: "person.3", "club.chat.title", detail: "club.chat.disabled") }
        }.cyHeroScreen()
    }
}
@MainActor private struct ClubChatEntryView: View {
    @StateObject private var model: ClubChatViewModel
    @ObservedObject var session: AppSession
    @State private var conversation: MessagingConversation?
    init(owner: ClubChatCoordinator, session: AppSession) { _model = StateObject(wrappedValue: ClubChatViewModel(owner)); self.session = session }
    var body: some View {
        Form {
            Section {
                CYHeroHeader("club.chat.title", subtitle: "club.chat.explanation")
                    .listRowBackground(Color.clear)
                if !model.owner.service.isConfigured {
                    CYStatusChip("club.chat.disabled", tone: .neutral, systemImage: "bubble.left.and.exclamationmark.bubble.right")
                        .accessibilityIdentifier("club.chat.disabled")
                }
                CYPillButton(model.phase == .unknown ? "club.chat.retry" : "club.chat.enter", systemImage: "bubble.left.and.bubble.right") {
                    Task { await model.owner.enter(); if case .ready(let row) = model.owner.visiblePhase { conversation = row } }
                }.disabled(!model.owner.canEnter).accessibilityIdentifier("club.chat.enter")
            }
            Section {
                switch model.phase {
                case .entering: ProgressView("club.chat.loading")
                case .unknown:
                    CYStatusChip("club.chat.unknown", tone: .warning, systemImage: "questionmark.circle").accessibilityIdentifier("club.chat.unknown")
                case .rejected: CYStatusChip("club.chat.rejected", tone: .danger, systemImage: "xmark.circle")
                case .stale: CYStatusChip("poll.stale", tone: .neutral, systemImage: "clock.arrow.circlepath")
                default: EmptyView()
                }
            }
        }.privacySensitive().accessibilityIdentifier("club.chat.screen")
        .onAppear { model.observe() }
        .onDisappear { model.owner.suspend() }
        .onChange(of: model.owner.isCurrent) { _, current in if !current { conversation = nil } }
        .navigationDestination(isPresented: Binding(get: { conversation != nil && model.owner.isCurrent }, set: { if !$0 { conversation = nil } })) {
            if let conversation, model.owner.isCurrent {
                MessagingHistoryView(conversationID: conversation.id, conversation: conversation, reader: session.messagingReader,
                    sender: session.messageSender(for: conversation.id), mediaReader: session.socialMessageMediaReader, expanded: session.imExpandedNavigation).id(session.messagingViewIdentity)
            }
        }
    }
}
