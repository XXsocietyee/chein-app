import SwiftUI
import CoreLocation
#if canImport(QuestifyCore)
import QuestifyCore
#endif

// Continuity pass 5 (xrefs-1): hold to start → the live session over the SAME 漫游 map. The hold capsule becomes
// the live controls (the pause pill, with the stats pill growing up from it), the 附近 drawer slides away, the map
// stays put (no new screen), and ending reverses it.
//
// OWNER APPROVAL FLAG. This changes the navigation structure (an in-place overlay instead of the pushed
// `RoamLiveSessionView`), so it is off unless `CityLiveOnMap.isEnabled`. The session logic is NOT re-implemented:
// the overlay drives the same retained `RoamLiveSessionController` through its public calls (prepare, start,
// pulse, pause, resume, finish, setForeground) with the same cadence and the same offline write opt-in as the
// live page. Everything the overlay does not own stays on the live page, which it opens unchanged:
// first-use consent and location priming, a denied location, recovery, the presence toggle, the place list,
// paused browsing and the finish report.

enum CityLiveOnMap {
    /// Off by default. On with the launch argument `--city-live-on-map` or the defaults key `cityLiveOnMapV1`.
    static var isEnabled: Bool {
        if ProcessInfo.processInfo.arguments.contains("--city-live-on-map") { return true }
        return UserDefaults.standard.bool(forKey: "cityLiveOnMapV1")
    }
    /// The live page's own consent record (`@AppStorage("roamLivePurposeAcceptedV1")` in `RoamLiveSessionView`).
    static let purposeKey = "roamLivePurposeAcceptedV1"
    /// The write routes the live page opts in for offline capture.
    static let writeRoutes = ["/api/roam/reveal", "/api/compliance/consents"]
    /// The matched-geometry id shared by the hold capsule and the pause pill.
    static let capsuleID = "city.live.capsule"
}

/// Observes the retained live controller without taking its single `onChange` observer away from the live page:
/// it chains onto whatever observer is installed. `attach()` runs again whenever the root reappears, because the
/// live page installs its own observer when it opens.
@MainActor final class CityLiveMapSession: ObservableObject {
    let controller: RoamLiveSessionController
    @Published private(set) var revision = 0
    private var generation = 0

    init(controller: RoamLiveSessionController) {
        self.controller = controller
        attach()
    }

    func attach() {
        generation &+= 1
        let mine = generation
        let previous = controller.onChange
        controller.onChange = { [weak self] in
            previous?()
            guard let self, self.generation == mine else { return }
            self.revision &+= 1
        }
    }

    var phase: RoamLivePhase { controller.phase }
    /// A walk that the map controls can show: started, running, paused or finishing.
    var isRunning: Bool { [.acquiring, .active, .paused, .finishing].contains(controller.phase) }

    /// The overlay can start or resume in place only when the live page has nothing to ask first.
    func canRunInPlace(purposeAccepted: Bool) -> Bool {
        guard purposeAccepted, CLLocationManager().authorizationStatus != .notDetermined else { return false }
        controller.prepare()
        switch controller.phase {
        case .ready: return controller.record == nil
        case .paused: return controller.record?.finishRequested == false && controller.record?.pendingWrite == nil
        case .active, .acquiring: return true
        default: return false
        }
    }
}

/// The live controls docked where the hold capsule was: the stats pill above, the pause / resume pill and the finish
/// circle below. The pause pill shares the hold capsule's matched geometry, so it grows out of it.
struct CityLiveMapControls: View {
    @ObservedObject var session: CityLiveMapSession
    /// Nil under Reduce Motion: the pill then cross-fades instead of growing out of the capsule.
    let space: Namespace.ID?
    /// Called when the walk ends (finished, refused or needing the live page). `openLivePage` asks the root to show
    /// the live page (the finish report, recovery or a denied location) after the controls fold back.
    let onEnded: (_ openLivePage: Bool) -> Void

    @State private var confirmFinish = false
    @State private var showsStats = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.locale) private var locale
    @Environment(\.cyPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.offlineWriteSession) private var offlineWriteSession

    private var copy: CityCopy { CityCopy(locale: locale) }
    private var owner: RoamLiveSessionController { session.controller }

    var body: some View {
        let _ = session.revision
        VStack(spacing: CYSpacing.sm) {
            if showsStats {
                stats
                    .transition(reduceMotion ? .opacity
                                : .scale(scale: 0.6, anchor: .bottom).combined(with: .opacity).combined(with: .offset(y: 24)))
            }
            HStack(spacing: CYSpacing.md) {
                primary
                    .cityMatched(CityLiveOnMap.capsuleID, in: space)
                CityGlassCircle(systemImage: "flag.checkered", label: copy("结束漫游", "Finish roaming")) { confirmFinish = true }
                    .disabled(owner.busy || owner.record == nil || ![.active, .paused].contains(owner.phase))
                    .accessibilityIdentifier("city.live.finish")
            }
        }
        .padding(.horizontal, CYSpacing.pageHorizontal)
        .padding(.bottom, CYSpacing.md)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("city.live.controls")
        // The stats pill follows the pill by one beat (one lead, its follower; xrefs-1).
        .task {
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 0 : 120))
            withAnimation(reduceMotion ? CityTokens.reducedFade : CYMotion.entrance) { showsStats = true }
        }
        .task(id: owner.phase) { await pulseWhileActive() }
        .onChange(of: scenePhase) { _, value in owner.setForeground(value == .active) }
        .onChange(of: owner.phase) { _, phase in phaseChanged(phase) }
        .sensoryFeedback(.impact(weight: .medium), trigger: owner.phase == .paused)
        .overlay {
            if confirmFinish {
                PlayAreaRoamFinishModal(onConfirm: {
                    confirmFinish = false
                    Task { await owner.finish() }
                }, onCancel: { confirmFinish = false })
            }
        }
    }

    @ViewBuilder private var primary: some View {
        switch owner.phase {
        case .active:
            pill(systemImage: "pause.fill", title: copy("暂停", "Pause"), id: "city.live.pause") { owner.pause() }
        case .paused:
            pill(systemImage: "play.fill", title: copy("继续", "Resume"), id: "city.live.resume") { resume() }
                .disabled(owner.busy)
        case .ready, .acquiring:
            pill(systemImage: nil, title: copy("正在定位…", "Locating…"), id: "city.live.acquiring") {}
                .disabled(true)
        default:
            pill(systemImage: nil, title: copy("正在结束…", "Finishing…"), id: "city.live.finishing") {}
                .disabled(true)
        }
    }

    private func pill(systemImage: String?, title: String, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: CYSpacing.sm) {
                if let systemImage { Image(systemName: systemImage).accessibilityHidden(true) }
                else { ProgressView().tint(palette.actionPrimaryFg) }
                Text(verbatim: title).lineLimit(1)
            }
            .cyText(.button)
            .foregroundStyle(palette.actionPrimaryFg)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(palette.actionPrimaryBg, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }

    /// 用时 · 地盘 · 距离, the live page's three readings ("—" when unknown), on one material pill.
    private var stats: some View {
        HStack(spacing: 0) {
            TimelineView(.animation(minimumInterval: RoamLiveTick.interval(reduceMotion: reduceMotion),
                                    paused: owner.phase != .active || !owner.foreground)) { _ in
                reading(RoamLiveElapsedCopy(locale: Locale(identifier: "en")).value(seconds: owner.record == nil ? nil : owner.localForegroundElapsedSeconds),
                        label: copy("用时", "Time"))
            }
            divider
            reading(RoamLiveCoveragePresentation(controller: owner).percentage.map { "\($0)%" } ?? "—", label: copy("地盘", "Turf"))
            divider
            reading(distance, label: usesMiles ? copy("英里", "mi") : copy("公里", "km"))
        }
        .padding(.vertical, CYSpacing.sm)
        .background {
            if reduceTransparency { Capsule().fill(palette.bgElevated) } else { Capsule().fill(.regularMaterial) }
        }
        .overlay(Capsule().strokeBorder(palette.borderSubtle, lineWidth: 0.5))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("city.live.stats")
    }

    private var divider: some View {
        Rectangle().fill(palette.borderSubtle).frame(width: 0.5, height: 28)
    }

    private func reading(_ value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(verbatim: value).cyText(.cardTitle, monospacedDigit: true).foregroundStyle(palette.textPrimary)
                .contentTransition(.numericText())
                .animation(reduceMotion ? nil : CYMotion.numericRoll, value: value)
            Text(verbatim: label).cyText(.caption).foregroundStyle(palette.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    /// i18n r1: miles where the locale is not metric (US English); Chinese and metric locales keep km.
    private var usesMiles: Bool { !copy.chinese && locale.measurementSystem != .metric }
    private var distance: String {
        guard let meters = owner.record?.distanceMeters, meters.isFinite, meters >= 0 else { return "—" }
        return (meters / (usesMiles ? 1609.344 : 1000)).formatted(.number.precision(.fractionLength(1)).locale(locale))
    }

    /// The live page's cadence: one pulse every 3 s while active, in the foreground or holding background location.
    private func pulseWhileActive() async {
        guard owner.phase == .active else { return }
        while !Task.isCancelled && owner.phase == .active {
            do { try await Task.sleep(for: .seconds(3)) } catch { return }
            guard !Task.isCancelled, scenePhase == .active || owner.continuesInBackground else { return }
            await owner.pulse()
        }
    }

    private func resume() {
        Task {
            await SessionOfflineSyncModel.shared.performWriteOptIn(environmentSession: offlineWriteSession.session,
                                                                   routes: CityLiveOnMap.writeRoutes) {
                await owner.resume(purposeAccepted: true)
            }
        }
    }

    private func phaseChanged(_ phase: RoamLivePhase) {
        switch phase {
        case .acquiring, .active, .paused, .finishing: return
        case .ready:
            // A refused start (no fix, consent hook declined): fold back, nothing to show.
            onEnded(false)
        case .finished, .recoveryRequired, .recovering, .locationDenied, .unavailable:
            onEnded(true)
        }
    }
}

extension View {
    /// Matched geometry only when a namespace is given (the hold capsule outside the live root has none).
    @ViewBuilder func cityMatched(_ id: String, in space: Namespace.ID?) -> some View {
        if let space { matchedGeometryEffect(id: id, in: space) } else { self }
    }
}
