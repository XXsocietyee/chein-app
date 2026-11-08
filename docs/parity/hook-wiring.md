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

## Wired in GM-HOOK2 (reads first, one commit per item)

Same rules: leases only when the reviewed deployment has `productionGatesEnabled` and market is China; source defaults stay `reviewed: nil` -> `.unconfigured` (enables nothing); exact-path allowlists in `CompositionHTTPTransport`; settlement, bank withdrawal payout, virtual goods and password login stay off. Tests: `Tests/AppUnitTests/ReviewedHookWiring2Tests.swift` (one class per item; each asserts unconfigured and gates-off refusal, the exact-route allow list, neighbour/foreign-host refusal and viewer/role limits).

| Item | Wiring | Notes |
|---|---|---|
| 1. merchant marketing + ai-insight reads | `composition.merchantMarketingGates` (`reads`/`insight` true, `settlement` false) feeds `AppSession.merchantMarketingCoordinator`; `ReviewedMerchantMarketingReadRoute`: POST `api/merchant/marketing-home?windowDays=30` and POST `api/ai/merchant/insight`, merchant role, no body | `api/merchant/access/me` and the query-less `marketing-home` stay on the coupon-management read lease. `subscription`, `commerce/capabilities`, `predict/inbox`, `predict/settle` are NOT admitted: those marketing surfaces still error closed. |
| 2. roam share snapshot | `composition.isRoamShareSnapshotApproved` -> `AppSession.makeRoamShareSnapshotReader()` (`RoamShareSnapshotReaderFactory`, nil unless approved); `ReviewedRoamShareSnapshotReadRoute`: anonymous GET `api/roam/share/snapshot?token=<32 lowercase hex>` (no Authorization/cookie/body), allowed for signed-out and signed-in viewers | **Entry point not wired**: there is no `NativeEntryIntent` case or production host for `RoamSharedFootprintView` (only fixtures construct it). Opening a `shareToken` link still needs a Core intent + navigation host; the reader and route are ready for it. |
| 3. merchant decor / coop-profile / npc / perk-template saves | `composition.merchantOperationsWriteApproval` (merchant only; paths `api/merchant/decor/save`, `api/merchant/coop-profile/save`, `api/merchant/npc/save`, `api/merchant/city-node/template/submit`); `AppSession.merchantOperationsReader` now builds with that lease and `composition.storage.operationJournal()` (journal only attached together with the lease); `ReviewedMerchantOperationsRoute` admits the saves (JSON, per-path key allowlists, scalar values, required keys) and the four baseline reads a save performs (`coop-profile` and `npc/profile` with `{}`, `merchant/info` empty multipart, `template/myinfo` single positive `id`) | Placed before the coupon `coop-profile` branch (distinct shape: JSON `{}` vs the coupon owner read's no body). Profile (`merchant/update`), business-status and the story second leg are not leased; a story save therefore fails closed before any request. List reads for the editors (`category/list`, `template/my-list`, `activity/list`, `city-node/list`, voice/avatar status) are not admitted in this pass. `AppSession.merchantOperationsReader` is now a cached computed property (rebuilt only when the lease changes). |
| 4. citynode-code issue | `composition.verificationCodeApproval(context)` (kind `.cityVoucher` only, path `api/verify/citynode/issue`) used by `AppSession.makeVerificationCodeCoordinator` when `runtimeDependencies.verificationCodeApproval` is nil; form route `api/verify/citynode/issue` (`poiId` positive) added to `ReviewedProductionFormMutationRoute` | ticket (`dyncode`), `redeem`, `receipt`, `groupcode` stay off. |
| 5. team writes apply / withdraw / handle | `composition.nearbyTeamWriteApproval`; `ReviewedNearbyTeamWriteRoute` (POST sorted-key JSON `{"teamId":N}` / `{"approved":Bool,"memberId":N,"teamId":N}`); `AppSession.makeNearbyTeamCoordinator` now wires `NearbyTeamHTTPWriteAdapter` with a default fresh-evidence loader | Evidence contract (derived from `NearbyTeamWriteEvidence.validates`, no separate mini-program contract exists): the loader re-reads only what the review carries - team via `api/team/nearby` with the current roam query context, applicant via `api/team/applications`, application via `api/team/my-applications` - and the adapter requires each to equal the reviewed value; any drift or missing row is `.notSent`. The coordinator cache is keyed on read+write leases. `kick`/`quit`/`disband`/`join` are not admitted. The round-1 test `ReviewedHookWiringTests` asserted apply/withdraw/handle refused with gates on; those three requests moved to `teamWrites()` (still asserted refused for unconfigured and gates-off compositions) and are asserted admitted in `ReviewedNearbyTeamWriteWiringTests`. |

## Left unwired

Backend column: "absent" = no such route found in `/Users/fanning/chengyin-handoff/backend` Java sources; "present" = route found there; "unchecked" = not looked up in this pass.

| Hook | Reason |
|---|---|
| `merchant/team` operators invite/role/remove (cl-w5a) | **backend gap**: route `api/merchant/operators/*` absent (owner needs it) |
| `merchant/citynode/create` `api/merchant/city-node/save` (cl-w5b) | **backend gap**: route absent (owner needs it) |
| `play/merchant` store-day check-in/answer (cl-w8a) | **backend gap**: route absent (owner needs it) |
| merchant reviews reply, aftercare respond, customer batch tag (cl-w5d, cl-w7b, cl-w7c) | write contract found (`MerchantBusinessMutation`: `api/merchant/reviews/reply`, `api/merchant/aftercare/respond?refundId=`, `api/merchant/crm/customers/tags/batch`), but `MerchantBusinessProductionApproval` needs a `reviewedPolicyVersion` and per-(merchant, action, exact target) `MerchantBusinessActionGrant`s; no reviewed policy exists and a composition cannot enumerate per-entity grants without issuing blanket authority; left off (GM-HOOK2) |
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
