import Foundation
import XCTest
@testable import QuestifyCore

final class WP13RevokePurgeHookTests: XCTestCase {
    private final class Recorder: ChannelRevokePurgeHook {
        struct Call: Equatable { let channelID: Int; let reason: ChannelRevokeReason; let generation: UInt64 }
        var calls: [Call] = []
        func purgeChannelCaches(channelID: Int, identity: ChannelAccount4Identity,
                                reason: ChannelRevokeReason, revokedAtGeneration: UInt64) {
            calls.append(Call(channelID: channelID, reason: reason, generation: revokedAtGeneration))
        }
    }

    private func identity() throws -> ChannelAccount4Identity { try ChannelAccount4Identity(accountID: 7, epoch: 1) }
    private func member() throws -> ChannelGovernanceProjection {
        let rules = try ChannelRulesCAS(publishedVersion: 3, pendingVersion: nil, expectedVersion: 3)
        var value = ChannelGovernanceProjection(
            catalog: try ChannelCatalogEntry(channelID: 21, conversationID: 12, kind: .group, rules: rules),
            identity: try identity())
        try value.consentToPublishedRules(try ChannelRulesAdmission(identity: try identity(), consentedVersion: 3))
        try value.submitInviteOrApply(kind: 1, spaceID: 12, requestID: "wp13-join-02") { _, _, _, _, _, request in
            ["request_id": request, "status": 0, "join_state": "PENDING_REVIEW"]
        }
        try value.assignMemberRole(.member)
        _ = try value.authorizeReadWrite()
        return value
    }
    private func isolation(_ value: ChannelGovernanceProjection) throws -> ChannelRevokeIsolation {
        ChannelRevokeIsolation(channelID: value.catalog.channelID, identity: try identity(),
                               revokedAtGeneration: value.revokeReason == nil ? nil : value.generation,
                               reason: value.revokeReason, phase: value.phase)
    }

    func testRevokeInvokesPurgeCallbackForChannelCaches() throws {
        var value = try member()
        let hook = Recorder()
        let dispatcher = ChannelRevokePurgeDispatcher()
        // Not revoked yet: nothing is purged.
        XCTAssertFalse(dispatcher.dispatch(try isolation(value), to: hook))
        XCTAssertTrue(hook.calls.isEmpty)
        try value.ban()
        XCTAssertTrue(dispatcher.dispatch(try isolation(value), to: hook))
        XCTAssertEqual(hook.calls, [Recorder.Call(channelID: 21, reason: .ban, generation: value.generation)])
    }

    func testPurgeRunsExactlyOncePerRevoke() throws {
        var value = try member()
        let hook = Recorder()
        let dispatcher = ChannelRevokePurgeDispatcher()
        try value.leave()
        let revoked = try isolation(value)
        XCTAssertTrue(dispatcher.dispatch(revoked, to: hook))
        XCTAssertFalse(dispatcher.dispatch(revoked, to: hook))
        XCTAssertFalse(dispatcher.dispatch(try isolation(value), to: hook))
        XCTAssertEqual(hook.calls.count, 1)
        XCTAssertEqual(hook.calls.first?.reason, .leave)
    }
}
