# Receipt: design pass, lane explore + events (`design/pass-explore`)

Brief: `origin/design/handoff-r2:docs/briefs/design-principles.md` (P1–P12 + surface map), rules from
`docs/briefs/components-r1.md` and `COORDINATOR-HANDOVER.md` §4. Base `origin/ui/combined-r7` @ `fc95e6a19`
(already contains `origin/comp/r1-kit` @ `bea0ff9bb`; merge was a no-op). Date 2026-11-27.
No compiler in the cloud: every API checked by grep against the kit and design system. **Needs `build_sim` before merge.**
Story-flow theme and merchant surfaces untouched.

## Shared building blocks (new file `App/NativeR2/Explore/ExploreDesignPass.swift`)

| Piece | What | Principles | Apple API / kit |
|---|---|---|---|
| `ExploreEventClock` | Parses MP activity start/end strings exactly like `E1ActivityState.of` (local, then UTC); 24 h horizon | — | `HomeFeedDate.parse` |
| `ExploreStartsInLine` | "距开始 1:23:45" / "Starts in 1:23:45" within a day of the start; "进行中 · 还剩 0:42:10" / "In progress · Ends in 0:42:10" while it runs; nothing otherwise. Ticks by itself, wakes once at start/end | P1, P2, P5 (same clock as the Live Activity), P12 | kit `CYCountdown` (`Text(timerInterval:)`), `TimelineView(.explicit)`, `ViewThatFits` (one line → stacked when English is longer) |
| `ExploreGoingStack` | Up to 3 roster avatars (MP `registrationList`) + MP `registrationCount` rolling: "12 人已报名" / "12 going". Hidden when the count is unknown or 0; never counts the (partial) roster | P6, P2 | kit `CYLiveCounter`, `@ScaledMetric` avatars, one VoiceOver element |

Strings (fragment `docs/port/strings/design-pass-explore.json`, merged): `explore.endsIn` 还剩 / Ends in,
`explore.going` 人已报名 / going. Reuses kit keys `comp.kit.startsIn`, `comp.kit.countdown.started/ended`.

## Screen by screen: principles failed → fix

### Explore / home feed (`App/HomeFeedView.swift`)
- **Today card** (`HomeTodayCard`) — fails **P1** (leads with an eyebrow + title; the time is buried in a grey meta line) and **P2** (a ticket for 19:00 looks the same at 18:59).
  Fix: `Content.start` carries the ticket / club-event start; under the title the card now leads with the ticking `ExploreStartsInLine` in `.cardTitle` within a day of the start. Meta line, pill (P3 already OK: one `.borderedProminent`) and VoiceOver label unchanged.
- **即将上线 rail** — fails **P2** (the MP 还剩N小时 copy reads "还剩1小时" for the whole last hour). Fix: inside the last hour it becomes a live `距开始 mm:ss` (`homeFeed.upcoming.live.<key>`); ≥1 h keeps the MP copy (`upcomingCountdown`, MP `index.wxml` 即将上线).
- **Section rail loading** — fails **P10** (bare spinner). Fix: `ProgressView("homeFeed.loading")` (正在加载… / Loading…).
- P5: feed cards already zoom into the detail (`cyHeroSourceInherited`); P6 (friends going) — **not fixed**: the MP home feed payload has no friend/attendee field, adding one would invent data.

### Discovery home (`App/DiscoveryHomeView.swift`)
- Fails **P10** twice (banner + home loading were spinner-only with a hidden label). Fix: `ProgressView("discovery.loading")` shows the words.

### Search (`App/GlobalSearchView.swift`, `NativeR2/Search/GlobalSearchSession.swift`)
- Already native (`.searchable`, `.searchSuggestions`, `.searchScopes`); empty/issue states say what to do (P10 OK except the loading row).
- Fails **P10** on the in-progress row (spinner only). **Not changed:** `GlobalSearchView.swift` is SHA-pinned by
  `Tests/ContractChecks/test_global_search_category_recovery.py:91` (`CURRENT_VIEW_SHA256`). Tried `ProgressView("explore.status.searching")` (正在搜索… / Searching…), the hash test failed, reverted. Coordinator: re-pin the hash if you want it (one-line change at `GlobalSearchView.swift:112`).

### Activity list (`App/ActivityBrowserView.swift`, `ActivityListCard`)
- Fails **P10** (first-page + paging spinners spoke only to VoiceOver). Fix: `ProgressView("activity.loading")` (正在加载活动… / Loading activities…).
- Fails **P1** (card leads with title; time is a date string). **Not fixed on purpose:** `test_activity_design_structure.py:108` forbids `countdown`/`Timer`/`Date()` in `ActivityPresentationComponents.swift` and the MP list has no countdown (same decision as the kit lane). The detail and Today card carry the live clock instead.

### Activity detail (`App/ActivityDetailView.swift`, `App/E1ActivityDetailParts.swift`)
- Hero fails **P1/P2** (status chip "即将开始" but no number). Fix: `E1ActivityHero` shows `ExploreStartsInLine` under the title in `onCoverFg` — the event's one number is time-to-start (or time left while live).
- Footer fails **P6** (who's going lives in a stats cell and a section far below the action). Fix: `ExploreGoingStack(people: detail.people)` above the one pill in `registrationAction` (hidden for cancelled events); bottom content margin 112 → 148 so the last row clears the taller footer.
- **P3** OK (one `CYPillButton`; host cancel / blocked / unavailable are mutually exclusive). **P11** partial: the footer is now what · price (pinned summary) · who (stack) · one answer; no "later" because the MP has no RSVP-later.
- **P12**: hero title already wraps (`fixedSize(vertical)`); the new line uses `ViewThatFits` and never a fixed text width.

### Activity registration (`SessionRegistrationSheet` → `RegistrationSheetView`)
- Not changed. Money path is TEST-gated and contract-pinned (`freeWhenUnapproved`, quote/creation policy). **P4** (step checklist for 选票 → 报名人 → 支付) would need `CYStepChecklist`, which is **not in the kit yet** (`App/NativeR2/Components/` has no `CYStepChecklist.swift`). Left for when it lands.

### Official events (`OfficialEventsBrowserView`, `OfficialEventDetailView`, `OfficialEventComponents`)
- **P2** already fixed by the kit lane (`CYCountdown` under one hour, `OfficialCountdownText`). P1 OK (countdown + collective bar). No change.

### Topic discovery (`App/TopicBrowserView.swift`, `App/TopicDetailView.swift`)
- Fails **P10** (list, paging and detail loading were spinner-only). Fix: `ProgressView("topic.loading")` (正在读取路线… / Loading routes…).
- P1/P5: cards share the home card (`QuestifyImageEntityCard`) — OK. Topics are routes, not timed events, so no starts-in line.

## Reference log (self-found, add to `design-principles.md`)

| Reference | Why it works | Principle |
|---|---|---|
| **Apple Sports** (iOS) game rows | A game row shows its start time until kickoff, then flips to a live score with a LIVE marker; the same game becomes a Live Activity with identical tiles | P2, P5 |
| **Apple Wallet event tickets** (iOS 18 enhanced passes) | The pass leads with the one thing you need (date/time, then gate/seat), and the same ticket surfaces on the Lock Screen on event day | P1, P5 |
| **HIG — Progress indicators / Loading** | "Let people know what's happening": prefer a labelled indicator, show content as soon as possible, never a spinner alone for long | P10 |
| **HIG — Live Activities** | Use system timer text for countdowns instead of pushing updates; it stays accurate and battery-cheap | P2 |
| **Messages group / SharePlay avatar stacks** | Overlapping faces + a count beside the action make "who's here" readable at a glance without a roster | P6 |
| **SwiftUI `ViewThatFits` (WWDC22 "Compose custom layouts")** | Offer a one-line and a stacked layout; the system picks the one that fits the language and Dynamic Type size | P12 |

## Gates

- `check_scaffold.py`: PASS (5231 Swift files, bilingual keys incl. 2 new).
- `check_a11y_lint.py`: PASS, 0 new. `check_typography_lint.py`: PASS.
- `contract_ratchet.py --check`: **104 failing, baseline 104, new 0, fixed 0** (exit 0).
- Targeted contract tests for every touched file (59 files, 418 tests): only pre-existing failures in
  `test_merchant_discovery_redemption_contracts` (same 5 errors on the untouched base) remain.

## For the coordinator

- `build_sim`. Riskiest spots: `ExploreStartsInLine.fitting` (a `CYCountdown` passed as a value into a `ViewThatFits`), the `Text + Text` lead, `@MainActor` `MemberIdentityCardSection.remoteAvatarURL` called from `ExploreGoingStack`.
- No capabilities, profiles or backend changes.
