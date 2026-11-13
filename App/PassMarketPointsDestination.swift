import SwiftUI

/// Stub-ledger row 26. The pass-market balance card opens the existing points ledger.
/// History is `POST api/points/list` (`WalletLedgerView` `.assetPoints`).
/// Earn rules are `POST api/points/result_list` (`WalletPointsTasksView`, the ledger's existing link).
/// Weekly statistics are `POST api/user/points/statistics` (`ProfileWeeklyPointsSection` on the profile).
/// `AppSession` and `AppCompositionRoot` are not extended. No redeem, withdraw, or payout is sent.
@MainActor enum PassMarketPointsBridge {
    @MainActor final class Slot {
        weak var session: AppSession?
        let commerce: WalletCommerceReader
        let statistics: PassMarketPointsStatisticsReader
        let destination: () -> AnyView

        init(session: AppSession) {
            self.session = session
            let transport = PassMarketPointsReadTransport(underlying: session.composition.makeTransport())
            let commerce = Self.commerce(session: session, transport: transport)
            let statistics = PassMarketPointsStatisticsReader(session: session, transport: transport)
            self.commerce = commerce
            self.statistics = statistics
            self.destination = {
                AnyView(WalletLedgerView(reader: commerce, kind: .assetPoints))
            }
        }

        private static func commerce(session: AppSession, transport: PassMarketPointsReadTransport) -> WalletCommerceReader {
            guard let configuration = session.regionalConfiguration?.apiConfiguration else {
                return WalletCommerceReader(session: { nil })
            }
            let service = WalletCommerceService(configuration: configuration, transport: transport)
            return WalletCommerceReader(service: service, onUnauthorized: { [weak session] scope in
                guard let session, session.walletCommerceScope == scope else { return }
                session.expireIfMatching(error: APIError.unauthorized, stamp: session.sessionRevision, credential: session.token)
            }, session: { [weak session] in
                guard let session, let scope = session.walletCommerceScope, let token = session.token else { return nil }
                return (scope, token)
            })
        }
    }

    private static var slots: [Slot] = []

    static func slot(for session: AppSession) -> Slot {
        slots.removeAll { $0.session == nil }
        if let existing = slots.first(where: { $0.session === session }) { return existing }
        let created = Slot(session: session)
        slots.append(created)
        return created
    }

    static func statistics(for session: AppSession) -> PassMarketPointsStatisticsReader {
        slot(for: session).statistics
    }

    static func destination(for session: AppSession) -> () -> AnyView {
        slot(for: session).destination
    }
}

/// Same weekly snapshot the profile section already shows. A missing field stays a failed read, not zero.
@MainActor final class PassMarketPointsStatisticsReader: ProfileWeeklyPointsReading {
    private weak var session: AppSession?
    private let service: ProfileWeeklyPointsService?

    init(session: AppSession, transport: PassMarketPointsReadTransport) {
        self.session = session
        if let configuration = session.regionalConfiguration?.apiConfiguration {
            service = ProfileWeeklyPointsService(configuration: configuration, transport: transport)
        } else {
            service = nil
        }
    }

    var identity: ProfileReadIdentity? {
        guard let session, let account = session.account, account.id > 0 else { return nil }
        return ProfileReadIdentity(accountID: account.id, epoch: session.sessionRevision)
    }

    var isConfigured: Bool {
        guard service != nil, let session, let token = session.token, AuthRequestBuilder.isValidToken(token),
              (session.account?.id ?? 0) > 0 else { return false }
        return true
    }

    func weeklyPoints() async throws -> ProfileWeeklyPoints {
        try Task.checkCancellation()
        guard let session, let service, let token = session.token, AuthRequestBuilder.isValidToken(token),
              let account = session.account, account.id > 0 else { throw APIError.unauthorized }
        let epoch = session.sessionRevision
        do {
            let value = try await service.read(token: token)
            try Task.checkCancellation()
            guard session.account?.id == account.id, session.sessionRevision == epoch, session.token == token else {
                throw CancellationError()
            }
            return value
        } catch {
            guard !Task.isCancelled, session.account?.id == account.id, session.sessionRevision == epoch,
                  session.token == token else { throw CancellationError() }
            if (error as? APIError) == .unauthorized {
                session.expireIfMatching(error: error, stamp: epoch, credential: token)
            }
            throw error
        }
    }
}

private struct PassMarketPointsDestinationKey: EnvironmentKey {
    static let defaultValue: (() -> AnyView)? = nil
}

extension EnvironmentValues {
    var passMarketPointsDestination: (() -> AnyView)? {
        get { self[PassMarketPointsDestinationKey.self] }
        set { self[PassMarketPointsDestinationKey.self] = newValue }
    }
}

struct PassMarketPointsRootModifier: ViewModifier {
    let session: AppSession
    func body(content: Content) -> some View {
        content.environment(\.passMarketPointsDestination, PassMarketPointsBridge.destination(for: session))
    }
}
