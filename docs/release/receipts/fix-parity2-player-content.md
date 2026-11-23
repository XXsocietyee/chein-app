# Receipt: fix-parity2-player-content (parity r2)

- Branch: `fix/parity2-player-content`, cut from `origin/ui/combined-r5` (base unchanged at the last fetch).
- Brief: `docs/briefs/fix-parity-r2.md` (design/handoff-r2). Findings: `docs/audit/parity/player-content.md`
  (audit/parity-player-content). Round 1: `docs/release/receipts/fix-parity-player-content.md`.
- Swift is not installed in the cloud: nothing here was compiled or run. Every row's "verify" column is the local step.
- Strings: every new key is written by `tools/add_fix_parity2_player_content_localizations.py` (idempotent, en + zh-Hans).

## Gates (last commit)

- `tools/check_scaffold.py`: PASS.
- `tools/check_design_lint.py`: PASS. Typography: **large title 11 → 8**, every other count unchanged
  (raw text style 1173, Theme.Font 63, raw size 67, back chevron 12, hidden back 7). Baseline not rewritten.
- `tools/contract_ratchet.py --check`: the base (`ui/combined-r5`) already reports 185 failing / baseline 184
  (`test_workshop_paid_professional…bounded_paging` is new on the base, not from this branch). See "Ratchet" below for this branch.
- `tools/report_chrome.py`: `hero-chrome` 2 → 0 (topic and activity detail), `large-title` 12 → 9 in this area.

## Shared DesignSystem changes

None. (`docs/release/ui-strings-subpackageA-pages-myproject-index.json` drops the identifier of the removed
发布单场活动 row; `Tests/ContractChecks/test_global_chrome_domain_contract.py` now pins the system back on topic /
activity detail instead of the old hero chrome.)

## Round-1 leftovers

| id | status | files | verify (local) |
|---|---|---|---|
| PC-B-1-3 (已截止 bar) | fixed | `Core/TopicContracts.swift` (`saleEndAt`), `Core/TopicXcxFacts.swift` (`.closed`, `saleClosed`), `App/TopicXcxSections.swift`, `App/TopicDetailView.swift`, `Tests/CoreTests/TopicXcxFactsTests.swift` | Unit `TopicXcxFactsTests.testSaleClosedStateAfterDeadline`. TEST topic with `endDate` (or `saleEndAt`) in the past: bottom bar reads 已截止 with no button; paywall 立即解锁 hidden |
| Hero chrome on topic / activity detail (round-1 design call) | fixed | `App/TopicDetailView.swift`, `App/ActivityDetailView.swift` | Both heroes are inset list rows, not full-bleed images, so the rule card's glass exception does not apply: system back + edge swipe, share / 举报 stay in the bar. Open any topic and activity: system back chevron, swipe-back works, no custom glass/bar chevron |
| PC-B-1-2 收藏 | blocked (owner decision) | — | Unchanged from round 1 (BK-LIKE pin) |
| PC-B-2-2, B-2-3, B-3-1, B-3-2, B-4-1 | blocked (owner decision) | — | Unchanged: merchant / pricing writes behind un-issued grants |
| PC-B-4-2 per-ticket final prices | deferred | — | Needs the preview's ticket list in `PublisherPricingView`; confirm is still grant-gated (B-4-1) |
| PC-C-4-1 安全须知 | client fixed in r1; blocked-backend | — | See "Backend needed" |
| PC-A-1-3 city picker | deferred | — | Still no city → coordinate source |
| PC-D-9-1 mark read | deferred | — | IM follows the Flutter app (owner rule); the Flutter source is not in this checkout |

## P1 (fix-plan order)

| id | status | files | verify (local) |
|---|---|---|---|
| PC-A-1-8 | fixed | `App/MPReviewedPageScreen.swift` (`MPTabHandoff`) | `chein://mp/pages/index/index` closes the link and selects 首页; no second home with its own stack |
| PC-A-2-6 | fixed | `App/MPReviewedPageScreen.swift`, `App/SessionHomeFeedView.swift` | Template link and 首页 浏览模板 both show 应用 and 发布 like the 发布 tab entry |
| PC-A-6-2 | partial | `App/MPReviewedPageScreen.swift`, `App/GlobalSearchLinksAndTemplates.swift` | `…/templatedetail/templatedetail?id=<id>` and the search 玩法模板 row open with 应用. `scope=my` / `operationScope` / `readonly` still not read |
| PC-D-1-1 | fixed | `App/SubscribeMessageTapScreens.swift` | `…/subpackageA/pages/myproject/index` (and its subscribe message) opens the in-app 我的项目 (covers, tabs, ··· menu) |
| PC-D-2-1 | fixed | `App/MPReviewedPageScreen.swift` | `…/subpackageA/pages/infomation/infomation`: the three mode cards show 去看看; tap → 首页 / 漫游 tab |
| PC-C-1-3 | fixed | `Core/ActivityDetail.swift` (`signUpBlock`, `ActivitySignUpBlock`), `App/ActivityDetailView.swift`, `Tests/CoreTests/ActivityContractTests.swift` | Unit `testSignUpBlockFollowsSelectableTickets`. Activity with all tickets sold out / past → pill disabled 暂无可报名票种; no tickets → 暂未开放票种. Unknown `isSignUp` still opens the sheet (pinned by `ActivityContractTests` line 65) |
| PC-C-1-4 | fixed | `Core/ActivityDetail.swift`, `App/ActivityPeopleSection.swift`, `App/ActivityDetailView.swift` | Fixture/TEST activity with `organizerShopName`: people section reads 主办方 + shop name, no member row |
| PC-B-1-15 | fixed | `App/TopicDetailView.swift` | Locked story with `selfPlayPrice`: paywall shows the price and 已购？去票夹 (opens the ticket wallet sheet) |
| PC-A-6-1 | fixed | `App/DiscoveryTemplateDetailView.swift` | 玩法详情 with `imgUrl`: the head shows the cover; generated art while loading / on failure / without one |
| PC-A-7-3 | fixed | `App/DiscoveryTemplateDetailView.swift` | Topic-template detail while the copy write is gated: 用这个模板 is shown disabled with 当前版本暂未开放复制模板 |
| PC-C-4-3 | fixed | `App/OfficialEventDetailView.swift` | Official event detail: trailing share opens the share card (title, subtitle, city) |
| PC-C-3-2 | fixed | `App/OfficialEventComponents.swift` (`OfficialReadScreen`) | Official list / inbox / mine: pull to refresh keeps the cards and shows 正在更新活动列表…; a failed pull keeps them with 刷新失败，稍后再试 |
| PC-C-5-1 | fixed | `App/OfficialActionViews.swift` | Inbox 接受职责 opens the review sheet titled 接受本场职责 directly (no generic 确认回应官方邀约 modal first) |
| PC-C-5-2 | fixed | same | 接受职责 is the primary pill; 拒绝 / 退出 secondary |
| PC-C-7-2 | fixed | `App/OfficialOrganizerConsoleView.swift` | Organizer console: paused event shows only the resume form; running shows only the pause form |
| PC-C-7-3 | fixed | same | Pull the console: 正在读取平台最新记录… line while locked |
| PC-C-1-10 | fixed | `App/E1ActivityDetailParts.swift` | Activity without category / meeting point / time / price / count: those info-card rows are absent, no "—" rows |
| PC-D-7-1 | fixed | `App/VideoBountyView.swift`, `App/VideoBountySession.swift` | Video bounty signed out (configured, no token): one 登录后查看你的视频投稿与奖励 + 登录 (opens 我的), not two 读取失败 |
| PC-D-6-5 | fixed | `App/WalletIncomeAnalysisView.swift`, `App/MPReviewedPageScreen.swift` | `…/assetcenter/analysis/index` signed out: 登录后查看分析 + 登录 |
| PC-B-5-1 | fixed | `App/PublisherLifecycleViews.swift` | Partner pricing read failure: 重试 under the error |
| PC-D-5-4 | fixed | `App/WalletEarningsParity.swift` | 账户收益 with zero balance: 还没有收益 + 去发布路线 (switches to 发布) |
| PC-D-1-4 | fixed | `App/MyProjectTabViews.swift` (`MyProjectRowMoreButton`), `App/CreatorContentViews.swift` | 我的项目 rows with operations show a visible ··· (same menu as long-press); none when nothing applies |
| PC-D-1-5 | fixed | `App/CreatorContentViews.swift`, `App/MyProjectTabViews.swift` | Non-empty 活动 tab: no 发布单场活动 row above the list (empty state keeps its CTA) |
| PC-B-4-5 | fixed | `App/PublisherLifecycleViews.swift`, xcstrings | 定价 有人带: 本团带队总成本 / 成团人数 labels stay above the fields after typing; floor section reads 最低价 |
| PC-B-4-6 | partial | same | Opens on 有人带; floor auto-loads when inputs allow. Tabs still shown for free-explore topics (the view has no `productType`) |
| PC-D-5-3 | partial | `App/WalletCommerceViews.swift` | Balance label 账户收益. The inline `t("…")` section copy is unchanged |
| PC-D-6-4 | fixed | `Resources/WalletIncomeAnalysis.xcstrings` | 收益分析 segment reads 提现 |

### Chrome / titles (X2, brief step 3)

| id | status | files | verify (local) |
|---|---|---|---|
| PC-B-1-8, PC-C-1-9 | fixed | `App/TopicDetailView.swift`, `App/ActivityDetailView.swift`, `Tests/ContractChecks/test_global_chrome_domain_contract.py` | see round-1 leftovers |
| PC-A-2-3 | fixed | `App/DiscoveryTemplateBrowserView.swift` | 发布 → 浏览模板: inline 模板 title |
| PC-A-5-6 | partial | `App/GlobalSearchLinksAndTemplates.swift` | Search / map opened from a link: inline titles. `SearchMapExplorerView` and `GlobalSearchView` are SHA-pinned (`test_global_search_category_recovery`), so the in-app push keeps its mode |
| PC-D-1-7 | fixed | `App/CreatorContentViews.swift` | 我的 → 我的项目: inline title |
| PC-D-2-3 | fixed | `App/SocialGuideViews.swift` | 我的 → 城瘾玩法: inline |
| PC-D-3-1 | partial | same | 玩法详情 inline (was large). The article title stays in the cover as the object's name; the bar still says 玩法详情 |
| PC-D-5-5 | fixed | `App/WalletCommerceViews.swift` | 账户收益: inline |
| PC-D-6-3 | fixed | `App/WalletIncomeAnalysisView.swift` | 收益分析: title in the bar, no in-content hero header |
| PC-D-7-2 | fixed | `App/VideoBountyView.swift` | 视频悬赏: inline |
| PC-D-8-2 | fixed | `App/MessagingHomeView.swift` | 我的 → 消息: inline |
| PC-B-4-7, PC-B-5-3 | fixed | `App/PublisherLifecycleViews.swift` | 确认终价 / 合作俱乐部 page: title drawn once by the bar |
| PC-D-4-3 | fixed | `App/WalletCommerceViews.swift` | 收益明细: no second in-content 收益明细 |
| X2 official list | fixed | `App/OfficialEventsBrowserView.swift` | 官方活动 list: inline |

### Blocked / deferred P1 (reason)

| id | status | reason |
|---|---|---|
| PC-D-6-2 | blocked (review) | The 10 × 20-row budget is pinned as the approved read (`test_wallet_income_analysis_closure`, `WalletHistoryReadRoute`). Raising to MP's 200/page until `total` needs that route review |
| PC-C-1-8 | blocked (contract) | `test_activity_registration_parity_w2_06` pins 关于这场活动 inside 更多信息; needs a hand-off ruling to move it |
| PC-A-3-3, PC-A-5-4, PC-A-5-5 | blocked (pinned files) | `GlobalSearchView`, `SearchMapExplorerView`, `SearchMapFilterSheet`, `SearchMapService` are SHA-pinned by `test_global_search_category_recovery` |
| PC-D-8-1, D-8-3, D-9-3, D-9-4 | deferred | IM follows the Flutter app (owner rule); the Flutter source is not in this checkout |
| PC-C-6-1, PC-A-3-1, PC-B-6-2, PC-D-5-1 | owner decision | 发布官方活动 entry vs the 2026-09-03 ruling; player search hides 商家; `/catalog` still live; 提现 in Release (money stays TEST-only) |
| everything else in the audit P1 list (A-1-5/6/7, A-2-1/2/5, A-3-4, A-4-2/3, A-5-1/2/3, A-7-2, A-8-2/3, B-1-4…7, B-1-9…11, B-1-14, B-2-4/5, B-3-3…5, B-4-4, B-5-2, B-6-1, C-1-1/2/5/6/7, C-2-3…7, C-3-3, C-4-2/4, C-5-3/4, C-6-2, D-1-3/6/8/9, D-2-2/4, D-3-2, D-4-2/4/5, D-5-2, D-7-3) | deferred | Not reached in this run; P2s untouched |

## Backend needed

- `GET /api/official/events/{id}` (and v2 detail): `safetyNotice: { title: string, version: string }` (unchanged from round 1).

## Ratchet

See the last line of `contract_ratchet.py --check` recorded below (updated at the end of the run).
