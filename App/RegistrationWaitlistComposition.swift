import Foundation

/// Gap #8 (1128 plan, G-02): Release used to give the registration sheet no waitlist service (`registrationApproval` is
/// nil in `AppSession(composition:)`), so every sold-out ticket showed 候补暂不可用. The player write grant now carries
/// the waitlist: one lease per signed-in CN player for `api/club/event-ops/waitlist/{status,join,cancel}`, and the sheet
/// gets a service scoped to the activity it opened. The composition transport admits only the exact
/// `{activityId, ticketId}` body (`ReviewedProductionFormMutationRoute.waitlistScopeBody`).
extension AppCompositionRoot {
    static let registrationWaitlistPaths: Set<String> = RegistrationProductionApproval.waitlistPaths

    /// Nil unless the player write grant (which already carries `api/registration/create`) is issued for `context`.
    func registrationWaitlistApproval(_ context: RuntimeDependencyContext) -> OperationEndpointApproval? {
        guard let grant = playerWriteGrant(context), grant.registration.paths.contains("api/registration/create") else { return nil }
        return try? OperationEndpointApproval(baseURL: context.baseURL, namespace: context.session.namespace,
                                              accountID: context.session.accountID, paths: Self.registrationWaitlistPaths)
    }
}

extension AppSession {
    /// The Release waitlist for one activity: nil when signed out or outside the player grant.
    func registrationWaitlistLease(activityID: Int) -> (any RegistrationWaitlistServing)? {
        guard activityID > 0, let context = currentRuntimeDependencyContext,
              let approval = composition.registrationWaitlistApproval(context),
              let configuration = regionalConfiguration?.apiConfiguration else { return nil }
        let captured = context
        return try? RegistrationWaitlistLeaseService(configuration: configuration, transport: runtimeHTTPTransport,
            approval: approval, activityID: activityID, current: { [weak self] in
                guard let self, self.currentRuntimeDependencyContext == captured else { return nil }
                return self.registrationWaitlistLeaseSession
            })
    }

    private var registrationWaitlistLeaseSession: RegistrationWaitlistLeaseSession? {
        guard let context = currentRuntimeDependencyContext, let token else { return nil }
        return try? RegistrationWaitlistLeaseSession(accountID: context.session.accountID, namespace: context.session.namespace, token: token)
    }
}

extension AppSession {
    /// Gap #8 / #28: after a registration read-back the ticket wallet and "today" ticket read again
    /// (MP baoming → 票已放入票夹; the wallet page reloads on show).
    func refreshTicketWallet() {
        ticketWalletReader.refresh()
        objectWillChange.send()
    }
}
