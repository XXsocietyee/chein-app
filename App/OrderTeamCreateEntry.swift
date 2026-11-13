import SwiftUI

private struct OrderTeamCreateKey: EnvironmentKey {
    static let defaultValue: ((Int, Int) -> AnyView)? = nil
}

extension EnvironmentValues {
    /// Activity owner id, then the owned registration id. Nil hides the order-detail entry (fixtures).
    var orderTeamCreate: ((Int, Int) -> AnyView)? {
        get { self[OrderTeamCreateKey.self] }
        set { self[OrderTeamCreateKey.self] = newValue }
    }
}
