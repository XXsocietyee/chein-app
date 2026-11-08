# Gap-Wave Hook Wiring (GM-HOOK)

Scope: the hooks listed in `gap-wave-hooks.md`. Edited `App/AppCompositionRoot.swift` and `App/AppSession.swift` only
(`App/RegionalLaunchConfiguration.swift` untouched; source default stays `reviewed: nil` -> `.unconfigured`).

Rules held: every new lease comes from `ReviewedProductionGateLeases` and is issued only when the reviewed deployment has
`productionGatesEnabled` and the market is China; every new transport route is an exact-path allowlist entry (method, path,
same origin, signed-in viewer, Core-built body/query shape). No write route was added. Bank withdrawal payout, virtual goods
and password login are untouched (no route, still off). No hosts, tokens or bypasses.

## Wired (read-only)

| Hook | Lease / route | Tests |
|---|---|---|
| `subpackageRoam/history/index`, `subpackageTools/anniversary/index` passport history read grant (cl-w5d) | `gates.roamPassportHistory` -> `roamPassportHistoryReadAccess`; the transport already admitted `RoamPassportHistoryReadRoute` once a lease exists (`api/roam/passport/history\|record\|summary`) | `ReviewedHookWiringTests` |
| `subpackageRoam/my-teams/index` read approval (cl-w5a) | `gates.teamRead` -> `teamReadApproval` (`TeamReadApproval`, 1 h, `api/team/my` + `api/team/info`); existing `TeamReadRoute` check admits it | `ReviewedHookWiringTests` |
| `subpackageRoam/nearby/index` + my-teams read grants (cl-w5a, cl-w5b) | `composition.nearbyTeamReadApproval` (paths `api/team/nearby`, `api/team/applications`, `api/team/my-applications`) now the default `readApproval` of `AppSession.makeNearbyTeamCoordinator`; new exact route `ReviewedNearbyTeamReadRoute` (GET `lat,lng,radius` in that order with a valid `NearbyQueryContext`; POST `applications` `{"teamId":N}`; POST `my-applications` with no body) | `ReviewedHookWiringTests` |

`AppSession.nearbyTeamCoordinator` is now a cached computed property that is rebuilt only when the nearby lease appears,
changes owner or disappears. Without production gates the lease is always nil, so the first coordinator is kept as before.

## Already wired by G1 (no change)

- `subpackageTools/capsule/index` private tools (cl-w5a): `roamPrivateToolsWriteAccess` and `makeRoamLiveWriteTransport(profile: .privateTools)` are leased behind `productionGatesEnabled` (China, player); reads fall back to that lease in `permitsRoamLiveRoute`.

## Left unwired (no code in this pass)

Backend column: "absent" = no such route found in `/Users/fanning/chengyin-handoff/backend` Java sources; "present" = route found there; "unchecked" = not looked up in this pass.

| Hook | Reason |
|---|---|
| `merchant/team` operators invite/role/remove (cl-w5a) | backend route `api/merchant/operators/*` absent |
| `merchant/citynode/create` `api/merchant/city-node/save` (cl-w5b) | backend route absent |
| `play/merchant` store-day check-in/answer (cl-w8a) | backend route absent |
| team writes `api/team/apply\|withdraw\|handle` (cl-w5b) | backend present; needs a write lease plus a fresh-evidence loader (`NearbyTeamWriteEvidence`) whose contract is not defined in the app; left off |
| merchant decor / coop-profile / npc / perk-template saves (cl-w5a, cl-w5c, cl-w5d, cl-w5b) | backend present; `OperationEndpointApproval` + `OperationPendingJournal` composition and per-route body allowlists not built in this pass |
| `citynode-code` verification code `api/verify/citynode/issue` (cl-w5b) | backend present; needs a `verificationCodeApproval` and exact body route, not built in this pass |
| `merchant/marketing` + `ai-insight` reads (cl-w5c, cl-w5b) | backend `marketing-home` present; `MerchantMarketingService.Gates` plus a per-market read route not built in this pass |
| roam share snapshot `RoamShareSnapshotReaderFactory` (cl-w5c) | backend present (`api/roam/share/snapshot`); share-token entry point and read route not built in this pass |
| merchant reviews reply, aftercare respond, customer batch tag (cl-w5d, cl-w7b, cl-w7c) | `MerchantBusinessMutation` production transport/grant not built; write contract unchecked |
| CRM campaigns `merchantEngagementApproval` (cl-w5d) | grant type needs reviewed contract; unchecked |
| `merchant/relation` post feed, IM coop invite strip, club edit governance (cl-w6a) | environment-key view wiring, not a grant; not done in this pass |
| `square/detail` block (cl-w6b) | hook doc itself says no backend block route/grant |
| club detail entry gate, governance route, topic end summary (cl-w6c) | view/command shape wiring; open contract mismatch in `gap-wave-open-bugs.md` (`confirmEndTopic`); left unchanged |
| IM chat `MessageSessionWriter` sends (cl-w6c) | IM send is not in this pass's route list; unchecked |
| avatar upload, pricing grants, invoice launch mutations (cl-w7a) | write grants/body routes not built; backend unchecked |
| complaint submitter (cl-w7b) | reviewed complaint-report grant undefined |
| template authoring HTTP service (cl-w8a) | backend unchecked, write route not built |
| story participation, challenge POI, template use, my-project mutation, free-explore cancel, orient score review writers (cl-w8b) | player routes unspecified (see `gap-wave-open-bugs.md` `topic-node-answer`); backend unchecked |

Nothing here was verified by running the simulator tests unless the final report says so.
