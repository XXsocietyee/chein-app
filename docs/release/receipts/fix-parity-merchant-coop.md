# Receipt — fix parity r1, merchant-coop

Brief: `origin/design/handoff-r2:docs/briefs/fix-parity-r1.md` · Findings: `origin/audit/parity-merchant-coop:docs/audit/parity/merchant-coop.md`
Branch: `fix/parity-merchant-coop` from `origin/ui/combined-r4` (no new base commits at the time of writing).

Finding ids: the audit has no numbered ids, so this receipt uses `<page>-P0a/b`, `<page>-P1…` in the audit's row order,
the cross-page ids `X0`–`X6`, and `batch-<A|B|C|D>-<n>` for the batched fix-plan items.

## Gates (run on the branch head)

| Gate | Result |
|---|---|
| `python3 -B tools/check_scaffold.py` | PASS (project regenerated with `tools/generate_project.py` for 5 new Swift files) |
| `python3 -B tools/check_design_lint.py` | PASS; typography ratchet lowered: back chevron 15→14, hidden back 15→11 (`--update` run after lowering) |
| `python3 -B tools/contract_ratchet.py --check` | 195 failing / baseline 184 / new 11 — **identical to the base `ui/combined-r4` run** (same 11 test ids). No new failures from this branch. |
| `python3 -B tools/report_chrome.py` | title-mode-unset 331→290; hidden-back / custom back gone from every merchant-coop file |

Swift is not installed in the cloud: nothing here was compiled. All code follows existing patterns in the same files.

## P0 findings

| Id | Status | Files | Local verification |
|---|---|---|---|
| X0 / decor-P0a / ai-npc (probe panel) | fixed | App/MerchantOperationsViews.swift, App/MerchantStoreCharacterView.swift, App/MerchantBusinessViews.swift, App/CouponManagementView.swift, App/MerchantContentViews.swift, tests | TEST account, open 品牌中心 / AI 店铺角色 / 团队 / 优惠券 / 章节: no route/path rows at the top; proxy log shows no `commerce/order`, `claims/submit` or `share-code` on open. DesignFixtures still render the panel. |
| X5 / verify-records-P0 | fixed | Core/MerchantBusinessQuery.swift, Core/MerchantBusinessDocuments.swift, Core/MerchantBusinessSyntheticFixtures.swift, App/MerchantVerifyRecordsSections.swift, App/MerchantBusinessViews.swift | 工作台 › 更多 › 核销记录 with a 核销员 (MERCHANT_CHECKIN) TEST account: request is POST `api/merchant/finance/redemptions` `{filter:all,pageSize:50}`; 已核销 n / 已撤销 n chips, day groups with "N 条", per-bucket empty copy. Offline example: 1 已核销 + 1 已撤销. |
| apply-P0a (identity never registered) | fixed | Core/MerchantOnboardingContracts.swift, Core/MerchantOnboardingService.swift, Core/MerchantOnboardingSession.swift, Core/MerchantOnboardingCoordinator.swift, App/MerchantOnboardingModel.swift, App/MerchantOnboardingView.swift, App/MerchantOnboardingFixtureSupport.swift, tests | TEST account without identity: step 3 license picker is enabled; complete step 4 (name, ID, consent), 提交: proxy shows POST `api/publisher/identity` `{realName,idCard,consent:true,source:merchant_apply}` then POST `merchant_registration` (no identity fields). Fixture `identity-required` reaches submit. |
| apply-P0b (行业类型 free text) | fixed | same + App/MerchantOnboardingCategoryPicker.swift | Step 1 行业类型 row opens a sheet over `api/category/list type=MERCHANT`, 1–5 picks (numbered), submit body has `categoryIds:"11,61"`, no `preference`. |
| bundle-reservations-P0 | fixed (write TEST-only) | Core/MerchantBundleReservations.swift, Core/MerchantBusinessService.swift, Core/MerchantBusinessReading.swift, Core/MerchantAccess.swift, App/MerchantBundleReservationsView.swift, App/MerchantHomeView.swift | 工作台 › 更多 › 套票到店 (verify role): GET `free-explore/bundle/merchant/reservations?from&to` (now−2d…+9d); rows "M月D日 HH:mm" + status chip; BOOKED rows past start show 记未到店 → destructive confirm → POST `…/reservation/{id}/no-show` then refresh. On the production host the button is disabled with 当前版本暂不支持记未到店 (merchantWrites switch). |
| aftercare-P0 (MANUAL_CASE breaks list) | fixed | Core/MerchantBusinessDocuments.swift, Core/MerchantAftercareParity.swift, App/MerchantAftercareParityViews.swift, App/MerchantBusinessViews.swift, Resources/MerchantOps.xcstrings, tools/build_merchant_ops_catalog.py, tests | Core test `testManualCaseRowDecodesReadOnlyWithItsOwnID`; TEST bucket 处理中 with a 人工退款工单 lists "人工退款工单 #81 · 玩家申请退款 · 平台评估中", tap opens the read-only progress page. Detail is built from the list row (not a fresh `manual-case-detail` read — see partials). |
| X1 / coop-list-P0a / coop-invite-P0 / invite-detail-P0 / relation (dead submit) | fixed (TEST-only by switch) | App/CoopFlowPreviewWrite.swift, App/CooperationFlowEditors.swift, App/QuestifyApp.swift | TEST host: any 接受/拒绝/撤回/取消/联系/申报/评价/发送邀约 review page shows an enabled 暂不可提交→提交 button; tap → fresh evidence → POST `api/coop/<op>` → 已提交 / server message / 结果暂未确认. Production host: disabled button + 当前版本暂不支持在此提交合作操作。 Built like `WP06ComplaintWrite`. |
| perks-P0 | fixed (TEST-only by switch) | App/CoopFlowPreviewWrite.swift, App/MerchantHomeView.swift | TEST host: 品牌中心 › 常备权益 shows 添加权益 and swipe/visible 删除; production keeps the read-only list. |
| relation-P0a (tab root) | fixed | App/HomeSearchTabParityViews.swift | Merchant mode › 合作 tab opens 发现 (帖子 / 俱乐部); toolbar ⊞ 合作工具 pushes the old workbench. |
| relation-P0b (帖子 feed) | partial | App/CoopRelationDiscoveryView.swift, Core/CoopRelationSection.swift, tests | 帖子 is the default tab and shows the club post feed. The app's feed omits `scope`, so the server returns joined/cooperated clubs' posts; MP sends `scope:"all"` (site-wide). Composer and post actions come with ClubCommunityFeedView. Changing the scope is in the club community reader (other area). |
| decor-P0b (contact fields) | partial | Core/MerchantOperationsContracts.swift, Core/MerchantOperationsDraft.swift, App/MerchantOperationsEditor.swift, docs/merchant-operations-localizations.json, tests | 品牌中心 › 店铺资料 › 联系方式: 联系电话 / 门店微信号 editable, sent to `/api/merchant/update` only when changed, server format rules shown inline. 门店二维码 (upload) and 店铺地址 (map picker → `decor/save` lat/lng/address) are shown read-only — follow-up. |
| coop-list-P0b (row actions) | partial | App/CooperationBrowserView.swift | 协作邀请: pending received application → 拒绝; pending sent application → 撤回申请; pending registration → 婉拒 + 确认占槽 (sheet with the reviewed submit). Missing: 回邀约, 发邀约, 再邀别人, 去收到的确认. |
| ai-npc-P0, citynode-P0, citynode-create-P0, game-node-P0 | blocked-owner | Core/MerchantCityNPCParityGates.swift (unchanged) | `MerchantCityNPCParityGates.reviewedEndpoints` is documented "empty until a deployment review approves exact routes". The brief keeps the reviewed route gate as is, so these writes need the owner's endpoint review. No code change. |
| nearby-P0 (topic flow, invitable, 补位) | deferred | — | Needs a topic entry from merchantinfo (topic area) and the gated `ChapterReplacementInvitation` write. |
| X6 (`merchantBusinessApproval` never supplied) | blocked-owner | — | `MerchantBusinessProductionApproval` grants are per merchant + exact target; supplying them is a policy decision on the reviewed gate, not a parity fix. 口碑 / 客户 / 售后 writes stay disabled until then. |

## P1 and chrome items done

| Id | Status | Files | Local verification |
|---|---|---|---|
| verify-records-P1a (split, day groups, title 核销记录) | fixed | see X5 | as X5 |
| verify-records-P1b (direct entry) | fixed | App/MerchantHomeView.swift, Core/MerchantAccess.swift | 更多 shows 核销记录 for verify or verify:record:read roles |
| aftercare-detail-P1a (manual case detail) | partial | see aftercare-P0 | read-only page from the list row |
| aftercare-P1 (reload after detail) | fixed | App/MerchantBusinessViews.swift | Open a 待回应 refund, go back: the list reloads |
| aftercare-detail-P1 (storage-key field) | fixed | App/MerchantBusinessEditor.swift | 售后 response editor has no 对象键 TextField; attached evidence shows 已添加凭证 |
| customer-detail-P1 (hex colour field) | fixed | App/MerchantBusinessEditor.swift, Core/MerchantTagColorPalette.swift | 客户详情 › 标签: colour is a named picker; wire value stays `#RRGGBB` |
| batch-A-6 (redemption permission) | partial | Core/MerchantBusinessQuery.swift, tests | `.redemptions/.redemption` require `merchant:verify:record:read` (server gate; every finance role holds it). `recordType` passthrough for activity_ticket/session_fee not done. |
| batch-A-10 / batch-D-6 / X2 (deep links) | partial | App/MPReviewedPageScreen.swift | MP links to apply, verify-records, team, coop-center, nearby open native screens. Query params (ledger view/topicId, order-detail ids, invite-detail inviteId, settlement-detail) still rejected. |
| payout-P1 (商户号 copy) | fixed | App/MerchantPayoutAccountView.swift | Long-press 商户号 → 复制商户号 (local-only, 2-minute pasteboard) |
| batch-A-12 (竞猜→预测) | fixed | Resources/Localizable.xcstrings | Workbench reminder and marketing prediction copy say 预测 |
| relation-P1 theme / 商家 tab / stray rows | fixed | App/CoopRelationDiscoveryView.swift, Core/CoopRelationSection.swift | Light merchant theme; no 商家 segment; no author-delete section or lone "—" |
| coop-list-P1 (协作邀请 row target, nested stack) | fixed | App/MerchantHomeView.swift, App/CooperationBrowserView.swift, App/CoopFlowPreviewWrite.swift, App/QuestifyApp.swift | 工作台 › 协作邀请 pushes the invitation list with one back button |
| coop-P2-17 (提现 rows on tools root) | fixed | App/CooperationFlowWorkbench.swift | 合作工具 has no 提现 / 提现记录 rows; 提现 stays on 分润明细 |
| chrome: hidden back + custom 返回/取消/chevron | fixed | App/MerchantOnboardingView.swift, App/MerchantOperationsViews.swift, App/MerchantCityNodeCreateView.swift, App/MerchantStoreCharacterView.swift, UI tests | With edits: bare back opens the existing discard confirm; without edits: system back + swipe. AI 店铺角色 avatar sub-screen still returns to home first. |
| chrome: title mode (X3, batch-A-15, B-P2, C-17, D-16) | fixed in 29 files | 29 merchant-coop App files | Pushed merchant/coop pages show the inline title (no large title after a large root). `MerchantBusinessRecordViews.swift` left as is: a byte-frozen contract covers it. |

## Deferred (not started)

All other P1s, in the audit's fix-plan order: batch A 5, 7, 8, 9, 11-rest, 13, 14, 15 (paging/status chips); batch B marketing tiles, 店铺参谋 rebuild,
触达历史, 口碑 server filter + card, 客户 filter sheet/selection/append paging, predictions; batch C 7–14, 16; batch D 8–13 (deposit
sheet TEST-only, invite detail bar, coop-center card, finance, settlement `source=club`, team share/confirm); city-node create
登录 button (no session sign-in hook in the environment); all P2s.

## Shared DesignSystem changes

None. New environment keys live in App/CoopFlowPreviewWrite.swift (`coopFlowPreviewWrite`, `merchantCoopInboxDestination`).

## Backend needed

None required for the fixes above. Open questions for the owner:
- `MerchantCityNPCParityGates.reviewedEndpoints` (city-node `save`/`claim`/`claim/cancel`/上下线, station commands, store character save/voice) — endpoint review decision.
- `merchantBusinessApproval` grants for 口碑 / 客户 / 售后 writes (X6).
