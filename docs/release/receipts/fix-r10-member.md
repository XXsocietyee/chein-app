# fix-r10 · member lane receipt (2026-11-26)

Brief: `design/handoff-r2:docs/briefs/fix-r10.md`. Source: `design/handoff-r2:docs/audit/parity-r10/member.md` §4 (P0, P1, P2).
Branch `fix/r10-member` from `origin/ui/combined-r7` @ `d9832ac50`. Nothing was compiled (no Swift toolchain in the cloud); every type and member was grepped before use.

Base note: the audit read `82bcf2c2d`. Between that commit and this base, `fix/r9-member` round 3 (merged as `cf1e31ccb`) already closed most of the §4 rows. Each of those rows was re-checked in code on this base. They are marked **fixed on base**, with the commit that fixed them.

## Gates (at the last push)
- `python3 tools/check_scaffold.py`: PASS structural checks (5190 Swift files, 19486 bilingual keys).
- `python3 -B tools/check_a11y_lint.py`: PASS (0 new).
- `python3 -B tools/contract_ratchet.py --check`: 193 failing, baseline 192, **new 1, and it is not from this lane**. The new failure is `test_social_article_content…test_renderer_is_wired_only_to_existing_scoped_article_contents`. It reads `App/SocialAccountComponents.swift`, which this branch does not touch, and it already fails on the base `d9832ac50`.
- `python3 tools/merge_localization_fragments.py --check-member`: MATCH (6 fragments).

## Rows

### P0
| id | status | SHA | app file:line |
|---|---|---|---|
| MKT-3-1b | fixed | 9251fd891 | `Core/ChinaReviewedRouteCapability.swift:113,121` adds `memberGiftClaimOwnerGrant` (`/api/marketing/product/gifts/claim`, MP `market/gift/index.js:101-123`; the claimer sends only the gift token). It is kept outside `wiredPatterns`, so the count stays 680. `Core/PlayerJourneyProductionLease.swift:28` drops `.giftClaim` from `refused`. Four tests were updated to pin the new contract, with comments citing the MP. The landing-page `JourneyLoopSource.giftClaim` stub still throws; that belongs to the play-roam lane, not this one. |

### P1
| id | status | SHA | app file:line |
|---|---|---|---|
| R9-MEM-STR-1a | fixed on base | — | `--check-member` reports MATCH on `d9832ac50`. Examples: `mp.member.buy.renew` = 续买30天, `accountCollection.coupons.title` = 优惠券. |
| R9-MEM-STR-1b | fixed on base | — | Same check, member-b fragment. |
| (MKT-8-2) | fixed on base | — | Closed with STR-1a. |
| R8-MEM-26-1b | fixed | 95ac49a6c | Removed the page rule and the enumerated `scope` entry for mytemplate. The redirect is restored at `Core/MiniProgramPageLink.swift:287`: the link opens `pages/activity/official-mine/index` and drops the query (MP app.json has no mytemplate, xcx 910de033). The reviewed-page case is removed from `App/MPReviewedPageScreen.swift`. This reverses the Cursor commit `d76820751`, which kept the page. `TemplateAuthoringMineView` stays, because other entries still use it. |
| MKT-7-3b | fixed on base | fa230d1b6, eb5e7a73e | `App/FreeExploreBundleLaunchView.swift`: `startAtText`, plus 取消预约 / 更换商家 / 商家评价 |
| FIN-17-4b | fixed on base | 5043b2ced | `App/ProfileOrderSourceDetailSections.swift:144` uses `followClubOwner` (`/api/user/follow/action`) |
| MKT-9-2 | fixed on base | 354b9f8af (merge) | `App/CouponCodeView.swift:71` issues the code on appear, with no confirm sheet |
| R8-MEM-21-1 | fixed on base | 8b7cf1bb8 | `App/TicketWalletView.swift:100` shows companion seats as 同伴席位 rows |
| NAT-1 | fixed on base | 87ee71b9d | `App/DesignSystem/CYStates.swift:51` uses `ContentUnavailableView` |
| NAT-2 | fixed on base | — | `App/TicketPassPresentView.swift` has no `preferredColorScheme` |
| NAT-3 | fixed on base | — | `App/PassMarketViews.swift` and `App/PassMembershipViews.swift` have 0 `CYNight`, gradients or `.shadow` |

### P2
| id | status | SHA | app file:line |
|---|---|---|---|
| PLY-23-6 | fixed on base | 6a51c25aa | `App/PlayerJourneyViews.swift:499,563` |
| R7-MEM-7-1 | fixed on base | a5e9d9842 | `App/FreeExploreTopicCatalogScreen.swift:113` |
| R8-MEM-7-3 | fixed on base | e4beeb88a | `App/FreeExploreReceiptResolveScreen.swift:59,112` |
| MKT-10-3 | fixed on base | 597ef5d4e | `App/CouponManagementView.swift:83` |
| R7-MEM-16-1 | fixed (base + money) | c225362bd, **29d4bf6ee** | The base already had 取消订单 / 取消报名 on the card. Money is ON per the fix-r10 brief, so this lane adds 立即支付 (unpaid) and 取消并退款 (paid and refundable) on the card, MP order-history `index.wxml:84-90`. Each shows only while its own switch (`ReleaseMoneyWriteSwitch.paymentEnabled` / `refundEnabled`) is on, and opens the existing `OrderLifecycleView` sheet (pay section, reviewed refund confirm). See `App/ProfileOrdersView.swift:47,872,879`. New keys: `profile.orderExit.payNow`, `profile.orderExit.cancelRefund` (`docs/port/strings/fix-r10-member.json`). |
| R7-MEM-24-2 | fixed on base | 7e1a04954 | `App/CharacterSheetDetailView.swift:36` |
| R9-MEM-17-2 | fixed on base | 9458684d8 | `ProfileOrderSettlementCopy` |
| R9-MEM-5-1 | fixed on base | 100a5a2a7 | `App/PassMarketViews.swift:1203` |
| R9-MEM-3-1 | fixed on base | 5a93bbe0c | `App/PassRedeemCodeView.swift` deleted; `App/MPParityKit.swift:113` |
| NAT-4 | fixed on base | — | `App/DesignSystem/CYStatusChip.swift:42` draws footnote text or a `Label` in a system colour, with no capsule |
| NAT-5 | fixed on base | — | `App/DesignSystem/CYPillButton.swift:110-112` maps to `.borderedProminent` / `.bordered` |
| NAT-6 | fixed on base | 8c9408404 | `App/InvoiceLaunchTitleEditor.swift` |
| NAT-7 | fixed on base | — | `App/DesignSystem/CYSkeleton.swift` uses `.redacted(reason: .placeholder)` |
| NAT-8 | fixed on base | — | `App/InvoiceLaunchHistoryView.swift:27`, `App/MemberScoreAppealListView.swift:60` use a segmented `Picker` |
| NAT-9 | fixed on base | 1b868d8e6 | `App/FreeExploreBundleLaunchView.swift` |
| NAT-10 | fixed on base | f7f5d0670 | `App/OrientScoreView.swift` |
| NAT-11 | fixed on base | ce2c6feb5 | `App/CharacterSheetDetailView.swift` |
| NAT-12 / NAT-13 | fixed on base | 8c9408404 | `App/TicketWalletView.swift`, `App/TicketPassSheet.swift` |
| NAT-14 / NAT-15 / NAT-16 | fixed on base | — | `App/PassMarketViews.swift`, `App/PassMembershipViews.swift:128`, `App/CouponCodeView.swift:26` are `List`s |
| NAT-17 | fixed on base | 8c9408404 | No `CYSheetContainer` / `RoundedRectangle` / `CYListRow` / `Capsule` remains in the four cited files |
| R9-MEM-NIT-1 | fixed on base | bd9469fe3 | `App/TicketWalletView.swift:68` |

## Notes for the coordinator
- **MONEY-GOV-1:** the fix-r10 brief says money is ON in Release (owner, 11-26), which answers the audit's go-live blocker.
- **Not a queue row (MKT-5-3, platform-pass order cancel / confirm / refund-apply):** this stays TEST-only. A platform pass is digital content, which falls under virtual goods, and virtual goods stay off. While payment is on, `PassOrderRefusedWrites` shows the gated note and 已拒绝 on tap; it does not send. A product decision is needed if the owner wants these sent.
- No merchant-only rows in this slice.

## Round 2 (2026-11-26): member §4 done; B-topic P2 rows

Round 2 re-checked member.md §4 on the new base (`origin/ui/combined-r7` @ `05caead53`, merged first). Every row is still closed as listed above, so the lane moved on to the P2 rows of `player-content-groups/B-topic.md` §4. `fix-r10-content-a.md` covers only P0 and P1, so all 19 P2 rows were open to this lane. Several had already landed on the base through `fix/r9-player-content`. Nothing was compiled.

| id | status | SHA | app file:line | note |
|---|---|---|---|---|
| R7-PC-B2-5 | partly (on base) | (r9 enum copy) | `App/MerchantContentViews.swift` `MerchantContentEnumCopy` | The MP enum words for termsMode and registration status are already in. The host recruit stats (nodeFilled / nodeTotal / pendingCount) are still separate `LabeledContent` rows. The MP source is not in this container, so the designed layout was not copied. |
| R7-PC-B1-13 | fixed on base (picker) | 4cc1461c6 | `App/TopicDetailView.swift:25,390`; `App/TopicSessionSelectionView.swift` `preferredTicketName` | The tapped ticket is preselected in the picker, which is what the row asks for. The activity page hand-off still takes only an activity id. |
| R8-PC-B6-1 | fixed | 084adf846 | `App/NativeEntryLandingView.swift:60-67`; deleted `App/PublicCatalogViews.swift`, `Tests/AppUnitTests/PublicCatalogViewsTests.swift` | MP `catalog/index.js:1-10` is a redirect stub. `/catalog?id=` now opens the topic page and `/catalog` goes home. `ContentLandingScreen` moved to `App/ContentLandingScreen.swift`. `PublicCatalogHostWiring` and `installPublicCatalogHost` were removed. The Core `PublicCatalogHost` / link parser stay, because Core tests pin them. |
| R9-PC-BN-3 | fixed on base | e6e9e8f5e | `App/ContextualReviewComposer.swift:29` | `@ScaledMetric` star size |
| R9-PC-BN-4 | fixed on base | a1824d03d | `App/TopicDetailView.swift:~505` | The card is a real `Button`. |
| R10-PC-B-N1 | fixed on base | — | `App/TopicDetailView.swift` | 0 `CYOptionSheet` / `CYModal` / `CYField` / `CYPrimaryButtonStyle` |
| R10-PC-B-N2 | fixed | 152978ee4 | `App/TopicDetailView.swift:275-278, 857-866` | With no image storage, the hero is the plain header row, not `CYDesignedCover`. The refused state is a `ContentUnavailableView` with an `actions:` `.bordered` 返回. The beta badge was already tinted `Text`. `test_topic_session_selection.py` was updated. |
| R10-PC-B-N3 | fixed | 152978ee4 (+ base) | same | The last `CYPillButton` (refused 返回) is gone. `scrollContentBackground(.hidden)` / `bgPage` were already gone. |
| R10-PC-B-N4 | fixed on base | — | `App/TopicXcxSections.swift:27-62` | The tabs are a segmented `Picker`. The pinned copy on `.bar` keeps the MP sticky tabs. |
| R10-PC-B-N5 | fixed | a64d9f6bf (+ base) | `App/TopicXcxSections.swift:222-252` | The lineup is one list row per member, as a `NavigationLink` when it opens (it was a horizontal card strip). Chips and the stat bar were already plain. `CYAvatarView` is a plain image. |
| R10-PC-B-N6 | fixed | 120e4cfe7 | `App/TopicXcxSections.swift:319-385, 391-412` | The bar is a `Divider` plus content on `.background(.bar)` inside the host's `.safeAreaInset(edge: .bottom)`, with no `CYFooterBar`. `TopicBarHeroSource` / `TopicBarHeroDestination` are pass-throughs (no `cyHeroSource` morph or corner clip). `TopicBarRecede` was already a pass-through. The chrome contract test was updated. |
| R10-PC-B-N7 | fixed | 120e4cfe7 (+ base) | `App/TopicXcxSections.swift:~625` | The stop image uses `.clipped()`, with no corner clip. The night-palette chip and the drawn circle were already gone; the number is an SF Symbol. |
| R10-PC-B-N8 | fixed | 7e630d97f | `App/MPGap/PlayerContent/TopicRouteMapAndTeamsSection.swift:58-80` | Pins are `Marker(monogram:)`, tinted green when done, selected through `Map(selection:)` and then `onSelectPin`. The map has no clip. The topic host (`App/TopicXcxSections.swift:556`) passes no `teams` or `merchantCards`, so no team card renders on this page. The row-ifying of those blocks waits for the R7-PC-B1-6 merchant-card hand-off (content-a, partly). |
| R10-PC-B-N9 | blocked (device pass) | — | `App/MerchantContentViews.swift:107` | See the note below. |
| R10-PC-B-N10 | blocked (device pass) | — | `App/MerchantContentViews.swift:285-305, 514-531` | `CYEmptyState` → `ContentUnavailableView` is already on base. The row style stays until N9 lands; without a `List` the links would become bare text. |
| R10-PC-B-N11 | fixed on base | b1e2db839 | `App/MerchantContentViews.swift:215, 609` | `.confirmationDialog`; `.borderedProminent` |
| R10-PC-B-N12 | fixed on base | 81e15fa3d | `App/MPGap/PlayerContent/PlayerContentRound4Views.swift:118-130` | |
| R10-PC-B-N13 | fixed on base | — | `App/PublisherLifecycleViews.swift:56-66, 99, 165` | `ContentUnavailableView`, `.bordered` / `.borderedProminent` |
| R10-PC-B-N14 | fixed on base | — | `App/PublisherLifecycleViews.swift:399-405` | `ProgressView`, `.bordered`, no fixed `minHeight` |

**N9/N10 note:** I tried this and reverted it. Turning `MerchantContentDocumentView` into a `List` makes each record (`MerchantContentRows`) and the project block (`MerchantContentProjectView`) one row that holds several `NavigationLink`s and `Button`s. In a SwiftUI `List`, one tap on such a row fires every link in it. Doing this safely means splitting each action into its own row. That needs a simulator check, and there is none in the cloud.
