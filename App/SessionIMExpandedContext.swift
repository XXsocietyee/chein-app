import SwiftUI

/// Passed only by the normal session host. No closure starts a request by construction.
@MainActor struct IMExpandedNavigationContext {
    let coordinator: (Int) -> IMExpandedCoordinator?
    let uploadCoordinator: (Int) -> IMImageUploadCoordinator?
    let starter: () -> IMConversationStarter?
    let topicReader: any TopicReading
    var attachmentPreview: ((MessagingMessage) -> NativeChannelAttachmentPreviewFlow?)? = nil
    var videoCoordinator: ((Int) -> IMVideoCoordinator?)? = nil
    var fileCoordinator: ((Int) -> IMFileCoordinator?)? = nil
    var voiceCoordinator: ((Int) -> IMVoiceCoordinator?)? = nil
    var pollCoordinator: ((Int, GroupPollReference?) -> GroupPollCoordinator?)? = nil
    var chainCoordinator: ((Int, NativeChannelChainReference?) -> NativeChannelChainFlow?)? = nil
    var checkinCoordinator: ((Int) -> NativeChannelCheckinFlow?)? = nil
    var channelGovernanceDestination: ((NativeChannelGovernanceNotice) -> AnyView?)? = nil
    var safetyCoordinator: ((Int) -> IMSafetyCoordinator?)? = nil
    var channelReadCoordinator: ((Int) -> NativeChannelNotificationCoordinator?)? = nil
    /// mp-nav r3: MP pages a system card opens with navigateTo (page path, `id`), pushed above the chat.
    var pageDestination: ((String, Int) -> AnyView?)? = nil
}
extension AppSession {
    var imExpandedNavigation: IMExpandedNavigationContext {
        .init(coordinator: { [weak self] in self?.imExpandedCoordinator(for: $0) },
              uploadCoordinator: { [weak self] in self?.imImageUploadCoordinator(for: $0) },
              starter: { [weak self] in self?.imConversationStarter() }, topicReader: topicReader,
              pollCoordinator: { [weak self] in self?.groupPollCoordinator(conversationID: $0, reference: $1) },
              channelGovernanceDestination: { [weak self] notice in
                  guard let flow = self?.makeNativeChannelAppealFlow(notice: notice) else { return nil }
                  return AnyView(NativeChannelAppealEntry(flow: flow))
              },
              safetyCoordinator: { [weak self] in self?.imSafetyCoordinator(for: $0) },
              pageDestination: { [weak self] page, id in
                  guard let self else { return nil }
                  return AnyView(MPReviewedPageScreen(page: page, query: ["id": String(id)]).environmentObject(self))
              })
    }
}

// The existing page ports continue to use the original command and journals.
typealias ChannelPageActions = NativeChannelMessagePageActions<NativeChannelTextCoordinator, NativeChannelMessageCoordinator, NativeChannelTextJournal, NativeChannelMessageMutationJournal>
