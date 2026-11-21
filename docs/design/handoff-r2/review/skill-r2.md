# SKILL REVIEW r2 · Skill-led design round 2 of 2 · the final design review before code

Reviewer: Fable 5.2 · 2026-11-16 · **read-only** (no Figma node and no code was changed).
File `0YyoybGnU1KG0657wdGCPX`. Executor for this plan: Opus (section 3). After that the app is built from the file.

**Result: 51 findings. P0 6 · P1 27 · P2 18.**

Overall rating in the `apple-design-review` scale: **Needs work**, for a different reason than in round 1.

Round 1 gave the game its object. The 地契 (deed card), the district colours, one map component, the moment layout, the odds bar, springs and real overlays all exist now, and they are the right ideas. What stands between this file and a build is mostly **finish and truth**:

1. **Round 1 left five visible breakages on main paths.** The 俱乐部 tab root lost its club cards (seven grey covers with no names). 我的地盘 shows a flag glyph where each place name was. The odds bar component has a 10 pt high frame, so on the challenge sheet it sits under the footnote and is cut off. The merchant's 扫码 button is a blank black disc. The 称号 list lost four row titles. (SR2-01, 23, 24, 14, 37)
2. **The deed is a picture of a deed, not a component.** Every instance says "Lv 2 · 插旗" and "地契 · No. 07" and shows the same photo, because level, number, holder, photo and district are not properties. The player claims 老麦咖啡馆 and is told 武康大楼 is theirs. (SR2-25, 42)
3. **The moments have a layout but no motion.** Each strip opens on a black frame, two of the five beats are the same still in three strips, and no element has a from and a to. The die shows 17 before it is thrown and after a roll of 8. (SR2-26, 34, 49)
4. **The map cannot be read.** Road against land is 1.31:1, water 1.02:1, fog against explored ground 1.11:1. `me` and `district/1` are the same blue (1.28:1 apart). (SR2-31, 32)
5. **An engineer cannot tell what is final.** No frame is marked Ready for dev. The R pages still hold 274, 344 and 141 `MP/Nav Bar` instances, P and its R twins have diverged, and the shipped app already differs from both. (SR2-46, 12, 17)

The thesis is now visible: *a city you can own, one street sign at a time*. The signature element is the deed and it should stay the only loud thing. This round makes it real, fixes what round 1 broke, and gives the build exact values.

---

## 0 · Method, the skills used, and the Figma calls used

### Skills, in the order the brief required

| # | Skill | What it drove in this audit | Files opened |
|---|---|---|---|
| 1 | `apple-design` (hub) | The restraint pass ("Remove it — does the design lose meaning, or just decoration?"), "Show the real product. Always", one accent, and the surface axis: lists and sheets are utility (motion near-invisible), moments are the flagship surface (under-staging is the failure). | `references/restraint-and-antislop.md` |
| 2 | `apple-design-review` | Main lens and severity. Five lenses in order (accessibility, conventions, craft, interaction, writing); contrast "computed from hex values"; "Review the flow, not just the screen". Report format adapted to the brief's P0/P1/P2. | `hig/`: `design-principles`, `designing-for-games`, `accessibility`, `typography`, `color`, `layout`, `maps`, `sheets`, `buttons`, `toolbars`, `tab-bars`, `motion`, `playing-haptics`, `gestures`, `undo-and-redo`, `gyro-and-accelerometer`, `loading`, `feedback`, `progress-indicators`, `writing`, `icons`, `toggles`, `widgets`, `notifications`, `live-activities`, `voiceover`, `liquid-glass` |
| 3 | `apple-design-foundations` | Type scale and Dynamic Type (census by script), 8 pt grid, semantic colour and contrast (computed from the variables). | SKILL core rules; `color-systems.md › System semantic colors`; `typography.md` (headings) |
| 4 | `apple-design-os` | Navigation bars and large titles, the tab bar, sheets and detents, empty states; which Figma components are stand-ins for system components. | SKILL core rules; `ios-ipados.md › Navigation Patterns`, `Sheets and Modal Presentation` |
| 5 | `apple-design-interaction` | Push vs sheet vs cover, medium detent, every state, skeletons that mirror content, one primary per view. | SKILL core rules; `navigation-models.md › 2.2 Sheets + Detents`, `2.3 Full-Screen Cover`; `state-and-feedback-logic.md › Principles` |
| 6 | `apple-design-motion` | Springs, interruptible transitions, hero transitions, haptics, Reduce Motion; the SwiftUI values the build needs. | SKILL core rules; `motion-animation.md › 2.2 SwiftUI spring presets`, `2.3 Standard durations`, `2.4 Hero / continuity transitions`; `gestures-interaction.md › Discoverability vs. Hidden Gestures`; `microinteractions-feedback.md › Restraint` |
| 7 | `apple-design-materials` | Glass is chrome only, never stacked; one icon language; symbol rendering modes. | SKILL core rules; `iconography-sf-symbols.md › Rendering Modes`; `materials-liquid-glass.md` (headings) |
| 8 | `apple-design-tactics` | Contrast, colour alone, 44 pt, VoiceOver labels, Reduce Motion, copy voice. | SKILL core rules; `accessibility-inclusive.md` (headings) |

Citations use the form `skill › file › heading`. HIG quotes are Apple's wording from the `apple-design-review` reference pages. Where no page covers a point it is marked **judgment**.

### Figma calls: 31 used of the 35 allowed

| # | Call | What it returned |
|---|---|---|
| 1 | `create_session` | session |
| 2 | `use_figma` (read-only) | **failed**: the return value was over the 48 KB limit; nothing was read |
| 3 | `use_figma` (read-only) | Sections of all 14 in-scope pages; variable collections (Color 92 in 10 modes, Radius, Motion 25, Role Shape, Type 4 modes); text and effect styles; 37 kit components with their variant and property definitions |
| 4–20 | `get_screenshot` ×17, whole sections at 1× | N1: `204:22013` board, `204:24419` territory, `204:27379` claim, `204:34760` challenge, `399:4429` moment strips, `204:7912` local components, `208:2662` Live Activity, `205:8940` protection, `204:34179` rent, `207:2684` attributes, `209:15518` channels. P: `204:9668` tab roots, `396:4368` overlays, `204:9670` play loop, `204:9671` roam. Library: `285:20181` Player kit. Patterns: `402:647` Motion & Haptics board |
| 21 | `use_figma` (read-only) | N1 census: text sizes, instances by component, every Deed Card and Odds Bar instance with its overrides, Map/* definitions, reactions, strip timings and annotations |
| 22 | `use_figma` (read-only) | P census: text, instances, header components by frame, reactions, small hotspots, flows, the anatomy of the 俱乐部 root and the 首页 root |
| 23–31 | `use_figma` (read-only) ×9, one page each, census plus up to five frames rendered at 0.72× | R3, R4, C2, R6, C1, C3, R5, R1, R2 |

Every `use_figma` script only read nodes and rendered them. Nothing was created, renamed or moved. Section images were downloaded and cropped locally (`review/skill-r2-work/`).

### What I saw and what I did not

- **Seen at 0.9× to 1×:** all of N1's board, territory, claim and challenge sections (40 frames), the Player kit, the P tab roots, N46 and N66 (zoomed).
- **Seen at 0.5× to 0.75×:** N1 protection, rent, attributes, Live Activity (first 9 of 13), channels (first 6 of 12); the 42 strip frames at 0.42× (composition only); P overlays, play loop and roam (about 34 frames); 44 frames across R1 to R6 and C1 to C3 (ids in the findings).
- **Measured, not judged by eye:** contrast (WCAG relative luminance from the variable values of the Player-Dark mode), text sizes and styles, component properties, instance overrides, reactions and timings.
- **Local evidence read:** `review/skill-r1.md` in full, `revise/skill-r1/LOG.md` in full, the reference sections of `full-player.md`, `full-member-club.md`, `full-merchant-creator.md`, `full-config.md`, `verify-r1.md` and `iterate/round-1-refs.md`, `CODE-QUEUE.md`, and four app screenshots from `r2-shots/` (首页, 漫游, 俱乐部, merchant workbench).
- **Not seen:** N1's season board section `205:9363`; P sections 1 and 4 to 9 (section 4 is a re-clone of N1); the Club, Merchant and Editor kit sections and Library pages `6:2` and `6:4` beyond the Motion board (inventoried by script, not rendered); the last 4 Live Activity frames and the last 6 channel frames. About 2,700 frames exist on the pages in scope; this review looked at about 210 of them and the Player kit. The Figma Glass effect does not appear in exported images, so SR1-38 (glass) is confirmed by the log and by component properties, not by eye.
- **Round 1's log is accurate.** Every census number I re-measured matched it, except three: N1 has 76 unstyled top-level text nodes (the log says 0), 47% of N1's text is 14 pt or smaller (the round-1 target was under 20%), and the duplicate `r-2xl` radius token no longer exists (only `mp/radius-2xl` does), so that leftover is closed.

---

## 1 · References (12, none cited in any earlier review)

Checked against the reference sections of `full-player.md`, `full-member-club.md`, `full-merchant-creator.md`, `full-config.md`, `verify-r1.md`, `iterate/round-1-refs.md` and `skill-r1.md`, by app name and by Mobbin screen id. ADA text is quoted from `developer.apple.com/design/awards/` (2026), `/2025/` and `/2024/`, fetched today. Two Apple apps appear earlier with other screens: Apple Maps (place card, guide card, Add Stop) and Apple Wallet (named once in prose, no screen). The screens below are different ones. "Lesson" lines marked *my reading* are not Apple's words.

| # | Reference | What Apple or the screen shows | The specific lesson for this file |
|---|---|---|---|
| 1 | **SILT** · ADA 2026 finalist, Visuals and Graphics (game) | "a camera that zooms in as the diver swims through tight tunnels, then zooms out to show the scale of a colossal eel boss monster" | The camera carries the drama. A claim zooms the map into the cell, the result pulls back to show the district filling in. Today every moment starts from a black frame (SR2-34). |
| 2 | **Primary: News in Depth** · ADA 2026 winner, Social Impact (app) | "With a properly minimal UI, Primary wisely gets out of the way of the news, keeping the focus on the story." | Say each fact once. The claim sheet states the price three times and the protection time three times (SR2-29). |
| 3 | **Lumy** · ADA 2025 finalist, Delight and Fun (app) | "elegant widgets and Live Activities, Lumy offers a quick and intuitive way to get celestial information" | A game whose events happen while the phone is in a pocket needs a widget and notifications as designed surfaces, not as an afterthought (SR2-39). |
| 4 | **Denim** · ADA 2025 finalist, Delight and Fun (app) | "a seamless SwiftUI-built experience, with smooth scroll transitions and elegant text and mesh gradients… custom haptics, intelligent cropping, and cool depth effects" | The share card and the deed band can be built natively: a mesh gradient from the district colour, the photo cropped by the system. Specify them in SwiftUI terms (SR2-42, 49). |
| 5 | **Mela** · ADA 2025 finalist, Interaction (app) | "recipe steps, measurements, and timing details are subtly dimmed and highlighted at the proper time" | On the play screen only the current step is bright: the next stop and its distance. Everything else dims (SR2-04). |
| 6 | **Rytmos** · ADA 2024 winner, Interaction (game) | "creating pathways using simple drag gestures… The onboarding makes gameplay instantly clear, and the gestures are simple and fun" | One gesture per verb, taught at first use. The die screen names a shake in its copy and a flick in its prototype (SR2-27). |
| 7 | **Play** · ADA 2025 winner, Innovation (app) | "everything you create in Play — including logic and interactions — matches perfectly with Xcode" | The prototype is only useful to the build if its values are the build's values. Each motion note needs a SwiftUI line beside it (SR2-49). |
| 8 | **puffies.** · ADA 2025 finalist, Inclusivity (game) | "Reduce Motion, a high-contrast mode, and a series of 'outline settings' that add focus to certain parts of the board" | The territory map needs an outline mode for Increase Contrast and Differentiate Without Color: thicker cell borders and a hatch for "mine" (SR2-32). |
| 9 | **Apple Wallet** (Mobbin): [boarding pass](https://mobbin.com/screens/fe3800b2-59af-4229-9412-115dcb51c881), [Apple Card](https://mobbin.com/screens/e5c938d7-50d2-44b5-925f-5450cadc2713), [card added](https://mobbin.com/screens/f6094101-de0a-445d-bb32-19b0f938bdc3) | A pass is one object with a header strip and labelled fields in a grid. The card screen is the object, then tiles, then a ledger. Adding a card ends with the card, a tick and the word Done | The deed's fields are a labelled grid, every field real (SR2-42). 我的地盘 detail is deed, tiles, ledger (SR2-29). A confirmation can be the object and one word (SR2-34). |
| 10 | **Apple Sports** (Mobbin): [match stats](https://mobbin.com/screens/f22c0688-fc14-4d38-af6c-3e7d52a17a8a), [play-by-play](https://mobbin.com/screens/f06290af-809e-48d6-a612-c197092f4edf), [rankings](https://mobbin.com/screens/f5143ac1-f680-441c-9f25-a2451270ff94) | The score stays pinned at the top. Two sides are compared as paired bars in their own colours. Each event row carries a thin team-colour edge | A challenge is two sides: show attacker and holder as a pair (SR2-27). A rent row carries a 3 pt district edge instead of two leading images (SR2-36). |
| 11 | **Apple Maps, iOS 26 sheet** (Mobbin): [Add to Guides](https://mobbin.com/screens/f32a2f05-0606-4fe6-900d-aea49e4a38fa) | Close is a glass circle at the leading edge, confirm is one tinted glass circle at the trailing edge, the title is centred with the place name under it. No second primary at the bottom | The 选择玩法 sheet has a 完成 capsule in the header and a blank capsule at the bottom. One confirm, in the header (SR2-19). |
| 12 | **Maps under floating chrome** (Mobbin): [OpenTable](https://mobbin.com/screens/4cb0d3c1-8fbc-45e0-bcc9-6f03fcdb77c4), [Citi Bike](https://mobbin.com/screens/b56bb6f2-12ae-47e2-aec5-0d13f7ceb227) | OpenTable: list content stays visible through the floating tab bar. Citi Bike: pins carry counts, street names stay on at this zoom, the one action (Scan) sits in the sheet header | The scroll edge fades content, it does not hide it behind a black band (SR2-09). Pins carry a value and streets keep their names (SR2-31). The roam root's one action belongs with the sheet (SR2-03). |

---

## 2 · Findings by area

Each finding: id · severity · rule · nodes · issue · how to optimise · how to implement in Figma. Tokens are the file's own variables and text styles. Contrast figures are computed from the Player-Dark values.

### 2.0 · Round 1, verified

| Round-1 item | Status in the file now | Carried as |
|---|---|---|
| SR1-01 漫游 rows overlap (P0) | **Landed.** Rows read `¥29 · 今晚 19:30 · 800 米` on P `210:8322` and R1 `169:4853` | — |
| SR1-22 地契 (P0) | **Landed, with defects.** Component exists and is used on 14 frames of N1 | SR2-25, 29, 33, 42 |
| SR1-23 CITY home (P0) | **Landed, with defects.** Map module, today strip, deeds are there | SR2-30 |
| SR1-24 one map (P0) | **Partly.** `Map/Base` exists; two older drawings and two legends remain; features are too faint | SR2-31, 44 |
| SR1-25 moments (P0) | **Landed, with defects.** Eight results on `Player/Moment` | SR2-26, 34, 43 |
| SR1-36 kit (P0) | **Partly.** `MP/Button`, `MP/Chip` and `MP/Tag` are gone from N1 (none in the instance census). P keeps 35 `MP/Nav Bar`; N1 uses `Player/Nav Bar` at most twice (it is not among its 45 most-used components); the R pages were not touched | SR2-05, 12, 17 |
| SR1-43 springs (P0) | **Landed.** P 233 spring of 234; N1 51 of 56; C1 93, C3 89, C2 19, R4 23, all spring | — |
| SR1-44 overlays and drag (P0) | **Landed.** 16 overlay actions, 11 drags, 10 closes on P | SR2-50 (scrim) |
| SR1-02 play screen | Partly: cover and distance landed, bottom row not | SR2-04 |
| SR1-03 scroll edge | Landed, too strong | SR2-09 |
| SR1-04 placeholders, stock photos | Partly | SR2-06 |
| SR1-05 走起 | Landed on P; the R1 twin is unchanged | SR2-03 |
| SR1-08 club covers | **Regressed**: the cards were replaced, not their covers | SR2-01 |
| SR1-09 概览 | Landed | SR2-13 |
| SR1-11 merchant first job | Landed; the 扫码 glyph is invisible | SR2-14 |
| SR1-16 blank primary | Not done | SR2-19 |
| SR1-17 text under 11 pt | Landed (what remains is 10 pt glyphs and tab labels) | — |
| SR1-26 pins | Partly: "?" pins keep orange and green rings on N07 | SR2-31 |
| SR1-27 disabled pills | Landed; N50 repeats one label twice | SR2-38 |
| SR1-28 type on N1 | Partly: 47% at 14 pt or smaller | SR2-41 |
| SR1-29 contrast | Landed for the two cases named; new failures measured | SR2-33 |
| SR1-30 odds bar | **Broken** on N34 | SR2-24 |
| SR1-31 blue means five things | Partly: `me` and `district/1` are the same blue | SR2-32 |
| SR1-32 door on tab roots | Landed, with layout defects | SR2-02, 03 |
| SR1-33 one celebration style | Partly: six green ticks and a green check remain | SR2-07, 11 |
| SR1-37, 38, 39, 45, 47 | Landed (37 and 38 by log and properties) | SR2-47 |
| SR1-40 icons | Mostly: 46 `N1/Icon/*` components remain, with 47 instances on N1 per the log | SR2-47 |
| SR1-46 strips and gestures | Landed, thin | SR2-34 |
| Leftovers named in the brief | SR1-16 → SR2-19 · SR1-15 → SR2-16 · 35 `MP/Nav Bar` → SR2-05 · play bottom row → SR2-04 · R6 A46 switch → SR2-08 (found: `185:6705`) · duplicate `r-2xl` → **closed**, it no longer exists | |

### 2.1 · Player (P `204:9667`, R1 `90:3`, R2 `91:656`, R6 `91:34`)

**SR2-01 · P0 · The 俱乐部 tab root lost its clubs**
- Rule: `apple-design › restraint-and-antislop.md` default 2 ("Show the real product. Always"); HIG `design-principles.md › Craft`.
- Nodes: P `210:8452`, frame `club list` (393×1735): seven `Club/Default Cover` instances at 359×224 and nothing else.
- Issue: round 1 was to swap seven covers. It replaced seven cards. The fourth tab of the prototype is now grey rectangles with a cropped 旅 or 兴 and no club name, member count or role. The shipped app (`r2-shots/04-tab-club-TEST-at-limit.png`) shows what belongs here: cover thumbnail, name, members, role tag.
- Optimise: a club row is a thumbnail, a name, one meta line and a role tag. The default cover is the thumbnail, not the card.
- Figma: rebuild each item as an auto-layout card (fill `surface`, r `r-md` 16, padding 12, gap 12, hug): leading `Club/Default Cover` or `Media/Cover` at 72×72 r12; column: name `t-head` 17, meta `t-foot` 13 `ink-2` (`4 名成员 · 旅行组织`), optional `t-foot` line for the next activity; trailing `Player/Status Tag` Neutral (`创建者` or `成员`). Seven names from the app shot or the R1 twin. List gap `sp-3` 12, page margin 16. Add it to the kit as `Club/List Card` so P and R3 share it.

**SR2-02 · P1 · The 我的地盘 rail on 首页 is off the grid and sits on old hotspots**
- Rule: HIG `layout.md`: "Align elements to make them easier to scan"; HIG `typography.md` (minimum 11 pt).
- Nodes: P `210:8239`; hotspots `⌖ → act` ×2 (170×256 at y 504) and `⌖ → create1` (361×68 at y 784).
- Issue: the rail's header starts at x 50 while every other block starts at 16 or 34; 70 pt of empty space sits above it. The two `→ act` hotspots still cover the area where 附近活动 cards were, so tapping a deed opens an activity. `→ create1` lies under the tab bar. Deed Mini text is 7 and 9 pt (SR2-42). All three deeds show the same photo.
- Optimise: the rail is a normal section: header on the page margin, cards on the margin, 24 pt above.
- Figma: header row at x 16 (`t-2` 22 title, trailing `全部` with `Icon/chev`), 12 pt gap, then a horizontal auto-layout of Deed Mini (gap 12, left padding 16). Move the block to 24 pt under 编辑精选. Delete the three stale hotspots; add one hotspot per deed → the N11 copy and `全部` → the N01 copy.

**SR2-03 · P1 · The 漫游 root collides with itself, and its R1 twin was not updated**
- Rule: HIG `maps.md`: "Noninteractive elements that obscure the map can interfere with people's expectations"; `apple-design-os` core rule ("Anchor primary controls in reach"); reference 12.
- Nodes: P `210:8322`, hold state `397:4607`; R1 `169:4853`.
- Issue: (a) the City stat pill has the same shape as the 迷雾 and 领地 chips, so it reads as a third filter. (b) The caption 按住 0.8 秒开始漫游 sits on the map with the street label 湖南路 under it. (c) A glass circle is half hidden under the 走起 button. (d) 迷雾 is selected but the map shows no fog: this root still uses its own map drawing. (e) The first 附近 row is a photo of two people at a café (Q10 of round 1 ruled out people stock photos). (f) R1 `169:4853` still has the small mid-map 走起 pill, so the file holds two answers.
- Optimise: chips at the left, the stat as plain text in the header subtitle, the hold button docked to the sheet, the map from the kit.
- Figma: move `持有 3 / 9 · 今天 +186` into the `Player/Root Header` subtitle (it replaces 已点亮 38 格 · 本周 +6, which moves to the fog legend) and link the subtitle to N01. Swap the map for `Map/Base` Layer=Fog. Dock the hold button inside the sheet header area (12 pt above the grabber is where it is; make the sheet's top edge 76 pt lower so the button and caption sit on `surface`, not on the map). Move the two glass circles to y ≤ 300. Replace the café photo with a `Media/Cover` place photo. Then either re-clone R1 `169:4853` from P or rename it `010 · superseded by P 210:8322`.

**SR2-04 · P1 · The play screen: two distances, three equal buttons, one bright thing too many**
- Rule: HIG `designing-for-games.md`: "Make sure text is always legible"; HIG `buttons.md`: "Use style — not size — to visually distinguish the preferred choice among multiple options"; reference 5.
- Nodes: P `401:4731`, `401:4796`; N1 `209:14900` (N87).
- Issue: carried from SR1-02. The 下一站 card says 步行约 180 m and, one line below, 1.2 km 距离. The heading arrow is a 20 pt ↗, not a control you can follow while walking. 提示, 队伍 and 背包 are still three equal buttons under the primary. The status bar and the top pill sit on a bright photo with no shade. The cover is the 武康大楼 night photo for a chapter called 老洋房的门牌, and it is the same photo as every deed.
- Optimise: one distance, one arrow, one primary; helpers recede.
- Figma: in the 下一站 card keep `老麦咖啡馆` (`t-head`), a 44 pt heading arrow (annotate "rotates to bearing, 15° steps, `.rotationEffect` with the push spring") and `180 m` in `role/stat` 22; one caption line `用时 23:10 · 线索 3 / 6`; delete the 1.2 km tile. Bottom row: `提示` as `Player/Button` Secondary 44 (fills the row), then two 44 pt glass circles, 队伍 with its count badge and 背包, each with an accessibility label. Add a 96 pt top shade (`bg` 60% → 0%) under the status bar. Give each chapter its own `Media/Cover` variant.

**SR2-05 · P1 · Thirty-five frames still use the mini-program header, and N1 never adopted the new one**
- Rule: HIG `design-principles.md › Familiarity`: "apply them consistently throughout your design"; HIG `toolbars.md` (title and navigation controls); `apple-design-os › ios-ipados.md › Navigation Patterns`.
- Nodes: P, 35 `MP/Nav Bar` instances: settings, search, results, wfilter, pdetail, order, playerr, report, rank, history, session, clubwelcome, clubhome, apply1–5, create1–5, tenew, teedit, tecat, tedraft, tetemp, pub1–3, mhome, mrecords, mrecord, mledger. N1: 56 loose `Icon/back` instances, and `Player/Nav Bar` at most twice (it is not among the page's 45 most-used components).
- Issue: the lobby, the roam consent and the map screens have a glass circle for Back. 战报, 排行榜, 漫游记录, N01, N46 and N64 have a bare chevron. Round 1 stopped because "header layout differs": `Player/Nav Bar` has no large-title variant, and that is the header most of these frames use.
- Optimise: one component for pushed pages with both title modes, used everywhere.
- Figma: add to `Player/Nav Bar` `384:1342` a variant property `Title` = None / Inline / Large (Large: Back circle, then a 28 pt `t-1` title on the next line with an optional `t-foot` subtitle, 393×112), and rename the text property to `Title text` (two properties are both called `Title` today). Swap the 35 `MP/Nav Bar` on P and the 56 loose chevrons on N1 by frame. In the description write: "SwiftUI: not a custom view. `NavigationStack` title, `.navigationBarTitleDisplayMode(.large` or `.inline)`, `ToolbarItem`s; the system draws the back button and the glass."

**SR2-06 · P1 · Placeholders and stock photos are still in finished frames, and every deed has the same photo**
- Rule: `apple-design › restraint-and-antislop.md` default 2: "Placeholder rectangles, abstract SVG 'UI diagrams,' and lorem blocks are a failure, not a stand-in."
- Nodes: P `210:8374` (发布 root: an empty dark thumbnail in 全部主题 and an empty card under 两小时内玩完); R2 `204:29927` (票夹: the pass body is a dark box with a small route glyph; the log recorded "no change needed"); R4 `233:12260` (grey bars inside the hero cover; two list thumbnails are people photos); R3 `204:24899` (下一场活动 thumbnail is a crowd photo); P `210:8322` (SR2-03 e). `Media/Cover` `381:993` has `Place 1` to `Place 5`; all 14 deeds on N1 and the three on 首页 use the same one.
- Issue: a collectible that always shows the same building is not collectible, and the roots still sell the product with grey boxes.
- Optimise: every cover is a real place or the designed default; each deed has its own photo.
- Figma: grow `Media/Cover` to at least 9 place photos and name the variants by place (`武康大楼`, `老麦咖啡馆`, `转角花店`, `梧桐书店`, `安福路 12 号`, `愚园路 1088 弄`, …). Source: the claim-camera photo on N20, `seed-images/`, the place photos already used in Theme Cards. Set the photo per deed (SR2-25). Swap the frames above. R2 票夹: the pass body shows the theme cover with the route drawn over it.

**SR2-07 · P2 · 战报, 结算 and 排行榜 leftovers**
- Rule: HIG `writing.md`: "Check each word to be sure it needs to be there"; HIG `design-principles.md › Familiarity`.
- Nodes: P `204:15044`, `204:15096`, the `rank · 完整排行榜` frame in section `204:9670`.
- Issue: 本局不计分 appears as the subtitle and again as a tile. Three rows still end in "→" (SR1-06, SR1-13). 结算 opens with six flat green ticks, the last of the old celebration styles. The podium shows places 2 and 1 and nothing for 3.
- Figma: hide the tile; replace the three arrows with `Icon/chev`; replace the tick row with `Moment/Art` Seal at 96 pt over `6 / 6`; add the third podium seat as an empty outline (`ink-3` dashed ring, `—`).

**SR2-08 · P2 · The share cards: a green switch, a small badge**
- Rule: owner ruling Q3 of verify-r1 (neutral tint); HIG `toggles.md`: "Change the default color of a switch only if necessary" (the owner has ruled it necessary here).
- Nodes: R6 `185:6705` (A46 · 优化), layer `带上路线 (switch row)` › `switch · on` (a local frame, which is why round 1 did not find it); P frame `rshare · 分享卡片 · 漫游` in section `204:9671`; P `210:10082`.
- Figma: replace both local switches with the kit switch in its neutral tint (`ink` track at 32%, white knob). On `210:10082` enlarge the `Badge/Art` to 144 pt and remove the mustard swatch from the four colour options.

**SR2-09 · P2 · On the dark theme the tab bar has no edge, and the scroll edge is a black band**
- Rule: `apple-design-review › hig/liquid-glass.md`: "use a scroll edge effect instead of a solid or semi-opaque background color beneath them"; "Content scrolls and peeks through the functional layer"; reference 12.
- Nodes: `Tab Bar / Player` `12:129`; `Chrome/Scroll Edge` `384:1344` (393×120, `bg` 0% → 100%); P roots `210:8239`, `210:8322`, `210:8374`, `210:8452`, `210:8603`.
- Issue: the capsule's fill is `glass` (#1C1C1E at 72%), which over `bg` is 1.14:1: it has no visible edge. Under it the 120 pt gradient reaches 100% black, so nothing passes under the bar. The result reads as a flat opaque bar, the opposite of round 1's intent. The merchant light theme shows the capsule correctly (R4 `182:7328`), and so does the app (`r2-shots/`).
- Figma: capsule: add a 0.5 pt inside stroke `sep-strong` and a 1 pt top highlight (white 8%). Scroll edge: 393×72, stops `bg` 0% → 80%, ending at the capsule's vertical centre. Description: "SwiftUI: do not draw. `TabView` gives the floating bar; `.scrollEdgeEffectStyle(.soft, for: .bottom)`. Verify both names against the iOS 27 SDK."

**SR2-10 · P2 · Three drawings of the hold button**
- Rule: HIG `design-principles.md › Familiarity`; `apple-design-motion › gestures-interaction.md › Discoverability vs. Hidden Gestures`.
- Nodes: P lobby `204:15032`, `289:2730` (no ring at rest), `289:2804` (green progress around the pill, label 松手取消); roam `210:8322`, `397:4607` (white ring at rest); R6 `301:3116` (four green segments).
- Figma: one component `Player/Hold Button` (361×52): `State` = Rest (2 pt ring track `ink` 24%), Holding (ring trimmed to progress in `ink`, label 松手取消), Done (ring full, label swaps to a check). Text property `Label`. Use it in all three places. SwiftUI mapping in section 2.6.

**SR2-11 · P2 · Sheets have three surface tones; 附近 uses rainbow tiles; one more celebration style**
- Rule: `apple-design` hub ("One accent color"); HIG `color.md`: "Use color consistently throughout your interface".
- Nodes: overlays `396:4369` and `396:4404` (near-black sheet), `396:4449`, `396:4504`, `396:4561`, `396:4610` (grey sheet), `396:4645` and `396:4688` (black sheet); 附近 rows in `396:4645` and P `210:10410` (purple, green and magenta gradient tiles); `396:4688` 俱乐部已创建 (flat green check).
- Figma: every sheet's fill is `surface-2`; rows inside are `surface-3`. 附近 tiles: `surface-3` with a 20 pt `ink` glyph. 俱乐部已创建: `Moment/Art` Seal at 96 pt in place of the green circle.

### 2.2 · Club (R3 `91:33`)

**SR2-12 · P1 · The club pages are still built from mini-program parts**
- Rule: HIG `design-principles.md › Familiarity`; HIG `typography.md` (default 17 pt, minimum 11 pt).
- Numbers: R3 has 345 frames; `MP/Nav Bar` 274 instances, `MP/Button` 30, `MP/Chip` 28. Top-level text: 3,799 nodes, 1,399 with no style; 11 pt ×752, 12 pt ×702, 14 pt ×588, 13 pt ×245 (60% at 14 pt or smaller). No prototype reactions on the page.
- Issue: round 1 moved N1 onto the Player kit and stopped. A club organiser's screens are still 11 and 12 pt with the old header and old buttons, next to a player app at 15 and 17 pt.
- Optimise: run the N1 scripts on the frames that are final.
- Figma: on frames named `优化` only: `MP/Nav Bar` → `Player/Nav Bar` (Large or Inline by the existing title), `MP/Button` → `Player/Button`, `MP/Chip` → `Player/Chip`, then the type map of SR1-28 (`MP/body` 14 → `t-sub` 15, `MP/caption` 11 → `t-foot` 13, `MP/card-title` 16 → `t-head` 17, `MP/page-title` 29 → `t-1` 28). Dry run first; render ten frames after.

**SR2-13 · P2 · 概览 and the workbench: small ones**
- Rule: HIG `design-principles.md › Craft`.
- Nodes: `204:24899`, `170:1744`.
- Issue: on 概览 the meta line breaks after "12 / 20" and leaves 人 alone on a line; the 俱乐部勋章 row is a full pill while its neighbours are 16 pt cards; the 下一场活动 thumbnail is a crowd photo. On the workbench the scan glyph is still in the header beside ⋯ (the log says it was hidden), and the seven project rows have letter tiles.
- Figma: meta → two lines by design (`11月22日 周六 14:00` / `12 / 20 人`); 勋章 row → `surface` card r `r-md` with a trailing chevron; thumbnail → place photo; hide the scan glyph; project tiles → the theme cover at 44×44 r10.

### 2.3 · Merchant (R4 `90:26`, R5 `90:2`)

**SR2-14 · P0 · The merchant's primary action is a blank black disc**
- Rule: HIG `buttons.md`: "Ensure that each button clearly communicates its purpose"; HIG `accessibility.md` (contrast).
- Nodes: R4 `182:7328` (workbench), instance of `Merchant/Quick Action` `384:1486`, variant `Emphasis=Primary` `384:1477`.
- Issue: round 1 made 扫码 the primary quick action and set its glyph to `cta-ink` in a later fix. In the render the disc is solid black with nothing in it. The glyph and the fill resolve to the same colour in this frame's mode. The shipped app shows the glyph correctly.
- Figma: in the main component bind the glyph fill to `cta-ink` and the disc to `cta`, then check the instance on `182:7328` for a local fill override on the glyph and reset it. Verify in Merchant-Light and Merchant-Dark by render: the glyph must be at least 3:1 against the disc.

**SR2-15 · P1 · 营销: four actions with one icon, and text colliding under the tab bar**
- Rule: HIG `icons.md`: "Create a recognizable, highly simplified design"; HIG `layout.md` (safe areas).
- Nodes: R4 `182:8065`.
- Issue: 店铺参谋, 店铺装修, 发主题 and 发活动 all show the same viewfinder glyph (the component default). At the bottom the 优惠券 card runs under the tab bar and its line `领取 5 · 核销 5` overlaps another label.
- Figma: icons `Icon/chart`, `Icon/store`, `Icon/route`, `Icon/cal`. Extend the frame to its full content height, mark the tab bar and `Chrome/Scroll Edge` as fixed, and give the scroll content a 96 pt bottom inset.

**SR2-16 · P2 · Three header styles across the merchant roots (carried from SR1-15)**
- Rule: HIG `design-principles.md › Familiarity`.
- Nodes: `182:7328` (store name as the title, avatar at the right), `182:8065` (large title 营销), `233:12260` (centred inline title 模板 with a text button 发布).
- Figma: build `Merchant/Root Header` on the anatomy of `Player/Root Header` `287:508`: large leading title 28, optional one-line subtitle, up to two trailing glass circles. Workbench: title = store name, subtitle = `营业中` tag. 模板: title 模板, trailing ⊕ circle for 发布. Use it on the five roots.

**SR2-17 · P1 · The merchant pages are at mini-program scale**
- Rule: HIG `typography.md`; `apple-design › restraint-and-antislop.md` default 2.
- Numbers: R4 has 463 frames; `MP/Nav Bar` 344, `R4/Image Placeholder` 119, `R4/Merchant Tab Bar` 4 (the retired bar). Top-level text 5,148 nodes: 14 pt ×1,571, 12 pt ×905, 11 pt ×819, 13 pt ×294 (70% at 14 pt or smaller); 1,860 unstyled.
- Issue: as SR2-12, with 119 grey image placeholders on top.
- Figma: the same script on `优化` frames with `Merchant/Nav Bar`, `Merchant/Button`, `Merchant/Chip`; row titles 14 → 16 (`t-callout`), captions 11 and 12 → 13 (`t-foot`); swap the 4 retired tab bars; replace `R4/Image Placeholder` on `优化` frames with `Media/Cover`.

**SR2-18 · P1 · R5 (first review): cooperation cards with holes, arrows, and a status dressed as a button**
- Rule: HIG `layout.md`: "Group related items"; HIG `feedback.md`: "Show people when a command can't be carried out and help them understand why"; `apple-design-interaction` core rule (disabled with a reason).
- Nodes: `186:5944` (协作邀请), `186:6119` (协作详情), `186:6257` (分润明细). R5 has 22 `优化` frames of 146; `MP/Nav Bar` 114, `MP/Button` 46.
- Issue: on the invite list the cards have 40 to 60 pt empty bands where hidden rows keep their space, every thumbnail is the same route art, and titles are cut ("思南公馆声景推理 · 民国…"). 协作详情 ends rows with "→" and sets labels at 11 pt. 分润明细 shows a grey full-width pill, 提现由平台客服处理 ›, which looks like a disabled primary.
- Figma: cards → auto-layout hug, hidden rows removed, title on two lines (`t-head`), one meta line, the action bottom-right; thumbnails → theme covers. Arrows → `Icon/chev`; labels → `t-foot` 13. The pill → a plain row in a grouped list (`提现` / `由平台客服处理` + chevron).

### 2.4 · Editor (C1 `237:14642`, C2 `235:178`, C3 `235:13237`)

**SR2-19 · P1 · 选择玩法 still has a blank capsule and two confirms (carried from SR1-16)**
- Rule: HIG `buttons.md`: "Ensure that each button clearly communicates its purpose"; HIG `sheets.md` (Done paired with Cancel); reference 11.
- Nodes: C2 `237:71933` (A3) and the 26 other frames of section `237:71932`.
- Issue: the sheet has a round ✕ and a black 完成 capsule in the header, and a bottom bar with 选一个玩法 and a black capsule with no label. Round 1 could not match it because it sits inside an `Editor/Bottom Bar` instance.
- Optimise: picking a card is the choice. One confirm, in the header.
- Figma: hide the bottom bar on the whole section. Header: ✕ at the leading edge, title, and a trailing 完成 that is disabled until a card is selected (add the Disabled look to the header button). If the owner prefers a bottom confirm, set the bottom bar's primary label to 用这个玩法 and remove 完成 from the header.

**SR2-20 · P2 · The template plaza mixes emoji-style colour icons into a monochrome app**
- Rule: HIG `icons.md`: "Maintain visual consistency across all interface icons in your app"; `apple-design-materials › iconography-sf-symbols.md › Rendering Modes` (pick one mode deliberately); `apple-design` hub (one accent).
- Nodes: C3 `243:1964`, `243:3249`; P `210:8374`.
- Issue: the 主题 and 玩法 tabs use a colour 3D map and die, the section heading 一小时内 carries a 3D clock, a bell floats alone at the top centre, and the toast on `243:3249` is white on a dark page (the Editor toast in a Player frame).
- Figma: tabs → `Player/Chip` Choice with `Icon/map` and the Library die glyph in `ink`; drop the clock from the heading; move the bell into the trailing slot of `Player/Root Header`; toast → `Player/Toast`.

**SR2-21 · P2 · Editor text is not on styles**
- Rule: `apple-design-foundations` core rule (Dynamic Type must reflow: it cannot if text has no style); HIG `typography.md`.
- Numbers: unstyled top-level text: C2 3,784 of 4,726 (80%), C3 1,841 of 2,751, C1 1,131 of 2,385. 12 pt is the most common size on C1 (×750) and C2 (×1,549).
- Figma: one script per page: bind each loose text node to the nearest `t-*` or `role/*` style; field labels and helper text at 12 → `t-foot` 13. Render five frames per page to check row heights.

**SR2-22 · P2 · Two button shapes in the light theme (Q4 is still open)**
- Rule: HIG `design-principles.md › Familiarity`.
- Nodes: variable `button-radius` in `Role Shape` (Player 999 / Merchant 12 / Editor 999); R4 `182:7693` against C3 `237:59431`.
- Figma: set Merchant to 999 (one value). Render `182:7693`, `182:7628` and `182:8065` to check. This is owner question Q4.

### 2.5 · City Monopoly and the new features (N1 `204:7911`)

N1 has not been built in code. Everything here is cheaper to fix now than after the first Swift file. The structure of round 1 (deed, board home, moment layout, odds bar, strips) stays. The findings are about breakages, truth of the sample data, legibility, and the motion the build will need.

**SR2-23 · P0 · 我的地盘 shows a flag glyph where each place name was**
- Rule: HIG `design-principles.md › Craft`; `apple-design-review › Working rules` ("Review the flow, not just the screen").
- Nodes: N46 `205:8376`, N50 `205:8786`: six `City/Deed Card` Row instances whose 名称 property is the SF glyph 􀋉. Bases under the sheets on N47, N48, N49 and N51 (section `205:8940`) still show the old list.
- Issue: the three cards read "⚑ · 武康路 Lv 2 · +12 每次到访". The names (武康大楼, 老麦咖啡馆, 安福路话剧中心) are gone, all three say Lv 2, and the figure a holder wants here, today's rent (今天 +58), was replaced by the per-visit rate. The sheets N47 to N49 and N51 open over the old list, so the flow shows two different pages as one.
- Optimise: name first, today's income at the right, one status line.
- Figma: set 名称 on the six instances (武康大楼 · 据点 Lv2; 老麦咖啡馆 · 前哨 Lv1; 安福路话剧中心 · 插旗 Lv0, weathered) and the matching 等级. Trailing value: `今天 +58` in `role/stat`, caption `每次到访 +12` (needs the `Trailing` property of SR2-42). Re-clone N46 as the base of N47, N48, N49 and N51.

**SR2-24 · P0 · The odds bar component is 10 pt high, so it overlaps and is cut off**
- Rule: HIG `designing-for-games.md`: "Teach through play"; HIG `design-principles.md › Craft`.
- Nodes: `City/Odds Bar` `382:1120`: frame 329×10, vertical auto-layout with **both axes fixed**, children 100 + 12 + 18 + 26 pt high. N34 `204:34263`: the instance is 361×10 at y 714, under the footnote; only the row of 20 segments shows, cut by the sheet edge. P overlay `396:4610` has the same cut (N34's P copy `394:6411` is a re-clone and was not rendered). In the kit section the component is white text on the light canvas and cannot be seen.
- Issue: the rule that decides a challenge, which round 1 turned into a bar, is not readable on the screen where the player decides. The table above it still says 难度（已侦察）12 and 你的修正 +1 起, the prose the bar was meant to replace.
- Figma: on the component set the primary axis to hug (height becomes about 168) and put a `surface` backing behind it in the kit. On N34: place the instance between the tag row and the table, delete the rows 难度 and 你的修正, keep 挑战费 and 今天还可挑战. Make the sheet hug. Repeat on `396:4610`.

**SR2-25 · P0 · Deeds show component defaults, and the story changes place mid-flow**
- Rule: `apple-design › restraint-and-antislop.md` ("Show the real product"); HIG `writing.md`: "Build language patterns. Consistency builds familiarity"; reference 9.
- Nodes and facts (from the instance census): all 14 deed instances on N1 have 等级 = `Lv 2 · 插旗`, including Claimable and Unlit; every Full deed reads `地契 · No. 07`; every deed photo is the same `Media/Cover`. N09 `204:23542`: the deed says 林小舟 持有, the row under it says 阿兰 · 据点 Lv2. N10 `204:23691`: deed 林小舟 · Lv 2 · 插旗, row 小李 · 前哨 Lv1. N11 `204:23832`: deed Lv 2 · 插旗, the table offers 升到 据点 Lv2. N22 `204:26968` and N38 `204:34407`: 你持有 · 第 3 天 seconds after taking the place. The claim sheets N18 to N26 are for 老麦咖啡馆; the result N22 says 武康大楼现在是你的. The challenge sheets N34, N42, N43, N45 are for 转角花店; N38 says 武康大楼归你了. N01 `204:21814`: 武康大楼 is 风化 · 9 天未到 in 需要你处理 and healthy two rows below, where 安福路 12 号 carries the same tag.
- Issue: the owner cannot approve a flow that changes its subject, and an engineer will copy these strings into fixtures. The level names also disagree: the deed pairs Lv 2 with 插旗, the moments say 前哨 Lv1 → 插旗 Lv0.
- Optimise: one cast, used everywhere. Proposed: **老麦咖啡馆** (可圈 → claimed in the claim flow; 武康路街区; No. 12; 插旗 Lv0 after the claim), **转角花店** (held by 小李, 前哨 Lv1, weathered; the challenge target), **梧桐书店** (held by 阿兰, 据点 Lv2, protected), **武康大楼** (mine, 据点 Lv2, day 3), **安福路 12 号** (mine, weathered). Level ladder written once on the board: 插旗 Lv0 → 前哨 Lv1 → 据点 Lv2.
- Figma: after SR2-42 adds the properties, set name, district, number, level, holder, days and photo on every deed instance (N01, N08 to N12, N22, N36 to N41, N46, N50, the six strips, P copies, 首页 rail). N22: 老麦咖啡馆, `你持有 · 第 1 天`, 插旗 Lv0, the photo taken on N20. N38: 转角花店, `前哨 Lv1 → 插旗 Lv0`. Delete the holder rows under the deed on N09 and N10 (the deed carries the holder). Fix N01's two lists so one place has one state.

**SR2-26 · P1 · The die shows the result before the throw and the wrong number after it**
- Rule: HIG `design-principles.md › Delight` ("Know the feeling you want to evoke"); HIG `feedback.md` (status must be true).
- Nodes: `Moment/Art` `382:1118` (kinds Die and Die · Lost: the numeral 17 is fixed text); N36 `204:34340`, N37 `204:34369`, N38 `204:34407`, N39 `204:34440`; strips roll-win and roll-lose in `399:4429`.
- Issue: the die reads 17 while waiting and while rolling. On N39 the text says 掷出 5 + 3 = 8 and the die says 17. On N38 the die shows the total, not the face (14).
- Figma: add a text property `Face` to the two die kinds. N36: `20` (a d20 at rest shows its top face). N37: no numeral, three motion streaks. N38: `14`, with `+2` and `+1` chips beside the 48 pt total `17`. N39: `5`.

**SR2-27 · P1 · 准备掷骰 repeats itself and names two gestures**
- Rule: HIG `undo-and-redo.md`: "Avoid redefining standard gestures… shake their iPhone"; HIG `gestures.md`: "Make custom gestures easy to learn"; HIG `gyro-and-accelerometer.md` (motion data needs a purpose string); references 6, 10.
- Nodes: N36 `204:34340`; `Moment/Stage` Ready in `382:1362`.
- Issue: the chips 任务 +2 and 洞察 +1 appear under the odds bar and again under the line. The line says 甩一下手机掷骰. The prototype, by the owner's Q6, throws with a flick on the die. A shake is the system's undo gesture, needs motion access, and cannot be done discreetly on a street.
- Optimise: flick the die or tap 掷骰. Show the two sides once.
- Figma: line → `把骰子甩出去，或点「掷骰」。`; remove the Moment chips on N36 (the odds bar keeps them); under the odds bar add one caption `你 14 级洞察 · 对手 前哨 Lv1` so the two sides are named. Add a 20 pt drag hint (a short arc with an arrowhead, `ink-3`) beside the die, shown on first use only (annotate).

**SR2-28 · P2 · 掷骰中 shows a spinning primary button under the die**
- Rule: HIG `progress-indicators.md` (one indicator per task); `apple-design` restraint pass.
- Nodes: N37 `204:34369`.
- Figma: remove the button. The die is the indicator. Keep the chip `需要 ≥ 9`. Annotate the VoiceOver announcement `正在掷骰` and, on the result, the headline and line.

**SR2-29 · P1 · The property sheets grew to full height and say each fact three times**
- Rule: HIG `sheets.md`: "consider supporting the medium detent to allow progressive disclosure of the sheet's content"; HIG `maps.md` (keep the map usable); HIG `writing.md`: "If you can use fewer words, do so"; reference 2.
- Nodes: N08 `204:23400`, N09 `204:23542`, N10 `204:23691` (871 pt high per the log), N11 `204:23832`, N12 `204:23956`; overlays `396:…` for the N08 and N11 copies.
- Issue: Deed Full is 329×420. With a banner, a table and a button the sheet covers 80 to 100% of the screen, so the pin the player tapped is no longer visible. On N08 the price 120 appears in the deed tag, the table and the button; `28 m` appears in the banner only, good. On N09 the protection appears as a tag, a banner and a table row with two different readings (11:42 后结束 and 今天 21:30). The lower 90 pt of the Full deed is empty.
- Optimise: medium detent with a compact deed; the full deed on expand.
- Figma: add `Size=Sheet` to the deed (329×176: band 32, photo 329×88, then one row with name `t-2` and the level pips, one row with the rent). Sheets N08 to N12: Deed Sheet, at most one banner, a table of at most two rows, the primary; target height 420 (annotate `.presentationDetents([.height(420), .large])` and, because the map stays live, `.presentationBackgroundInteraction(.enabled(upThrough: .height(420)))`). At the large detent show Deed Full and the full table. Remove the price from the deed tag on N08 and the protection tag from the deed on N09. One time format: `保护到 今天 21:30`.

**SR2-30 · P1 · The CITY home: a misplaced heading, red for warnings, two primaries on the empty board**
- Rule: HIG `layout.md` (grouping and alignment); HIG `color.md`: "Avoid using the same color to mean different things"; HIG `buttons.md` (one prominent button for the most likely action); `apple-design-interaction › state-and-feedback-logic.md`: "Skeleton shapes mirror real content."
- Nodes: N01 `204:21814`, N02 (加载中) and N03 `204:21889` in section `204:22013`.
- Issue: (a) the heading 我的地盘 sits above the stat strip; the three deeds below 需要你处理 have no heading. (b) The two 需要你处理 tags are red. Weathering and a shield about to end are warnings, and red is the error colour elsewhere. (c) A pin overlaps the stat pill inside the map module, and a street label is cut by another pin. (d) N02's skeleton has the old block order. (e) N03 shows the new board, the primary 去圈第一块地, and then the old empty state again with a second white primary 打开领地地图.
- Figma: N01 order: map module → stat strip (no heading) → `需要你处理` → `我的地盘 · 3` (heading above the deeds) → 街区 → 更多. Tags → `Player/Status Tag` with the new Warning (amber) of SR2-45. Map module: keep pins out of the top 56 pt; move the stat pill to the bottom-left of the module. N02: blocks 220 / 60 / 2×52 / 3×72. N03: delete the lower empty state and its two buttons; keep one line of `t-sub` under the primary (`走到真实地点，拍一张照片，通过定位校验，就能圈下它。`) and 看看玩法规则 as a text link.

**SR2-31 · P1 · The map's features are below what an eye can separate**
- Rule: HIG `maps.md`: "Use distinctive styling to differentiate the features of your map" (via SR1-24) and "Clearly identify elements that people select"; HIG `accessibility.md`: "Convey information with more than color alone"; reference 12.
- Nodes: `Map/Base` `387:2721` (on the N1 page); N07 `204:23260`, N13 to N17 in section `204:24419`; `Map/Pin` `204:21680`; `Map/Legend` `387:2926`.
- Numbers (Player-Dark): `map-road` on `map-land` 1.31:1, `map-water` 1.02:1, `map-park` 1.07:1; fog (`bg` 62% over land) against explored land 1.11:1.
- Issue: water and parks cannot be told from land, and fog cannot be told from explored ground, which is the whole point of the fog layer. Territory cells are rounded rectangles laid over the street grid, and they cover the labels (安福路 sits inside a cell; a lone 路 shows beside the 领地 chip). N07 has two legends, the `Map/Legend` strip and a second row inside the district card. The "?" pins still have orange and green rings. The chat button overlaps the legend.
- Optimise: four tones you can separate, labels on top, one legend, unlit in one grey.
- Figma: variables: `map-road` → #3A3F46 (1.69:1), new `map-road-major` #454B53 (2.04:1) for the two wide roads, `map-water` → #12304A (1.32:1), `map-park` → #1B3324 (1.32:1). Fog: `bg` at 80% plus a 1 pt `sep` edge line along the fog boundary, so the boundary reads even where tones are close. Layer order in `Map/Base`: land, water, parks, roads, **cells**, **labels**, pins. Labels `t-cap2` 11 Medium in #8E8E93 (5.5:1 on land). Remove the legend row from the district card on N07. Unlit pins → `Map/Pin` Owner=Unlit (hollow dot, `ink-3`); delete the ringed "?" pins. Move the chat button above the legend with 12 pt clearance. Note on the component: "Stand-in for MapKit; see SwiftUI mapping in 2.6."

**SR2-32 · P1 · Colour roles collide: `me` is a district colour, and districts share hues with status**
- Rule: HIG `color.md`: "Avoid using the same color to mean different things"; HIG `accessibility.md` (colour alone; blue-orange and red-green pairs); reference 8.
- Numbers: `me` #5A9BFF against `district/1` #4F86EA is 1.28:1 (the same blue). `route` #FF6A2A against `district/3` #F0954A 1.24:1, `warn` against `district/3` 1.26:1, `ok` against `district/2` 1.29:1, `bad` against `district/4` 1.04:1.
- Nodes: N07 `204:23260` (my pin is blue, 武康路 cells are blue); P `run`, `move`, `done` frames in section `204:9671` (the walked route is drawn in blue although the `route` token is orange); Live Activity N74, N76 (teal), N79 (amber), N80 (blue bar).
- Issue: on the map a blue shape is either mine or in 武康路街区. The walked route uses the "me" blue in the app frames and three other colours in the Live Activity.
- Optimise: three jobs, three channels. **Mine = white** (the same white as the primary button: "you"). **District = hue.** **Status = a badge shape, never a hue on the map or the deed band.**
- Figma: `me` → alias of `cta` (#F5F5F7). `Map/Pin` Owner=Mine: white disc, `ink-inv` flag. Other: outline in `ink`, flag in `ink`. My cells: district outline 1.5 pt plus a 2 pt white inner line; other cells: district outline only. The 我 avatar on the deed: white disc, `ink-inv` glyph. Route line → `route` on every map and in the Live Activity (one accent, SR2-40). For Increase Contrast and Differentiate Without Color add a variant property `Contrast=Increased` to `Map/Base` Territory: outlines 2.5 pt and a 45° hatch on my cells.

**SR2-33 · P1 · The deed band labels and the grey captions fail contrast**
- Rule: HIG `accessibility.md`: text up to 17 pt needs 4.5:1; `apple-design-review › Working rules` ("Numbers, not adjectives").
- Numbers: white (`on-solid`) on the six bands: district/1 3.54, /2 2.60, /3 2.31, /4 3.16, /5 3.42, /6 3.05 (labels are 12 pt Semibold, so 4.5:1 applies). `ink-3` #7C7C80 captions: 4.43:1 on `surface`, 4.09:1 on `surface-2`, 3.45:1 on `surface-3` (5.05:1 on `bg`). The red status tag passes (4.51 to 4.92:1); amber passes (6.65:1).
- Nodes: `City/Deed Card` `381:1401` (band texts 武康路街区 and 地契 · No.); every 13 pt `ink-3` caption on a card or sheet (N1 has 336 text nodes at 13 pt).
- Figma: band labels → `ink-inv` #0A0A0A (5.59 to 8.58:1 on the six bands). `ink-3` → #8E8E93 in the dark modes (5.64 on `surface`, 5.22 on `surface-2`, 4.39 on `surface-3`), and use `ink-2` for any caption on `surface-3`. Re-run the contrast script on N08 and N22 after the change.

**SR2-34 · P1 · The moments open on black, and half the beats do not move**
- Rule: HIG `motion.md`: "Strive for realistic feedback motion that follows people's gestures and expectations"; `apple-design-motion › motion-animation.md › 2.4 Hero / continuity transitions`; `apple-design` surface axis (the moment is the flagship surface); references 1, 9.
- Nodes: `Moments · 分镜` `399:4429`: 6 strips × (5 beats + Reduce Motion + XXL). Timeouts 0.15, 0.45, 0.35, 0.35 s. `Moment/Stage` `382:1362` kinds Rent and Level. N22 `204:26968` carries two motion notes.
- Issue: (a) beat 1 of every strip is an empty black frame: the moment is cut off from the sheet and the map it came from. (b) In 被抢, 收租入账 and 升级, beats 2 and 3 are the same still; in 圈下了 the deed is complete from beat 2 and only the seal and the text appear. Nothing has a start position, so Smart Animate can only fade. (c) Rent and Level put a 160 pt medal in a 440 pt stage: 60% of the stage is black. (d) N22 still has the PL-44 note (flag drops from 40 pt above, the cell fills outward in 500 ms, the 积分 pill ticks down) beside the SR1-25 note (deed and seal). Those are two different animations.
- Optimise: each moment starts from the thing the player just touched and ends on the deed.
- Figma, per strip (values in SR2-49):
  - **圈下了**: beat 1 = N21 with the claim photo thumbnail highlighted; beat 2 = the photo grown to the deed's photo slot (same layer name in both frames so Smart Animate moves it), sheet gone, map dimmed behind; beat 3 = band and text rows in; beat 4 = seal at scale 1.6, −24°, 0% → beat 5 seal at 1.0, −8°, 100%, headline and chips in. Delete the PL-44 note from N22.
  - **掷骰**: beat 1 = N36; beat 2 = die enlarged and blurred mid-air; beat 3 = die landed with face 14; beat 4 = `+2` `+1` chips slide into the total, total 17; beat 5 = the deed rises under it (win) or the die turns grey and sinks 24 pt (lose).
  - **被抢**: beat 1 = the deed upright with 你持有; beat 2 = it tips to −6° and the holder row changes to 林小舟; then text.
  - **收租入账**: Stage Rent = three Deed Mini fanned (−8°, 0°, +8°) with the coin above; beats count `+0` → `+96` → `+150` → `+186`.
  - **升级**: Stage Level = the attribute glyph over a level bar that fills from Lv 3 to Lv 4, then the medal.
  - Add the same camera idea as a note on N07: on a successful claim the map zooms to the cell while the sheet leaves.

**SR2-35 · P1 · The XXL and Reduce Motion proofs do not prove enough**
- Rule: HIG `accessibility.md`: "Support larger text sizes… at least 200 percent"; `apple-design-foundations` core rule ("Dynamic Type must reflow. Layouts grow/wrap; never truncate"); HIG `motion.md`: "Make motion optional".
- Nodes: the six `· XXL` frames in `399:4429` (393×1000); `N08·XXL` in section `204:24419` (still the pre-deed sheet: title, tags, table); `Type` collection modes Large, xLarge, xxLarge, xxxLarge.
- Issue: the XXL frames are 1,000 pt tall. No iPhone grows; the content must scroll or the stage must shrink. In them the deed keeps its fixed height and clips its last row (你持有 · 第 3 天 is cut). There is no XXL proof of the deed sheet, and the Type collection stops at xxxLarge with no accessibility sizes (AX1 to AX5), where the real failures happen.
- Figma: make the XXL frames 393×852 with vertical scrolling; in `Player/Moment` add `Layout=Compact` (stage 240 pt, deed as Row) for xxxLarge and above. Deed: text rows hug; the card grows. Rebuild `N08·XXL` on the Deed Sheet size. Add one mode `AX3` to `Type` (body 40 pt per Apple's table) and one proof each for N08, N22 and N34: rent line wraps under the name, chips stack, buttons go two lines.

**SR2-36 · P1 · 收租明细 rows have two leading images and three-line meta**
- Rule: HIG `layout.md` (alignment, scanning); reference 10.
- Nodes: N28 `204:33843`; N33 (通知未开) in section `204:34179` keeps the older, cleaner row.
- Issue: each row now has the deed thumbnail and the old icon tile side by side, which leaves a 150 pt text column where `访客 阿* · 18:20 · 据点 ×1.8 · 多数 ×1.2 · 黄金时段 ×1.2` wraps to three lines.
- Figma: one leading image (Deed Mini cropped to 44×44, or the district as a 3 pt edge on the row); title `t-head`; one meta line `阿* · 18:20`; trailing `+31` in `role/stat` over the 待入账 tag. The multipliers live in the detail sheet N29, where they already are. Apply to N28 and N33.

**SR2-37 · P1 · 称号 lost four row titles**
- Rule: HIG `design-principles.md › Craft`.
- Nodes: N66 称号与原型 in section `207:2684`.
- Issue: under 主题结局称号 the single row shows only a centred 佩戴. Under 属性称号 three of the six rows show only 佩戴; their names and conditions are gone (a 1 pt mark remains at the left where the text was).
- Figma: restore the title and caption of the four rows from the text still present in the layers (or from `final-pass/n1-new-features.json`); set the text column to fill; make 佩戴 a trailing `Player/Button` Secondary at hug width, not a centred label.

**SR2-38 · P2 · Small ones on N1**
- N50 `205:8786`: the primary and the text link are both 带我过去. Link → `改天再升`. Rule: HIG `writing.md` ("Be clear").
- Loading: N19 and N42 show a dark pill `正在获取报价` with no spinner; N21 and N37 show a white pill with a spinner and no label. Use the new Loading (spinner and label) of SR2-45 on all four. Rule: HIG `progress-indicators.md`.
- Section `204:27379` and `207:2684` keep three labels with no frame (`N22·a`, `N22·b`, `N68·a`) after the frames were archived. Delete the labels.
- N12 `204:23956` (未点亮) shows the district band and a deed number for a place whose owner and district are meant to be hidden. Use a neutral band (`surface-3`) and no number.

**SR2-39 · P1 · The game's off-screen moments have no design**
- Rule: HIG `notifications.md`: "Provide concise, informative notifications"; HIG `widgets.md`: "Aim to create a widget that gives people quick access to the content they want"; HIG `live-activities.md` (track an event at a glance); reference 3.
- Nodes: section `208:2662` has Live Activities for roam and play only. N40 `204:34476` is titled 被抢（守方，打开 App 时）.
- Issue: rent arriving, a challenge on my place, a shield about to end and weathering all happen while the app is closed. The only design for them is the screen shown after the player opens the app. Round 1's Q9 deferred widgets until the deed existed. It exists.
- Figma: new section `N1 · 系统触点` with: three notification layouts on the lock screen stand-in (`武康大楼被拿走了` · `林小舟 掷出 17。补偿 40 积分已到账。`; `老麦咖啡馆的保护还剩 1 小时` with actions `开护盾 · 60 积分` and `稍后`; `今天收租 +186` as one daily summary, as N33 promises); a small widget (today's rent in `role/stat`, `持有 3 / 9`); a medium widget (three Deed Mini with a status dot each); a lock-screen rectangular widget (`保护到 21:30 · 老麦咖啡馆`). Mark each "tap → N11 of that place". Scope is owner question Q6.

**SR2-40 · P2 · The Live Activity still uses three accents**
- Rule: HIG `color.md` (one meaning per colour); carried from SR1-34.
- Nodes: N74 (teal progress), N76 (teal time), N79 (amber time), N80 (blue progress) in `208:2662`.
- Figma: every progress bar, ring and keyline in the section → `route`.

**SR2-41 · P2 · N1 type: still 47% at 14 pt or smaller**
- Rule: HIG `typography.md`; HIG `designing-for-games.md`: "Make sure text is always legible".
- Numbers: 1,183 top-level text nodes: 13 pt ×336, 11 pt ×113, 12 pt ×91, 14 pt ×11, 9 pt ×2 (553, 47%); 76 unstyled. Glyphs in `Map/Legend` are 6 to 9 pt; the coin is the character 积 at 7 to 9 pt.
- Figma: captions that carry a number a player acts on (rent per visit, protection time, distance, cost) → `t-sub` 15; keep `t-foot` 13 for true secondary lines. Coin → the Library coin glyph at 16 pt (and merge `N1/Icon/coin`, SR2-47). Legend glyphs → 12 pt in a 24 pt row. Bind the 76 loose nodes.

### 2.6 · Library and kit (`6:2`, `6:3`, `6:4`, Player/*, Club/*, Merchant/*, Editor/*, City/*, Map/*, Moment/*)

**SR2-42 · P0 · `City/Deed Card` cannot express a real deed**
- Rule: HIG `design-principles.md › Craft`; `apple-design-review › Lens 3` ("One signature element"); reference 9.
- Nodes: `381:1401`: 21 variants (`Size` Full / Row / Mini × `State` Mine / Other / Protected / Challengeable / Claimable / Weathered / Unlit); text properties 名称, 街区, 等级, 租金 only; 122 text nodes, 16 with no style, sizes 7, 9, 12, 13, 17, 20, 22.
- Issue: the band colour, which is the game's colour-group idea, is a hand override per instance. The deed number, holder, holder avatar, status line, days held and photo are not properties. The level pips are drawn, not driven by the level. Mini sets its band label and rent at 9 pt and its coin at 7 pt. This is why SR2-25 happened, and it is the first component the build will write.
- Figma:
  - Variant property `District` = 1 … 6 (band, dot and outline bound to `district/n`), or put the six colours in a variable collection `District` with six modes and set the mode on the instance. The second is one component set instead of 126 variants; prefer it.
  - Text properties: `名称`, `街区`, `编号` (No.), `等级名` (插旗 / 前哨 / 据点), `租金`, `持有人`, `状态` (the status tag's label), `持有天数`. Boolean `Show status`. Instance swap `Photo` (a `Media/Cover`), `Avatar`.
  - Variant property `Level` = 0 / 1 / 2 driving the pips. Today three pips are drawn for a ladder whose top is Lv 2, so the third never fills. Use two pips (Lv 0 = ○○, Lv 1 = ●○, Lv 2 = ●●) with the level name beside them, or confirm that a Lv 3 exists.
  - `Size` = Full (329×hug, min 380) / **Sheet** (329×176, SR2-29) / Row (361×72) / Mini (104×132). Mini: band label 11 pt Semibold, name `t-foot` 13 Semibold, rent 12 pt; coin glyph 12 pt.
  - Row gets a `Trailing` variant: Rent / Today / Status / Price.
  - Band labels `ink-inv` (SR2-33). Bind the 16 loose text nodes. Remove the empty 90 pt in Full (hug).
  - Description: the SwiftUI mapping below.

**SR2-43 · P1 · `Player/Moment` has one variant and no slot; the art has fixed text**
- Rule: `apple-design-os` core rule (documented hierarchy, every state); HIG `design-principles.md › Familiarity`.
- Nodes: `Player/Moment` `382:1364` (1 variant; properties Headline, Line, Chip 1–3, Show chip 2, Show chip 3); `Moment/Stage` `382:1362` (9 kinds, absolute layout, no text); `Moment/Art` `382:1118` (7 kinds; 4 text nodes with no style: 17, 17, 积, 已圈下).
- Issue: the stage cannot be swapped through a property, the two button labels are not properties, the chips are local pills and not `Player/Stat Tile` as round 1 specified, and there is no variant for the Reduce Motion result or the large-text layout.
- Figma: instance swap `Stage` (preferred values = the 9 `Moment/Stage` kinds); text properties `Primary` and `Secondary`; boolean `Show secondary`; chips = a `Player/Chip` Kind=Info variant (new, non-interactive, 32 high). Variant `Layout` = Regular / Compact (SR2-35). `Moment/Art`: text property `Face` on the two dice, `Label` on Seal; the coin's 积 becomes a drawn mark. Rebuild Stage Rent and Level (SR2-34).

**SR2-44 · P1 · Four map drawings in the file, and the map kit lives on a feature page**
- Rule: HIG `design-principles.md › Familiarity`; SR1-24 carried.
- Nodes: `Map/Base` `387:2721`, `Map/Pin` `204:21680`, `Map/Legend` `387:2926` are local components on N1 (section `204:7912`). The Library still publishes `Map Pin` `23:307` and `Map Tile` `23:410`. P `210:10364` and `210:10410` use a navy grid with an orange ring and white pins; R6 `301:3116` the same. P `210:10487` has its own legend where 别人的 is a red square. P `204:15182` (the 漫游记录 tiles) uses a grid with a purple dot.
- Figma: move the three `Map/*` components into the Library (new section `Map · 地图`), deprecate `Map Pin` and `Map Tile` into `411:1228`. Swap the maps on `210:10364`, `210:10410`, `210:10487`, `204:15182` and the roam root to `Map/Base` (Plain or Fog); search ring → `route` 1.5 pt; legend → `Map/Legend`. `Map/Pin`: reorder `Level` to 0 / 1 / 2 (it is 1 / 0 / 2), keep the 44×44 hit frame, add a `Value` text property for the rent on selected pins (reference 12, Citi Bike).

**SR2-45 · P1 · State gaps in the kit that the build will have to guess**
- Rule: `apple-design-interaction` core rule ("Design every state, not just the happy path"); HIG `buttons.md`: "Always include a press state for a custom button".
- Nodes and gaps:
  - `Player/Button` `285:20238`: Loading shows a spinner and drops the label. Add the label after the spinner (`校验中`), keep the width.
  - `Player/Status Tag` `285:20260`: states Neutral / Live / Paused / Warning / Done, where Warning is red and Paused is amber. Rename: Neutral / Live / **Warning** (amber, was Paused) / **Error** (red, was Warning) / Done; add Paused as Neutral with a pause glyph.
  - `Player/Chip` `384:1218`: add `State=Disabled`, a `Count` badge, and Kind=Info (SR2-43).
  - `Player/Nav Bar` `384:1342`: Large title (SR2-05).
  - `City/Odds Bar` `382:1120`: properties Target and Caption only. Add `Win faces` as a variant 0 … 20 in steps the designs use (6, 9, 12, 15), and text properties for the two modifier chips, so 12 of 20 is not hand-painted.
  - `Player/Sheet` `287:462`: add `Scrim` = On / Off (map sheets have none) and a header variant with a trailing confirm.
  - `Player/Stat Tile` `285:20262`: add `Emphasis` = Default / Large (the today strip uses 22 pt, the tile is 20).
  - New: `Player/Hold Button` (SR2-10), `Club/List Card` (SR2-01), `Merchant/Root Header` (SR2-16).

**SR2-46 · P1 · There is no hand-off: nothing says which frames are final**
- Rule: `apple-design-review › Working rules` ("Review the flow, not just the screen"); HIG `design-principles.md › Simplicity` ("Be clear and direct"); reference 7.
- Numbers: frames marked Ready for dev: 0 on every page checked. Frames named `优化`: R1 70 of 211, R2 63 of 203, R5 22 of 146; R3 has 345 frames and R4 463, mixing restored mini-program screens with optimised ones. P and its R twins have diverged (漫游 root, SR2-03). The shipped app differs from both: its 漫游 tab is a list with 走起 and 漫游护照 (`r2-shots/02-tab-roam-TEST.png`), P's is a map.
- Issue: the next step is code. An engineer opening R4 sees 463 frames, with 70% of their text at 11 to 14 pt under `MP/Nav Bar` headers, and cannot know that only some are the design.
- Figma: (a) set Dev status **Ready for dev** on the frames listed in section 3.2 once their batch is done, and on nothing else. (b) New page `00 Hand-off · 交付清单`: one table per area with frame name, node id, the SwiftUI view it becomes, the kit components it uses, its states, and its motion row. (c) Rename the unoptimised R frames with a `还原 · ` prefix and move superseded twins into a section `Superseded`. (d) State the source of truth in the page description: P and N1 and C1 to C3 first; R `优化` frames where no P twin exists (owner question Q8).

**SR2-47 · P2 · Tokens: loose ends**
- `r-xl` is 28 in the Value mode and 24 in the MP mode; state which one sheets use (28) and bind `Player/Sheet` to it. The duplicate `r-2xl` is gone.
- `Motion` (25 variables) has no stagger, press scale, count-up, hold duration or Reduce Motion fade (values in SR2-49).
- `Type` has no accessibility-size mode (SR2-35).
- Ten `MP/*` text styles and 46 `N1/Icon/*` components are still live; N1 has 47 instances of them per the log (coin 28, flash 7, eye 3, book 3, and others), plus 8 `MP/Logo` and 3 deprecated `Button` instances. Add the nine missing glyphs to the Library `Icon/*` set, re-point, then move `MP/*` styles and `N1/Icon/*` to Deprecated.
- Icons still have no `Weight` property (SR1-40): add Regular / Semibold and use Semibold beside Semibold and Bold labels.
- Rule: `apple-design-foundations` core rules (semantic tokens, 8 pt grid); HIG `icons.md`: "match the weights of interface icons and adjacent text".

**SR2-48 · P2 · Kit documentation**
- Nodes: Player kit section `285:20181`.
- Issue: `Player/Stat Tile` and `City/Odds Bar` are white on the light canvas and cannot be seen; component descriptions say where a component came from (finding ids), not how to build it.
- Figma: a `bg` backing frame behind every dark component; rewrite each description to three lines: purpose, properties, SwiftUI mapping (table below).

#### SwiftUI mapping for the new kit (put each line in the component description)

API names are from the iOS 18 and iOS 26 SDKs as I know them; the project builds with Xcode 27, so confirm each against the iOS 27 SDK before relying on it.

| Component | SwiftUI | Notes the build needs |
|---|---|---|
| `City/Deed Card` | `struct DeedCard: View` with `Deed` model and `size: .full / .sheet / .row / .mini`; `RoundedRectangle(cornerRadius: 20, style: .continuous)`; band colour from an asset-catalog colour per district; photo `AsyncImage` + `.aspectRatio(16/9, contentMode: .fill)` + `.clipped()`; outline states `StrokeStyle(lineWidth: 1, dash: [4, 4])` | One accessibility element: `.accessibilityElement(children: .combine)` reading "老麦咖啡馆，武康路街区，插旗 0 级，每次到访 12 积分，你持有". `@ScaledMetric` for the band height. Hero: `.matchedTransitionSource(id:in:)` on the card and `.navigationTransition(.zoom(sourceID:in:))` on the detail. |
| `Map/Base` | Not a drawing: `Map(position:)` with a muted dark `.mapStyle(.standard(emphasis: .muted, pointsOfInterest: .excludingAll))`. Cells = `MapPolygon` with `.foregroundStyle(district.opacity(0.22))` and `.stroke(district, lineWidth: 1.5)`. Fog = one polygon covering the region with the explored cells as interior holes (`MKPolygon(coordinates:count:interiorPolygons:)`) | The Figma tones are a stand-in; MapKit's dark style will not match them exactly. Decide MapKit or a custom tile renderer (Q5). |
| `Map/Pin` | `Annotation(name, coordinate:, anchor: .bottom) { PinView(owner:badge:level:) }` inside a 44×44 frame; selection via `Map(selection:)` | I know of no clustering API in SwiftUI `Map`; clustering needs `MKMapView` in a representable or grouping by zoom level in the view model. Label: `.accessibilityLabel("老麦咖啡馆，可圈")`. |
| `Map/Legend` | `HStack` in a capsule with `.glassEffect()`, placed with `.safeAreaInset(edge: .bottom)` | Opaque `surface-2` when Reduce Transparency is on. |
| `Player/Moment` | `.fullScreenCover` presenting `MomentView(stage:headline:line:chips:primary:secondary:)`; beats with `PhaseAnimator(Beat.allCases, trigger:)` or `KeyframeAnimator` | Tap anywhere: jump to the last phase. `@Environment(\.accessibilityReduceMotion)`: show the last phase with a 200 ms opacity fade. Post `AccessibilityNotification.Announcement(headline + line)`. |
| `Moment/Stage` | A `@ViewBuilder` slot of `MomentView` | Height: 56% of the safe area in Regular, 240 pt in Compact. |
| `Moment/Art` | Vector assets (PDF or SVG in the asset catalog); die numeral as a `Text` overlay with `.contentTransition(.numericText())` | 2D rotation with `TimelineView` or a sprite sequence, or a 3D die in RealityKit: the design must choose (Q7). |
| `City/Odds Bar` | `HStack(spacing: 3)` of 20 `Capsule`s; filled count from the model | One element with `.accessibilityLabel("胜率")` and `.accessibilityValue("20 面里 12 面能赢，百分之六十")`. Not a `Gauge`. |
| `Player/Chip` | Choice: `Toggle(isOn:)` with `.toggleStyle(.button)` in a capsule style; Filter: `Menu` with a chip label; Info: plain `Label` | 44 pt hit area with `.contentShape(.capsule)` and padding. |
| `Player/Nav Bar` | Not a view: `NavigationStack`, `.navigationTitle`, `.navigationBarTitleDisplayMode`, `ToolbarItem(placement: .topBarTrailing)` | The system draws Back and the glass. |
| `Tab Bar / Player`, `/ Merchant` | `TabView` with `Tab` values | System floating bar on iOS 26 and later; do not draw it. |
| `Chrome/Scroll Edge` | `.scrollEdgeEffectStyle(.soft, for: .bottom)` | A gradient mask only as a fallback for older systems. |
| `Player/Hold Button` (new) | `Button` label + `.onLongPressGesture(minimumDuration: 0.8, maximumDistance: 24, perform:onPressingChanged:)`; ring = `Capsule().trim(from: 0, to: progress)` animated linearly | VoiceOver: a normal activation starts at once (`.accessibilityAction`), per HIG `gestures.md`: "Give people more than one way to interact". |
| `Media/Cover`, `Club/Default Cover` | `AsyncImage` with `Club/Default Cover` as the placeholder view (gradient + 96 pt initial at 12% opacity) | Decorative: `.accessibilityHidden(true)` unless it is the only content. |
| `System/Alert`, Date Picker, Keyboard | `.alert`, `.confirmationDialog`, `DatePicker` | Stand-ins. Never built by hand. |
| Sheets (`Player/Sheet`) | `.sheet` + `.presentationDetents`, `.presentationDragIndicator(.visible)`; map sheets add `.presentationBackgroundInteraction(.enabled(upThrough:))` | Detents per sheet are in SR2-49. |

### 2.7 · Prototype and motion (P `204:9667`, strips on N1, board `402:647`)

**SR2-49 · P1 · The motion spec names springs but not values per element; the build will have to invent them**
- Rule: `apple-design-motion` core rules ("Springs over fixed easing", "Interruptible + velocity handoff", "Honor Reduce Motion"); `motion-animation.md › 2.2 SwiftUI spring presets`, `2.3 Standard durations`; HIG `motion.md`: "Aim for brevity and precision in feedback animations"; reference 7.
- Nodes: board `402:647`; strip annotations in `399:4429` (each says only "Smart Animate · moment spring (Figma 247 / 17.3)"); `Motion` collection.
- Issue: the board gives five springs and twelve haptics. It does not say what moves, from where, to where, in what order, or which sheet rests at which height. Those are the lines an engineer types.
- Figma: add this table to the board, add the new tokens to `Motion`, and replace each strip annotation with its row.

  | Event | Element: from → to | Animation (SwiftUI) | Start | Haptic |
  |---|---|---|---|---|
  | Press, any button or row | scale 1 → 0.97 | `.easeOut(duration: 0.08)`; release `spring(response: 0.30, dampingFraction: 0.80)` | touch down | none |
  | Chip, segment, pin select | pin scale 1 → 1.15; chip fill cross-fade | `spring(response: 0.30, dampingFraction: 0.80)` | tap | selection |
  | Property sheet | detents `.height(420)`, `.large`; no scrim; map stays live | `spring(response: 0.38, dampingFraction: 0.86)` | pin tap | selection on settle |
  | Claim, challenge confirm sheets | one detent, height = content; scrim 40% | same | button | none |
  | 附近 sheet | detents `.height(96)`, `.medium`, `.large`; no scrim up to medium | same | — | selection on settle |
  | 队伍聊天, 提示 | `.medium`, `.large`; scrim 40% | same | button | none |
  | Hold to start | ring trim 0 → 1 | `.linear(duration: 0.8)`; early release: back to 0 with the press spring | touch down | impact medium at completion |
  | Fog cell lights | mask radius 0 → cell | `.easeOut(duration: 0.6)` | on entering a cell | impact light, at most one per 2 s |
  | 圈下了 1 · photo | claim thumbnail 58×58 → deed photo slot | zoom transition, `spring(response: 0.45, dampingFraction: 0.86)`; map camera to the cell over 0.6 s | 0 ms | none |
  | 圈下了 2 · deed | band offset y −44 → 0; text rows opacity 0 → 1, stagger 60 ms | `spring(response: 0.42, dampingFraction: 0.80)` | 350 ms | none |
  | 圈下了 3 · seal | scale 1.6 → 1, rotation −24° → −8°, opacity 0 → 1 | `spring(response: 0.40, dampingFraction: 0.55)` | 600 ms | impact heavy at contact (≈ 780 ms), success 150 ms later |
  | 圈下了 4 · text | headline offset y 12 → 0, opacity 0 → 1; chips stagger 60 ms; buttons fade 200 ms | `spring(response: 0.42, dampingFraction: 0.80)` | 950 ms; buttons 1,250 ms | none |
  | Die throw | follows the finger; on release, velocity feeds rotation; under 300 pt/s it springs back | `DragGesture` + `spring(response: 0.40, dampingFraction: 0.55)` | drag | impact light every 120 ms while rolling |
  | Die lands | scale 1.15 → 1; face counts to the roll | landing spring as above; `.contentTransition(.numericText())` over 400 ms | server result | impact rigid |
  | Modifiers | each chip flies to the total; total 14 → 17 | chip `spring(0.30, 0.80)`; total `numericText` 300 ms | +400 ms | win: two taps (0 ms at intensity 0.5, 120 ms at 1.0); lose: impact soft |
  | Rent arrives | total 0 → 186 in three steps; deed minis fan −8°, 0°, +8° | `numericText`, 800 ms total; fan `spring(0.42, 0.80)` | 0 ms | impact soft once |
  | Level up | bar fill old → new; medal scale 0.8 → 1 | `.smooth(duration: 0.6)`; then `spring(0.40, 0.55)` | 0 ms; medal 600 ms | impact rigid at the medal |
  | Reduce Motion | every row above becomes an opacity fade | `.easeInOut(duration: 0.2)` | — | unchanged |

  New `Motion` variables: `scale/press` 0.97, `scale/pin-selected` 1.15, `duration/stagger` 60, `duration/hold` 800, `duration/count-up` 800, `duration/reduce-motion-fade` 200, `delay/moment-deed` 350, `delay/moment-seal` 600, `delay/moment-text` 950, `delay/moment-actions` 1250. Every moment is skippable by a tap and finishes within 1.5 s.

**SR2-50 · P2 · Prototype loose ends**
- Rule: HIG `accessibility.md` (44×44 pt); HIG `design-principles.md › Craft`.
- Nodes and facts: flows on P are named `04 漫游` twice and `Flow 7` once. Eleven hotspots are under 44 pt: `back` 24×24 on create1 to create4, `segment-1/2/3` 119×30 on the three 消息 frames (six), `city stat pill` 173×36. Four overlay frames carry their scrim as an opaque grey rectangle inside the frame (`396:4369`, `396:4404`, `396:4449`, `396:4688`). R1, R2 and R3 have no reactions; only P plays. P has 639 unstyled top-level text nodes and sizes such as 18, 19, 21, 23, 25, 29 and 31 pt outside the ramp.
- Figma: rename the flows (`04a 漫游 · 开始`, `04b 漫游 · 地图`, `06b …`); wrap the eleven hotspots in 44 pt frames; replace the grey rectangles with a `scrim` fill at 40% bound to the variable (the Plugin API cannot set the overlay background, so note "set Background: scrim 40% in the UI" once per overlay); run the type map on P (SR2-12's script) so P is on the ramp before it is cloned into code.

**SR2-51 · P2 · The haptic map has stale and missing verbs**
- Rule: HIG `playing-haptics.md`: "build a clear, causal relationship between each haptic and the action that causes it"; `apple-design-motion › microinteractions-feedback.md › Restraint` (no double-firing on system controls).
- Nodes: board `402:647`.
- Issue: the table has a row `Flag plants`, but the claim moment no longer has a flag (it is a seal). There are no rows for hold-to-start, pin select, the level-up medal, or the quote expiring. `Roll won` says "custom: two rising taps" with no values. Nothing says which controls must not get an added haptic.
- Figma: rename `Flag plants` → `Seal lands`; add the rows from SR2-49; give the custom pattern its two transients (0 ms intensity 0.5 sharpness 0.4; 120 ms intensity 1.0 sharpness 0.7); add a line "No added haptic on system switches, pickers, sheets' own drag, or tab changes"; add "Sounds follow the silent switch and are off by default".

---

## 3 · Plan for the executor and the code hand-off

### 3.1 · Batched plan for the Opus Figma executor (about 120 calls, highest impact first)

Rules for the run, learned from round 1's log: write the scripts offline, one page per call, a dry run for any script that matches by name or by text, an inline render in the same call for anything visual, one log row per call. **After every swap script, run the three checks that would have caught this round's regressions**: (1) no visible text node narrower than 6 pt with two or more characters; (2) no component instance whose text property is still the component default where the frame needs its own value; (3) a render of every frame the script touched, looked at before the next call.

| Batch | What | Findings | Pages | Calls |
|---|---|---|---|---|
| **1 · Repair what round 1 broke** | 俱乐部 root cards; 扫码 glyph; N46 and N50 names and bases; odds bar sizing, N34 and its overlay; N66 titles; N28 and N33 rows; N50 label; 营销 icons and overflow; 首页 rail alignment and hotspots | SR2-01, 14, 23, 24, 37, 36, 38, 15, 02 | P, R4, N1, Library | 16 |
| **2 · Finish the kit** | Deed properties, `District` modes, `Size=Sheet`, Mini type, band label colour; Moment slot, labels, Layout; Art `Face`; Stage Rent and Level; odds bar properties; Button Loading; Status Tag rename; Chip states; Nav Bar Large; Sheet scrim; Hold Button; Club/List Card; Merchant/Root Header; move `Map/*` to the Library and deprecate the old pair; map tokens; `me` → white; `ink-3`; descriptions with the SwiftUI mapping; dark backings | SR2-42, 43, 45, 44, 31, 32, 33, 10, 48 | Library, N1 local components | 24 |
| **3 · N1: truth and legibility** | The cast on every deed; property sheets on Deed Sheet at 420 pt; N01, N02, N03; N07 legend, unlit pins, labels; die faces, N36 copy, N37; strips rebuilt with from and to frames and the photo hero; XXL at 852 and AX3 proofs; `N1 · 系统触点` section; Live Activity accent; caption sizes and loose text | SR2-25, 29, 30, 31, 26, 27, 28, 34, 35, 39, 40, 41 | N1 | 30 |
| **4 · Prototype and player** | Re-clone the changed N1 frames into P; 漫游 root; play HUD; 35 nav bars on P and 56 chevrons on N1; photos and placeholders; 战报, 结算, 排行榜; share-card switches; tab bar edge and scroll edge; sheet surfaces; flows, hotspots, scrims; type map on P; sync or retire the R1 twins | SR2-03, 04, 05, 06, 07, 08, 09, 11, 50 | P, R1, R2, R6 | 22 |
| **5 · Club, merchant, editor** | Kit and type script on the `优化` frames of R3, R4 and R5; 概览 and workbench; merchant root headers; R5 cards; 选择玩法 sheet; template-plaza icons and toast; editor text styles; `button-radius` | SR2-12, 13, 16, 17, 18, 19, 20, 21, 22 | R3, R4, R5, C1, C2, C3 | 18 |
| **6 · Hand-off and proof** | Motion and haptics board rows and tokens; icon merge and `Weight`; Ready for dev marks; the `00 Hand-off` page; renames; final census (the numbers below) and renders of the 24 frames in 3.2 | SR2-49, 51, 47, 46 | Library, all | 10 |
| | | | **Total** | **120** |

Order matters: batch 2 before 3 (the deed properties must exist before the cast is set), 3 before 4 (P re-clones N1). If the shared daily cap is short, stop after batch 3: batches 1 to 3 hold all six P0 items and fifteen of the P1 items.

Done means the census moves. Targets: visible defects of this review 0 (the five in batch 1); deed instances with a default name, level or number 0 (now 14 of 14 on N1); distinct deed photos ≥ 6 (now 1); odds bar height ≥ 160 (now 10); `MP/Nav Bar` on P 0 (now 35) and `Player/Nav Bar` on N1 ≥ 40 (now at most 2); N1 text at 14 pt or smaller under 30% (now 47%), unstyled 0 (now 76); map road, water, park against land ≥ 1.3:1 (now 1.31, 1.02, 1.07); band label contrast ≥ 4.5:1 on all six (now 2.31 to 3.54); strip beats that are identical to the one before 0 (now 3 strips); frames marked Ready for dev = the list in 3.2 (now 0).

### 3.2 · Code hand-off: what is final, per area, highest impact first

"Ready now" means I saw the frame in this review and found nothing above P2 on it. "After batch n" means it becomes final when that batch lands. Build in this order.

| Area | Ready now for SwiftUI | Ready after | Not for code |
|---|---|---|---|
| **City Monopoly** (not yet built: build first) | Claim flow sheets and states N18, N20, N23 `204:27073`, N24 `204:27181`, N25 `204:27271`, N26, N27 (section `204:27379`); 在地任务 N35 `204:34304`; map states N13 to N17 (section `204:24419`) as layout, with MapKit for the map; six attributes N64 `207:2026`, N65, N73; states N04, N05, N06 | **Batch 2**: `City/Deed Card`, `City/Odds Bar`, `Map/Pin`, `Player/Moment` (write these four views first). **Batch 3**: board home N01 `204:21814`, N03 `204:21889`; territory N07 `204:23260`; property sheets N08 to N12; 圈下了 N22 `204:26968`; challenge N34 `204:34263`, N36 to N41; 我的地盘 N46 `205:8376` and its sheets; 收租明细 N28 `204:33843`; 称号 N66; the six strips as the motion reference | N22·a, N22·b, N37·a, N68·a (archived); `N08·XXL` until rebuilt |
| **Player** | Lobby and hold to start `204:15032`, `289:2730`, `289:2804`; roam consent, running, moving, done (section `204:9671`, first four frames); new badge `210:10045`; 收集册 R2 `204:30158`; 我的 root `210:8603`; overlays 选择票种 `396:4369`, 提示 `396:4404`, 队伍聊天 `396:4449`; error states on R1 (`166:3280`, `169:4754`) | **Batch 1**: 俱乐部 root `210:8452`, 首页 `210:8239`. **Batch 4**: 漫游 root `210:8322`, play HUD `401:4731`, 发布 root `210:8374`, 战报 `204:15044`, 结算 `204:15096`, share cards, 票夹 R2 `204:29927` | R1 `169:4853` (superseded by P), P `210:10364`, `210:10410`, `210:10487` until they use `Map/Base` |
| **Editor** (already closest to final) | C1: editor list `237:31646`, 主题详情 `239:31923`, node sheet `238:20393`, publish blockers `249:16773`, ticket errors `249:46938`. C2: template editor `237:43689`, question card `238:16749`, player preview `238:25435`. C3: 发布活动 step 1 `237:59431`, AI 快速创建 `239:24018`, 小游戏库 `247:17370` | **Batch 5**: 选择玩法 sheet `237:71933` and its section; template plaza `243:1964`, `243:3249` | — |
| **Merchant** | Onboarding review `182:7693`; identity step with consent `182:7628` and its checked state `406:9580` (send `identityConsent: true`, per `CODE-QUEUE.md`) | **Batch 1**: workbench `182:7328`, 营销 `182:8065`. **Batch 5**: 模板 root `233:12260`, the three root headers, R5 协作邀请 `186:5944`, 协作详情 `186:6119`, 分润明细 `186:6257` | Every R4 and R5 frame not named `优化` |
| **Club** | Create wizard `204:24591`; 成员管理 sheet with the row menu `223:3698` | **Batch 5**: 概览 `204:24899`, `204:24850`; workbench `170:1744`; the rest of R3's `优化` frames after the kit and type script | Every R3 frame not named `优化` |

Three notes for the engineers, whatever the batch:
1. **System components are stand-ins in Figma.** Navigation bars, the tab bar, the scroll edge, alerts, the date picker, the keyboard and sheet chrome are drawn so the frames read; in code they are the system's (mapping table in 2.6).
2. **Motion comes from the table in SR2-49**, not from the per-frame notes, which still disagree in places.
3. **The app and the file disagree on the 漫游 tab root** (list in the app, map in the file). Do not build either until Q9 is answered.

---

## 4 · Owner questions (the plan proceeds on the default)

| # | Question | Default |
|---|---|---|
| Q1 | "Mine" on the map: white instead of blue, so blue can mean only 武康路街区? | Yes. White is already "you" on every primary button. |
| Q2 | The die: flick or tap only, and drop 甩一下手机 (shake)? | Yes. Shake is the system's undo gesture and needs motion access. |
| Q3 | Property sheets: a compact deed at a 420 pt detent with the map visible, the full deed on expand? | Yes. |
| Q4 | Light-theme buttons: capsule for the merchant too (`button-radius` 12 → 999)? Open since round 1. | Yes, one shape across player, merchant and editor. |
| Q5 | The map in code: MapKit (muted dark style, cells and fog as overlays) or a custom-drawn map? | MapKit. The Figma map is a stand-in and will not match tone for tone. |
| Q6 | Notifications and widgets for City Monopoly in the first build? | Design all now (SR2-39). Build the three notifications with the core loop; widgets one release later. |
| Q7 | The die: 2D illustrated art that rotates, or a 3D die? | 2D, from `Moment/Art`. A 3D die is a later upgrade. |
| Q8 | Source of truth when P and an R twin differ? | P, N1 and C1 to C3. R `优化` frames only where there is no P twin; the rest are marked 还原 or Superseded. |
| Q9 | 漫游 tab root: the map (file) or the list with 走起 and 漫游护照 (shipped app)? | The map. City Monopoly's door is the map. |
| Q10 | Keep the deed serial (`地契 · No. 12`)? | Yes, a real serial per district, issued at first claim. If the server has no such number, drop it. |
| Q11 | May district colours share hues with status colours, given status is never drawn as a hue on the map or the band? | Yes. Status is a badge shape there. |

---

## Severity count

| Area | P0 | P1 | P2 | Total |
|---|---|---|---|---|
| Player | 1 | 5 | 5 | 11 |
| Club | 0 | 1 | 1 | 2 |
| Merchant | 1 | 3 | 1 | 5 |
| Editor | 0 | 1 | 3 | 4 |
| City Monopoly N1 | 3 | 12 | 4 | 19 |
| Library and kit | 1 | 4 | 2 | 7 |
| Prototype and motion | 0 | 1 | 2 | 3 |
| **Total** | **6** | **27** | **18** | **51** |

## What works (keep through the build)

- **The deed as an idea**: band, photo, name, pips, rent line. On the 首页 rail the three band colours already make the game legible at a glance.
- **`Moment/Art`**: one glossy language for seal, die, shield, coin and medal, taken from `Badge/Art`. The 收集册 page `204:30158` and the new-badge screen `210:10045` remain the best art in the file.
- **The moment layout** (N22, N38, N40, N41): object, headline, one line, chips, one primary, one link. N40's tipped deed with the new holder's name is the one moment that already tells its story in a still.
- **The claim sheet** N18 to N25: four checks, error text in ink with a red glyph, the amber banner with one way forward.
- **The territory cells in district colours** and the pin set's shape-for-ownership rule.
- **The Motion & Haptics board** `402:647` and the `Motion` variables: the right container; it needs the rows of SR2-49.
- **Real overlays with drag** and 233 spring transitions on P: the prototype can now be felt.
- **The editor** (C1 to C3): the calmest, most finished part of the file. The publish-blockers sheet `249:16773` and the ticket error state `249:46938` are models for the rest.
- **The merchant identity step** `182:7628` with its consent checkbox and inline hint.
