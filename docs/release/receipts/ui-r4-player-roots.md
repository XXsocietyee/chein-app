# Receipt · ui/r4-player-roots · player tab roots (screens r4)

Cloud agent, scheduled run 2026-11-21. Branched from `origin/ui/h-code-r3-ops` (c239789ec) as the shared brief
(`design/handoff-r2:docs/briefs/screens-r4.md`) says. **Swift is not installed in the cloud: nothing here was compiled,
run or screenshotted.** Every type, initializer and modifier was checked against code that already exists in the tree
(see "Compile risk" below). A local integrator has to build, run and shoot the checklist at the end.

Design sources used (no Figma access): `revise/skill-r2/js/_handoff.json` (frame → view table), `review/skill-r2.md`
SR2-02 / SR2-06 / SR2-20, `review/xrefs-1.md` B.2 + section 2 Adopt 3 / 4 / 6 / 9, `revise/xrefs-1/LOG.md`,
`revise/skill-r1/src/14-p-cleanup.js` (the 发布 root block: draft card, 新主题 / 新玩法, 从模板开始 and their copy),
`review/full-player.md` PL-30 + Q-B, `review/verify-r1.md` D-01 / D-16 / 2.5 / Q8, `revise/player.md` PL-22, and C1's
receipt `docs/release/receipts/ui-h-code-r3-player.md`. The js scripts in `revise/skill-r2/js` edit existing Figma
frames; they hold the copy and spacing quoted below, not whole layouts.

Status words: **done** (built to every rule the sources give; screenshot still to be taken locally), **partial** (what
is left is named), **left**.

## Frames

| Frame | Status | What changed | Left |
|---|---|---|---|
| `210:8239` 首页 (`HomeView` = `HomeFeedView`) | **partial** | 我的地盘 rail (SR2-02, xrefs-1 Adopt 9): header on the type scale (`CYTypography.sectionTitle`, the same as 编辑精选 / 附近活动, was raw `Font.title3`), title wraps and uses tabular digits for `今天 +N`; deeds snap to the margin (`.scrollTargetLayout` + `.viewAligned`), neighbours at 94 % / 70 % through `scrollTransition` (off under Reduce Motion), not clipped at the margin, press feedback (`.cyPressable`), places that join or leave on a reload fade in place on `CYMotion.standard`. 24 pt above the rail is kept (8 group spacing + 16 host padding). Pull to refresh is `.cyRefreshable` (light tick at release, 0.45 s floor). First-load stagger (`cyStaggeredAppear` / `cySectionReveal`) and per-rail in-place cross-fades were already there and are untouched. | The header itself (greeting, search field, 45 % empty first fold, xrefs-1 B.2) is the global-search owner's (`HomeHeroHeaderSectionView`); not touched per the brief. Tapping a deed still opens the roam map (existing destination kept); the zoom into the property sheet (xrefs-1 Adopt 1) needs the City sheet to accept a source id. The 编辑精选 carousel already had the focused-card transition (C1). |
| `210:8374` 发布 root (`PublishRootView`) | **done** (one gap) | New `App/PublishRootContent.swift`, used only on the tab: system large title 发布 via `cyRootHeader(.publish)` (was an empty inline bar + a hero header in the content). Order per SR1-07: **继续上次的草稿** card (56 pt thumb, eyebrow, the draft's name in two lines at most, `N 个地点` tabular; shown only when a quick draft is saved on this device: `PublishingDraftStore.loadActive`, so never a fake draft), **新主题** (路线、章节、地点) and **新玩法** (问答、拍照、竞速) as two equal 120 pt cards (stacked at accessibility sizes), 专业创建 rows (城市定向 / 自由探索), **从模板开始** (the template browser moved from a third toolbar button into the page, so the header is 消息 + one page action, verify-r1 2.5 / SR2-20), then 发布活动 / 我的项目 / 发布者身份. No emoji or colour icons (SR2-20), no empty placeholder cards (SR2-06). Stagger on first load (indices 0–4), the draft card arrives / leaves in place, pull to refresh re-reads the draft. | 继续上次的草稿 opens quick setup, where the existing 恢复本地草稿 row restores it. Auto-restore would need a line in `QuickPublishingView`, whose source slice is hash-locked by `test_activity_publishing_wizard` (as is all of `PublishingModesViews.swift`), so it was left. No "3 天前" (the local draft has no timestamp; not invented). The frame's 主题 / 玩法 chip tabs and a template rail need a template list read this root does not have; the section is a row into the browser. |
| `210:8603` 我的 root (`MeRootView` = `AccountView` + `PassportView`) | **done** (C1's partial finished, one item left) | **积分 first**: directly under the name / streak, as a plain number (`CYTypography.dataXL`, tabular, grouped digits `1,234,567`, shrinks to fit rather than truncating) with no tile (xrefs-1 Adopt 4); rolls with `cyNumericRoll` only when the value really changes (Adopt 3); unknown is "—" in tertiary ink, never 0. 积分 opens 钱包 (where 积分明细 lives) with a chevron on its label. **¥ only when present**: the 账户余额 column appears after a hairline only when the server sent a balance, formatted `¥560.00` (owner Q-B / Q8); the columns stack at accessibility sizes. One 票夹 entry (the card's pill); the duplicate 票夹 circle 250 pt lower is gone (verify-r1 D-16; same destination). Streak and late values arrive in place (`standard`), the card and the three overview blocks enter once (stagger 0–3), pull to refresh is `.cyRefreshable` and reloads in place. | The attributes card from the frame (`23 探索 …`) still has no read in this view (same as C1). The xrefs-1 Adopt 5 hide toggle was not asked for by the owner; not added. |
| `204:30158` 收集册 (`CollectionBookView` = `CollectionAlbumView`) | **partial** | Title rule: 收集册 is the inline nav title (it was a 28 pt display title drawn in the content under an inline bar). Segment chips: palette colours (were `Color.white` / `CYNight.ink0`), neutral selected capsule (`textPrimary` / `actionPrimaryFg`), the capsule slides to the picked chip (matched geometry on the existing `standard` swap; instant under Reduce Motion), chips scroll sideways for long English labels / AX sizes, `.cyPressable`, 44 pt height. Reduce Motion now reads `@QuestifyReduceMotion` like the rest of the kit. | The frame has no spec beyond its id here. The segments' own content (medals, stamps, objects: their empty states, loading and refresh) belongs to `RoamStampViews` / growth / object cards, outside this area. |

## Files touched

- `App/CityKit/CityHomeRail.swift` (rail on 首页; the 漫游 root and `CityRoamRootView` are untouched)
- `App/HomeFeedView.swift` (one line: `.cyRefreshable`)
- `App/MemberHomeHeader.swift`, `App/AccountView.swift`, `App/PassportView.swift`
- `App/PublishRootContent.swift` (new), `App/SessionPublishingModesView.swift` (chooses the root content on the tab;
  the two shared closures became helpers so each destination is written once), `App/PublishTabRootView.swift`
- `App/CollectionAlbumViews.swift`
- `Questify.xcodeproj/project.pbxproj` (the new file, via `tools/generate_project.py`; the regenerated test-plan
  shards were reverted to base, `check_scaffold` still passes the project-equivalence check)
- **Shared DesignSystem: no changes.** Not touched: global search, `CYTabs`, IM views, TopicDetail bottom bars, the
  漫游 root, `PublishingModesViews.swift` (contract-frozen).

## Skill rules applied

- apple-design-os `app-component-anatomy.md`: large title on tab roots that collapses on scroll (发布 now uses it);
  pushed pages inline (收集册). Type-and-chrome (consist-1) §2: no second page-type title in content.
- apple-design-interaction / mifb §16: 44 pt targets on chips, 积分, the draft card and the entry cards.
- apple-design-motion: Reduce Motion fallbacks on every new motion (rail transition off, chip capsule jumps, rolls
  cross-fade via `cyNumericRoll`); motion only on a cause (a real value change, a pick, a reload), never on a visit.
- emil choreograph: one entrance per container (blocks are siblings; nothing animates a parent and its children),
  no stagger on repeat UI (gates replay nothing after the first load or on refresh), choreography never blocks taps.
  Known gap: `cyStaggeredAppear` is a uniform 50 ms step (rule 3); it is the shared kit, not changed here.
- emil gestures: pull to refresh with a release tick and a floor so it never flashes; press scale on cards.
- emil break-ui: wrap names (draft title two lines, rail title wraps), never truncate numbers (积分 and ¥ shrink to fit,
  grouped digits), empty = the block is absent (no draft, no balance, no places), unknown = "—".
- emil write-swift / apple-design-foundations: tokens only (`CYTypography`, `CYSpacing`, `CYRadius`, palette), no raw
  `.system(size:)`, no raw colours; tabular digits for every changing number (mifb §9).
- xrefs-1 Adopt 3 (numbers roll), 4 (stats without a box), 6 (streak row kept from C1), 9 (focused card in a rail).

## Gates (cloud)

- `python3 -B tools/check_scaffold.py`: PASS (4919 Swift files, project equivalence).
- `python3 -B tools/check_design_lint.py`: PASS (0 violations).
- `python3 -B tools/contract_ratchet.py --check`: see the line below (filled after the run). Every contract module
  that names a touched file was run on this branch and on the base worktree: identical failures, none new.
  On the way, `test_activity_publishing_wizard` (hash lock on `PublishingModesViews.swift`) and
  `test_project_cloud_draft_intent` (one `cloudDraftProjectsHost` per host) caught two first attempts; both fixed.

Ratchet result (2026-11-21 run): `185 failing, baseline 184, new 1, fixed 0`. The one "new" id is
`test_workshop_paid_professional.PaidProfessionalContracts.test_current_generic_draft_cas_reuses_real_reader_with_bounded_paging`
(looks for `value.businessType == "TOPIC"` in `Core/WorkshopPaidProfessionalPreparation.swift`). It fails identically on
the base `origin/ui/h-code-r3-ops` (checked in a clean worktree), and this branch has no diff under `Core/` or `Tests/`:
it was already failing on the base and is missing from `docs/release/contract-failing-baseline.txt`, so it is not caused
by this branch. The baseline was not rewritten here (outside this area); the integrator should add it or fix the marker.

## Compile risk (checked by reading, not by a compiler)

- `PublishRootContent` memberwise init: parameter order matches the declaration order used in
  `SessionPublishingModesView`; `QuickPublishingView(placeSearch:account:draftStore:makeAIDraft:simplePageRead:openProfessional:)`
  matches its declarations.
- `cyRefreshable` closures are `@Sendable`; the `@State` writes go through `await MainActor.run { … }` (Swift 5 mode,
  same pattern family as `ActivityBrowserView`).
- `CYUnknownValue.text(points) { $0.formatted(.number.locale(locale)) }`, `AnyLayout` with `if let` inside its builder,
  `matchedGeometryEffect` inside `.background { if … }`: worth a glance if the build complains.

## LOCAL VERIFICATION CHECKLIST

Shoot each in dark (player) at default size and at AX3, zh-Hans and en:

1. **首页** (TEST, signed in with a CITY lease): the rail 24 pt under 编辑精选; swipe it: cards snap to the 16 pt margin,
   neighbours smaller and dimmer; turn on Reduce Motion: neighbours full size. A lease with 0 places shows the one-line
   empty. Pull to refresh: one light tick, rails stay and cross-fade, no re-stagger.
2. **发布** tab: large title 发布 collapsing on scroll; trailing items are 消息 and ⋯ only. With no saved draft: no draft card.
   Save a quick draft (新主题 → 保存本地草稿 → back): the card appears in place with its name and `N 个地点`. Edge data:
   a 40-character Chinese name (two lines, no clip), an empty name (未命名草稿), 0 places (meta line hidden), 128 places.
   Tap 从模板开始 → template browser (same destination as the old toolbar button, id `publishTab.openTemplates`).
   Non-club account: no 发布活动 row. AX3: the two entry cards stack. Pushed copy of the menu (template browser → 发布)
   is unchanged (hero header).
3. **我的**: order name → streak → 积分 → counters → 票夹 pill. Fixture data: 积分 `nil` ("—", grey), `0`, `1286`, `1234567`
   (no truncation); balance absent (no column, no hairline) and `560` (`¥560.00`). Change 积分 between two loads (pull to
   refresh): the digits roll once; a plain revisit does not roll. Tap 积分 → 钱包. Only one 票夹 entry on the page.
   First open: card then 钱包/消息 circles, stamps, badges enter once; switching tabs back does not replay.
4. **收集册** (漫游 → 邮票 or 勋章 tile): inline title 收集册 in the bar, no big title in the content; pick 勋章 / 邮票 /
   藏品: the white capsule slides, content slides from the side; Reduce Motion: capsule jumps, content cross-fades; en
   at AX3: chips scroll sideways.
5. Light theme sanity (editor domain is not involved, but the palette chips must read in both schemes).
