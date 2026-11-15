import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Live UIKit feedback driver backed by `UIImpactFeedbackGenerator`,
/// `UINotificationFeedbackGenerator`, and `UISelectionFeedbackGenerator`.
/// UIKit feedback generators natively obey iOS Settings -> Sounds & Haptics -> System Haptics.
@MainActor final class UIKitHapticsDriver: HapticsFeedbackDriver {
    static let shared = UIKitHapticsDriver()

    #if canImport(UIKit)
    private lazy var selectionGenerator = UISelectionFeedbackGenerator()
    private lazy var notificationGenerator = UINotificationFeedbackGenerator()
    private lazy var lightImpactGenerator = UIImpactFeedbackGenerator(style: .light)
    private lazy var mediumImpactGenerator = UIImpactFeedbackGenerator(style: .medium)
    private lazy var heavyImpactGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private lazy var softImpactGenerator = UIImpactFeedbackGenerator(style: .soft)
    private lazy var rigidImpactGenerator = UIImpactFeedbackGenerator(style: .rigid)
    #endif

    func prepare(_ style: HapticFeedbackStyle) {
        #if canImport(UIKit)
        switch style {
        case .selection:
            selectionGenerator.prepare()
        case .impactLight:
            lightImpactGenerator.prepare()
        case .impactMedium:
            mediumImpactGenerator.prepare()
        case .impactHeavy:
            heavyImpactGenerator.prepare()
        case .impactSoft:
            softImpactGenerator.prepare()
        case .impactRigid:
            rigidImpactGenerator.prepare()
        case .notificationSuccess, .notificationWarning, .notificationError:
            notificationGenerator.prepare()
        }
        #endif
    }

    func trigger(_ style: HapticFeedbackStyle) {
        #if canImport(UIKit)
        switch style {
        case .selection:
            selectionGenerator.selectionChanged()
            selectionGenerator.prepare()
        case .impactLight:
            lightImpactGenerator.impactOccurred()
            lightImpactGenerator.prepare()
        case .impactMedium:
            mediumImpactGenerator.impactOccurred()
            mediumImpactGenerator.prepare()
        case .impactHeavy:
            heavyImpactGenerator.impactOccurred()
            heavyImpactGenerator.prepare()
        case .impactSoft:
            softImpactGenerator.impactOccurred()
            softImpactGenerator.prepare()
        case .impactRigid:
            rigidImpactGenerator.impactOccurred()
            rigidImpactGenerator.prepare()
        case .notificationSuccess:
            notificationGenerator.notificationOccurred(.success)
            notificationGenerator.prepare()
        case .notificationWarning:
            notificationGenerator.notificationOccurred(.warning)
            notificationGenerator.prepare()
        case .notificationError:
            notificationGenerator.notificationOccurred(.error)
            notificationGenerator.prepare()
        }
        #endif
    }

    /// Lazily installs the UIKit driver onto `HapticsService.shared` on iOS app runtime.
    private static var didInstall = false
    static func ensureInstalled() {
        guard !didInstall else { return }
        didInstall = true
        HapticsService.shared.install(driver: shared)
    }
}

extension View {
    /// Declarative haptic via `HapticsService`, honoring system settings, in-app toggle, and 120 ms cooldown.
    func cyHapticEvent<T: Equatable>(_ event: HapticEvent, trigger: T) -> some View {
        onChange(of: trigger) { _, _ in
            UIKitHapticsDriver.ensureInstalled()
            HapticsService.shared.play(event)
        }
    }

    /// Declarative conditional haptic via `HapticsService`.
    func cyHapticEvent<T: Equatable>(
        _ event: HapticEvent,
        trigger: T,
        where condition: @escaping (T, T) -> Bool
    ) -> some View {
        onChange(of: trigger) { oldValue, newValue in
            guard condition(oldValue, newValue) else { return }
            UIKitHapticsDriver.ensureInstalled()
            HapticsService.shared.play(event)
        }
    }
}
