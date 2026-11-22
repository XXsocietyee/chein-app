# Receipt · integ-r3 → combined-r4 · Opus integrator (task_45b87e3b8efb)

Two phases. First `ui/h-integ-r3` (C1 + consist-1 + the four continuity branches + C2), pushed as a reference
branch. Then, on the coordinator's new plan, `ui/combined-r4` (everything plus the one-pass type sweep): made it
build, ported the integ-r3 fixes, kept the contract ratchet at its baseline, ran every gate, re-checked the
transitions on TEST. `ui/main` was not touched. No deploys. Local Mac, Xcode 27.2, sim Questify-iPhone17-Lane2
(2337B386, iOS 27), own DerivedData `DES-ag6-h-integ-r3` (deleted at the end), builds and simulator sessions under
`lockf /private/tmp/design-build.lock`.

Shots (local only): `/Users/fanning/chengyin-refs/integ-r3-shots/` (bursts: one folder per transition, `sheet.jpg`
per burst, file names carry the capture time) and `/Users/fanning/chengyin-refs/combined-r4-shots/` (main screens),
each with `index.md`. TEST = the app with `--e2e-test-host https://8120-…instabox.tech`, signed in by SMS as fixture
player 9009 (沪上寻踪搭子).

## 1 · ui/h-integ-r3 (reference, pushed at daa0c8f46)

Merges (no squash, in order): `ui/h-code-r3-player` 6597b85a5 → `ui/consist-1` e416bdf34 → `ui/c-cont-search`
281234b41 → `ui/c-cont-sheets` 82b579e2f → `ui/c-cont-tabs` 0811cf248 → `ui/c-cont-im` 698d5e52f →
`ui/h-code-r3-ops` c239789ec (added on the coordinator's request). No text conflicts. The four continuity branches,
written without a compiler, built on the first try.

| Commit | What |
|---|---|
| b18409640 | IM unread badge on C1's `cyNumericRoll` (was its own numericText + spring); one `HomeSearchMapGlyph` for the 首页 field and the travelling search field; C1's new raw fonts onto the consist-1 scale (ratchet) |
| 1af97840f | C2's new raw fonts onto the scale (only the lines C2 added) |
| 88bcebc63 | **search stuck invisible (bug):** see §3 |
| a9ef316eb | **search hand-over frame (bug):** see §3 |
| daa0c8f46 | **topic tabs never pinned after a tab tap (C1 bug):** see §3; GlobalSearchView byte pin bumped |

## 2 · ui/combined-r4: compile fixes (pushed first, 90a5c8200) and the rest

| Commit | What |
|---|---|
| 90a5c8200 | Build fixes. `DiceD20View`: the sweep's `.cyText` turned the die label into a View; `GraphicsContext.draw` needs a `Text` → static token font. `EditorDragReorderStack` (r4-config): "unable to type-check in reasonable time" → row chain, drop lines and feedback conditions split into typed pieces, behaviour unchanged. `CYBadgeUnlockCover` (r4-play): `Self.settled` for a static member |
| c49e55d3a, 3a842b1e6, 577e50cad | the integ-r3 search and tab fixes, cherry-picked (§3) |
| e1aca41eb | **contract-pinned files keep their reviewed bytes.** The sweep rewrote fonts in 14 files whose bytes / spans / regexes are pinned by contract checks: ratchet 185 → 194 (9 new). Each failing check was run on the pre-sweep commit (8 of 9 pass there; the 9th, `project_editor_readiness` `ProjectEditFixtureSupport.swift`, too after restoring that file), then the minimal set of files to restore was found per check (revert all candidates, put back every file the check does not need): `ClubGovernanceViews`, `ClubStoryViews`, `CoopRelationDiscoveryView`, `MerchantBusinessEditor`, `MerchantContentViews`, `MerchantEngagementViews`, `MerchantOperationsViews`, `NativeQRScanner`, `NativeVerificationView`, `ObjectBadgeViews`, `PublishingModesViews`, `SearchMapExplorerView`, `WorkshopPaidInstalledTextView`, `ProjectEditFixtureSupport` are back to pre-sweep bytes (no later commit touched them). Typography baseline raised for 5 of them (raw text style 1181 → 1199). A later contract-aware sweep can move those files together with their pins |
| 2d099fcad | IM badge on `cyNumericRoll`; GlobalSearchView byte pin follows the tree |
| 8a26c15d5 | `CodeR3OpsTests.testClubR4DateReadsTheSourceDayAsHandbookDate` fed 2026-11-15 (a Sunday) and expected 周六; the code was right (11月15日 周日). The handbook's 11月15日 周六 is 2025-11-15 |
| dbb4c1e4d | IM composer: ghost and receipt get an opaque field ground (see §3) |

Not ported: the shared `HomeSearchMapGlyph` (on combined-r4 both glyphs are still byte-identical; skipping it keeps
the sweep's typography baseline untouched).

## 3 · Transitions: verification on the simulator, and the fixes it needed

Method: real app on TEST; MCP `touch` (taps by accessibility element) while two interleaved `simctl io screenshot`
loops capture (≈ 0.2 s apart). Video frame extraction was not possible: the Bash sandbox blocks the video decoder
(`-12911`), and AXe taps from Bash are blocked too (testmanagerd socket). So a 350–450 ms spring yields one or two
mid frames per run, not a frame-by-frame scrub; where the mid frame was missed it is said below.

| Transition (branch) | Result | Evidence (`integ-r3-shots/burst/…`) |
|---|---|---|
| 首页 field → in-page search (c-cont-search) | **FAILED, fixed.** The layer mounted but never showed: `GlobalSearchFieldMorph` measured its rest frame through a GeometryReader placed *before* the travel offset computed from it, so `rest` flipped between two frames on every update (≈ 400 k updates in seconds), progress never settled, and the `.isModal` layer hid 首页 from VoiceOver (the accessibility tree collapsed to 1 element). The reader now sits after the offset; a pre-layout first frame outside the window cannot start the move | `search-open` (before/after) |
| same, hand-over frame | **FAILED, fixed.** On the frame the search field takes over, the layer's stack drew a large 搜索 title over 首页, and the field's magnifier/prompt were one step lighter than the 首页 field. Hosted root is now inline with its bar hidden; hosted field uses `textSecondary`. After: the hand-over frame equals 首页 at rest, the field leaves from its exact box | `search-open` (crop of frames 7 → 11), `comb-search-open` |
| search 取消 (close) | pass: field travels back, list fades, 首页 field returns in the same frame, no stuck overlay | `search-close` |
| typing / results swap, open result, back | pass: spinner ↔ clear trade places, skeleton fades in, result pushes inside the layer, back keeps keyword + results | `search-results` |
| topic bar 去票夹 → ticket sheet (c-cont-sheets) | pass for the recede (page to 0.96 and back, no jump; drag-dismiss returns it over two frames). The zoom out of the button fell between captured frames, so the zoom path itself is **not confirmed** by a frame | `topic-bar-tickets`, `topic-bar-tickets-dismiss` |
| 俱乐部 帖文/俱乐部 segmented tabs (c-cont-tabs) | pass: frame 5 catches the pill stretched (leading edge on 帖文, trailing edge still behind), labels cross-fade, lands on the rest box with no jump; old list fades as the new one comes | `comb-club-tabs` |
| topic 详情/故事/路线 tabs (C1 + c-cont-tabs) | **FAILED (C1), fixed.** A tab tap scrolls with `scrollTo`, which jumps; the inline row left the list without reporting a position above the pin line, so the pinned row never appeared (topics 992001, 993006, both hosts). A row that leaves while the page is on screen now pins. After: pinned under the bar with 路线 selected. The indicator's travel itself could not be caught (the row scrolls away in the same frame) | `topic-tabs`, `topic-tabs-home`; `combined-r4-shots/04-…` |
| 消息 row → chat (c-cont-im) | pass: system push, inbox title into Back, chat bar title (avatar + name) at rest by the next frame; transcript skeleton then content | `comb-im-row-to-chat` |
| IM send: spinner in the button, ghost → bubble, receipt in the field | pass with one **defect, fixed**: the field's own 输入消息 placeholder showed under the ghost while sending and under the receipt while it faded in (two texts overlapping). Both now sit on an opaque field ground from the first frame (only the words fade); re-checked on device ("test 31"). Remaining small artifact: during its 0.12 s fade the ghost's words drift down out of the field (the matched-position flight pulls them toward the inserted bubble). TEST messages "test 30" / "test 31" sent to 玩家小城 | `comb-im-send` (before), `comb-im-send-fixed` (after) |

### 3b · Second verify pass (task_82f07ede4735, build 7e9e57443 → b1c7eed71)

Method additions: three interleaved capture loops (~0.13 s between frames); MCP `batch` taps (several taps ~0.1–0.6 s
apart in one call) for repeated taps and close-then-reopen; short edge swipes and short sheet drags for gestures
released half-way. A simulator-wide slow-animation switch was tried (`-UIAnimationDragCoefficient 10` as a launch
argument) and has no effect, so true mid-animation taps are still not possible. Reduce Motion = the app's
`--uitesting-reduce-motion` switch (the same path `@QuestifyReduceMotion` reads). Bursts in `integ-r3-shots/burst/`,
stills in `combined-r4-shots/` (12–40).

| Check | Result | Evidence |
|---|---|---|
| Topic bar sheet: zoom path | **pass**: frame 5 catches the sheet as a small card growing out of 查看场次 (bottom-left) while the page behind fades back | `zoom-sessions` |
| Topic bar sheet: drag released early | **pass**: a short downward drag leaves the sheet presented (settles back) | `combined-r4-shots/12-…` |
| Activity footer 立即报名 → registration sheet | **FAILED, fixed (23a1fa233)**: the footer pill was **invisible at rest** (only "0 人已报名" showed; it drew over that line only while pressed), on TEST activity 993036 and in the `activity-collapsed` fixture; the 11-16 shots still show it. Cause: `cyHeroSource(…, cornerRadius: CYRadius.pill)`; the pill token is 499.5 and the `matchedTransitionSource` clip, which also applies to the resting source, does not clamp such a radius on iOS 27. `CYHeroSource` now measures the source and clips at most `min(w, h) / 2` (every other source already passed a real radius). After: pill visible. The zoom itself (the sheet opens) was not caught mid-frame. The fixture cannot open the registration sheet (it crashes: `SessionRegistrationSheet` needs `AppSession`, a fixture limit present on ui/main too) | `zoom-activity-test`, `combined-r4-shots/21-…` |
| Points ledger zoom (c-cont-sheets) | **pass on the pop**: frame 8 catches the 积分明细 page shrinking back into the balance card; the push lands with balance header, chips and history (the zoom-in fell between frames). 通行证与礼品 is **not reachable on TEST** (the pass-market binding is not injected for this session: not in 我的 or 设置), so this ran on a new DEBUG fixture `--design-fixture t5-pass-market-points` (7e9e57443) | `zoom-ledger`, `zoom-ledger-back` |
| Reduce Motion: search | **pass**: no travel; the layer switches inside one frame gap (a 0.2 s cross-fade) | `rm-search-open` |
| Reduce Motion: topic bar sheet | **pass**: plain slide-up, no zoom, page behind keeps full size (no recede) | `rm-topic-sessions` |
| Repeated taps: search 取消 then 🔍 (one batch, 0.15 s apart) | **pass**: the close completed before the re-open landed (~0.6 s), so this is close-then-immediate-reopen, not a mid-close retarget; no hidden field, no stuck layer | `int-search-close-reopen` |
| Repeated taps: topic tabs 路线→详情→故事, then on the pinned row 故事→详情→故事 | **pass**: ends on the last tapped tab, indicator under it, no stuck stretch | `combined-r4-shots/13-, 14-` |
| Back swipe released early (topic page) | **pass**: page and pinned tabs unchanged | `combined-r4-shots/15-` |
| C2 chapter delete with undo (`t11-fabu`) | **pass**: a chapter with nodes asks once (copy says it can be undone), deletes at once with the toast 已删除「The first clue」 撤销 and the quiet empty line; 撤销 within 5 s restores it with its node. (The first try missed the 5 s window and tapped the row under it, which opened the mode sheet: expected) | `combined-r4-shots/30–32-` |
| C2 reorder | **not testable on device**: the fixture has one chapter and 创建章节 needs a live lease (`starter.createChapter`), so ⋯ shows only 删除 and there is nothing to move; covered by `CodeR3OpsTests` / the list `onMove` | — |
| C2 pinned wizard bar (`d4-ops-create`, and TEST 俱乐部 → 创建俱乐部) | **pass** for the bar (开始创建 → 下一步 in one pinned bar, 第1步，共4步). Found and **fixed (a18105699, b1c7eed71)**: the step-0 title 建一个俱乐部 sat in the system List row fill, a white capsule under a light system appearance; with the fill cleared it took the system primary colour (black on the dark page), so it now uses the form palette's `textPrimary` and carries `.isHeader` like the step titles. Checked in light and dark, fixture and TEST. Pre-existing on ui/main | `combined-r4-shots/33-35-, 40-` |
| C2 refund pair (`--uitesting-merchant-business-fixture`) | **pass**: 不同意 · 同意退款 ¥12.00 pinned, equal widths; 同意 opens the response editor preset to 商家意见 · 同意申请. **Finding, not fixed:** inside that editor sheet the heading and form text are near-white on the white merchant sheet in both system appearances (unreadable). The presenter's sheet theming is unchanged from ui/main and `MerchantBusinessEditor.swift` is hash-protected (and back to its reviewed bytes), so this looks pre-existing (theme arbitration: Form text follows the host's dark scheme while `cyDomainSheet` paints the merchant light ground); not verified on a ui/main build | `combined-r4-shots/37-39-` |
| Light / dark system appearance | The simulator ran in **light** system appearance for every TEST check in §3 and §3b (player shell forces its dark palette: all player screens read correctly); light-domain pages checked: editor (`t11-fabu`), merchant aftercare, club wizard. Dark system appearance: club wizard (fixed) and the merchant editor (finding above). In the fixtures (not the app) a player page's navigation title can turn black under light because the fixture host does not apply the shell's scheme | `combined-r4-shots/30-, 35-, 37-40-` |
| VoiceOver focus | **Code review only** (VoiceOver cannot be driven from this sandbox): search moves keyboard focus into the field, marks the layer `.isModal` and returns `AccessibilityFocusState` to the 首页 field on close; sheets, pushes and the ledger rely on the system's focus hand-off; tabs keep the selected trait and label; the club wizard intro now has the header trait. Note: the automation snapshot still lists 首页 elements while search is open (it does not apply modal semantics), so "feed unreachable while search is open" is unconfirmed | — |

Shared worktree note: from 09:45 on 11-22 another agent (also a "combined-r4 verify" task) had uncommitted edits in this worktree (ChatMessageBubble, ClubHomeView, GameplayPresetSection, IMRecipientPreviewRow, SessionHomeFeedView, TopicDetailView). They are not in any of my commits, but the two builds at 10:01 and 10:15 compiled them, so the club-wizard re-checks (35-, 40-) ran with them in the app; every other §3b check ran on builds without them.

Still not verified on the device: a true mid-animation reversal (取消 while the open is running), long/short-text and
missing-image variants beyond the TEST data, and the inbox unread count-down (the list reload re-creates rows).

## 4 · Gates (ui/combined-r4, final tree)

| Gate | Result |
|---|---|
| Build (Questify, Debug, Lane2, `OTHER_SWIFT_FLAGS=$(inherited) -disable-sandbox`) | BUILD SUCCEEDED; build-for-testing (QuestifyAppUnitTests) TEST BUILD SUCCEEDED |
| `tools/check_scaffold.py` | PASS (re-run after the second verify pass: PASS) |
| design lint + typography ratchet | PASS (typography raw text style 1199 after the contract restores, see §2) |
| `tools/contract_ratchet.py --check` | 185 failing, baseline 184 (re-run on b1c7eed71: unchanged); the one "new" id is `test_workshop_paid_professional…bounded_paging`, red on `ui/main` (same as every r3 receipt). Before the restores: 194 / new 10 |
| Core `swift test --disable-sandbox` | 16 989 tests, **27 unique failing = baseline 27** |
| AppUnit, 4 shards (xctestruns from the shard plans, `test_sim`) | 6 / 15 / 27 / 26 failing → **74 unique names**. Against the 72-name baseline bundles (11-17/11-18, 75 names when read from the bundles): new = `CodeR3OpsTests…HandbookDate` (test bug, fixed, 10/10 after), one `OwnAccountRefreshOrderingTests` name (the intermittent ordering class: 4 of its baseline names pass this run; run alone it crashes inside XCTest's error observation), `RoamPrivateReadDenialHostTests…ReceiptRefusal` (one of the two known intermittent hosted-roam names). Against C1's 77: 0 new besides those |
| `RegistrationUncertainEvidenceCacheTests` (6, flagged by C1) | **pre-dates this work**: it already fails in the 11-16 r2-verify bundles (the 74-name list) and in the 11-17 bundles behind the 72-name baseline; fails again alone on this tree (XCTUnwrap of the evidence scope). Not caused by C1, C2 or the continuity branches |

Lock discipline: every build and test took the lock. Second pass: four full rebuilds (DerivedData deleted after each to keep the disk above 6 GB while the fix agents built), simulator batches of 15 minutes, one wait of ~10 minutes for the lock. Two slips, stated: one rebuild ran past the end of its 15-minute
simulator hold (05:03–05:18 on 11-21), and the 17-second `CodeR3OpsTests` confirmation ran just after a release.

## 5 · Left

- True mid-animation reversal and on-device VoiceOver (need frame-accurate input / VoiceOver; not possible from this
  sandbox).
- ~~Merchant aftercare response editor: near-white text on the white sheet (§3b)~~: fixed in §6 (fixture role root;
  the editor and its presenter are untouched).
- C2 reorder on device (needs a fixture with two chapters or a live lease).
- The 14 contract-pinned files still carry raw fonts; a contract-aware sweep should move them with their pins.
- `RegistrationUncertainEvidenceCacheTests` (pre-existing), the intermittent `OwnAccountRefreshOrderingTests` class.

## 6 · combined-r4 verification (task_ae4e670fb1b3, builds 993d5d347 → 28d9b2bdc)

Third pass, run in this same worktree while §3b ran (the two passes shared the tree; each committed only its own
paths). Own DerivedData `DES-ag6-c4v`, every build and simulator batch under the lock (batches 09:36–09:47,
10:27–10:35, 10:48–10:53, 10:56–10:57, tests 11:08–11:21), a disk watchdog that aborts a build below 6 GB free (it
fired once at 5 GB while other agents built; retried). To get the disk back I emptied Lane2's symbolication cache
(`data/Library/Caches/com.apple.coresymbolicationd/data`, 5.2 GB, rebuilt by the simulator on demand). One slip,
stated: the very first `simctl install` ran while another worker held the lock (install only, no build).

Reduce Motion here = the **system** setting (`defaults write com.apple.Accessibility ReduceMotionEnabled` on Lane2 +
relaunch), which also reaches the 66 views that read `accessibilityReduceMotion` directly (the in-app switch and
`--uitesting-reduce-motion` do not reach those). Shots: `/Users/fanning/chengyin-refs/combined-r4-verify/` (`index.md`;
bursts ordered by **write** time: a slow `simctl` capture can start earlier and land later, which made one search
burst look like it flickered).

### Fixes (all re-checked on the simulator, pushed to ui/combined-r4)

| Commit | Finding | Fix |
|---|---|---|
| 78324d048 | **Topic bar sheet zoom-back lands in an empty page.** Dismissing 查看场次 (drag or 关闭) reloads the topic; `load()` reset the page to the skeleton, so mid zoom-back the bar (the zoom source) was gone, the sheet shrank into the middle of a blank page and the scroll position was lost (`burst/int-bar-sheet-drag-cancel`, frame 10) | a reload of the topic already on screen keeps it until the new read lands; a failed refresh keeps it too; first reads unchanged (contract tokens kept). After: `burst/fix-bar-sheet-dismiss-after` |
| 4ee27427b | **IM sent bubble unreadable.** The 收件人预览 rows inside a sent bubble (light fill on the dark page) used the page's `textSecondary` (light grey on near-white) and the issued values `textPrimary` (white: invisible). Pre-existing (the §3 `comb-im-send-fixed` shot shows it) | `ChatMessageBubble` hands its ink down (`imPreviewInk`); other hosts keep the page tokens (`12-` before, `13-` after) |
| fe922e664 | **VoiceOver read 帖文 as 俱乐部.** The club top tabs' container label and id landed on both buttons (automation tree: two 俱乐部 buttons, both `clubTab.topTabs`) | one `.contain` container; the tree now reads 帖文 / 俱乐部 |
| fe922e664 | **Search open left the VoiceOver cursor behind.** The in-page search is a custom `.isModal` layer, so nothing moved VoiceOver off the hidden 首页 field | a screen change is posted once the field is placed (lands on the layer's first element, the field). Close already returned focus (`AccessibilityFocusState`) |
| be062b1c9 | **模板 › 玩法预设 rows centred their wrapped second line** (button label default; reads as a ragged block with the taller CJK lines) | leading alignment on the row (`25-`) |
| 28d9b2bdc | **Merchant refund editor sheet: near-white on white** (§3b finding). Fixture-only: the merchant-business fixture host had no role root, so the role defaulted to player; `cyDomainSheet` → `roleThemedPresentation` themed the sheet content dark over the merchant page's light ground, and no merchant bar chrome was installed (white large title). The app presents these pages under the merchant role root (`HomeSearchTabParityViews`: `cyScreenStyle` + `roleTheme(.merchant)`) | the fixture host does the same; `MerchantBusinessEditor` / `MerchantBusinessViews` untouched (hash-pinned), so no pin changed. Readable in light and dark (`40-`, `41-`). `check_merchant_business.py` (3) and the fixture-ownership contract (2) fail identically before and after (pre-existing) |

### Checks

| Item | Result | Evidence |
|---|---|---|
| 1 · Reduce Motion (system) | **pass** for the app's own motion: search open/close cross-fade in place (mid frame caught), club pill and topic tabs jump without travel, topic bar sheet plain (no zoom, no recede), drag-release settles. **System motion stays**: pushes still slide and the keyboard still rises (iOS keeps both under Reduce Motion; with RM the zoom pushes fall back to that plain push) | `burst/rm-*`, `10-` |
| 2 · Light / dark | player screens identical under system light and dark (the shell forces its palette); light editor pushed from the dark shell keeps a **dark status bar** in both (`30-`, `31-`); merchant editor sheet fixed (above). The merchant shell on TEST was not signed in (9009 is a player) | `20-`–`31-`, `40-`, `41-` |
| 3 · VoiceOver focus | **not runnable**: the simulator has no VoiceOver and the Accessibility Inspector cannot be driven from this sandbox. Checked through the automation (accessibility) tree and code: labels/ids (club tabs fixed), search open/close focus (open fixed, close already handled), sheets / pushes / City sheets / IM chat are system presentations (focus moves in and is restored by UIKit), IM chat has a header on the conversation name. The automation tree does not apply modal semantics (it lists the presenter under system sheets too), so it cannot prove what is hidden. Noted, not fixed: an empty-label `switch` beside 邀约提醒 in 消息 and an empty-label button next to the editor's ⋯; 玩法预设 rows read a trailing "—" | snapshots in this pass |
| 4 · Interruption | fast repeated taps (batch taps 0.05–0.1 s apart): IM row ×3 → one chat; zoom card ×2 → one page; 查看场次 ×3 → one sheet, one recede; 首页 field ×2 → one layer. Drag released half-way: sheet settles back (RM and normal). 取消 then 首页 field: ends clean, but the second tap did not land mid-close (MCP tap latency). Back during a zoom / short edge swipe: the swipe preset did not engage the pop, so not shown | `burst/int-*` |
| 5 · Zoom paths | topic bar sheet: open (one sheet + recede), dismiss **fixed** (above); card → topic and back: system zoom, mid frames missed; points ledger and activity zooms: covered by §3b (pass, pill fixed there). The 我的 积分 tile opens 账户收益 (wallet), not a ledger: as designed in `AccountView` | `burst/zoom-*`, `fix-*` |
| 6 · C2 flows | covered by §3b (delete + undo, pinned wizard bar, refund pair: pass). Extra: on TEST the editor's 创建章节 does nothing for 9009 (`starter.createChapter` needs an opening lease), same root cause as §3b's "reorder not testable" | — |
| 7 · Typography (new line heights) | 15 screens, no clipped or overlapping text: 首页, topic detail (+ pinned 路线/故事), 筛选 sheet, 消息, IM chat, 俱乐部, 我的, 发布, 模板 (fixed), 漫游, City passport sheet, editor, 开局大厅 (`t5-seats`), 通行证 balance (`t5-pass-market-points`), merchant aftercare editor. **Dynamic Type XXL** (`simctl ui content_size extra-extra-large`) on 首页, topic detail, pinned tabs, 开局大厅, 俱乐部: everything wraps (titles to two lines), no clipping, bars keep their height | `20-`–`29-`, `50-`–`54-` |

### Gates (tree 28d9b2bdc)

| Gate | Result |
|---|---|
| Build (Questify, Debug, Lane2, arm64, `OTHER_SWIFT_FLAGS=$(inherited) -disable-sandbox`) | BUILD SUCCEEDED on every fix; build-for-testing (QuestifyAppUnitTests) TEST BUILD SUCCEEDED |
| `tools/check_scaffold.py` | PASS (the a11y lint inside it rejected a first IM fix that used `.secondary` / opacity; the shipped fix uses CY tokens) |
| design lint + typography lint | PASS; typography raw text style 1199 (unchanged) |
| `tools/contract_ratchet.py --check` | 185 failing, baseline 184, new 1 = `test_workshop_paid_professional…bounded_paging` (red on `ui/main`, as in §4): **unchanged** |
| AppUnit, 4 shards (xctestruns from the shard plans, `test_sim`) | 6 / 15 / 26 / 25 failing → **72 unique names, 0 new** against §4's run of this branch (bundles 11-22 15:43–15:50): gone = `CodeR3OpsTests…HandbookDate` (fixed in §2) and `OwnAccountRefreshOrderingTests…NewPhoneLoginCannotClearNewCredential` (intermittent class). Targeted run first (13 classes near the changed views, 121 tests): 117 pass; the 4 failures (`ProfileFavoriteTopicReadTests…ChapterCoverReturn…`, 3 `RoamNearbyEventsOriginalHostTests`) are in the 15:45 / known-hosted baseline |

Not re-run: Core `swift test` (no file under `Core/`, `Tests/CoreTests` or `Package.swift` changed since §4's 27 =
baseline run; the Core package does not compile `App/`).

### Left

- On-device VoiceOver and true mid-animation reversal (needs VoiceOver / frame-accurate input).
- The merchant shell on TEST (sign in as 9002) for a light-domain pass with live data; aftercare is closed on TEST.
- The two empty-label accessibility elements above; the topic route card stack's square inner corners (`11-`), a
  pre-existing list-section look, not a type-sweep effect.
