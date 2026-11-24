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
