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

Not verified on the device (honest list): Reduce Motion, light mode and VoiceOver focus for each transition; fast
repeated taps and mid-animation reversal (MCP tap latency is ≈ 1–2 s, so taps cannot be placed inside a 0.4 s
animation); long/short text and missing-image variants beyond the TEST data; the points-ledger zoom (通行证与礼品),
the activity footer zoom, the inbox unread count-down (the list reload re-creates rows, per the c-cont-im receipt),
and C2's in-place results / chapter delete with undo / reorder / pinned wizard bar / refund pair on the simulator
(covered by their AppUnit tests, which pass: `CodeR3OpsTests` 10/10).

## 4 · Gates (ui/combined-r4, final tree)

| Gate | Result |
|---|---|
| Build (Questify, Debug, Lane2, `OTHER_SWIFT_FLAGS=$(inherited) -disable-sandbox`) | BUILD SUCCEEDED; build-for-testing (QuestifyAppUnitTests) TEST BUILD SUCCEEDED |
| `tools/check_scaffold.py` | PASS |
| design lint + typography ratchet | PASS (typography raw text style 1199 after the contract restores, see §2) |
| `tools/contract_ratchet.py --check` | 185 failing, baseline 184; the one "new" id is `test_workshop_paid_professional…bounded_paging`, red on `ui/main` (same as every r3 receipt). Before the restores: 194 / new 10 |
| Core `swift test --disable-sandbox` | 16 989 tests, **27 unique failing = baseline 27** |
| AppUnit, 4 shards (xctestruns from the shard plans, `test_sim`) | 6 / 15 / 27 / 26 failing → **74 unique names**. Against the 72-name baseline bundles (11-17/11-18, 75 names when read from the bundles): new = `CodeR3OpsTests…HandbookDate` (test bug, fixed, 10/10 after), one `OwnAccountRefreshOrderingTests` name (the intermittent ordering class: 4 of its baseline names pass this run; run alone it crashes inside XCTest's error observation), `RoamPrivateReadDenialHostTests…ReceiptRefusal` (one of the two known intermittent hosted-roam names). Against C1's 77: 0 new besides those |
| `RegistrationUncertainEvidenceCacheTests` (6, flagged by C1) | **pre-dates this work**: it already fails in the 11-16 r2-verify bundles (the 74-name list) and in the 11-17 bundles behind the 72-name baseline; fails again alone on this tree (XCTUnwrap of the evidence scope). Not caused by C1, C2 or the continuity branches |

Lock discipline: every build and test took the lock. Two slips, stated: one rebuild ran past the end of its 15-minute
simulator hold (05:03–05:18 on 11-21), and the 17-second `CodeR3OpsTests` confirmation ran just after a release.

## 5 · Left

- Reduce Motion / light / VoiceOver / interruption passes per transition (needs frame-accurate input; not possible
  from this sandbox).
- The 14 contract-pinned files still carry raw fonts; a contract-aware sweep should move them with their pins.
- `RegistrationUncertainEvidenceCacheTests` (pre-existing), the intermittent `OwnAccountRefreshOrderingTests` class.
