# Receipt — fix parity r2, merchant-coop

Brief: `origin/design/handoff-r2:docs/briefs/fix-parity-r2.md` · Findings: `origin/audit/parity-merchant-coop:docs/audit/parity/merchant-coop.md`
Round 1: `docs/release/receipts/fix-parity-merchant-coop.md` · Branch: `fix/parity2-merchant-coop` from `origin/ui/combined-r5` (rebased; no newer base commits at the time of writing).

Finding ids follow the round-1 receipt: `<page>-P1 (<short name>)` in the audit's row order, `batch-<A–D>-<n>` for fix-plan items, `X0`–`X6` for cross-page.

Swift is not installed in the cloud: nothing here was compiled. Code follows the patterns already in the same files.

## Gates (branch head)

| Gate | Result |
|---|---|
| `python3 -B tools/check_scaffold.py` | PASS (project regenerated with `tools/generate_project.py` for 2 new App/Core files) |
| `python3 -B tools/check_design_lint.py` | PASS; typography ratchet unchanged (raw text style 1173, back chevron 12, hidden back 7, large title 11) — no new raw fonts |
| `python3 -B tools/contract_ratchet.py --check` | 185 failing / baseline 184 / new 1 — identical to the base `ui/combined-r5` run (same single `test_workshop_paid_professional…bounded_paging`). Two byte-pinned files with real fixes re-pinned with a note (MerchantOperationsViews, CoopRelationDiscoveryView); chrome-only edits on pinned files reverted. |
| `python3 -B tools/report_chrome.py` | title-mode-unset 223 → 197; no hidden-back / custom back chevron left in merchant-coop files |
| `python3 -B tools/audit_client_ops_surfaces.py --check` | PASS (new 我的消息 read-mark store catalogued) |

## Fixed / partial

| Id | Status | Files | Local verification |
|---|---|---|---|
| merchant/index-P1 (我的消息 missing) | fixed (read marks local; see partial note) | Core/MerchantInboxPreview.swift (new), App/MerchantInboxPreviewSection.swift (new), App/MerchantHomeView.swift, App/QuestifyApp.swift, Core/MerchantContracts.swift, Core/MerchantAccess.swift, App/MerchantLedgerSettlementOverview.swift, Core/MerchantService.swift, Tests/CoreTests/MerchantInboxPreviewTests.swift, docs/ops-safety/client-data-catalog.json | TEST owner account with an IM conversation, a received coop invite and a recent 核销: 工作台 bottom shows 我的消息 with three rows, newest first (port of `pages/merchant/utils/inbox-preview.js`). Swipe a row → 标为已读 hides it; 清空 asks 全部标为已读？ then shows 都看完了; 全部 pushes the in-app inbox; an invite row opens invite detail (received); a 收入到账 event opens 账本 › 结算, a 核销 event 账本 › 核销. Proxy: POST `api/im/conversations`, POST `api/coop/list` (only with `merchant:coop:manage`), POST `api/merchant/events` now also for finance / verify-record roles (source `startInbox`). Before the first load settles the section keeps one empty row (never says 还没有消息 early). Core tests: `MerchantInboxPreviewTests`. |
| merchant/index-P1 (no CTA on signed-out / denied gates) | fixed | App/MerchantHomeView.swift, App/HomeSearchTabParityViews.swift | Merchant root signed out → 登录 under the empty state (returns to 我的); `merchant.access.denied` → 申请入驻 (`openApplication`); `auth.expired` → 登录. |
| merchant/index-P1 (营业 toggle is a push) | fixed | App/MerchantHomeView.swift | When `merchantOperationsReader.canSave`: tap 营业中 → confirm 暂停营业？ / 玩家会看到本店今日已打烊，到店仍可核销。 / 暂停营业 · 继续营业 → POST `api/merchant/business-status/update business_status=0` through the reviewed `saveReviewed` → re-read GET `api/merchant/business-status`; tap 已打烊 reopens without a confirm. Failure → toast, value read back. Without a save approval the chip keeps the editor push (unchanged). |
| merchant/index-P1 (duplicate refund / prediction rows) | fixed | App/MerchantHomeView.swift | 待办事项 no longer repeats 售后 / 预测 counts; MerchantWorkbenchReminders still shows them once. |
| merchant/index-P1 (copy: 重新检查经营身份 button) | fixed | App/MerchantHomeView.swift | Bottom 重新检查经营身份 button gone; pull to refresh reloads access. (竞猜→预测 was done in round 1.) |
| merchant/index-P2 (dead login modal / verify sheet; payout label; circle 56pt) | fixed | App/MerchantHomeView.swift | No code path to the removed states; 收款账户 row uses `payoutAccount.title` (PayoutReceiver); quick circles 60 pt. The toast state now reports a failed 营业 change. |
| apply-P1 (phone accepts any text) | fixed | Core/MerchantOnboardingContracts.swift, tests (Core + AppUnit phone fixtures) | Step 1 with 12345 → 请填写11位手机号; 13800000000 passes (MP `form-state` `^1[3-9]\d{9}$`). The old test that asserted "no phone regex" now asserts the MP rule. |
| apply-P1 (no inline 重新提交) | fixed | App/MerchantOnboardingView.swift | Force a server rejection on TEST: the rejection section shows 重新提交 → same reviewed confirm sheet. |
| apply-P1 (two titles) | fixed | App/MerchantOnboardingView.swift | Bar title 商家入驻申请; the form shows only the step headline (section-title style) + progress bar. |
| marketing-P1 (发活动 regressed to 接活动) | fixed | App/MerchantMarketingHomeSections.swift, App/MerchantMarketingView.swift, App/HomeSearchTabParityViews.swift, Resources/MerchantOps.xcstrings | 营销 tab: 发活动 shows only with `canManageProjects` and opens the 发布活动 form (`SessionActivityPublishingDestination`). |
| marketing-P1 (合作机会 opens the workbench) | fixed | same | 合作机会 row pushes the coop center (`merchantCoopCenterDestination(.plaza)`). Falls back to the old route only where no links are supplied (account-entry copy of the page). |
| marketing-P1 (tiles / 管理 / coupon deck inert) | fixed | same | 我的内容 tile with count > 0 → 我的项目 list; count 0 → create (主题 → content editor, 活动 → activity form); 管理 in the section header; coupon deck tap → 优惠券管理. All gated on `canManageProjects` except the deck. |
| marketing-P1 (3 tiles incl. 自由探索, M-10) | fixed | App/MerchantMarketingHomeSections.swift | Two tiles 主题 · 活动; 主题 = topicCount + freeExploreCount. |
| marketing-P1 (refresh wipes data) | fixed | Core/MerchantMarketingCoordinator.swift, App/MerchantMarketingView.swift | Pull to refresh on 经营 keeps the cards and shows 正在更新营销数据…; a transient failure keeps them with the error line; denied / signIn / unavailable / stale still clears. Existing Core tests (denied clears, session change clears) keep their meaning. |
| marketing-P2 (copy drift; mine number size) | fixed | Resources/MerchantOps.xcstrings, App/MerchantMarketingHomeSections.swift | 还没有主题和活动 / 你的岗位还不能查看营销数据 / 暂无报名; tile number `.display` 28 pt. Catalog edited in place: `tools/build_merchant_ops_catalog.py` is behind the merged catalog (regenerating drops ~20 merged keys), its four rows were updated to match. |
| relation-P1 (no inline retry) | fixed | App/CoopRelationDiscoveryView.swift, Tests/ContractChecks/test_coop_fixture_lifecycle_diagnostic.py (re-pin) | Force a read failure: 重新加载 under the error. |
| relation-P1 (guest copy / CTA) | partial | App/CoopRelationDiscoveryView.swift | Copy is 登录后查看发现; no 登录 / 申请入驻 button (no sign-in hook reaches this view). |
| decor-P1 (per-page error titles) | fixed | App/MerchantOperationsViews.swift, docs/merchant-operations-localizations.json, Tests/ContractChecks/test_merchant_station_submission_import.py (re-pin) | Fail a 品牌中心 / 相册 / 承接设置 read: title 品牌中心加载失败 / 相册加载失败 / 承接设置加载失败 above the reason and 重试. Inactive-identity empty state not changed. |
| decor-P1 (招牌主推 type / id; labels) | partial | App/MerchantOperationsEditor.swift, Resources/Localizable.xcstrings | Labels: 店铺名称, 品牌介绍, 一句话介绍, 特色标签, 店铺 Logo, 封面图, 招牌主推. A set featured pick shows 已选择主推 (MP fallback); the activity name lookup (MP `featuredName`) is not ported. |
| coop/finance-P1 (fake-zero screen when empty) | fixed | App/CoopFinanceProfitView.swift | Account with no settlements: only 还没有合作结算 + safety notice. |
| coop/finance-P1 (提现 as a row) | fixed | App/CoopFinanceProfitView.swift | With settlements: 提现 is a list row with chevron that opens the support sheet; the MR-38 hand-off card stays above it. |
| team-P1 (two messages for non-admin) | fixed | App/MerchantOperatorRosterSections.swift | Non-admin role: only the self-role card. |
| team-P1 (typed reason) | deferred | — | A prefill was tried and reverted: MerchantBusinessEditor is sliced by test_merchant_note_correction_presentation; needs that contract updated with the change. |
| X3 / batch-A-15 / B-P2 / C-17 / D-16 (title mode) | fixed in 24 more files | App/Merchant*.swift, App/PublicMerchantReviewEditor.swift | 26 pushed merchant-coop pages get the inline title (`cyPageTitle` or `.navigationBarTitleDisplayMode(.inline)`). Fixture hosts and byte-pinned files (MerchantBusinessRecordViews, MerchantStationServiceTimeFields, MerchantContentEditor) left as is. |

## Round-1 deferred / partial items — status now

| Id | Status | Note |
|---|---|---|
| relation-P0b (帖子 scope) | partial (unchanged) | Feed `scope:"all"` lives in the club community reader (other area). |
| decor-P0b (二维码 upload, 地址 map picker) | deferred | Needs the image upload + map picker on `/api/merchant/update` / `decor/save`; not started. |
| coop-list-P0b (回邀约, 发邀约, 再邀别人, 去收到的确认) | deferred | — |
| ai-npc-P0, citynode-P0, citynode-create-P0, game-node-P0, X6 | blocked-owner (unchanged) | Reviewed route gate / `merchantBusinessApproval` decisions; the brief keeps the gate. |
| nearby-P0 | deferred | Topic flow + gated `ChapterReplacementInvitation` write. |
| aftercare-detail-P1a (manual-case-detail read), batch-A-6 recordType, deep links with query params | deferred | — |

## Deferred P1 (not started this round)

merchant/index: project cards (MP `buildProjectCards`: join + host projects, upcoming runs, 待核销 per card — four reads) and 财务 → 账户收益 (owner ruling needed: round 1 kept 账本).
apply: map picker + lat/lng, claim entry, owned-club hand-over card, result page with timeline, status rows, guest 登录.
ledger / order-detail / batch-detail (batch A 5–7), payout, profile; marketing 店铺参谋 rebuild, 触达历史, 口碑 server filter, 客户 filter sheet / selection / paging, 售后 response cleanup, predictions copy (batch B);
decor hub header / inline toggle / 看公开主页, gallery upload-on-crop, perks yuan + sheet, store character media, city-node poster, game-node scan, city-node create 登录 (batch C 7, 10–16);
invite detail bar, deposit sheet (TEST-only), coop-center card, settlement `source=club`, team ShareLink + invite preview, deep links (batch D 6–10, 12, 13 rest).
All P2s except those listed as fixed above.

## Shared DesignSystem changes

None. New environment keys: `merchantInboxSources` (App/MerchantInboxPreviewSection.swift), `merchantMarketingLinks` (App/MerchantMarketingHomeSections.swift). `MerchantLedgerSettlementOverview` gained an `initialView` init parameter (default unchanged).

## Backend needed

None for the fixes above. Notes:
- 我的消息 marks a conversation read only locally; the server read `POST api/im/read {conversation_id}` (MP does it) stays with the inbox, where its write is gated (`IMExpandedService.canWriteOrdinaryRead`). Opening it here is a gate decision, not a backend change.
- `source=club` settlement detail needs `api/club/settlement/summary` (exists on the server) wired into `CoopFlowRead`; app-side work, listed as deferred.
