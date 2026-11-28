import Foundation

/// P0-8 team writes. `makeTeamCoordinator()` used to wrap `TeamReadOnlyService` only, whose submit answers `.notSent`.
/// With the reviewed membership write lease the team pages get `TeamHTTPService`: it journals the operation, re-reads
/// `/api/team/info`, sends the exact `TeamWriteContract` body to `/api/team/{join,quit,kick,disband,join-mode}`
/// (`ApiPlayTeamController` on `us/r3-functional`) and decodes the server's acknowledgement. Without the lease, reads only.
extension AppCompositionRoot {
    /// Nil unless the reviewed deployment enables production gates (CN player / club / merchant roles).
    func teamMembershipWriteApproval(_ context: RuntimeDependencyContext) -> OperationEndpointApproval? {
        guard reviewed?.productionGatesEnabled == true else { return nil }
        return productionGateLeases.teamMembershipWrite(context)
    }
}

enum TeamMembershipWriteComposition {
    /// The team service for one coordinator: the write adapter when `write` is issued, else the read-only reader.
    /// Both keep the read lease and the fresh-membership rule on ID reads.
    @MainActor static func service(configuration: APIConfiguration, transport: any HTTPTransport,
                                   readEndpoints: OperationEndpointApproval, write: OperationEndpointApproval?,
                                   journal: any TeamPendingJournal,
                                   currentSession: @escaping () -> TeamSession?) -> any TeamServing {
        if let write {
            return TeamHTTPService(configuration: configuration, transport: transport, approval: write,
                                   journal: journal, currentSession: currentSession,
                                   readApproval: readEndpoints, requiresIDMembership: true)
        }
        return TeamReadOnlyService(configuration: configuration, transport: transport, readApproval: readEndpoints,
                                   currentSession: currentSession, requiresIDMembership: true)
    }
}
