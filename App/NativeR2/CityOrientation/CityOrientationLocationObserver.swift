import Foundation
import CoreLocation
import UIKit

/// Run-scoped position session for city orientation (P-050): distance to the next control point and the
/// walked distance metric. It is owned by the play screen (`PlayExperienceView`, a `@StateObject` above the
/// run view), so pushing a page over the run no longer stops it; only the end of the run, the play screen
/// leaving for good, or a lost authorization stops it.
///
/// - Foreground: it reads while the run screen exists, as before (never asks for permission).
/// - Background: only while a run is active (`setRunActive(true)`, set by the owner from the run clock),
///   with `allowsBackgroundLocationUpdates`, `pausesLocationUpdatesAutomatically = false` and the system
///   location indicator. The app declares the `location` background mode (`Config/Info.plist`).
///
/// It only reads; arrival is still `PlayArrivalService` and the server, and the 50 m highlight never punches by
/// itself (`PlayArrivalPolicy.stationHighlightMeters`). Nothing is uploaded or shared.
@MainActor final class CityOrientationLocationObserver: NSObject, ObservableObject, @preconcurrency CLLocationManagerDelegate {
    struct Fix: Equatable {
        /// GCJ-02, the datum the run's control points use.
        let latitude: Double
        let longitude: Double
        let accuracyMeters: Double
    }
    enum Access: Equatable { case notDetermined, denied, granted }

    @Published private(set) var fix: Fix?
    @Published private(set) var walkedMeters: Double = 0
    @Published private(set) var access: Access = .notDetermined
    /// True while a city orientation run is active: the only time tracking may continue in the background.
    private(set) var runActive = false
    private var manager: CLLocationManager?
    private var lastWalked: Fix?
    private var lifecycleObservers: [NSObjectProtocol] = []

    override init() {
        super.init()
        let center = NotificationCenter.default
        lifecycleObservers = [
            center.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.applicationBecameActive() }
            },
            center.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.applicationEnteredBackground() }
            }
        ]
    }

    deinit {
        lifecycleObservers.forEach { NotificationCenter.default.removeObserver($0) }
        if let manager {
            manager.stopUpdatingLocation()
            manager.allowsBackgroundLocationUpdates = false
            manager.showsBackgroundLocationIndicator = false
            manager.delegate = nil
        }
    }

    static var currentAccess: Access {
        guard CLLocationManager.locationServicesEnabled() else { return .denied }
        switch CLLocationManager().authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways: return .granted
        case .notDetermined: return .notDetermined
        default: return .denied
        }
    }

    /// Same check as `SessionBackgroundLocationTracker`: setting the background flags without the mode crashes.
    static var declaresBackgroundLocationMode: Bool {
        (Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String])?.contains("location") == true
    }

    private var mayRunInBackground: Bool { runActive && Self.declaresBackgroundLocationMode }

    /// Starts reading. No-op unless already authorized and in the foreground. Never requests authorization.
    func start() {
        access = Self.currentAccess
        guard manager == nil, access == .granted, UIApplication.shared.applicationState == .active else { return }
        let manager = CLLocationManager()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 5
        manager.activityType = .fitness
        // A walk with pauses at control points must not be cut by the system's automatic pause.
        manager.pausesLocationUpdatesAutomatically = false
        self.manager = manager
        applyBackgroundFlags()
        manager.startUpdatingLocation()
    }

    /// Ends the session: the run ended or the play screen left.
    func stop() {
        guard let manager else { return }
        manager.stopUpdatingLocation()
        manager.allowsBackgroundLocationUpdates = false
        manager.showsBackgroundLocationIndicator = false
        manager.delegate = nil
        self.manager = nil
    }

    /// Set by the owner from the run clock. Turning it off in the background ends background reading at once.
    func setRunActive(_ active: Bool) {
        guard runActive != active else { return }
        runActive = active
        applyBackgroundFlags()
        if !active, UIApplication.shared.applicationState == .background { stop() }
    }

    private func applyBackgroundFlags() {
        guard let manager else { return }
        let background = mayRunInBackground
        manager.allowsBackgroundLocationUpdates = background
        manager.showsBackgroundLocationIndicator = background
    }

    private func applicationBecameActive() {
        // Resume foreground reading only for a screen that had started a session before.
        if manager == nil, runActive { start() }
    }

    private func applicationEnteredBackground() {
        if !mayRunInBackground { stop() }
    }

    /// Distance in metres from the last fix to a GCJ-02 point; nil without a fix or coordinate.
    func distance(toLatitude latitude: Double?, longitude: Double?) -> Double? {
        guard let fix, let latitude, let longitude else { return nil }
        return PlayArrivalPolicy.distanceMeters(latitude: fix.latitude, longitude: fix.longitude,
                                                toLatitude: latitude, toLongitude: longitude)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard self.manager === manager else { return }
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways: access = .granted
        default: access = .denied; stop()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard self.manager === manager else { return }
        guard UIApplication.shared.applicationState != .background || mayRunInBackground else { stop(); return }
        for location in locations where location.horizontalAccuracy >= 0 {
            guard let raw = RoamCoordinate(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude),
                  let center = try? RuntimeLocationProjection.gcj02MapCenter(.init(coordinate: raw, datum: .wgs84)) else { continue }
            let next = Fix(latitude: center.coordinate.latitude, longitude: center.coordinate.longitude,
                           accuracyMeters: location.horizontalAccuracy)
            fix = next
            // Walked distance follows the team-trail rule: coarse fixes and standing jitter are not steps.
            guard location.horizontalAccuracy <= TeamWalkedTrail.maxAccuracyMeters else { continue }
            if let last = lastWalked {
                let step = PlayArrivalPolicy.distanceMeters(latitude: last.latitude, longitude: last.longitude,
                                                            toLatitude: next.latitude, toLongitude: next.longitude)
                guard step >= TeamWalkedTrail.minStepMeters else { continue }
                walkedMeters += step
            }
            lastWalked = next
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard self.manager === manager else { return }
        if (error as? CLError)?.code == .denied { access = .denied; stop() }
    }
}
