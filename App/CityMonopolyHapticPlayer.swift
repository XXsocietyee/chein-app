import SwiftUI

/// Plays City Monopoly feedback moments (spec §5) through the one haptics map, `CYHaptics`.
/// The system haptics switch is honoured by the generators themselves. Under Reduce Motion only
/// the closing cue plays, so a sequence never becomes a long buzz train.
@MainActor enum CityMonopolyHapticPlayer {
    static func haptic(for cue: CityMonopolyHapticCue) -> CYHaptics {
        switch cue {
        case .selection: return .selection
        case .success: return .success
        case .warning: return .warning
        case .error: return .error
        case .impactLight: return .impactLight
        case .impactMedium: return .impactMedium
        case .impactHeavy: return .impactHeavy
        case .impactRigid: return .impactRigid
        }
    }

    static func play(_ event: CityMonopolyHapticEvent, reduceMotion: Bool) {
        let steps = event.steps
        guard let last = steps.last else { return }
        if reduceMotion {
            haptic(for: last.cue).play()
            return
        }
        Task { @MainActor in
            for step in steps {
                if step.delayMs > 0 {
                    try? await Task.sleep(nanoseconds: UInt64(step.delayMs) * 1_000_000)
                }
                haptic(for: step.cue).play()
            }
        }
    }
}

extension View {
    /// Plays each new City Monopoly haptic ticket once.
    func cityMonopolyHaptics(_ ticket: CityMonopolyHapticTicket?, reduceMotion: Bool) -> some View {
        onChange(of: ticket) { _, newValue in
            guard let newValue else { return }
            CityMonopolyHapticPlayer.play(newValue.event, reduceMotion: reduceMotion)
        }
    }
}
