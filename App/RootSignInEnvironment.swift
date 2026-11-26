import SwiftUI

/// L1 P-004: asks the root to present the player sign-in sheet over the current screen, instead of switching to
/// the 我的 tab. The optional `resume` runs once the sheet closes with an account in place, so the action that
/// needed an account continues where the player was. Signed in already: `resume` runs at once.
struct RootSignIn {
    let isAvailable: Bool
    private let request: @MainActor ((@MainActor () -> Void)?) -> Void
    init(_ request: @escaping @MainActor ((@MainActor () -> Void)?) -> Void) { isAvailable = true; self.request = request }
    private init() { isAvailable = false; request = { _ in } }
    static let unavailable = RootSignIn()
    @MainActor func callAsFunction(then resume: (@MainActor () -> Void)? = nil) { request(resume) }
}

private struct RootSignInKey: EnvironmentKey {
    static let defaultValue = RootSignIn.unavailable
}

extension EnvironmentValues {
    var rootSignIn: RootSignIn {
        get { self[RootSignInKey.self] }
        set { self[RootSignInKey.self] = newValue }
    }
}
