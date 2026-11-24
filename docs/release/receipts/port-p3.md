# Receipt · port P3 · route detail (topic)

- **Branch:** `port/p3-route-detail`, base `origin/ui/combined-r6` (`f1115875e`).
- **Worker:** Claude cloud (scheduled run, 2026-11-24). No Swift compiler in the cloud: parse-checked only (see Verification).
- **Plan:** `port/plan-r1:docs/port/ios-port-plan.md` §2.2 C9 + C13, §3, §4 P3. Shared brief `design/handoff-r2:docs/briefs/port-packages-r1.md`.
- **Sources:** chengyin-ios `f815bf30` (#157 chapter cards) and `fd2bdc49` (#166 player 1121: 出发前, 0/empty hiding, reviews). Behaviour re-checked against the MP (`hengyin` `7c56d722`, `chengyinhub-xcx/pages/topic/index/index.{wxml,js}`, `utils/chapter-cards.js`, `utils/depart-notes.js`, `utils/topic-motion.js buyOptions`).

## Clusters done
| Cluster | Item | Status |
|---|---|---|
| C9 | Chapter cards 「节点介绍」: one card per chapter, sorted by `sortId`, first chapter image → route cover → placeholder, 含 N 个玩法 · 约 M 分钟 (each part hidden when unknown), ending chapters (名以「结局」开头, or 0 games and 0 time) never get a card, expand in place, one open at a time, `CYMotion.standard` spring, instant under Reduce Motion | done |
| C9 | **`totalTime` seconds fix**: `TopicChapter.totalTimeMinutes` (read seconds as minutes → 60× too large) renamed to `totalTimeSeconds`; the 章节 row and cards show `TopicChapterCards.minutes` (round, min 1; 0/missing → sum of the games' minutes; else hidden) | done |
| C9 | The old per-template 「节点介绍」 shelf (`TopicXcxTemplatesSection`) is replaced by the chapter cards, as in the MP (`chapter-cards.js` header comment) | done |
| C13 | 「活动内容」 keeps only the story (`TopicDepartNotes.split`); practical lines go to 出发前 | done |
| C13 | 「出发前」: self-play pass price, session tickets (only when the route has sessions; same-name tickets fold to the lowest 「起」 price; 「N 人同玩一张票」 when `teamSize`/`maxPeople` ≥ 2), 含 章节/站点/玩法/语音导览, 中途可暂停 (not free exploration), finish medal (name → 「路线名 · 通关」 → unnamed copy), coupon, practical notes | done |
| C13 | 0/empty hiding: 商家数 0 and 总时长 0 rows hidden; chapter 站点 row hidden when the chapter has no visible stops; chapter duration hidden when unknown | done |
| C13 | Reviews: no 「0」 total (the empty line says it once), no 「评价预览 · 最多显示 5 条」 small print, no 积分 small print (`activity.reviewPointsNote`) under the topic reviews, no duplicate 「还没有评价」 title above the empty line | done |
| C8 hook | `TopicCastRow` mount from P1 | **placeholder only** (see Mount hooks) |

## Files
**Copied (chengyin-ios `origin/main` a5c863e), then adapted**
- `Core/TopicChapterCards.swift`: verbatim + provenance comment.
- `Core/TopicDepartNotes.swift`: `split` verbatim (matches MP `splitDescription` line for line). `items(for:)` rewritten to the MP rules: `buyOptions` (tickets only with `activityList`, 起 folding, `teamSize`/`maxPeople`), `TopicXcxFacts.includes` for the 含 line (same chapter/ending counting as the rest of our page), medal fallback chain from `finishMedalName`/`finishMedalImg`. `Item.price` gains `from:`; `Item.includes` now carries `[TopicXcxFacts.Include]`; `Item` is `Equatable` (not `Hashable`).
- `App/TopicChapterCardsSection.swift`: re-skinned for the native iOS rule (`.cyText` Dynamic Type tokens, 12 pt card radius, `CYCachedAsyncImage`, `.cyPressable`, `CYMotion`, `accessibilityReduceMotion`). Section title reuses our `topicXcx.section.nodeIntro` (节点介绍).
- `Tests/CoreTests/TopicChapterCardsTests.swift`: verbatim.
- `Tests/CoreTests/TopicDepartNotesTests.swift`: split tests verbatim; the items test adapted to the MP rules above; one new test (tickets without sessions, medal image fallback).

**Adapted (hand re-implementation on our code)**
- `Core/TopicContracts.swift`: `TopicChapter` `totalTimeSeconds`, `imageSources` (`imgArr` as array, JSON string or list), `templateCount`, `sortID`; `TopicTicket.teamSize`.
- `App/TopicDetailView.swift`: chapter cards mount, `TopicCastRow` placeholder, story-only 活动内容, `TopicDepartSection` mount, zero-fact hiding, review section clean-up, chapter rows use `TopicChapterCards.minutes`.
- `App/TopicXcxSections.swift`: new `TopicDepartSection`; removed the now-unused `TopicXcxTemplatesSection` and `TopicXcxIncludes`.
- `App/TopicReviewsContent.swift`: no 0 total, no preview small print, `.monospacedDigit()` on numbers.

**Touched outside the P3 list (minimal, needed by the changes above; please keep on merge)**
- `Tests/CoreTests/TopicTests.swift` (1 assertion): `totalTimeMinutes == 90` → `totalTimeSeconds == 90` and `minutes == 2`.
- `Tests/ContractChecks/test_w2_07_topic_parity.py` (1 pin): `TopicXcxTemplatesSection(...)` → `TopicChapterCardsSection(...)`.
- `Tests/ContractChecks/test_activity_topic_accessible_summaries.py` (1 pin): the `评价总数、0` label pin → the empty line + "no count row" assertions.
- `Tests/AppUITests/TopicFlowTests.swift` (`testKnownEmptyTopicReviewsUseChineseEmptyStateWithoutZeroStars`): asserts the 0 total is absent instead of 「评价总数、0」.
- `App/TopicFixtureSupport.swift` (DEBUG only): scenarios `routeDetail` / `routeDetailSparse` + `TopicP3Fixtures` for the acceptance screenshots. Synthetic, no `https://`, no coordinates.

## New types and call sites (compile order for the local integrator)
1. Core: `TopicChapterCard`, `TopicChapterCards` (pure). `TopicContracts.swift` calls `TopicChapterCards.imageList` in `TopicChapter.init(from:)`.
2. Core: `TopicDepartNotes` (+ `Item`, `Split`); depends on `TopicDetail`, `TopicXcxFacts.includes`.
3. App: `TopicChapterCardsSection`, `TopicChapterCardView` (uses `CYCachedAsyncImage`, `CYMotion.standard`, `.cyPressable`, `CYRadius.md`, `CYSpacing`).
4. App: `TopicDepartSection` in `TopicXcxSections.swift` (uses `appLocalized`, `topicXcx.include.*` keys).
5. Call sites: `TopicDetailView.content(_:)` mounts `TopicChapterCardsSection` and `TopicDepartSection`; chapter rows call `TopicChapterCards.minutes`.
- Removed symbol: `TopicChapter.totalTimeMinutes` (only users were `TopicDetailView` and `TopicTests`, both updated). Removed views: `TopicXcxTemplatesSection`, `TopicXcxIncludes` (no other users; `TopicXcxFacts.nodeTemplates` stays for `MerchantContentViews`).

## Tests ported
- `TopicChapterCardsTests` (4 tests: picture fallback, minute rounding + template fallback, ending exclusion + `sortId` order, toggle).
- `TopicDepartNotesTests` (5 tests: story/notes split, empty/`null`, MP items, tickets without sessions + medal fallback, free exploration with nothing known).
- `TopicTests.testNestedDetailPreservesOrderAndUnknownAmounts` updated for seconds.

## Mount hooks
- **Needed from P1:** `TopicCastRow`. Placeholder comment in `App/TopicDetailView.swift` right above `TopicChapterCardsSection(...)` (chengyin-ios puts 人物 before the cards). P3's final wiring commit replaces it once P1 merges, e.g. `if let cast = value.castConfig, !cast.cast.isEmpty { Section("topic.cast") { TopicCastRow(config: cast) } }`. That needs P1 to add `castConfig` to `TopicDetail`, or to expose the decode as an extension; `Core/TopicContracts.swift` is P3's, so P1 should send the field and P3 adds it in the wiring commit.
- **Provided:** none.

## Route rows for P2
- None. P3 adds no endpoint; everything reads the existing `GET` topic detail snapshot.

## Strings
- `docs/port/strings/p3.json` (14 keys, en + zh-Hans): `topic.depart*`, `topic.chapterCard.*`. Reused existing keys: `topicXcx.section.nodeIntro`, `topicXcx.section.contents`, `topicXcx.include.*`.
- No longer referenced on route detail (left in the catalog for the integrator): `topic.reviews.previewHint` (still in the catalog test list), `topicXcx.templateMinutes`; `activity.reviewPointsNote` is still used by activity detail.

## P5 money call site
- `TopicDepartSection` formats prices with `.currency(code: "CNY").precision(.fractionLength(0...2))` (same as the existing paywall price). Switch it to P5's `MoneyDisplay` when P5 lands.

## Verification (cloud, no compiler)
- `tools/check_swift_syntax.py` (tree-sitter 0.26.0 / swift 0.7.3) on all 12 touched Swift files: PASS, 0 recovery nodes.
- `tools/check_typography_lint.py`: PASS (raw text style 1143, no increase).
- Contract modules that read P3 files (`test_w2_07_topic_parity`, `test_topic_reviews`, `test_route_total_count`, `test_topic_chapter_itinerary`, `test_signed_in_content_details`, `test_ugc_*`, `test_global_chrome_domain_contract`, `test_contextual_selfplay_payment`, `test_topic_session_selection`): OK.
- `tools/contract_ratchet.py --check` (full suite, final tree): 186 failing vs baseline 184 → 2 new, both explained here. Expected, by rule S: `test_localization_key_catalog_contract...test_no_looked_up_key_is_missing_from_every_catalog` fails until `p3.json` is merged into `Localizable.xcstrings` (7 looked-up keys). With `p3.json` merged into a scratch copy, the audit reports 0 missing keys. `test_workshop_paid_professional...bounded_paging` also fails on the untouched base (the r6 "185 vs 184").
- Core `swift test` / AppUnit / UI tests: **not run** (no toolchain in the cloud).

## Acceptance
- `.github/workflows/acceptance.yml` did **not** exist on any branch when this was pushed (2026-11-24), so the handbook §4 loop could not run. Screens to capture: `docs/port/accept/p3.txt` (7 lines; launch-argument format, adjust to the workflow's format when it lands).
- Run URL / gate counts / screenshots: **pending** the workflow.
- MP functions checked (by reading the MP page and our code):
  - present: 节点介绍 chapter cards (image fallback, meta, endings hidden, sortId order, tap to expand, `aria-expanded` → accessibility value); 活动内容 story only; 出发前 (prices, 起, 同票人数, 含…, 暂停续玩, 勋章, 优惠券, practical notes); zero/empty hiding; reviews without small print or 0 total.
  - missing / differs: seat products in 出发前 (MP `seatProductOptions` from `_loadSeatProducts`, multi-person tickets, hengyin #912) — not loaded on our route detail; belongs to the archived `biz/seats-parity-1124` work (P5/commerce). Hero brief falls back to the story in the MP (`subtitle || storyText`); ours still shows `coverHint` when there is no subtitle (left as is, not in C13). The MP review header reads 「基于 N 条评论」; ours keeps 「评价总数 N」 (unchanged copy). Chapter-card images resolve only through `CYCachedAsyncImage` (no MP `/images/route_city_cover.png` asset); the placeholder tone shows instead.

## Could not do
- Compile or run Swift tests (no toolchain). The integrator compiles; the type list above gives the order.
- Acceptance run (workflow missing). The P3 receipt needs the run URL, gate counts and screenshots added when it exists.
- `TopicCastRow` wiring (waits for P1).
- Slack `#chengyin-rc` start/finish lines: this cloud run has no Slack access.
