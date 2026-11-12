# U9-B receipt: screenshot-driven visual parity, domain B (player, non-merchant)

Branch `ui/u9-b`, rebased on `origin/ui/next` @ 877127f72. Code only: no xcodebuild, no simulator. The integrator compiles.
References: private mini-program matrix `1c80c5a-matrix` (hengyin chengyinhub-xcx @1c80c5a) and its source. No mini-program screenshot is committed or quoted here.

Checks run here: `tools/check_scaffold.py` PASS, `tools/check_design_lint.py` PASS (one stale allowlist entry removed after `SocialGuideXcxParity.swift` lost its last fixed font size). No files added, so `tools/generate_project.py` was not needed. Contract checks touched by these edits were updated where they pinned the old layout (listed under "Tests and pins changed").

Legend: **fixed** = changed in this branch; **left** = needs logic, data, a product decision, or a structural rebuild outside a parity pass.

| row | route | state | native file | gaps found | fixed | left (needs logic or decision) |
|---|---|---|---|---|---|---|
| B01 | pages/roam/index | normal | RoamBrowserView, RoamHomeTabsView | tab and card 1 say 走起, mp 开始漫游; cards 1 and 3 have subtitles mp leaves empty; no paging dots; native adds an official-routes card | — | 走起 comes from the voice pass (W3-7, release notes). Reverting it is a copy decision. Paging dots need a paged ScrollView. |
| B03 | pages/roam/index | permission | RoamBrowserView | mp shows 需要定位才能开始漫游 / 去设置 above the cards. Native roam home asks for an area and never checks location permission. | — | Needs a location-permission state on the roam home (logic). |
| B04 | pages/roam/index (summary) | empty | RoamLiveSessionView, RoamSummaryCelebration | mp finish report (0 家探店, 探索度/邮票/探索值/勋章, empty-track pill, 分享, 漫游记录). Native ends with a celebration overlay. | — | Structural: needs a full finish-report screen. |
| B07 | subpackageRoam/history | normal | RoamHistoryViews, RoamSubpageParityViews | strip was one line (次漫游·公里·家店), not the 次漫游/家店/用时 columns; total km had 1 decimal (mp 2); no month heads; RunCard had title before sketch, M/D/YY date below | NRC total columns (trips, shops, h:mm total from durSec, em dash if any unknown); 2-decimal km; `2026年8月` month heads; RunCard = sketch → route icon + title + `8月9日 周六 · 晚上` → stats → hairline + filled-star N 枚邮票 | mp remote-read banner (漫游记录读取失败…点此重试) has no native remote pager. |
| B08 | subpackageRoam/session | normal | RoamHistoryViews, RoamExperienceComponents, RoamSubpageParityViews | header 本次漫游 repeated inside the card; route name and completeFact (share-card content) inside the card; kv rows unitless; rewards rows lacked hex mark and 成就; empty-track copy | subtitle `date · time` under the title; 本次路线 card (eyebrow + date + replay); kv rows with hairlines and units (`6.8 公里`, `0 家`); 解锁奖励 hex + name + 成就; 点亮地点 hex rows; empty track 这次没有记录到连续轨迹 | — |
| B09 | subpackageRoam/session | missing-param | RoamHistoryViews | missing state had no way back | 找不到这次漫游 + 返回漫游历史 (dismiss) | — |
| B10 | subpackageRoam/citynode-code | missing-param | RoamSubpageParityViews | extra hint line | title + 返回 only | — |
| B11 | subpackageRoam/citynode-code | error | VerificationCodeView | native adds the voucher description and an authority footnote | — | Keep: the footnote is the native trust line ("showing a code does not mean redeemed"). |
| B12 | pages/play (city) | normal (state-unmet) | PlayExperienceView | node-lit interstitial (城市探索 / 城市线索已点亮 / 继续探索) | — | Play-kit interstitial; mock-only state upstream. |
| B13 | pages/play (free) | normal | PlayExperienceView | foil-pack opener | — | Structural (free-play opener animation). |
| B14 | pages/play (journal) | state-unmet | PlayExperienceView | not captured upstream | — | No reference. |
| B15 | pages/play (story) | normal | PlayExperienceView | station sheet: 第 N 站 + title + ×, art, text | — | Not re-laid out in this pass. |
| B16 | pages/play | success | PlayExperienceView | title was the topic name, subtitle generic, stats 站点/用时/探索值/勋章 with dashes, secondary 完成 | 主题通关 title; `{topic} · 获得 N 枚勋章`; only real stats (用时 h:mm:ss, 节点 done/total); 查看记录 + 分享战报 | 步行·公里 and 解谜分 need data the coordinator does not expose. |
| B90 | subpackageRoam/official-routes | normal | OfficialRouteViews | title 官方路线, mp 官方线路 | title 官方线路 | — |
| B91 | subpackageRoam/official-route | normal | E1OfficialRouteParts | native hero cover, stats and map CTA go beyond the mp's title / city·km / 节点(n) list | — | E1 design-pass decision; all mp sections are present. |
| B18 | pages/activity/detail | normal | ActivityDetailView | tickets header 选择票种 (mp 票种); reviews hidden behind 更多信息 (mp shows them on the first fold after 票种) | 票种 header; reviews + 写评价 + points note moved after the tickets on the first fold | Bottom bar 分享 lives in the toolbar (platform placement). |
| B19 | pages/activity/detail | joined | ActivityDetailView | same as B18; N 人已报名 avatars present | as B18 | — |
| B21 | pages/activity/detail | error | ActivityDetailView | mp renders a blank shell; native shows load-failed + retry | — | Native is better; no change. |
| B22 | pages/activity/baoming | form | RegistrationSheetView | title 活动报名 (mp 结算); header 参与人 (mp 参与人信息); activity card had no 活动信息 header; no 退款规则 tiers | 结算 title (zh; EN unchanged); 参与人信息 and 活动信息 headers | 退款规则 tier table needs refund-policy data. Payment stays gated. |
| B23 | pages/activity/baoming | error | RegistrationSheetView | failure banner 这次报名还没完成 + 重新提交 | — | Covered by existing outcome-unknown section; copy not re-aligned. |
| B25 | pages/activity/baoming | loading | RegistrationSheetView | skeleton under 结算 | title (via B22) | — |
| B26 | pages/activity/baoming | form | RegistrationSheetView | as B22 | as B22 | as B22 |
| B27 | pages/activity/list | normal | OfficialEventsBrowserView | segmented control (mp chip tabs); placeholder 搜索活动名或城市 (mp 搜索活动名称或城市) | chip tabs (capsules, selected solid, selection haptic); placeholder copy | 邀约 stays in the toolbar (documented: no WeChat capsule). |
| B28 | pages/activity/list | empty (我的) | OfficialEventsBrowserView | PNG shows 还没有参与的官方活动 + sub; mp source says 还没有参与的活动 with no sub | chips (as B27) | Copy: PNG and source disagree; native keeps its current line. |
| B29 | pages/activity/list | normal | OfficialEventsBrowserView | as B27 | as B27 | — |
| B30 | pages/activity/official-detail | ended | OfficialEventDetailView | sections already ported (detailParity) | — | — |
| B35 | subpackageA/infomation | normal | SocialGuideViews, SocialGuideXcxParity, SocialGuideTemplateSection | native hero line and 三种玩法 header; mode cards were gradient art with tag + description; template rows text-only with no 开始 | hero and header removed; mode card = icon disc + name + 去看看; template row = cover tile + name + desc + 已玩 N 次 + 开始; 更多玩法 only with rows | — |
| B36 | subpackageA/infomation | empty | SocialGuideTemplateSection, SocialGuideViews | 现成玩法 empty copy and CTA; 玩法文档 empty had an extra sub | 还没有上架的现成玩法 + 去发布广场; 暂无玩法说明 without sub; docs header without hint | — |
| B37 | subpackageA/infomationdetail | normal | SocialGuideViews | art banner header, summary line, inline title | plain title + time + hairline + 适用玩法版本暂未标注… disclaimer + hairline, then body; large nav title 玩法详情 | — |
| B38 | subpackageA/infomationdetail | loading | SocialGuideViews | shared read screen | — | — |
| B39 | subpackageA/infomationdetail | missing-param | SocialGuideViews | 链接不完整… without a back action | 链接已失效 + 返回 | — |
| B43 | subpackageA/myproject | normal (主题) | CreatorContentViews | three menu pickers (type/owner/state incl. 全部); tall image card | underline tabs 主题/活动/模板 (default 主题); row = cover tile + type/state + title + meta, hairline, `N 报名 · N 浏览` | Owner/state filters dropped as in the mp; merchant entry scope unchanged. |
| B44 | subpackageA/myproject | normal (模板) | MyProjectTabViews (via CreatorContentViews) | template shelf rows (节点玩法 / 广场已上架 / 通过 / 从广场下架 / 删除) | tabs (as B43) | Shelf row anatomy and write actions not re-checked; writes stay gated. |
| B45 | pages/publish/template-intro | normal | TemplateAuthoringIntroExperience | weights inverted (lead light, tail bold) | bold lead, lighter tail | Empty-examples line kept: a contract pins the visible empty state. |
| B48–B50 | pages/publish/fabu | form | ProjectEditView | mp light card wizard (主题详情 · 还有 N 项未填, 模式/票务 tiles, 章节, 保存草稿/下一步) vs native Form | — | Structural rebuild of a gated editor. |
| B51 | pages/publish/simple | form (state-unmet) | PublishingModesViews | no reference | — | — |
| B52 | pages/publish/temp | form | TemplateAuthoringView | 选择玩法 sheet (问答/推理/互动/挑战 chips, gameplay rows) | — | Gated editor; not rebuilt. |
| B53 | pages/publish/activity | form (club) | PublishingModesViews / ActivityPublishingWizardView | 基本信息 · 活动内容 · 票务与合作 stepper | — | Wizard is shared with the club domain; note for the owner. |
| B57 | pages/templatedetail | normal | DiscoveryTemplateDetailView | mp header (icon, name, creator), 应用 + share, 详情/能力 tabs | — | Tabs and 应用 need the template-use flow (gated). |
| B58 | pages/templatedetail | loading | DiscoveryTemplateDetailView | — | — | — |
| B59 | pages/template | normal (state-unmet) | DiscoveryTemplateBrowserView | one search 搜索主题与玩法模板 vs two scoped searches | — | Unifying needs a combined search (logic). |
| B60 | pages/play/circle | missing-param | PlayCircleRetiredLinkView | mp redirects to home | — | Dropped route, by design. |
| B62 | stamp-album | normal | RoamStampViews | mp 收集册 with 勋章/邮票/藏品 chips, `N 枚`, FAB + | — | Combined collection page needs routing across three screens; 集邮册 title is the voice-pass name. |
| B63 | stamp-album | empty | RoamStampViews | 还没有邮票 + 打开集邮相机 vs voice-pass 第一枚章在等你 + hint + camera | — | Voice-pass copy decision (ui-voice-pass receipt). |
| B64 | stamp-album | error | RoamStampViews | mp shows `0 枚` and nothing; native shows the error + retry | — | Native is better. |
| B65b | subpackageRoam/citystamp | normal (write) | RoamSubpageParityViews | copy (今日城市签, 给下一个来这里的人留一句, 投进信箱, drag hint) present | — | — |
| B65c | subpackageRoam/citystamp | normal (print) | RoamSubpageParityViews | slip already ported | — | — |
| B66 | badge-wall | normal | ObjectBadgeViews | WebGL wall vs native grid/showcase | — | 3D wall is a separate track. |
| B67 | badge-wall | empty | ObjectBadgeViews | 还没有徽章 (shared profile key); no 去探索 | 还没有点亮勋章 (own key) + 去探索 when the host supplies `growthExploreHomeAction` | — |
| B68 | growthcenter | normal | GrowthCenterView | mp: avatar + 积分, 总积分榜 row, 我的足迹 (探索值/徽章/完成路线/探索距离), 我的徽章; native adds missions, level, and has a different section set | — | Section set is a product decision; data for 完成路线/探索距离 not on the overview read. |
| B70–B73 | growthcenter/leaderboard | normal | GrowthLeaderboardView | metric picker before period; segmented controls; my rank as a top section; no podium | 周榜/总榜 chips first; podium 2·1·3 (initial disc, rank coin, name, score + unit); 积分榜/成长榜 chips between podium and rows; rows from 4th; my row last with 我 tag | Avatars render as initials (no remote avatar loader on this screen). |
| B74 | growthcenter/leaderboard | empty | GrowthLeaderboardView | both chip pairs above the empty state | both chip pairs shown above the empty state | — |
| B75 | growthcenter/leaderboard | error | GrowthLeaderboardView | mp blank under chips; native shows issue + retry | chips (as B74) | Native is better. |
| B76 | templatedetail/topic-preview | normal | DiscoveryTemplateDetailView (merged) | mp renders `[object Object]` (mp bug) + 查看详情 | — | Merged route; nothing to copy. |
| B78 | templatedetail/topic-detail | normal | DiscoveryTemplateDetailView (merged) | 应用 + share, 详情/能力 tabs, 剧情, 节点 grid | — | As B57. |

## Tests and pins changed
- `Tests/ContractChecks/test_activity_reviews.py`: reviews now sit on the first fold after the tickets (was: behind 更多信息).
- `Tests/ContractChecks/test_creator_content_contracts.py`: row artwork is `E1CoverArt` (was `QuestifyImageEntityCard`).
- `Tests/ContractChecks/test_object_badge_wall_layout.py`: wall empty key `badgeWall.empty`.
- `Tests/ContractChecks/test_social_guide_templates.py`: fragment now 9 keys; key scan also reads `CYEmptyState`/`actionTitle:`.
- `Tests/AppUITests/RegistrationWaitlistUITests.swift`: zh nav title 结算.
- `Tests/AppUITests/GrowthCenterFlowTests.swift`: chips are buttons, so the test taps the option directly.
- Localization ledgers kept in step: `docs/registration-ui-localizations.json`, `docs/release/ui-strings-pages-activity-baoming-baoming.json`, `docs/roam-experience-localizations.json`, `docs/official-event-localizations.json`, `docs/release/ui-strings-pages-activity-list-index.json`, `Resources/SocialGuideTemplateLocalizations.fragment.json`.

## Shared code touched (note for owners)
- `RoamRecordedStats` (RoamExperienceComponents) and `RoamSessionParityHeader` are used only by the session detail.
- `roam.experience.noTrack` copy changes everywhere the route sketch is empty.
- `tools/check_design_lint.py`: one allowlist line removed (file now clean).

## Contract-check comparison
I ran the 244 `Tests/ContractChecks/test_*.py` files that mention a changed App file or the string catalog against `origin/ui/next` @ 877127f72 and against this branch. After the ledger update above, both runs give the same result for every file. The failures that remain were already failing on the base.
