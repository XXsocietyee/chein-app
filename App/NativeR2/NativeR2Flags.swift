import Foundation

/// Native r2 (owner 2026-11-26, "everything native"): one switch per flow. A flow that is on routes its
/// existing entry points to the Apple-component screens under `App/NativeR2/<Flow>/`; off keeps the old screens.
/// Constants, not settings: flipping one is a code change reviewed with the flow.
enum NativeR2Flags {
    /// 自由探索: bundle detail, next-stop map, arrival unlock, stamp capture and the stamp album.
    static let freeExplore = true
}
