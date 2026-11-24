import SwiftUI

/// C-F6 (MP pages/publish/fabu/theme-fe-visit): mounts the per-place 「到访方式」 editor in the topic editor
/// for a saved free-explore topic. The factory is installed once at the app root; fixtures and previews get
/// nil and show nothing. Reads and writes stay behind `PlayRuntimePortRouteGate` (both default off).
private struct FreeExplorationVisitConfigFactoryKey: EnvironmentKey {
    static let defaultValue: ((_ topicID: Int, _ authorWrites: Bool) -> FreeExplorationVisitConfigModel?)? = nil
}

extension EnvironmentValues {
    var freeExplorationVisitConfig: ((_ topicID: Int, _ authorWrites: Bool) -> FreeExplorationVisitConfigModel?)? {
        get { self[FreeExplorationVisitConfigFactoryKey.self] }
        set { self[FreeExplorationVisitConfigFactoryKey.self] = newValue }
    }
}

extension AppSession {
    /// Nil while the read gate is off, signed out, or unconfigured. Writes need both the write gate and the
    /// editor's own author-write grant (`authorWrites`, derived from the approved project write authority).
    func freeExplorationVisitConfigModel(topicID: Int, authorWrites: Bool) -> FreeExplorationVisitConfigModel? {
        guard PlayRuntimePortRouteGate.freeExploreVisitConfigRead, topicID > 0, isConfigured, isSignedIn,
              let configuration = regionalConfiguration?.apiConfiguration else { return nil }
        let service = FreeExplorationVisitConfigService(
            configuration: configuration, transport: compositionTransport,
            authorWrites: PlayRuntimePortRouteGate.freeExploreVisitConfigWrite && authorWrites,
            readsEnabled: PlayRuntimePortRouteGate.freeExploreVisitConfigRead,
            token: { [weak self] in self?.token })
        return FreeExplorationVisitConfigModel(topicID: topicID, service: service)
    }
}

/// One disclosure row 到访方式 › in the topic editor. Absent when no factory or the gate gives no model.
@MainActor struct FreeExplorationVisitConfigEntrySection: View {
    let topicID: Int
    let authorWrites: Bool
    @Environment(\.freeExplorationVisitConfig) private var factory

    var body: some View {
        if let factory, let model = factory(topicID, authorWrites) {
            Section {
                NavigationLink {
                    FreeExplorationVisitConfigView(model: model)
                } label: {
                    Label("feVisitConfig.title", systemImage: "location.viewfinder")
                }
                .accessibilityIdentifier("projectEdit.feVisitConfig")
            }
        }
    }
}
