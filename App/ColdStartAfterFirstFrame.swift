import SwiftUI

/// Work the first screen does not need. `open` runs on the next main turn after the
/// root appears, so it is not on the frame that commits. Home feed reads, account
/// bootstrap, the notification delegate, and the Control Center handler do not wait here.
@MainActor enum ColdStartAfterFirstFrame {
    private static var opened = false
    private static var waiters: [CheckedContinuation<Void, Never>] = []

    static func waitUntilOpen() async {
        if opened { return }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            if opened {
                continuation.resume()
            } else {
                waiters.append(continuation)
            }
        }
    }

    /// Live Activities left by the previous process, and plan-activity token observation.
    /// Both used to run in `QuestifyApp.init`, before the first frame.
    static func open() {
        guard !opened else { return }
        opened = true
        let pending = waiters
        waiters.removeAll()
        pending.forEach { $0.resume() }
        QuestLiveActivityCenter.shared.endOrphanedActivities()
        QuestPlanActivityCenter.shared.start()
    }
}

/// Arms `ColdStartAfterFirstFrame.open` on the next main turn after the first appearance.
struct ColdStartDeferredLaunch: ViewModifier {
    @State private var scheduled = false

    func body(content: Content) -> some View {
        content.onAppear {
            guard !scheduled else { return }
            scheduled = true
            DispatchQueue.main.async { ColdStartAfterFirstFrame.open() }
        }
    }
}
