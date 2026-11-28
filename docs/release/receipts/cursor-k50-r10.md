# K50-R10 XCUITest page coverage

Branch `cursor/1128-k50-r10` from `origin/ui/combined-r7` @ `d5702393c`. Extends the K24 `Tests/AppUITests/Accept` lane. Each new test calls `XCUIAcceptSmoke.cover`, which launches the existing `--design-fixture` once in English and once in zh-Hans and waits until a marker accessibility identifier and the page copy are both on screen.

35 page tests added. K24's 25 tests are unchanged. No new fixture, launch argument, accessibility identifier, or page path. `AppSession.swift` stays 7976 lines (ceiling 7977). `AppCompositionRoot.swift` stays 4173. Init order stays devices, sensors, artworkHosts. Money is unchanged. `merchantCenterEnabled` stays false in Release (`#if DEBUG || TEST` true, else false). `pages/coop/invite-detail/index` stays hidden on that flag; its test only launches the existing DEBUG fixture. No `String(localized:)`.

XCUITest NOT_RUN. This VM has no Xcode and no simulator, and this round does not run `xcodebuild`.

## Added

| Fixture | Screen | Marker | English | zh-Hans |
|---|---|---|---|---|
| `d4-growth` | `subpackageP3/pages/growthcenter/index/index` | `growth.refresh` | Growth center | 成长中心 |
| `d4-leaderboard` | `subpackageP3/pages/growthcenter/leaderboard/index` | `growth.board.period` | Leaderboard | 完整排行榜 |
| `d4-badges` | `subpackageP3/pages/badge-wall/index/index` | `objects.badge.summary` | My badges | 我的徽章 |
| `d4-stamps` | `subpackageP3/pages/stamp-album/index/index` | `roam.experience.album` | Stamp album | 集邮册 |
| `t5-official-inbox` | `pages/activity/official-inbox/index` | `official.inbox.content` | Official event invitations | 官方活动邀约 |
| `t5-official-mine` | `pages/activity/official-mine/index` | `official.published.content` | My published | 我发布的 |
| `t5-official-organizer` | `pages/activity/official-organizer/index` | `official.organizer.content` | Organizer console | 主办控制台 |
| `t5-official-detail` | `pages/activity/official-detail/index` | `official.detail.content` | Official event | 活动详情 |
| `t5-coop-invite-detail` | `pages/coop/invite-detail/index` | `cooperation.detail.status` | Collab details | 协作详情 |
| `t11-fabu` | `pages/publish/fabu/index` | `projectEdit.name` | Edit topic | 编辑主题 |
| `publish-quick` | `pages/publish/simple/index` | `publishModes.quick.name` | Quick route setup | 快速配置 |
| `e5-guide` | `subpackageA/pages/infomation/infomation` | `social.guide` | Play guide | 城瘾玩法 |
| `e5-info-detail` | `subpackageA/pages/infomationdetail/infomationdetail` | `social.information.detail` | Example city guide / 示例城市指南 | Example city guide / 示例城市指南 |
| `e4-about` | `pages/shezhi/about/index` | `settingsNative.about.appName` | About | 关于 |
| `e4-profile-edit` | `pages/gerenziliao/gerenziliao` | `profile.edit.reload` | Edit profile | 个人资料 |
| `e4-complaint` | `subpackageMember/complaint/index` | `profile.complaint.pageSubtitle` | Complaints & feedback | 投诉与建议 |
| `cur6-privacy` | `pages/privacy/index` | `privacy.guide.summaryItems` | Privacy | 隐私保护 |
| `cur6-agreement` | `pages/agreement/index` | `settingsNative.legal.noAcceptance` | User service agreement | 用户服务协议 |
| `e5-circle-link` | `pages/play/circle/index` | `playx.circleLink.missing` | Free exploration | 自由探索 |
| `r3-roam-poi` | `subpackageRoam/poi-detail/index` | `roam.place.header` | Bund Origin courtyard | 外滩源庭院 |
| `r3-roam-routes` | `subpackageRoam/official-routes/index` | `officialRoute.list` | Official routes | 官方路线 |
| `r3-roam-route` | `subpackageRoam/official-route/index` | `officialRoute.detail` | Bund night walk | 外滩夜色步行线 |
| `r3-roam-session` | `subpackageRoam/session/index` | `roam.experience.session` | This roam | 本次漫游 |
| `r3-roam-tasks` | roam official-task list (`RoamOfficialTasksView`) | `roam.tasks.browser` | Official roaming events | 漫游官方活动 |
| `r3-roam-my-teams` | `subpackageRoam/my-teams/index` | `nearby.mine.map` | My teams | 我的队伍 |
| `t5-team-detail` | `pages/team/detail/index` | `team.detail.card` | Synthetic harbor companions | Synthetic harbor companions |
| `t5-pass-market` | `subpackageMember/market/passes/index` | `passMarket.points` | Passes | 通行证 |
| `wallet` | `subpackageA/pages/assetcenter/earnings/index` | `wallet.earnings.overview` | Account earnings | 账户收益 |
| `e4-wallet-income` | `subpackageA/pages/assetcenter/income-detail/income-detail` | `wallet.income.filter` | Income details | 收益明细 |
| `e4-wallet-assets` | `WalletAssetsView` (`e4-wallet-assets`) | `wallet.assets.loading` | Assets | 我的资产 |
| `e4-wallet-analysis` | `WalletIncomeAnalysisView` (`e4-wallet-analysis`) | `wallet.analysis` | Analysis | 分析 |
| `album-cards` | `subpackageP3/pages/object-cards/index/index` | `objects.collection` | Items | 藏品 |
| `d4-enroll` | `pages/club/enroll/index` | `club.enroll.screen` | Enrollment roster | 报名名册 |
| `e2-stamp-camera` | `subpackageP3/pages/stamp-camera/index/index` | `nativeR2.stamp.capture` | Stamp camera | 集邮相机 |
| `d2-square-detail` | `pages/square/detail/index` | `square.detail` | Post | 动态 |

A test lists every marker it accepts. The table names the one that identifies the page. Information detail and team detail use the fixture's own title, which is the same string in both languages. Place detail, the official route, and the pass balance use the fixture's bilingual copy.

## Skipped (no stable identifier)

`docs/parity/page-map.csv` has 163 pages. One target file has no accessibility-identifier string literal:

| Page | Screen | Why |
|---|---|---|
| `pages/shezhi/marketing/index` | `App/MarketingConsentOriginalPresentation.swift` | The only identifier is `marketing.original.receipt.\(receipt.requestId)`. |

Pages that already have a literal identifier, and that this repo does not already launch with a design fixture, stay uncovered. This round does not add a fixture for them.

## Gates

`python3 tools/generate_project.py` (new Accept sources are in the UI-test target). `tools/check_scaffold.py` PASS (21802 bilingual keys). `tools/check_a11y_lint.py` 0 new. `tools/check_design_consistency.py` PASS. `tools/check_appsession_ratchet.py` PASS (7976 < 7977). `python3 -B tools/contract_ratchet.py --check` 46 failing, baseline 46, **new 0**.
