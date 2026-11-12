# cloud-w1

Branch `ui/cur8-player-writes`. Base `ui/main` `72d2eb9e`. This commit replaces the parallel player-write allow-list with the reviewed production leases.

## Design

`PlayerWriteAdmission` and `PlayerWriteCatalog` are deleted. They named features and admitted any POST on a flat path set. That is not how this app grants a write.

`ReviewedProductionGateLeases.playerWriters` constructs one real approval per approved feature when `playerWritesEnabled` is on, the market is China, and the role is player or club. `ReviewedProductionFormMutationRoute.acceptsPlayerWrite` admits a request only when that constructed writer covers the path and the body matches the feature rule. `CompositionHTTPTransport.send` calls that route only for a signed-in China viewer on a deployment with `playerWritesEnabled`. A deployment that turns on production gates and leaves player writes off still refuses these bodies.

The shipped China composition (`reviewedDeployment`) sets `playerWritesEnabled`. `reviewedMarketDeployment` and the process-default composition do not.

## Writers the shipped composition constructs

- IM send and send-receipt, including channel text for any positive conversation.
- Club join, apply, and quit (`api/club/join` and `api/club/quit`). Apply is join with `joinMessage`.
- Club post and comment create, delete, like, report, and repost. Role assign and revoke stay nil.
- Square `/api/v1/community/*` GET, POST, PATCH, and DELETE, including guidelines, ack, media register, drafts, posts, publish, and readback. A mutation keeps a non-empty request id. Square drafts already derive `requestId`, `clientRequestId`, and `uploadRequestId` from `workflowID`, so an unknown result retries the same id.
- Profile edit (`api/user/update`) and avatar (`api/common/uploadOSS`, native picker approval, checked avatar transport).
- Free registration only: `api/registration/create` with no `payChannel` and no positive amount. `RegistrationCoordinator.confirm` still sends `payAmount == 0` and `usesAppPaymentChannel: false`. Paid create, pay, and cancel-refund stay denied.
- Team `api/team/command`, `api/team/command/query`, and `api/team/command/cancel`. `TeamCommandWriter` keeps the 32-hex request id until 2xx or 4xx. Transport failure and 5xx stay on that id.
- Play loop: arrive, answer, checkin, photo, sensor-result, puzzle/reveal, action, help, advanced start and action, chapter finish, run-session save, journey opening complete, orient session, and scan-entry. The play configuration includes those capabilities. Scan-entry is enabled with the player-write switch. Inviter binding stays off.
- Roam extras (check-in, stamps, finish, shop visit, discover, reveal, city-node favorite and complete). Presence and presence-visibility are not in the writer. `RoamLiveApproval.presence` stays false.
- Likes, reports, and appeals.
- Friends (read and write approvals) and channel text send plus receipt.

## Still off

Password login, bank withdrawal, payout, virtual goods, merchant and coop operator writes, club role assign and revoke, roam presence, and paid registration. `ReleaseMoneyWriteSwitch` is unchanged. A money path is refused even if a writer path set were later widened.

## Request id

Same rule as `chengyinhub-xcx` `utils/community-submit-progress.js` and `utils/community-post-api.js` at `1c80c5a`: keep the saved id across ack, media register, create, patch, and publish until a confirmed 2xx or an explicit 4xx rejection. Unknown and transport failure do not mint a new id. Team command uses the same rule.

## Tests

- `ReviewedChinaLaunchCompositionTests` asserts each shipped writer is non-nil, merchant and role writers stay nil, and the transport admits a free registration, a community publish, and an IM send while paid registration, login, pay, presence, and role assign stay closed. Gates-only deployments do not construct the writers.
- `TeamCommandWriterTests` keeps one request id across 5xx and clears it on 409 and 200.
- `test_player_write_grant.py` rejects the deleted allow-list and checks the lease path set.
- China route counts include the newly wired team command, play help, and friend paths. Password, bank, and virtual-goods routes stay hidden.
