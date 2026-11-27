# en-layout r3 — receipt

Lane **en-layout**, branch `i18n/r3-en-layout` (from `origin/ui/combined-r7`). Brief: `origin/design/handoff-r2:docs/briefs/round3-1127.md` (Lane areas row: every player screen in English for the US launch — untranslated text, truncation, wrapping, plural/number/date/currency formats, "Chein" brand, long English at large Dynamic Type). OWNER RULE / OWNER RULE 2: string and layout fixes only; no MP section is added, dropped or reordered, no navigation chrome changes.

No Swift compiler in the cloud: fixes are catalog values and stock SwiftUI modifiers already used in the repo.

## Run log

### Run 1 (2026-11-27, hourly)

| # | MP page → native view | Problem in English | Fix | Status |
|---|---|---|---|---|
| 1 | `pages/play/*` clue unlock, free-explore meta, play tools, lead bar → `CYBusinessComponents.swift:716`, `FreeExplorationViews.swift:174`, `MPGap/PlayRoam/PlayToolsAndLeadSheetView.swift:161`, `MPGap/PlayRoam/PlayLeadBar.swift:55` | `check_locale_format.py` FAILED: 4 multi-argument count strings read "1 points / 1 chapters · 1 shops / 1 shops · … / finished 1/1 stops" | `tools/add_i18n_r2_substitutions.py` run: English plural substitutions (catalog + the `i18n-r3-strings` / `mp-journey-r3` fragments). Gate now PASS | Done |
| 2 | `pages/topic/*` purchase reveal → `TopicPurchaseRevealMount.swift:22` | Pass card kind read "Chengyin · Free Explore pass" / "Chengyin · City Orienteering pass"; the English brand is **Chein** (InfoPlist `CFBundleDisplayName`, owner 11-27) | `topicReveal.kind.free` / `.city` en → "Chein · …" (catalog + `i18n-r3-strings.json`) | Done |
| 3 | 21 single-count strings on player screens: topic detail (`topic.chapterCard.games`, `topic.depart.sharedBy`, `topic.depart.stops`, `topic.reviews.basedOn`, `topic.teams.count`, `topicXcx.routeNote.freeShops`, `topicXcx.routeNote.stops`), roam (`roam.w208.intro.live`, `design.roam.teamsOnRoute` on the city-run map pill, `附近共有 %lld 支队伍`, `附近共 %lld 个结果 · 最近`), play (`playFree.meta.stores`, `playx.board.score`, `play.nr2.route.stops`, `cyBiz.clue.spend`, `cyBiz.clue.unlockFor`), club (`club.topic.card.chapters`, `club.strip.all`, `clubR3b.notify.sendTo`), publish/me (`templateAuthor.mine.useNum`, `fixr9.ap.tickets.missing`) | Read "1 teams on the route", "1 stops", "Based on 1 reviews", "Used 1 times" … The r1 plural tool skipped every key a `docs/port/strings` fragment spells, so later lanes' count strings never got plural variants | `tools/add_i18n_r1_plurals.py`: a key spelled only in a byte-stable fragment is now converted and the fragment's English entry updated (same rule as the r2 substitutions tool), so a fragment merge keeps the plural. `club.settings.customerCount` stays plain (`String(format:)` call site, host-only). 21 keys converted, 13 fragments updated; `check_locale_format.py` PASS | Done |

| 4 | `pages/topic/index` bottom bar (price left, one primary right; MP order unchanged) → `TopicXcxSections.swift` `TopicXcxActionBar.barContent` | Price ("$12.50 from", "Free") + "Sign up now" / "Play any time" (`minWidth: 132`) in one `HStack` overflow the bar at accessibility sizes in English | `AnyLayout`: `HStackLayout` as before at standard sizes; `VStackLayout(alignment: .leading)` with the price above the primary button at accessibility sizes (spacer only in the row form). Same pattern as `ParticipationParityViews.swift:40` | Done |

### Run 2 (2026-11-27, hourly)

| # | MP page → native view | Problem in English | Fix | Status |
|---|---|---|---|---|
| 5 | `pages/club/*` inline leaderboard row → `ClubDetailR8Mounts.swift:472` | `clubR8.lb.meta` read "1 runs · 3.2 km · time 40 min"; the call site ran `String(format:)`, which drops a plural substitution | Call site now interpolates (`appLocalized("clubR8.lb.meta \(row.clearCount) \(mileageText(row)) \(durationText(row))")`, same key); `runs` added to the r1 plural nouns; r2 tool converted the key + `fix-r8-club.json` fragment. The r1 tool also converted `mp.rank.unattributed %lld` (journey report, interpolated call site): one form hand-fixed to "%lld run lacks a frozen location and isn't counted" | Done |
| 6 | `subpackageMember/components/cy/profile` `pc-actions` (MP: [开始探索][票夹][···]) → `MemberHomeHeader.swift` `actionRow` | Coordinator 16:37 `d2-me` en-US: "Start exploring" wrapped to four lines inside the button at 375 pt | Labels `lineLimit(1)`; `ViewThatFits(in: .horizontal)` keeps the MP row when it fits, otherwise stacks the same buttons vertically (MP order unchanged); accessibility sizes always stack as before. Buttons stay `.borderedProminent` / `.bordered` large | Done |
| 7 | MP badge-wall (`subpackageP3/badge-wall`) fixture → `DesignFixtures/E5bFixtures.swift` `E5bBadgeWallFixture` | Coordinator 16:53 `e5b-badge-wall` zh-Hans: badge names and unlock conditions English | Fixture names/hints go through the fixture's `tt(en, zh)`. The zh date `2026-10-01` is deliberate: MP `displayDate` keeps `YYYY-MM-DD` in Chinese (`LocaleDisplay.civil`, pinned by `LocaleDisplayTests.swift:47`); English reads "Oct 1, 2026". Not changed | Done |
| 8 | `pages/search2/index` 推荐搜索 + 类别 → `GlobalSearchView.swift` (`capsuleLayout`) → shared `TemplateChipFlow` (`TemplateDetailXbChrome.swift:201`) | Coordinator 16:37 `d2-search`: category card renders as one tall narrow pill. The flow layout always placed a chip at its one-line ideal width, so a long English category name ran past the row | `TemplateChipFlow.chipSize`: a chip wider than the row is proposed the row width (wraps inside); zero/unknown widths keep the ideal size. MP order unchanged. Suggested chips (骑行, 外滩 …) are the MP fixed China-market keyword list sent to search (`Core/GlobalSearchRecommendedKeywords.swift`, pinned by `GlobalSearchRecommendedKeywordsTests`); US market shows none, so Chinese in the China-market fixture is correct. Not changed. Needs a simulator look to confirm the tall-pill symptom is gone (mp-home / polish-search own the page) | Done (layout), verify on device |

### Run 3 (2026-11-27, hourly)

Sweep `docs/sweeps/latest` (build 070117595) was taken under build load (coordinator 17:40: ignore); the mp-mine / mp-club en sheets show launch logos only, so this run works from code.

| # | MP page → native view | Problem in English | Fix | Status |
|---|---|---|---|---|
| 9 | `pages/roam/*` roam tools 清除缓存 confirm → `MPGap/PlayRoam/RoamSessionToolsSheetView.swift` | `roamTools.clearCache.confirmMessage` en: "Records already uploaded to **Chengyin** aren't affected" — app brand in English is Chein | en → "…uploaded to Chein…" (catalog + `mp-r3-roam.json` fragment). Catalog-wide scan: no other English value names the app "Chengyin" except the three WeChat mini-program strings in Not done | Done |
| 10 | `pages/topic/index` publisher row (avatar · name · 发布 · owner review chip, wxml 89-91/101) → `TopicXcxSections.swift` `TopicXcxHero` | One `HStack`: "Name posted Under review" runs past the row at accessibility sizes in English | Accessibility sizes: `VStackLayout` with the review chip under the publisher line (same `AnyLayout` pattern as the action bar in this file); "posted" `fixedSize` so the name truncates, not the verb. MP order unchanged | Done |
| 11 | Me tabs (MP `profileTabs` 项目/帖文/成就/关于) → `AccountView.swift:65` | Checked: "Achievements" in a 4-segment picker at 375 pt | Already `cyAdaptiveSegmented()` (segmented when it fits, menu otherwise / at AX sizes). No change | Checked |
| 12 | Ticket wallet detail → `TicketWalletDetailView.swift:378` | Checked: pass expiry is Chinese from Core (`今天过期`, `N 天内过期`) | `CoreLoopCopy.tr` maps both to "Expires today" / "Expires in N day(s)" with plural. No change | Checked |
| 13 | `subpackageRoam` roam-place-card (photo → facts → 导航/分享 row; activity time section) → `NativeR2/MapHome/RoamMapHomePlaceCard.swift` | Activity / search-activity start and end showed raw server text "2026-12-01 10:00:00" in English; the action row (primary · Navigate · View details · Share, caption labels) is one `HStack` that cannot fit four English captions at accessibility sizes | Dates → `LocaleDisplay.civil` (English "Dec 1, 2026 at 10:00 AM"; Chinese keeps the MP text unchanged). Action row → `AnyLayout`: `HStackLayout` as before, `VStackLayout` at accessibility sizes, same buttons and order | Done |
| 14 | Raw server timestamps on player screens: topic reviews (`TopicReviewsContent.swift`), activity reviews (`ActivityReviewsSection.swift`), ticket pass present date (`TicketPassPresentView.swift`), order row fallback date (`ProfileOrdersView.swift` `ProfileOrderRow`), wallet ledger timestamp + withdrawal time (`WalletCommerceViews.swift`), club post time (`ClubPostDiscussion.swift`) | English showed "2026-10-01 14:30:00" as the server sent it | `LocaleDisplay.civil(_, locale:)` (same helper as Growth / badges / club editions): English "Oct 1, 2026 at 2:30 PM"; Chinese and unparsable/relative text unchanged (MP parity). Pins `test_topic_reviews.py` / `test_activity_reviews.py` updated to the new token (reason inline) | Done |

## Not done

| Item | Why |
|---|---|
| `payoutReceiver.bind.mpOnly`, `payoutReceiver.bind.mpPathCopied`, `authEntry.deregister.wechatUnavailable` say "the Chengyin (WeChat) mini program" in English | These name the WeChat mini program, which is searched by its Chinese name; owner to decide whether English shows "Chein", "城瘾" or both. Not changed. |


## Next pages (no row yet)
Topic route stop address (1 line at AX sizes); ticket/order currency formats in English; Club home checked (tabs already adaptive, `ClubDetailTabBar.swift`).

## For other lanes
- `Tests/ContractChecks/check_wallet_earnings_overview.py` fails (2) on `ui/combined-r7` before any en-layout change (debt-r3).

## Gates
See the commit message of each push (generate_project, check_scaffold, a11y lint, contract ratchet new 0, design consistency PASS, locale format PASS).

### Pins updated (run 3)
- `Tests/ContractChecks/test_topic_reviews.py`, `test_activity_reviews.py`: review date token is now `Text(verbatim: LocaleDisplay.civil(date, locale: locale))`. Reason: English date format; plain-text rule unchanged.

### Pins updated (run 1)
- `Tests/ContractChecks/test_play_gameplay_mode_separation.py:69` and `test_play_experience_contracts.py:110`: read the English plural `other` form when a `playFree.*` / `playx.*` key carries plural variations (`playFree.meta.stores`, `playx.board.score`). Reason: count strings now vary by plural; the bilingual check itself is unchanged.
