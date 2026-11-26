import CoreLocation
import SwiftUI

// Play HUD (hand-off frame 401:4731 `PlayHUDView`, skill-r2 SR2-04): one distance, one arrow, one primary; the helpers
// recede. Over the play map: the 下一站 card (place name, a 44 pt heading arrow that turns to the stop in 15° steps,
// the distance once, one caption line 用时 · 线索), then one row: 提示 as a Secondary pill that fills the row and two
// 44 pt glass circles, 队伍 (the team channel, with its unread badge) and 背包.
//
// Motion (xrefs-1, PAT row 3): the timer and the distance are live counters, so they are plain tabular digits that
// never roll. The arrow turns on `CYMotion.standard` only when its 15° step changes; Reduce Motion snaps it.

// MARK: - Geometry

/// Pure geometry for the HUD; both points in the same datum (the server's GCJ-02).
enum PlayHUDGeometry {
    /// Great-circle distance in metres.
    static func distanceMeters(fromLatitude lat1: Double, longitude lng1: Double, toLatitude lat2: Double, longitude lng2: Double) -> Double {
        let radius = 6_371_000.0
        let p1 = lat1 * .pi / 180, p2 = lat2 * .pi / 180
        let dp = (lat2 - lat1) * .pi / 180, dl = (lng2 - lng1) * .pi / 180
        let a = sin(dp / 2) * sin(dp / 2) + cos(p1) * cos(p2) * sin(dl / 2) * sin(dl / 2)
        return radius * 2 * atan2(sqrt(a), sqrt(1 - a))
    }

    /// Initial bearing from the first point to the second, degrees clockwise from north, 0..<360.
    static func bearingDegrees(fromLatitude lat1: Double, longitude lng1: Double, toLatitude lat2: Double, longitude lng2: Double) -> Double {
        let p1 = lat1 * .pi / 180, p2 = lat2 * .pi / 180, dl = (lng2 - lng1) * .pi / 180
        let y = sin(dl) * cos(p2)
        let x = cos(p1) * sin(p2) - sin(p1) * cos(p2) * cos(dl)
        return normalized(atan2(y, x) * 180 / .pi)
    }

    /// The arrow's rotation: the stop's bearing relative to where the phone points, in `step`° steps (SR2-04: 15°),
    /// so a walking hand does not make the arrow shiver. 0..<360.
    static func steppedRotation(bearing: Double, heading: Double, step: Double = 15) -> Double {
        let relative = normalized(bearing - heading)
        return normalized((relative / step).rounded() * step)
    }

    /// The shortest turn from `old` to `new` expressed as an unwrapped angle, so 345° → 0° turns 15°, not −345°.
    static func unwrapped(from old: Double, to new: Double) -> Double {
        var delta = normalized(new) - normalized(old)
        if delta > 180 { delta -= 360 }
        if delta < -180 { delta += 360 }
        return old + delta
    }

    /// `180 m` under a kilometre (rounded to 10 m), `1.2 km` above. PLAY-4: Chinese uses the MP units
    /// (utils/geo.js `distanceText`: 米 / 公里), so the HUD reads 「180 米」「1.2 公里」.
    static func distanceText(_ meters: Double, chinese: Bool = false) -> String {
        guard meters.isFinite, meters >= 0 else { return "—" }
        let metre = chinese ? " 米" : " m", kilometre = chinese ? " 公里" : " km"
        if meters < 1000 {
            let rounded = max(10, Int((meters / 10).rounded()) * 10)
            return rounded >= 1000 ? "1.0" + kilometre : "\(rounded)" + metre
        }
        return String(format: "%.1f", meters / 1000) + kilometre
    }

    static func normalized(_ degrees: Double) -> Double {
        let value = degrees.truncatingRemainder(dividingBy: 360)
        return value < 0 ? value + 360 : value
    }
}

// MARK: - Heading

/// The phone's compass heading while the HUD is on screen. Only starts when location is already authorized for
/// When In Use (the HUD never asks; the arrival action's primer owns the first prompt). nil: no compass (simulator,
/// no permission), and the arrow is not drawn.
@MainActor @Observable final class PlayHUDHeadingSource: NSObject, @preconcurrency CLLocationManagerDelegate {
    private(set) var heading: Double?
    @ObservationIgnored private var manager: CLLocationManager?

    func start() {
        guard manager == nil, CLLocationManager.headingAvailable(), SessionBackgroundLocationTracker.locationAlreadyAuthorized else { return }
        let manager = CLLocationManager()
        manager.delegate = self
        manager.headingFilter = 5
        manager.headingOrientation = .portrait
        manager.startUpdatingHeading()
        self.manager = manager
    }

    func stop() {
        manager?.stopUpdatingHeading()
        manager?.delegate = nil
        manager = nil
        heading = nil
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        guard manager === self.manager, newHeading.headingAccuracy >= 0 else { return }
        let value = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
        guard value.isFinite else { return }
        heading = value
    }

    func locationManagerShouldDisplayHeadingCalibration(_ manager: CLLocationManager) -> Bool { false }
}

// MARK: - 下一站 card

/// What the 下一站 card shows. Every unknown is nil and its piece is left out (never 0).
struct PlayHUDNextStop: Equatable {
    var name: String
    /// `180 m`; nil hides the distance (no fix yet, or the stop has no coordinates).
    var distanceText: String?
    /// Arrow rotation in degrees (already stepped); nil hides the arrow (no compass or no distance).
    var arrowDegrees: Double?
    /// `用时 23:10`; nil leaves it out.
    var elapsedText: String?
    /// Stops done / total (`线索 3 / 6`); nil leaves it out.
    var clues: (done: Int, total: Int)?

    static func == (lhs: PlayHUDNextStop, rhs: PlayHUDNextStop) -> Bool {
        lhs.name == rhs.name && lhs.distanceText == rhs.distanceText && lhs.arrowDegrees == rhs.arrowDegrees
            && lhs.elapsedText == rhs.elapsedText && lhs.clues?.done == rhs.clues?.done && lhs.clues?.total == rhs.clues?.total
    }
}

struct PlayHUDNextStopCard: View {
    let stop: PlayHUDNextStop
    @Environment(\.locale) private var locale
    @Environment(\.cyPalette) private var palette
    @QuestifyReduceMotion private var reduceMotion
    @ScaledMetric(relativeTo: .title2) private var arrowSide: CGFloat = 44
    /// Unwrapped so the arrow always takes the short way round.
    @State private var shownDegrees: Double = 0

    var body: some View {
        HStack(alignment: .center, spacing: CYSpacing.md) {
            VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                Text("playHUD.next").cyText(.meta).foregroundStyle(palette.textSecondary)
                Text(verbatim: stop.name)
                    .cyText(.cardTitle)
                    .foregroundStyle(palette.textPrimary)
                    .lineLimit(2)
                    .accessibilityAddTraits(.isHeader)
                if let caption {
                    Text(verbatim: caption)
                        .cyText(.meta, monospacedDigit: true)
                        .foregroundStyle(palette.textSecondary)
                        .accessibilityIdentifier("playHUD.caption")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if stop.distanceText != nil || stop.arrowDegrees != nil {
                VStack(alignment: .trailing, spacing: CYSpacing.xxs) {
                    if stop.arrowDegrees != nil {
                        Image(systemName: "location.north.fill")
                            .cyText(.sheetTitle)
                            .foregroundStyle(palette.textPrimary)
                            .rotationEffect(.degrees(shownDegrees))
                            .frame(width: arrowSide, height: arrowSide)
                            .background(palette.bgRaised, in: Circle())
                            .accessibilityHidden(true)
                    }
                    if let distance = stop.distanceText {
                        // A live counter: plain tabular digits, no roll (xrefs-1 §3 row 14).
                        Text(verbatim: distance)
                            .cyText(.sheetTitle, monospacedDigit: true)
                            .foregroundStyle(palette.textPrimary)
                            .accessibilityIdentifier("playHUD.distance")
                    }
                }
            }
        }
        .padding(CYSpacing.lg)
        .background(palette.bgElevated, in: RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(verbatim: spoken))
        .accessibilityIdentifier("playHUD.nextStop")
        .onAppear { if let degrees = stop.arrowDegrees { shownDegrees = degrees } }
        .onChange(of: stop.arrowDegrees) { _, degrees in
            guard let degrees else { return }
            let target = PlayHUDGeometry.unwrapped(from: shownDegrees, to: degrees)
            if reduceMotion { shownDegrees = target } else { withAnimation(CYMotion.standard) { shownDegrees = target } }
        }
    }

    // PLAY-4: HUD copy lives in the string catalog (no in-code language ternaries).
    private func text(_ value: String.LocalizationValue) -> String {
        appLocalized(value, locale: locale)
    }

    private var caption: String? {
        var parts: [String] = []
        if let elapsed = stop.elapsedText { parts.append(text("playHUD.caption.time \(elapsed)")) }
        if let clues = stop.clues { parts.append(text("playHUD.caption.clues \(clues.done) \(clues.total)")) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private var spoken: String {
        var parts = [text("playHUD.a11y.next \(stop.name)")]
        if let distance = stop.distanceText { parts.append(distance) }
        if let degrees = stop.arrowDegrees { parts.append(text("playHUD.a11y.clock \(Self.clockPosition(degrees))")) }
        if let caption { parts.append(caption) }
        return parts.joined(separator: ", ")
    }

    /// The arrow as a clock position for VoiceOver (unambiguous in both languages).
    static func clockPosition(_ degrees: Double) -> Int {
        let hour = Int((PlayHUDGeometry.normalized(degrees) / 30).rounded()) % 12
        return hour == 0 ? 12 : hour
    }
}

// MARK: - Helper row

/// The 44 pt glass circle of the play bar (队伍, 背包). Applied as a style so it also dresses a button whose label
/// another file owns (the in-game channel entry), with a full 44 pt hit target.
struct PlayHUDCircleButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @QuestifyReduceMotion private var reduceMotion
    @ScaledMetric(relativeTo: .body) private var side: CGFloat = 44

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .cyText(.bodyMedium)
            .foregroundStyle(Color.white)
            .frame(width: min(side, 56), height: min(side, 56))
            .background(reduceTransparency ? AnyShapeStyle(Color.black) : AnyShapeStyle(.ultraThinMaterial), in: Circle())
            .overlay(Circle().strokeBorder(Color.white.opacity(contrast == .increased ? 0.5 : 0.14), lineWidth: contrast == .increased ? 1.5 : 1))
            .contentShape(Circle())
            // PLAY-11: white glyphs need the dark material on light map tiles.
            .environment(\.colorScheme, .dark)
            .scaleEffect(configuration.isPressed && !reduceMotion ? CYMotion.Scale.press : 1)
            .animation(configuration.isPressed ? CYMotion.press : CYMotion.release, value: configuration.isPressed)
    }
}

/// 提示 (Secondary, fills the row) + 队伍 + 背包. A circle whose destination does not exist in this run is left out;
/// 提示 is always there while a stop is current.
struct PlayHUDBar<Team: View>: View {
    let onHint: () -> Void
    let onBackpack: (() -> Void)?
    @ViewBuilder var team: () -> Team

    var body: some View {
        if NativeR2Flags.storyFlow { nativeBar } else { r1Bar }
    }
    /// Native r2: the same three actions as system bordered buttons (the play stage stays on its dark domain).
    private var nativeBar: some View {
        HStack(spacing: CYSpacing.md) {
            Button(action: onHint) { Label("playHUD.hint", systemImage: "lightbulb").frame(maxWidth: .infinity) }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .accessibilityIdentifier("playHUD.hint")
            team()
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
                .controlSize(.large)
            if let onBackpack {
                Button(action: onBackpack) { Image(systemName: "bag") }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.circle)
                    .controlSize(.large)
                    .accessibilityLabel(Text("playHUD.backpack"))
                    .accessibilityIdentifier("playHUD.backpack")
            }
        }
    }
    private var r1Bar: some View {
        HStack(spacing: CYSpacing.md) {
            CYPillButton("playHUD.hint", style: .secondary, systemImage: "lightbulb", action: onHint)
                .accessibilityIdentifier("playHUD.hint")
            team()
                .buttonStyle(PlayHUDCircleButtonStyle())
            if let onBackpack {
                Button(action: onBackpack) { Image(systemName: "bag") }
                    .buttonStyle(PlayHUDCircleButtonStyle())
                    .accessibilityLabel(Text("playHUD.backpack"))
                    .accessibilityIdentifier("playHUD.backpack")
            }
        }
    }
}

// MARK: - Live wiring

/// Turns the run and the device into a `PlayHUDNextStop`. The fix comes from the play session's own foreground hold
/// (`SessionBackgroundLocationTracker`), read every two seconds; nothing new is requested.
@MainActor enum PlayHUDReading {
    static func nextStop(node: PlayNode, snapshot: PlaySnapshot, elapsedSeconds: Int, heading: Double?,
                         fix: CLLocation?, chinese: Bool = false) -> PlayHUDNextStop {
        var distance: Double?
        var bearing: Double?
        if let lat = node.latitude, let lng = node.longitude, lat.isFinite, lng.isFinite, let here = gcj02(fix) {
            distance = PlayHUDGeometry.distanceMeters(fromLatitude: here.latitude, longitude: here.longitude, toLatitude: lat, longitude: lng)
            bearing = PlayHUDGeometry.bearingDegrees(fromLatitude: here.latitude, longitude: here.longitude, toLatitude: lat, longitude: lng)
        }
        let summary = PlayTaskSummaryPresentation(snapshot: snapshot)
        let clues: (done: Int, total: Int)? = summary.completed.flatMap { done in summary.total.map { (done, $0) } }
        let name = node.name?.trimmingCharacters(in: .whitespacesAndNewlines)
        return PlayHUDNextStop(
            name: (name?.isEmpty == false ? name : nil) ?? "—",
            distanceText: distance.map { PlayHUDGeometry.distanceText($0, chinese: chinese) },
            arrowDegrees: zip2(bearing, heading).map { pair in PlayHUDGeometry.steppedRotation(bearing: pair.0, heading: pair.1) },
            // PLAY-5: the run header already shows the dataXL clock; one timer on screen.
            elapsedText: nil,
            clues: clues)
    }

    private static func zip2(_ a: Double?, _ b: Double?) -> (Double, Double)? {
        guard let a, let b else { return nil }
        return (a, b)
    }

    /// The device fix (WGS-84) in the server's datum. A coarse or stale fix gives no distance rather than a wrong one.
    private static func gcj02(_ fix: CLLocation?) -> RoamCoordinate? {
        guard let fix, let coordinate = RoamCoordinate(latitude: fix.coordinate.latitude, longitude: fix.coordinate.longitude),
              let device = try? RoamDeviceFix(coordinate: coordinate, accuracyMeters: fix.horizontalAccuracy, measuredAt: fix.timestamp, datum: .wgs84),
              let projected = try? RuntimeLocationProjection.gcj02(device) else { return nil }
        return projected.coordinate
    }
}

/// The HUD over the play map: the 下一站 card, the run's one primary (start / pause / resume), then the bar.
/// Shown while a single stop is current and the run is live.
@MainActor struct PlayHUDView<Primary: View, Team: View>: View {
    let node: PlayNode
    let snapshot: PlaySnapshot
    let elapsedSeconds: Int
    let onOpenStop: () -> Void
    let onHint: () -> Void
    let onBackpack: (() -> Void)?
    @ViewBuilder var primary: () -> Primary
    @ViewBuilder var team: () -> Team
    @State private var heading = PlayHUDHeadingSource()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.locale) private var locale

    var body: some View {
        TimelineView(.periodic(from: .now, by: 2)) { _ in
            let stop = PlayHUDReading.nextStop(node: node, snapshot: snapshot, elapsedSeconds: elapsedSeconds,
                                               heading: heading.heading,
                                               fix: SessionBackgroundLocationTracker.shared.freshFix(maxAge: 10),
                                               chinese: locale.language.languageCode?.identifier == "zh")
            VStack(spacing: CYSpacing.md) {
                Button(action: onOpenStop) { PlayHUDNextStopCard(stop: stop) }
                    .buttonStyle(.cyPressable)
                    .accessibilityHint(Text("referenceTask.open"))
                    .accessibilityIdentifier("playHUD.open")
                primary()
                PlayHUDBar(onHint: onHint, onBackpack: onBackpack, team: team)
            }
        }
        .padding(.horizontal, CYSpacing.lg)
        .onAppear { if scenePhase == .active { heading.start() } }
        .onDisappear { heading.stop() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { heading.start() } else { heading.stop() } }
    }
}
