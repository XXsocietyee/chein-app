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

## Not done

| Item | Why |
|---|---|
| `payoutReceiver.bind.mpOnly`, `payoutReceiver.bind.mpPathCopied`, `authEntry.deregister.wechatUnavailable` say "the Chengyin (WeChat) mini program" in English | These name the WeChat mini program, which is searched by its Chinese name; owner to decide whether English shows "Chein", "城瘾" or both. Not changed. |

| `clubR8.lb.meta %lld %@ %@` (club leaderboard row, `ClubDetailR8Mounts.swift:470`) reads "1 runs · …" | Call site runs `String(format: appLocalized(…))`; a plural substitution may not survive that path. Next run: move the call site to interpolated `appLocalized("clubR8.lb.meta \(n) \(a) \(b)")`, then add `runs` to the plural nouns. |

## Next pages (no row yet)
Topic detail remaining sections (hero, stat bar, route stops) at AX sizes; Club home; Me tabs; Roam map home place card; ticket wallet dates/currency.

## For other lanes
- (none yet)

## Gates
See the commit message of each push (generate_project, check_scaffold, a11y lint, contract ratchet new 0, design consistency PASS, locale format PASS).

### Pins updated (run 1)
- `Tests/ContractChecks/test_play_gameplay_mode_separation.py:69` and `test_play_experience_contracts.py:110`: read the English plural `other` form when a `playFree.*` / `playx.*` key carries plural variations (`playFree.meta.stores`, `playx.board.score`). Reason: count strings now vary by plural; the bilingual check itself is unchanged.
