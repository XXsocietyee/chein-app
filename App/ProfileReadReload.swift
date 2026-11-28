import SwiftUI

/// Gap #28 (1128 plan, O-02): a host bumps this token after a write it presented (MP `orderchanged`: the order
/// list reloads when the order sheet closes), and the `ProfileReadScreen` below it reads again, keeping its rows.
private struct ProfileReadReloadTokenKey: EnvironmentKey { static let defaultValue: Int = 0 }

extension EnvironmentValues {
    var profileReadReloadToken: Int {
        get { self[ProfileReadReloadTokenKey.self] }
        set { self[ProfileReadReloadTokenKey.self] = newValue }
    }
}
