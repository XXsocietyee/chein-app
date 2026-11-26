# Parity + native-iOS re-audit r10 — group C (pages/activity/*)

- App: `origin/ui/combined-r7` @ `82bcf2c2d` (r9 audited `ebf6c160c`). Every group-C file was checked with `git log` / `git diff ebf6c160c..HEAD`.
- MP: `hengyin/chengyinhub-xcx` (`pages/activity/*`; detail body in `subpackageMember/components/cy/scene-play-activity-detail/`).
- Rules: `native-r2.md` (everything native) and `owner-decisions-1124.md` (MP-first; only money is "money, not a gap").
- Method: same 147 function lines as r8/r9. Page parity = (✅ + ⚠️) / (lines − N/A). Only lines whose status changed are moved. Every r9 queue row was checked in code, not in commit messages. Native verdict per page: native (essentially no custom chrome) / partly (system `List`/`Form` root, some custom chrome) / custom (custom chrome dominates). Group native % = (native 1 + partly 0.5 + custom 0) / pages.
- Group-C commits since r9: `dcdde358b` (activity meta rows moved to first fold), `c9da95476` (broadcast stats failure carries the server message), `4bbba2ba4` (**removed** the 安全恢复原投递 button and the Core recover POST), `c8c179188` (empty leaderboard, 安全须知, bilingual leaderboard chip / broadcast summary), `04c1d84f1` (official detail split), `82bcf2c2d` (official flow surfaces use `cyApplyColorScheme(domain.forcedColorScheme)`; player domain is not forced, `App/Theme/Theme.swift:21-25`).

## 1. Per-page parity (r9 → r10) and native verdict

| page | r9 | r10 | native | non-Apple elements (sites) |
|---|---|---|---|---|
| C1 pages/activity/detail/index | 29/29 (100%) | 29/29 (100%) | custom | ~45 |
| C2 pages/activity/baoming/baoming | 22/25 (88.0%) | 22/25 (88.0%) | partly | ~30 |
| C3 pages/activity/list/index | 19/19 (100%) | 19/19 (100%) | partly | ~11 |
| C4 pages/activity/official-detail/index | 24/25 (96.0%) | 24/25 (96.0%) | partly | ~17 |
| C5 pages/activity/official-inbox/index | 16/16 (100%) | 16/16 (100%) | partly | ~12 |
| C6 pages/activity/official-mine/index | 14/14 (100%) | 13/14 (92.9%) | partly | ~7 |
| C7 pages/activity/official-organizer/index | 19/19 (100%) | 19/19 (100%) | partly | ~13 |
| **group** | **143/147 (97.3%)** | **142/147 (96.6%)** | **native 42.9%** (0 native, 6 partly, 1 custom) | |

Line moves (r9 → r10):
- **C6 #14 安全恢复原投递 ✅ → ❌ (regression).** `4bbba2ba4` removed the button, confirm dialog and re-read from `App/OfficialPrivateViews.swift` (stats view and inline stats row), and the POST from `Core/OfficialEventService.swift`. `Core/OfficialEventReading.swift:47-48` now says "the read surface does not send a recover write" and throws. The app shows only a status line 站内投递标记为可恢复 (`App/OfficialPrivateViews.swift:181-186, 261-266`). MP still has the button for the publisher (`official-mine/index.wxml:30`, `index.js:181-197`). Not money. MP-first → app fix.
- C6 #13 failure line ⚠️ → ✅: `c9da95476` passes `OfficialBroadcastStats.serverNote(error)` into `failureLine` (`App/OfficialPrivateViews.swift:267-270, 297`; `Core/OfficialEventContracts.swift:700-716`) + ，点一下重试 (MP `official-mine/index.js:168, 175`). Fraction unchanged (was already counted).
- C4 #13 leaderboard: chip now English under en via Core `presentedChip` (`c8c179188` `Core/OfficialEventContracts.swift:654-657`, `App/OfficialEventDetailView.swift:416`). Still ✅; placement is still before 我的活动任务 (`App/OfficialEventDetailView.swift:182-184` vs tasks `:202-237`).
- C1 meta (分类 / 集合点 / 已报名) moved into the first fold after the cancellation notice (`dcdde358b` `App/ActivityDetailView.swift:442-444`), matching MP order. Line was ✅; no change.
- No other line changed. C1 #5/#17/#21/#23/#27, C2 #11/#17/#19/#21, C3 #3, C4 #23, C5 #14 stay as in r9.

## 2. r9 queue rows — r10 status

| id | r9 sev | r10 status | evidence |
|---|---|---|---|
| R9-PC-C1-2 | P1 | open | Host footer still needs `hostCancelAccess`, which is nil outside TEST (`App/AppSession.swift:3481-3482`), so a Release host falls through to 立即报名 (`App/ActivityDetailView.swift:677-704`). MP `index.wxml` host footer on `isOwner` |
| R7-PC-C2-1 | P1 | open | `ActivityRegistrationGapSections` still has no caller outside `App/MPGap/PlayerContent/RegistrationGapSections.swift` (grep = 0). `RegistrationSheetView.swift` unchanged since r9 |
| R9-PC-C2-1 | P1 | open | `hostReservation(` has 0 callers in App; waitlist section still only `ClubHostRequestButton` (`App/RegistrationSheetView.swift:678-682`) |
| R7-PC-C1-6 | P1 | partly | Stars + 300 done. Still no photo picker; `img_arr: ""` (`Core/ContextualReviews.swift:25`); Core cap still 500 (`:21, :188`) |
| R9-PC-C1-1 | P2 | open | 查看我的订单 still `rootTabSwitch(.mine)` (`App/ActivityDetailView.swift:196-197`); second CTA still `common.back` (`App/MPGap/PlayerContent/PlayerContentRound2Views.swift:155-156`) |
| R7-PC-C1-5 | P2 | partly | Window chip done. `cmsRegistrationList` still not decoded on `ActivityTicket` (only Club/Topic contracts decode it) |
| R7-PC-C4-4 | P2 | open | No notification permission request on official signup (`App/OfficialActionViews.swift:322+`, `App/OfficialEventDetailView.swift:267`); MP `official-detail/index.js:604-610` |
| R7-PC-C3-3 | P2 | open | `official.bucket.upcoming` zh-Hans still 即将 |
| R9-PC-C3-1 | P2 | fixed (already correct before r9: `4dbde728d` `Core/OfficialEventContracts.swift:245` `tabTitleKey` → `official.tab.mine` = 我的; chip `App/OfficialEventsBrowserView.swift:158`) | r9 false positive: `official.bucket.mine` is not used by the chip |
| R7-PC-C4-5 | P2 | open | `official.detail` zh-Hans still 官方活动详情 (`App/OfficialEventDetailView.swift:304`) |
| R9-PC-C4-1 | P2 | partly | Chip language fixed (`c8c179188` `Core/OfficialEventContracts.swift:654-657`). Catalog keys `official.leaderboard.provisional/.final` still missing (fallback now harmless). Placement still open (`App/OfficialEventDetailView.swift:182-184`) |
| R7-PC-C5-2 | P2 | partly | Busy line only in the review sheet (`App/OfficialActionViews.swift:71-77`), not on the inbox card (`App/OfficialPrivateViews.swift:31-66`) |
| R8-PC-C6-2 | P2 | fixed (`c9da95476` App/OfficialPrivateViews.swift:267-270, 297; Core/OfficialEventContracts.swift:700-716) | |
| R9-PC-C6-1 | P2 | open | `emptyRow("official.published.broadcastsEmpty", "official.published.broadcastsEmptyDetail")` (`App/OfficialPrivateViews.swift:114`) |
| R9-PC-CN-1 | P2 | open | Hand-built failure state still `ScrollView` + `CYStateArt` + `CYPillButton` (`App/ActivityDetailView.swift:172-186`) |
| R9-PC-CN-2 | P2 | open | `OfficialIssueView` still `ScrollView`/`VStack` + `Label` (`App/OfficialEventComponents.swift:43-68`) |
| R9-PC-CN-3 | P2 | open | 32 pt fixed avatar / stars (`App/ActivityPeopleSection.swift:88`; `App/ContextualReviewComposer.swift:30`) |

Totals (17 r9 rows): **fixed 2, partly 4, open 11**. Plus 1 regression (C6 recover) → new rows R10-PC-C6-1/2.

## 3. Native findings per page

Shared: all player pages use system Light/Dark (no forced dark; `App/Theme/Theme.swift:21-25`). Text goes through `.cyText(...)` (maps to system text styles) and colours through `CYColor.*` / `palette.*` tokens (trait-resolved, not hex). Counted below only where they form custom chrome.

**C1 activity detail — custom.** Root is `List` (`App/ActivityDetailView.swift:403`) but almost every row is custom chrome.
- `App/ActivityDetailView.swift:168` `CYEmptyState` (missing); `:172-186` `ScrollView` + `CYStateArt` + `CYPillButton` (failure); `:332-333` `ScrollView` + `CYSkeleton` (loading); `:342-344` `ScrollView` + `CYStateArt` (club gate); `:387` `CYPillButtonStyle`.
- `:408, :415, :425-426, :437-438, :461-462, :479-480, :493` `questifyCardSurface` / `questifyCardListRow` card rows (`App/QuestifyMotionComponents.swift:11-13` rounded `CYRadius.hero` background).
- `:432` `CYStatusChip` (cancelled notice).
- `:450-462` MapKit `Map` (good) but forced `.environment(\.colorScheme, .light)` `:454`, `CYMapPlaceholder` `:455`, `RoundedRectangle` clip `:456`, card surface `:461-462`.
- `:468, :503, :577, :586, :598, :601` `CYListRow` + `CYRowIcon` instead of `NavigationLink` + `Label`.
- `:551` `.background(CYColor.bgPage)`; `:692` `cyDomainSheet`.
- Footer `:696, :700, :707, :715` `CYPillButton`; `:703, :719` `cyHeroSource(cornerRadius: CYRadius.pill)`.
- Action tiles `:825-840` custom `VStack` buttons on `RoundedRectangle` background, `.cyPressable` style.
- `App/E1ActivityDetailParts.swift:31-32` `CYStatusChip` price; `:54-66` `LinearGradient` scrim over the cover + `RoundedRectangle(CYRadius.xl)` clip; `:115-149` stats `ScrollView` strip + `cyDomainCard`; `:166-190` `CYTabs` / `CYTabItem` in-page tabs; `:193-261` info card `cyDomainCard` + `CYRowIcon`.
- `App/ActivityPresentationComponents.swift:35, :40` rounded clips; `:46, :185` `cyDomainCard`; `:73, :75, :149-160` `CYStatusChip`; `:90` `RoundedRectangle(cornerRadius: 12)` placeholder; `:105` `questifyCardSurface`.
- `App/ActivityPeopleSection.swift:88` fixed 32×32 avatar; `App/ContextualReviewComposer.swift:30` fixed 32×32 stars, `:97` `cyDomainSheet`.
- Native already: cancelled state `ContentUnavailableView` + `.borderedProminent` (`App/MPGap/PlayerContent/PlayerContentRound2Views.swift:146-158`); meta `LabeledContent` rows (`App/ActivityDetailView.swift:760-785`).

**C2 registration (baoming) — partly.** Root `Form` (`App/RegistrationSheetView.swift:87`).
- `CYPillButton` ×14: `:109, :237, :254, :521, :539, :569, :655, :661, :675, :684, :773, :822, :937, :1011`.
- `CYLoadingStateView` ×8: `:112, :536, :640, :724, :825, :889, :965, :1026`.
- `CYOptionSheet` / `CYOptionSheetItem` `:194-231`; `CYModal` `:389`; `CYScreenOfflineWriteSection` `:95`.
- Summary card `:296-348` (`RoundedRectangle` clip `:305`, `cyDomainCard` `:348`, clear row background).
- `:191` `cyDomainScreen`; `:231` `cyDomainSheet`; `:1193-1194` fixed 32×32 avatar on `Circle().fill(palette.bgElevated)`.

**C3 activity list (official list) — partly.** Root `List` (`App/OfficialEventsBrowserView.swift:99`).
- `:35-39` custom search box: `TextField` + padding + `.background(CYColor.bgElevated, in: Capsule())` instead of `.searchable`.
- `:42-48, :158` `ScrollView` of `CYFilterChip` instead of `Picker(.segmented)`.
- `:118` `CYEmptyState` instead of `ContentUnavailableView`.
- `:124-125` `QuestifyCardButtonStyle` + `questifyCardListRow` card rows; `:131` `cyDomainScreen`.
- `App/OfficialEventComponents.swift:192-230` `OfficialEventCard`: `CYStatusChip` `:198`, `CYColor.brand` tint `:221`; `:121` `CYLoadSlot`; `:43-68` `OfficialIssueView` (custom state view).

**C4 official detail — partly.** Root `List` (`App/OfficialEventDetailView.swift:157`).
- `:148, :212` `CYEmptyState`; `:163` `OfficialEventCard` + `questifyCardListRow`; `:166, :429` `CYStatusChip`; `:169` fixed 24×24 logo.
- `:178` `CYHeroHeader`; `:193` `cyDomainCard` per mission card; `:366-380` facts `ScrollView` strip.
- `:262` `CYPillButton`; `:457` `CYPillButtonStyle` CTA; `:281` `cyDomainPageBackground` + `tint(CYDomainPalette(.player).brand)`; `:290` custom `.background(.bar)` CTA bar.
- `App/OfficialEventComponents.swift:238-239, :305` `Theme.Generated` page background / brand tint; `:252` `OfficialFlowNotice` on `RoundedRectangle(cornerRadius: 12)` `.quaternary` box; `:297-307` custom action bar.
- `App/MPGap/PlayerContent/TopicAndOfficialGapSections.swift:40` fixed 40 pt rank column.

**C5 official inbox — partly.** Root `List` (`App/OfficialPrivateViews.swift:22`).
- `:25` `CYEmptyState`; `:33` `CYStatusChip`; `:72` `.background(palette.bgPage)` with hidden scroll background.
- Actions: `App/OfficialActionViews.swift:24` `CYEmptyState`; `:65, :82, :272` `CYPillButton`; `:72` `CYSkeletonBlock`; `:239` `cyDomainSheet`.
- Issue states via `OfficialIssueView` (`App/OfficialEventComponents.swift:43-68`).

**C6 official mine (我发布的) — partly.** Root `List` (`App/OfficialPrivateViews.swift:98`).
- `:121, :143` `CYStatusChip`; `:137` `.background(CYColor.bgPage)`.
- `:162-168` custom `emptyRow` `VStack` instead of `ContentUnavailableView`.
- `:244-277` inline stats as a `.plain` button wrapping custom text lines with `palette` colours.
- Issue states via `OfficialIssueView`.

**C7 official organizer — partly.** Root `List` (`App/OfficialOrganizerConsoleView.swift:200`).
- `:156` `CYSkeleton`; `:163` `CYEmptyStateView`; `:168` `CYErrorStateView`; `:176` `.background(CYColor.bgPage)`.
- `:182-195` `CYConfirmSheet` + `cyDomainSheet`; `:432-445` `CYConfirmConsequence` ×8.
- `:353-356` `ScrollView` of `CYFilterChip` presets.
- `:555` `CYPillButtonStyle(style: .primary)`.
- Write forms in `App/OfficialActionViews.swift:116-190, :398-407` are system `Form` + `TextField` (good) but end in `CYPillButton` (`:143, :190, :371, :407`).

## 4. Group fix queue

| id | severity | MP file:line | app file:line | what to do | owner |
|---|---|---|---|---|---|
| R9-PC-C1-2 | P1 | scene-play-activity-detail/index.wxml:149-151; index.js:338 (`isOwner`) | App/ActivityDetailView.swift:677-704; App/AppSession.swift:3481-3482 | When the viewer is the host and `hostCancelAccess` is nil (money off), show a disabled 取消活动并退款 with a short note instead of 立即报名. The refund write stays money, not a gap | Claude App |
| R7-PC-C2-1 | P1 | pages/activity/baoming/baoming.wxml:155-161, 206-212, 321; js:1876 | App/RegistrationSheetView.swift:718-756; App/MPGap/PlayerContent/RegistrationGapSections.swift:5 | Mount `ActivityRegistrationGapSections`: 儿童年龄 picker in quote/create, 包含内容, 商家暂停营业, 通行证 row | Claude App |
| R9-PC-C2-1 | P1 | pages/activity/baoming/baoming.wxml:225-241; js:1083 | App/RegistrationSheetView.swift:678-682; Core/RegistrationWaitlist.swift:60-87 | Render `waitlist.hostReservation(ticketSoldOut:)` as its own section: status, 请求主持, 取消, pay hint | Claude App |
| R7-PC-C1-6 | P1 | scene-play-activity-detail/index.wxml:138-139; js:590-605 | App/ContextualReviewComposer.swift:20-47; Core/ContextualReviews.swift:21, 25, 188 | Add ≤9 photo picker, send URLs in `img_arr`; lower Core cap to 300 | Claude App (picker) + Cursor Core (`img_arr`, cap) |
| R10-PC-C6-1 | P1 | pages/activity/official-mine/index.js:181-197 | Core/OfficialEventReading.swift:43-48; Core/OfficialEventService.swift:66-69 | Regression from `4bbba2ba4`: restore `recoverBroadcast(id:token:)` POST `/api/official/broadcast/{id}/recover` in the service and the reader | Cursor Core |
| R10-PC-C6-2 | P1 | pages/activity/official-mine/index.wxml:30; index.js:181-197 | App/OfficialPrivateViews.swift:181-186, 237-300 | Regression from `4bbba2ba4`: put back 安全恢复原投递 (confirm 只会按原收件人恢复…, one request at a time, error toast, re-read stats) when `canRecoverInapp`; drop the status-only line | Claude App |
| R9-PC-C1-1 | P2 | scene-play-activity-detail/index.wxml:5-6; index.js:436-441 | App/ActivityDetailView.swift:196-197; App/MPGap/PlayerContent/PlayerContentRound2Views.swift:151-156 | 查看我的订单 → push the order list; show 返回活动列表 when no own order | Claude App |
| R7-PC-C1-5 | P2 | scene-play-activity-detail/index.wxml:89-96 | App/ActivityPresentationComponents.swift:137-185; Core/ActivityDetail.swift (`ActivityTicket`) | Decode `cmsRegistrationList` per ticket and show the lineup | Cursor Core → Claude App |
| R7-PC-C4-4 | P2 | pages/activity/official-detail/index.js:604-610 | App/OfficialActionViews.swift:322-330; App/OfficialEventDetailView.swift:267 | On signup ask for notification permission for the activity start | Claude App |
| R7-PC-C3-3 | P2 | pages/activity/list/index.js:59 | Resources/Localizable.xcstrings `official.bucket.upcoming` | zh-Hans 即将 → 即将上线 | Claude App |
| R7-PC-C4-5 | P2 | pages/activity/official-detail/index.json:2 | Resources/Localizable.xcstrings `official.detail`; App/OfficialEventDetailView.swift:304 | zh-Hans 官方活动详情 → 活动详情 | Claude App |
| R9-PC-C4-1 | P2 | pages/activity/official-detail/index.wxml:143-153 | App/OfficialEventDetailView.swift:182-184, 202-237 | Move the leaderboard after 我的活动任务 (chip language done) | Claude App |
| R7-PC-C5-2 | P2 | pages/activity/official-inbox/index.wxml:20-32; js:177-193 | App/OfficialPrivateViews.swift:31-66; App/OfficialActionViews.swift:71-77 | Show 正在提交，请稍候 on the inbox card while its write runs; disable its buttons | Claude App |
| R9-PC-C6-1 | P2 | pages/activity/official-mine/index.wxml:23 | App/OfficialPrivateViews.swift:114 | Drop `broadcastsEmptyDetail`; MP shows 还没发过通知 only | Claude App |
| R9-PC-CN-1 | P2 | — (native) | App/ActivityDetailView.swift:168-186, 332-344 | Failure / missing / club-gate / loading → `ContentUnavailableView` (+ 重试 `.borderedProminent`) and `ProgressView` | Claude App |
| R9-PC-CN-2 | P2 | — (native) | App/OfficialEventComponents.swift:43-68 | Rebuild `OfficialIssueView` on `ContentUnavailableView` (label, description, actions) | Claude App |
| R9-PC-CN-3 | P2 | — (native) | App/ActivityPeopleSection.swift:88; App/ContextualReviewComposer.swift:30; App/RegistrationSheetView.swift:1193 | `@ScaledMetric` for 32 pt avatars / stars | Claude App |
| R10-PC-C-N1 | P2 | — (native) | App/E1ActivityDetailParts.swift:11-66 | Hero: drop `LinearGradient` scrim and `CYRadius.xl` clip; plain image row + system title | Claude App |
| R10-PC-C-N2 | P2 | — (native) | App/E1ActivityDetailParts.swift:72-261 | Stats strip / `CYTabs` / info card → `LabeledContent` rows in a `Section`; remove in-page tabs (or `Picker(.segmented)`) | Claude App |
| R10-PC-C-N3 | P2 | — (native) | App/ActivityDetailView.swift:408-493, 551, 825-840 | Remove `questifyCardSurface/ListRow` and `CYColor.bgPage`; action tiles → plain `Button` + `Label` rows | Claude App |
| R10-PC-C-N4 | P2 | — (native) | App/ActivityDetailView.swift:468, 503, 577-601, 696-719 | `CYListRow`/`CYRowIcon` → `NavigationLink` + `Label`; footer `CYPillButton` + `cyHeroSource` → `Button` `.borderedProminent` `.controlSize(.large)` | Claude App |
| R10-PC-C-N5 | P2 | — (native) | App/ActivityDetailView.swift:450-462 | Map: drop forced `.light`, `CYMapPlaceholder`, rounded clip and card surface; keep MapKit `Map` | Claude App |
| R10-PC-C-N6 | P2 | — (native) | App/ActivityPresentationComponents.swift:16-185 | List/ticket cards: drop `cyDomainCard` / rounded clips / `questifyCardSurface`; `CYStatusChip` → secondary `Text`/`Label` | Claude App |
| R10-PC-C-N7 | P2 | — (native) | App/RegistrationSheetView.swift:109-1011 (`CYPillButton` ×14) | `CYPillButton` → `Button` (`.bordered` / `.borderedProminent`) | Claude App |
| R10-PC-C-N8 | P2 | — (native) | App/RegistrationSheetView.swift:95, 112-1026 (`CYLoadingStateView`), 194-231, 389 | `CYLoadingStateView` → `ProgressView`; `CYOptionSheet` → `.sheet` with `List`/`Picker`; `CYModal` → `.alert`/`.confirmationDialog` | Claude App |
| R10-PC-C-N9 | P2 | — (native) | App/RegistrationSheetView.swift:296-348 | Summary card → plain `Section` with `LabeledContent` (ticket, price) | Claude App |
| R10-PC-C-N10 | P2 | — (native) | App/OfficialEventsBrowserView.swift:35-48, 118-131, 158 | Search → `.searchable`; chip row → `Picker(.segmented)`; `CYEmptyState` → `ContentUnavailableView`; drop card button style / `cyDomainScreen` | Claude App |
| R10-PC-C-N11 | P2 | — (native) | App/OfficialEventComponents.swift:121, 192-252, 297-307 | `OfficialEventCard` → plain row (no `CYStatusChip`/brand tint); `CYLoadSlot` → `ProgressView`; `OfficialFlowNotice` box and `Theme.Generated` tints → system | Claude App |
| R10-PC-C-N12 | P2 | — (native) | App/OfficialEventDetailView.swift:148-195, 366-380 | `CYHeroHeader`, mission `cyDomainCard`, `CYStatusChip`, facts `ScrollView` strip → system rows / `LabeledContent` | Claude App |
| R10-PC-C-N13 | P2 | — (native) | App/OfficialEventDetailView.swift:212, 262, 281-290, 429, 457 | `CYEmptyState`, `CYPillButton(Style)`, `cyDomainPageBackground`/`CYDomainPalette` tint, custom bar → `ContentUnavailableView`, `.borderedProminent`, `.safeAreaInset` with system button | Claude App |
| R10-PC-C-N14 | P2 | — (native) | App/OfficialPrivateViews.swift:22-73 | Inbox: `CYEmptyState` → `ContentUnavailableView`; `CYStatusChip` → `Label`; drop `palette.bgPage` background | Claude App |
| R10-PC-C-N15 | P2 | — (native) | App/OfficialActionViews.swift:24, 65-82, 143, 190, 239, 272, 371, 407 | `CYPillButton` → system buttons; `CYSkeletonBlock` → `ProgressView`; `CYEmptyState` → `ContentUnavailableView` | Claude App |
| R10-PC-C-N16 | P2 | — (native) | App/OfficialPrivateViews.swift:98-168, 244-277 | 我发布的: `CYStatusChip` → `Label`; `emptyRow` → `ContentUnavailableView`; drop `CYColor.bgPage`; inline stats as a normal `Button` row | Claude App |
| R10-PC-C-N17 | P2 | — (native) | App/OfficialOrganizerConsoleView.swift:156-195, 432-445 | `CYSkeleton`/`CYEmptyStateView`/`CYErrorStateView` → `ProgressView`/`ContentUnavailableView`; `CYConfirmSheet`+`CYConfirmConsequence` → `.confirmationDialog`/system sheet; drop `CYColor.bgPage` | Claude App |
| R10-PC-C-N18 | P2 | — (native) | App/OfficialOrganizerConsoleView.swift:353-356, 555 | `CYFilterChip` preset row → `Picker`; `CYPillButtonStyle` → `.borderedProminent` | Claude App |

Money, not a gap: host refund write (`App/AppSession.swift:3481-3482`, TEST-only) — the UI part is R9-PC-C1-2.

**Open after r10: P0 0 · P1 6 · P2 29** (35 rows: 14 parity incl. the 2 new regression rows R10-PC-C6-1/2, 3 r9 native, 18 new native). r9 rows fixed this round: 2 (R8-PC-C6-2, R9-PC-C3-1). r9 had P0 0 · P1 4 · P2 13.
