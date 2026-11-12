# Wave 3 · B3 — Continuity: Today→Activity, Club card→detail, Passport grid→stamp

Branch `ui/w3`. Code-only: nothing here was compiled or recorded; the integrator builds and records the videos.
Spec: `chengyin-refs/specs/design-wave3.md` §4 recipes 1, 3, 4 (Kubai087).

## Mechanism

- **`CYHeroNamespace`** (`App/DesignSystem/CYMotion.swift`): `EnvironmentValues.cyHeroNamespace`, `View.cyHeroNamespace(_:)`.
  A host owns one `@Namespace`, publishes it, and any card below calls `cyHeroSourceInherited(id)` (no initializer threading).
  No namespace in the environment (previews, other hosts) = plain button, nothing changes.
- **iOS 18+**: `cyHeroSource` (`matchedTransitionSource`) → `cyHeroDestination` (`navigationTransition(.zoom)`). The tapped element grows into the destination and back-swipe returns along the same path (system zoom is interruptible/interactive).
- **iOS 17 / Reduce Motion**: `cyHeroDestinationWithFallback` = plain push + `CYHeroFallbackEntrance` (28 pt rise + fade, `CYMotion.entrance`; iOS 17 only, none under `QuestifyReduceMotion`). iOS 18 under RM: plain push (unchanged `cyHeroSource` rule).
- **Title travels**: `cyHeroTitleRise()` on the destination title (16 pt below its rest, opacity never below 0.5 so it does not blink, `CYMotion.entrance` + 60 ms). Reads as the card title settling into the page title while the card zooms.
- `cyHeroSource(_:in:cornerRadius:)` gained a corner radius (default `CYRadius.lg`, existing callers unchanged); the stamp seal passes 64 so the zoom clip is a circle.

## Mounted (live screens)

| Flow | Source | Destination |
|---|---|---|
| Explore feed card / carousel card → Activity or Topic | `HomeFeedView.row` (`cyHeroSourceInherited(item.id)`), first copy of an item only (Today card → rails in order → stream) so one id never has two sources | `SessionHomeFeedView` `navigationDestination(for: AppRoute)`: `ActivityDetailView` / `SessionTopicDetailView` with `cyHeroDestinationWithFallback(HomeFeedDestination…)`; `E1ActivityHero` title `cyHeroTitleRise` |
| Today card (club event that is an activity) → Activity | `HomeTodayCard` source (`HomeTodayCandidate.activityID`, new optional; card opens `.activity(id)`). Host does not supply an activity-backed club event yet, so live it still shows ticket / roam | same |
| Club home card / row → Club detail | `ClubHomeView.clubRows` (`CYClubPhotoCard`, `CYClubRowCard`) `cyHeroSource(club.id)` | `ClubHomeView` `navigationDestination(item:)` → `ClubDetailView` `cyHeroDestinationWithFallback`; `club.detail.name` `cyHeroTitleRise` |
| Passport stamp cell → stamp detail | `PassportOverviewContent.slot` (now a button when hosted) `cyHeroSourceInherited(index, cornerRadius: 64)` | `AccountView` `cyPassportStampHost()` → `CYPassportStampDetailView` (same `CYStampSeal` at 2.2×, title, earned text or "how to earn" for a locked slot) |

New: `App/DesignSystem/CYStampContinuity.swift` (`CYStampSeal`, `CYPassportStampSelection`, `cyPassportStampHost`, `CYPassportStampDetailView`). The seal drawing moved out of `PassportView.slot` unchanged (colours, strokes), parameterised by `scale`.
Strings (EN + zh-Hans, `Localizable.xcstrings`): `passport.stamp.detail.title %lld`, `.earned`, `.locked`.
Accessibility identifiers kept: `passport.stamp.<n>` (now on the button), `homeFeed.*`, `club.*`, `activity.detail.name`, `club.detail.name`; new `passport.stamp.detail`, `passport.stamp.detail.title`, `passport.stamp.detail.body`.
Not done (out of scope / needs data): member-strip avatar slide (separate hierarchy across a push; would need a custom presentation), locked-cell 220 pt popover (locked cell opens the same detail with "how to earn"), `CYFoil` on seals (B1 type not on this base; `cyFoilSheen` kept).

## Fixtures to record (`xcrun simctl launch <udid> invalid.example.questify.ios --design-fixture <name>`)

| Video | Launch | Do | Expected beats |
|---|---|---|---|
| `d2-home` | `--design-fixture d2-home` | tap the first Editors-picks card, wait 1 s, swipe back from the left edge | card zooms (rounded-rect clip) into the Activity hero, hero title rises into place, nothing blinks out; back swipe shrinks the page into the same card |
| `d2-home` (Today) | `--design-fixture d2-home --design-today activity` | tap "See event" on the Today card | whole Today card zooms into the activity detail; back returns to the card |
| `clubcards-home` | `--design-fixture clubcards-home` | tap "Riverside Runners" (row), back; tap "Night Market Crew" (photo card), back | each card grows into the club detail, club name rises into the hero; back along the same path |
| `ia-passport` | `--design-fixture ia-passport` | tap stamp 1 (earned), back; tap stamp 9 (locked), back | circular seal grows to 2.2×, title "Stamp 1" rises; locked: dashed ghost grows, "How to earn…" text |

Record each twice: default and `--uitesting-reduce-motion` (RM: plain push, no zoom, no rise).
iOS 17 check: boot the iOS 17.5 runtime, same launches: push + 28 pt rise-and-fade entrance, no zoom.
