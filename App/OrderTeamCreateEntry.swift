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

private struct OrderActivityDestinationKey: EnvironmentKey {
    static let defaultValue: ((Int) -> AnyView)? = nil
}

extension EnvironmentValues {
    /// Planning audit G-04: the activity detail for an order's activity id. Nil hides the post-refund link (fixtures).
    var orderActivityDestination: ((Int) -> AnyView)? {
        get { self[OrderActivityDestinationKey.self] }
        set { self[OrderActivityDestinationKey.self] = newValue }
    }
}
