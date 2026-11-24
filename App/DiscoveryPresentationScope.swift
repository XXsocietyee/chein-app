import Combine

extension DiscoveryReading {
    var discoveryPresentationIdentity: String { "public-fixture" }
    var discoveryPresentationChanges: AnyPublisher<Void, Never> { Empty<Void, Never>().eraseToAnyPublisher() }
}

extension AppSession {
    /// Epoch plus viewer revision also fences same-account role/credential ABA.
    var discoveryPresentationIdentity: String { "\(sessionRevision):\(contentDetailRevision)" }
    var discoveryPresentationChanges: AnyPublisher<Void, Never> { objectWillChange.eraseToAnyPublisher() }
}

import SwiftUI

extension View {
    /// Native sheet chrome for R1 player-front sheets: system detents plus the visible drag indicator.
    func cyR1Sheet(_ detents: Set<PresentationDetent> = [.large]) -> some View {
        presentationDetents(detents).presentationDragIndicator(.visible)
    }
}
