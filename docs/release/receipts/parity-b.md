# Parity package P-B: remaining player paths

Base `origin/ui/g-partials` 6adbae522 → branch `ui/parity-b`. Source: `docs/release/parity-2.md` (origin/docs/parity2 d1a1d0e73),
mini-program hengyin 92eda9126 (`/private/tmp/claude-501/hg/chengyinhub-xcx` plus the `work` VPS clone for pages the
partial checkout lacks), backend controllers at the same commit (form vs JSON bodies checked per route).

All new requests are `PlayerGapService` extensions (`Core/PlayerParityBRoutes.swift`, `PlayerGapService.parityBPaths`),
so every view reads the existing `\.playerGapService` and hides when the shipped China composition did not build the
player grant. Grants: every path is in `ReviewedProductionFormMutationRoute.playPaths` **and**
`ChinaReviewedRouteCapability.playerParityBOwnerGrant`; `testShippedChinaAdmitsParityBRoutesAndKeepsMoneyClosed`
drives each request through the shipped China composition and keeps money (pay, payment-readiness, withdraw,
settlement withdraw) and the merchant-scope supply review closed. No change to `App/AppSession.swift` or
`App/AppCompositionRoot.swift`; the only root edit is one `.environment(\.analyticsEventClient, …)` line in
`App/QuestifyApp.swift`. `PlayerGapService.transport` lost `private` so the extension can read raw envelopes.

## Items 1–5

| Item | Path(s) | Native file | Host screen / entry id | State |
|---|---|---|---|---|
| 1 roam passport | `GET /api/roam/passport/summary` | existing `RoamPassportHistoryReader` (already owner-scoped, `RoamPassportHistoryReadRoute`); new `RoamPassportServerSummarySection` in `App/PlayerParityBViews.swift` | Roam hub passport (`RoamPassportOverviewView`): server stats 漫游/探店/活跃日/公里 replace the local-only numbers when the owner read is configured (`pages/roam _loadIntroPassport`); a missing count is "—", a failed read shows the issue, never local numbers. `parityB.passport` | DONE |
| 1 roam passport | `GET /api/roam/passport/history` (`before`, `limit=30`) | existing `RoamPassportHistoryView` / coordinator | 漫游记录 tile under the stats → server history (`parityB.passport.history`); the roam history page keeps its existing `roam.serverHistory.open` entry | DONE (was already native; the capgraph flag was the `prefix + "history"` concatenation) |
| 2 shared session | `GET /api/game/session/shared/control` | `PlayerGapService.sharedControl`, `SharedRunControlSummary`, `SharedRunControlSection` | Organiser runtime: `PlayDirectorView` (CLUB projection = the caller is organiser) shows it for `playMode == ROUTE` with the projection revision fence; club topic detail (`ClubGovernanceViews` topic overview, per session) shows `SharedRunControlEntry` only after `shared/control` answers (served to the organiser alone). `parityB.shared.open.<id>` | DONE |
| 2 shared session | `GET /api/game/session/shared/export` | `sharedExport`, `SharedRunExportSummary` | Same panel, 本局账本 (session, config / high-water hash, manual next sequence, needs-review, version-changed check) | DONE (read-only ledger). The manual takeover sheets that consume it (`MANUAL_BEGIN`, `STAFF_MANUAL_SIGN`, …) post `game/session/command`, which is not in the player grant: HIDDEN |
| 2 shared session | `POST /api/game/session/shared/export/anchor` | `anchorSharedRun`, `SharedRunAnchorResult` | 开始离线记录 (confirm dialog) when `offlineAnchorAvailable`; only a `GAME_*` reason refuses; everything else is reconciled by re-reading control for an anchor of the same epoch (`_reconcileOfflineAnchor`), with a 重新确认 button and no resend | DONE. The MP's storage marker for auto-reconcile after a relaunch is not kept; control's `offlineAnchor` shows the server state on the next open |
| 3 seat scan | `POST /api/registration/scan_group_member_ticket` (form `code`, `activityId`) | `LeadMemberTicket.resolve` (`lead-ticket-scan.js`), `RegistrationSeatTarget` (`registration-seat.js`), `LeadTicketScanOutcome.classify` (`classifyVerificationOutcome`), `LeadTicketPendingStore` | Play lead section (`PlayLeadSection`, leader of an existing lead, activity scope): `LeadMemberTicketScanButton` → `NativeQRScanner`. Seat codes hold one UNKNOWN marker per account+seat before POST; a held seat is only reread. `parityB.lead.scan` | DONE |
| 3 seat scan | `POST /api/verify/seat/receipt` (form) | `seatReceipt`, `LeadTicketScanOutcome.recovered` | Same button: rescanning a held seat reads the original seat; only a 200 `replayed: true` receipt for that seat clears it | DONE |
| 3 seats page | — | — | `subpackageJourney/pages/seats` does not call this path (only `pages/play/index` does), so `JourneySeatsHost` has no entry | HIDDEN: not an MP call site |
| 4 editor | `POST /api/orient/task/alternative` (JSON) | `saveOrientAlternative`, `OrientAlternativeRow` (`theme-runtime-structure.js`) | Topic editor node page (`ProjectEditNodeView`, saved personal topic, saved node with a server id): 找不到时换个方式 section, `parityB.alt.save`. Only changed rows are sent, one at a time; the first failure stops with the server text; inputs stay until the readback matches | DONE |
| 4 editor | `POST /api/topic/author-saved-detail` (form `id`) | `orientAlternatives` (readback + initial load, `nodeAlternativeConfigsLoaded`) | Same section | DONE. Merchant-scope editing is not offered (merchant stays hidden) |
| 4 circle host | `POST /api/circle-theme/instance/configure` (JSON, `scope: ""`) | `CircleThemeCatalog` (`circle-theme.js`, verbatim theme content), `configureCircleInstance`, `CircleThemeConfigureSheet` | Play page circle row (`PlayExperienceView`, circle topic): `CircleThemeHostSection` shows 30天供给复核 + 选择供给角色 only when `project/home` reports the caller as host of a circle topic. The sheet never pre-selects; validates 3–4 covering all roles; unknown result reloads and says so | DONE |
| 4 circle host | `POST /api/project/home` (JSON `{topicId, scope: ""}`) | `circleHostTopic` | Same section (host check + review-date readback after save) | DONE. `circle-theme/instance/review` (确认本实例供给已复核) is not granted for the player: HIDDEN (the merchant workbench keeps it) |
| 5 analytics | `POST /api/analytics/events/batch` (JSON `{events}`) | `Core/AnalyticsEventClient.swift` (`analytics.js`: same allow-list, queue ≤100 per account in UserDefaults, batch ≤50, one batch in flight, ack only on `accepted == count`, each event tried once per flush, same-key dedupe, `sanitizeProperties`, `actorScope member:<id>`, empty `anonymousId`, source `ios_app`) | `\.analyticsEventClient` is built only when the player grant exists (nil capability → nothing tracked). U08-02: `FinishRouteAnalyticsModifier` on `PlayFinishRouteCardView` sends `finish_route_recommendation_shown` once per card and `…_click` on open with `trackProperties` (`mode`, `placement`, `impressionId`, source ids) | DONE (client + events). The card itself is still unmounted on this base, see row h7 below |

## Item 6: open PLAYER PARTIAL rows from parity-2 §3 (g-partials / cloud-g6 rows excluded)

The rows below were written on branches that are not ancestors of this base (mount-g45, cloud-h7-claude,
cloud-h2-claude, cloud-g-editor, ui/main for H1/H4). Their code is not on `ui/g-partials`, so this package does not
edit it or redeclare its types; each row is closed or hidden by what ships today.

| Receipt row | Native file | Host | State and reason |
|---|---|---|---|
| social-roam `/api/roam/session/records` | mount-g45 `RoamSessionArchive.flush` | live roam finish | HIDDEN: the MP flushes pending records made by its own live tile recorder; native live roam keeps no pending tile records, so there is nothing to upload. Server passport facts (item 1) cover the finished-trip view |
| social-roam `/api/template/author-info`, `author-myinfo` | mount-g45 `TemplateAdoptionService.authorDetail` | — | HIDDEN: the MP reads them inside the fabu node-template editor and `temp` page to prefill a template draft; the native editor reads its node templates through its own template detail, so the call has no native counterpart screen |
| social-roam `/api/template/{}/market-submit` | mount-g45 `TemplateProjectActions(.template)` | — | HIDDEN: product decision; the own-shelf contract pins "never dispatch market-submit" |
| h7 U08-02 next-route recommendation + feedback | `Core/AnalyticsEventClient.swift`, `FinishRouteAnalyticsModifier` | play finish | Analytics leg DONE here. Card mount HIDDEN: gated by server feature `finishNearbyRoute` (MP default false), which has no app reader on this base; once mounted, the modifier already tracks it. Integrator: h7's `PlayFinishRouteImpression` may replace `FinishRouteAnalyticsSource` (same fields) |
| h2 U03-03 my-projects status consistency | cloud-h2 `TopicPublicationHeadline` | my projects | HIDDEN for the per-card `publish-status` read: the MP does not read it per card either; editor scope stays the server's `edit-detail` scope |
| h3 U04-02 choices, evidence, endings | `PlayBranchHistoryView` | play | HIDDEN: no in-flow branch-choice sheet; the MP has none (`chapter.blocks.branch` undeclared) |
| h3 U04-03 capability check before buying/starting | `PlayCompatibilitySection` | play | HIDDEN for the purchase side: no activity/registration read carries a verdict (BLOCKED backend), and it precedes payment |
| h1 U02-02 keep places vs change city | ui/main `TopicTemplateUseSection` | template adopt | HIDDEN: production keeps `GatedTopicTemplateUser`; the `/use` grant + `install` belong to the H1 integration, and the owner ruled no city change |
| h1 U02-03 place to-dos + reconfirmation | ui/main `TopicLocationTodosSection` | editor | HIDDEN: hidden while the client is gated (no `/binding-status`, `/binding` grant on this base) |
| h1 U02-04 source version / adoption updates | ui/main `TopicTemplateUse` | — | HIDDEN: diff/upgrade endpoints do not exist (BLOCKED backend); the owner ruled the revision rows are not shown |
| h1 U02-05 attribution, language, preview | ui/main `TopicTemplateNodeCredit` | template detail | HIDDEN on this base; note `GET /api/media/asset/attribution` is already granted here (`PlayerGapService.assetCredit`, G7/G8), so the H1 install only needs its own wiring |
| h5 U06-02 my role and private clues | `PlayAdvancedTeamViews` | play | HIDDEN: "whose turn" needs `turnOrder`, which is not projected (BLOCKED backend); no evidence field exists; the MP made no change |
| h4 U05-02 closed place + approved replacement | ui/main `PlayStationPauseNotice` | shared runtime player view | HIDDEN for the named contact (not projected, BLOCKED backend). The organiser side of the shared runtime now has its control panel (item 2) |
| h4 U05-04 download + offline reading | ui/main `PlayOfflinePackView` | play | HIDDEN for offline reading: the manifest fixes `verified=false`, so nothing can be declared readable offline (BLOCKED backend) |
| g-editor `/api/topic/attribute-binding` editor sheet | cloud-g-editor `TopicCreatorToolsView` | creator tools | HIDDEN: the enable/conflict-resolution sheet edits template attribute registries, a creator-tools surface the read already covers; not ported here to avoid touching cloud-g-editor types |

Money/admin rows (free-explore order receipt, U03-04 admin review, supply-terms REVSHARE) stay counted only.

## Gates

- `tools/generate_project.py`: regenerated (new files in app, Core, and test targets).
- `tools/check_scaffold.py`: PASS. `tools/check_design_lint.py`: PASS.
- `swiftc -parse` on every changed Swift file: PASS.
- Core: `swift build --target QuestifyCore`: Build complete (no errors). `Tests/CoreTests/PlayerParityBRoutesTests.swift`
  has one stub-transport test per new request (control, export, anchor, scan, seat receipt, alternative, author readback,
  project home, configure, analytics batch). Because the whole CoreTests target is known-red on unrelated suites, the file
  was type-checked against the built module and run as a standalone xctest bundle linked to `QuestifyCore.o`:
  10 tests, 0 failures.
- Not run here (integrator compiles): xcodebuild, AppUnitTests (`testShippedChinaAdmitsParityBRoutesAndKeepsMoneyClosed`), simulator.
