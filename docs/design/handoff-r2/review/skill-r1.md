# SKILL REVIEW r1 · Skill-led design round 1 of 2 (whole Figma file)

Reviewer: Fable 5.2 · 2026-11-16 · **read-only** (no Figma node and no code was changed).
File `0YyoybGnU1KG0657wdGCPX`. Executor for this plan: Opus (section 3).

**Result: 50 findings. P0 8 · P1 24 · P2 18.**

Overall rating in the `apple-design-review` scale: **Needs work**. The file is now consistent and honest as a utility app (states, sheets, copy, 44 pt targets were fixed by the earlier rounds). What keeps it below Apple Design Award level is different in kind:

1. **City Monopoly has no object to remember.** The board home is a list, a property is a key–value table, and a win is the same table with a green die. Nothing on screen says "Monopoly" or "this street in Shanghai" (SR1-22 to SR1-25).
2. **Motion is written, not shown.** Annotations ask for springs; 208 of the 215 timed transitions on the prototype page play ease-out, sheets are frame swaps, and no drag exists anywhere (SR1-43, SR1-44).
3. **The reference page is not built from the kit.** N1 uses the old mini-program components (MP/Button 93, MP/Tag 67, MP/Chip 56) against 6 Player/Button instances, and 57% of its text is 14 pt or smaller (SR1-36, SR1-28).
4. **Three map drawings, five celebration styles, four tab bars.** Each is fine alone; together they read as several apps (SR1-24, SR1-33, SR1-39).
5. **One live defect on a tab root:** the 漫游 root still shows overlapping meta text in the 附近 rows (SR1-01).

The design's thesis today, in one sentence: *a dark, calm, well-behaved city-walk utility*. The thesis it needs: *a city you can own, one street sign at a time*. The single signature element proposed in this review is the **地契 (deed card)** with a district colour band (SR1-22). Everything else stays quiet.

---

## 0 · Method, the skills used, and the Figma calls used

### Skills, in the order the brief required

| # | Skill | What it drove in this audit | Files opened |
|---|---|---|---|
| 1 | `apple-design` (hub) | The two-axis decision: this is a **utility** surface for lists and forms (motion near-invisible) and a **game** surface for moments (motion is the substance). The restraint pass: "Remove it — does the design lose meaning, or just decoration?" and "Show the real product". | `references/restraint-and-antislop.md` |
| 2 | `apple-design-review` | Main lens and report format: context → five lenses (accessibility, conventions, craft, interaction, writing) → severity. The craft questions "Does it have a point of view?", "Is the boldness spent in one place?", "Does structure encode information?". | `hig/design-principles.md`, `designing-for-games.md`, `accessibility.md`, `typography.md`, `color.md`, `maps.md`, `live-activities.md`, `motion.md`, `playing-haptics.md`, `liquid-glass.md`, `buttons.md`, `tab-bars.md`, `icons.md`, `branding.md`, `feedback.md`, `loading.md` |
| 3 | `apple-design-foundations` | Type scale and Dynamic Type, 8-pt grid, semantic colour: measured by script (text sizes, gaps, radii, variable bindings). | `layout-grid-spacing.md › The 8pt spacing system`, `typography.md` |
| 4 | `apple-design-os` | Tab bar, large titles, sheets and detents, empty states, primary control in reach. | `ios-ipados.md` (headings), SKILL core rules |
| 5 | `apple-design-interaction` | Push vs sheet vs cover, disabled-with-reason, every state. | `state-and-feedback-logic.md › 4. Disabled States`, `navigation-models.md › 2.2, 2.3` |
| 6 | `apple-design-motion` | Springs over easing, interruptible, velocity handoff, haptic catalogue. | `motion-animation.md` (spring presets and timing table), `microinteractions-feedback.md`, `gestures-interaction.md` |
| 7 | `apple-design-materials` | Glass is a layer, not a paint; one icon language; symbol weight matches text. | `materials-liquid-glass.md`, `iconography-sf-symbols.md › 5.2, 5.3` |
| 8 | `apple-design-tactics` | Contrast, colour-alone, 44 pt, Reduce Motion, copy voice. | `accessibility-inclusive.md` (headings), SKILL core rules |

Citations below use the form `skill › file › heading`. HIG quotes are Apple's wording from the `apple-design-review` reference pages. Where no page covers a point, it is marked **judgment**.

### Figma calls: 20 used of the 35 allowed

| # | Call | What it returned |
|---|---|---|
| 1 | `create_session` | session |
| 2 | `use_figma` (read-only) | Sections of every page; variable collections; text and effect styles; the component inventory of Library `6:3` |
| 3 | `use_figma` (read-only) | N1 census (1,967 texts, 4,369 boxes, instances, effects, reactions, annotations) + section `204:22013` |
| 4 | `use_figma` (read-only) | Motion annotations of the N1 moment frames + sections `204:34179`, `204:34760`, `205:8940` |
| 5 | `use_figma` (read-only) | N1 sections `205:9363`, `207:2684`, `208:2662`, `209:15518` |
| 6–7 | `get_screenshot` ×2 | N1 sections `204:24419` (territory map), `204:27379` (claim) |
| 8 | `use_figma` (read-only) | Prototype page P census: 11 flows, 313 reaction nodes, transitions, easing, durations, scroll, fixed layers, kit use |
| 9–11 | `get_screenshot` ×3 | P sections `204:9668` (tab roots), `204:9670` (play loop), `204:9671` (roam) |
| 12 | `use_figma` (read-only) | Kit metrics (type, radius and gap bindings, component anatomy) + the four kit sections `285:20181`, `316:4681`, `291:60973`, `276:295` |
| 13–16 | `use_figma` (read-only) ×4 | R4, R3, C1, C2: light census + 5 frames each |
| 17 | `get_screenshot` | R6 celebrations section `102:1047` |
| 18–20 | `use_figma` (read-only) ×3 | R2 (5 frames), C3 (5 frames), R4 (5 more frames) |

Every `use_figma` script only read nodes and rendered them. Nothing was created, renamed or moved.

### What I saw and what I did not

- **Seen, rendered at 1×:** all 10 N1 feature sections (103 frames); P tab roots, play loop and roam (about 34 frames); the four role kits; R6 celebrations (20 frames).
- **Seen, rendered at 0.75×:** R4 `182:7328` `182:7693` `183:1731` `233:9703` `182:8065` `182:8263` `180:7203` `233:12260` `358:9915` `322:14880`; R3 `204:24899` `204:24850` `223:3698` `204:24591` `170:1744`; R2 `204:30158` `181:3114` `204:29927` `314:3734` `181:3539`; C1 `237:31646` `237:67108` `238:20393` `249:16773` `239:31923`; C2 `237:43689` `237:71933` `238:16749` `238:25435` `238:25538`; C3 `237:59431` `238:14596` `239:24018` `243:1964` `247:17370`.
- **Measured by script, not by eye:** text sizes and styles, variable bindings, radii, gaps, effects, instance counts, prototype reactions, annotation counts.
- **Contrast** was measured from the rendered pixels of N1 (WCAG relative luminance, background = most common pixel, text = 99.5th-percentile distance from it). Anti-aliasing makes small text read slightly lower than its token value; both figures are given where it matters.
- **Local evidence read:** `revise/r2/LOG.md`, `revise/r2/PLAN.md`, `review/verify-r1.md` (sections 0, 2.2, 3, 4, 5), the reference sections of the four `full-*.md` reviews and `iterate/round-1-refs.md`, all eight contact sheets, `final-pass-n1.md`, and six app screenshots from `r2-shots/` (home, roam, lobby, merchant workbench, club detail, gameplay editor).
- **Not seen:** R5 (creator and cooperation) was not rendered. R1 was read only through its copies on P. P sections 1 and 4 to 9 were not rendered (section 4 is a copy of N1). The Library pages `6:2` Foundations and `6:4` Patterns were inventoried, not rendered. `Tab Bar / Player` `12:129` was read by size only. Roughly 2,300 frames exist; this review saw about 230. Motion and haptics cannot be judged from stills; the motion findings rest on the prototype data, which is exact.
- **Not re-listed:** anything `LOG.md` records as done. Three items below touch earlier findings and say so (SR1-01 extends 4.2, SR1-36 extends F-11, SR1-39 extends PL-01's tab bar work).

---

## 1 · References (12, none cited in any earlier review)

Checked against the reference sections of `full-player.md`, `full-member-club.md`, `full-merchant-creator.md`, `full-config.md`, `verify-r1.md` and `iterate/round-1-refs.md`. Two apps appear in earlier reviews with other screens: Apple Fitness (award detail, awards list, Edit Activity, weekly schedule) and Apple Games (achievements). The Fitness and Games screens below are different ones; none of the eight Mobbin screen ids below occurs in any earlier file. ADA text is quoted from `developer.apple.com/design/awards/` (2026), `/2025/` and `/2024/`, fetched today. "Lesson" lines marked *my reading* are not Apple's words.

| # | Reference | What Apple or the screen shows | The specific lesson for this file |
|---|---|---|---|
| 1 | **PowerWash Simulator** · ADA 2026 finalist, Delight and Fun (game) | "thoughtful touches like specific haptic feedback for each hose nozzle" | Each game verb gets its own haptic, used nowhere else: plant a flag, roll, land, collect rent, lose a place. Today the notes reuse `.success` for five different events (SR1-47). |
| 2 | **Grand Mountain Adventure 2** · ADA 2026 finalist, Interaction (game) | "the gestures are smooth, quick to pick up, and immediately responsive" | The dice is thrown with a flick, not confirmed with a button; the button stays as the fallback. The prototype has no drag trigger at all (SR1-46). |
| 3 | **Guitar Wiz** · ADA 2026 winner, Inclusivity (app) | "Robust VoiceOver integration provides spoken information and instructions"; supports Differentiate Without Color | A map pin must say who owns it by shape, not by ring colour (SR1-26). |
| 4 | **Pine Hearts** · ADA 2026 winner, Inclusivity (game) | "settings that let players enhance text legibility, customize controls, and ease both motion and sensory feedback" | Game moments need a Reduce Motion frame and an XXL frame each, and one in-game setting for 动效与触感 (SR1-49). |
| 5 | **Katha Room** · ADA 2026 finalist, Social Impact (app) | "decorates them with a UI drawn from the Gond art form", "its intricate patterns and vibrant colors bringing warmth to every screen" | Identity comes from the place's own visual language. For Shanghai that is the blue enamel street sign and house-number plate: the source for the deed card band (SR1-22). *My reading.* |
| 6 | **Balatro** · ADA 2025 winner, Delight and Fun (game) | "A precisely calibrated mix of poker, solitaire, deck-building, and chaos." | The number is the spectacle: the sum counts up and each modifier lands with its own beat. The roll result `14 + 3 = 17` is 14 pt body text today (SR1-25). *My reading of the game.* |
| 7 | **CapWords** · ADA 2025 winner, Delight and Fun (app) | "makes the whole world a language playground" | A photo of a real thing becomes a collectible object. The claim photo is the player's own proof; today it is a 58 pt thumbnail under a table (SR1-22, SR1-25). *My reading.* |
| 8 | **Watch Duty** · ADA 2025 winner, Social Impact (app) | "Clearly and reliably offering updates, resources, and real-time guidance." | A map people act on outdoors uses one legend, one colour per meaning and real street labels (SR1-24). |
| 9 | **oko** · ADA 2024 winner, Inclusivity (app) | "takes full advantage of flawless VoiceOver and Dynamic Type implementation" | A street-level app must be usable without looking: the four claim checks need a spoken and a haptic result, not only a spinner turning into a tick (SR1-47). |
| 10 | **Apple Games · Friends** (Mobbin): [active challenge](https://mobbin.com/screens/ca25ef50-6b12-4c17-a52d-4e9e120ca4ed), [friends and groups](https://mobbin.com/screens/416f2956-a1fc-4118-be43-416a7dec79ba) | Large title; a challenge card tinted by its own content, one line of state ("Challenge started! Be the first to play", "6d 23h left"), one button; floating glass tab bar | A game hub is led by tinted cards with one action each, not by a list of chevron rows. This is the pattern for the CITY home (SR1-23). |
| 11 | **Apple Fitness (iOS 26)** (Mobbin): [Go For It](https://mobbin.com/screens/385c1711-6119-4b91-8ec2-50851648825a), [Sharing empty state](https://mobbin.com/screens/58350124-152e-4d0e-9622-1d9ba918289c), [alert](https://mobbin.com/screens/2b5e9c1b-195a-4641-b63e-10430a03fa82) | Locked awards drawn as outline art with a progress bar; an empty state as one glass card (icon, title, one line, one button); the iOS 26 alert with a capsule button | Unlit and claimable places can be outline versions of the same deed art (SR1-22). The system alert is no longer hairline rows of blue text (SR1-20). |
| 12 | **Maps as the page** (Mobbin): [Rodeo](https://mobbin.com/screens/990a7f50-f867-498b-bd84-9557125ec1e9), [ClassPass Browse nearby](https://mobbin.com/screens/f00e727e-f9a5-49f6-a675-8f3f1e1d9f89), [Fresha](https://mobbin.com/screens/f66940a0-458d-4a59-97df-3b8889a42b1b) | Rodeo: a real map with street names, pins that carry a pictogram and a name. ClassPass: a 150 pt map module inside a scrolling page. Fresha: pins with the value on them, sheet below, glass bar | Pins carry a name and a value; a home page can hold a live map module; street names stay on (SR1-23, SR1-24, SR1-26). |

Official pages cited for rules but not counted as references: HIG *Design principles* (June 2026: Craft, Delight), *Branding*, *Icons*. None was cited before.

---

## 2 · Findings by area

Each finding: id · severity · rule · nodes · issue · how to optimise · how to implement in Figma.
Tokens are the file's own variables (`Color`, `Spacing`, `Radius`, `Type` collections) and text styles (`t-*`, `role/*`).

### 2.1 · Player (P `204:9667`, R1 `90:3`, R6 `91:34`)

**SR1-01 · P0 · The 附近 rows on the 漫游 root still overlap their own text**
- Rule: `apple-design-review › Lens 3 craft` ("Spacing, alignment, wording: is it finished?"); HIG `design-principles.md › Craft`: "Every element of your design shows people how much you care."
- Nodes: P `210:8322` (rows 苏州河夜行 · 七座桥, 武康路慢走 · 六个老房子); component `Player/Theme Card` `287:43163`, variant Size=Row.
- Issue: the meta line reads as two strings on top of each other ("¥29 免费 晚 19:…00 徐汇区"). Round 2 item 4.2 repaired the Large variant (9 cards on P, 12 on R1); the Row variant in this list was not touched. It is the second tab of the prototype.
- Optimise: one meta line, three pairs at most: `¥29 · 今晚 19:30 · 徐汇区`.
- Figma: in every `Player/Theme Card` instance with Size=Row or Tile on P (14 instances) and R1, reset the glyph layers to the component's icons and write the value into the label layers (same method as LOG rows 11–12, 17). Then set the meta row in the main component to auto-layout horizontal, hug, gap `sp-1` (4), so an override cannot overlap again.

**SR1-02 · P1 · The play screen is a paragraph on black**
- Rule: HIG `designing-for-games.md › Look stunning on every display` ("Design for the full-screen experience"); `design-principles.md › Delight`: "Identify the emotion you want to inspire… a game might thrill."
- Nodes: P `289:2596`, `210:10974`; N1 `209:14900` (N87).
- Issue: chapter label, title, four lines of story, then about 300 pt of empty black, then the 下一站 card. No image of the chapter, no sense of direction, and 提示 / 队伍 / 背包 are three equal buttons. This is where a player spends most of a 90-minute game.
- Optimise: the top 40% is the chapter (its cover with a bottom fade, title over it); the story sits under it; the 下一站 card gains a heading arrow and the distance as the large number, because "which way" is the question on the street.
- Figma: add a 393×300 cover (image fill, `media-shade` gradient 0 → 80% over the lower 120 pt) behind the header; title `t-1` 28 Bold on the image, chapter label `t-foot`; story `t-body` 17. In the 下一站 card put a 44 pt heading arrow (rotating glyph, annotate "follows compass, 15° steps") left of `1.2 km` in `role/stat` 22 Bold; demote 用时 and 线索 to one caption line. Bottom row: keep three, but 提示 becomes `Player/Button` Secondary 44 and the other two icon-only glass circles with labels under them.

**SR1-03 · P1 · Content runs under the floating tab bar with no edge treatment**
- Rule: `apple-design-review › hig/liquid-glass.md › Review checklist 6`: "Content fades and blurs where it meets a bar instead of colliding with it"; `apple-design-materials` core rule "Glass is a layer, not a paint".
- Nodes: P `210:8239` (a line of text is readable through the bar), `210:8322`, `210:8452` (a club cover under the bar), `210:8603`.
- Issue: the capsule bar sits on live content; text shows through and beside it.
- Optimise: a 32 pt fade from the page colour under the bar, and 96 pt of bottom inset so the last row can scroll clear.
- Figma: new component `Chrome/Scroll Edge` (393×120, linear gradient `bg` 0% → `bg` 100%, bottom-pinned, under the tab bar instance). Place it on the five tab roots of P and of the merchant roots (`182:7328`, `182:8065`, `233:12260`). Bind the fill to `bg` so it follows the mode.

**SR1-04 · P1 · Placeholder and unrelated images inside finished frames**
- Rule: `apple-design › restraint-and-antislop.md` default 2: "Show the real product. Always… Placeholder rectangles, abstract SVG 'UI diagrams,' and lorem blocks are a failure, not a stand-in."
- Nodes: P `210:8239` (附近活动: two stock café photos for 苏州河夜行 and 武康路慢走), `210:8374` (发布 root: two empty dark cards with a route glyph), R2 `204:29927` (票夹: empty pass cover), N1 `209:15118`, `209:15194` (chat tiles labelled 图片 1 / 2 / 3), R4 `233:12260` (grey skeleton bars inside the hero cover).
- Issue: the first screen of the app sells Shanghai walks with photos that are not Shanghai; other frames ship grey boxes.
- Optimise: every cover is either a real place photo already in the file or a designed default (SR1-08).
- Figma: build `Media/Cover` (component set, 16:9 and 1:1, Image property) from the place photos already in the file (`123:1497` and the C3 asset board `237:9072`, 178 images; the local `seed-images/` folder has 35). Swap the five frames above. Chat tiles: use three covers at 96×96 r12.

**SR1-05 · P1 · 走起 is a small pill in the middle of the map**
- Rule: `apple-design-os` core rule: "Anchor primary controls in reach — bottom on iPhone"; HIG `gestures` via `apple-design-motion › gestures-interaction.md › Discoverability vs. Hidden Gestures`.
- Nodes: P `210:8322`; R1 `169:4853`.
- Issue: the one action of the tab is a 120 pt pill at mid-screen with an 11 pt caption 按住 0.8 秒开始漫游. The hold is invisible until it is tried.
- Optimise: a 52 pt hold button pinned above the 附近 peek, with the ring drawn at rest so the hold is taught before the touch.
- Figma: `Player/Button` Primary Size=52, width 361, 12 pt above the sheet grabber; a 2 pt ring track around the pill (`ink` 24%) as a separate layer named `hold ring`; caption `t-foot` 13 `ink-2`. Wire it as in SR1-46.

**SR1-06 · P2 · 本局战报 contradicts itself**
- Rule: `apple-design-review › Lens 5` ("Names come from what people control"); HIG `feedback.md`.
- Nodes: P `204:15044`.
- Issue: the tag says 已通关 while the tiles say 0/6, "—" and 本局不计分; rows end in "→" instead of a chevron (see SR1-13).
- Optimise: show only tiles that have a value; if the game does not score, say so once in the subtitle.
- Figma: hide the two empty `Player/Stat Tile` instances; subtitle `本局不计分`; replace the three arrows with `Icon/chev`.

**SR1-07 · P2 · The 发布 root opens on an empty card**
- Rule: HIG `tab-bars.md`: "Use a tab bar to support navigation, not to provide actions"; `design-principles.md › Purpose`.
- Nodes: P `210:8374`.
- Issue: the tab is named for an action and lands on a template gallery whose hero is a blank box.
- Optimise: lead with what the creator was doing: 继续上次的草稿, then two entry cards (主题, 玩法), then templates. Naming is an owner question (Q5).
- Figma: first block = `Editor/History Row` style card in the player theme with cover, title, "3 天前 · 还差 2 项"; second block = two 172×120 cards.

### 2.2 · Club (R3 `91:33`, R2 `91:656`)

**SR1-08 · P1 · Every club wears the same loud cover**
- Rule: `apple-design-review › Lens 3 craft` ("Is the boldness spent in one place?"); HIG `branding.md`: "Ensure branding always defers to content."
- Nodes: `Club/Header` `291:66013` (all 5 states); P `210:8452` (three clubs, one cover); R3 `204:24899`, `204:24850`, `170:1744`.
- Issue: the 一起玩 illustration (teal, pink, yellow) is the most saturated thing in the player app and it repeats on every club. Clubs become indistinguishable and the cover fights the monochrome kit.
- Optimise: a default cover system keyed to the six club types of the wizard (校园社团, 旅行组织, 兴趣社群, 商业活动组织方, 内容创作团队, 其他): one muted hue and one glyph per type, the club's initial large. A club that uploads a photo uses the photo.
- Figma: add property `Cover` to `Club/Header` (Photo / Default) and an instance-swap slot fed by `Media/Cover`; draw six `Club/Default Cover` variants (393×150, fill = the district palette of SR1-22 at 40% over `surface`, 96 pt initial in `ink` 12%, type glyph 24 top-left). Give the three clubs on `210:8452` three different covers.

**SR1-09 · P1 · 概览 does not answer "what is this club doing next"**
- Rule: HIG `layout` via `apple-design-review › Lens 3` ("Order content by relative importance"); `apple-design-interaction › state-and-feedback-logic.md › 2. Empty States` (an empty state has a path forward).
- Nodes: R3 `204:24899`, `204:24850`.
- Issue: order is description, 俱乐部勋章 row, one avatar with "+4" for four members, then an empty 贡献榜 drawn as a bold sentence with no icon and no action. The next activity is on another tab.
- Optimise: 概览 = next activity card, members, 贡献榜, about.
- Figma: insert a `Member/Order Card`-sized card first (cover 56, title, `11月22日 周六 14:00`, 12 / 20 人, `Player/Button` Secondary 44 查看); members = `Avatar Stack` with four different avatars; the empty board = `Player/State` Kind=Empty with action 发起一次活动 (managers) or no action (members).

**SR1-10 · P2 · Workbench: three bare icons in the bar, look-alike rows**
- Rule: HIG `toolbars` via `apple-design-review › Lens 2` ("a More menu holds the overflow"); `accessibility.md`: "Consider spacing between controls as important as size."
- Nodes: R3 `170:1744`.
- Issue: scan, QR and settings sit about 8 pt apart at the top right; twelve rows below use a single character in a circle as their image.
- Optimise: one 44 pt action (扫码) and a ⋯ menu; project rows get a 44 pt cover.
- Figma: keep `nav action scan (44 hit)`, replace the other two with `Icon/more` opening `Club/Row Menu` (团码, 设置); in the 项目 list swap the initial circles for `Media/Cover` 44×44 r8.

### 2.3 · Merchant (R4 `90:26`)

**SR1-11 · P1 · The merchant's first job is one of four equal circles**
- Rule: HIG `buttons.md`: "use a button that has a prominent visual style for the most likely action in a view"; `apple-design-os` core rule (primary control in reach).
- Nodes: `182:7328`; kit `Merchant/Quick Action` `316:6040`, `Merchant/Today Card` `316:5878`.
- Issue: 扫码 / 客户 / 财务 / 更多 are the same white circle. The work waiting ("有 1 笔售后待回应") is a 14 pt row under them, while ¥268.00 takes 42 pt. The app has moved on: the `r2-shots/18-…` screenshot already puts 待处理 first and fills the 扫码 circle black. Figma is behind the build.
- Optimise: 待处理 first (amber NeedsMe), then Today, then a scan action that cannot be missed.
- Figma: add variant `Emphasis=Primary` to `Merchant/Quick Action` (fill `cta`, glyph `cta-ink`) and use it for 扫码; move the alert row above `Merchant/Today Card` and restyle it as a card with `Merchant/Status Tag` NeedsMe and the count in `t-2` 22 Bold; Today's income drops from 42 to `role/stat`-scale 28.

**SR1-12 · P2 · Two shapes for the same shortcut**
- Rule: HIG `design-principles.md › Familiarity`: "Once you establish a behavior or appearance for an element, apply it throughout your design."
- Nodes: `182:7328` (circles), `182:8065` (rounded squares: 店铺参谋, 店铺装修, 发主题, 发活动).
- Figma: use `Merchant/Quick Action` on 营销 too; delete the local tiles.

**SR1-13 · P2 · Arrows and chevrons both mean "open"**
- Rule: HIG `icons.md`: "Maintain visual consistency across all interface icons in your app"; `branding.md`: "use standard symbols to represent common actions".
- Nodes: R4 `182:7328` ("有 1 笔售后待回应 →"), `182:8065` ("管理 →"), `180:7203` ("合作分润 →"); P `204:15044` (three "→" rows). Elsewhere the same pages use "›".
- Figma: replace the arrow glyphs with `Icon/chev` 16 in `ink-3`. Keep "→" only inside value changes (`Lv23 → Lv25`).

**SR1-14 · P2 · 营销 opens on a bare "2"**
- Rule: HIG `charting-data` idea via `apple-design-review › Lens 3` ("Does structure encode information?").
- Nodes: `182:8065`.
- Figma: replace the 近 30 天报名 block with `Merchant/Metric Module` `341:1489` (value, delta against the previous 30 days, bars), as `182:8263` already does.

**SR1-15 · P2 · Three header styles across five merchant roots**
- Rule: HIG `design-principles.md › Familiarity`; `apple-design-os` (large titles).
- Nodes: `182:7328` (shop name 22 Bold), `182:8065` (large left title), `233:12260` (centred inline title 模板 with a text button 发布).
- Figma: `Merchant/Nav Bar` Type=Root on all five roots; 工作台 keeps the shop name as its title; 发布 on 模板 becomes the bar's trailing action.

### 2.4 · Editor (C1 `237:14642`, C2 `235:178`, C3 `235:13237`)

**SR1-16 · P1 · A primary button with no label**
- Rule: HIG `buttons.md`: "Ensure that each button clearly communicates its purpose"; `apple-design-interaction › state-and-feedback-logic.md › 4. Disabled States`: "Disable with discoverable reason".
- Nodes: C2 `237:71933` (A3 问答 · 未选), bottom bar; check the other 36 frames of section `237:71932`.
- Issue: the bar reads 选一个玩法 on the left and shows a solid black capsule with nothing in it on the right. It looks active and says nothing.
- Figma: label `下一步`; in the unselected state use the disabled style (`mp/disabled` fill, `ink-3` label). The hint on the left already gives the reason.

**SR1-17 · P1 · Text under 11 pt is back**
- Rule: HIG `typography.md`: iOS default 17 pt, minimum 11 pt; `apple-design-foundations` non-negotiable rules.
- Nodes (from the census): C1 sample of 9 frames: 10 pt ×22, 8 pt ×4 (`237:31646`, `237:67108`, `238:20393`, `249:16773`, `239:31923`, `241:1680`, `246:5882`, `237:32444`, `249:19962`); C2 sample of 8 frames: 10 pt ×12 (`237:43689`, `237:71933`, `238:16749`, `238:25435`, `238:25538`, `237:64541`, `239:20809`, `243:24749`); Editor kit `276:295`: 10 pt ×10, 8 pt ×3; P: 10 pt ×25; Player kit: 10 pt ×1.
- Figma: one script per page: every text node with `fontSize < 11` → 11 with style `t-cap2`, then screenshot the frames it touched. Counters (`11/30`) go to `t-cap` 12.

**SR1-18 · P2 · Thirty rows, six icons**
- Rule: `apple-design-review › Lens 3 craft`: "Does structure encode information? Numbering, eyebrows, dividers, and labels should say something true about the content."
- Nodes: C1 `239:31923` (主题详情, full).
- Issue: 生命值, 幸运值, 行动次数 and 体力 share one bar glyph; four other rows share a bag. The icons add width, not meaning.
- Figma: remove leading icons in the 数值与状态 and 高级 groups (`Editor/Row` showIcon=false); keep icons only in 基本信息, where each is distinct.

**SR1-19 · P2 · The player preview uses a cartoon chest**
- Rule: HIG `design-principles.md › Familiarity` (consistent visuals); **judgment** on illustration style.
- Nodes: C2 `238:25435`.
- Issue: a glossy 3D chest on purple appears nowhere else in the product. The creator is previewing their own gameplay.
- Figma: show the template's own cover (the route art from `237:43689`) or the `G6/Gameplay Preview` tile of the chosen gameplay.

**SR1-20 · P2 · The alert stand-in is the old system alert**
- Rule: HIG `alerts` via `apple-design-review › Lens 4`; reference 11 (the iOS 26 alert has capsule buttons).
- Nodes: `Editor/Confirm Dialog` `290:20572`.
- Issue: hairline-separated rows with blue 取消. Blue was removed from the rest of the editor in rounds 1 and 2, and iOS 26 and 27 draw alerts differently.
- Figma: redraw as a stand-in of the current alert: title `t-head`, message `t-foot`, two capsule buttons side by side (neutral fill, destructive label in `bad`); rename `System/Alert · 系统控件替身` and move it to section `341:911` beside the date picker and keyboard stand-ins.

**SR1-21 · P2 · Two segmented controls in the light theme**
- Rule: HIG `design-principles.md › Familiarity`.
- Nodes: C1 `237:31646` (列表 | 地图: selected = dark fill), `Merchant/Segmented` `316:5034` (selected = white thumb), base `Segmented Control` `12:299`.
- Figma: keep the white-thumb version (it matches the system); swap the five `Segmented · 列表 | 地图` instances.

### 2.5 · City Monopoly and the new features (N1 `204:7911`)

N1 has not been built in code, so this is the cheapest place to raise the bar. The structure (states, sheets, checks, copy) is sound and should stay. The findings are about identity, hierarchy, legibility and the moments.

**SR1-22 · P0 · The game has no signature object: design the 地契 (deed card)**
- Rule: `apple-design-review › Lens 3 craft`: "Name the one thing this design would be remembered by" and "One signature element, everything around it quiet"; HIG `design-principles.md › Delight`: "Create defining moments"; references 5, 7, 11.
- Nodes: property sheets `204:23400` (N08), `204:23542` (N09), `204:23691` (N10), `204:23832` (N11), `204:23956` (N12); result `204:26968` (N22); lists `204:21814` (N01 我的地盘), `205:8376` (N46); rent `204:33843` (N28).
- Issue: a place is always a title, two tags and a grey table. A flagged landmark and a corner shop look the same. Nothing can be collected, compared or shared.
- Optimise: one card that *is* the property, modelled on a Monopoly title deed and a Shanghai street sign: a colour band for the district (the colour group), the place photo, the name, level pips, the rent line.
- Figma: new component set `City/Deed Card` in the Player kit section `285:20181`.
  - Properties: `Size` = Full (329×420, sheets and results) / Row (361×72, lists) / Mini (96×120, rails, pin callout); `State` = Mine / Other / Protected / Challengeable / Claimable / Weathered / Unlit; text props 名称, 街区, 等级, 租金; instance-swap `Photo`.
  - Anatomy (Full): r `r-lg` 20, fill `surface`; band 329×44 at the top, fill `district/n`, district name `role/tag` 12 Semibold in `on-solid`; photo 16:9 below the band; name `t-2` 22 Bold; pips = three 6 pt dots (filled = level); rent line `role/stat` 22 Bold with the coin glyph and caption `t-foot` 每次到访; holder row (avatar 28, name) for Other. Claimable and Unlit = outline version (photo replaced by the band colour at 12%, dashed 1 pt border `sep-strong`).
  - New variables in `Color` (all ten modes): `district/1`…`district/6` and `district/1-soft`…`district/6-soft`. Start from the three already used as dots on N01 (blue 武康路, green 安福路, orange 愚园路) and add three. Scope: frame fill and shape fill only.
  - Use: N08–N12 replace the title + tags + first table with Deed Full (the sheet keeps the banner, one table of costs, the primary); N22 and N38 use it as the hero (SR1-25); N01 and N46 rows become Deed Row; N28 rows show Deed Mini as the leading image.

**SR1-23 · P0 · The CITY home is a settings list; it has no board**
- Rule: HIG `maps.md`: "In general, make your map interactive"; `design-principles.md › Purpose`: "Keep focused. Prioritize your app's most important features"; reference 10, reference 12 (ClassPass).
- Nodes: `204:21814` (N01); empty `204:21889` (N03); P `204:32786`.
- Issue: stat card, a white 打开领地图 pill, four chevron rows, three progress rows, three place rows. The map, which is the board, is one tap away behind a button. A player cannot see their city.
- Optimise: the first screen shows the board. Order: title → live map module with my flags → today strip → 需要你处理 → 我的地盘 (deeds) → the four secondary rows.
- Figma: on N01 insert a map module 361×220 r20 (instance of the map of SR1-24, Territory layer, my pins, the top stat pill overlaid at 12 pt inset, a 44 pt expand glyph bottom-right; the whole module links to N07). Remove the white pill. Today strip = three `Player/Stat Tile` (积分 1,286 with +186 待入账 as caption; 持有 3 / 9; 赛季 12 天). 需要你处理 = up to two rows with `Player/Status Tag` Warning (风化 · 9 天未到; 保护 11:42 后结束). 我的地盘 = `City/Deed Card` Row ×3. 收租明细, 赛季榜, 战队频道, 收藏据点 move to one grouped list at the end. N03 (empty) shows the same map with claimable outlines and one primary 去圈第一块地.

**SR1-24 · P0 · Three map drawings, two legends, no street names**
- Rule: HIG `maps.md`: "Use annotations that match the visual style of your app" and "Use distinctive styling to differentiate the features of your map"; HIG `color.md`: "Avoid using the same color to mean different things"; `apple-design › restraint-and-antislop.md` ("Show the real product"); reference 8.
- Nodes: `N1/迷雾地图` `204:21627` (25 instances on N1, 17 on P); `204:23260` (N07); P `210:8322` (roam root), `210:10364` and `210:10410` (navy grid, orange ring, white pins), `210:10487` (fog), `204:15182` (history tiles); legends on `204:23260` (别人的 = blue ring) and `210:10487` (别人的 = red square).
- Issue: the territory map is a grey field with a black blob and a grid. The explored area is *darker* than the fog, which reverses the metaphor. No street is named, so it could be any city. The roam map is a different drawing with different pins, and the two legends give 别人的 two different marks.
- Optimise: one base map that looks like Shanghai at night, with fog as a layer over it and territory as outlines on it.
- Figma: rebuild the main component `204:21627` as `Map/Base` with property `Layer` = Plain / Fog / Territory.
  - Base: `map-land` ground, `map-road` roads at two widths, `map-water` (苏州河 or 黄浦江 edge), `map-park`; street labels in `t-cap2` 11 Medium `ink-3` along the roads (武康路, 安福路, 湖南路, 复兴西路); two landmark glyphs.
  - Fog: a `bg` layer at 62% with a 24 pt soft edge, so unexplored is darker and explored shows the real map.
  - Territory: each cell outlined 1.5 pt in its `district/n`; my cells filled `district/n-soft`.
  - One `Map/Legend` component (我的 / 别人的 / 可圈 / 未点亮, marks taken from the pin set of SR1-26) used on both `204:23260` and `210:10487`.
  - Swap the roam maps on P (`210:8322`, `210:10364`, `210:10410`) to `Map/Base` Plain; the orange search ring becomes `route` at 1.5 pt.

**SR1-25 · P0 · The moments are result tables**
- Rule: HIG `design-principles.md › Delight`: "Know the feeling you want to evoke, and let it shape your design" and "Don't mistake delight for decoration"; `apple-design` surface axis (a game moment is the flagship surface: under-animation and under-staging is the failure there); references 6, 7.
- Nodes: `204:26968` (N22 圈下了), `298:2524`, `298:2564` (in-betweens); `204:34340` (N36), `204:34369` (N37), `298:2604`; `204:34407` (N38 拿下了), `204:34440` (N39), `204:34476` (N40), `204:34510` (N41); `207:2460` (N68).
- Issue: N22 is an icon in a blue circle, a headline, a four-row table and the player's own photo at 58 pt. N38 and N39 share one layout and differ by a green or red wireframe die; the roll total sits in a 14 pt sentence. N37, the peak of tension, is a 120 pt outline and the line 结果由服务器掷出，马上就到。 The lower 30–40% of each is empty. N39 uses a red die although its own note says "No shake, no red flood."
- Optimise: one moment layout: a stage (top 56%) with the object, a 28 pt headline, one sentence, at most three delta chips, one primary, one text link.
- Figma: new component `Player/Moment` (393×852): slot `Stage` (393×480), `Headline` `t-1` 28 Bold, `Line` `t-sub` 15 `ink-2`, `Chips` (auto-layout, gap 8, up to three `Player/Stat Tile`), `Primary` `Player/Button` 52, `Secondary` Text.
  - N22: Stage = `City/Deed Card` Full with the claim photo, a 96 pt seal 已圈下 overlapping the top-right corner at −8° (reuse the gold seal art of R6 `102:1047` A38); chips `−120 积分`, `保护到 明天 14:20`, `探索 +30`. Delete the table and the thumbnail row.
  - N36: add the odds bar of SR1-30 under the die.
  - N37: die at 240 pt, centred in the stage; replace the sentence with the chip `需要 ≥ 9`.
  - N38: Stage = the die resting on the Deed card, the band shown in my colour; total as `t-hero` 48 Heavy `17`, and under it `14 + 3` in `t-3` 20 with the modifiers as chips; chips `前哨 Lv1 → 插旗 Lv0`, `保护 24 小时`, `探索 +40`.
  - N39: grey die (`ink-3`), headline 这次没拿下, chips say what remains (`今天还可挑战 2 次`, `24 小时后可再来`); no red.
  - N40 and N41: Stage = Deed Row tipped 6° (lost) or with a shield badge (held); the compensation or gain as chips.

**SR1-26 · P1 · Pins say who owns a place by ring colour**
- Rule: HIG `accessibility.md`: "Convey information with more than color alone"; HIG `maps.md`: "Clearly identify elements that people select" and "Cluster overlapping points of interest"; reference 3.
- Nodes: `N1/地产图钉` `204:21680` (6 states, 142 instances on N1, 62 on P); `204:23260`.
- Issue: mine = filled blue, others = blue ring, protected = green ring, unlit = an orange "?" in one place and a green "?" in another. All pins are the same size whatever the level, and thin 1.5 pt glyphs carry the meaning.
- Optimise: shape for ownership, badge for condition, size for level, label on selection.
- Figma: restructure the set to `Owner` = Mine (filled, flag) / Other (outline, flag) / None (dashed, plus) / Unlit (hollow dot) × `Badge` = None / Shield / Hourglass (14 pt, top-right) × `Level` = 0 / 1 / 2 (36 / 44 / 52 pt) × `Selected` (scale 1.15, name label in `role/pin-label`, halo in `district/n-soft`). Add a `Cluster` variant with a count. Every variant sits in a 44×44 hit frame. One colour for "?" (`ink-3`).

**SR1-27 · P1 · A disabled button is used as a status line**
- Rule: `apple-design-interaction › state-and-feedback-logic.md › 4. Disabled States`: "Never just remove the opacity and leave no explanation"; HIG `feedback.md`: "Show people when a command can't be carried out and help them understand why"; HIG `buttons.md` (prominent style for the most likely action).
- Nodes: `204:23542` (N09 保护中，暂不能挑战), `204:27271` (N25 积分不足), `205:8786` (N50 不在现场，暂不能升级), `204:26790` (N19), `204:26924` (N21 校验中), `204:34369` (N37 掷骰中).
- Issue: the sheet's largest control is a grey pill that states a fact. On N25 both pills are grey, so nothing on the sheet looks tappable. On N09 the fact is also in the blue banner above.
- Optimise: facts go in the banner; the pill is the thing the player can do now.
- Figma: N09: delete the disabled pill; 保护结束时提醒我 becomes `Player/Button` Primary. N25: banner `还差 34 积分` (Warning), primary 看看怎么赚积分. N50: banner stays, primary 带我过去. N19, N21, N37: `Player/Button` State=Loading with the label kept (spinner + 校验中).

**SR1-28 · P1 · Type is sized for a mini-program, not for a street**
- Rule: HIG `typography.md`: default 17 pt, minimum 11 pt; HIG `designing-for-games.md`: "Make sure text is always legible"; `apple-design-foundations`: "Dynamic Type must reflow."
- Nodes: all of N1. Census: 1,967 text nodes; 14 pt ×451, 11 pt ×423, 12 pt ×179, 13 pt ×55; **57% are 14 pt or smaller and 21.5% are 11 pt**; 17 pt body is used 17 times; 28 distinct sizes including 12.67, 11.2, 15.83, 34.56 and 50.67; 652 nodes (33%) have no text style; the `MP/*` styles carry 1,268 nodes and the Dynamic Type styles `t-*` carry 27. The `Type` collection has four size modes (Large to xxxLarge) that these frames cannot use.
- Issue: the file owns an Apple-scale ramp with Dynamic Type modes, and the newest page does not use it. Captions that matter outdoors (rent, protection time, distances) are 11 pt.
- Optimise: nothing a player reads while walking is under 15 pt; 11 and 12 pt are for tags and pin labels only.
- Figma: one script on N1: `MP/body-strong` 14 → `t-callout` 16 Semibold (row titles); `MP/body` 14 → `t-sub` 15; `MP/caption` 11 → `t-foot` 13; `MP/label` 12 → `t-foot` 13 where it is a caption, `role/tag` where it is inside a tag; `MP/card-title` 16 → `t-head` 17; `MP/sheet-title` 22 → `t-2`; `MP/page-title` 29 → `t-1` 28; fractional sizes to the nearest style; every node bound to a style. Row min-height 52. Re-check the two XXL proofs (`302:30640`, `302:30701`) after the change.

**SR1-29 · P1 · Two text colours fail contrast**
- Rule: HIG `accessibility.md`: text up to 17 pt needs 4.5:1; `apple-design-tactics › accessibility-inclusive.md › Color & Contrast`.
- Nodes and numbers: N23 `204:27073`, N24 `204:27181` error lines, 11 pt `bad` on `sheet-inset`: **2.5:1 measured** (about 3.4:1 by token values); district and status tags, 11 pt `info` on `info-soft` (N08 `204:23400` and every sheet): **3.4:1 measured**. Passing, for the record: `ink-3` captions on the sheet 5.3:1, the 怎么算赢 paragraph 5.0:1, disabled labels 4.6:1.
- Figma: error lines → `ink` text at `t-foot` 13 with a leading 16 pt `Icon/alert` in `bad` (colour on the icon, not on the sentence). Tags → label in `ink` on the soft fill, or add `info-ink` (about #8FB6FF in the dark modes, 5.7:1 on `info-soft`) and use it for tag labels only.

**SR1-30 · P1 · The rule that decides a challenge is two 11 pt paragraphs**
- Rule: HIG `designing-for-games.md`: "Teach through play"; HIG `design-principles.md › Simplicity`: "Establish hierarchy."
- Nodes: `204:34263` (N34 怎么算赢), `204:34340` (N36).
- Issue: the odds are the decision, and they are prose. "难度 12 − 你的修正 3" must be worked out by the player.
- Optimise: show the target and the chance; put the full rules one tap away.
- Figma: new `City/Odds Bar`: line `需要掷出 ≥ 9` in `t-2` 22 Bold; a 20-segment bar, 12 segments filled (`ink`), 8 empty (`fill`), caption `20 面骰 · 12 个面能赢`; modifier chips `任务 +2`, `洞察 +1`. Replace the paragraph on N34 with it and an ⓘ that opens the rules sheet; repeat the same bar on N36 so the two screens read as one thought.

**SR1-31 · P1 · Blue means five things**
- Rule: HIG `color.md`: "Avoid using the same color to mean different things"; HIG `branding.md`: "Apply your app's accent color judiciously"; `apple-design` hub: "One accent color".
- Nodes: N07 `204:23260` (blue = mine), N08 `204:23400` (blue tag = 武康路街区), N28 `204:33843` (blue tag = 待入账), N64 `207:2026` and N68 `207:2460` (blue = 探索), N09 `204:23542` (blue banner = protected). `info` is the fill of 30 text nodes and `info-soft` of 37 boxes on N1.
- Optimise: three colour jobs, kept apart. **Me** = one hue (keep the blue, token `me`). **District** = `district/n`, only on the deed band, cells and district chip. **Status** = `ok` / `warn` / `bad`, only inside `Player/Status Tag` and banners. Everything else is ink.
- Figma: 待入账 → `Player/Status Tag` Neutral with a clock; the protection banner → Neutral fill with the shield glyph; attribute bars on N64 to N68 → `ink` (the attribute is named by its icon and label); district tags → `district/n-soft` fill.

**SR1-32 · P1 · The headline feature has no door on any tab root**
- Rule: HIG `design-principles.md › Purpose`: "Prioritize your app's most important features"; `apple-design-interaction › navigation-models.md › 2.5 Tab Bars` (peer top-level sections).
- Nodes: P tab roots `210:8239`, `210:8322`, `210:8374`, `210:8452`, `210:8603`; entry `204:32786`.
- Issue: none of the five roots shows City Monopoly. The layer chips 迷雾 | 领地 exist only on the pushed fog map.
- Optimise (default, see Q1): the 漫游 root map carries the 迷雾 | 领地 chips and the City stat pill; 首页 gains a rail 我的地盘 · 今天 +186 of Deed Mini cards.
- Figma: on `210:8322` add the two `MP/Chip`-style chips (as `Player/Chip`, SR1-36) under the header and link 领地 to N07; on `210:8239` insert the rail between 编辑精选 and 附近活动 (header `t-2`, three `City/Deed Card` Mini, trailing 全部 →  N01).

**SR1-33 · P1 · Five celebration styles**
- Rule: HIG `design-principles.md › Familiarity`: "Keep visuals and interactions consistent"; `apple-design-review › Lens 3` ("Is the boldness spent in one place?").
- Nodes: P `210:10045` and R6 A40, A41 (illustrated navy sky, gold shield); R6 A38, A39 (gold seal on black); N22, N38, N40 (flat icon or wireframe on black); N68 `207:2460` (blue glowing tile); P `204:15096` (six green ticks); share cards P `210:10082` and R6 A47 (a flat mustard tile where the shield was just earned).
- Issue: each win looks like a different product, and the share card does not show the badge the player won.
- Optimise: the `Badge/Art` language (`291:70467`: gloss, three shapes) is the best art in the file. Use it for every moment object.
- Figma: new set `Moment/Art` drawn in that style: Flag (claim), Die (challenge), Shield (defence), Coin (rent), Seal (stamp), Level (attribute). Share cards `210:10082` and A47: replace the mustard tile with the `Badge/Art` instance of the earned badge on the navy field of `210:10045`. N68 keeps its layout and swaps the glowing tile for `Moment/Art` Level.

**SR1-34 · P2 · Live Activity: a red ✕ in the island, a generic minimal view**
- Rule: HIG `live-activities.md`: "Focus on simple, direct actions… Only include interactive elements for essential functionality"; "Ensure that your Live Activity is recognizable in the minimal presentation. If possible, display updated information rather than just a logo"; "Use large, heavier-weight text — a medium weight or higher."
- Nodes: `208:2281` (N77), `208:2311` (N78), `208:2414` (N81), `208:2153` (N74).
- Issue: ending a walk is one tap on a small red ✕ beside pause; the minimal view is a pulse glyph that could be any fitness app; roam is teal and play is yellow, so the two do not read as one app; stat captions are 11 pt Regular.
- Figma: N77: keep pause, remove ✕ (ending happens in the app, Q7). N78 and N81: a 22 pt progress ring with the app mark inside. One accent for both (`route`). Captions → 12 Medium.

**SR1-35 · P2 · Small ones on N1**
- N35 `204:34304`: the 42-second limit is 13 pt in a corner → a 2 pt progress line under the nav row, time in `role/stat`. Rule: HIG `feedback.md` (status near what it describes).
- N67 `207:2311`: "•••" is at the leading edge and the title 主页 is centred → More goes trailing, as on every other header. Rule: HIG `branding.md` ("Place UI in expected locations").
- N90 and N91: see SR1-04.
- R6 A46 (in `102:1047`): the 带上路线 switch is green; the owner ruled a neutral tint (Q3 of verify-r1). Swap to the neutral switch.

### 2.6 · Library and kit (`6:2`, `6:3`, `6:4`, Player/*, Club/*, Merchant/*, Editor/*)

**SR1-36 · P0 · The page that will be coded first is not built from the kit**
- Rule: HIG `design-principles.md › Familiarity`; `apple-design-review › Working rules` ("Review the flow, not just the screen"). Extends verify-r1 F-11 with counts.
- Nodes and numbers: N1 instances: `MP/Button` 93, `MP/Tag` 67, `MP/Chip` 56, `R6/Status Bar` 96, against `Player/Button` 6. P: `MP/Button` 54, `MP/Nav Bar` 35, `MP/Tag` 32, `MP/Chip` 25, against `Player/Button` 41. The Library holds five button systems (`Button` `13:281` 48 variants, `Player/Button` `285:20238`, `Merchant/Button` `316:4734`, `MP/Button`, and buttons drawn inside `Editor/Bottom Bar`), four sheets, four toasts, five state blocks, four status tags and three switches. LOG row 82 records why the swap stopped: "the player kit has no filter chip or pushed nav".
- Issue: the Player kit was derived from N1, but N1 never adopted it. An engineer building N1 from Figma will find mini-program components.
- Optimise: finish the Player kit, swap N1 and P onto it, retire the base duplicates.
- Figma: add `Player/Chip` (Choice / Filter × Default / Selected, 36 high, 44 hit, r pill) and `Player/Nav Bar` (Back / Close × title None / Inline × trailing None / One / Two) to `285:20181`. Script on N1 and P: `MP/Button` → `Player/Button` (Primary / Secondary by fill, 52 when wider than 280), `MP/Chip` → `Player/Chip`, `MP/Tag` → `Player/Status Tag` when it carries a status and a plain neutral tag otherwise (check labels first: round 2b found 58 of 154 candidates were not buttons), `MP/Nav Bar` → `Player/Nav Bar`. Move the base `Button`, `Sheet`, `Toast`, `Tag`, `Switch`, `State Block` into a section named `Deprecated · 不再使用` with a one-line description pointing to the role kit.

**SR1-37 · P1 · Spacing and radius tokens exist and nothing uses them**
- Rule: `apple-design-foundations › layout-grid-spacing.md › The 8pt spacing system` (8 base, 4 half-step, 2 optical only); HIG `design-principles.md › Craft`.
- Numbers: gaps bound to `Spacing` variables: Editor 0 of 263, Player 0 of 105, Club 0 of 116, Merchant 0 of 63. Radii bound to `Radius`: Editor 53 of 234, Merchant 50 of 71, Player 0 of 122, Club 0 of 103. N1 uses 19 radii (20, 999, 16, 12, 14, 2, 3, 18, 28, 8, 9, 25, 6, 4, 5, 19, 24, 22, 48) against 6 tokens, and gaps of 6 (121 times), 10 (37), 27 (24), 14, 7, 11, 5.
- Figma: fix the scale first: radius 8 / 12 / 16 / 20 / 28 / pill (`r-xs` to `r-pill`; add 28 if `r-xl` is not 28). Script per kit section, then per page: radius 9, 10 → 8 or 12 by size; 14 → 12 (controls) or 16 (cards); 18, 19, 22 → 20; 24, 25 → 28; gaps 5, 6, 7 → 8 (4 inside tags); 10, 11 → 12; 14 → 16; 27 → 24. Then bind `itemSpacing`, paddings and corner radii to the variables. Screenshot each kit section after.

**SR1-38 · P1 · Glass is a fill colour**
- Rule: `apple-design-materials` core rule: "Glass is a layer, not a paint. It samples + blurs what's behind"; `apple-design-review › hig/liquid-glass.md › Review checklist 1, 5`.
- Numbers: on N1 the `glass` variable fills 129 boxes and exactly one node has a background blur. The Library has three blur styles (`material/glass-20`, `material/tab-24`, `material/alert-30`) and no Liquid Glass effect.
- Issue: the top pills, glass circles and tab bar over the map are flat translucent grey. On a busy map they read as stickers, and the build has no material to copy.
- Figma: apply Figma's Glass effect (or `material/glass-20` where Glass is unavailable) to `Player/Top Pill` `287:521`, the glass circle buttons, the tab bars and `Player/Toast`; never to cards or sheets' content. Add a boolean `Reduce Transparency` to those components that swaps the fill to opaque `surface-2`. Replace N1's local pills with the kit instances so the effect arrives everywhere.

**SR1-39 · P1 · Four tab bars**
- Rule: HIG `tab-bars.md`; HIG `design-principles.md › Familiarity`. Extends the PL-01 work.
- Nodes: `OPT/Tab Bar (labelled)` `174:3515` (floating capsule, used on P and N1 N67); Library `Tab Bar / Player` `12:129` (393×83, the published one); C3 `243:1964` (flat bar, outline icons, a yellow ⊕ for 发布, a centred bell above); `Merchant/Tab Bar` `319:8299` and Library `Tab Bar / Merchant` `12:256`.
- Figma: one `Tab Bar` set in the Library with `Role` = Player / Merchant × `Selected` 1–5, drawn as the floating capsule with the glass of SR1-38. Move `174:3515`'s drawing into `12:129` (so the published name stays) and re-point instances; swap the bar on `243:1964` and scan C3 for others.

**SR1-40 · P1 · Three icon sets with duplicates and one thin weight**
- Rule: HIG `icons.md`: "all interface icons in your app need to use a consistent size, level of detail, stroke thickness (or weight)" and "match the weights of interface icons and adjacent text"; `apple-design-materials › iconography-sf-symbols.md › 5.2 Mismatched symbol weight vs. text weight`.
- Numbers: Library `Icon/*` 55; N1 local `N1/Icon/*` 46; page-local `icon/*`. N1 mixes them in the same frames: `N1/Icon/chev-l` 49 and `Icon/back` 7; `N1/Icon/x` 32 and `Icon/x`. All are about 1.5 pt outlines beside Semibold and Bold labels.
- Figma: merge `N1/Icon/*` into the Library set (keep one of each: chev, x, more, check, clock, lock, info, star, plus, chat, camera, store), add property `Weight` = Regular (1.5 pt) / Semibold (2 pt), put the SF Symbol name in each description, and add filled variants for the five tab icons. Re-point instances by name.

**SR1-41 · P2 · Three status-tag anatomies**
- Numbers: `Player/Status Tag` 22 high, 11 pt Regular; `Merchant/Status Tag` 22 high, 11 pt Semibold; `Tag` r6, 12 pt Semibold.
- Rule: HIG `typography.md` ("avoid light font weights" for small text); Familiarity.
- Figma: one anatomy for both roles: 24 high, `role/tag` 12 Semibold, 12 pt glyph, padding 8, r pill; colours stay per role.

**SR1-42 · P2 · Two button shapes in the light theme**
- Rule: HIG `design-principles.md › Familiarity`. Owner question Q4.
- Nodes: `Merchant/Button` `316:4734` (r12, 46, Bold 16) and the editor's bottom-bar buttons (`Editor/Bottom Bar` `280:593`: capsule, Semibold 16), for example R4 `182:7693` against C3 `237:59431`.
- Issue: a merchant who publishes an activity moves from square-cornered to capsule buttons inside one light theme.
- Figma (round 1, no visual change): add a FLOAT variable `button-radius` to a per-role collection (Player 999, Merchant 12, Editor 999) and bind the three button components to it, so the owner's answer is one value change in round 2.

### 2.7 · Prototype and motion (P `204:9667`, flows on C1–C3, R4)

**SR1-43 · P0 · The notes say spring; the prototype plays ease-out**
- Rule: `apple-design-motion` core rule: "Springs over fixed easing"; `motion-animation.md` timing table (sheet 300–400 ms spring smooth; push 350–450 ms spring smooth; chip or toggle 200–300 ms spring snappy); HIG `motion.md`: "Strive for realistic feedback motion that follows people's gestures and expectations."
- Numbers: P has 313 nodes with reactions. Easing: `EASE_OUT` 208, `CUSTOM_SPRING` 5, `LINEAR` 2. Durations: 300 ms ×91, 150 ×48, 200 ×23, 140 ×21. C1: 225 reaction nodes, `EASE_OUT` 209, spring 4. C2: spring 2 of 19. Only R4 is half spring (10 of 21).
- Issue: every frame carries an Interaction note asking for `spring(response .38, damping .86)`, and the thing the owner can actually play does something else. The feel cannot be approved from this prototype.
- Figma: one script per page that rewrites `transition.easing` by role, using Figma's custom spring (mass 1):

  | Use | SwiftUI spec | Figma spring (stiffness, damping) | Duration shown |
  |---|---|---|---|
  | Sheet in, detent change | response .38, damping .86 | 273, 28.4 | about 350 ms |
  | Push, pop | response .45, damping .86 | 195, 24.0 | about 400 ms |
  | Press, chip, segment | response .30, damping .80 | 439, 33.5 | about 250 ms |
  | Result card rise | response .42, damping .80 | 224, 23.9 | about 400 ms |
  | Moment (flag plant, die land) | response .40, damping .55 | 247, 17.3 | about 600 ms |

  Rule for the script: `PUSH` and `BACK` → push spring; `MOVE_IN` and sheet dissolves → sheet spring; `SMART_ANIMATE` on a component variant → press spring; frames named N22·, N37·, N68·, cok-, roll- → moment spring. `BACK` currently has no transition (98 instant): give it the push spring.

**SR1-44 · P0 · Sheets are frame swaps: nothing rises, nothing can be dragged**
- Rule: HIG `sheets` via `apple-design-review › Lens 2` ("a grabber when resizable, swipe to dismiss"); `apple-design-motion` core rule: "Interruptible + velocity handoff"; `apple-design-interaction › navigation-models.md › 2.2 Sheets + Detents`.
- Numbers: actions on P: `NAVIGATE` 209, `BACK` 98, `CHANGE_TO` 6; **overlay actions 0; drag triggers 0** (`ON_CLICK` 303, `ON_PRESS` 2, timeouts 8). Transitions: `DISSOLVE` 95, `MOVE_IN` 6.
- Issue: a sheet "opens" by cross-fading to another whole frame that contains a dimmed copy of the page. The grabber does nothing. The detent table of the earlier reviews exists only as notes.
- Figma: for the thirteen sheets on the main paths, split the sheet from its base and present it as an overlay: action `OPEN_OVERLAY`, position bottom-centre, background `scrim` 40%, close on outside tap, `MOVE_IN` from bottom with the sheet spring; add `ON_DRAG` on the grabber → close overlay (and Fit ⇄ Large via `Player/Sheet` variant swap where the table gives two detents). The thirteen: 选择票种 `210:8892`, 提示 `210:9344`, 队伍聊天 `210:11017`, 地产卡 `204:32959` and `204:33244`, 圈地确认 `204:33032`, 校验 `204:33109`, 挑战确认 `207:6715`, 附近 `210:10410`, 街区频道入口 `210:11140`, 登录 `204:21385`, 俱乐部已创建 `345:3309`, 俱乐部欢迎 `204:15551`. Map sheets get no scrim (the map stays live). I did not render `210:11140`, `204:21385`, `345:3309` or `204:15551`; they are on this list from the earlier detent table and LOG, so the executor should confirm each is a sheet before converting it.

**SR1-45 · P1 · Only 13 of 111 prototype frames scroll**
- Rule: `apple-design-review › hig/liquid-glass.md › checklist 6`; HIG `scroll-views` idea via `apple-design-interaction` (scroll is an input).
- Numbers: overflow `VERTICAL` 13, `NONE` 98; frames with fixed layers 9; 105 frames are exactly 852 high.
- Issue: most screens are one-screen crops. Bars are not fixed, so the behaviour under the tab bar (SR1-03) and the collapse of large titles cannot be tried.
- Figma: on the five tab roots, 活动详情 `210:8708`, 主题详情 `210:9137`, 我的 `210:8603`, CITY home `204:32786`, 赛季榜 `207:6432`: extend the content to its full height (take it from the R1 "full" twins), set overflow vertical, mark the tab bar, sticky bar and header as fixed, and add `Chrome/Scroll Edge`.

**SR1-46 · P1 · Moments have one or two in-between frames and no gesture**
- Rule: `apple-design-motion › gestures-interaction.md › Direct Manipulation`, `Velocity Handoff into Springs`; HIG `motion.md`: "Aim for brevity and precision in feedback animations"; reference 2.
- Nodes: N22·a `298:2524`, N22·b `298:2564`, N37·a `298:2604`, N68·a `298:2634`; P `298:23194`, `298:23226`, `298:23258`; hold-to-start `289:2804`, R6 `301:3116`, `301:3180`.
- Issue: each moment is specified in a paragraph and shown in one or two stills chained by timers (8 `AFTER_TIMEOUT` on P). The hold to start has two `ON_PRESS` reactions in the whole file. The die cannot be thrown.
- Figma: a five-frame strip per moment (anticipation, action, impact, settle, result) in a section `Moments · 分镜` on N1, wired `AFTER_TIMEOUT` + Smart Animate with the moment spring, and a tap anywhere that jumps to the result ("Let people cancel motion", HIG `motion.md`). Strips: 圈下了, 掷骰 (win and lose endings), 被抢, 收租入账, 升级. Hold to start: `ON_PRESS` (mouse down) → ring fill 0 → 100% Smart Animate 800 ms linear → `AFTER_TIMEOUT` 0.8 s → play; mouse up before that → back to rest with the press spring. Die: `ON_DRAG` on the die → rolling; the 掷骰 button remains as the second way.

**SR1-47 · P1 · No motion or haptic tokens; the spec lives in about 1,000 frame notes**
- Rule: HIG `playing-haptics.md`: "build a clear, causal relationship between each haptic and the action that causes it"; `apple-design-motion › microinteractions-feedback.md › Restraint` (no double-firing); references 1, 9.
- Numbers: 156 variables in four collections (Color 78, Spacing 35, Radius 14, Type 29) and none for duration, spring or haptic. Round 2 put an Interaction annotation on 994 frames (P 110, R1 183, R2 171, R3 267, R6 161, N1 102). On N1 most repeat the same four lines ("Press… scale .97, 80 ms"). `.success` is assigned to claim, win, level-up, new district and the result card; `.warning` to both a lost roll and a lost place.
- Figma: (a) new collection `Motion` (FLOAT): `duration/press` 80, `duration/quick` 250, `duration/sheet` 350, `duration/push` 400, `duration/moment` 600, and `spring/sheet-response` .38, `spring/sheet-damping` .86 and the other four pairs of SR1-43. (b) A board `Motion & Haptics · 动效与触感` on Library `6:4` with the spring table and this haptic map, one row per verb:

  | Verb | Haptic | Sound pairing |
  |---|---|---|
  | Fog cell lights | impact light, at most one per 2 s | none |
  | Claim check passes (each row) | selection | soft tick |
  | Claim check fails | notification error | none |
  | Flag plants | impact heavy at contact | low thud |
  | Claim confirmed | notification success, 150 ms after the plant | none |
  | Die rolling | impact light every 120 ms, intensity rising | rattle |
  | Die lands | impact rigid | click |
  | Roll won | custom: two rising taps | short rise |
  | Roll lost | impact soft, single | none |
  | Rent arrives | impact soft | coin |
  | Place taken from me | notification warning | none |
  | Sheet settles on a detent | selection | none |

  (c) Shorten the frame notes to the token and verb names. VoiceOver speaks every result (HIG `accessibility.md`: "Use haptics in addition to audio cues").

**SR1-48 · P2 · 19 prototype hotspots under 44 pt**
- Rule: HIG `accessibility.md`: 44×44 pt default control size.
- Nodes (P census): `back` 24×24 ×4, `← 返回` 32×32 ×2, `segment-1/2/3` 119×30 ×6, `→ create1` 90×34, `→ wfilter` 79×28, `→ attrs` 329×22, `→ titles` 119×21, `→ lockplay` 200×40 ×2, `→ cboard` 230×40. N1 has 5 more (segments 119×30, three 42-high buttons).
- Figma: wrap each in a 44-high transparent hit frame and move the reaction to it, as round 2 did for the editor links.

**SR1-49 · P2 · The moments have no Reduce Motion or XXL proof**
- Rule: HIG `motion.md`: "Make motion optional"; `apple-design-tactics › accessibility-inclusive.md › Reduce Motion`, `Dynamic Type`; reference 4.
- Nodes: N1 has three proofs (`302:30701`, `302:30640`, `207:2683`); none for N22, N37–N39, N68.
- Figma: for each moment strip of SR1-46 add one frame `· Reduce Motion` (the result with a cross-fade note and the haptic kept) and one `· XXL` (headline wraps to two lines, chips stack).

**SR1-50 · P2 · Loose ends in the flows**
- Nodes: `210:9379` (playerr) and `289:2730` (lobby-ready) are reached by no link; the create-club flow starts at `345:2990` under the name "Flow 1"; R3 has no reactions at all (club flows exist only on P).
- Figma: link lobby `204:15032` → `289:2730` → `289:2804`; link play `289:2596` → `210:9379` from a 断网 hotspot note; rename "Flow 1" to `11 俱乐部 · 创建`.

---

## 3 · Batched plan for the Opus Figma executor (about 120 calls, highest impact first)

Rules for the run: write the scripts offline first (as round 2 did), one page switch per call, a dry run for any script that matches by name or fill, an inline screenshot inside the same call for anything visual, and a log row per call. Budget below includes fixes.

| Batch | What | Findings | Pages | Calls |
|---|---|---|---|---|
| **1 · Foundations in the Library** | `district/*` colour variables and `Motion` collection; `City/Deed Card`; `Map/Base` (rebuild `204:21627`) and `Map/Legend`; pin set; `Player/Moment`, `Moment/Art`, `City/Odds Bar`; `Player/Chip`, `Player/Nav Bar`; `Chrome/Scroll Edge`; `Media/Cover` and `Club/Default Cover`; one `Tab Bar` set; `System/Alert`; Motion & Haptics board; `button-radius` variable | SR1-22, 24, 26, 25, 30, 36, 03, 04, 08, 39, 20, 47, 42 | Library `6:3`, `6:4`, N1 local components `204:7912` | 22 |
| **2 · N1: City Monopoly** | N01 rebuild; N08–N12 sheets on the deed; N18–N25 claim (disabled pills, error text); N22, N36–N41, N68 on `Player/Moment`; N28 and N46 rows; colour roles; Live Activity; small ones; then the kit swap script and the type remap script, each with a dry run | SR1-23, 22, 27, 29, 25, 30, 31, 33, 34, 35, 36, 28 | N1 | 30 |
| **3 · Prototype** | Fix the 漫游 rows; City rail and layer chips on the roots; re-clone the changed N1 frames into P section 4; 13 sheets as overlays with drag; scroll and fixed layers on 10 frames; the spring script on P; hold-to-start and die gestures; five moment strips with Reduce Motion and XXL frames; 44 pt hotspots; loose ends | SR1-01, 32, 44, 45, 43, 46, 49, 48, 50, 05, 02 | P, N1 (strips) | 30 |
| **4 · Player, club, merchant, editor screens** | Covers swapped in; play HUD; 战报; 发布 root; club 概览 and workbench; merchant workbench, quick actions, chevrons, 营销 metric, root headers; editor blank pill, sub-11 pt script, 主题详情 icons, preview art, segmented; tab bar on C3 | SR1-04, 02, 06, 07, 08, 09, 10, 11–15, 16–21, 39 | P, R3, R4, C1, C2, C3, R2 | 24 |
| **5 · Tokens, materials, proof** | Radius and gap snap-and-bind scripts (four kits, then N1 and P); Glass effect and Reduce Transparency on the chrome components; icon merge; status-tag anatomy; spring script on C1–C3 and R4; re-run this review's census on N1, P and the kits; final screenshots of the 20 key frames | SR1-37, 38, 40, 41, 43 | Library, N1, P, C1–C3, R4 | 14 |
| | | | **Total** | **120** |

Order inside batch 1 matters: variables → Deed, Map, Pin → Moment → the rest. Batch 2 must not start before the Deed and Map components exist. If the day's shared cap is short, stop after batch 3: batches 1 to 3 carry all eight P0 items.

Done means, per batch: the census numbers move. Targets for the round-2 review: N1 text ≤ 14 pt under 20% (now 57%), unstyled text 0 (now 652), `MP/*` instances on N1 and P 0 (now 216 and 146), spring share of timed transitions on P above 90% (now 2%), overlay actions on P ≥ 12 (now 0), drag triggers ≥ 14 (now 0), gaps bound to variables in the kits above 90% (now 0%), tab bar components 1 (now 4).

---

## 4 · Owner questions (the plan proceeds on the default)

| # | Question | Default |
|---|---|---|
| Q1 | Where does City Monopoly enter the app? | The 漫游 root map gets the 迷雾 / 领地 layer chips, and 首页 gets a 我的地盘 rail. No sixth tab. |
| Q2 | May the game introduce six district colours (the Monopoly colour groups)? | Yes, used only on the deed band, map cells and the district chip. Everything else stays monochrome. |
| Q3 | Whose photo is on a deed? | The holder's claim photo; the merchant's storefront photo when the place is a partner shop; the outline card when unlit. |
| Q4 | Light-theme buttons: merchant r12 and editor capsule, or one shape? | No visual change in round 1; the shape becomes one variable so round 2 can switch it. My recommendation is capsule for both, matching iOS 26 controls. |
| Q5 | Rename the 发布 tab to 创作? | Keep 发布; change only what the root shows first (the last draft). |
| Q6 | Throw the die with a flick, with the 掷骰 button as the fallback? | Yes. |
| Q7 | Remove the end (✕) button from the Dynamic Island and keep only pause? | Yes; ending a walk happens in the app. |
| Q8 | The level-up and celebration art: adopt the `Badge/Art` style for all moments? | Yes. |
| Q9 | Widgets for City Monopoly (today's rent, shields about to end)? | Not in round 1; propose in round 2 once the deed exists. |
| Q10 | May the executor replace the stock café photos and grey placeholders with the place photos already in the file? | Yes; no stock photos of people. |

---

## Severity count

| Area | P0 | P1 | P2 | Total |
|---|---|---|---|---|
| Player | 1 | 4 | 2 | 7 |
| Club | 0 | 2 | 1 | 3 |
| Merchant | 0 | 1 | 4 | 5 |
| Editor | 0 | 2 | 4 | 6 |
| City Monopoly N1 | 4 | 8 | 2 | 14 |
| Library and kit | 1 | 4 | 2 | 7 |
| Prototype and motion | 2 | 3 | 3 | 8 |
| **Total** | **8** | **24** | **18** | **50** |

## What works (keep through round 2)

- The sheet anatomy on N1 (grabber, title left, round ✕, banner, one table, one pill) and the four claim checks of N18 to N21.
- `Badge/Art` and the 收集册 page `204:30158`: the best art in the file.
- The floating capsule tab bar on the P roots.
- The club create wizard `204:24591` and the merchant onboarding review `182:7693`.
- The editor's collapsed-card outline `237:43689` and the publish-blockers sheet `249:16773`.
- The hold-to-talk ring `358:9915`: the one control in the file that already shows its gesture.
- State coverage: every N1 section has loading, empty, error and permission frames.
