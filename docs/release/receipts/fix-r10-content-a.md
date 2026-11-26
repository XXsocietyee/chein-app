# Receipt: fix/r10-content-a

Brief: `origin/design/handoff-r2:docs/briefs/fix-r10.md` (lane content-a).
Slice: `origin/design/handoff-r2:docs/audit/parity-r10/player-content-groups/B-topic.md`, all P0 + P1 (9 rows).
Base: `origin/ui/combined-r7` @ `d9832ac50` (merged again before each push).
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
| R7-PC-B4-3 | partly | dfde7dbc8 (+36c849a9f earlier) | App/PublisherLifecycleViews.swift:33-34, 134, 227-241, 281-284; Core/PublisherLifecycleContracts.swift:60-74, 82-83, 91-92 | Done: per-ticket finals. Core decodes the preview `tickets` (`ticketId`/`id`, `ticketName`/`name`, `price`/`finalPrice`; the keys are read tolerantly because the MP source wasn't available to confirm them). `TopicPricingGapSection` is mounted with live fields, editable while confirm is shown, and confirm sends `ticketPrices` when there is more than one ticket. 开售状态 and 结算待处理 were already done in r9. **Open:** the fee / 到手 row needs the fee-rate field of the MP payload, and I couldn't confirm that field here. Test: `PublisherLifecycleTests.testPreviewTicketsDecodeTolerantlyAndDropInvalidRows` |
| R7-PC-B1-5 | fixed (prior) | 0ab79f407 | App/TopicDetailView.swift:19-20, 71-75 | Landed after the r10 audit snapshot. 开始游玩 opens `playDestination`. |
| R7-PC-B1-6 | partly (prior) | 002dfb536 | App/TopicXcxSections.swift:505-515, 556 | Done: route progress from `/api/play/nodes` (bought only). **Open:** the free-explore merchant cards. `TopicRouteMapAndTeamsSection` can take `merchantCards`, but the route section has no route opener for a card tap, and the bundle `stores` carry only `offerId`, with no merchant id. I did not mount them, to avoid a dead button. This needs an environment opener for `pages/free-explore/index?topicId=`. |
| R7-PC-B1-7 | fixed (prior) | ef6471025 | App/ContextualReviewComposer.swift:16-30, 95 | ≤9 `PhotosPicker` → `img_arr`. |
| R7-PC-B1-12 | fixed (prior) | 858262b40 | App/TopicSelfPlaySheet.swift:14, 24-29 | Pass reveal after a completed order. Free orders now reach it through R8-PC-B1-1. |
| R7-PC-B3-3 | fixed (prior) | 062388650 | App/MerchantContentEditor.swift:30-33, 236, 245, 325 | 你的门店 card and `MerchantApplySuccessSummaryView` mounted. |

## Notes

- Merchant-only rows: none in this slice's P0/P1. merchantapply / merchantinfo rows were already closed.
- Contract ratchet: the base already had 1 new failure (`test_social_article_content…test_renderer_is_wired_only_to_existing_scoped_article_contents`; it expects an `.onDisappear { loads.cancel(); generation += 1; busy = false }` line that the base reshaped). It is not in this lane's files, and this lane leaves the count unchanged.
- P2 rows of B-topic are not in this lane's slice (content-a = P0 + P1).
