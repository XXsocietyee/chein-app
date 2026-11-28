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

    /// Gap #6 (1128 plan): the Release team writes. The command writer (`api/team/command` + query / cancel, from the
    /// player grant) carries join / quit / kick / disband / join-mode the way the MP sends them; the direct-route lease
    /// stays as the fallback when no command grant is issued.
    func teamWrites(_ context: RuntimeDependencyContext?, transport: any HTTPTransport) -> TeamWriteLeases {
        guard let context else { return TeamWriteLeases(approval: nil, commands: nil) }
        return TeamWriteLeases(approval: teamMembershipWriteApproval(context),
                               commands: teamCommandWriter(context: context, transport: transport))
    }
}

/// The two Release team write leases for one coordinator.
struct TeamWriteLeases {
    let approval: OperationEndpointApproval?
    let commands: TeamCommandWriter?
}

enum TeamMembershipWriteComposition {
    /// The team service for one coordinator: the write adapter when `write` is issued, else the read-only reader.
    /// Both keep the read lease and the fresh-membership rule on ID reads.
    @MainActor static func service(configuration: APIConfiguration, transport: any HTTPTransport,
                                   readEndpoints: OperationEndpointApproval, write: TeamWriteLeases,
                                   journal: any TeamPendingJournal,
                                   currentSession: @escaping () -> TeamSession?) -> any TeamServing {
        if write.approval != nil || write.commands != nil {
            return TeamHTTPService(configuration: configuration, transport: transport, approval: write.approval,
                                   journal: journal, currentSession: currentSession,
                                   readApproval: readEndpoints, requiresIDMembership: true, commandWriter: write.commands)
        }
        return TeamReadOnlyService(configuration: configuration, transport: transport, readApproval: readEndpoints,
                                   currentSession: currentSession, requiresIDMembership: true)
    }
}
