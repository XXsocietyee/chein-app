# Receipt · design-r2-play (`design/r2-play`)

Brief: `origin/design/handoff-r2:docs/briefs/round2-1127.md` (row `design-r2-play` + the coordinator's English sweep rows for
d2-play, e5b-badge-wall, d2-me, ia-passport), `design-principles.md` P1–P16, round-1 receipts `design-pass-me`,
`design-pass-explore`, `comp-r1-island-steps`, `comp-r1-games`. Base `origin/ui/combined-r7` @ `fdbd9584d`. Date 2026-11-27.
MP-first: `origin/mp-source` read for the result-sheet copy (`components/cy/result-sheet`, `playkit-qa` heads
答对了/再想想), the badge-wall condition line (`subpackageP3/pages/badge-wall`), and the publish simple page (deleted in the MP,
PG-021). **Nothing was compiled** (no Xcode in the cloud); the coordinator's `build_sim` is the first compile.

## Done

| Surface | Principle failing before | Fix | Files |
|---|---|---|---|
| City run panel (`d2-play`) | P3: Continue looked disabled — the whole metrics row (button included) was at 0.6 opacity while paused | Only the three stat cells dim; the trailing primary keeps full `.borderedProminent` strength | `App/NativeR2/CityOrientation/CityOrientationRunView.swift` (`statsOpacity`) |
| City run panel | P1: distance cell showed "—" before any walking | New `nextStopMeters` (optional, default nil): before walking the cell leads with distance to the current stop, labelled "To next point / 距下一站"; with no fix it reads "0 m", never a dash | same + `PlayExperienceView.cityNextStopMeters` |
| City run panel | Title "City orienteering" twice (nav bar + panel) | Panel `navigationTitle` removed; the run screen's nav title stays | `PlayExperienceView.swift` `cityRunPanel` |
| Play loading (P10) | Bare skeleton ~1 s | "Loading your run… / 正在读取本局…" beside the skeleton; skeleton leaves keep `playMode.loading` / `playx.loading` (contract `test_play_experience_return_mount` green) | `PlayExperienceView.swift` |
| Game result sheet (P16, P7/P8) | Score + pills, no name or date | Named record: reward badge, verdict eyebrow (MP 闯关成功 / 再想想 / 已记录), the game's title, date line (MP result-sheet `meta`), rolling score, then a label-over-value grid (tries used, attempts, hints). Share in the top bar on a pass, one Done | `App/NativeR2/Games/NativeGameShell.swift`, new `App/NativeR2/Components/CYRecordStatGrid.swift` |
| City run finish (P16) | Mood hero first, route mid-page, 2-col grid | Route map on top, record title (topicName, else the server result word), "date · start place", subtitle, 2/3-col grid (bold values), then the mood hero (P7), legs, medals, ranking. Share + Done unchanged | `CityOrientationFinishSummaryView.swift` |
| Event venue detail (P15) | Name + category, Directions as a stacked row under the map | name → "category · area" → live status in colour (`ExploreStartsInLine`, success tint) → capsule row (Directions · Share). Directions keeps `nativeR2.city.event.directions`; reviews/tickets order unchanged (`test_activity_reviews` green) | `CityOrientationEventDetailList.swift` |
| Game HUDs (P1/P2) | Audit: all kits draw through `NativeGameShell` + `NativeGameScreenHost.nativeHUD` (score, tries, hints, progress pills; countdown kit self-ticks). One fail: countdown kit showed "—" before Start | Idle countdown shows the challenge length ("30.0 s"); running = server-acknowledged clock as before. Stopwatch's hidden "—.—" after 1 s is MP game design, kept | `NativeGameTimedKit.swift` `clockLabel` |
| Badge wall (`e5b-badge-wall`) | Raw `2026-10-01`; status line left-aligned under a centred title; "Not lit yet" | Date via `LocaleDisplay.civil` (zh keeps MP `YYYY-MM-DD`, en "Oct 1, 2026"); description stack centred; `objects.badge.meta.locked` en → "Locked"; fixture locked badges carry their MP condition (`unlockHint`) so P14 "what it takes" shows | `ObjectBadgeViews.swift`, `E5bFixtures.swift`, catalog + `fix-r3-play-roam-b.json` |
| Me (`d2-me`) | Fixture painted the signed-out line and dashes under "Mia" (bare `AppSession()` is signed out) | Fixture now hosts the real `MemberIdentityCardSection` + `MemberBenefitsSection` with the signed-in fixture readers (`MemberHomeFixtureReader("ready")`, `GrowthCenterFixtureReader(.content)`), so 积分 hero reads 700 | `DesignFixtures/D2Fixtures.swift` |
| Passport (`ia-passport`) | "Account earnings" wrapped → unequal capsules; badges "3" vs stamps "3 of 12"; a badge titled "Badge" | Capsules: `ViewThatFits` (full title one line → short "Earnings / 收益"), equal height via `fixedSize` row + `maxHeight: .infinity` labels; VoiceOver keeps the full title. Badges "n of N" from the profile badge wall total (`ObjectBadgeWallSummary`, new optional `badgeWall:` on `PassportOverviewSection`, passed `session.profileReader` in `AccountView`). Fixture uses real names + total 12 | `PassportView.swift`, `AccountView.swift`, `IAFixtures.swift`, `DesignFixtureRegistry.swift` |
| Club create wizard (P4) | Bare `ProgressView` | `CYStepProgressHeader` titled with MP 第n步，共4步, "n / 4" + ring; step title, 已选 n/3 and identifiers unchanged (`club.player.create.progress` now on the header) | `ClubOperationsViews.swift` `steppedCreateSections` |
| Topic quick setup (P4) | No progress | `CYStepProgressHeader` "Quick setup  n / 3" (details → stops → editor) from `QuickPublishValidation` (`QuickPublishingView.stepsDone`); nothing new is gated. MP deleted its simple page, so the form itself is unchanged | `PublishingModesViews.swift` |

Contract test updated (pinned old layout): `Tests/ContractChecks/test_activity_publishing_wizard.py` `QUICK_SHA` re-pinned
with a note (`design-r2-play: P4 CYStepProgressHeader section + stepsDone (layout-only; was 65a1870d)`). PREFIX/SUFFIX SHAs unchanged.

## Strings

`docs/port/strings/design-r2-play.json` (10 keys, en + zh-Hans) merged with `tools/merge_localization_fragments.py`:
`designR2Play.run.loading`, `designR2Play.city.metric.toNext`, `designR2Play.passport.wallet.short`,
`designR2Play.games.verdict.{notPassed,recorded}`, `designR2Play.games.stat.triesUsed`,
`designR2Play.games.share.score %lld`, `designR2Play.games.share.passed`. One override: `objects.badge.meta.locked` en
"Not lit yet" → "Locked" (also in its source fragment `fix-r3-play-roam-b.json`). Reused: `nativeGames.passed.island`,
`nativeR2.city.finish.share`, `passport.stamps.ofTotal %lld`, `passport.stamps.count %lld %lld`, `playkit.attempts`,
`nativeGames.hud.hints`, `publishModes.quick`.

## Not done

- P7 at club-create completion (no MP celebration found in the create flow this round).
- Topic quick setup has no per-step rows (`CYStepChecklist`): the MP has no step page to mirror; header only.
- Live venue status shows only inside the `ExploreEventClock.horizon` (as Explore does); no "Open until" for venues (no hours in the activity contract).
- Social proof under the venue header ("Saved by 3 friends") — no such read in the activity detail.
- Reference log additions to `design-principles.md` live on `design/handoff-r2` (not this branch): none new beyond the P15/P16 Mobbin set already logged.

## Risks for first compile

- `CityOrientationRunMetricsRow` gained `var nextStopMeters: Double? = nil` **before** the `@ViewBuilder var trailing` closure; the one call site passes it by label with the trailing closure.
- `NativeGameShell.resultHeader`: `title` (a `Text`) gets `.font/.multilineTextAlignment`; toolbar uses `if verdict == .passed { ToolbarItem … }`; `appLocalized("designR2Play.games.share.score \(score)", locale:)` follows the existing `medalScreen.earned` pattern.
- `CityOrientationFinishSummaryView`: `@Environment(\.dynamicTypeSize)` declared mid-struct; `finishedAt.formatted(.dateTime…locale(locale))`.
- `PassportOverviewSection.loadBadges` awaits `badgeWall.profileBadges()` (protocol `ProfileReading`, AnyObject) after the growth read.
- `ExploreStartsInLine(startRaw:endRaw:tint: CYColor.successText)` in the venue header — `successText` assumed `Color` like `textSecondary`.
- `QuickPublishingView.stepsDone` uses `QuickPublishIssue` `==` (enum is `Equatable`).

## Gates

`generate_project.py` run (new `CYRecordStatGrid.swift`) · `check_scaffold.py` PASS · `check_a11y_lint.py` PASS (0 new) ·
`check_design_lint.py` PASS · `check_typography_lint.py` PASS · `contract_ratchet.py --check`: 104 failing = baseline 104, **new 0** (one interim new failure, `test_play_experience_return_mount`, fixed by keeping the skeleton leaf identifiers).
No capabilities, entitlements, merchant features or story-flow theme touched. Nothing deployed.
