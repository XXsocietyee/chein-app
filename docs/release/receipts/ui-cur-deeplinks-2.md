# Handover 52 — mini-program page links

Branch `ui/cur-deeplinks-2` from `9209d33cb2d7ceed6f95a1b9d90b556e531a63b0` (`ui/main`).

`MiniProgramPageLink` and `MPParityRoute` already covered twelve parity pages that are not rows in `docs/parity/page-map.csv`. Those twelve rules are unchanged. This change adds every other page-map path whose target file on that base already contains a page-level native view. The link type is still `MiniProgramPageLink.Rule`. The route type is still `MPParityRoute`, with one existing-style case `screen(page:query:)` for the page-map paths. Query keys are only the keys those twelve pages already used, plus the canonical `id` that `NativeContentTarget` and `subpackageMember/orderinfo/orderinfo` already use. No path was invented.

`pages/activity/detail/index`, `pages/club/detail/index`, `pages/topic/index/index`, `pages/templatedetail/templatedetail`, `pages/square/detail/index`, `subpackageRoam/poi-detail/index`, and `subpackageRoam/session/index` stay `NativeEntryIntent.content` for an internal path, a push tap, and a verified universal link when the query is exactly `id=<canonical>`. `chein://mp` still classifies them as `MiniProgramPageLink`. `pages/team/join/index` stays on the team-invitation parser (`code` → invitation, `teamId` → `legacyTeamLink`). It is not in `reviewedPages`.

A routed page whose existing screen can be built from `AppSession` opens that screen. A routed page whose screen needs an id or a model the accepted query does not carry shows the existing empty state `mp.route.unavailable`. No new string key was added. English and zh-Hans for that state, and for every opened screen, are the catalogs those screens already ship.

`ReviewedAreaSwitch` was not redeclared. `App/AppSession.swift`, `App/AppCompositionRoot.swift`, and `App/RegionalLaunchConfiguration.swift` were not edited. `docs/release/contract-failing-baseline.txt` was not raised. `App/MPReviewedPageScreen.swift` was registered with `python3 tools/generate_project.py`.

## Routes added

158 page-map paths. The query column is the only query `MiniProgramPageLink` accepts for that path.

| Page | Query |
| --- | --- |
| `pages/activity/baoming/baoming` | none |
| `pages/activity/detail/index` | required `id` |
| `pages/activity/list/index` | none |
| `pages/activity/official-detail/index` | optional `id` |
| `pages/activity/official-inbox/index` | none |
| `pages/activity/official-mine/index` | none |
| `pages/activity/official-organizer/index` | none |
| `pages/address/address` | none |
| `pages/addressinfo/addressinfo` | none |
| `pages/agreement/index` | none |
| `pages/club/apply/index` | none |
| `pages/club/badges/index` | none |
| `pages/club/checkin-detail/index` | none |
| `pages/club/create/index` | none |
| `pages/club/customer-detail/index` | none |
| `pages/club/customers/index` | none |
| `pages/club/detail/index` | required `id` |
| `pages/club/edit/index` | none |
| `pages/club/enroll/index` | none |
| `pages/club/event-ops/index` | none |
| `pages/club/group-code/index` | none |
| `pages/club/join-requests/index` | none |
| `pages/club/notify/index` | none |
| `pages/club/topic-detail/index` | none |
| `pages/club/topic-story/index` | none |
| `pages/club/workbench/index` | none |
| `pages/coop/finance/index` | none |
| `pages/coop/invite-detail/index` | none |
| `pages/coop/invite/index` | none |
| `pages/coop/list/index` | none |
| `pages/coop/nearby/index` | none |
| `pages/coop/settlement-detail/index` | none |
| `pages/coop/withdraw/index` | none |
| `pages/coop/withdraw/records/index` | none |
| `pages/crop/index` | none |
| `pages/deregister/index` | none |
| `pages/gerenziliao/gerenziliao` | none |
| `pages/index/index` | none |
| `pages/member/index/index` | none |
| `pages/merchant/aftercare/detail/index` | none |
| `pages/merchant/aftercare/index` | none |
| `pages/merchant/apply/index` | none |
| `pages/merchant/citynode/create/index` | none |
| `pages/merchant/citynode/index` | none |
| `pages/merchant/coop-center/index` | none |
| `pages/merchant/crm-campaigns/index` | none |
| `pages/merchant/customer/index` | none |
| `pages/merchant/decor/ai-npc/index` | none |
| `pages/merchant/decor/coop-setting/index` | none |
| `pages/merchant/decor/gallery/index` | none |
| `pages/merchant/decor/index` | none |
| `pages/merchant/decor/perks/index` | none |
| `pages/merchant/game-node/index` | none |
| `pages/merchant/index/index` | none |
| `pages/merchant/ledger/batch-detail/index` | none |
| `pages/merchant/ledger/index` | none |
| `pages/merchant/ledger/order-detail/index` | none |
| `pages/merchant/marketing/ai-insight/index` | none |
| `pages/merchant/marketing/index` | none |
| `pages/merchant/predict/index` | none |
| `pages/merchant/profile/index` | none |
| `pages/merchant/relation/index` | none |
| `pages/merchant/reviews/index` | none |
| `pages/merchant/team/index` | none |
| `pages/merchant/verify-records/index` | none |
| `pages/mylike/mylike` | none |
| `pages/play/circle/index` | none |
| `pages/play/index` | none |
| `pages/play/merchant/index` | none |
| `pages/play/poi-challenge/index` | none |
| `pages/privacy/index` | none |
| `pages/publish/activity/index` | none |
| `pages/publish/fabu/index` | none |
| `pages/publish/simple/index` | none |
| `pages/publish/temp/index` | none |
| `pages/publish/template-intro/index` | none |
| `pages/publish/topicadd/topicadd` | none |
| `pages/roam/index` | none |
| `pages/search2/index` | none |
| `pages/search2/result/index` | none |
| `pages/searchmap/index` | none |
| `pages/shezhi/about/index` | none |
| `pages/shezhi/marketing/index` | none |
| `pages/shezhi/shezhi` | none |
| `pages/square/detail/index` | required `id` |
| `pages/square/list/index` | none |
| `pages/talent/list/index` | none |
| `pages/talent/search/index` | none |
| `pages/team/detail/index` | none |
| `pages/template/index` | none |
| `pages/templatedetail/templatedetail` | required `id` |
| `pages/templatedetail/topic-detail/index` | none |
| `pages/templatedetail/topic-preview/index` | none |
| `pages/templatedetail2/templatedetail2` | none |
| `pages/topic/index/index` | required `id` |
| `pages/topic/merchantapply/index` | none |
| `pages/topic/merchantinfo/merchantinfo` | none |
| `pages/topic/pricing/index` | none |
| `pages/topic/pricing/partner/index` | none |
| `pages/topic/settlement/index` | none |
| `pages/userinfo/userinfo` | optional `id` |
| `subpackageA/pages/assetcenter/analysis/index` | none |
| `subpackageA/pages/assetcenter/earnings/index` | none |
| `subpackageA/pages/assetcenter/income-detail/income-detail` | none |
| `subpackageA/pages/infomation/infomation` | none |
| `subpackageA/pages/infomationdetail/infomationdetail` | optional `id` |
| `subpackageA/pages/myproject/index` | none |
| `subpackageB/pages/im/chat/index` | none |
| `subpackageB/pages/im/list/index` | none |
| `subpackageMember/appeal-mine/index` | none |
| `subpackageMember/character/index` | none |
| `subpackageMember/complaint/index` | none |
| `subpackageMember/coupon-qr/index` | none |
| `subpackageMember/coupon-wallet/index` | none |
| `subpackageMember/coupon/coupon` | none |
| `subpackageMember/couponInfo/couponInfo` | none |
| `subpackageMember/free-explore/index` | none |
| `subpackageMember/invoice-apply/index` | none |
| `subpackageMember/invoice-detail/index` | none |
| `subpackageMember/invoice-title-edit/index` | none |
| `subpackageMember/invoice-titles/index` | none |
| `subpackageMember/invoice/index` | none |
| `subpackageMember/mycanyu/mycanyu` | none |
| `subpackageMember/mycanyuinfo/mycanyuinfo` | none |
| `subpackageMember/myinvite/myinvite` | none |
| `subpackageMember/mytemplate/mytemplate` | none |
| `subpackageMember/order/order` | none |
| `subpackageMember/orderinfo/orderinfo` | required `id` |
| `subpackageMember/orient-score/index` | none |
| `subpackageMember/points-history/index` | none |
| `subpackageMember/report-detail/index` | none |
| `subpackageMember/report-mine/index` | none |
| `subpackageMember/signup/index` | none |
| `subpackageMember/signupInfo/signupInfo` | none |
| `subpackageMember/signupInfo2/signupInfo2` | none |
| `subpackageMember/tixian/tixian` | none |
| `subpackageMember/tixianjilu/tixianjilu` | none |
| `subpackageP3/pages/badge-3d/index` | none |
| `subpackageP3/pages/badge-wall/index/index` | none |
| `subpackageP3/pages/growthcenter/index/index` | none |
| `subpackageP3/pages/growthcenter/leaderboard/index` | none |
| `subpackageP3/pages/object-cards/index/index` | none |
| `subpackageP3/pages/stamp-album/index/index` | none |
| `subpackageP3/pages/stamp-camera/index/index` | none |
| `subpackageRoam/citynode-code/index` | none |
| `subpackageRoam/citystamp/index` | none |
| `subpackageRoam/history/index` | none |
| `subpackageRoam/my-teams/index` | none |
| `subpackageRoam/nearby/index` | none |
| `subpackageRoam/official-route/index` | none |
| `subpackageRoam/official-routes/index` | none |
| `subpackageRoam/poi-detail/index` | required `id` |
| `subpackageRoam/session/index` | required `id` |
| `subpackageTools/anniversary/index` | none |
| `subpackageTools/capsule/index` | none |
| `subpackageTools/exploration-export/index` | none |
| `subpackageTools/exploration-goals/index` | none |
| `subpackageTools/monthly-recap/index` | none |

## Pages skipped because there is no native view

These four `docs/parity/page-map.csv` rows name a file that only has a section, a card, or a picker. They are not routes.

| Page | Why |
| --- | --- |
| `pages/club/governance/index` | `ClubOpsGovernanceSections` and related sections. No page view. |
| `pages/club/roles/index` | Governance sections plus `ClubRoleAssignmentPicker`. No page view. |
| `pages/club/settlement/index` | `ClubOpsSettlementSummaryCard` and related cards. No page view. |
| `pages/merchant/customer/detail/index` | `MerchantCustomerDetailSections` only. No page view. |

`pages/team/join/index` has a native team-invitation screen. It is left off this table because that parser already owns the path. It is not a missing-view skip.

## Checks

`python3 tools/check_scaffold.py` PASS. `python3 tools/check_design_lint.py` PASS. This VM has no `swiftc`. Changed Swift was not parsed, compiled, or run under XCTest.

## 中文

分支 `ui/cur-deeplinks-2`，基线 `9209d33cb2d7ceed6f95a1b9d90b556e531a63b0`。原来的十二条奇偶页规则没有改。`docs/parity/page-map.csv` 里、目标文件已经有页面级原生视图的路径都进了 `MiniProgramPageLink.reviewedPages`，再用原来的 `MPParityRoute`，新增的只是 `screen(page:query:)`。没有新造路径，也没有新的链接类型。查询只允许这十二条里已经有的键，以及原来的规范 `id`。

上面七条内容路径在内部路径、推送和已核验的通用链接上仍是 `content`。`chein://mp` 仍按小程序页解析。`pages/team/join/index` 仍走队伍邀请解析，不在本表里。

能用现有 `AppSession` 装出来的页面打开原来的屏幕。链接里没有构造所需的 id 或模型时，显示已有的 `mp.route.unavailable`。没有新文案键。该空态和被打开的屏幕本来就有英文和简体中文。

没有重新声明 `ReviewedAreaSwitch`。没有改 `AppSession`、`AppCompositionRoot`、`RegionalLaunchConfiguration`，也没有抬高 contract-failing baseline。新文件经 `python3 tools/generate_project.py` 登记。

新增路由共 158 条，见上表。因没有页面级原生视图而跳过的是：`pages/club/governance/index`（只有治理分区）、`pages/club/roles/index`（分区和角色选择器）、`pages/club/settlement/index`（只有结算卡片）、`pages/merchant/customer/detail/index`（只有客户详情分区）。

`check_scaffold.py` 与 `check_design_lint.py` 通过。本机没有 `swiftc`，没有解析，没有编译，也没有跑 XCTest。
