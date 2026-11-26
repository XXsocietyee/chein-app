import SwiftUI
import UIKit
import Combine

/// One logical share page. A permission alert, guide, or system sheet may cover it without
/// surrendering a requested save. Retirement never revives an old page or its prepared export.
@MainActor final class RoamSharePresentationLifetime: ObservableObject {
    private var active = false
    private var retired = false
    private var attachmentID: UUID?
    private weak var photoSave: RoamSharePhotoSaveModel?
    var isActive: Bool { active && !retired }
    init(photoSave: RoamSharePhotoSaveModel) { self.photoSave = photoSave }
    func appear() {
        guard !retired, !active else { return }
        objectWillChange.send(); active = true
    }
    func retire(publishing: Bool = true) {
        guard !retired else { return }
        if publishing { objectWillChange.send() }
        retired = true; active = false
        // Preserve the original model's submitted-write lock and completion behavior.
        // This cannot cancel a PhotoKit transaction or manufacture a saved receipt.
        photoSave?.invalidate()
    }
    func attach() -> UUID {
        let id = UUID(); attachmentID = id; return id
    }
    func isCurrentAttachment(_ id: UUID) -> Bool { attachmentID == id }
    func dismantle(_ id: UUID) {
        guard isCurrentAttachment(id) else { return }
        attachmentID = nil; retire(publishing: false)
    }
}

/// No scenePhase hook: PhotoKit's authorization UI is not a user leaving this page.
/// Only confirmed native departure/removal retires the original share presentation.
@MainActor struct RoamShareNativeLifetime: UIViewControllerRepresentable {
    let presentation: RoamSharePresentationLifetime
    func makeUIViewController(context: Context) -> RoamShareNativeLifetimeController { .init(presentation: presentation) }
    func updateUIViewController(_ controller: RoamShareNativeLifetimeController, context: Context) {}
    static func dismantleUIViewController(_ controller: RoamShareNativeLifetimeController, coordinator: ()) {
        controller.presentation?.dismantle(controller.attachmentID)
    }
}
@MainActor final class RoamShareNativeLifetimeController: UIViewController {
    weak var presentation: RoamSharePresentationLifetime?
    let attachmentID: UUID
    private var departing = false
    private var wasInNavigation = false
    init(presentation: RoamSharePresentationLifetime) {
        self.presentation = presentation; attachmentID = presentation.attach()
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { return nil }
    private var ancestry: [UIViewController] {
        var values: [UIViewController] = [], next: UIViewController? = self
        while let value = next { values.append(value); next = value.parent }
        return values
    }
    /// The hosting controller is the navigation child; this attachment is only a descendant.
    private func navigationHost() -> UIViewController? {
        var current: UIViewController? = self
        while let value = current {
            if let navigation = value.navigationController {
                var node: UIViewController? = value
                while let item = node {
                    if navigation.viewControllers.contains(where: { $0 === item }) { return item }
                    node = item.parent
                }
            }
            current = value.parent
        }
        return nil
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if navigationHost() != nil { wasInNavigation = true }
        guard let presentation, presentation.isCurrentAttachment(attachmentID) else { return }
        departing = false; presentation.appear()
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if navigationHost() != nil { wasInNavigation = true }
        departing = ancestry.contains { $0.isMovingFromParent || $0.isBeingDismissed }
    }
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        // A cancelled interactive pop must not retire the page. A push or full-screen
        // cover leaves this host in the navigation stack.
        guard transitionCoordinator?.isCancelled != true else { return }
        retireIfPopped()
        // Non-animated pop never sets isMovingFromParent and drops the host after this callback.
        Task { @MainActor in self.retireIfPopped() }
    }
    private func retireIfPopped() {
        guard transitionCoordinator?.isCancelled != true,
              let presentation, presentation.isCurrentAttachment(attachmentID) else { return }
        let leaving = departing || ancestry.contains { $0.isMovingFromParent || $0.isBeingDismissed }
        let popped = wasInNavigation && navigationHost() == nil
        guard leaving || popped else { return }
        presentation.retire(publishing: false)
    }
}
