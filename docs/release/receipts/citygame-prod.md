# citygame-prod: production CITY game against the gaps-A backend

Branch `ui/citygame-prod` (from `origin/ui/main` 469e525f0). Backend: hengyin `feature/app-gaps-a`
(daee0d4d8..00df8a74e on `integration/backend-app-20261112`), migration `20261113_gaps_a_city_game`,
contract `docs/delivery/app-gaps-a/MAPPING.md` (read on VPS `work`, and the controller and services
read from source).

Code-only on this Mac. The integrator compiles the app target. Core was built and tested here (see Verification).

## (1) Production `CityGameServing`

`Core/CityGameHTTPService.swift`

| `CityGameServing` | Route |
|---|---|
| `snapshot(for:)` | `GET api/city-game/game/snapshot?boardId=` (`CITY_GAME_SNAPSHOT_V1`, incl. `team` block) |
| `deltas(after:)` | `GET api/city-game/game/deltas?boardId=&seasonId=&after=` |
| `quote(_:targetId:read:)` | `POST api/city-game/game/quote` `{action, boardId, targetId}` (paid kinds only) |
| `submit(_:)` | `POST api/city-game/game/action` with `CityActionIntent.body()` (same bytes on every retry, so the server's request hash matches) |
| `receipt(for:)` | `GET api/city-game/game/action/{requestId}`; only `404 CITY_RECEIPT_NOT_FOUND` returns nil |

- The server rolls the die. The client never rolls. `CityActionReceipt` now decodes `diceFace` and
  `pointsCharged` and validates them: a face appears only on an applied roll or challenge, and a
  non-zero charge only on an applied, consented paid action. The board HUD shows the server face
  (`CityGamePanel`, which replaced the `face: nil` stub).
- Unknown outcome: a lost or failed submit leaves the coordinator `unknown` with the journaled intent.
  `readBack` and `retryExact` read the receipt by the saved requestId first. A missing receipt
  re-sends only the identical intent. Any other read failure never dispatches.
- Errors: 401 (HTTP or envelope) calls the session expiry hook. `409 CITY_SNAPSHOT_CHANGED` maps to
  `.snapshotChanged`. Everything else maps to `.rejected(status, errorCode)`. A lapsed lease sends nothing.
- Rules, participation, invite, receipts and fairness use the existing reviewed Core clients
  (`CityPlayerRulesClient`, `CityParticipationRuntimeOwner` with its scoped transport and original
  receipts, `CityFairnessReader`). They are now fed by the CITY lease (see section 3).
- `CityGameSnapshot.team` (`trackPosition`, `landedPropertyId`, `score`) is decoded and validated:
  members only, and the landing must be a listed property. When it is present, `actions(for:)`
  mirrors the server's preconditions. Occupy is offered only on the landed property with a kept
  task. Challenge needs a kept task. Accept-task is hidden once it has been kept.

## (2) One lifecycle; dead path removed

- `CityBoardLifecycle` is the single scale for both generations, as the backend serves it:
  `acceptsNewActions` (OPEN: quote and action) and `servesFrozenReads` (FROZEN: bounded state
  snapshot, player rules, city-value map). `CityReadBoard.phase`, `.acceptsNewActions` and
  `.servesFrozenReads` replace every `lifecycle == "OPEN"/"FROZEN"` string check in Core and App:
  `CityActionContract`, `CityGameCoordinator`, `HomeReturnAndCityDeltaCoordinator`,
  `CityPlayerRulesClient`/`Contracts`, `CityPlayerValue*`, `CityValueBoundedMap*`,
  `CityCurrentSnapshotReading`, `AppSession`, and the `CityPlayerView` chip.
- A FROZEN board still loads the game snapshot read-only: the board shows, every action is hidden,
  and `boardNotice == .boardNotOpen`. Covered by `testOneLifecycleActionsOnlyWhenOpenReadsWhenFrozen`.
- Removed the dead gate `CityGameEndpointAllowlist` / `CityGameOperation`. It was an empty reviewed
  allowlist that could never be satisfied; the CITY lease replaces it.
- Not removed: the r491 action-budget, acquisition, arrival, merchant and task clients. The backend
  defers those routes (MAPPING.md), and their production approvals stay nil, so they stay hidden.
  Deleting them is a separate cleanup.

## (3) Composition behind a CITY capability lease

- `CityGameProductionLease` (Core) carries the host and region. Its `paths` are the 15 composed routes.
  `ChinaReviewedRouteCapability.admitsChinaProductionCall` admits exactly those paths, and
  `/api/city-game/acquisition` and the other deferred routes stay refused.
- `ReviewedProductionGateLeases.cityGame(_:)` mints a lease only when all of these hold: the owner
  approved player writes (`playerWritesEnabled`), the market is China, the base URL is the China
  production host, the role is player or club, and the build names a region. The lease is
  `CityGameCapabilityLease` (`App/ReviewedCityGameLease.swift`). It holds the board read approval,
  the rules approval, the participation grants and the fairness approvals, all for one region and
  one hour. It is reissued when they lapse or the session changes.
- Money check (MAPPING.md and the source): the only charge is `deductMemberPoints` on
  `ums_member.point`, logged in `ums_member_points_detail` and charged to the confirming member
  only. These are member game points, not money. No CITY route creates an order, payment, refund,
  wallet or payout. A contract check (`test_city_routes_move_no_money`) pins this.
- Participation commands get an exact `CityParticipationCommandGrant` only after the player confirms
  that exact command in the form (`CityParticipationGrantIssuer.approve`).
- Wiring:
  - `cityPlayerReadApproval` falls back to the lease read.
  - `notePlayerWrites` installs `cityPlayerRulesApproval` and `cityParticipationRuntimeGrants`.
  - `SessionCityPlayerView` passes `gameFactory: session.cityGameFactory`.
  - `SessionPlayRuntimeView` passes `cityGameModel: session.playCityGame` and loads the real CITY
    read in `.task(id: cityPlayerReadIdentity)`.
  - `CityFairnessEntryBinding` builds the reader for the loaded board (`rulesVersion` = board rule version).
- Region: the app had no CITY region source. It is now `QuestifyCityGameRegion` in Info.plist, from
  `QUESTIFY_CITY_GAME_REGION` in `Config/Base.xcconfig`, which is empty by default. **Empty means no
  lease and no board.** The release owner must set the production `city_game_board.region_id` (in
  `China.Production.xcconfig` or Local) for the board to show. The TEST seed uses `gaps-a-test`.
- A joined member's coordinator needs its recovery journal (Application Support `CityGameActions`).
  If the journal cannot be opened, no coordinator is built, so there is no write without a durable
  record. The store is catalogued in `docs/ops-safety/client-data-catalog.json`.
- The glue-file ratchet held: the CITY session factories live in `ReviewedCityGameLease.swift`, so
  `AppSession.swift` and `AppCompositionRoot.swift` did not grow.

## (4) Tests

`Tests/CoreTests/CityGameHTTPServiceTests.swift` (11 tests, stub transport):
- each game route: request shape and decode
- receipt found, receipt 404 = nil, receipt 503 and lost connection throw
- 401, 409 and lapsed-lease handling
- end-to-end lost roll: unknown, then readback with no receipt, then the same body re-sent, then the server face is settled
- the unified lifecycle
- landing gating
- receipt charge and face validation
- path admission

Updated:
- `CityGameCoordinatorTests`: the allowlist assertion was removed.
- `Tests/ContractChecks/test_city_game_base.py`: the capability comes only from the lease; the production service plus DEBUG fixtures are the only conformers; the production entry points pass the leased game; the no-money check.

## Verification (this Mac)

- `tools/generate_project.py`: regenerated (new files are in the project).
- `tools/check_scaffold.py`: PASS. `tools/check_design_lint.py`: PASS.
- `swiftc -parse` on every changed Swift file: OK.
- Core (`swift build`): compiles. The full `QuestifyCoreTests` target does not compile on the base
  tree (pre-existing errors in `TopicTests`, `ClubCheckinRailTests`, `CloudL5IMSquareTests`,
  `CloudX1AuditBugTests` and others, none touched). So the touched suites ran in a scratch package
  against this `Core/`: **103 tests, 0 failures** (CityGameHTTPService, CityGameCoordinator,
  CityGameProjection, ChinaReviewedRouteCapability, CityPlayerRulesFlow, CityCurrentSnapshot x3,
  CityValueBoundedMapReading, CityPlayerValue x2, HomeReturnAndCityDeltaCoordinator).
- ContractChecks, full run compared with `origin/ui/main` on the same machine: the set of failing
  tests is identical to the base. That base is already red with 94 failures and 100 errors. The one
  failure this branch added (`test_audit_tool_catalog_is_complete`, uncatalogued store) is fixed.
- App target not compiled here, per the brief. The integrator should check `ReviewedCityGameLease.swift`
  (the AppSession extension and `@Observable CityGameHolder`), `AppCompositionRoot` (closure
  fallback for `cityPlayerReadApproval`, `notePlayerWrites`), and `SessionPlayRuntimeView`.

## Left / for the integrator

- Set `QUESTIFY_CITY_GAME_REGION` for production, and the backend must have a board in that region.
- Simulator smoke against TEST (be-int, region `gaps-a-test`) after the app compiles.
- The backend's own lifecycle note stands: OPEN means actions and FROZEN means bounded reads, so one
  board serves the two surfaces at different times. The app now follows that single meaning.
