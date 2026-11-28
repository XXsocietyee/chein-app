import Foundation

// fix/1128c-ai-npc-guide: the player AI features the planning audit found dormant in Release, switched on in the
// reviewed China composition. Kept out of AppSession.swift / AppCompositionRoot.swift (line-ratcheted).
// The backend still decides: `feature.flag.shopNpcChat` (shop NPC text + voice) and its ASR provider. When a flag
// is off the app sends, and renders the server's own refusal message (ShopNPCFailure.server).

extension ReviewedProductionGateLeases {
    /// In-store NPC chat (MP pages/play/index.js:2328,2368; BE ApiAiNpcController.java:266,338), the puzzle hint
    /// ladder and hint unlock (MP pages/play/index.js:7189,7256; plan audit J-09a / J-10b), and the NPC chat data
    /// delete (MP subpackageMember/components/cy/npc-chat/index.js:232-237; BE :507). All non-money player writes.
    nonisolated static let aiNPCPlayPaths: Set<String> = [
        "api/ai/npc/shop-chat", "api/ai/npc/voice-chat",
        "api/play/puzzle/hint", "api/play/hint/unlock",
        "api/ai/npc/chat/data/delete"
    ]

    /// The Release shop NPC grants. Text and voice transmission are on; reply audio playback stays off because the
    /// backend `audioUrl` belongs to the deferred merchant voice clone (P2). Read-aloud is on-device TTS instead.
    nonisolated static func releaseShopNPCGrants() -> ShopNPCGrants {
        var grants = ShopNPCGrants()
        grants.server = true
        grants.provider = true
        grants.legal = true
        grants.access = true
        grants.voiceTransmission = true
        grants.voiceFormatVerified = true
        grants.microphone = true
        return grants
    }

    /// Exact endpoint approval for `POST api/ai/npc/chat/data/delete` on this account. Nil outside China.
    nonisolated static func npcChatLogDeletionApproval(_ context: RuntimeDependencyContext) -> OperationEndpointApproval? {
        guard context.market == .china, context.session.accountID > 0 else { return nil }
        return try? OperationEndpointApproval(baseURL: context.baseURL, namespace: context.session.namespace,
                                              accountID: context.session.accountID, paths: [NPCChatLogDeletion.path])
    }
}

extension AppCompositionRoot {
    /// True when the shipped China composition has the reviewed player grant on (the same switch every other
    /// player write in Release rides on).
    func releaseAINPCEnabled(_ context: RuntimeDependencyContext) -> Bool {
        reviewed?.playerWritesEnabled == true && reviewed?.regional.market == .china && context.market == .china
            && (context.role == "player" || context.role == "club")
    }
}

extension AppSession {
    /// 「AI 对话记录」 (MP pages/shezhi/shezhi.wxml:24): issue the owner's read lease for their own stored NPC chat text.
    /// The data right is never behind a chat flag (BE ApiAiNpcController.java:484-495).
    func ensureReleaseNPCChatDataApproval() {
        guard let context = currentRuntimeDependencyContext, composition.releaseAINPCEnabled(context),
              composition.npcChatDataReadSelection.approval(for: context) == nil,
              let approval = try? NPCChatDataReadApproval(context: context, expiresAt: Date().addingTimeInterval(3600)) else { return }
        try? composition.npcChatDataReadSelection.replace(with: approval)
    }

    /// The log deletion service bound to the reader's own session; nil when the Release grant is off.
    func releaseNPCChatLogDeletion(for reader: NPCChatDataReader) -> NPCChatLogDeletionService? {
        let context = reader.approval.context
        guard composition.releaseAINPCEnabled(context),
              let approval = ReviewedProductionGateLeases.npcChatLogDeletionApproval(context),
              let configuration = try? APIConfiguration(baseURL: context.baseURL) else { return nil }
        let token = context.session.token
        return NPCChatLogDeletionService(configuration: configuration, transport: composition.makeTransport(),
            current: { [weak reader] in
                guard let reader, reader.isCurrent else { return nil }
                return reader.session
            },
            token: { token },
            approval: { approval })
    }
}
