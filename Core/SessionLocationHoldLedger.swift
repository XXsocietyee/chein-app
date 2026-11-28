import Foundation

/// OWN-D-07.a: the one switch for session location, ported from `mp:utils/location/bg-tracker.js`.
///
/// The risk is not starting location, it is forgetting to stop it. Every play or roam session takes a hold
/// under its own key. The driver stops only when the last hold is released. Going to the background is not a
/// release: a roam player locks the phone and keeps walking (bg-tracker header comment). A hold ends only
/// when its session finishes, the player exits or leaves the page, the account changes, or the purpose is revoked.
///
/// Background updates are asked for only while a hold that is not foreground-only exists. Permission stays
/// When-In-Use; the system shows the blue background indicator. There is no Always request and no sharing.
@MainActor public protocol SessionLocationDriving: AnyObject {
    /// Start, or reconfigure, continuous updates. `background` sets `allowsBackgroundLocationUpdates`
    /// and `showsBackgroundLocationIndicator`; false clears both.
    func startUpdates(background: Bool)
    /// Stop updates and clear both background flags.
    func stopUpdates()
}

@MainActor public final class SessionLocationHoldLedger {
    /// Known purposes. The privacy page lists the ones that hold location now.
    public enum Purpose: String, CaseIterable, Sendable {
        case roam
        case play
        public static func of(key: String) -> Purpose? {
            if key == Purpose.roam.rawValue || key.hasPrefix("roam:") { return .roam }
            if key.hasPrefix("play:") { return .play }
            return nil
        }
    }
    private struct Hold {
        let key: String
        let foregroundOnly: Bool
        /// False once the account that took this hold is no longer the signed-in account.
        let isCurrent: () -> Bool
        let onFailure: ((Error) -> Void)?
    }
    private var holds: [Hold] = []
    private var revisions: [String: Int] = [:]
    private var revokeListeners: [String: [UUID: () -> Void]] = [:]
    /// Weak: the session tracker owns this ledger and is the driver. A strong driver
    /// would keep that tracker (and every hold closure) alive after the session drops it.
    private weak var driver: (any SessionLocationDriving)?
    public private(set) var isRunning = false
    public private(set) var isBackground = false
    /// Changes on every acquire, release and revoke, for observers that redraw the privacy page.
    public private(set) var changeCount = 0
    public var onChange: (() -> Void)?

    public init(driver: any SessionLocationDriving) { self.driver = driver }

    public var count: Int { holds.count }
    public var keys: [String] { holds.map(\.key) }
    public func hasOwner(_ key: String) -> Bool { holds.contains { $0.key == key } }
    public func revision(_ key: String) -> Int { revisions[key] ?? 0 }
    /// Purposes that hold location now, in a fixed order.
    public var activePurposes: [Purpose] {
        Purpose.allCases.filter { purpose in holds.contains { Purpose.of(key: $0.key) == purpose } }
    }
    public func keys(for purpose: Purpose) -> [String] { holds.map(\.key).filter { Purpose.of(key: $0) == purpose } }

    /// The owner key is the idempotency key: a second acquire for a held key changes nothing and returns false.
    @discardableResult
    public func acquire(_ key: String, foregroundOnly: Bool, isCurrent: @escaping () -> Bool = { true },
                        onFailure: ((Error) -> Void)? = nil) -> Bool {
        guard !key.isEmpty, !hasOwner(key), isCurrent() else { return false }
        holds.append(Hold(key: key, foregroundOnly: foregroundOnly, isCurrent: isCurrent, onFailure: onFailure))
        apply()
        return true
    }

    /// Release one hold; the driver stops when none is left. `force` clears every hold (the catch-all exit).
    public func release(_ key: String, force: Bool = false) {
        let before = holds.count
        if force { holds.removeAll() } else { holds.removeAll { $0.key == key } }
        guard holds.count != before || force else { return }
        apply()
    }

    public func releaseAll() { release("", force: true) }

    /// The player withdrew this purpose. Other independently granted holds keep running; the last one stops the
    /// driver. The revision moves so a session that captured the old revision cannot silently re-acquire.
    public func revoke(_ key: String) {
        revisions[key] = revision(key) + 1
        holds.removeAll { $0.key == key }
        apply()
        for listener in (revokeListeners[key] ?? [:]).values { listener() }
    }

    /// Revoke every hold of one purpose (the privacy page's per-purpose action).
    public func revoke(_ purpose: Purpose) { keys(for: purpose).forEach(revoke) }

    /// Returns a cancel closure. Listeners run after the hold is gone.
    public func observeRevocation(_ key: String, _ listener: @escaping () -> Void) -> () -> Void {
        let id = UUID()
        revokeListeners[key, default: [:]][id] = listener
        return { [weak self] in
            self?.revokeListeners[key]?[id] = nil
            if self?.revokeListeners[key]?.isEmpty == true { self?.revokeListeners[key] = nil }
        }
    }

    /// Called on every location callback before the fix is delivered: a hold whose account changed is released
    /// in that same callback, so switching account stops collection within one callback.
    @discardableResult
    public func dropStaleOwners() -> Bool {
        let stale = holds.filter { !$0.isCurrent() }.map(\.key)
        guard !stale.isEmpty else { return false }
        holds.removeAll { stale.contains($0.key) }
        apply()
        return true
    }

    /// Authorization denied or the driver failed: every hold ends and its owner hears the failure (bg-tracker `finishFailure`).
    public func driverFailed(_ error: Error) {
        let failed = holds
        holds.removeAll()
        apply()
        failed.forEach { $0.onFailure?(error) }
    }

    private func apply() {
        let wantsBackground = holds.contains { !$0.foregroundOnly }
        guard let driver else {
            isRunning = false; isBackground = false
            changeCount &+= 1; onChange?(); return
        }
        if holds.isEmpty {
            if isRunning { driver.stopUpdates() }
            isRunning = false; isBackground = false
        } else if !isRunning || isBackground != wantsBackground {
            driver.startUpdates(background: wantsBackground)
            isRunning = true; isBackground = wantsBackground
        }
        changeCount &+= 1
        onChange?()
    }
}
