import SwiftUI
import CoreMotion
import Observation

/// One shared device-tilt source for foil, parallax and gyro-driven light. CMMotionManager at 30 Hz, only while at
/// least one consumer holds it (`acquire` / `release`), never under Reduce Motion or Low Power (callers check).
/// The simulator has no gyro: DEBUG `--uitesting-fake-tilt` sweeps roll -0.5 to 0.5 over 3 s and back, forever.
@MainActor @Observable
final class CYTilt {
    static let shared = CYTilt()

    /// Radians, like CMAttitude. Both stay 0 until a source delivers.
    private(set) var pitch = 0.0
    private(set) var roll = 0.0

    @ObservationIgnored private let manager = CMMotionManager()
    @ObservationIgnored private var holders = 0
    @ObservationIgnored private var fakeTimer: Timer?
    @ObservationIgnored private var fakeStart = Date()

    static var isFakeTilt: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("--uitesting-fake-tilt")
        #else
        return false
        #endif
    }

    /// Whether a source can deliver at all (real gyro or the DEBUG sweep). Foil uses this to pick static vs live.
    var isLive: Bool { Self.isFakeTilt || manager.isDeviceMotionAvailable }

    func acquire() {
        holders += 1
        if holders == 1 { start() }
    }

    func release() {
        holders = max(0, holders - 1)
        if holders == 0 { stop() }
    }

    private func start() {
        guard CYLightBudget.gyroAllowed else { return }
        if Self.isFakeTilt { startFake(); return }
        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 30.0
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let attitude = motion?.attitude else { return }
            let pitch = attitude.pitch, roll = attitude.roll
            MainActor.assumeIsolated {
                withAnimation(.interactiveSpring) { self?.pitch = pitch; self?.roll = roll }
            }
        }
    }

    private func stop() {
        manager.stopDeviceMotionUpdates()
        fakeTimer?.invalidate(); fakeTimer = nil
    }

    private func startFake() {
        guard fakeTimer == nil else { return }
        fakeStart = Date()
        fakeTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                let t = Date().timeIntervalSince(self.fakeStart)
                // Triangle wave: -0.5 -> 0.5 in 3 s, then back, so a recording never snaps.
                let phase = (t / 3.0).truncatingRemainder(dividingBy: 2)
                self.roll = (phase < 1 ? phase : 2 - phase) - 0.5
                self.pitch = 0.12 * sin(t * 1.3)
            }
        }
    }
}

/// Holds `CYTilt` for the lifetime of the view when `enabled`.
private struct CYTiltHold: ViewModifier {
    let enabled: Bool
    @State private var held = false
    func body(content: Content) -> some View {
        content
            .onAppear { update() }
            .onDisappear { drop() }
            .onChange(of: enabled) { _, _ in update() }
    }
    private func update() { enabled ? take() : drop() }
    private func take() { guard !held else { return }; held = true; CYTilt.shared.acquire() }
    private func drop() { guard held else { return }; held = false; CYTilt.shared.release() }
}

extension View {
    /// Keeps the shared tilt source running while this view is on screen and `enabled`.
    func cyTiltHold(_ enabled: Bool = true) -> some View { modifier(CYTiltHold(enabled: enabled)) }
}
