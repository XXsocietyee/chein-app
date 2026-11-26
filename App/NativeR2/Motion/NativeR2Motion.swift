import SwiftUI
import MapKit
import Observation

extension NativeR2Flags {
    /// Motion r1: route draw-on, rolling counters, the overlay sheet backdrop and symbol effects.
    /// `-nativeR2.motion NO` turns every one of them off and leaves the static screens.
    static var motion: Bool { isEnabled("nativeR2.motion") }
}

/// A 0…1 progress value that advances once per `run`. Map content is not interpolated by
/// `withAnimation`, so a route polyline reads this value and trims its coordinates frame by frame.
@MainActor @Observable final class NativeR2DrawOn {
    private(set) var progress: Double

    init() { progress = NativeR2Flags.motion ? 0 : 1 }

    /// Draws from 0 to 1 over `duration` with an ease-in-out curve. With the flag off or
    /// Reduce Motion on, the route appears at once.
    func run(duration: TimeInterval = 1.6, reduceMotion: Bool) async {
        guard NativeR2Flags.motion, !reduceMotion, duration > 0 else { progress = 1; return }
        progress = 0
        let start = Date()
        while !Task.isCancelled {
            let linear = min(1, Date().timeIntervalSince(start) / duration)
            progress = Self.ease(linear)
            if linear >= 1 { return }
            try? await Task.sleep(for: .milliseconds(16))
        }
        progress = 1
    }

    static func ease(_ t: Double) -> Double {
        t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
    }
}

/// Coordinate trimming for the draw-on, plus the per-team route tint.
enum NativeR2RoutePath {
    static func point(from a: CLLocationCoordinate2D, to b: CLLocationCoordinate2D, fraction: Double) -> CLLocationCoordinate2D {
        let f = min(1, max(0, fraction))
        return CLLocationCoordinate2D(latitude: a.latitude + (b.latitude - a.latitude) * f,
                                      longitude: a.longitude + (b.longitude - a.longitude) * f)
    }

    /// How much of leg `index` (of `count`) is drawn when the whole route is at `progress`.
    static func legFraction(index: Int, count: Int, progress: Double) -> Double {
        guard count > 0 else { return 1 }
        return min(1, max(0, progress * Double(count) - Double(index)))
    }

    /// The two ends of a leg, the second one moved back to the drawing head.
    static func leg(_ start: CLLocationCoordinate2D, _ end: CLLocationCoordinate2D,
                    index: Int, count: Int, progress: Double) -> [CLLocationCoordinate2D] {
        [start, point(from: start, to: end, fraction: legFraction(index: index, count: count, progress: progress))]
    }

    /// The prefix of a polyline at `progress`; the head is interpolated between two vertices.
    static func prefix(_ coordinates: [CLLocationCoordinate2D], progress: Double) -> [CLLocationCoordinate2D] {
        guard coordinates.count > 1, progress < 1 else { return coordinates }
        let legs = coordinates.count - 1
        let head = max(0, progress) * Double(legs)
        let whole = min(legs, Int(head))
        var drawn = Array(coordinates[0...whole])
        let rest = head - Double(whole)
        if whole < legs, rest > 0 {
            drawn.append(point(from: coordinates[whole], to: coordinates[whole + 1], fraction: rest))
        }
        if drawn.count == 1 { drawn.append(coordinates[0]) }
        return drawn
    }

    static func meters(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
        CLLocation(latitude: a.latitude, longitude: a.longitude).distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
    }

    /// System colours only; the server's `colorIndex` picks one so a team keeps its colour.
    static func teamColor(_ index: Int) -> Color {
        let palette: [Color] = [.blue, .orange, .green, .pink, .teal, .red, .mint, .brown]
        return palette[abs(index) % palette.count]
    }
}

/// `.contentTransition(.numericText())` plus the animation that makes the digits roll.
/// Reduce Motion or the flag off: the number is set instantly.
struct NativeR2RollingNumber: ViewModifier {
    let value: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @ViewBuilder func body(content: Content) -> some View {
        if NativeR2Flags.motion && !reduceMotion {
            content
                .contentTransition(.numericText(value: value))
                .animation(.smooth, value: value)
        } else {
            content
        }
    }
}

/// `.symbolEffect(.bounce)` on a successful punch, stamp or unlock.
struct NativeR2Bounce<Value: Equatable>: ViewModifier {
    let value: Value
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @ViewBuilder func body(content: Content) -> some View {
        if NativeR2Flags.motion && !reduceMotion {
            content.symbolEffect(.bounce, value: value)
        } else {
            content
        }
    }
}

/// A success symbol that is inserted already "done" (punched, unlocked): it bounces once on appear.
struct NativeR2BounceOnAppear: ViewModifier {
    @State private var tick = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @ViewBuilder func body(content: Content) -> some View {
        if NativeR2Flags.motion && !reduceMotion {
            content
                .symbolEffect(.bounce, value: tick)
                .onAppear { tick += 1 }
        } else {
            content
        }
    }
}

/// State chips: the symbol swaps with `.contentTransition(.symbolEffect(.replace))`.
struct NativeR2SymbolReplace: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @ViewBuilder func body(content: Content) -> some View {
        if NativeR2Flags.motion && !reduceMotion {
            content.contentTransition(.symbolEffect(.replace))
        } else {
            content
        }
    }
}

extension View {
    func nativeR2RollingNumber(_ value: Double) -> some View { modifier(NativeR2RollingNumber(value: value)) }
    func nativeR2Bounce<Value: Equatable>(_ value: Value) -> some View { modifier(NativeR2Bounce(value: value)) }
    func nativeR2SymbolReplace() -> some View { modifier(NativeR2SymbolReplace()) }
    func nativeR2BounceOnAppear() -> some View { modifier(NativeR2BounceOnAppear()) }
}
