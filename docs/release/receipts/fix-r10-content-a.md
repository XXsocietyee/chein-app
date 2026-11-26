# Receipt: fix/r10-content-a

Brief: `origin/design/handoff-r2:docs/briefs/fix-r10.md` (lane content-a).
Slice: `origin/design/handoff-r2:docs/audit/parity-r10/player-content-groups/B-topic.md`, all P0 + P1 (9 rows), then P2 (round 2).
Base: `origin/ui/combined-r7` @ `ae477be47` (round 3; was `d9832ac50`) (merged again before each push).
MP source (`chengyinhub-xcx`) is not in this container. MP file:line citations come from the audit rows.
Gates: `python3 tools/check_scaffold.py` → `PASS structural checks`; `python3 -B tools/check_a11y_lint.py` → PASS (0 new); `python3 -B tools/contract_ratchet.py --check` → new 0 from this lane (see the note at the end).
I had no compiler in the cloud, so the Swift build, unit tests, XCUITest and VoiceOver were NOT_RUN. I grepped every new type and member before using it.
Strings: no new catalog keys. The new copy reuses existing keys or passes the server `msg` through.

## P0

| id | status | SHA | app file:line | note |
|---|---|---|---|---|
| R8-PC-B1-1 | fixed | 4b5aa40e2 | App/GlobalSearchLinksAndTemplates.swift:548-558; App/TopicDetailView.swift:138-139; Core/PlayerContentMPContract.swift:16-20 | `PlayerContentSelfPlayClient.create` now calls `inner.create(intent)`. It sends when the payment switch is on (money is on in Release). With the switch off, it still sends a ¥0 order, checked against a fresh topic read. `PlayerContentMPContract.selfPlayCreateOpen(price:)` decides. With a paid price and the switch off, the topic page shows `TopicSelfPlayUnavailableSheet` before the name/phone form. Test: `PlayerContentMPContractTests.testSelfPlayCreateOpensFreeOrdersAndPaidFollowsMoney` |
| R7-PC-B4-1 | fixed | aac860d1c | Core/RuntimeDependencyConfiguration.swift:116-141; Core/PlayerContentMPContract.swift:12-13 | `publisherGrants` now issues `pricing` (session endpoints + `api/topic/pricing/confirm`), the same way it builds the ownership grant. `pricingGrantEnabled` is `true` and no longer tied to `moneyEnabled` (MP pricing/index.js:419-460 saves a final price; it is not a payment). I updated the pinned tests and cited the MP file: PlayerContentMPContractTests, Cov3DContractPinTests, PlayCov3ContractPinTests, ZzZzCov4PlayerSquarePinTests, ZzZzZzCov4Tests4PinTests, PlayerContentMPLaneATests, RuntimeDependencyTests, test_w2_07_pricing_apply_parity.py, test_fix_r8_mp_first_pc.py and test_runtime_dependency_wiring.py |

## P1

| id | status | SHA | app file:line | note |
|---|---|---|---|---|
| R8-PC-B4-1 | fixed | 8800ad57b | App/PublisherLifecycleViews.swift:330-362 | `beginConfirm` calls `coordinator.confirm(value, consequentialApproval: true)`. On 200 it toasts `res.msg` and goes back after 1.5 s. A message that contains 支付资质 opens the 终价已确认 alert, which dismisses the page. Rejected, notSent and unknown outcomes show their message (`submitError`). Source pins updated: test_publisher_pricing_lifetime.py (confirm now fenced like preview/prepare). |
| R7-PC-B4-3 | partly | dfde7dbc8 (+36c849a9f earlier) | App/PublisherLifecycleViews.swift:33-34, 134, 227-241, 281-284; Core/PublisherLifecycleContracts.swift:60-74, 82-83, 91-92 | Done: per-ticket finals. Core decodes the preview `tickets` (`ticketId`/`id`, `ticketName`/`name`, `price`/`finalPrice`; the keys are read tolerantly because the MP source wasn't available to confirm them). `TopicPricingGapSection` is mounted with live fields, editable while confirm is shown, and confirm sends `ticketPrices` when there is more than one ticket. 开售状态 and 结算待处理 were already done in r9. **Open (blocked, round 2 re-checked):** the fee / 到手 row needs the fee-rate field of the MP pricing payload. The MP source isn't in this container and no app code, doc or test names that key, so I did not guess one. `TopicPricingExtraStatus.platformFeeRatePercent` is ready; it needs only the key. Test: `PublisherLifecycleTests.testPreviewTicketsDecodeTolerantlyAndDropInvalidRows` |
| R7-PC-B1-5 | fixed (prior) | 0ab79f407 | App/TopicDetailView.swift:19-20, 71-75 | Landed after the r10 audit snapshot. 开始游玩 opens `playDestination`. |
| R7-PC-B1-6 | fixed | a215b7833 (+002dfb536 earlier) | App/TopicXcxSections.swift:505-520, 563-565, 578; App/MPGap/PlayerContent/TopicRouteMapAndTeamsSection.swift:11-13, 108-127; Core/MPGap/PlayerContent/TopicRouteMapAndPreviewModels.swift (`TopicFreeExploreMerchantCard.cards(fromCatalog:)`) | Route progress from `/api/play/nodes` (bought only) landed earlier. Round 2: the free-explore merchant cards now load from `/api/free-explore/bundle/catalog` (productType 2), one card per `offerId`, the item name as the perk line. No opener for a card exists (no merchant id in the bundle stores), so the cards are read-only rows, not dead buttons. Test: `MPGapG1Round2Tests.testFreeExploreMerchantCardsFromCatalogDedupeAndDropNamelessStores` |
| R7-PC-B1-7 | fixed (prior) | ef6471025 | App/ContextualReviewComposer.swift:16-30, 95 | ≤9 `PhotosPicker` → `img_arr`. |
| R7-PC-B1-12 | fixed (prior) | 858262b40 | App/TopicSelfPlaySheet.swift:14, 24-29 | Pass reveal after a completed order. Free orders now reach it through R8-PC-B1-1. |
| R7-PC-B3-3 | fixed (prior) | 062388650 | App/MerchantContentEditor.swift:30-33, 236, 245, 325 | 你的门店 card and `MerchantApplySuccessSummaryView` mounted. |

## P2 (round 2)

| id | status | SHA | app file:line | note |
|---|---|---|---|---|
| R7-PC-B2-5 | merchant release | — | App/MerchantContentViews.swift | merchantinfo host recruit stats; merchant center is gated off in Release. |
| R7-PC-B1-13 | fixed (prior) | — | App/TopicDetailView.swift:25-26, 399-400, 600-602; App/TopicSessionSelectionView.swift:13, 57 | `sessionPreferName` → `preferredTicketName` already landed on combined-r7. |
| R8-PC-B6-1 | fixed | 27c7d351d | App/PublicCatalogViews.swift (deleted); App/ContentLandingScreen.swift (moved, unchanged); App/NativeEntryLandingView.swift; Core/NativeEntryRouting.swift; App/PlayerJourneyReadBindings.swift; App/MPParityPassSession.swift | The `.publicCatalog` intent was never constructed. Deleted the views, `PublicCatalogHostWiring`, `installPublicCatalogHost` and `PublicCatalogViewsTests`; `PlayerJourneyProductionTests` keeps the `publicCatalogHost()` money-off checks. `tools/current_ci_manifest.json` still lists the old paths (it was not regenerated for earlier deletions either). |
| R9-PC-BN-3 | fixed (prior) | — | App/ContextualReviewComposer.swift:28-29 | `@ScaledMetric starSide`. |
| R9-PC-BN-4 | fixed (prior) | — | App/TopicDetailView.swift:508 | real `Button`. |
| R10-PC-B-N1 | fixed (prior) | — | App/TopicDetailView.swift:190-258 | no `CYOptionSheet`/`CYModal`/`CYField`/`CYPrimaryButtonStyle` remain; `.alert` + `.textContentType` fields. |
| R10-PC-B-N2 | fixed | c944cc8eb | App/TopicDetailView.swift:299-307, 862-872 | No-photo hero is the plain MP cover-route `Image` (no `CYDesignedCover`); refused state uses `ContentUnavailableView(actions:)` with a `.bordered` 返回. Loading was already `ProgressView`. Pin updated: test_topic_session_selection.py. |
| R10-PC-B-N3 | fixed (prior) | — | App/TopicDetailView.swift | no `CYPillButton` on the page body and no `.scrollContentBackground(.hidden)`. |
| R10-PC-B-N4 | fixed (prior) | — | App/TopicXcxSections.swift:26-63 | `Picker(.segmented)`. |
| R10-PC-B-N5 | fixed | 6cbd6e71c | App/TopicXcxSections.swift:222-254 | Lineup: one `LabeledContent` row per partner, `NavigationLink` when it opens. Chips/stat card were already plain. `CYAvatarView` stays as the plain avatar image. |
| R10-PC-B-N6 | fixed | 1a987bb8e | App/TopicXcxSections.swift:318-330, 386-401 | Bar = padded content on `.background(.bar)` in the host's bottom inset; `TopicBarHeroSource`/`Destination` are pass-throughs (no `cyHeroSource` radius); `TopicBarRecede` was already a pass-through. Pin updated: test_global_chrome_domain_contract.py. |
| R10-PC-B-N7 | fixed | 0e4bc5bc7 | App/TopicXcxSections.swift:636-637 | Stop image `.clipped()`, no corner clip. Note chip/stop number were already plain. |
| R10-PC-B-N8 | fixed | 0f8388e54 | App/MPGap/PlayerContent/TopicRouteMapAndTeamsSection.swift:55-78 | `Marker` with route-number monogram, green tint when done, `Map(selection:)` → `onSelectPin`. Teams are plain text rows (no cards). |
| R10-PC-B-N9 | merchant release | — | App/MerchantContentViews.swift:107-118 | `MerchantContentDocumentView` is merchant-center only (gated off). Its `CYSkeleton` is already `ProgressView`. |
| R10-PC-B-N10 | merchant release | — | App/MerchantContentViews.swift:293, 510-518 | `CYEmptyState` already `ContentUnavailableView`; `MerchantContentRowLinkStyle` remains (merchant only). |
| R10-PC-B-N11 | fixed (prior) | — | App/MerchantContentViews.swift:215, 609 | `.confirmationDialog`, `.borderedProminent`. |
| R10-PC-B-N12 | fixed (prior) | — | App/MPGap/PlayerContent/PlayerContentRound4Views.swift:118-125 | one row per photo, `.clipped()`. |
| R10-PC-B-N13 | fixed (prior) | — | App/PublisherLifecycleViews.swift:56-66, 99, 165 | `ContentUnavailableView`, `.bordered`/`.borderedProminent`. |
| R10-PC-B-N14 | fixed (prior) | — | App/PublisherLifecycleViews.swift:399-405 | `ProgressView`, `.bordered`. |

Already fixed in the r10 audit and not re-touched: R9-PC-B3-2, R7-PC-B1-18, R9-PC-BN-5.

## Notes

- Merchant-only rows: none in this slice's P0/P1. merchantapply / merchantinfo rows were already closed.
- Contract ratchet: the base already had 1 new failure (`test_social_article_content…test_renderer_is_wired_only_to_existing_scoped_article_contents`; it expects an `.onDisappear { loads.cancel(); generation += 1; busy = false }` line that the base reshaped). It is not in this lane's files, and this lane leaves the count unchanged.
- Round 2 added the P2 rows (scheduled prompt).
- Round 3 (2026-11-26): merged `origin/ui/combined-r7` @ `ae477be47` (fast-forward, no conflicts). I re-checked every row ID in B-topic.md: all P0/P1/P2 rows are fixed, merchant release, or listed as fixed in the audit itself (R7-PC-B2-1, R7-PC-B3-2, R7-PC-B1-4, R9-PC-B3-1). The only open item is still the R7-PC-B4-3 fee / 到手 row. I searched the repo again (`docs/mp-gap/player-content.md` §14, `docs/mp-gap/copy-g1-player.md`, `docs/port/strings/gap-g1-player.json` `topicPricing.feeRate`, contract checks). None of them names the preview payload's fee-rate key, so it is still blocked on the MP source (`pages/topic/pricing/index.wxml:52`, `index.js`). No code changes this round. Gates re-run: scaffold PASS, a11y PASS (0 new), contract ratchet 192 failing / baseline 192 / new 0. Swift build / tests still NOT_RUN (no compiler in the cloud).
