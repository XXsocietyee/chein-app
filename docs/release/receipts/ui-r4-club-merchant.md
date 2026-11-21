# Receipt · ui/r4-club-merchant (screens r4 · club, merchant, creator)

Base: `origin/ui/h-code-r3-ops`. Brief: `docs/briefs/screens-r4.md` on `design/handoff-r2`. Scope: the club workbench
`170:1744` and the club, merchant and creator frames that `ui-h-code-r3-ops.md` and `ui-h-code-app.md` left or marked
partial. Where a frame says nothing, the mini-program's structure wins. Swift isn't installed in the cloud, so nothing
here has been compiled or screenshotted. Every type, initializer and modifier was checked against existing code. The
local integrator builds and shoots from the checklist at the end.

Status words: **done** (in code; a screenshot is still owed locally), **partial** (the missing part is named), **left**.

## Club (R3)

| Frame | View / files | Status | Notes |
|---|---|---|---|
| `170:1744` workbench (MC-28) | `ClubDetailView` 管理 tab → `ClubWorkbenchSection` (`App/ClubKit/ClubWorkbenchKit.swift`, `Resources/ClubR4.xcstrings`) | **partial** | 现在要做 card with one primary (去审批 → 入会申请), then three tappable tiles 待审批 · 待核销 · 本周场次. Only 待审批 is read (`pendingJoinRequestCount`); the other two show "—", never 0 (owner rule), and the card is left out when nothing is known. The project and management rows keep their order below. **Left:** the ⋯ menu and moving 扫码 + 团码 into the nav bar. The club 管理 tab has no club-level scan or team-code entry (both live per session under 活动), so there is nothing to move. 项目 rows with a status sub-line: no project-status read at club level. |
| `204:24899` header · MC-22 | `ClubDetailView` header + `ClubHeaderShareButton` | **done** | 邀请朋友加入 is the header's one full-width action for members and the owner. Share is in the bar beside the system back. Both share the existing text invitation, since clubs have no invite link. |
| `204:24899` 下一场活动 card, member avatars | — | **left** | `/api/club/detail` (`ClubRecord`) has no next-activity or avatar read. Owner rule: hide rather than invent. |
| Roster (MC-25) | `ClubEnrollmentView`, `ClubWorkbenchKit` (`ClubR4Date`) | **done** | Roster card dates read as in the handbook, `11月15日 周六`. Free text such as `下周六` passes through unchanged. |
| Settlement wording (MC-29) | `App/ClubSettlementDetail.swift`, `Resources/DesignR1Club.xcstrings`, `tools/build_design_r1_localizations.py` | **done** | Each row keeps only title / status / date / amount. An unverified amount shows "—" with a 待核验 tag. The button reads 申请提现. Money stays TEST-only behind the existing switches. |
| `222:5684` consequence sheet · 结束主题 | `App/ClubKit/ClubGovernanceConsequence.swift`, `Resources/OpsR3.xcstrings` | **done** | 结束主题 joins 封禁 · 转让 · 撤销身份 · 解散 in `ClubConsequenceSheet` and is still confirmed exactly once. |
| `223:3698` member sheet row menu | `ClubMembersView` → `ClubMemberActionMenu` | **done** (earlier round) | Checked: the ⋯ pull-down (举报 · 设为管理员 · 临时封禁 · 移除) is already in code. No change. |
| Organiser actions (MC-21) | `ClubManagementView` | **done** (earlier round) | Checked: 拒绝 · 通过 are 44 pt and 12 pt apart, with swipe. No change. |
| `210:8452` 俱乐部 root meta line / 下一场 | `CYClubRowCard` (DesignSystem) | **left** | A shared DesignSystem card with the join-motion choreography, on the player side. There is no next-activity read, and the one-line meta change belongs to the player root owner. |

## Merchant (R4 / R5)

| Frame | View / files | Status | Notes |
|---|---|---|---|
| `182:8065` 营销 · SR2-15 icons | `App/MerchantMarketingHomeSections.swift` | **done** | Four distinct glyphs, as the Figma's Icon/chart · store · route · cal: `chart.bar.xaxis` · `storefront` · `point.topleft.down.to.point.bottomright.curvepath` · `calendar.badge.plus`. **No extra 96 pt inset:** the system tab bar already insets the List's scroll content, so 96 pt more would leave a band. Check that on device. |
| `186:6119` 协作详情 · MR-36 rating | `App/CooperationInviteActionSections.swift` (`CoopStarRatingControl`) | **done** | Five tappable stars in place of the pick sheet. The word under them follows the tap (the existing `CoopReviewScore` copy), then 下一步 › opens the same optional comment and request review. Each tap gives one `.selection`. **No stagger or pop:** the Figma motion (40 ms stagger, 1.15 pop) conflicts with the contract `test_cooperation_structure…no_custom_motion` (no `.animation` / `.scaleEffect` on cooperation pages), so the contract wins and only the symbol swaps. VoiceOver: one adjustable element, "评分 N / 5". |
| `186:6119` · MR-36 terms and actions | `App/CooperationInviteDetailView.swift`, `App/CooperationInviteActionSections.swift` | **done** | The terms stay a LabeledContent table and the split (分成) row is the one semibold row. 取消合作 (or its locked note) sits alone in the last group, below 联系对方 / 申报 / 评价. |
| `233:9703` 暂停接待 in a ⋯ menu | `MerchantGameNodeView.runCard` | **left** | UI tests (`MerchantGameNodeFlowTests`) tap `gameNode.pause` directly. Moving it into a menu changes those flows, and they can't run in the cloud. The quiet red row keeps it reachable. |
| MR-37 / MR-25 (merchant cards, address map snapshot) | — | **left** | Not started this round. |

## Creator (editor)

| Frame | View / files | Status | Notes |
|---|---|---|---|
| `237:32444` 地图视图, full-bleed | `App/ProjectEditOverviewKit.swift` (`ProjectEditNodeMap(fullBleed:)`, `ProjectEditNodeMapPage`), `Resources/OpsR3.xcstrings` (`editor.map.open`, `editor.map.title`) | **done** | Inside the Form the map is a 220 pt still preview (`interactionModes: []`, pins not tappable), so a drag over it scrolls the page. That fixes the r3 left item. 打开地图 (a capsule, the whole preview is the target) pushes the full-bleed page: the map runs under the nav bar and to the bottom edge, the inline title is 地图, the system back returns to the Form, compass and scale are on, and the selected pin grows to 1.15 with the node card and 编辑节点 floating above the home indicator. The unplaced count stays under the map. |
| `239:31923`, `238:20393`, `249:16773`, `249:46938`, C2 / C3 | — | **left** | Editor pages beyond the map are outside this branch's frames. |

## Shared changes

- None to DesignSystem. `CYMotion` and the tokens are used as they are.
- Strings: `Resources/ClubR4.xcstrings` (new, from the earlier commits) and two keys added to `Resources/OpsR3.xcstrings`.

## Skill rules applied

- apple-design-interaction: "Make targets reachable & affordant: ≥44 pt". Stars, 下一步 and 打开地图 are all ≥ `CYSpacing.minTouchTarget`. "Scroll is an input — decide consciously": the map preview no longer captures the page's scroll.
- apple-design-motion: "Every action gets feedback": the stars fill and tick with one `.selection` per commit, no double-firing. The editor map pin keeps its existing interruptible 1.15 spring.
- apple-design-foundations: no ignored safe areas. The full-bleed map ignores only the container insets; the node card and the unplaced line keep them.
- emil choreograph: one lead per change. On the map page the pin leads and the node card follows; everything else stays still.
- emil mobile-native and haptics: the haptic fires on the same frame as the visual and is never the only feedback.
- mifb make-interfaces-feel-better: the hit targets are larger than the glyphs (stars, map preview), and unknown counts show "—".
- Owner rules: never 0 for unknown (workbench tiles); money stays TEST-only (settlement, 申请提现); no feature hidden (暂停接待 stays a row).
- consist-1 type-and-chrome: system back only, inline 17 pt title on the pushed map page, no custom chevrons, `CYTypography` tokens in all new code.

## Gates (cloud, on this branch's tip)

| Gate | Result |
|---|---|
| `python3 -B tools/check_scaffold.py` | PASS (structural, bilingual keys, routes) |
| `python3 -B tools/check_design_lint.py` | PASS (0 violations) |
| `python3 -B tools/contract_ratchet.py --check` | First run: 186 failing against a baseline of 184, 2 new. (1) `test_cooperation_structure…no_custom_motion`, caused by this branch's star animation, now fixed (the class passes). (2) `test_workshop_paid_professional…generic_draft_cas…`: it asserts on `Core/WorkshopPaidProfessionalPreparation.swift`, which this branch does not touch (no Core diff against the base), so it is a base or baseline mismatch, not a regression from this branch. Re-run result below. |
| Swift build, unit and UI tests | **not run** (no Swift in the cloud). New tests in `Tests/AppUnitTests/CodeR3OpsTests.swift`: `testClubWorkbenchSummaryKeepsUnknownAsDash`, `testClubR4CopyIsBilingual`, `testClubR4DateReadsTheSourceDayAsHandbookDate`, `testEditorMapPreviewAndPageCopy`, `testCoopStarMapsOntoTheReviewScore`. |

## Local verification checklist

1. **Build** the app and the AppUnit target. Run `CodeR3OpsTests`, `PremergeScreensViewModelTests` (CoopReviewScore), `MerchantGameNodeFlowTests` (UI, unchanged) and the cooperation-detail classes.
2. **Club workbench** `170:1744`: log in as 9003 (club owner). Open the club → 管理. Shoot the head with `pendingJoinRequestCount` > 0 (去审批 pushes 入会申请), with 0 (quiet line, no button), and missing (no card, tiles "—"). Fixture: `d4-tab-manage` in `DesignFixtureRegistry`. Dark player theme.
3. **Club header**: 邀请朋友加入 as a member and as the owner, share in the bar. Both open the system share sheet with the text invitation.
4. **Roster / settlement**: roster card date `11月15日 周六`; a settlement row with an unverified amount shows "—" and 待核验, and the button reads 申请提现 (TEST switches only).
5. **结束主题**: run the governance end-topic command and shoot the consequence sheet. Confirm it asks once.
6. **营销** `182:8065`: four different icons. Scroll to the bottom and check that the 优惠券 card's last line clears the tab bar with no overlap and no extra band.
7. **协作详情** `186:6119`: an accepted invite where the viewer can review. Tap star 3, then 5: the stars fill and the word changes (3 星 · 一般 → 5 星 · 很满意) and 下一步 appears; it opens the comment prompt and then the request review. With VoiceOver, swipe up and down on the rating. Check the bold 分成 row and 取消合作 alone in the last group.
8. **Editor map** `237:32444`: topic editor → 列表 / 地图 → 地图, on a topic whose nodes have coordinates. A drag over the preview scrolls the Form. Tap 打开地图: the full-bleed page shows the map under the bar, tap a pin to get the 1.15 pin and the node card, then 编辑节点 pushes the node, and back returns to the map and then to the Form. Edge data: no coordinates (empty overlay, no 打开地图), one pin (street-level span), unplaced nodes (count under the map). Interrupt the push with an edge swipe halfway.
9. **Light/dark**: merchant and editor pages stay light, the club stays dark player.
