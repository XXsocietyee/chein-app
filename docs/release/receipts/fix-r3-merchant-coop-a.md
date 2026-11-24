# fix/r3-merchant-coop-a — receipt (Claude F-agent, merchant-coop half a)

- **Brief:** `origin/design/handoff-r2:docs/briefs/wave-x10.md`
- **Base:** `origin/ui/combined-r7`, with `origin/restyle/r3-merchant-creator` merged first, as the brief requires.
- **Layer:** App/ only. Two exceptions:
  - copy values in `Resources/MerchantOps.xcstrings`, plus the generator that writes them (`tools/build_merchant_ops_catalog.py`);
  - the strings fragment `docs/port/strings/fix-r3-merchant-coop-a.json`.
- **Half a:** the first 18 of the audit's 35 pages. These are audit Sections A and B, from `pages/merchant/index` through `pages/merchant/predict`. Half b covers decor, citynode, game-node, coop-center, relation, team and `pages/coop/*`.
- **Gap sources:** I used all of these:
  - the r7 fix queue `origin/audit/parity-r7-merchant-coop:docs/audit/parity-r7/merchant-coop.md`, with ids MC7-01-* to MC7-18-*;
  - the round-1 audit;
  - `review/r7-rev-{a,b,c}`. Their only merchant finding is B-19, a Core public-review hook, so not in this layer.
- **No compiler here.** Every API called was grepped on the branch first. The coordinator compiles the branch.

## New Swift files (all in `App/`, already matched by the `App/*.swift` glob, so no generator change)

| File | What |
|---|---|
| `MerchantGateStates.swift` | Shared MP full-page states, all as `ContentUnavailableView`:<br>• `MerchantSignInState`: 登录…, then 登录, which opens `LoginView(intent: .merchant)`.<br>• `MerchantDeniedState`: 当前身份不能…, then 申请入驻 when access/me has no active merchant, or 返回 otherwise (MP onDenyCta).<br>• `MerchantLoadFailedState`: page title, server reason, 重新加载.<br>• `MerchantMissingParamState`: 缺少…, then 返回上一页.<br>It also adds `merchantGateActions` to the environment, injected in `QuestifyApp.chain3_3`. |
| `MerchantBusinessPageGate.swift` | Page-specific gate for `MerchantBusinessPage`. When the first read fails, it maps denied / sign-in / not-found / load-failed onto each MP page's copy. |
| `MerchantApplyTimeline.swift` | 审核进度 timeline (status and submitted variants) and the 店铺地址 row that opens Apple Maps. |
| `MerchantLedgerRedemptionsSection.swift` | The 账本 核销 segment. It reuses `.redemptions(filter:page:)` and has append paging. It also adds the `merchantCoopProfitDestination` environment key. |
| `MerchantCampaignHistoryView.swift` | 触达记录 page, its detail sheet, and a standalone host. |
| `MerchantReviewAuthorLine.swift` | Review author line: avatar, nickname, time and 平台复审中. |

## Fixed (id → files)

| id | What changed | Files |
|---|---|---|
| MC7-01-4 | 更多 › 管理优惠券 for `merchant:coupon:manage` | MerchantHomeView |
| MC7-01-5 | Header store avatar (44 pt) pushes 品牌中心 for `profile:write` | MerchantHomeView |
| MC7-02-1 | Signed out: 登录后申请商家入驻 + 登录 | MerchantOnboardingView, MerchantGateStates |
| MC7-02-5 | Submitted result: 你的申请已提交, then receipt rows, then the 4-step timeline, then 返回首页. The status card gains 联系电话 / 店铺地址 and the 3-step timeline. | MerchantOnboardingView, MerchantApplyTimeline |
| MC7-02-6 | Status address row opens Maps (geocoded query) | MerchantApplyTimeline |
| MC7-03-2 | `pages/merchant/profile/index?id=` → `PublicMerchantHomeView(.legacyMerchantRowID)`. `poiId`, or neither id, goes to the invalid state. | MPReviewedPageScreen |
| MC7-04-1 | Verify-records denied → 当前身份不能查看核销记录 + 申请入驻/返回 | MerchantBusinessPageGate, MerchantBusinessViews |
| MC7-04-3 | 已经到底了 footer once every record is loaded | MerchantVerifyRecordsSections |
| MC7-05-1 | Bundle-reservations denied → ContentUnavailableView + 申请入驻/返回 | MerchantBundleReservationsView |
| MC7-06-2 | Ledger denied → 当前身份不能查看这份商家账本 page | MerchantLedgerSettlementOverview |
| MC7-06-3 | 合作分润 row (finance roles) at the top of 核销 → CoopFinanceProfitView | MerchantLedgerRedemptionsSection, QuestifyApp |
| MC7-06-6 | 去我的资产 (MerchantLedgerAssetsEntry) under the overview hero | MerchantLedgerSettlementOverview |
| MC7-06-11 | The 核销 segment renders the redemption ledger: filter (finance), summary strip, rows that open their detail when a journal is passed, and 正在加载更多… / 已经到底了. 收入明细 moved under 结算 with the batches. | MerchantLedgerSettlementOverview, MerchantLedgerRedemptionsSection, MerchantHomeView, SubscribeMessageTapScreens |
| MC7-06-5 (part) | Append paging for the 核销 list. The 结算 entries/batches pager is unchanged (Core slot model). | MerchantLedgerRedemptionsSection |
| MC7-07-3 | Order detail: a missing or not-visible record → 核销记录不可见 + 返回核销列表. Other failures → 核销详情加载失败. | MerchantBusinessPageGate, MerchantBusinessViews |
| MC7-08-1 | 打款日期 under the batch hero (paid only) | MerchantLedgerSettlementOverview |
| MC7-08-3 (+08-2) | Labelled 打款进度 timeline via the existing `MerchantSettlementProgressView`, which also brings 复制打款凭证. The bare stamps on the statement card are hidden there. | MerchantLedgerSettlementOverview, MerchantLedgerParityViews |
| MC7-08-5 (part) | `pages/merchant/ledger/batch-detail/index?batchId=` screen. A missing id → 缺少结算批次信息 + 返回上一页. | MPReviewedPageScreen, MerchantGateStates |
| MC7-09-1 | Payout account: access/me inactive or without `finance:read` → 当前身份不能查看收款账户 + 申请入驻/返回 | MerchantPayoutAccountView |
| MC7-10-1 | Marketing signed out → 登录后查看营销 + 登录 (picker hidden) | MerchantMarketingView |
| MC7-10-2 | Not-member marketing tab → 当前身份不能查看营销 + 申请入驻 | HomeSearchTabParityViews |
| MC7-10-3 | Entry error → 商家营销加载失败 + server message + 重新加载 | MerchantMarketingView |
| MC7-10-5 | All-zero 还没有主题和活动 sits in place of the 我的内容 tiles, not above the hero | MerchantMarketingHomeSections |
| MC7-11-4 | Recommended topic → medium sheet: reason and host, 先不用, 去申请承接 (the existing recruiting route) | MerchantInsightRecommendationRows |
| MC7-11-5 | 店铺参谋 segment hidden unless `canReadMarketing` | MerchantMarketingView |
| MC7-11-6 | Insight full-page states: 请先登录 / 当前身份不能查看店铺数据 / 店铺数据加载失败 | MerchantMarketingView |
| MC7-11-8 | Unknown facts → 店铺数据没加载完整 + 重新加载 | MerchantInsightAttributionSummary, MerchantMarketingView |
| MC7-11-9 | 生成时间 row → footer 解读依据 {date} 的经营数据与当时的档案；今天修改的档案次日生效 | MerchantMarketingView |
| MC7-11-10 | No `ai` → the whole 经营解读 section is hidden. Suggestions move to their own section. | MerchantMarketingView |
| MC7-12-2..12-9 | 触达记录 page (workbench 更多, `crm:read`). It has:<br>• rows of time · channel · status chip and 送达 N / M 人;<br>• the footer 仅显示最近 20 条;<br>• `.refreshable` that keeps the list and toasts 刷新失败，稍后再试;<br>• denied / load-failed / empty states;<br>• a detail sheet titled with the campaign, with its own loading and 触达明细加载失败 + 重新加载, exactly five counts, and 这次触达没有逐人结果. | MerchantCampaignHistoryView, MerchantHomeView |
| MC7-13-4 | Reviews: 当前身份不能管理口碑 / 登录后查看口碑管理 pages (replaces the CloseW5d denied row) | MerchantBusinessPageGate, MerchantBusinessViews |
| MC7-13-5 | Reviews empty → 还没有真实到店评价 | MerchantBusinessViews |
| MC7-13-6 | Review header numbers no longer repeat in the generic summary rows | MerchantBusinessViews |
| MC7-13-7 (part) | Author line: avatar with 城 fallback, nickname, time, 平台复审中 | MerchantReviewAuthorLine, MerchantBusinessViews |
| MC7-13-8 | Reply recovery: 复制原请求号 (local-only pasteboard, 120 s) and 联系平台客服 (ParticipationSupportView) | MerchantReviewReplyRecoveryView |
| MC7-13-9 | Developer notice above the review list removed. Write gating stays in the confirm sheet. | MerchantBusinessViews |
| MC7-14-8 | Customers denied → full page (search and filters hidden) + 申请入驻/返回 | MerchantBusinessPageGate |
| MC7-14-9 | Free-text 开始/结束 date fields removed; only the range picker is left | MerchantBusinessViews |
| MC7-14-10 | Refresh with rows: rows stay, plus an inline 正在更新客户名单… | MerchantBusinessViews |
| MC7-14-11 | 44 pt customer avatar with initial fallback | MerchantCustomerListParityViews, MerchantBusinessViews |
| MC7-15-3 | 找不到这位客户 (404) / 当前身份不能查看客户, with 返回客户列表 / 返回 | MerchantBusinessPageGate |
| MC7-15-4 | Customer avatar beside the name | MerchantCustomerDetailSections |
| MC7-15-5 | Customer detail error → 客户详情加载失败 + reason + 重新加载 | MerchantBusinessPageGate |
| MC7-15-6 (part) | Dropped the 无法确定最新备注… line | MerchantCustomerDetailSections |
| MC7-16-1 | Aftercare denied → 当前身份不能查看退款售后 + 申请入驻/返回 | MerchantBusinessPageGate |
| MC7-16-2 | While more pages exist: 只在已加载的 N 笔中搜索 + 加载更多. No matches → 没有找到 + 清除搜索. | MerchantBusinessViews |
| MC7-16-3 | The next page loads when the 正在加载更多… row appears (manual button removed) | MerchantBusinessViews |
| MC7-16-4 | 已经到底了 when there are no more pages | MerchantBusinessViews |
| MC7-17-2 | Refund detail denied → same page as 16-1 | MerchantBusinessPageGate |
| MC7-18-2 | Prediction inbox signed out → 登录后查看预测 + 登录 | MerchantPredictionInboxView |
| MC7-18-3 | 竞猜 → 预测 copy: 当前身份不能公布预测答案 / 没有等你给答案的预测 / 有 N 轮预测待给答案 | Resources/MerchantOps.xcstrings, tools/build_merchant_ops_catalog.py |
| MC7-18-4 | 营销 no longer shows its own 预测 segment where the inbox entry exists. A dashboard row opens the one inbox. | MerchantMarketingView |

The strings are in `docs/port/strings/fix-r3-merchant-coop-a.json` (91 keys, zh-Hans + en).

## Left open (with reasons)

### Needs Core (requests for Cursor `cursor/core-merchant-coop`)

- **MC7-04-3 paging:** `.verificationRecords` has no page (it reads 50 rows once). Add `page` so the view can append and show 正在加载更多….
- **MC7-06-5 (结算 part):** `MerchantLedgerReadSlot` replaces its snapshot per page. Append-on-scroll for entries/batches needs an accumulating slot.
- **MC7-06-9:** 收入明细 COOP_SHARE rows open `pages/coop/settlement-detail?source=ledger&id=refId`. `CoopFlowSettlement.Source` has no `.ledger` case (MC7-35-1 adds club sources). After that, wrap `MerchantLedgerRowLabel` in a `NavigationLink` when `refKind == coop_settlement`.
- **MC7-08-5:** `MiniProgramPageLink` must accept `batchId` on `pages/merchant/ledger/batch-detail/index`. The screen case is in place. The orphan `MerchantSettlementBatchDetailView` / `MerchantSettlementOverviewView` deletion is left to the integrator, because there is no compiler here to prove nothing else references them.
- **MC7-03-2:** `MiniProgramPageLink` must accept `id` / `poiId` on `pages/merchant/profile/index` (MC7-03-1). The screen case is in place.
- **MC7-12-1:** `.campaigns` / `.campaign(id)` reads require `marketing:write` in `MerchantEngagementContracts.swift:123`. The MP reads them with `MARKETING_READ`. Once Core relaxes this, also widen the `marketing:write` gate in `MerchantEngagementViewModel.load()`. The new page is already reachable for `crm:read`.
- **MC7-13-3:** this depends on MC7-13-2 (server `filter` on `.reviews` and `filterCounts`).
- **MC7-14-7:** customers need a loaded-pages accumulator like `MerchantAftercareLoadedPages` / review pages before the pager can become append-on-scroll.
- **MC7-17-3:** `MerchantAftercareProgress` evidence is a status enum with no URLs. Previewing evidence needs the URLs plus the retained image reader.

### Blocked by hash- or line-pinned contract tests (Cursor to re-pin, then a small follow-up)

- **MC7-13-7 (drop `version` from review fields):** the field list lives in `App/MerchantBusinessRecordViews.swift`, whose whole-file SHA-256 is pinned by `test_merchant_customer_contact.py` and `test_merchant_station_submission_import.py`.
- **MC7-12-2 (link from the engagement home), MC7-12-3:** `App/MerchantEngagementViews.swift` is hash-pinned (`test_merchant_station_submission_import.py`). The new page is linked from the workbench 更多 list instead.
- **MC7-17-4:** this needs the response editor in `App/MerchantBusinessEditor.swift` (pinned by about 20 tests) to lock to the tapped decision.
- **MC7-15-6 (refund boundary line):** `test_merchant_customer_detail.py` requires `merchant.customerDetail.refundTimeBoundary` under `if latest.kind == .refunded`.
- **One call site kept unchanged:** the `MerchantBusinessHomeView` 账本 call site passes no journal, because `test_merchant_settlement_overview.py` pins that line. From that entry the 核销 rows are read-only. Every other entry passes the journal.

### Deferred: larger native restructures (next pass)

- **MC7-14-1 / MC7-14-2 / MC7-14-5:** filter sheet with 我的分群 / 存为分群, and the toolbar 管理 menu. This rebuilds the customer filter block, which is under slice-pinned tests and coupled with the X6 write approvals.
- **MC7-14-6:** one-tap phone. It changes the reviewed two-step contact flow (privacy-sensitive), so I'd rather do it with a compiler loop.
- **MC7-15-2:** single 编辑标签与备注 sheet. Every write behind it ends in 提交暂不可用 until the X6 approval (owner MC7-15-1).

### Owner decisions (not code)

- MC7-01-1, MC7-01-6, MC7-06-7, MC7-10-4, MC7-12-10.
- X6 approvals: MC7-13-1, MC7-14-3, MC7-15-1, MC7-17-5.
- Prediction settlement on TEST: MC7-18-1.
- I did not hide the write buttons the owner rows mention. That is the owner's call, and the existing confirm-sheet gating is unchanged.

### Owned by other agents (skipped)

- **Gemini:** MC7-01-2, MC7-01-3, MC7-02-2, MC7-02-3, MC7-03-3, MC7-03-4, MC7-06-8, MC7-08-2 (the voucher copy is in place anyway, via the existing progress view), MC7-11-1, MC7-11-2, MC7-14-4, MC7-17-1.
- **MC7-11-7:** the hero number with 环比 comes from the MC-G07 dashboard, which is Gemini's to un-park.
- **Cursor:** MC7-02-4, MC7-03-1, MC7-06-1, MC7-06-4, MC7-06-10, MC7-07-1, MC7-07-2, MC7-11-3, MC7-13-2.
- **In-flight branches:** `restyle/r3-merchant-creator` (merged here as the base layer), `gap/g2-ops` (MPGap compile fixes only, untouched), `cursor/*` and `port/*` (no merchant pages).

## MP assets, native structure, accessibility

- **MP assets:** `cursor/mp-assets` does not exist yet, so there are no `MPAsset` accessors to adopt.
  - The new UI uses only system-control SF Symbols (lock, chevrons, checkmarks, map, paperplane) and `CYAvatarView` monograms.
  - Once the accessors land, these should switch to MP images:
    - the MP review star / check icons (`pages/merchant/images/merchant/reviews/*`);
    - the customer default avatar (`/images/d_profile.png`).
- **Native structure:** full-page states use `ContentUnavailableView`. The topic and campaign detail are `.sheet` with detents. The 账本 sections are `List`s and the timeline is a plain list section. No custom chrome was added.
- **Accessibility:**
  - every new action has a minimum height of `CYSpacing.minTouchTarget` (44 pt);
  - avatars are hidden from VoiceOver and their rows are `.combine`d;
  - the timeline rows read as one element;
  - all text uses semantic `cyText` styles (Dynamic Type).

## Verification (cloud, no compiler)

- **Contract checks:** `Tests/ContractChecks` and `tools/tests` modules that mention any changed file (121 modules) were run before and after.
  - The comparison baseline is the restyle merge `ac04442bf`.
  - There are no new failures, with one exception: `tools/tests/test_xcode_cloud_plans.py`, which expects `project.pbxproj` to match the generator. Six new Swift files were added, so the integrator must regenerate the project.
  - `check_public_merchant_home.py` fails identically before and after (it reads a path outside the repo).
- **Fixture routes:** `docs/port/accept/f-merchant-coop-a.txt`.
- **Acceptance run:** none yet. The coordinator compiles the branch and runs the acceptance workflow.

---

## Round 2 (2026-11-24)

- **Brief:** `origin/design/handoff-r2:docs/briefs/fix-r3-round2.md`, plus `wave-x10.md` and `owner-decisions-1124.md`.
- **Sync:** merged `origin/ui/combined-r7` at `97ee2bc9e`. The only conflict was `tools/check_typography_lint.py`, which I took from r7.
  - r7 did **not** yet contain Cursor's merchant Core or the MP assets, so I also merged `origin/cursor/mp-assets` (`05d527e12`) and `origin/cursor/core-merchant-coop` (`c9cbcd24b`).
  - `tools/generate_project.py` conflict: I kept both the `App/MPGap/**` and the `App/MPAssets/*` globs.
  - I merged r7 again before the final push (`82388e4a5`, then `aee32a61f`, a Swift 6 annotation fix in Core; together they integrate Cursor W1, C7 and K1–K10). It merged cleanly, and I re-grepped every Core and MPAsset API used here.
- **Review findings:** `review/r7-rev-a`, `-b` and `-c` have **no** Claude-owned rows for merchant-coop. The Claude rows are B-02…B-16 (topic, IM, ticket wallet, club), which belong to other areas, so nothing changed here.
- **Cursor wiring call sites:** `cursor-core-merchant-coop.md` lists no `cursor/wire-merchant-coop` call sites. I followed its "For the Claude F-agent (App)" list instead.

### Fixed in round 2

| id | What changed | Files |
|---|---|---|
| MC7-07-1 / MC7-07-2 | `pages/merchant/ledger/order-detail/index?recordType=&recordId=` opens that ledger record. `activity_ticket` and `session_fee` keep their typed key (`MerchantOrderDetailLink.record` → `.redemption(recordID:)`). A missing pair shows 缺少核销记录信息 + 返回上一页. | MPReviewedPageScreen |
| MC7-07-3 (+) | Order-detail "missing record" also matches 记录不存在 / 记录不可见 messages, via Core `MerchantFinanceDetailLoad.isMissingRecord`. | MerchantBusinessPageGate |
| MC7-08-4 | A batch that is 404 or 记录不存在/不可见 shows 这条结算批次不存在或已不可见 + 返回结算列表 (pops), not the generic retry. | MerchantLedgerSettlementOverview |
| MC7-04-2 / MC7-04-3 | Verify records now append:<br>• the first page is Core's 50-row `.verificationRecords` (`hasMore` from `MerchantVerificationRecordPage`);<br>• later rows come from the existing 20-row `.redemptions(filter:"all", page:)` read (same endpoint and permission), starting at the overlapping page and de-duplicated by `recordKey`;<br>• 正在加载更多… loads when it appears; a failure turns it into 重新加载; 已经到底了 shows once every row is loaded. | MerchantVerifyRecordsSections, MerchantBusinessViews |
| MC7-11-3 | 到店时段 reads `facts.checkin.slotBuckets` through Core `MerchantInsightSlots`: four bars (peak highlighted), percentages, and the footer 共 N 次打卡 · {peak}到店最多. The old `hourBuckets` rows are gone. | MerchantInsightSlotsSection (new), MerchantMarketingView |
| MC7-13-3 (part) | Review tab labels show the server `filterCounts` (`reviewFilterCounts`) when present. Unknown counts keep the bare label. | MerchantBusinessViews |
| MC7-06-1 (App part) | `pages/merchant/ledger/index?view=settlement` (or `tab=2/3`) opens the 账本 on its 结算 segment (`MPParityRoute.merchantLedgerSettlement`). The bare path is unchanged (`.merchantLedger`, so the AppUnit test still holds). | MPParityKit, SubscribeMessageTapScreens |
| Owner #9 | The refund hero and the customer 累计消费 amounts now show `¥12.50` through the shared `MoneyDisplay` switch, instead of `CNY 12.5`. The other merchant money (ledger, aftercare list, orders) already used two-decimal `¥` formatters. | MerchantMoneyText (new), MerchantAftercareProgressView, MerchantCustomerDetailSections |

### MP assets applied (`MPAsset.*`; rows from `docs/mp-assets/mapping.md`)

- [x] `FeatureIcon.iconCalendar`: workbench 更多 › 核销记录 (index.wxml:292). Replaces `checkmark.seal`.
- [x] `FeatureIcon.iconShop`: 更多 › 品牌中心 (index.wxml:316). Replaces `slider.horizontal.3`.
- [x] `Other.navMsg`: 更多 › 协作邀请 (index.wxml:283). Replaces `envelope.badge.person.crop`.
- [x] `FeatureIcon.iconStarFilled` / `iconStarMuted`: review header stars (reviews/index.wxml:42). Replaces `star.fill` / `star`.
- [x] `FeatureIcon.iconBubble` / `iconPlus` / `iconCheckBlue` / `iconStarOutline`: the four manage metric cards (reviews/index.wxml:50-75).
- [x] `FeatureIcon.iconStarSmall` / `iconStarMuted`: per-review stars (reviews/index.wxml:160). Replaces the `★ n/5` text.
- [x] `FeatureIcon.iconCheckGreen`: 核销已验证 (reviews/index.wxml:155). Replaces `checkmark.seal`.
- [x] `AvatarDefault.dProfile`: default avatar on the customer list and customer detail (customer/index.wxml:71, detail:29), via the new `MerchantMPAvatar`. Review authors keep the 城 monogram, as in the MP (reviews/index.wxml:149).
- [x] `BannerCover.merchantCoopBanner`: the marketing coop entry (marketing/index.wxml:135).
- [x] `FeatureIcon.check` + the tag icons (`baby` … `wine`, all 33): the apply 行业类型 sheet (apply/index.wxml:308 `cy-tag-sheet`). They use the `tag-library.js` merchant presets, then the keyword rules (`MerchantTagIcons`). Unmapped labels stay text-only, as in the MP.
- [ ] `FeatureIcon.iconCopy` (customer 复制电话): the copy control is in `App/MerchantBusinessRecordViews.swift`, which is whole-file SHA-pinned (see round 1). Cursor needs to re-pin it first.
- [ ] `FeatureIcon.iconSend` (reply send): the reply editor is in `App/MerchantBusinessEditor.swift`, which is pinned by about 20 tests.
- [ ] `BannerCover.flavorTour` / `midlifeDay` / `oldMovie` / `treasureHunter` (insight 经营优化 cards): these live only in `App/MPGap/MerchantCoop/MerchantGapAIInsightViews.swift`, which is Gemini's (`gap/g2-ops`) and parked. I skipped it.
- System-control glyphs stay SF Symbols, per the mapping: `ellipsis`, chevrons, `circle` (unselected), `lock`, `doc.on.doc` on non-MP rows, and the gate-state symbols.

New helper files: `MerchantMPIcon.swift` (`MerchantMPIcon`, Dynamic-Type scaled and decorative; `MerchantMPAvatar`) and `MerchantTagIcons.swift`.

### Still open after round 2 (requests for Cursor)

- **MC7-13-3 (server tabs):** `MerchantBusinessReading.snapshot` only takes a `MerchantBusinessQuery`, and `.reviews(page:)` always sends `filter=all`.
  - Selecting 待回复/低分/有图/平台复审 therefore still filters the loaded page locally.
  - **Request:** a `.reviews(filter:page:)` query case (or a reader method for `MerchantReviewManageRead`), plus a `platform` case on `MerchantReviewFilter`.
- **MC7-06-10:** the same limit. `MerchantFinanceRedemptionList(topicID:)` cannot be sent through the reader, because `.redemptions` has no `topicId`.
  - **Request:** `.redemptions(filter:page:topicID:)`. After that, the App opens a 台账-titled list for `view=redemptions&topicId=`.
- **MC7-04-2:** works now through `.redemptions` paging (see above). A `.verificationRecords(page:)` case would remove the overlap and de-duplication step.
- **MC7-06-9:** `CoopFlowSettlement.Source` still has no `.ledger` case. `MerchantSettlementDetailLink.Source.ledger` exists, but `CoopSettlementDetailView` cannot read it.
- **MC7-08-5 / batch link:** `pages/merchant/ledger/batch-detail/index` is still in the no-query list in `MiniProgramPageLink`, so `?batchId=` is rejected before the screen case runs.
- **MC7-12-1:** campaign reads still require `marketing:write`.
- **MC7-01-7:** `MerchantDeskManualCodeClient` exists, gated off. I did not add a 手输码 row: the gate is default-off and new gates stay off, so the row would never show. It is ready to add once the owner turns the gate on.
- Unchanged from round 1: MC7-14-7, MC7-17-3, the hash-pinned files (MC7-13-7 `version`, MC7-12-2/3, MC7-17-4, MC7-15-6), the deferred restructures (MC7-14-1/2/5/6, MC7-15-2), and the owner and X6 rows.

### Owner decisions check (`owner-decisions-1124.md`)

- **#9 two decimals:** applied (above). `MoneyDisplay.current` stays `.twoDecimals`.
- **#3, #6, #12 money:** nothing in this half writes money. Refund decisions keep the existing X6 confirm gating, and the payout account stays read-only.
- **#5 merchant approvals:** the approve/reject screens are the existing permission-checked confirm sheets. No new write path.
- **#7, #8, #10** (cast, GPS arrival lock, game-kit pilot gate): not in this half's pages.
- **New gates:** none added.

### Verification (round 2, cloud, no compiler)

- I ran the 49 contract modules that mention any round-2 file, before and after (baseline: the merge commit, in a worktree). There are **no new failures**: the failing set is identical before and after, and every failure is pre-existing.
- `test_category_roam_registration` (its frozen SHA history of `Localizable.xcstrings`) fails on the baseline as well.
- **For the integrator:**
  - new Swift files: `MerchantInsightSlotsSection`, `MerchantMPIcon`, `MerchantMoneyText`, `MerchantTagIcons`. They are all matched by `App/*.swift`, so regenerate `project.pbxproj`.
  - `MerchantInsightSlots.peakText` is Chinese from Core (早上到店最多), so the English footer shows it as given.
- **Repo gates vs. r7 (`tools/check_*.py`, all 85):** three differ from r7, and all three are expected until integration.
  - `check_catalog_coverage`, `check_missing_string_keys` and the strings assertion in `check_scaffold` need the fragment keys merged into `Localizable.xcstrings`.
  - `check_scaffold`'s project assertion needs `project.pbxproj` regenerated. I ran `tools/generate_project.py` locally and that assertion then passed, but I did not commit the result, to avoid pbxproj conflicts across branches.
  - `check_a11y_lint` was failing with 8 new findings. These were the decorative glyphs the restyle merge had re-lined. They are now `.accessibilityHidden(true)`, and the lint passes. `check_typography_lint` passes.
- **Strings:** 7 new keys in `docs/port/strings/fix-r3-merchant-coop-a.json` (98 keys, en + zh-Hans).
- **Fixture routes:** unchanged (`docs/port/accept/f-merchant-coop-a.txt`). `merchant-home`, `t12-reviews`, `t12-marketing`, `merchant-customers` and `t12-ledger-batches` cover the round-2 changes.

---

## Round 3 (2026-11-24 evening)

- **Brief:** `origin/design/handoff-r2:docs/briefs/fix-r3-round3.md`, plus `wave-x10.md`, `fix-r3-round2.md` and `owner-decisions-1124.md`.
- **Sync:** `git merge origin/ui/combined-r7` at `b0ac0108d` fast-forwarded (my round 2 was already integrated there). I merged r7 again before the final push.
- **No compiler here.** Every API used below was grepped on the new base first. No new type name collides with App/ or Core/.

### Round 3 · re-applied

I diffed each round-2 commit (`1617b471c`, `08afe8867`, `be3f55013`) against the new base, line by line. Everything survived except the hunks below. Each was re-applied on top of Cursor's wiring, not as a second implementation.

| Round-2 hunk | State on b0ac0108d | Re-applied as |
|---|---|---|
| MC7-04-2 / 04-3 verify-records pager (`MerchantVerifyRecordsPager` over `.redemptions`) | Replaced by Cursor's `MerchantVerificationAppendList` (`reader.verificationPage`). Its failures set `stopped`, so the footer vanished: no 重新加载 and no 已经到底了. | On Cursor's list: a failed page shows 重新加载 (retry), cancellation is ignored, and `hasMore == false` shows 已经到底了 even when `total` disagrees. The 正在加载更多… row re-asks after each page through `.task(id: records.count)` (`onAppear` fired only once). `MerchantVerifyRecordsSections` gains `loadFailed` / `onRetry` / `exhausted`. |
| MC7-06-1 `pages/merchant/ledger/index?view=settlement` → `.merchantLedgerSettlement` | The `MPParityRoute` case survived, but Cursor's `topicID` branch dropped the `view` check, so the case was unreachable. | Inside Cursor's no-topic `else` branch (`MPParityKit.swift`). |
| MC7-11-3 slot bars | Both mine (`MerchantInsightSlotsSection`) and a second inline copy inside 经营数据 were rendered. | Removed the inline duplicate. The one section remains. |
| `MPReviewedPageScreen` order-detail | The merge left two `case "pages/merchant/ledger/order-detail/index"`. Only the first (Cursor's `record.recordKey`) can match. | Deleted the dead second case. |

### Fixed in round 3

| id | What changed | Files |
|---|---|---|
| flows-g2 MISSING-ROUTE (half a) | These bare MP links now open the workbench's native screens instead of 该页面暂未开放:<br>• `pages/merchant/aftercare/index` → `.aftercare(.pending, page: 1)`;<br>• `aftercare/detail/index` lands on the list (MP `onLoad` redirects without a valid id; the link rule admits no query yet);<br>• `reviews/index` → `.reviews(page: 1)`;<br>• `customer/index` → `.customers`;<br>• `crm-campaigns/index` → `MerchantCampaignHistoryHost`;<br>• `marketing/index` and `marketing/ai-insight/index` (`.insight`) → `MerchantMarketingView` with the 营销 tab's links;<br>• `predict/index` → the prediction inbox, or 登录后查看预测 + 登录 when there is no reader. | MPReviewedPageScreen, MerchantMPLinkScreens (new) |
| MC7-06-9 | 收入明细 rows open `pages/coop/settlement-detail/index?source=ledger&id=refId` (Cursor's `CoopSettlementDetailRoute`, ledger → mybiz). This happens only for the MP rule: `COOP_SHARE` + `coop_settlement`, payee merchant/club/unset, and a positive safe-integer `refId`. Other rows stay plain. | MerchantLedgerSettlementOverview, MerchantLedgerRedemptionsSection (`MerchantLedgerCoopDetail`, env key), QuestifyApp (`chain3_3`) |
| MC7-06-5 (结算 part) | 收入明细 and 结算批次 append on scroll:<br>• 正在加载更多… while loading;<br>• 重新加载 on a failed page, with the loaded rows kept;<br>• 已经到底了 at the end.<br>The 上一页 / 下一页 pager is gone. The App model accumulates rows by id, page 1 replaces them, and an owner change clears them. A popped batch cover reloads from page 1. Core `MerchantLedgerReadSlot` is unchanged. | MerchantLedgerSettlementOverview |
| Strings | `docs/port/strings/fix-r3-merchant-coop-a.json` is now xcstrings-shaped (`sourceLanguage` / `strings` / `localizations`): 98 keys, en + zh-Hans. No new keys this round. The new UI reuses `merchant.gate.reload`, `merchant.list.loadingMore`, `merchant.list.end` and `merchant.predict.signIn`. | fragment |

New Swift file: `App/MerchantMPLinkScreens.swift` (`SessionMerchantMarketingLinkScreen`, `SessionMerchantPredictionLinkScreen`). It is matched by `App/*.swift`, so the integrator needs to regenerate `project.pbxproj`.

### Checked, nothing to do

- **Review findings:** `review/r7-rev-{a,b,c}` are unchanged since round 2. There are still no Claude rows for merchant-coop.
- **Audit:** every MC7-01-* … MC7-18-* row is accounted for in this receipt (script check against `parity-r7-merchant-coop`).
- **MP assets (`docs/mp-assets/mapping.md`):** every half-a row is applied except `iconCopy` and `iconSend`. Those files are still SHA-pinned (`test_merchant_customer_contact.py` and others for `MerchantBusinessRecordViews.swift`; about 20 tests for `MerchantBusinessEditor.swift`). The new mapping rows (template-detail shelf tabs, leaderboard memojis, member-journey icons) are not on merchant pages.
- **Now done by Cursor's wiring (no App work left):**
  - MC7-13-3 server review tabs (pending/low/photo);
  - MC7-06-10 ledger `topicId`;
  - MC7-04-2 `verificationPage`;
  - MC7-07-1/2 typed order-detail;
  - MC7-08-4 batch missing copy.

### Still open after round 3

**Requests for Cursor (Core):**

- **`MiniProgramPageLink`:**
  - `pages/merchant/ledger/batch-detail/index` (MC7-08-5) and `aftercare/detail/index` (`refundId` / `manualCaseId` / `recordType`) are still in the no-query list, so their screens only ever see bare links;
  - `reviews/index?mode=manage` (decor link) is rejected for the same reason;
  - `pages/merchant/bundle-reservations/index` is not a reviewed page at all, so the flows-g2 row from merchant home stays unroutable as a deep link. In-app it is the workbench 更多 row.
- **MC7-03-2 `poiId`:** `MerchantPublicHomeLink.poi` exists, but `PublicMerchantHomeTarget` has no POI case. `poiId` stays on the invalid state (MC-G03, Gemini).
- **MC7-13-3 platform tab:** `MerchantReviewFilter` has no `platform` case, so the 平台复审 segment is still missing.
- **MC7-12-1:** campaign reads still require `marketing:write`.
- **MC7-14-7:** customers need a loaded-pages accumulator (`MerchantBusinessViews` customer block is under slice-pinned tests).
- **MC7-17-3:** aftercare evidence has no URLs.

**Re-pin requests:** unchanged from round 1 (MC7-13-7 `version`, MC7-12-2/3, MC7-17-4, MC7-15-6, `iconCopy`, `iconSend`).

**Left for a reason:**

- **flows-g2 `customer/index.js:1017` → 触达记录 row on the customer page:** the MP shows it only when a probe finds at least one campaign (owner decision B, 2026-11-22). That probe is the `.campaigns` read, which still needs `marketing:write` in Core (MC7-12-1). Adding the row without the probe would break the owner rule. The page stays reachable from the workbench 更多 › 触达记录.
- **Owner rows and X6 rows:** unchanged.
- **Duplicate `case "pages/coop/settlement-detail/index"` in `MPReviewedPageScreen`:** this is coop (half b) and dead code, not a compile error (string patterns). I left it for half b or the integrator.

### Verification (round 3)

- `test_appsec_review`, `test_merchant_settlement_overview` and `test_global_chrome_domain_contract` pass.
- The `test_merchant_insight_*` modules and `check_merchant_marketing` fail identically before and after (stash comparison): `check_merchant_marketing` fails on the base too.
- `check_typography_lint` passes.
- `check_a11y_lint` fails on the base, with no new merchant findings from this branch. The only merchant hit is Gemini's parked `MPGap/MerchantCoop/MerchantGapAIInsightViews.swift:146`.
- **Fixture routes:** unchanged (`docs/port/accept/f-merchant-coop-a.txt`). `cur9-ledger` and `t12-ledger-batches` cover the 结算 paging, and `t12-aftercare`, `t12-reviews`, `t12-marketing` and `merchant-customers` cover the deep-linked screens.
