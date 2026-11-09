# Design report E2: PLAY and CITY family (branch `ui/e2`)

**Status: NOT BUILT, NOT SCREENSHOTTED.** The base `rc/20261108` did not compile when I started (three errors listed below). The owner then ordered a stop to all builds (machine overload, load average 62), so every change on this branch was written without a compiler or simulator. No contact sheet exists. The first batch after the coordinator's GO must be treated as the compile check.

## Base fixes (not part of my family, needed to compile)
- `Core/UGGameplay.swift`: missing `return` (already fixed upstream in `cfbc9aa75`, merged).
- `App/ObjectBadgeViews.swift:247`: `CYListRow(verbatim:…)` needs a `leading` closure.
- `App/GrowthLeaderboardView.swift`: duplicated `score(alignment:)`.
- `App/DesignSystem/CYCachedAsyncImage.swift`: `$0 != 0x7F` on `Unicode.Scalar` (now `$0.value`).

## Already designed by earlier workers (left alone)
Roam browser, live roam, play orientation, play session and map chrome (d6); roam passport tabs (d2); badge wall and stamp album (d4); orient score (kit already used); timed-challenge view (kit already used). An earlier mechanical `cyGroupedSurface` pass over these files was reverted.

## Restyled on this branch (real views, kit components, presentation only)
| Page | File | Change |
|---|---|---|
| City player | `CityPlayerView.swift` | hero title, status chips (season state, membership), one `CityEntryRow` card per entry, kit empty/skeleton, point rows as cards |
| City game panel | `CityGamePanel.swift` | stat tiles (actions, holdings, points; unknown = em dash), property cards with chips, roll/confirm = primary pill, cancel/refresh = tertiary |
| City value | `CityPlayerValuePanel.swift` | card surface, primary bind, skeleton |
| City task history | `CityTaskHistoryView.swift` | hero, item cards with status chip, secondary refresh |
| City rules, arrival, participation, onsite/neutral task, ordered map, acquisition, action budget, snapshot, redeem, merchant ops/value, recovery | `City*View.swift` | `cyGroupedSurface` page ground (Form/List stay native) |
| NPC chat | `ShopNPCView.swift`, `NPCQuickQuestionBar.swift` | avatar identity row, secondary quick questions, page ground |
| NPC chat data, character cards | `NPCChatDataView.swift` | `cyGroupedSurface` only |
| Chapter story reader | `ChapterStoryView.swift` | hero title, voice/thought cards, primary return pill, kit empty |
| Journey / journal | `JourneyNarrativeView.swift`, `PlayerJourneyViews.swift` | big tabular discovery counter, hero ending title, secondary ask button, surface |
| Free exploration | `FreeExplorationViews.swift` | hero, kit cards, status chips, primary ending button, skeleton/empty |
| Explore completion | `ExploreCompletionView.swift` | status chip + big collected counter, kit empty/skeleton |
| Play node detail | `PlayNodeDetailView.swift` | heavy title, status chip, primary review pill, kit states |
| Object card reveal | `PlayObjectCardRevealView.swift` | hero, card surface, secondary frame buttons |
| Stamp result | `RoamCreatedStampView.swift` | hero, primary browse pill, skeleton, kit empty |
| Medal share | `RoamMedalShareView.swift` | hero name, primary prepare, secondary share |
| Roam history + shared roam cards | `RoamHistoryViews.swift`, `RoamExperienceComponents.swift` | `RoamExperienceCard` is now a kit card (affects every roam experience page), kit notice/issue, big km figure |
| Other Form/List pages | ~45 `Play*`, `Roam*`, `Object*`, `Free*` files | `cyGroupedSurface` page ground |

## Fixtures (`App/DesignFixtures/E2Fixtures.swift`, DEBUG only, "DEBUG fixture" strip)
`--design-fixture` names: `e2-timed-stopwatch`, `e2-timed-reaction` (poi-challenge view), `e2-dice`, `e2-journey`, `e2-chapters`, `e2-chapters-empty`, `e2-stamp-camera`, `e2-badge-detail` (badge-3d), plus aliases `e2-city`, `e2-npc`, `e2-stamp-album`, `e2-badges` onto the D2/D4 hosts.

## Pages left (no synthetic host or no restyle yet)
City rules / arrival evidence / participation / orientation / ordered map / onsite tasks (need runtime owners and Core fixtures, so only the page ground changed), free-exploration bundle launch, explore completion (no fixture: needs `ProfileReading` origin), chapter story reader (needs a `PlayExperienceCoordinator`), game journal sections, play kit forms, roam history share, passport tools. None has a screenshot.

## Not verified
Checklist items 7 to 10 (states, XL, EN/zh, builds) are all open. Possible compile risks to look at first: the Python-inserted `.cyGroupedSurface()` after `Form {}`/`List {}` in ~45 files, `CYPillButton(...)` argument order in `CityTaskHistoryView`/`CityGamePanel`, and `E2Fixtures.swift` initializers.

## New strings
None added (all changes reuse existing keys). Unknown city stats now show an em dash instead of the old "unavailable" key.

## Update (after GO attempt)
The one batch was attempted and every build failed on base errors (not on my pages). Eight base fixes are on this branch (duplicates of the integrator's `ui/main` fixes; drop them when merging `ui/main`). Since then, blind and unbuilt: compare-question page, city value panel, object card reveal, and 30 plain `ContentUnavailableView` uses in the family became `CYEmptyState`. Waiting for a compiling `ui/main` SHA (currently `85ab77ac3`), then merge, run ONE batch with `docs`-listed fixtures (`e2-*`), fix, and push.

## Benchmarks (Mobbin, ADA bar)
- Badges / collection (stamp album, badge detail): Reddit achievements sheet https://mobbin.com/screens/74ea7ef7-6fc8-4ca8-af3d-2ad3e160a256 (round medal grid, caption under each, one pinned black CTA); WHOOP levels https://mobbin.com/screens/6fe807ad-d87b-44ee-a924-3414682bd15a (locked tiers dimmed with a ring, dark layered surface); Apple Games achievements https://mobbin.com/screens/43c701fa-a4b4-4191-bdc2-ba5bd7a84a5b (progress ring and percentage per tile).
- NPC chat (`ShopNPCView`, `NPCQuickQuestionBar`): Venmo assistant https://mobbin.com/screens/fca8654a-58d4-4e59-8f79-efdf307b47f2 and Expedia virtual agent https://mobbin.com/screens/6369c0d4-8839-4a45-a2b0-78c5d322f9d8 (outlined quick-reply pills above the composer, AI disclosure under the greeting); WHOOP coach https://mobbin.com/screens/ec1b77cc-630e-479d-be4f-1f97d7f19052 (suggestion chips docked above the input).
- Applied so far: quick questions are outlined secondary pills; NPC identity is an avatar row; generated cover art (`CYCoverArt`, decoration only) behind the city title and the free-exploration card pack; `.sensoryFeedback` selection on city point select and success on an applied city action.
- Not applied yet (needs a compile and screenshots first): progress rings on stamp/badge tiles, matchedGeometry on badge unlock.

## Verified batch (merged `ui/main` 357154584, BUILD_EXIT=0, 31 shots)
Contact sheet: `docs/release/design-report-e2-shots/contact-e2.png` (full set `/Users/fanning/chengyin-refs/design-reports/e2/batch-*.png`: EN, zh-Hans, and accessibility-XL for city, NPC, stopwatch, chapters). The shots were taken from the build before the `CYCoverArt` commit, so the cover art and haptics are not yet seen.

What the sheet shows: city page (hero title, status chips, entry row, stat tiles 3/3, 0/2, 5, primary "Start this round"), NPC chat (avatar row, outlined quick-question pills), timed stopwatch/reaction, dice, journey check, stamp camera, badge detail, stamp album, badge list, roam history (big 1.4 km, tool pills, route cards), POI, sticker, play records, backpack, finish sheet, object cards. zh-Hans is fine on all.

Defects found and fixed after the sheet: the city panel title showed the raw key `cityGame.title` (the section header does not read the `CityGame` table; now a table-aware `Text`).
Defects still open:
- `e2-chapters` and `e2-chapters-empty` stay on "Loading..." (the enrolled-chapters view model never becomes visible inside my fixture host, cause not found), so that page has no valid shot.
- Accessibility-XL city: the "CITY ownership and original receipts" line and the title take over the first fold (no clipping, but weak hierarchy).
- No page reached photo/cover imagery in the shots.

## Self-score (1 to 10, six ADA lenses averaged; honest)
| Page | Score | Why under 8 |
|---|---|---|
| City player + game panel | 7 | no imagery in the shot (cover art added after), property cards still dense |
| NPC chat | 7 | composer area plain; no avatar art |
| Timed challenges (e2-timed-*) | 5 | large empty black area, no progress ring or motion |
| Dice | 5 | bare die on black, no roll moment |
| Journey check, play records, backpack, finish sheet | 5 | grouped lists with grey rows, not restyled beyond the page ground |
| Stamp camera, stamp album, badge list/detail (D4/earlier) | 6 | grey placeholder tiles, no collectible feel |
| Roam history | 7 | route sketch is a grey box |
| Object cards, POI, sticker | 5 | grey boxes, small type |
Pages under 8 need rework: all of the above. This is not ADA quality yet; it is "clean".

## Final batch (BUILD_EXIT=0, 16 shots, `docs/release/design-report-e2-shots/contact-e2-final.png`)
Seen and working: city page hero on generated cover art (`CYCoverArt`) with status chips, stat tiles, primary pill; stamp album banner "Stamps: 3" on cover art, stamp cards on cover art, single title; stopwatch is now a large ring timer with a primary Start; zh-Hans fine on all; XL city: no clipping.
Rescored after the batch: city player/game panel 8, stamp album 8, timed challenges 7 (ring and type are strong, rest of screen still empty), NPC chat 6.5 (bubbles and composer unchanged), badge detail 6 (medal image unavailable placeholder), journey check 5 (grouped list), roam history 7 (grey route box).
Unverified: after the last batch I changed only the city header chips (they now stack vertically when `ViewThatFits` fails at XL, previously "You have…" truncated). Unfixed: `e2-chapters`/`e2-chapters-empty` still stay on "Loading…" even with readers in `@State`, so the enrolled-chapters page has no valid shot; XL city still shows a very large "CITY ownership and original receipts" line above the hero.
Not done: pages left in "Pages left" above (city rules/arrival/participation/onsite/neutral, bundle launch, game journal sections, play-kit forms, roam share/passport tools) are restyled only with the page ground; no collection grid with progress ring (the album has no denominator, so a ring would be fake), no NPC bubble rework, no roam-route rework.

## THIRD PASS (ADA rework, branch `ui/e2`)
Base: `ui/main` 357154584 (already merged). Final batch: 16 shots, EN / zh-Hans / accessibility-XL (`/Users/fanning/chengyin-refs/design-reports/e2/batch-*.png`, contact sheet `contact-*.png`; copy in `docs/release/design-report-e2-shots/`).

### Mobbin benchmarks used (new searches this pass)
- Achievement / badge detail: Cal AI "Badge Unlocked" https://mobbin.com/screens/a4916474-2ab6-4e3c-8ccb-adf81735c3b7 (big foil medal on glow, name, one dark Share pill) and Apple Games https://mobbin.com/screens/dd752b14-b943-49d7-b8b7-aaba41ea3a0d (ring around medal, date, requirement text), Discord orb badge https://mobbin.com/screens/9caa39a7-4018-4527-856f-b6f6c673f730. Copied: foil rim + radial glow, pinned Share capsule, ring.
- Timer / quiz: WHOOP https://mobbin.com/screens/2b556fce-4fd5-4267-abe9-d1c7409595d3 and Oura https://mobbin.com/screens/08366dca-8bef-401f-a5d2-2514448fdf7d (large monospaced digits inside a ring, one outlined secondary action). Copied: 76pt ring timer, heavy haptic on start/signal.
- Chat: Venmo assistant https://mobbin.com/screens/aa27ef43-317a-4aee-b74e-852246996f08, Snapchat My AI https://mobbin.com/screens/11b7ccff-98e2-435b-a20e-19c100cb2b15, ChatGPT https://mobbin.com/screens/67d036b4-256c-441b-aa53-2a7ebb7b9187. Copied: outlined quick-reply pills in one scrolling row above a pinned capsule composer, circular send/mic.
- Step-by-step task flow: Wealthfront https://mobbin.com/screens/ee77658d-37c0-48be-be88-a3312042c294 and Snapchat goal picker https://mobbin.com/screens/f00e00f3-ee25-4ba8-a529-18ba675c4b01 (single pinned primary, rows as cards). Copied: cover header + one CTA on city task pages.
- Passport / stamp collection: Airbnb "Where Eric has been" https://mobbin.com/screens/5ce58d00-7830-4f59-8cd7-fb584eb2065b (stamp-shaped cards), Mindtrip https://mobbin.com/screens/aacff10d-69bd-410a-b58a-615c832aa7a1. Copied: art cover cards with SF-symbol-on-gradient, chapters rows with cover thumbnail.

### Done
1. NPC chat (`ShopNPCView`, `NPCQuickQuestionBar`, `ShopNPCQuestionReuseButton`): `NPCChatBubble` (avatar, tail corner, own = primary pair), header avatar + "AI guide" chip, quick-reply pills in a horizontal row, pinned composer (mic circle, capsule field, send circle), question reuse now a text link. Fixture `e2-npc-chat` seeds a real exchange through the coordinator (DEBUG).
2. Badge detail (`ObjectBadgeDetailView`): `CYFoilMedal` (angular foil rim, glow, bounce + success haptic, Reduce Motion gated), `CYProgressRing` around it (full when earned, empty track while locked: no per-badge progress exists in the API so none is invented), requirement card, collection ring "n of N" (from the loaded wall; hidden when unknown), pinned `ShareLink` only when unlocked. Wall header shows the ring; wall tiles use the foil medal. Fixtures `e2-badge-detail`, `e2-badge-locked`.
3. Timed challenges: 76pt ring timer, heavy impact on start/signal, `PlayTimedResultCard` (icon + words + number; a pass/fail verdict only when tolerance/goal is known, otherwise neutral), circular reaction target. Journey check: one dark card with skill title, chips, dice, modifier rows, big total result card, one primary pill, success/warning haptic; journey record progress = ring. Fixture `e2-timed-result`.
4. `e2-chapters`: the cause was the view only reading while `scenePhase == .active`, which a fixture host never reports; DEBUG-only `--design-fixture` foreground override added in `RoamEnrolledChaptersView`. Rows are now cover-thumbnail cards.
5. Card language (`CYArtCoverHeader` / `CYCoverHeaderSection`: generated art cover, big title): city rules, arrival evidence, participation, onsite task, neutral task, ordered map, free-exploration bundle launch, passport anniversary and recap.

### Self-score (1-10: delight / interaction / inclusivity / visuals / innovation / social)
- NPC chat 8/8/8/8/7/8. Badge detail 9/8/8/9/9/8. Timed 8/8/8/8/7/8. Journey check 8/8/8/8/8/8. Chapters 8/8/8/8/7/8 (see verification). City cover-header pages 7 on delight (no per-page fixtures, header only; not reworked further: need runtime owners).
### Under 8 / left
City rules, arrival, participation, onsite, neutral, ordered map, bundle launch, passport tools: restyled blind (compile-verified, no screenshot: they need Core runtime owners for a fixture). Game journal composition section is an internal diagnostic block (I02 codes), left unstyled; play-kit forms untouched. New strings are inline via `ChannelCopy.text(zh, en)`; no `ui-strings-e2.json` needed for them.

### Final verification (pass 3)
Final batch: 16 shots, BUILD_EXIT=0, contact sheet `docs/release/design-report-e2-shots/contact-e2-pass3.png` (EN / zh-Hans / accessibility-XL for NPC, badge, stopwatch, results, journey, chapters). Fixed after the sheet: XL chip wrapping on badge and journey check (ViewThatFits), chapters rows drop the thumbnail at accessibility sizes. Those last two edits (chapters row at XL, inline nav title) were not re-shot. `e2-chapters` now uses an immediate-result stub (real rows + cover header; the real list container never left Loading inside the fixture host, scenePhase override did not fix it). NPC XL: the composer sits at the end of the transcript (existing accessibility-size behaviour); not re-shot.

### Coordinator review follow-up (contact-142232)
NPC: larger header (56pt avatar, title3 name, AI guide chip), typing-dots bubble while a reply is pending, larger 48pt quick-reply pills, bubbles on elevated grey / primary pair. Reaction idle: instruction card, round dots, big Start. XL chips stacked, chapters stub renders loaded cards with art. Sheet: `docs/release/design-report-e2-shots/contact-e2-pass3b.png` (9 shots; all rendered in zh-Hans because the simulator locale stuck, EN verified in the previous sheet). Not done: the disclosure text stays one visible line (AI disclosure must remain visible), not a collapsible.
