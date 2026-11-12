# U9 domain F receipt (ui/u9-f)

Screenshot-driven visual parity for every `F*` row in the 1c80c5a shot matrix whose role is not merchant (99 rows). Code only: no xcodebuild or simulator run in this lane; the integrator compiles. Each touched Swift file passed `xcrun swiftc -parse` (syntax only, not a type check). `tools/check_scaffold.py` and `tools/check_design_lint.py` pass. No files were added, so `tools/generate_project.py` was not needed. Mini-program screenshots were compared locally and are not committed.

New copy goes into `Resources/Localizable.xcstrings` as en + zh-Hans, taken from the mini-program zh source. Colours use CYNight and CYColor roles only. Existing accessibility identifiers are unchanged. New ones: `playkit.eyebrow.*`, `playkit.triesLeft`, `playkit.dailySign.ticket`, `playx.answer.option.*`, `playx.preference.option.*`, `playx.advanced.summary`, `playkit.submit.<sort|match|classify>`, and a few others. Money, merchant and password paths stay gated.

## Shared components (noted, not changed)

- `CYChoiceRow` (QA and branch rows): it has no A/B/C key column, which the mini-program shows.
- `PlatformAudioHost`: the music-corner waveform skin.
- `photoInput`: the retake CTA copy 再拍一张.
- Avatar stacks for advanced multiplayer members.

## Rows

| row id | route | state | native file | gaps found | fixed | left (needs logic or decision) |
|---|---|---|---|---|---|---|
| F01 | /pages/play/merchant/index | empty | App/PlayStoreDayMerchantEntry.swift | unresolved entry showed bare "playMode.unavailable" text | "链接已失效" empty state (link icon) centred | MP 返回 pill (native nav back used) |
| F02 | /subpackageP3/pages/badge-3d/index | error (3D fallback) | App/ObjectBadgeViews.swift | native has no 3D stage; static badge + name + status chips already shown | — | "静态预览" caption and "2026 限定" tag line need a 3D-capability decision |
| F04 | /pages/club/join-requests/index?clubId=1 | empty | App/ClubManagementView.swift | none: "暂无待审申请" empty state present | — | — |
| F09 | /pages/addressinfo/addressinfo | normal (create) | App/ParticipantFormView.swift | placeholders repeated the labels; CTA 保存参与人 | placeholders 输入姓名 / 输入手机号; CTA 保存参与人信息 | required asterisks on labels |
| F10 | /pages/shezhi/about/index | normal | App/SettingsAboutView.swift | no "我的二维码" section | "我的二维码" section with "玩家个人码待生成" placeholder | 联系我们 row (native shows contact phone only when configured) |
| F11 | /subpackageMember/coupon-wallet/index | normal | App/AccountCollectionCouponsView.swift | none material: 全部/待使用/已使用/已过期 pills and coupon cards present | — | — |
| F12 | /subpackageRoam/poi-detail/index | missing-param | App/RoamSubpageParityViews.swift | copy 找不到这个据点 vs 找不到这个节点; question-mark icon vs info icon | copy and info icon aligned; 返回地图 action already present | sheet presentation with 节点详情 title |
| F14 | /pages/team/detail/index?teamId=31 | normal | App/TeamHomeView.swift | none material: header, member stack, 邀请队友 primary, 公开招募, members, progress already match | — | — |
| F15 | /pages/team/join/index?code=demo_team_invite | normal | App/TeamHomeView.swift | none material: name, 当前成员 / 加入方式 card, join CTA present | — | — |
| F17 | /pages/club/topic-detail/index?topicId=7&clubId=42&activityId=701 | normal (director) | App/ClubTopicDetail+Port.swift | 核销 counters were three form rows; label 待核销 vs 待我核销 | three big-number tiles; 待我核销 copy | hero quick actions (商家/报名参与者/团码/更多) row and 台账 link are host layout in ClubGovernanceViews (partial page, needs routing decision) |
| F19 | /pages/club/roles/index?clubId=1 | empty | App/ClubOpsGovernanceSections.swift | none: 角色与权限 + 暂无成员 | — | — |
| F20 | /pages/club/governance/index?clubId=1 | empty | App/ClubOpsGovernanceSections.swift | none: 成员治理 + 暂无可治理成员 | — | — |
| F21 | /pages/club/event-ops/index?clubId=1 | empty | App/ClubOpsEventView.swift | none material: 还没有系列场次 empty present | — | "暂无可开场的主题" under 重复方式 depends on topic list wiring |
| F22 | /pages/club/notify/index?clubId=1 | form | App/ClubOpsNotifySections.swift | none material: audience, required title/content with counters, preview, send | — | — |
| F32 | /pages/play/index?mock=1 (timewindow) | normal | App/NativeMotionReminderViews.swift | kicker missing; open window shown as two Opens/Closes rows instead of one "开放时段 a – b" line; no big countdown to opening | kicker; single range line; HH:MM:SS countdown + 后开播 from the authoritative window | glyph circle; subscribe CTA stays the native local reminder (WeChat subscription has no native equivalent) |
| F33 | /pages/play/index?mock=1 (blindtaste) | normal | App/PlayKitLegacyViews.swift | kicker missing; no 1/2/3 step row; no "刚才那杯是哪一种？" prompt; options were bordered buttons, not keyed A/B/C rows; xpLabel not shown | kicker; numbered step row (领小样/闭眼尝/作答); question line; keyed thin-line rows with selected marker; xpLabel footer | press-and-hold eyes-closed stage flow (needs interaction design decision) |
| F34 | /pages/play/index?mock=1 (silentorder) | normal | App/PlayKitLegacyViews.swift | kicker missing; witness code after timer and without caption; timer labelled 用时 in a form row; give-up as red button "停止计时并说话" | kicker; rule → code + "见证码 · 店员猜中后扫这里" → "已表演 mm:ss" (lantern) → trailing "认输说话 →" | — |
| F35 | /pages/play/index?mock=1 (diyname) | normal | App/PlayKitLegacyViews.swift | kicker missing; no creation photo; suggestions above field with no label; CTA generic 提交 not ctaLabel | kicker; photoUrl artwork; field first; "猫向导递来几个备选：" + 「」 chips; CTA uses ctaLabel (fallback 提交作品) | photo beside title layout (sheet presentation) |
| F36 | /pages/play/index?mock=1 (musiccorner) | normal | App/PlayKitLegacyViews.swift | kicker missing; no 到点 pill; duration shown as "240 s" | kicker; 到点 success chip when arrived; m:ss duration | waveform player skin is the shared PlatformAudioHost (shared component, noted); 继续 CTA (native closes via nav) |
| F37 | /pages/play/index?mock=1 (steps) | normal | App/NativeMotionReminderViews.swift | goal shown as bare number; co2Label/remainLabel not shown | "/ N 步" goal; co2/remain lines when the segment carries them | live step count needs the HealthKit read flow (logic), big count only after reading |
| F39 | /pages/play/index?mock=1 (dailysign) | normal | App/PlayKitDecisionProgressViews.swift | address/lines/signer/date as loose text; no ticket header, date, serial, field labels | thermal-ticket card: 今日城市签 + date, 出发, 签号 NO. + 你是第几位, 留签人, 留于, 留给你的一句 (em dash for blanks) | printer slot animation; CTA copy 收下这张签 (native claim also carries the reply text) |
| F41 | /pages/play/index?mock=1 (slowtask) | normal | App/PlayKitLegacyViews.swift | kicker missing; days left as form row; ready copy differed; unlock text unframed | kicker; "还有 N 天" large; MP ready copy; unlock text in outlined card | reveal tap kept (MP uses scratch card; scratch gesture is a decision) |
| F42 | /pages/play/index?mock=1 (game text) | normal | App/PlayExperienceView.swift | question image never shown; cap as form row; hint button had no level | question image under the question; used hints as "提示 n"; "当前最高 N 解谜分" line; "看提示（n/2）" label | "实在解不出，揭示答案" reveal action on the base node (needs reveal endpoint wiring) |
| F43 | /pages/play/index?mock=1 (game photo) | normal | App/PlayExperienceView.swift | photo requirement text not shown on the stop | photoRequirement shown as the task line | taken-photo preview lives in PlayDeviceTaskSection (unchanged) |
| F44 | /pages/play/index?mock=1 (game choice) | normal | App/PlayExperienceView.swift | choices in a menu Picker | keyed A/B/C option cards, selected one filled; question image | — |
| F45 | /pages/play/index?mock=1 (game scan) | normal | App/PlayExperienceView.swift | no "扫描现场的二维码" line | scan prompt line on scan stops | dashed scan frame illustration |
| F46 | /pages/play/index?mock=1 (preference) | normal | App/PlayPreferenceViews.swift | no "装机校准 i / n"; options in a menu Picker | step counter; option cards with check | one-question-at-a-time paging with 下一题 (flow logic) |
| F47 | /pages/play/index?mock=1 (advanced random) | normal | App/PlayAdvancedView.swift | status shown raw (RUNNING) plus internal version row | summary strip: localized status + 得分 N; version row removed | draws render inside the random kit screen, not inline in the sheet (navigation structure) |
| F48 | /pages/play/index?mock=1 (advanced branch) | normal | App/PlayAdvancedView.swift | same summary gap | summary strip | branch options open in the branch kit screen (structure) |
| F49 | /pages/play/index?mock=1 (advanced multiplayer) | normal | App/PlayAdvancedView.swift + PlayAdvancedTeamViews.swift | same summary gap; members/roles/progress already present | summary strip | member avatars (shared avatar component) |
| F50 | /pages/play/index?mock=1 (advanced leaderboard) | normal | App/PlayAdvancedView.swift | same summary gap; board rows already present | summary strip | — |
| F52 | /pages/play/index?mock=1 (club game player) | normal | App/PlayPlayerAndCircleViews.swift | title 玩家会话 not 本局线索; role header 你的角色; task prompt unlabelled; hint impact ("查看会减少 10 分") read but never shown; revealed hints unnumbered | title/role copy; 本站任务 label; impact lines under hint/reveal; "提示 n · …" | role card "状态更新于 hh:mm" timestamp (needs projection time); node state is raw server text |
| F53 | /pages/club/customers/index?clubId=42 | normal (state-unmet) | App/ClubOpsCustomerViews.swift | none material: count line, 全部/回头客/新客/有备注 chips, search, rows | — | — |
| F54 | /pages/club/customer-detail/index?clubId=42&memberId=41 | permission (no amount) | App/ClubOpsCustomerViews.swift | none material: 累计实付 shows 无查看权限; overview tiles, records, tags | — | money stays gated |
| F55 | /pages/play/index?mock=1 (reaction) | normal | App/PlayKitTimedChallengeView.swift | no local-measurement footnote | "本机测量读数…" footnote | full-screen red/green stage colour (CYNight has no stage red; decision) |
| F56 | /pages/club/topic-detail/index?topicId=9&clubId=42 | normal (running, state-unmet) | App/ClubTopicDetail+Port.swift | same as F17 | same tiles | same as F17 |
| F57 | /pages/club/topic-story/index?topicId=9&clubId=42 | normal (route, state-unmet) | App/ClubGovernanceViews.swift | none material: 剧情与玩法 title, 路线/玩法 tabs and stop cards present | — | walking-time connector between stops |
| F58 | /pages/club/settlement/index?clubId=42 | permission (ready) | App/ClubOpsSettlementViews.swift | none material: 已入账分润, per-topic cards present | — | "商家计酬 · 俱乐部直接付款" mode card copy missing; withdrawal stays gated (money) |
| F59 | /subpackageRoam/nearby/index | normal (state-unmet) | App/NearbyTeamViews.swift | MP shot shows only chips + map/list switch (list not rendered); native has discovery filter controls and view-mode picker | — | exact chip set 全部/主题队伍/地点玩法▾/商家▾ lives in NearbyMapDiscoveryControls (unchanged) |
| F60 | /pages/club/checkin-detail/index?clubId=1&registrationId=1 | normal (verified) | App/ClubCheckinRailView.swift | none material: head, ticket card, six rows and 4-stop rail already match | — | ticket cover thumbnail on the card; extra registrationId fact row kept |
| F61 | /pages/club/checkin-detail/index?clubId=1&registrationId=2 | normal (refunded) | App/ClubCheckinRailView.swift | same as F60 | — | refund dispatch stays gated (money) |
| F62 | /pages/club/checkin-detail/index?clubId=1&registrationId=3 | empty/denied (state-unmet) | App/ClubCheckinRailView.swift | denied title read 无权查看该核销记录, MP 核销记录不可见 | denied copy aligned | MP shows it as a bottom result sheet |
| F63 | /pages/play/index?mock=1 (branch) | normal | App/PlayKitQuestionForms.swift | none material: title/body/option rows present | — | — |
| F64 | /pages/play/index?mock=1 (estimate) | normal | App/PlayKitQuestionForms.swift | tries rows | tries-left dots via shared helper | CTA 就这个数 is inside the wheel form |
| F65 | /pages/play/index?mock=1 (pricepair) | normal | App/PlayKitQuestionForms.swift | tries rows | tries-left dots | coloured tile palette (decision) |
| F66 | /pages/play/index?mock=1 (hidden) | normal | App/PlayKitQuestionForms.swift | tries rows | tries-left dots | — |
| F67 | /pages/play/index?mock=1 (predict) | normal | App/PlayKitQuestionForms.swift | reveal days/hour rows present; tries | tries-left dots | tilted card carousel |
| F68 | /pages/play/index?mock=1 (random) | normal | App/PlayKitDecisionProgressViews.swift | deck name as big title; latest card unmarked | deck name as kicker; "这一关" chip on latest card | 换一张/就这张 swipe deck (native draw is server-side, flow differs) |
| F69 | /pages/play/index?mock=1 (bingo) | normal | App/PlayKitDecisionProgressViews.swift | line reward as form row; no filled count or footnote | "连成一条线 · reward" banner; "已完成 n / 9"; footnote | chessboard tinting per cell kind |
| F70 | /pages/play/index?mock=1 (scan) | normal | App/PlayKitPersonalForms.swift | no scope sub-line | "仅确认这一站的任务码" | scanner frame illustration lives in PlayKitScanInput |
| F71 | /pages/play/index?mock=1 (walk) | normal | App/PlayKitDecisionProgressViews.swift | steps/remaining/goal as form rows | lantern "还差 N 步" hero with bar and "a / b · p%"; 目标/已走/少排 tiles (em dash when unknown) | 同步微信运动 CTA has no native equivalent (provider gate kept) |
| F72 | /pages/play/index?mock=1 (coinflip) | normal | App/PlayKitDecisionProgressViews.swift | no "抛一次，认结果" kicker; no shake hint | kicker; "摇一摇手机" hint under the CTA | metal coin artwork / flip animation |
| F73 | /pages/play/index?mock=1 (diceroll) | normal | App/PlayKitDecisionProgressViews.swift | no kicker; total as a form row; no "5 + 4" line | kicker; large centred total; sum line; shake hint | 一颗/两颗 count toggle (authoring config, not player choice in native) |
| F74 | /pages/play/index?mock=1 (ballshake) | normal | App/PlayKitSensorChallengeView.swift | no "撞够 N 次" kicker or "N 秒内撞满" | kicker + limit line | — |
| F75 | /pages/play/index?mock=1 (quiethold) | normal | App/PlayKitSensorChallengeView.swift | no "别出声" kicker; relative-volume note missing | kicker; relative-volume note | green stage tint |
| F76 | /pages/play/index?mock=1 (countdown) | normal | App/PlayKitTimedChallengeView.swift | none material (big clock + 开始 already) | — | — |
| F77 | /pages/play/index?mock=1 (stopwatch) | normal | App/PlayKitTimedChallengeView.swift | no local-measurement footnote; no tries-left dots | footnote | "还能错" dots for stopwatch need the tries field on this segment (shared attempts helper not used here) |
| F78 | /pages/play/index?mock=1 (qa pick) | normal | App/PlayKitQuestionForms.swift | tries shown as two count rows, not "还能错 ●●" | shared attempts helper renders "还能错" dots (qa, estimate, blind taste, predict…) | A/B/C letter column comes from the shared CYChoiceRow (shared component, noted) |
| F79 | /pages/play/index?mock=1 (qa type) | normal | App/PlayKitQuestionForms.swift | same tries gap | tries-left dots | — |
| F80 | /pages/play/index?mock=1 (qa shot) | normal | App/PlayKitQuestionForms.swift | shotNote present; no change | — | large centred prompt styling |
| F82 | /pages/play/index?mock=1 (profile) | normal | App/PlayKitPersonalForms.swift | no 出生登记 summary card; all questions at once | — | one-question paging + summary card (flow logic) |
| F83 | /pages/play/index?mock=1 (photocheck) | normal | App/PlayKitPersonalForms.swift | retry state had reason only | "还差一点，再拍一张" headline + reason | CTA copy 再拍一张 lives in shared photoInput |
| F83a | /pages/play/index?mock=1 (photocheck card) | normal | App/PlayKitPersonalForms.swift | state-unmet in matrix; card mode already shows card + name | — | — |
| F84 | /pages/play/index?mock=1 (note) | normal | App/PlayKitPersonalForms.swift | no "前面的人写过" label; presets as full-width choice rows above the field | label; presets as small chips under the field | CTA copy 留下这句 (generic 提交) |
| F85 | /pages/play/index?mock=1 (typein) | normal | App/PlayKitTimedChallengeView.swift | target text unboxed; no "N 秒内一字不差地打完它" | boxed target; goal line | — |
| F86 | /pages/play/index?mock=1 (sort) | normal | App/PlayKitReasoningForms.swift | generic 提交; plain result text | "就这个顺序" CTA; tinted result banner; italic index | drag handle reorder (up/down kept for accessibility) |
| F87 | /pages/play/index?mock=1 (match) | normal | App/PlayKitReasoningForms.swift | generic 提交; plain result text | "连好了"; banner | two-column tap-to-link board (menus kept) |
| F88 | /pages/play/index?mock=1 (classify) | normal | App/PlayKitReasoningForms.swift | generic 提交; remaining as form row | "分好了"; "还有 N 条没分 · 分完才能提交"; banner | card-stack + bins board (menus kept) |
| F90 | /pages/play/index?mock=1 (compass idle) | normal | App/PlayKitSensorChallengeView.swift | no "把手机转向目标方向" kicker | kicker | dial artwork with tick marks (existing gauge kept) |
| F91 | /pages/play/index?mock=1 (compass done) | normal | App/PlayKitSensorChallengeView.swift | same kicker gap | kicker | — |
| F92 | /pages/play/index?mock=1 (scan overlay) | normal | App/PlayKitPersonalForms.swift | same sub-line gap | sub-line | in-page camera viewfinder for 显形 (camera overlay button kept) |
| F93 | /pages/play/index?mock=1 (shout) | normal | App/PlayKitSensorChallengeView.swift | no kicker | "一起喊，让这儿听见" kicker | — |
| F94 | /subpackageP3/pages/object-cards/index/index | normal (state-unmet) | App/ObjectCardViews.swift | none material: 收集册 with 勋章/邮票/藏品 tabs and filter | — | — |
| F95 | /pages/play/index?mock=1 (album) | normal | — | no album kit in native PlayKitScreenKind | — | album kit (new kit type; needs Core decision) |
| F96 | /subpackageRoam/my-teams/index | normal (approved) | App/NearbyTeamViews.swift | stats row, 已通过 group, team card present; tab labels/order differ (native 附近/我的, MP 我的/附近招募 · n) | — | tab order and 加入码/地图 header pills (navigation structure decision) |
| F98 | /subpackageTools/monthly-recap/index | normal | App/RoamPassportToolsViews.swift | none material: month switcher, hero count, 首次地点/城市签, chips, empty line present | — | — |
| F99 | /subpackageTools/exploration-goals/index | normal | App/RoamPassportPrivateToolsViews.swift | none material: 我的目标 count, progress card, add button | — | — |
| F100 | /subpackageTools/anniversary/index | normal | App/RoamPassportToolsViews.swift | none material: big date, 换一天, n 年前 card, 查看当前路线 | — | — |
| F101 | /subpackageTools/exploration-export/index | normal (state-unmet) | App/RoamExplorationExportView.swift | none material: start/end (不含) range, 准备导出 | — | — |
| F102 | /pages/club/badges/index?clubId=1 | empty | Resources/ClubBadge.xcstrings | copy said 徽章 (MP 勋章) and empty line ended with 。 | club badge table uses 勋章; empty "还没有俱乐部勋章" | club name subtitle under the title |
| F103 | /pages/play/index?mock=1 (hangman) | normal | — | no native screen (UG-01 pack is NOT_RUN in Core/UGGameplayReader.swift) | — | whole screen: needs UG pack enablement decision |
| F104 | /pages/play/index?mock=1 (accusation) | normal | — | no native screen (UG-03 NOT_RUN, accusationPublishable = false) | — | whole screen: needs UG pack enablement decision |
| F200 | /pages/play/poi-challenge/index | missing-param (state-unmet) | App/ChallengePOIView.swift | failure title 加载挑战失败 vs 挑战暂时打不开 | failure title aligned | native always opens with a node, so the "没有找到这个地点" missing-param branch is unreachable; 返回地图 secondary |
| F201 | /pages/shezhi/marketing/index | normal | App/MarketingConsentOriginalPresentation.swift | MP shot shows title only (content not rendered); native consent toggles present | — | — |
| F202 | /pages/play/index?mock=1 (compare) | normal | App/PlayCompareView.swift | generic 提交 CTA | "就标这些" CTA | — |
| F300 | /subpackageA/pages/video-bounty/index | missing-param | App/VideoBountyView.swift | none: 我的投稿/播放与应计 tabs + 读取失败 + 重试 present | — | accruals are money (gated) |
| F301 | /pages/topic/catalog/index | normal | App/PublicCatalogViews.swift | none material: 城市目录 title, category chip, cover cards | — | — |
| F302 | /pages/topic/catalog/detail | missing-param | App/PublicCatalogViews.swift | none: 作品已下架或未公开 empty state | — | — |
| F304 | /subpackageMember/market/passes/index | normal | App/PassMarketViews.swift | none material: 可购买/我的订单/礼品 tabs, pass card with price | — | purchase stays gated (money) |
| F305 | /subpackageMember/market/pass/index | missing-param | App/PassMarketViews.swift | none: 商品不存在或已下架 + 重试 | — | — |
| F306 | /subpackageMember/market/gift/index | missing-param | App/PassMarketViews.swift | none (same missing pattern) | — | — |
| F307 | /subpackageMember/market/membership/index | normal | App/PassMembershipViews.swift | none: 通行证暂未开放 empty state | — | — |
| F308 | /subpackageMember/market/library/index | normal | App/PassMembershipViews.swift | none material: 游戏主题库, 全部/城市定向/自由探索 chips, cover card with ¥0 可玩 + city | — | — |
| F309 | /subpackageJourney/pages/report/index | missing-param | App/JourneyReportViews.swift | none: 链接已失效 empty state | — | — |
| F310 | /subpackageJourney/pages/landing/index | missing-param (guest) | App/JourneyLandingViews.swift | none: 链接已失效 empty state | — | — |
| F311 | /subpackageJourney/pages/seats/index | missing-param | App/JourneyLandingViews.swift | none: 链接已失效 empty state | — | — |
| F312 | /subpackageJourney/pages/promo/index | missing-param | App/JourneyLandingViews.swift | none: 邀请与收益 + 收益暂未加载 + 重新加载 | — | earnings are money (gated) |
| F313 | /subpackageJourney/pages/settle/index | missing-param | App/JourneyLandingViews.swift | none: 结算 + 链接已失效 | — | — |
| F314 | /subpackagePass/reveal/index | normal | App/PassMembershipViews.swift | none material: key reveal with 跳过 | — | — |

Total rows: 99.

## Left for decision or logic (summary)

- F103 hangman and F104 accusation have no native screen: the UG-01 and UG-03 packs are NOT_RUN in Core. F95 album has no native kit type.
- Step-by-step paging, as in the mini-program, for profile (F82) and preference (F46). Blind-taste hold-to-close-eyes stage (F33).
- Mini-program bottom-sheet-over-pack presentation for legacy kits, and full-screen stage tints for reaction and quiet-hold.
- Base node reveal action (F42), club topic hero quick actions (F17/F56), and my-teams tab order (F96).
- Pass detail missing-id title 商品不存在或已下架 (F305/F306): native falls back to 加载失败, and the missing-id path is not distinguished from a network failure.
