# Wave 3 B8: Onboarding night-light

Code-only (not compiled or recorded here; the integrator builds and records). Spec: `specs/design-wave3.md` §5F, §6 row 12.

## What is mounted where

Live path: `WelcomeView` -> `OnboardingFlow` (`App/DesignSystem/CYOnboarding.swift`), unchanged host contract (`onRegister` / `onGuest`), every accessibility identifier kept (`onboarding.skip`, `onboarding.primary`, `onboarding.demo`, `onboarding.title`, `onboarding.dots`, `onboarding.consent`, `welcome.player`, `welcome.browse`).

| Piece | Where | Behaviour |
|---|---|---|
| Ground | `OnboardingBackdrop` | `indigo -> ink0` vertical, ember horizon pool (10-18 % by step), faint lantern light pool, deterministic film grain (`OBGrain`, overlay 22 %). Flow forced to `.dark` colour scheme. |
| Six lantern windows | `OBLanternWindows` inside `FogWindow` | fade+rise in at 200 / 420 / 640 / 860 / 1060 / 1260 ms, drift +-4 pt, flicker, parallax 8 pt x depth from `OBTiltSource` (gyro at 30 Hz, or fake sweep roll -0.5 -> 0.5 over 3 s under `--uitesting-fake-tilt`) plus drag tilt. Lantern gold only (discovery). |
| Wordmark bloom | `OBWordmarkBloom` in `FogWindow` (welcome, 1.4 s, 100 %) and `AppMark` (final step, 0.2 s, 40 %) | scale lands with overshoot, glow swells 0 -> 1 in 0.5 s then settles 0.55; two blurred lantern copies (skipped under RM / Reduce Transparency / Low Power). |
| Hold-GO demo clears fog | `GOHoldDemo` + `FogWindow(revealed:)` + hero `obWave` | ring fills lantern over 0.9 s, ticks (impactLight) at 200 / 400 ms, commit impactHeavy; then fog scales 1 -> 1.5 and fades, lantern ring expands, Metal ripple (`cyOnboardWave`, `CYOnboardingWave.metal`) crosses the hero for 0.8 s. RM: fog crossfade only, no ripple. Low Power / thermal: no ripple. |
| Stamp demo (§5A at 70 %) | `StampSeal` | 0 seal 1.15 and rises 28 pt; 120 impactHeavy + squash 0.92; 120-420 lantern ring 1 -> 2.4x + wave (amp 7); 250 success; 300 burst of 25 lantern particles (`OBBurst`); 350 "Stamped. You were here." / 盖章成功，算你来过 rises; 600 passport count chip rolls 0 -> 1 (`numericText`). RM: crossfade to final + one success haptic. |
| Create-account pill | `OBMorphPill` (final step, id `welcome.player`) | same width, fill crossfades to `verify` green, label swaps to a checkmark (bounce), selection haptic at 0, success at +250 ms. Live: relaxes after 1.5 s so a dismissed sign-in sheet leaves a normal pill. |
| zh-Hans type | `OnboardingCopy`, top-bar and bloom wordmark | titles `PingFang` Semibold 30 (scaled), never Heavy; EN titles Rounded Heavy 34. Eyebrow 13 pt: EN Semibold +0.6 tracking, zh Medium +1. |
| City disc | `CityDisc` | indigo body, cold glass rim; no gold on chrome. |

Not done (needs Core or is out of B8 scope): writing the **real** 新手章 at the stamp demo (UI-only rule; the demo is the §5A animation only), step-4 crowd bloom beyond the existing orbit, hold-sheet consent move.

New files: `App/DesignSystem/CYOnboardingLight.swift`, `App/DesignSystem/CYOnboardingWave.metal` (private `OB*` / `cyOnboardWave` names so they cannot collide with the shared light kit from B1/B2). New strings: `onboarding.stamps.slam`, `onboarding.createAccount.done` (EN + zh-Hans).

## Fixtures to record (iPhone17 sim, `--design-fixture <name>`)

The `onboarding-*` fixtures now self-play (`autoDemo`): hold-GO at 1.0 s, stamp at 1.0 s, club join at 1.0 s, account morph at 1.8 s.

```
xcrun simctl launch 25316F87-058C-46CE-8825-617906638207 invalid.example.questify.ios --design-fixture onboarding-1 --uitesting-fake-tilt
```
Names: `onboarding-1` ... `onboarding-5` (EN), `onboarding-zh-1` ... `onboarding-zh-5` (zh-Hans, identical timing), `onboarding-ax` (static, no autoplay). Add `--uitesting-reduce-motion` for the RM video. Record to `/Users/fanning/chengyin-refs/videos/b8-onboarding-<n>.mp4`.

## Expected beats (0.25x)

- `onboarding-1`: indigo ground + grain; disc dark; windows appear 0.2-1.3 s and slide with the fake tilt; wordmark 城瘾 blooms at 1.4 s then glow settles by 2.5 s. RM: windows static, wordmark crossfades at 0.2 s.
- `onboarding-2`: 1.0 s hold ring fills lantern, two ticks, 1.9 s fog fades + ring + ripple; copy "Fog cleared".
- `onboarding-3`: 1.0 s §5A sequence above (timestamps relative to 1.0 s), count chip shows 1 at +600 ms.
- `onboarding-4`: five orbiting avatars become six at 1.0 s.
- `onboarding-5`: faint wordmark bloom at 0.2 s; at 1.8 s pill morphs green with check, same width; sign-in gate not opened in fixture.
- zh: same timestamps; titles visibly lighter (Semibold).
