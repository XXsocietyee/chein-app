# Receipt: fix/r3-club-a (Claude F-agent, club, first half)

- **Brief:** `design/handoff-r2:docs/briefs/wave-x10.md`. App/ layer only; Core and Tests/ requests are listed for Cursor.
- **Base:** `origin/ui/combined-r7` (7fdfad1f1), with `origin/restyle/r2-club-social` (bc5a58dfe) merged first because it already touches the club files (the merge was clean).
- **Pages (first half of the round-1 audit list):** detail, topic-detail, topic-story, event-ops, governance, roles, apply, create, enroll, edit.
- **Gap sources used:** `audit/parity-r7-club:docs/audit/parity-r7/club.md` (fix queue), `review/r7-rev-{a,b,c}` (none of their club rows are App-layer for these pages), the round-1 audit `audit/parity-club`.
- **No compiler in the cloud.** Every type, modifier and initializer used was grepped on the branch first (see "APIs relied on" below). The coordinator's build is the first compile.
- **Strings:** `docs/port/strings/fix-r3-club-a.json`. Some keys are **value overrides of existing keys** (marked below); the integrator should let the fragment win.
- **Acceptance routes:** `docs/port/accept/f-club-a.txt`.

## Fixed

| id | what changed | files |
|---|---|---|
| CLB-detail-32 | System navigation bar and system back always visible (`cyPushedChrome`); the glass `CYHeroBackButton` and the duplicate share on the cover are gone; the inline club name still appears once the hero scrolls away. | App/ClubDetailView.swift; Tests/ContractChecks/test_global_chrome_domain_contract.py (pin flipped to the new rule) |
| CLB-detail-27 | A merchant account (`account.effectiveRole == "merchant"`) sees the club page in the `.merchant` light domain. | App/ClubDetailView.swift |
| CLB-detail-31 | `postId` deep link: the detail opens on 帖文, pushes the feed, and scrolls to that post (`ScrollViewReader`, once per appearance). | App/MPReviewedPageScreen.swift, App/ClubDetailView.swift, App/ClubCommunityViews.swift |
| CLB-detail-20 | 发布 on 活动 for owner **or** access/me `club:activity:manage`. | App/ClubDetailView.swift |
| CLB-r7-A-01 | Activity card tap: governors / activity managers open the club topic-detail (`.topicOverview`), others the ordinary topic page (MP goTopic). | App/ClubDetailView.swift |
| CLB-detail-21 | 概览: intro first with no 俱乐部介绍 header, then the 俱乐部勋章 row; 活动偏好 / 关键词 / 风格 rows removed. | App/ClubDetailView.swift |
| CLB-detail-22 (copy part) | 需审核 clubs say 通过审核后可看贡献榜. | App/ClubDetailView.swift; strings |
| CLB-detail-37 | Cover 160, logo 56. | App/ClubDetailView.swift |
| CLB-detail-40 | Welcome title `.sheetTitle`. | App/ClubMemberWelcomeSheet.swift |
| CLB-detail-41 | Invite row glyph `.cyText(.bodyMedium)`. | App/ClubMembersView.swift |
| CLB-detail-19 | The 活动 tab's embedded list has no 当前活动 header and no time-zone helper line (ended activities were already excluded). | App/ClubActivityListContent.swift, App/ClubPublicActivityListView.swift |
| CLB-r7-A-02 | 概览 shows 成员身份暂时无法确认，管理员工具暂不可用。 when the detail says `viewerIdentityUnavailable`. | App/ClubDetailView.swift; strings |
| CLB-r7-A-03 | 治理与安全 · 封禁申诉 row on 概览 for owner/admin, opening the club's cases. | App/ClubDetailView.swift; strings |
| CLB-r7-A-05 | 结算 entry on 管理 for the owner (settlement read). | App/ClubDetailView.swift; strings |
| CLB-topic-detail-02 (resubmit part) | Rejected topic: 修改并重新提交 opens the topic editor by id (`pages/publish/fabu?id=` → native ProjectEditView via MPReviewedPageScreen). | App/ClubGovernanceViews.swift |
| CLB-topic-detail-07 (gate part) | 管理场次 shows only when topic-manage-stats grants `canManageSessions`. | App/ClubGovernanceViews.swift |
| CLB-topic-detail-08 | Hero: cover (no block when none), merchant logo, name as `.cyText(.pageTitle)`, one date-range line, verify-mode line (玩家可到店核销 fallback when a merchant logo is present). | App/ClubGovernanceViews.swift; strings |
| CLB-topic-detail-16 | Name carries `.isHeader`. | App/ClubGovernanceViews.swift |
| CLB-topic-detail-13 / CLB-governance-19 | Governance workspace sheet and the command-form sheet open `.large` only. | App/ClubGovernanceViews.swift |
| CLB-topic-story-02 | One 查看答案 (sheet) per gameplay, in a borderless row with 看看模板; the「弹窗查看答案」and「请先刷新剧情数据」literals are gone (stale source → localized toast). The push destination stays in code because contract tests pin it. | App/ClubGovernanceViews.swift |
| CLB-topic-story-03 (title part) | Answer sheet title 答案 · <node name>. | App/ClubGovernanceViews.swift; strings |
| CLB-topic-story-06 | MP copy 暂无路线 / 这一章还没有节点 / 未填写地址 and the answer notice. **Value overrides.** | strings |
| CLB-topic-story-09 | Answer notice `.cyText(.meta)`. | App/ClubNodeAnswerContent.swift |
| CLB-governance-11 | MP governance link: report → report form seeded with targetType / targetId / label; manage → 成员治理 (`.bans`); appeal → cases. | App/MPReviewedPageScreen.swift |
| CLB-governance-12 | After an acknowledged 转让主理人, the form leaves after 1.5 s (MP js:584-605). | App/ClubGovernanceCommandForm.swift |
| CLB-governance-05 | 封禁 / 解封 / 填写事实并提交平台 / 填写理由并提交申诉. **Value overrides.** | strings |
| CLB-governance-02 | 解封 is a borderless inline link (new `inlineLink` action role), 44 pt. | App/ClubGovernanceViews.swift |
| CLB-governance-18 | VoiceOver labels name the member on 解封 / 封禁 / 转让 / 撤销. | App/ClubOpsGovernanceSections.swift; strings |
| CLB-roles-05 | 可委派角色 list removed. | App/ClubGovernanceViews.swift |
| CLB-roles-03 | Monogram avatar (`CYAvatarView` .sm) on role-picker member rows (the read has no avatar URL). | App/ClubRoleAssignmentPicker.swift |
| CLB-apply-02 | The host-apply form opens at step 1 (the intro is on the host-status page). | App/ClubGovernanceCommandForm.swift |
| CLB-apply-09 | 关闭 stays in the bar on every step; 上一步 is a secondary button in the bottom actions. | App/ClubGovernanceCommandForm.swift |
| CLB-apply-04 (part) | Merchant state: 查看商家入驻 (opens `pages/merchant/apply/index`) + 返回. | App/ClubGovernanceViews.swift; strings |
| CLB-apply-08 | Guest state 登录后申请成为主理人 + 登录 (switches to 我的). | App/ClubGovernanceViews.swift; strings |
| CLB-create-03 (guest + error) | Guest → 登录; failed check → 重新检查. | App/ClubOperationsViews.swift; strings |
| CLB-create-02 | Success line uses `.cyText` (no raw `.headline`) and adds 名称 · 城市. | App/ClubOperationsViews.swift |
| CLB-edit-06 | Raw `.title2` / `.subheadline` / `.footnote` → `.cyText`. | App/ClubOperationsViews.swift |
| CLB-edit-08 | Quota reads with 「个」. | App/ClubOperationsViews.swift; strings |
| CLB-edit-09 | 放弃本轮修改？ / 确认放弃 / 继续编辑. **Value overrides.** | strings |
| CLB-enroll-05 | 团状态 row removed (MP removed it). | App/ClubEnrollmentView.swift |
| CLB-enroll-06 | Cover side 72; chevron `.cyText(.label)`. | App/ClubEnrollmentView.swift |

### Value overrides in the strings fragment
`club.story.noRoute`, `club.story.noStops`, `club.story.addressUnavailable`, `club.story.answer.notice`, `club.gov.action.ban`, `club.gov.action.unban`, `club.gov.action.report`, `club.gov.action.appeal`, `club.ops.discardTitle`, `club.ops.discard`.

## Left, with reasons

| id | reason |
|---|---|
| CLB-detail-14 (inline feed) | The feed is a ScrollView/LazyVStack screen with its own pagination, composer and destinations; embedding it in the detail `List` without a compiler risks layout and lifecycle regressions. The postId path (detail-31) now pushes it automatically. Next round, with a build. |
| CLB-detail-35 (团码 on cards) | Needs the session picker + `ClubGroupCodePresentation` on the detail; overlaps CLB-group-code-05 (Gemini). |
| CLB-detail-22 (inline top rows + 我 row) | Needs the leaderboard read on the detail page; the avatar strip is parked (G08). |
| CLB-detail-43, -39, r7-A-06, r7-A-08 | Not reached this round (P2). r7-A-08 needs an `api/club/my` read in the router. |
| CLB-topic-detail-02 (pinned footer) | Moving `topicPrimary` into `.safeAreaInset` means restructuring the read view's List; left for a compiled round. |
| CLB-topic-detail-05, -06, -10 | Round actions with native sheets (M), toggle rows that write with rollback (M) and the customer rows: not attempted without a compiler. -06's more-menu rows are parked (G12). |
| CLB-topic-detail-11 | **Cursor request:** `ClubTopicMerchantList` strips contact fields; the copy-phone button needs a `phone` on `ClubTopicMerchantRow` (only when the merchant confirmed). |
| CLB-topic-detail-14, -15 | P2, not reached. |
| CLB-roles-02 | The session role page names the session: 「活动名 · 开始时间」 from the topic page's session rows (`ClubGovernanceEventView.activityLabel`) or the MP `activityLabel` query, and 未命名 otherwise. The id is never shown. | App/ClubRoleAssignmentPicker.swift, App/ClubGovernanceViews.swift, App/MPReviewedPageScreen.swift |
| CLB-topic-story-01 | `ClubGovernanceStoryView` binds to a parent read view's snapshot; opening it directly needs a small host that owns the overview read. Next round. |
| CLB-topic-story-03 (loading/error copy) | The sheet hosts `ClubGovernanceReadView(.nodeAnswer)`, which shows the shared loading/failure states. |
| CLB-topic-story-08, -10 | P2 layout, not reached. |
| CLB-event-ops-02 | Inline roster on the hub (M). Not attempted without a compiler. |
| CLB-event-ops-03 | **Cursor request:** `ClubRosterPresentation` requires `phoneIncluded == false`; a `tel:` call needs the roster phone in Core first. The rest is parked (G15). |
| CLB-event-ops-09 | Adding `trailing: .chevron` inside a `NavigationLink` in a List draws a double chevron; needs a visual check. |
| CLB-governance-01, -03 | Single-page governance layout and skipping the fact review for ban/unban/transfer/report/appeal change the command-form flow (M); left for a compiled round. |
| CLB-governance-04, CLB-roles-07, CLB-roles-10 | Copy lives in `Resources/OpsR3.xcstrings` / `ClubOpsGovernance.xcstrings` (not Localizable). **Integrator request:** `r3club.consequence.ban.title` 确认封禁这位成员, `.line1` 封禁后对方立即失去成员身份与群聊入口。, `.line2` 解封只恢复申请资格，成员身份不会自动恢复。, `.confirm` 确认封禁; `r3club.consequence.revokeRole.title` 撤销这个角色？, `.confirm` 撤销角色; `clubOpsGov.roles.empty` 暂无成员. |
| CLB-governance-16, CLB-G16 | P2, not reached. |
| CLB-roles-02, -04 | Activity label plumbing into the picker scope and the inline assign rows (M). Not reached. |
| CLB-r7-C-03 | P2, not reached. |
| CLB-apply-04 (切换到商家端) | The app has no account-side switch API reachable from this view; 查看商家入驻 is offered. |
| CLB-apply-06, -07 | Wizard kit reuse and persistent labels (M/S); not reached. |
| CLB-apply-10, CLB-create-07 | ChannelCopy / locale literals live in Core (`ClubPlayerFlows.swift`); **Cursor request** to move them to xcstrings. |
| CLB-apply-11 | 主理人 <leaderName> comes from the submission receipt only; not reached. |
| CLB-create-03 (limit → 管理我的俱乐部) | Needs a ClubDetailView reader inside the operations workspace; not reached. |
| CLB-create-06, CLB-edit-01, -05 | Inline create/save without the review sheet changes the operations flow (M); left for a compiled round. |
| CLB-edit-03 | `ClubOperationsFlowTests` pins `club.ops.member.704`; removing the legacy 设为管理员 block needs those UI tests updated in the same change (do it with edit-01). |
| CLB-edit-07 | Not reached. |
| CLB-enroll-02 | `ClubEnrollmentFlowTests` pins the profile tap on `club.enroll.profile.121`; swapping the tap to 核销详情 needs the tests updated together. |
| CLB-enroll-08 | Needs an `api/club/my` read in the router. |
| Cursor-owned rows (detail-30, -26, topic-detail-09, topic-story-05, event-ops-05/-06, r7-C-01, enroll-04, …) | Core; not touched. |

## In-flight branches (skipped)
- `restyle/r2-club-social`: merged first (type, spacing, radius only).
- `gap/g2-ops` parked `App/MPGap/Club` views (G01, G02, G04–G06, G08, G10, G12, G13, G15, G17, G19): not mounted here; mounting is the integrator's / Gemini's.
- `cursor/*`, `port/*`: no club-file overlap found.

## APIs relied on (grepped on the branch)
`cyPushedChrome(domain:)`, `cyTracksHeroScroll`, `ThemeDomain.merchant`, `Account.effectiveRole`, `ClubDetailManageGrant.permissions`, `ClubGovernanceReadView(operation:scope:identity:access:coordinator:)`, `ClubGovernanceScope(clubID:topicID:…)` defaults, `ClubGovernanceRead.cases/.settlement/.bans/.topicOverview`, `MPReviewedPageScreen(page:query:)` (needs `AppSession` as an environment object, as in PassMarketViews), `ClubGovernanceFormRoute(operation:scope:seed:)`, `ClubGovernanceValue.string/.integer`, `CYEmptyState(systemImage:_:messageIdentifier:actionTitle:actionIdentifier:actionStyle:action:)`, `rootTabSwitch.isAvailable` / `rootTabSwitch(.mine)`, `CYAvatarView(url:name:size:)`, `CYSheetDetent.full`, `CYMotion.standard`, `QuestifyCardArtwork.safeURL`, `CYColor.bgSurfaceSubtle`, `CYTextStyle` cases.

## Checks run here
- **Contract checks (Python) for every test that names a changed club file**, run on this branch:
  - Four source pins changed on purpose and were updated with the code: `test_global_chrome_domain_contract` (club page keeps the system bar), `test_club_ops_governance` (unban `inlineLink` role and its VoiceOver label), `test_club_member_pages` (`lockedCurrent.cyText(.meta)`), `test_club_detail_tabs` (`focusPostID` lands on 帖文), and the span hash in `test_club_leaderboard_member_navigation` (the apply guest state joins that span). These are Tests/ edits; Cursor may want to re-pin them in its own style.
  - Still failing, and failing the same way on the base `ui/combined-r7`: `test_club_customer_directory_remote_admission`, `test_club_operations_contracts`, `test_club_customer_keyword_debounce`, `test_profile_read_failure_remote_admission`, `test_category_roam_registration`.
  - `tools/check_typography_lint.py`: PASS. `tools/check_scaffold.py`: fails identically on the base.
- **No Swift build** (no compiler in the cloud). Acceptance run: pending the coordinator's build.

## Round 2 (2026-11-24)

- **Brief:** `design/handoff-r2:docs/briefs/fix-r3-round2.md`, with `wave-x10.md` and `owner-decisions-1124.md`.
- **Sync:** merged `origin/ui/combined-r7` (Core K1–K10, W1 wiring, C7 MP assets). One conflict, `tools/check_typography_lint.py`; the newer r7 version was taken. Re-merged before the final push.
- **Strings:** `docs/port/strings/fix-r3-club-a.json` is now in xcstrings format (`sourceLanguage` + `strings`, en and zh-Hans). The round-1 keys were converted unchanged. Round-2 keys are listed below. `test_localization_key_catalog_contract` fails on this branch only because these keys sit in the fragment and not yet in `Resources/Localizable.xcstrings`; it passes once the integrator merges the fragment.
- **Shared App helpers (new file, `App/*.swift` glob):** `App/ClubMPAssetViews.swift` holds `ClubMPAvatar`, `ClubShareURL`, `ClubDirectionIcon` / `ClubDirectionLabel`, `ClubMoneyText`, `ClubHostApplyFieldCopy` and the `clubDissolveAcknowledged` environment key.

### MP assets (`docs/mp-assets/mapping.md`, `MPAsset.<name>`)

| mapping row | applied in | how |
|---|---|---|
| [x] `MPAsset.BannerCover.clubCoverDefault` | App/ClubDetailView.swift (`ClubDetailCover`) | no club cover → the MP default cover (detail wxml:35) |
| [x] `MPAsset.BrandLogo.dLogo` | App/ClubDetailView.swift | no club logo → `d_logo.png` (detail wxml:48) |
| [x] `MPAsset.BannerCover.routeFreeCover` | App/ClubActivityListContent.swift | 活动 card without a cover → `route_free_cover.png` (detail wxml:169) |
| [x] `MPAsset.BannerCover.routeCityCover` | App/ClubEnrollmentView.swift | team cover fallback (enroll wxml:37) |
| [x] `MPAsset.AvatarDefault.dProfile` | App/ClubEnrollmentView.swift, App/ClubMembersView.swift, App/ClubPublicRosterView.swift, App/ClubRoleAssignmentPicker.swift, App/ClubOpsGovernanceSections.swift (members + role assignments) | every club `cy-avatar` fallback, through `ClubMPAvatar` (a real HTTPS avatar still uses `CYAvatarView`) |
| [x] `MPAsset.FeatureIcon.coffee / voice / gameHandle / footprints / dices / drama / sport / platte / noodles / music` | App/ClubKit/ClubCreateKit.swift (`ClubR1Chip` icon), App/ClubOperationsViews.swift (create chips, edit toggles), App/ClubProfileChoiceEditor.swift | the MP `tag-library.js` club 活动倾向 icons, template-rendered |
| [ ] `MPAsset.BannerCover.dFrametu`, `.mer1` | — | MP `mockData.js` only; nothing real renders them |
| [ ] `MPAsset.FeatureIcon.citylink / members / pin / iconBell`, `MPAsset.BannerCover.defaultCover` | — | `App/ClubHomeView.swift` club cards: half b's page (club home), not this half |
| [ ] `MPAsset.TabIcon.iconTabClub(On)` | — | `CYDomainTabBar` (design system / restyle r6), not a club page |
| kept SF Symbol | `chevron.right`, share, close, search, ellipsis | system-control glyphs, per mapping |

### Core hand-offs wired (from `cursor-core-club.md` "For the Claude F-agent")

No `cursor/wire-club` branch exists, so none of these call sites was being wired elsewhere.

| item | what changed | files |
|---|---|---|
| CLB-detail-29 | The welcome sheet shows 成员价 when Core has `memberPricePerk`. Server text wins; otherwise `MoneyDisplay.yuan` (two decimals, owner decision 9). | App/ClubMemberWelcomeSheet.swift |
| CLB-r7-C-01 | The ban review shows `durationDays` as 「N 天」 (the body no longer has `expiresAtEpochMs`). `durationDays` is kept out of the raw fact rows. | App/ClubOpsGovernanceSections.swift, App/ClubGovernanceCommandForm.swift |
| CLB-r7-A-07 / C-02 | The member-governance denial reads `club.memberGovernance.denied` (仅主理人与联合主理人可进行成员治理, the Core sentence; key from `cursor-core-club.json`). The gate itself is Core's `allows("club:member:manage")`, which now requires owner/co-owner. | App/ClubOpsGovernanceSections.swift |
| CLB-topic-detail-09 / event-ops-05 / notify-04 | `ClubOpsPageFailureSection` prefers `literalTitle` through its catalogued key (网络连接失败, 活动无法打开, 链接已失效, 系列列表加载失败, 可开场主题加载失败, 活动运营暂时不可用, 结算数据暂不可用). `prefersBack` shows 返回 (pop) instead of reload. | App/ClubOpsJoinNotifyViews.swift (shared with half b's notify page) |
| CLB-detail-30 | The club header share and the post share carry `ClubShareLink` as an in-app `chein://mp/pages/club/detail/index?id=…[&postId=…]` link (the deep-link router already accepts it), with the invitation or excerpt as the message. | App/ClubKit/ClubWorkbenchKit.swift, App/ClubDetailView.swift, App/ClubCommunityViews.swift |
| CLB-detail-16 | `AppSession.communityEvidence` passes the detail's `memberPostAllowed`, so the composer hides for plain members when posting is off. Nil stays allowed. | App/AppSession.swift |
| CLB-r7-C-06 | After an acknowledged dissolve, the form calls `clubDissolveAcknowledged`, which the edit page sets to `profileDraft.clearAfterConfirmedDissolve()`. | App/ClubGovernanceCommandForm.swift, App/ClubOperationsViews.swift |
| CLB-event-ops-06 (horizon part) | The weekly-horizon error names the real maximum (首次日期起 90 天内最多可排 N 期) using `ClubEventOpsFormRules.maxWeeklyOccurrences`. | App/ClubSeriesScheduleEditor.swift, App/ClubGovernanceCommandForm.swift |

### Owner decisions (`owner-decisions-1124.md`)

- **9, two-decimal money:** the welcome perk uses `MoneyDisplay.yuan`. Enroll per-session money (`ClubEnrollmentRoster.yuanText`, one decimal in Core) is re-rendered through `MoneyDisplay` at display (`ClubMoneyText.twoDecimals`). **Cursor request:** switch `yuanText` and `ClubMemberWelcome.memberPricePerk` to `MoneyDisplay`, then the App shim can go.
- **3, 6, 12, money stays TEST-only:** no money write was added. `cancelOccurrence` / `endTopic` / `dissolve` keep `risk == .financial`. Dispatch is still `ClubGovernanceSessionAccess.canDispatch` (production needs a reviewed production service). Nothing here flips a gate.
- **7, 8, 10 (cast, arrival lock, game kits):** no club page uses them.

### P1 rows closed this round

| id | what changed | files |
|---|---|---|
| CLB-create-03 (limit) | The limit state adds 管理我的俱乐部. One club opens that club's 管理 tab; otherwise it opens the MP `owner=1&tab=manage` route. | App/ClubOperationsViews.swift |
| CLB-apply-07 | Step 1/2 inputs have a persistent label above them (`*` on 实名/昵称 and 联系方式), the MP placeholder, and a required/optional VoiceOver hint. | App/ClubGovernanceCommandForm.swift |
| CLB-apply-06 (experience part) | 组织经验 is one `ClubR1OptionCard` per option (the create-wizard kit) instead of a Picker. | App/ClubGovernanceCommandForm.swift |
| CLB-governance-04 | The ban confirm reads 确认封禁 <name> / 封禁后对方立即失去成员身份与群聊入口。 / 解封只恢复申请资格，成员身份不会自动恢复。 / 确认封禁. | App/ClubKit/ClubGovernanceConsequence.swift, App/ClubGovernanceCommandForm.swift |
| CLB-roles-07 | One revoke confirm: 撤销「角色名」？, the MP's three consequences, and 撤销角色. The duplicate consequence lines in the form notes are gone. | App/ClubKit/ClubGovernanceConsequence.swift, App/ClubOpsGovernanceSections.swift |
| CLB-roles-10 | The no-delegable-members copy is 暂无成员. | App/ClubOpsGovernanceSections.swift |
| CLB-topic-story-01 | `pages/club/topic-story/index` opens the story directly. The topic overview hosts the read and pushes the story once after it loads, so back returns to the topic page. | App/MPReviewedPageScreen.swift, App/ClubGovernanceViews.swift |

The governance-04, roles-07 and roles-10 copy now uses Localizable keys from the fragment, so the round-1 OpsR3 / ClubOpsGovernance integrator request for these rows is **withdrawn**.

### Review findings (`review/r7-rev-{a,b,c}`)
- REV-A: no club rows.
- REV-B B-22 (`ClubRecord.viewerCanGovern` decode): Core, and it needs an owner call. Not touched.
- REV-C F-C20 / F-C21 (reference-settlement mount): the view is parked in `App/MPGap/Club` and not mounted. The settlement page belongs to half b. Not touched.

### Left after round 2, with reasons

| id | reason |
|---|---|
| CLB-detail-26 (Now card) | `ClubOwnerStageMachine.resolve` needs topic lifecycles, sale-review flags, uncontracted stations, projects and messages. `ClubLeadProgressSnapshot` reads them but does not expose them. **Cursor request:** add `ClubLeadProgressSnapshot.ownerStage: ClubOwnerStageResolution`, built inside the snapshot init. The App then shows its `label` / `hint`. |
| CLB-event-ops-06 (capacity part) | Needs the chosen topic's `sessionTicketCount` in the create-series form. The event-topics row's count is not carried by `ClubGovernanceFormRoute` or `seriesCreationSource`. **Cursor request:** expose `sessionTicketCount` on the event-topic source so `ClubEventOpsFormRules.showsCapacity` can be applied. |
| Governance/roles avatars | Rows show `d_profile` because `ClubOpsGovernanceMember` / role-assignment rows carry no avatar. **Cursor request:** decode `avatar` there; `ClubMPAvatar(url:)` already takes it. |
| CLB-detail-14, -22, -35, CLB-topic-detail-02 (pinned footer), -05, -06, -10, CLB-event-ops-02, CLB-governance-01, -03, CLB-roles-04, CLB-create-06, CLB-edit-01, -05 | Each restructures a List or the shared command-form flow (M). Several have UI/flow tests pinned to the current structure (`ClubOperationsFlowTests`, governance UI tests). Without a compiler, a wrong move here breaks a working flow. They are left for a compiled round, unchanged from round 1. |
| CLB-enroll-02, CLB-edit-03 | Need the pinned XCUITests changed in the same commit (Tests/ is Cursor's). |
| CLB-apply-04 (切换到商家端), -10, -11, CLB-create-07, CLB-topic-detail-11, CLB-event-ops-03 | Unchanged from round 1 (no switch API; Core literals; Core phone fields). |
| CLB-r7-A-08, CLB-enroll-08 | Need an `api/club/my` read in the router (Core). |

### Files touched in round 2 that half b also uses
`App/ClubOpsJoinNotifyViews.swift` (`ClubOpsPageFailureSection`), `App/ClubKit/ClubWorkbenchKit.swift` (`ClubHeaderShareButton`), `App/ClubKit/ClubCreateKit.swift` (`ClubR1Chip` gained an optional `icon`, default nil), `App/ClubKit/ClubGovernanceConsequence.swift` (ban/revoke branches only). Every change is additive with defaults, so existing call sites compile unchanged.

### Round-2 strings (fragment)
`club.welcome.memberPrice %@`, `club.schedule.error.weeklyHorizonMax %lld`, `club.ops.clubLimit.manage`, `club.host.requiredHint`, `club.host.optionalHint`, `club.host.placeholder.{leaderName,phone,identity,coFounders,maxEventSize,avgEventSize}`, `club.gov.consequence.ban.{title,titleNamed %@,line1,line2,confirm}`, `club.gov.consequence.revokeRole.{title,titleNamed %@,line1,line2,line3,confirm}`, `club.gov.roles.noMembers`, `club.rolePicker.untitledSession`. Uses Cursor's `club.memberGovernance.denied` and `clubOps.*` keys from `docs/port/strings/cursor-core-club.json`.

### Checks (round 2)
- Every contract check (`Tests/ContractChecks/test_*.py`) was run on this branch and on `origin/ui/combined-r7`. The only new failure is `test_localization_key_catalog_contract` (fragment keys, see Strings). The club failures (`customer_directory_remote_admission`, `customer_keyword_debounce`, `customer_permissions`, `operations_contracts`) fail identically on the base.
- `tools/check_typography_lint.py`: PASS.
- No Swift build (no compiler in the cloud). New APIs relied on, grepped on r7: `MPAsset.*` accessors, `MoneyDisplay.yuan(_:)`, `ClubShareLink.club/post`, `CheinDeepLink.scheme`, `ClubOpsPageFailureCopy.literalTitle/prefersBack`, `ClubOpsNetworkFailureClassifier.*Title`, `ClubProfileLocalDraftFlow.clearAfterConfirmedDissolve()`, `ClubEventOpsFormRules.maxWeeklyOccurrences`, `ClubSeriesScheduleDraft.day(_:)`, `ClubCommunityEvidence(…, memberPostAllowed:)`, `ClubRecord.memberPostAllowed/memberDiscountPrice(Text)`, `ClubR1OptionCard(title:isSelected:action:)`, `appLocalized(_:locale:)`, `View.cyText` / `Text.cyText`, `.onChange(of:initial:)` (iOS 17).

## Round 3 (2026-11-24 evening)

- **Brief:** `design/handoff-r2:docs/briefs/fix-r3-round3.md`, with `wave-x10.md`, `fix-r3-round2.md` and `owner-decisions-1124.md`.
- **Sync:** `fix/r3-club-a` was already contained in `origin/ui/combined-r7` (`b0ac0108d`), so the merge was a fast-forward. Re-merged before the final push.

### Round 3 · re-applied

Every round-2 hunk was compared with the new base (`git diff 5f7e01dbf b0ac0108d` per file). Where Cursor's wiring already covers the effect, Cursor's API was kept and no second implementation was added.

| round-2 item | state on b0ac0108d | round 3 |
|---|---|---|
| MP default cover `club_cover_default.png` and logo `d_logo.png` on the club header (`ClubDetailCover`) | dropped (ClubDetailView restored to Cursor's side) | **re-applied** on Cursor's file: `fallback:` parameter, `MPAsset.BannerCover.clubCoverDefault` / `MPAsset.BrandLogo.dLogo` |
| CLB-detail-30 header share: in-app `chein://mp/…` link with the invitation message | dropped; Cursor shares the bare `ClubShareLink.path` string | **re-applied on top of Cursor's `ClubHeaderShareButton(clubID:)`**: still built from `ClubShareLink.club(id:)`, sent as `ClubShareURL.url(link)` with the `r3club.invite.message` text; optional `clubName`, falls back to Cursor's path |
| CLB-detail-30 post share (`ClubPostShareText`) | dropped; Cursor shares the path string | **re-applied** the same way on `ClubShareLink.post(clubID:postID:)`; `ClubPostShareText` restored (no other declaration exists) |
| CLB-roles-02 `activityLabel` from the MP link into the roles page | dropped in `MPReviewedPageScreen` | **re-applied** (`.environment(\.clubRoleActivityLabel, …)` on the roles route) |
| CLB-r7-C-06 dissolve clears the local edit draft | Cursor added `clubProfileDraftFlow`, which does the same | **kept Cursor's**; removed my now-unset `clubDissolveAcknowledged` key and its call |
| CLB-event-ops-06 weekly-horizon maximum | Cursor's `weeklyHorizonMessage(now:)` replaced mine | kept Cursor's; dropped the unused `club.schedule.error.weeklyHorizonMax` fragment key |
| CLB-r7-C-01 ban `durationDays` review | Cursor's `banDayChoices` version | kept Cursor's |
| CLB-detail-29 welcome 成员价 | Cursor's `memberPricePerk` text | kept Cursor's |
| `ClubOpsPageFailureSection` literal titles | Cursor shows `literalTitle` verbatim (no English) | kept Cursor's; the English-locale gap is a note for Cursor |
| CLB-detail-26 Now card (my round-2 Cursor request) | Cursor implemented `loadOwnerStage` + `ClubWorkbenchNowCard(ownerStage:)` | nothing to do |
| `ClubMPAvatar`, `ClubMoneyText` | now only in `ClubKit/ClubMPArt.swift` | call sites unchanged (same `url:name:size:`; `twoDecimals` alias kept) |
| Everything else from round 2 (governance consequences, apply labels, MP tag icons, avatars, topic-story direct link, create limit) | present | — |

### Fixed in round 3

| id | what changed | files |
|---|---|---|
| CLB-topic-detail-02 (pinned footer) | The phase primary (去选一场 / 进入场次 / 查看结算 / 修改并重新提交 …) is a bottom bar (`safeAreaInset`, `.bar` material, divider) on a loaded, current topic overview, not the last list row. | App/ClubGovernanceViews.swift |
| CLB-create-06 | The stepped create wizard's 创建俱乐部 confirms in place (prepare → confirm, no review sheet). An unverified write path still shows the sheet; the flat UI-test form keeps it. | App/ClubOperationsViews.swift |
| CLB-topic-story-03 (loading/error) | The answer sheet shows 正在取答案… while reading and 答案没取到 + 重试 (with the server reason) on failure. | App/ClubGovernanceViews.swift; strings; Resources/ClubStoryLocalizations.fragment.json |
| CLB-topic-detail-14 | 核销 header is a sentence-case `.sectionTitle` (`textCase(nil)`, header trait); tile labels `.cyText(.label)`. | App/ClubTopicDetail+Port.swift |
| CLB-topic-detail-15 | 接下来 rows: when over who, the issued headcount as a trailing `CYStatusChip`. | App/ClubGovernanceViews.swift |
| CLB-topic-story-10 | At accessibility sizes the chapter chips become a menu `Picker` (same selection guard). | App/ClubGovernanceViews.swift |
| CLB-edit-07 | A non-manager opening edit sees 暂无编辑权限 + 返回俱乐部 (the message keeps the `club.ops.error` id the UI test reads). | App/ClubOperationsViews.swift; strings |
| CLB-apply-11 | The host done card shows 主理人 <leaderName> when the status read carries `leaderName`. | App/ClubGovernanceViews.swift; strings |
| CLB-apply-06 (header part) | Host-apply steps use the create wizard header: four capsules, 第 n 步，共 4 步, a `.display` headline. | App/ClubGovernanceCommandForm.swift |
| CLB-governance-16 | Ban and case status are plain coloured text (active ban red, pending case amber), not pills. | App/ClubOpsGovernanceSections.swift |
| CLB-detail-39 | Activity card: card surface, 130 pt cover with the status chip at its top-left, address in `.meta` (no raw `.caption`). | App/ClubActivityListContent.swift |
| CLB-detail-43 | Inside a club the like/comment counts sit on the 赞 / 评论 actions; the separate count row stays only on the cross-club feed (no action bar there). VoiceOver keeps the action name with the count as value. | App/ClubCommunityViews.swift |

### Gap flows (`docs/mp-gap/flows-g2.md`, edges for Claude) on this half's pages
- `club/detail:1079`, `club/topic-detail:915` → `pages/club/settlement/index?clubId=`, `coop/settlement-detail` → settlement: routed by `MPParityDestination.clubSettlement` (`App/MPParityKit.swift`), not by `MPReviewedPageScreen`, so the doc's MISSING-ROUTE is a false positive. Same for `club/payout-receiver`.
- `club/detail:944` → `pages/coop/list/index?tab=sent`: routed (`MPParityKit` `.coopList`).
- `club/create:196` → `redirectTo apply`: routed (`pages/club/apply/index`).
- `club/detail:998` (scan → `submitClubScan`): the club-scoped 扫码核销 is CLB-G02, parked in `App/MPGap/Club` (`ClubGapActivityAndScanActions`); mounting is the integrator's / Gemini's. Not duplicated here.
- `scene-club-edit:395`, `topic-detail:1292`, `director.js:1492`, `workbench:25`: these lines are requests or retries of the current page, not navigations (extraction noise).

### Left after round 3, with reasons

| id | reason |
|---|---|
| CLB-detail-35 (团码 on cards) | For managers the card already opens the club topic page (CLB-r7-A-01), whose 接下来 rows carry 出示团码 per session: two taps. A separate picker would duplicate it. |
| CLB-detail-14, -22, CLB-topic-detail-05, -06, -10, CLB-event-ops-02, CLB-governance-01, -03, CLB-roles-04, CLB-edit-01, -05 | Each restructures a List or the reviewed command flow and needs new reads or inline writes with rollback; several are pinned by `ClubOperationsFlowTests` / governance UI tests (Tests/ is Cursor's). Left for a compiled round. |
| CLB-r7-C-03 | `load()` clears the snapshot by design (fenced reads); keeping the old list on a failed reread needs a change to that fence. |
| CLB-enroll-02, CLB-edit-03 | Pinned XCUITests must change in the same commit (Cursor). |
| CLB-enroll-08 | **Cursor request:** `MiniProgramPageLink` requires `clubId` for `pages/club/enroll/index`; drop the requirement so the App can fall back to `ClubOwnedView`. |
| CLB-topic-detail-11, CLB-event-ops-03 | **Cursor request** (unchanged): merchant/roster phone fields in Core. |
| CLB-apply-04 (切换到商家端), -10, CLB-create-07 | Unchanged (no switch API; Core literals). |
| `ClubOpsPageFailureSection` | **Cursor note:** the literal titles are shown verbatim, so English shows Chinese; the round-2 key lookup (`clubOps.*` keys) could come back in Core's copy. |
| CLB-event-ops-09 | Double chevron risk inside `NavigationLink`; needs a visual check. |

### Round-3 strings (fragment)
`club.story.answer.loading`, `club.story.answer.failed`, `club.ops.edit.noPermission`, `club.ops.edit.backToClub`, `club.host.done.leaderLabel`. Removed: `club.schedule.error.weeklyHorizonMax %lld`.

### Checks (round 3)
- Contract checks for every changed file, run here and on the base: no new failures. Three pins moved on purpose: the `test_club_leaderboard_member_navigation` span hash (the answer-sheet states join that span), `Resources/ClubStoryLocalizations.fragment.json` gained the two answer keys (`test_club_story_navigation`), and the answer-sheet reason line uses its own id so `ClubOpsFailureCopy` stays ahead of `club.gov.error` (`test_club_ops_customer`). Failing identically on the base: `club_customer_directory_remote_admission`, `club_customer_keyword_debounce`, `club_customer_permissions`, `club_operations_contracts`, `category_roam_registration`, `profile_read_failure_remote_admission`, `ugc_1_2_completeness` (AppSession ratchet), `tools/tests/test_readiness_contract_parse_cache`.
- `tools/check_typography_lint.py`: PASS.
- No Swift build here. APIs used, grepped on b0ac0108d: `ClubShareLink.club(id:)/.post(clubID:postID:)/.path`, `ClubShareURL.url(_:)`, `OpsR3Text.string(_:locale:)`, `Locale.pick`, `ClubTopicDetailPort.Primary` (Equatable, `.none`), `ClubGroupCodePort.formatStart(date:time:)`, `ClubGroupCodeCount.displayText`, `CYStatusChip(_:tone:)` / `(verbatim:tone:)`, `CYEmptyState(systemImage:_:messageIdentifier:actionTitle:actionIdentifier:actionStyle:kind:action:)`, `CYStateKind.generic/.failure`, `CYColor.warningText/bgRaised/borderSubtle`, `ClubOperationsWriteAvailability`, `ClubOperationsReview.command`, `ClubRoleActivityLabel.entry`.
