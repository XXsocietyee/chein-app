# cloud-g-editor: capability gaps G2 (invoices, order center) + G3 (creator topic editor)

Branch `ui/cloud-g-editor` from `origin/ui/main` `ec2e42ba8`. Source list: `docs/release/capability-graph.md`
(ui/capgraph `c2202dbe3`) section (1) MP-ONLY, "orders/payment (player) — 12" and "topics/routes (player) — 11".
Mini-program reference: `chengyinhub-xcx` (`utils/user-invoice.js`, `subpackageMember/components/cy/order-center-entry`,
`pages/publish/fabu` + `theme-d20-page.js` + `theme-route-names.js`, `pages/publish/components/topic-state-keys`,
`components/cy/share-card`, `pages/play/index.js`, `subpackageMember/components/cy/coop-invite-sheet`,
`subpackageMember/utils/coop-publisher-access.js`, `pages/topic/merchantinfo` + `host-layers.js`).

Code only here: no xcodebuild was run. The integrator compiles and runs the app-unit test.

## Grants (both places)

- `App/ReviewedPlayerWriteLeases.swift` `playPaths`: all 23 paths below, plus `api/topic/state-keys` (the existing
  live list read the rename sheet needs). `acceptsPlayerWrite` now admits the three creator GETs
  (`play-setup`, `attribute-binding`, `state-keys`) with only `topicId`/`scope` in the query and no body, PUT
  `play-setup` and PUT `state-keys/{stateKey}` with a JSON body that has a positive `topicId` and no
  `payChannel`/`payAmount`/`price`/`amount`/`maxPerHeadFee`, and `chapter/supply-terms` only for `PERK`/`TRAFFIC`.
  `AppCompositionRoot.admitsPlayerWriteQuery` admits the same three GET queries (line-neutral edit).
- `Core/ChinaReviewedRouteCapability.swift`: new `creatorEditorAndOrderCenterOwnerGrant` set (order-center + 10 topic
  routes) and `isTopicStateKey` for `PUT /api/topic/state-keys/{clue|tag|counter|relation}.<name>`. The 11 invoice
  routes were already in the wired patterns. `wiredPatterns` is unchanged, so its count tests are not moved by this
  change.
- Invoice reader/writer: `ReviewedProductionGateLeases.playerInvoiceApproval` gives the shipped China player an
  `InvoiceLaunchReadApproval` (original receipts on, #725 command receipts off, because the mini-program sends the
  legacy `cancel` and `titles/delete`). `makeInvoiceLaunchService` enables mutations, and `makeInvoiceLaunchPresentation`
  shows the write entries, only when the player grant holds every invoice write path. Line-neutral edits; the
  AppSession/AppCompositionRoot ratchet still passes.
- Test: `ReviewedChinaLaunchCompositionTests.testShippedChinaAdmitsInvoiceOrderCenterAndTopicEditorAndKeepsMoneyClosed`
  sends every route through the shipped China composition transport, and checks that REVSHARE terms, a priced PUT, an
  unrelated PUT, pay, refund (`registration/cancel-refund`, `coop/deposit/refund/retry`) and withdraw stay closed.
  Core test `testChinaGateAdmitsTheG2G3RoutesAndKeepsMoneyClosed` checks the same set at the China route gate.

## G2 orders/payment

| path | native file | status |
|---|---|---|
| `/api/invoice/list` | `Core/InvoiceLaunchService.swift` (existing) · `App/InvoiceLaunchHistoryView.swift` | DONE: reader now granted |
| `/api/invoice/detail` | same · `App/InvoiceLaunchDetailView.swift` | DONE |
| `/api/invoice/orders/eligible` | same · `App/InvoiceLaunchApplyView.swift` | DONE |
| `/api/invoice/apply` (requestId) | `Core/InvoiceLaunchCoordinator.swift` (existing durable journal) | DONE: write enabled by the grant |
| `/api/invoice/request` (apply receipt) | `InvoiceLaunchService.originalApplication` | DONE: `originalReceipts: true` |
| `/api/invoice/cancel` | `InvoiceLaunchService.cancel` (legacy route, as the mini-program) | DONE |
| `/api/invoice/titles` | `InvoiceLaunchService.titles` · `App/InvoiceLaunchTitlesView.swift` | DONE |
| `/api/invoice/titles/save` | `InvoiceLaunchService.saveTitle` | DONE |
| `/api/invoice/titles/save-request` (requestId) | `InvoiceLaunchService.saveTitleWithRequest` · `App/InvoiceLaunchTitleEditor.swift` | DONE |
| `/api/invoice/titles/request` | `InvoiceLaunchService.titleReceipt` | DONE |
| `/api/invoice/titles/delete` | `InvoiceLaunchService.deleteTitle` (legacy route) | DONE |
| `/api/order-center/detail` | `Core/OrderCenterDetailService.swift` · `App/OrderCenterEntryView.swift` (Settings → Order lookup, `SettingsInvoiceEntry`) | DONE: `summaryOf` checks ported; status is the server's `statusText` verbatim; REGISTRATION opens the existing order detail via `mpParity.orderDetail`. The mini-program opens it from a deep link; the app takes the order number by hand or through `initialOutTradeNo`. |

Invoices are tax documents: no amount, payment state, or "paid" label is produced locally.

## G3 topics/routes

| path | native file | status |
|---|---|---|
| `/api/topic/attribute-binding` GET | `Core/TopicCreatorEditorService.attributeBinding` · `App/TopicCreatorToolsView.swift` (Registered attributes) | DONE: snapshot checks and the configVersion fence ported. The binding editor (enable/conflict resolution) is not ported: PARTIAL for that sheet. |
| `/api/topic/author-edit-detail` | `authorEditDetail` (Draft section) | DONE: `isEditingTopicPayload` checks |
| `/api/topic/author-saved-detail` | `authorSavedDetail` (readback before publish) | DONE |
| `/api/topic/play-setup` GET/PUT | `playSetup` / `savePlaySetup` (Play window and prep) | DONE: whole overwrite, `次日` prefix stripped, 6 prep items max |
| `/api/topic/publish-draft` | `publishDraft` (Publish saved draft) | DONE: readback first, configVersion/registryVersion and a `publishRequestId` written to UserDefaults before send and reused after an unknown result. The host-workbench "resubmit supply review" use is merchant workbench state and is not shown. |
| `/api/topic/share-code` | `shareCode` (Share → topic code) | DONE |
| `/api/topic/state-keys/named` | `createNamedStateKey` (Route names → Create) | DONE: clue/tag only, server names the key, 400 message shown |
| `/api/topic/state-keys/{}` PUT | `renameStateKey` (Route names → Rename) | DONE: the read row is sent back with only `label` replaced |
| `/api/topic/invite-chapters` | `inviteChapters` (chapter list for station terms) | DONE as a read. The coop invite send itself goes to coop/merchant routes, which stay hidden. |
| `/api/topic/chapter/supply-terms` | `saveSupplyTerms` (Station terms) | PARTIAL: PERK and TRAFFIC only. REVSHARE sets a per-head fee a club pays, which is a price term, so it is not offered and the grant refuses it. The chapter picker uses `invite-chapters`, not the merchant-recruit station list (`loadProjectHome`). |
| `/api/topic/host-qrcode` | `hostQRCode` (Share → host QR) | DONE |

Entry: owned topic detail in the personal creator list (`SessionCreatorProjectsView`, `.topic`) gets a "Creator tools"
toolbar link (`TopicCreatorToolsToolbar`). The merchant entry passes `entryScope` and gets nothing, so the
merchant-only workbench stays hidden. Strings: `Resources/CreatorEditorUI.xcstrings` (en + zh-Hans).

## Gates run here

- `python3 -B tools/generate_project.py`: regenerated (5 new sources, 1 new catalog).
- `python3 -B tools/check_scaffold.py`: PASS (catalog gaps 0, design lint PASS, AppSession ratchet PASS, structural PASS).
- `xcrun swiftc -parse` on all 13 changed Swift files: PASS.
- Core tests, `swift test --disable-sandbox` with the test target narrowed to one file (local edit, not committed):
  `TopicCreatorEditorServiceTests` 10/10 PASS (a stub transport per route, the order-center read, and the China gate).
  `InvoiceLaunchServiceTests` 18/18 and `CB93RouteAdaptationTests` 5/5 PASS. `ChinaReviewedRouteCapabilityTests` 5/6:
  `testEveryCallSiteHasOneMark` fails with 674 != 672, the same failure the base tree already has (see below).
- The whole `QuestifyCoreTests` target does not compile on `ec2e42ba8`, separately from this change:
  `UGGameplayTests.swift:421` (implicit `self` in a closure) and `IMChatSessionPageTests.swift:128,168`
  (`(Int, Int)` is not Equatable). This branch does not touch those files.

## Left for the integrator

- Build the app and run `ReviewedChinaLaunchCompositionTests` (app-unit, not run here).
- `ChinaReviewedRouteCapabilityTests`, `PlayerJourneyProductionLeaseTests`, and `VideoBountySourceTests` assert
  `wiredPatternCount == 672`. On `ec2e42ba8` the set already has 674 entries (H8 added help/use and help/skip).
  This branch does not change that count.
