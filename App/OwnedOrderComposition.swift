import SwiftUI

/// Normal Account destination. Reading the observable approval through reader.identity
/// tracks revocation/expiry even when an already-loaded screen is otherwise idle.
/// Ticket navigation uses a separately configured reader; the lifecycle uses the reviewed cancel/refund factory (payment gated) and no map provider is mounted.
@MainActor struct SessionOwnedOrdersView: View {
    @ObservedObject var session: AppSession
    @State private var showsSignIn = false
    var body: some View {
        OwnedOrdersLifecycleHost(session: session, onSignIn: { showsSignIn = true })
            .environment(\.freeExploreBundleReadProvider, session.freeExploreBundleReadProvider)
            .environment(\.bundleCommerceBaseURL, session.currentRuntimeDependencyContext?.baseURL)
            .environment(\.bundleCommercePublicMerchant, session.publicMerchantHomeContext)
            .environment(\.profileOrderInvoicePresentation, { [weak session] in session?.makeInvoiceLaunchPresentation() })
            .id(session.ownedOrderReader.identity)
            .sheet(isPresented: $showsSignIn) { Group { LoginView(intent: .player).environmentObject(session) }.presentationDetents([.large]).presentationDragIndicator(.visible) }
    }
}

/// Lifecycle for the normal Account destination (FIN-16-1 / FIN-17-1). Reads stay fenced by the
/// owned-order approval. Cancel / cancel-refund reuse the session's reviewed write factory, which
/// dispatches only when the deployment's `allowsReviewedCancellationAndRefund` (or an explicit order
/// approval) is present and the review is fresh. Payment stays behind `ReleaseMoneyWriteSwitch`: the
/// factory has no payment provider while that switch is off. No fixture simulator is attached.
@MainActor struct OwnedOrdersLifecycleHost: View {
    @State private var coordinator: OrderLifecycleCoordinator
    private let session: AppSession
    private let onSignIn: (() -> Void)?
    init(session: AppSession, onSignIn: (() -> Void)? = nil) {
        self.session = session
        self.onSignIn = onSignIn
        _coordinator = State(initialValue: OrderLifecycleCoordinator(
            reader: OwnedOrderLifecycleReader(origin: session.ownedOrderReader, base: session.orderLifecycleReader),
            production: { [weak session] in session?.makeOrderLifecycleDispatcher() }))
    }
    var body: some View {
        ProfileOrdersView(reader: session.ownedOrderReader, lifecycleCoordinator: coordinator, ticketReader: session.ticketWalletReader, onSignIn: onSignIn)
    }
}

/// Fences the shared lifecycle reader behind the owned-order read approval: once the approval is
/// revoked/expired or the account changes, the scope retires and the detail read throws. It
/// exposes no writer; `isOfflineExample` is always false so a fixture simulator is unreachable.
/// While current it reports the base reader's scope and replay context, so the session's reviewed
/// factory (which is bound to that scope) can match it; once retired both stop matching.
@MainActor final class OwnedOrderLifecycleReader: OrderLifecycleReading {
    private let origin: any ProfileReading
    private let base: any OrderLifecycleReading
    private let originReaderID: ObjectIdentifier
    private let baseReaderID: ObjectIdentifier
    private let originIdentity: ProfileReadIdentity?
    private let baseScope: UUID
    private let retiredScope = UUID()
    private var retired = false
    init(origin: any ProfileReading, base: any OrderLifecycleReading) {
        self.origin = origin; self.base = base
        originReaderID = ObjectIdentifier(origin); baseReaderID = ObjectIdentifier(base)
        originIdentity = origin.identity; baseScope = base.scope
    }
    private var current: Bool {
        guard !retired, ObjectIdentifier(origin) == originReaderID, ObjectIdentifier(base) == baseReaderID,
              let originIdentity, originIdentity.accountID > 0, origin.isConfigured, origin.identity == originIdentity,
              base.isConfigured, base.accountID == originIdentity.accountID, base.scope == baseScope else {
            retired = true
            return false
        }
        return true
    }
    var accountID: Int? { current ? originIdentity?.accountID : nil }
    var scope: UUID { current ? base.scope : retiredScope }
    var replayContext: OrderLifecycleReplayContext? { current ? base.replayContext : nil }
    var isConfigured: Bool { current }
    var isOfflineExample: Bool { false }
    func detail(id: Int) async throws -> OrderLifecycleDetail {
        guard let expectedAccountID = originIdentity?.accountID, current, id > 0 else { throw APIError.notConfigured }
        try Task.checkCancellation()
        do {
            let value = try await base.detail(id: id)
            try Task.checkCancellation()
            guard current else { throw CancellationError() }
            guard value.id == id, value.memberID == expectedAccountID else { throw APIError.malformedResponse }
            return value
        } catch {
            guard !Task.isCancelled, current else { throw CancellationError() }
            throw error
        }
    }
}

/// A fresh owned-order record identifies a registration; it does not authorize ticket reads.
/// The only normal host supplies both independently scoped readers from the same AppSession.
struct ProfileOrderTicketTarget: Hashable, Identifiable {
    let id = UUID()
    let registrationID: Int
    private let originReaderID: ObjectIdentifier
    private let originIdentity: ProfileReadIdentity
    private let ticketReaderID: ObjectIdentifier
    private let ticketScope: UUID
    @MainActor init?(order: ProfileOrder, requestedID: Int, origin: any ProfileReading, tickets: any TicketWalletReading) {
        guard requestedID > 0, order.id == requestedID, origin.isConfigured,
              let identity = origin.identity, identity.accountID > 0, order.memberID == identity.accountID,
              tickets.isConfigured, tickets.isAuthenticated else { return nil }
        registrationID = requestedID; originReaderID = ObjectIdentifier(origin); originIdentity = identity
        ticketReaderID = ObjectIdentifier(tickets); ticketScope = tickets.scope
    }
    @MainActor func matches(origin: any ProfileReading, tickets: any TicketWalletReading) -> Bool {
        ObjectIdentifier(origin) == originReaderID && origin.isConfigured && origin.identity == originIdentity &&
            ObjectIdentifier(tickets) == ticketReaderID && tickets.isConfigured && tickets.isAuthenticated && tickets.scope == ticketScope
    }
}

/// Bounded read proxy: neither list reads nor a different registration can use this navigation.
/// Origin approval revocation and ticket/account replacement fence both dispatch and receipt.
@MainActor final class ProfileOrderTicketReader: TicketWalletReading {
    private let target: ProfileOrderTicketTarget
    private let origin: any ProfileReading
    private let tickets: any TicketWalletReading
    private let activeScope = UUID(), retiredScope = UUID()
    private var retired = false
    init(target: ProfileOrderTicketTarget, origin: any ProfileReading, tickets: any TicketWalletReading) {
        self.target = target; self.origin = origin; self.tickets = tickets
    }
    private var current: Bool { !retired && target.matches(origin: origin, tickets: tickets) }
    var isConfigured: Bool { current }
    var isAuthenticated: Bool { current }
    var isOfflineExample: Bool { tickets.isOfflineExample }
    var scope: UUID { current ? activeScope : retiredScope }
    func retire() { retired = true }
    func ticketWallet() async throws -> TicketWalletSnapshot { throw APIError.notConfigured }
    func ticketDetail(id: Int) async throws -> TicketWalletTicket {
        guard current, id == target.registrationID else { throw APIError.notConfigured }
        try Task.checkCancellation()
        do {
            let value = try await tickets.ticketDetail(id: id)
            try Task.checkCancellation()
            guard current else { throw CancellationError() }
            guard value.id == target.registrationID else { throw APIError.malformedResponse }
            return value
        } catch {
            guard !Task.isCancelled, current else { throw CancellationError() }
            throw error
        }
    }
}
@MainActor struct ProfileOrderTicketDestination: View {
    let target: ProfileOrderTicketTarget
    @State private var reader: ProfileOrderTicketReader
    init(target: ProfileOrderTicketTarget, origin: any ProfileReading, tickets: any TicketWalletReading) {
        self.target = target
        _reader = State(initialValue: ProfileOrderTicketReader(target: target, origin: origin, tickets: tickets))
    }
    var body: some View {
        Group {
            if reader.isConfigured {
                TicketWalletDetailView(id: target.registrationID, reader: reader)
            } else { ProfileOrderTicketUnavailableView() }
        }.onDisappear { reader.retire() }
    }
}
struct ProfileOrderTicketUnavailableView: View {
    var body: some View {
        ContentUnavailableView("orderTicketEntry.unavailable", systemImage: "ticket",
                               description: Text("orderTicketEntry.changed"))
            .accessibilityIdentifier("orderTicketEntry.changed")
    }
}
