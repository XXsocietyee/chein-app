#if DEBUG
import SwiftUI

/// D7 design fixtures (synthetic data, debug only): publish tab sheet, publish menu, template browser and detail.
/// All reuse the real views with the existing offline fixture readers; themed as the player domain (dark).
enum PublishDesignFixtures {
    @MainActor static func make(_ name: String) -> AnyView? {
        switch name {
        case "publish-sheet": return wrap(sheet(#"{"role":"club","quota":{"themesRemaining":3}}"#))
        case "publish-sheet-locked": return wrap(sheet(nil))
        case "publish-sheet-quota": return wrap(sheet(#"{"role":"player","quota":{"themesRemaining":0}}"#))
        case "publish-menu": return wrap(PublishingModesFixtureHost())
        case "publish-menu-pro":
            return wrap(NavigationStack {
                PublishingModesView(service: nil, account: nil, placeSearch: nil, openProfessional: { _ in }, openResource: { _ in },
                                    makeProfessional: { _ in AnyView(EmptyView()) }, makeTemplateAuthoring: { AnyView(EmptyView()) })
            })
        case "publish-projects":
            return wrap(NavigationStack { PublishingProjectsView(service: nil, account: nil, openResource: { _ in }) })
        case "template-topics": return wrap(NavigationStack { DiscoveryTemplateBrowserView(reader: DiscoveryFixtureReader()) })
        case "template-games": return wrap(NavigationStack { DiscoveryTemplateBrowserView(reader: DiscoveryFixtureReader(), startOnGames: true) })
        case "template-detail":
            return wrap(NavigationStack { DiscoveryTemplateDetailView(id: 7, reader: TemplateDetailParityFixtureReader(scenario: "public")) })
        default: return nil
        }
    }

    @MainActor private static func sheet(_ capabilityJSON: String?) -> some View {
        let capability = capabilityJSON.flatMap { try? JSONDecoder().decode([String: ProjectEditJSON].self, from: Data($0.utf8)) }.map(PublishingCapability.init)
        return PublishTabFloatingSheetView(presentation: PublishTabFloatingSheetParity.presentation(capability: capability), onSelectAction: { _ in })
    }

    @MainActor private static func wrap<V: View>(_ view: V) -> AnyView {
        AnyView(view.themeDomain(.player).cyDomainPageBackground().themeDomain(.player))
    }
}
#endif
