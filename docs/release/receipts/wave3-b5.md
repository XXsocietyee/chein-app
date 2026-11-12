# Wave 3 · B5 — Stamp press + badge bloom (code-only, not compiled here)

Spec: `/Users/fanning/chengyin-refs/specs/design-wave3.md` §3.4, §3.5, §5A, §5B. Branch `ui/w5` (from `ui/night-base` + `ui/main`).
The integrator compiles and records the videos; nothing in this receipt was built or run on a simulator.

## What is mounted where

| Moment | Live mount | Notes |
|---|---|---|
| Stamp press (5A) | `RoamStampCameraView` enqueues `.stamp` when the capture coordinator reaches `.created(id)` (dedupe key `stamp-<id>`, plays once per session). `RoamBrowserView` hosts `.cyCelebrations(celebrations)` on its `NavigationStack` and publishes the centre through `EnvironmentValues.cyCelebrationCenter`. | The item-detail sheet (`RoamItemDetailView`) sits above the host layer, so it re-hosts only the stamp overlay with `.cyStampOverlay(celebrations)`. |
| Badge bloom (5B), Growth Center | `GrowthCenterView` already enqueues `.badge`; it now plays the rebuilt `CYBadgeUnlockCover`. | unchanged call site |
| Badge bloom (5B), badge detail | `ObjectBadgeDetailView.arrive()` now enqueues `.badge` into a per-view `CYCelebrationCenter` hosted with `.cyCelebrations`. The old `.cyUnlockCelebration` (confetti + ring) is removed from the live detail. | First open of a badge lit in the last 7 days only; `$seen.mark(key)` still gates it, so a second open is silent (quiet success tick). `cyUnlockCelebration` itself stays for `AlbumKitFixture` (not a live screen). |

## New / changed code

- `App/DesignSystem/CYBurst.swift` — Canvas particles, cap 60, `dust` and `confetti` styles; draws nothing under Reduce Motion, Low Power or thermal >= serious.
- `App/DesignSystem/CYStarBloom.swift` — silhouette -> bloom -> horizon -> orbit from one `phase`; `cheap` (Low Power / Reduce Transparency) drops the blur copies. Windows were re-timed from the spec so the order is strict: land 0-0.45, horizon 0.45-0.70, orbit 0.55-1.
- `CYStampSlamView` — rebuilt on a single elapsed clock (ms table below). Adds the paper card, lantern seal, two rings, `CYBurst`, passport mini-page flip + `numericText` count, and a Share pill (new `CYCelebrationShare.stamp`, `CYCelebrationCopy.shareStamp/stampEyebrow`). `CYStampPayload.passportCount` (nil = em dash, never 0).
- `CYBadgeUnlockCover` — `indigo -> ink0` ground, `CYStarBloom` + real `CYBadgeMedal` taking over from the white silhouette, Rounded Heavy name (zh-Hans: Semibold, +1 pt eyebrow tracking), one foil sheen sweep, Share enters at 1.5 s.
- Engine (`CYCelebrationEngine.swift`) — new haptic cues, new `hold` action (Share stops the stamp auto-dismiss clock). No Core changes.
- Environment key `cyCelebrationCenter` + `cyStampOverlay` in `CYCelebrationViews.swift`.

Not in this branch (other briefs): `CYWave` metal (B2) and `CYFoil` / `CYTilt` (B1). The stamp therefore uses a second shock ring in place of the wave at 120-420 ms, and the badge uses a one-shot sheen band for the 1400 ms foil beat. Swap in `cyWave` / `cyFoil` once B1/B2 land.

## Fixtures to record (`--design-fixture <name>`, add `-zh` for Simplified Chinese, `--uitesting-reduce-motion` for RM)

| Fixture | What it shows | Videos |
|---|---|---|
| `celebration-stamp` | the 5A stamp press; the lab logs every haptic with a timestamp | default, RM, `-zh` |
| `celebration-stamp-count` | same with a known passport count (rolls 11 -> 12); `celebration-stamp` shows a dash | default |
| `celebration-badge` | the 5B badge bloom | default, RM, `-zh` |
| `celebration-badge-long` | long name wraps under the Rounded Heavy title | default |
| `celebration-queue` | stamp then badge then summary, in priority order | default |
| `album-badges-new` | wall opens the detail on the badge lit today; cover plays once. Re-launch clears the seen key; opening the same badge again in one run is silent | default, RM |

## Expected beats

Stamp, ms from present (haptic log offsets are relative to the fixture task start):

| ms | beat | haptic log |
|---|---|---|
| 0 | seal rises 40 pt, grows to 1.15 on the `ink1` card, ink0 backdrop fades in | |
| 120 | drop and squash to 0.92, card dips 0.985 | `impactHeavy` ~0.12 s |
| 120-420 | lantern ring 1 -> 2.4x fading, thin second ring 60 ms behind | |
| 250 | | `success` — logs at ~0.27 s: the engine's 150 ms haptic spacing pushes it 20 ms, inside the ±60 ms window |
| 300-1100 | 36 lantern particles from the seal | |
| 350 | title (+ place) rise 14 pt | |
| 600 | passport mini-page top-right flips once, count rolls | |
| 900 | Share pill enters and goes live | |
| 2400 | auto-dismiss (4 s with VoiceOver); tap anywhere dismisses earlier; Share stops the clock | |

Badge:

| ms | beat | haptic |
|---|---|---|
| 0-150 | ground fades to indigo -> ink0 | |
| 150-600 | dark silhouette at 0.2x fills white, lands with overshoot, lantern bloom grows | `impactMedium` at 450 |
| 600-900 | horizon arc draws in; real medal takes over from the silhouette | |
| 700-1300 | seven stars orbit in | `success` at 1000 (+ 28 dust particles) |
| 1100 | eyebrow "NEW BADGE" + name rise 14 pt | |
| 1400-1900 | foil sheen crosses the medal | |
| 1500 | Share + Keep enter and become tappable (under 1.8 s to interactive); swipe down keeps at any time | |

Reduce Motion: stamp = finished state cross-fades in, no particles, no flip, one `success` at 0, auto-dismiss 2.0 s. Badge = 200 ms cross-fade to the finished state, one `success` at 0, no orbit, no particles. Low Power / thermal: no particles, no idle star drift, badge bloom without blur copies.

## Known limits

- The stamp from the live camera has no place name and no passport count yet (`place: nil`, `passportCount: nil`): the title line shows alone and the count is a dash. Wire them when the created-stamp read exposes them.
- Haptic and 1.8 s numbers are derived from the code clock, not measured; record at 0.25x speed to judge.
