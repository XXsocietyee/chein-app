import SwiftUI

// OWNER RULE 3 (11-28) celebration feedback, owner mp-roam (stamp collected): one warm burst over the stamp the moment
// it is collected (city-stamp slip revealed, created stamp read back). CYBurst draws nothing under Reduce Motion,
// Low Power or thermal pressure (CYLightBudget), never takes touches and is hidden from VoiceOver; the caller keeps
// its own success haptic, so this adds light only.

struct RoamStampRevealCelebration: ViewModifier {
    let collected: Bool

    func body(content: Content) -> some View {
        content.overlay {
            if collected {
                CYBurst(origin: .center, count: 42, duration: 1.2, style: .dust, reach: 140)
            }
        }
    }
}

extension View {
    /// Burst once when `collected` turns true (it never turns back on the stamp screens).
    func roamStampCollectedBurst(_ collected: Bool) -> some View {
        modifier(RoamStampRevealCelebration(collected: collected))
    }
}
