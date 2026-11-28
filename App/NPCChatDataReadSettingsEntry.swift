import SwiftUI

struct NPCChatDataReadPresentation: Identifiable {
    let id = UUID()
    let identity: AppSession.NPCChatDataReadIdentity
    let coordinator: NPCChatDataCoordinator
    /// Optional: supplied by a host holding the approval; nil leaves the reader unchanged.
    var consent: NPCChatDataConsentProbe?
}
/// A persistent entry even with no lease; the disabled reader explains unavailability without requiring a write journal.
@MainActor struct NPCChatDataReadSettingsEntry: View {
    @ObservedObject var session: AppSession
    var consentProbe: (() -> NPCChatDataConsentProbe?)?
    @Environment(\.scenePhase) private var scene
    @Environment(\.locale) private var locale
    @Environment(\.memberPopupActions) private var popupActions
    @State private var presentation: NPCChatDataReadPresentation?
    @State private var showsOptions = false
    @State private var confirmsClear = false
    @State private var pendingIdentity: AppSession.NPCChatDataReadIdentity?
    @State private var toastMessage: LocalizedStringKey?
    @State private var toastTone: CYToastTone = .info

    var body: some View {
        let renderedIdentity = session.npcChatDataReadIdentity
        SettingsEntrySection {
            // Mini-program settings row 「AI 对话记录」 (OFF-AI-DEL-01): option sheet -> view, export (copy) and delete.
            Button {
                guard scene == .active, session.npcChatDataReadIdentity == renderedIdentity else { return }
                pendingIdentity = renderedIdentity
                showsOptions = true
            } label: {
                // MP shezhi AI 对话记录 = icon_lc_message-square-text.
                Label { Text("mpd.aiChat.title") } icon: { AccountPublishMPGlyph(MPAsset.FeatureIcon.iconLcMessageSquareText) }
            }
            .foregroundStyle(CYColor.textPrimary)
            .accessibilityIdentifier("npcData.open")
        }
        .cySheet(isPresented: $showsOptions) {
            MemberAIChatRecordsOptionSheet(onSelect: { option in
                showsOptions = false
                let targetIdentity = pendingIdentity ?? session.npcChatDataReadIdentity
                switch option {
                case .view:
                    guard scene == .active, session.npcChatDataReadIdentity == targetIdentity else { return }
                    retire()
                    presentation = .init(identity: targetIdentity, coordinator: session.makeNPCChatDataReadCoordinator(), consent: consentProbe?())
                case .export:
                    Task {
                        if let text = await popupActions.exportNPCChatTranscript?(), !text.isEmpty {
                            LocalPasteboard.copy(text)
                            toastTone = .success
                            toastMessage = LocalizedStringKey(MemberPopupCopy.text(
                                "对话记录已复制",
                                "Chat records copied",
                                locale: locale))
                        } else {
                            toastTone = .info
                            // MP ai-chat-records exportRecords: empty export toasts 还没有对话记录.
                            toastMessage = LocalizedStringKey(MemberPopupCopy.text(
                                "还没有对话记录",
                                "No chat records yet",
                                locale: locale))
                        }
                    }
                case .clear:
                    confirmsClear = true
                }
            }, onClose: {
                showsOptions = false
            })
            .cyDomainSheet(detents: [.peek, .half])
        }
        .cySheet(isPresented: $confirmsClear) {
            MemberNPCLogDeleteConfirmSheet {
                confirmsClear = false
                Task {
                    switch await popupActions.clearNPCChatLogs?() {
                    case .deleted:
                        toastTone = .success
                        toastMessage = LocalizedStringKey(MemberPopupCopy.text(
                            "已清除对话记录",
                            "Chat records cleared",
                            locale: locale))
                    case .unknown:
                        toastTone = .warning
                        toastMessage = LocalizedStringKey(MemberPopupCopy.text(
                            "清除结果待确认，请打开记录查看",
                            "Clear outcome unknown; open records to verify",
                            locale: locale))
                    case nil:
                        toastTone = .info
                        toastMessage = LocalizedStringKey(MemberPopupCopy.text(
                            "请在对话记录详情页发起删除",
                            "Open chat records to review and clear logs",
                            locale: locale))
                    }
                }
            }
            .cyDomainSheet(detents: [.half])
        }
        .cySheet(item: $presentation) { NPCChatDataReadVisit(presentation: $0, session: session) }
        .cyToast(message: $toastMessage, tone: toastTone)
        .onChange(of: session.npcChatDataReadIdentity) { _, _ in retire() }
        .onDisappear { retire() }
    }
    private func retire() { showsOptions = false; confirmsClear = false; presentation?.coordinator.invalidate(); presentation = nil }
}
/// The visible sheet independently observes identity; its hidden Settings parent is not the privacy fence.
@MainActor struct NPCChatDataReadVisit: View {
    let presentation: NPCChatDataReadPresentation
    @ObservedObject var session: AppSession
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        Group {
            if session.npcChatDataReadIdentity == presentation.identity {
                NPCChatDataView(coordinator: presentation.coordinator, consent: presentation.consent)
            } else {
                NavigationStack {
                    Text("npcData.contentCleared")
                        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("action.done") { dismiss() } } }
                }
            }
        }
        .privacySensitive()
        .onChange(of: session.npcChatDataReadIdentity) { _, _ in presentation.coordinator.invalidate() }
        .onDisappear { presentation.coordinator.invalidate() }
    }
}
