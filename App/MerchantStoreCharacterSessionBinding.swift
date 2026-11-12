import SwiftUI

extension AppSession {
    /// Production AI 店铺角色 destination. Profile reads stay on the operations reader.
    /// The knowledge author flow is attached for this merchant scope. Its publish path stays waiting-source.
    func merchantStoreCharacterDestination(access: MerchantOperationsAccess) -> AnyView {
        AnyView(SessionMerchantStoreCharacterView(reader: merchantOperationsReader, authorFlow: characterKnowledgeAuthorFlow(access: access)))
    }
}

@MainActor struct SessionMerchantStoreCharacterView: View {
    let reader: any MerchantOperationsReading
    var authorFlow: MerchantNPCKnowledgeAuthorFlow? = nil
    var body: some View {
        MerchantStoreCharacterView(coordinator: StoreCharacterCoordinator(reader: StoreCharacterOperationsReader(reader: reader)), authorFlow: authorFlow)
            .id(reader.scope)
    }
}
