# ui/h-polish-d-r1 · design r1 polish pass receipt (2026-11-16)

Base `origin/ui/main` 165f6d593 (= `ui/h-integ-d-r1`). Items from the coordinator's review of the integ-d-r1 screenshots.
Mac only: Xcode 27, Questify-iPhone17-Lane2 (2337B386), arm64, one DerivedData, builds and simulator sessions under
`lockf /private/tmp/design-build.lock`. Screenshots: `/Users/fanning/chengyin-refs/integ-d-r1-shots/polish/` (not committed),
listed in that folder's `index.md`.

## Items

| # | Item | Status | Change |
|---|---|---|---|
| 1a | Club tab segments read "Posts / Clubs" | done | `ClubHomeView` looked the titles up with `Bundle.main.localizedString`, which follows the device language and ignores the in-app language. Now `appLocalized(_:locale:)` with the existing keys `club.tab.top.feed` / `club.tab.top.club` → 帖文 / 俱乐部 (kept the shipped 帖文, which matches the club detail tab). |
| 1b | Other English strings on player pages | done | Swept `App/` for `Bundle.main` lookups and verbatim Latin UI text. Fixed: km units on roam history share, growth centre and profile growth (`roam.history.km` / `roamSub.w208.history.km` = 公里), the celebration `kmUnit`, the roam tile `NEW` badge (`roam.private.new` = 新), the video bounty raw `UNKNOWN` status (now "—"). The remaining verbatim English is internal diagnostics screens and the language picker's "English". |
| 1c | 创建者 chips blue | done | Club role/status chips switched from `.info` (blue) to `.neutral` (MC-35): the club card owner chip (`CYClubCards`), detail 创建者 / 管理员 chips, member rows, the level chip, the story method chip and the lead-progress stage chip. |
| 1d | "你的俱乐部：5 / 2" | done | New Core `ClubTabPageModel.LeaderStatus.quota` (`within` / `full` / `over` / `unknown`, tested). Over the limit shows a warning `CYStatusTag` 已超出上限 and "你已创建 5 个俱乐部，上限是 2 个，暂时不能再创建新的俱乐部。"; within and full have their own sentences; unknown keeps the old em-dash line. Strings in `DesignR1Club` via `tools/build_design_r1_localizations.py`. |
| 1e | 主题 0 chips outside the cards | done | `CYClubRowCard` gained a `tags` slot drawn inside the card under the member strip; owned/joined rows pass `ClubTabTagLine` there. Nearby photo cards have no card surface around their footer, so their chips stay under it. |
| 2 | Live roam HUD "Time / Fog / km", bold italic "Pause" | done | `roam.live.stat.time/turf/distance` now read 时长 / 迷雾 / 公里 (Time / Fog / km); this also changes the shipped `RoamLiveSessionView` HUD, which used 用时 / 地盘 / 距离 (公里). `CYGoLabel` / `CYGoButton` keep the heavy italic only for the GO wordmark; a localised word uses `CYTypography.sheetTitle`. The `d6-live` design host (the screenshot source) now reads the same keys and `roam.live.pause`. |
| 3 | Home footnote under the tab bar; gap after 更多玩法 | done | The 编辑精选 footnote, and its 正在更新… line, are the rail's subtitle above the carousel, so neither can land under the floating bar (the home root already has `cyFloatingTabBarClearance`). Hero, consent card, offline notice and 编辑精选 are one group at `CYSpacing.sm`; most of the remaining space is the 更多玩法 menu's 44 pt touch target. |
| 4 | Lobby 房主 badge overlaps 我; first avatar clipped | done | Every seat reserves the badge's overhang (`.padding(.bottom, CYSpacing.md)`), so labels stay on one baseline. The seat row is inset by `CYSpacing.xs` for the "me" ring, which draws 3 pt outside its circle. |
| 5a | Merchant step 4 nested cards | done | Review rows are plain `CYListRow`s inside the grouped section: one card with dividers per group. |
| 5b | Status bar white on the light page | **open** | Tried `toolbarColorScheme(.light)` with a visible page-coloured bar background in `cyDomainScreen` for light domains. No effect: the app root applies `roleTheme(.player)` → `.preferredColorScheme(.dark)`, and a light page pushed inside the player shell cannot override the root presentation's scheme (`themeDomain(.merchant)` already asks for `.light` and loses too). Reverted, so the merchant nav bars are not changed for nothing. Proposed fix: let the root arbitrate the scheme (e.g. a root-held `@State` scheme that a light-domain page sets on appear and clears on disappear), which is a shell change for the coordinator to schedule. Merchant console screens (merchant role root) are unaffected. |
| 6 | Gameplay config 封面图片链接 raw URL field | done | Replaced by the shared 16:9 cover flow (picker → local crop → upload → apply) that activities use (`ActivityCoverAuthoringSection`, `kind: .template`, template copy in `ActivityCoverAuthoring.xcstrings`), under the existing 16:9 `TemplateAuthoringCoverHeader` tile (CF-44). `ActivityCoverTarget` gains `.template(UUID)` with its own replay key `template.cover:<id>`, so an uncertain template upload never locks an activity cover. The upload service and session come from the session-holding entries (发布 tab, 我的 → 创作, the MP page route) through a `templateCoverSource` environment value. Upload is still gated by the composition's existing cover approval. The design fixture has no service, so its 选择封面 opens nothing. |
| 7 | 查看成员 → 俱乐部加载失败 | done (app bug) | See below. |
| 8 | MC-25 roster card on the members screen; ⋯ menu for owner and admin | done | `ClubRosterCard` sits above the member rows with the club name, a 创建者 N · 管理员 N · 成员 N line and the member count. The card hides the money row where money is not part of the roster, shows only the count when no capacity is read (no empty bar), and expands only when it has money or attendees. The ⋯ menu was already gated on `canGovern = isOwner || viewerIsAdmin`; it was simply unreachable while the list failed to load (7). On TEST as owner of club 7003 it shows on every row except the viewer's own. The admin case was not exercised on the simulator (owner account only); it is the same code path. |

## Item 7 · request-shape vs backend

App log (`--e2e-test-host`, `E2ETestHostTransport` NSLog) when opening 查看成员 for club 7003:

```
[E2E] POST /api/club/detail -> 200 … {"code":200,"data":{"id":7003,…}}
[E2E] composition refused or failed POST /prod-api/api/club/members: notConfigured
```

The members read never reached the network. Replaying the app's exact requests against TEST as the club owner (fixture
member 9003, SMS-code login on the TEST VPS; token not recorded):

- `POST /api/club/detail` `{"id":7003}` → 200, `isOwner:true`, `isJoined:true`, `memberCount:4`
- `POST /api/club/members` `{"clubId":7003}` → 200, 4 rows (9003 role 2 owner, 9004 role 1, 9005 and 9009 role 0)

**Verdict: app-side, not a backend bug.** `ClubSessionReader.clubMembers` reads detail then members with the same
session. In the shipped China composition, signed-in player reads are admitted by the owner-approved list
`ReviewedPlayerReadRoute.paths`. It had `api/club/detail` and `api/club/access/me` but not `api/club/members`, so
`guardedSend` threw `notConfigured` and the screen showed 俱乐部加载失败 / 请检查网络连接后重试. The request shape (JSON
`{"clubId"}`) matched what the backend expects.

Fix: `api/club/members` added to `ReviewedPlayerReadRoute.paths`. It is `liveInProduction` and admitted by
`ChinaReviewedRouteCapability.admitsChinaProductionCall`, it is a non-money read, and the backend enforces
`club:member:list:read`. New `ReviewedChinaLaunchCompositionTests.testShippedChinaAdmitsClubMembersRead`: the read is sent,
and a money field still closes it. **This extends an owner-approved allowlist by one read; please confirm with the owner**
(precedent: `api/club/access/me`, E2E-20261113).

## Build and tests

- `build_sim` / `build_run_sim` (Questify, Debug, Lane2): succeeded. One compile error during the pass (`locale` not in scope
  in `ClubHomeView`) was fixed by adding the environment value.
- AppUnit, affected classes via `test_sim` -only-testing (`DesignR1ClubKitTests`, `DesignR1ClubRosterCardTests`,
  `DesignR1MerchantKitTests`, `DesignR1FoundationTests`, `ReviewedChinaLaunchCompositionTests`, `ActivityCoverAuthoringOwnerTests`,
  `ActivityEditingOwnerTests`, `ActivityEditingForegroundRecoveryTests`): **109 / 109 passed**.
- Core, affected classes (`ClubTabPresentationTests`, `ClubTabTopTabTests`, `ClubTabPageModelTests`, new `ClubTabLeaderQuotaTests`,
  `ActivityCoverAuthoringTests`): **33 / 33 passed**.
- `contract_ratchet.py --check`: 185 failing, baseline 184. The one "new" item is the same pre-existing
  `test_workshop_paid_professional…bounded_paging` already red on `ui/main` (see integ-d-r1 receipt). Two contracts tripped
  by this pass were fixed in code: `test_template_authoring_contracts` (an accessibility id with the `templateAuthor.` prefix
  was read as a catalog key; renamed `templateCover.section`), and `test_template_media_review_ui` (the pinned
  `.onDisappear { media.retire(); model.leave() }` line kept, with cover retirement in its own modifier).
- `check_design_lint.py` PASS, `check_missing_string_keys.py` 0 missing, `build_design_r1_localizations.py --check` OK,
  `check_scaffold.py` PASS.
- New tests: Core `ClubTabLeaderQuotaTests` (2); AppUnit `DesignR1ClubRosterCardTests.testCountWithoutCapacityAndExpandability`,
  `.testMembersScreenRosterCountsRoles`, `ReviewedChinaLaunchCompositionTests.testShippedChinaAdmitsClubMembersRead`.
- Full AppUnit shards were not re-run in this pass, only the affected classes.

## Left

- 5b status bar on light pages pushed inside the player shell (needs root scheme arbitration).
- Owner confirmation for adding `api/club/members` to the player read allowlist.
- The 创建俱乐部 entry still shows while `leaderStatus.canCreate` is false (it leads to the limit screen); not in this pass's list.
- `ui/main` not fast-forwarded.
