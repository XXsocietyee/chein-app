import SwiftUI
import UIKit

/// Injects `IslandCenter` at the app root and installs the island's pass-through window on the root's scene.
/// The island lives in its own window so it is drawn above sheets, full-screen covers and alerts, the way the
/// system banner is. Off (flag) the modifier only provides the environment value.
struct IslandRootModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .environment(IslandCenter.shared)
            .background {
                if IslandCenter.isEnabled {
                    IslandWindowInstaller()
                        .frame(width: 0, height: 0)
                        .accessibilityHidden(true)
                }
            }
    }
}

extension View {
    /// App root only (`QuestifyApp`).
    func islandRoot() -> some View { modifier(IslandRootModifier()) }
}

/// Finds the root view's window scene once it is on screen and gives that scene one island window.
private struct IslandWindowInstaller: UIViewRepresentable {
    func makeUIView(context: Context) -> IslandSceneProbe { IslandSceneProbe() }
    func updateUIView(_ uiView: IslandSceneProbe, context: Context) {}
}

final class IslandSceneProbe: UIView {
    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard let scene = window?.windowScene else { return }
        IslandWindowRegistry.install(on: scene)
    }
}

@MainActor enum IslandWindowRegistry {
    private static var windows: [ObjectIdentifier: IslandPassthroughWindow] = [:]

    static func install(on scene: UIWindowScene) {
        let key = ObjectIdentifier(scene)
        guard windows[key] == nil else { return }
        windows = windows.filter { $0.value.windowScene != nil }
        let window = IslandPassthroughWindow(windowScene: scene)
        let host = UIHostingController(rootView: IslandWindowRoot())
        host.view.backgroundColor = .clear
        window.rootViewController = host
        window.backgroundColor = .clear
        // Above the app's windows and its sheets; below the system status bar is not needed because the island
        // only takes touches inside its own frame.
        window.windowLevel = UIWindow.Level(rawValue: UIWindow.Level.alert.rawValue + 1)
        window.isHidden = false
        windows[key] = window
    }
}

/// Touches outside the island fall through to the app window below.
final class IslandPassthroughWindow: UIWindow {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let frame = IslandCenter.shared.interactiveFrame
        guard IslandCenter.shared.current != nil, !frame.isEmpty, frame.insetBy(dx: -4, dy: -4).contains(point) else { return nil }
        return super.hitTest(point, with: event)
    }
}

/// The island window's SwiftUI root: same language and tint as the app root.
private struct IslandWindowRoot: View {
    @AppStorage(AppLanguage.storageKey) private var storedLanguage = RegionalLaunchConfiguration.language(nil).rawValue
    var body: some View {
        IslandOverlay(center: IslandCenter.shared)
            .modifier(AppLanguageEnvironment(stored: storedLanguage))
            .tint(CYColor.brand)
    }
}
