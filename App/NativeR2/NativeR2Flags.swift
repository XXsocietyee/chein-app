import Foundation

/// Native r2 switches (owner brief 2026-11-26: "Everything is native").
/// Each flow is on by default. Turning one off restores that flow's previous UI.
/// Only the UI changes behind a flag: requests, payloads and scoring stay the same.
enum NativeR2Flags {
    /// Game kits draw through `NativeGameShell` (App/NativeR2/Games).
    static var games = true
}
