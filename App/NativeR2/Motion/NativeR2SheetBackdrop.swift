import SwiftUI
import Observation

/// The presented sheet's height, written by the sheet (`nativeR2SheetBackdropSource`) and read by
/// the screen behind it (`nativeR2SheetBackdrop`). Sheets inherit the presenter's environment.
@MainActor @Observable final class NativeR2BackdropTracker {
    var sheetHeight: CGFloat = 0
}

private struct NativeR2BackdropTrackerKey: EnvironmentKey {
    static let defaultValue: NativeR2BackdropTracker? = nil
}

extension EnvironmentValues {
    var nativeR2BackdropTracker: NativeR2BackdropTracker? {
        get { self[NativeR2BackdropTrackerKey.self] }
        set { self[NativeR2BackdropTrackerKey.self] = newValue }
    }
}

/// M2 backdrop for our own overlay sheets (punch, game result, story stage result): the screen
/// behind gets a blur that grows from 2 to 16 pt as the sheet rises, under a top-to-bottom wash
/// (light: white 0.92 → 0.15, dark: black 0.6 → 0.1). Reduce Motion keeps the wash and drops the blur.
/// Every other sheet keeps Apple's default dimming. Shared with the sheets lane: reuse, don't fork.
@MainActor struct NativeR2SheetBackdrop: ViewModifier {
    let isPresented: Bool
    @State private var tracker = NativeR2BackdropTracker()
    @State private var hostHeight: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    private var active: Bool { NativeR2Flags.motion && isPresented }
    /// Detent fraction: the sheet's height over the screen's. Half until the sheet reports.
    private var fraction: CGFloat {
        guard hostHeight > 0, tracker.sheetHeight > 0 else { return 0.5 }
        return min(1, max(0, tracker.sheetHeight / hostHeight))
    }
    private var blurRadius: CGFloat {
        guard active, !reduceMotion else { return 0 }
        return 2 + 14 * fraction
    }

    func body(content: Content) -> some View {
        content
            .blur(radius: blurRadius)
            .overlay {
                if active {
                    wash
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                        .transition(.opacity)
                }
            }
            .animation(reduceMotion ? nil : .smooth(duration: 0.35), value: active)
            .animation(reduceMotion ? nil : .smooth, value: fraction)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { hostHeight = $0 }
            .onChange(of: isPresented) { _, shown in if !shown { tracker.sheetHeight = 0 } }
            .environment(\.nativeR2BackdropTracker, tracker)
    }

    private var wash: LinearGradient {
        let dark = colorScheme == .dark
        let base: Color = dark ? .black : .white
        return LinearGradient(colors: [base.opacity(dark ? 0.6 : 0.92), base.opacity(dark ? 0.1 : 0.15)],
                              startPoint: .top, endPoint: .bottom)
    }
}

/// Put on the sheet's root view: reports the detent height to the backdrop behind it.
@MainActor struct NativeR2SheetBackdropSource: ViewModifier {
    @Environment(\.nativeR2BackdropTracker) private var tracker

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
                tracker?.sheetHeight = height
            }
    }
}

extension View {
    /// Apply after the `.sheet` it belongs to, so the sheet inherits the tracker.
    func nativeR2SheetBackdrop(isPresented: Bool) -> some View { modifier(NativeR2SheetBackdrop(isPresented: isPresented)) }
    func nativeR2SheetBackdropSource() -> some View { modifier(NativeR2SheetBackdropSource()) }
}
