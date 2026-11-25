import SwiftUI

extension AppSession {
    /// Production AI 店铺角色 destination. Profile reads stay on the operations reader.
    /// The knowledge author flow is attached for this merchant scope. Its publish path stays waiting-source.
    func merchantStoreCharacterDestination(access: MerchantOperationsAccess) -> AnyView {
        AnyView(SessionMerchantStoreCharacterView(reader: merchantOperationsReader, authorFlow: characterKnowledgeAuthorFlow(access: access),
                                                  writer: makeStoreCharacterWriter()))
    }
    /// MC8-23-1 (MP-first, owner 2026-11-25): npc/save, decor/save and voice/enroll go out as the MP sends them
    /// (pages/merchant/decor/ai-npc/index.js:533,744,942); `MerchantCityNPCParityGates.mpFirst` admits them.
    func makeStoreCharacterWriter() -> StoreCharacterServiceBackend? {
        guard let api = regionalConfiguration?.apiConfiguration, let market = regionalConfiguration?.market else { return nil }
        let reader = merchantOperationsReader
        return StoreCharacterServiceBackend(service: .init(configuration: api, transport: runtimeHTTPTransport), market: market,
                                            gates: .mpFirst, token: { [weak self] in self?.token }, currentScope: { reader.scope })
    }
}

@MainActor struct SessionMerchantStoreCharacterView: View {
    let reader: any MerchantOperationsReading
    var authorFlow: MerchantNPCKnowledgeAuthorFlow? = nil
    var writer: StoreCharacterServiceBackend? = nil
    var body: some View {
        MerchantStoreCharacterView(coordinator: StoreCharacterCoordinator(reader: StoreCharacterOperationsReader(reader: reader), writer: writer,
                                                                          gates: writer == nil ? .disabled : .mpFirst), authorFlow: authorFlow)
            .id(reader.scope)
    }
}
