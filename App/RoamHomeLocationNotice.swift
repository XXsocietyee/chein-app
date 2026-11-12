import SwiftUI

/// Mini-program roam home `intro-permission` (B03): 需要定位才能开始漫游 / 定位没打开，漫游看不到你在哪 / 去设置,
/// above the 开始漫游 cards. It reads the static OS status only (no prompt, no manager, no GPS) and appears only when
/// location is denied, restricted or switched off. An undecided or unread status shows nothing.
@MainActor struct RoamHomeLocationNotice: View {
    @StateObject private var model: RoamLocationSettingsModel
    @Environment(\.scenePhase) private var scenePhase
    init(provider: any RoamLocationSettingsProviding) {
        _model = StateObject(wrappedValue: RoamLocationSettingsModel(provider: provider))
    }
    static func blocksRoaming(_ snapshot: RoamLocationSettingsSnapshot) -> Bool {
        !snapshot.servicesEnabled || snapshot.authorization == .denied || snapshot.authorization == .restricted
    }
    private var blocked: Bool {
        if case .loaded(let snapshot) = model.state.phase { return Self.blocksRoaming(snapshot) }
        return false
    }
    var body: some View {
        ZStack {
            Color.clear.frame(width: 0, height: 0).accessibilityHidden(true)
            if blocked {
                CYEmptyState(systemImage: "lock", "u10.roam.permission.title",
                             detail: "u10.roam.permission.sub",
                             messageIdentifier: "roam.home.permission",
                             actionTitle: "u10.roam.permission.settings",
                             actionIdentifier: "roam.home.permission.settings",
                             actionStyle: .primary,
                             kind: .location) {
                    guard !model.state.isOpeningSettings else { return }
                    model.openSettings()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .onAppear { if scenePhase == .active { model.activate() } }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { model.activate() } else { model.suspend() }
        }
        .onDisappear { model.suspend() }
    }
}
