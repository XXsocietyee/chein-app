import Observation
import SwiftUI
import UIKit

/// The app's single top pop-up owner (spec M4). Injected at the app root (`IslandRootModifier`) and drawn by
/// `IslandOverlay` in its own pass-through window, so it stays on top of sheets and full-screen covers.
/// Sources call `show(_:)`; several items queue and present one after another. Never makes a request.
@MainActor @Observable final class IslandCenter {
    static let shared = IslandCenter()

    /// The item on screen.
    private(set) var current: IslandItem?
    /// Compact capsule (false) or expanded card (true).
    private(set) var isExpanded = false
    /// Bumped on every new presentation; drives the light impact and the VoiceOver announcement.
    private(set) var presentationCount = 0
    /// Items waiting for the current one to leave.
    private(set) var queued: [IslandItem] = []

    /// Screen frame of the island in window coordinates; the pass-through window only takes touches inside it.
    @ObservationIgnored var interactiveFrame: CGRect = .zero
    @ObservationIgnored private var interacting = false
    @ObservationIgnored private var dismissTask: Task<Void, Never>?
    @ObservationIgnored private var advanceTask: Task<Void, Never>?
    private let maxQueued = 5

    private init() {}

    /// The island is off when the rollout flag is off; callers then keep their old presentation.
    static var isEnabled: Bool { NativeR2Flags.island }

    // MARK: Showing

    /// Presents `item` now, or queues it. An item with the same `dedupeKey` as the current or a queued one replaces it.
    func show(_ item: IslandItem) {
        guard Self.isEnabled else { return }
        if let key = item.dedupeKey, let shown = current, shown.dedupeKey == key {
            // Same identity: the card updates in place instead of leaving and growing again.
            var replacement = item
            replacement.id = shown.id
            current = replacement
            if item.startsExpanded { isExpanded = true }
            scheduleDismiss()
            return
        }
        if let key = item.dedupeKey, let index = queued.firstIndex(where: { $0.dedupeKey == key }) {
            queued[index] = item
            return
        }
        guard current != nil else { present(item); return }
        queued.append(item)
        // Keep the newest few; a burst of status messages must not hold back an invitation for minutes.
        while queued.count > maxQueued {
            if let status = queued.firstIndex(where: { if case .status = $0.kind { return true } else { return false } }) {
                queued.remove(at: status)
            } else {
                queued.removeFirst()
            }
        }
    }

    /// Convenience for the `.status` kind (the `cyToast` shim and plain notices).
    func status(_ title: IslandText, tone: IslandTone = .info, actions: [IslandAction] = [], lifetime: Duration = .seconds(4)) {
        show(IslandItem(kind: .status(tone), title: title, actions: actions, lifetime: lifetime))
    }

    /// Updates the current or queued item with `dedupeKey` in place (no new presentation, no haptic).
    func update(dedupeKey: String, _ change: (inout IslandItem) -> Void) {
        if var item = current, item.dedupeKey == dedupeKey {
            change(&item)
            current = item
        } else if let index = queued.firstIndex(where: { $0.dedupeKey == dedupeKey }) {
            change(&queued[index])
        }
    }

    /// Removes the item with `dedupeKey` wherever it is (a source whose content went away).
    func withdraw(dedupeKey: String) {
        queued.removeAll { $0.dedupeKey == dedupeKey }
        if current?.dedupeKey == dedupeKey { dismiss() }
    }

    // MARK: Interaction

    func expand() {
        guard current != nil, !isExpanded else { return }
        isExpanded = true
        scheduleDismiss()
    }

    func collapse() {
        guard isExpanded else { return }
        isExpanded = false
        scheduleDismiss()
    }

    /// Tap: compact expands; an expanded card with an `open` target runs it and leaves.
    func tap() {
        guard let item = current else { return }
        if !isExpanded, !(item.actions.isEmpty && item.subtitle == nil && item.open != nil) {
            expand()
            return
        }
        if let open = item.open {
            dismiss()
            open()
        } else {
            isExpanded.toggle()
            scheduleDismiss()
        }
    }

    func perform(_ action: IslandAction) {
        if action.keepsIsland {
            action.handler()
            scheduleDismiss()
        } else {
            dismiss()
            action.handler()
        }
    }

    /// While a finger is on the island (or VoiceOver focus), it never auto-dismisses.
    func setInteracting(_ value: Bool) {
        guard interacting != value else { return }
        interacting = value
        if value { dismissTask?.cancel() } else { scheduleDismiss() }
    }

    /// Swipe up, the close action, or the end of the lifetime.
    func dismiss() {
        dismissTask?.cancel()
        guard current != nil else { return }
        current = nil
        isExpanded = false
        interactiveFrame = .zero
        interacting = false
        advanceTask?.cancel()
        advanceTask = Task { [weak self] in
            // Let the leaving island finish its spring before the next one grows.
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled, let self, self.current == nil, !self.queued.isEmpty else { return }
            self.present(self.queued.removeFirst())
        }
    }

    // MARK: Private

    private func present(_ item: IslandItem) {
        current = item
        isExpanded = item.startsExpanded
        presentationCount &+= 1
        scheduleDismiss()
    }

    private func scheduleDismiss() {
        dismissTask?.cancel()
        guard !interacting, let lifetime = current?.lifetime else { return }
        // VoiceOver needs time to read the card and reach its actions.
        let wait = UIAccessibility.isVoiceOverRunning ? lifetime * 3 : lifetime
        let id = current?.id
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: wait)
            guard !Task.isCancelled, let self, self.current?.id == id, !self.interacting else { return }
            self.dismiss()
        }
    }
}
