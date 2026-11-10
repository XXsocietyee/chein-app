# Onboarding: motion spec and deviations from the advisor spec

Source: `/Users/fanning/chengyin-refs/specs/onboarding.md` (advisor, advice only). Code: `App/DesignSystem/CYOnboarding.swift`, host in `App/WelcomeView.swift`.

## What shipped
Five steps (welcome, roam, stamps, clubs, consent), Skip (top right, steps 1-4), 5 dots (active 20x6 capsule), full-width white `CYPillButton` primary, one hero "city disc" with a per-step layer, and a 10-second demo per mechanic. State is `OnboardingStep` + `OnboardingState` + pure `OnboardingReducer`; the flow only reports an `OnboardingEffect` (`.register` / `.guest`) to its host, which runs the existing sign-in sheet and guest browse unchanged.

Motion tokens (`OBMotion`): page spring 0.48/0.86, copy out easeIn 0.14 (y -10), copy in `CYMotion.entrance` +0.10 (y +-16 by direction), demo success spring 0.32/0.55, tilt interactive spring, idle 2.6 s drift (+-5 pt). Haptics via `cyHaptic` only: selection on step change, heavy on GO / stamp, medium on join.

## Changes vs the advisor spec, and why
| Spec | Shipped | Why |
|------|---------|-----|
| 6 steps incl. `.tickets` (pass, flip, tear) | 5 steps; tickets dropped | Brief asked for 4-5 steps; tickets are the money-adjacent surface, the least safe to demo before sign-in. Roam, stamps, clubs carry the story. |
| Consent `Toggle` gating the primary button | Informational note row; primary opens the existing sign-in sheet | Consent behaviour must stay exactly as is. The real agreement is the existing launch gate / `UsageConsentSignInRequirement` inside `LoginView`. A second checkbox would create a competing source of truth and a different gate. `consentAccepted` state removed. |
| `OnboardingState.outcome` + `onChange` | Reducer returns `OnboardingEffect?` | An outcome stored in state does not re-fire for a second tap (e.g. after the sign-in sheet is dismissed). Effects are re-triggerable. |
| `matchedGeometryEffect` on the shared disc | Disc is a persistent view; only its size animates, layers swap by `.id(step)` | The disc is never recreated, so a matched pair is redundant and a hazard under the transition. Same visual result, one fewer moving part. |
| Tickets aspect morph 1:1 to 1.58:1 | Removed with the step | See above. |
| `UIScreen.main.bounds` for hero height and swipe | Fixed 260 pt hero (160 at AX1+, hidden at AX3+); swipe thresholds in points | `UIScreen.main` is deprecated and wrong in split view; hero zone is stable. |
| `Image("AppMarkGlyph")` on the last step | Wordmark text "城瘾" | No such asset exists; asset catalogs are out of scope. |
| Drag-follow fog window uses its own gesture | Fog window shares the hero tilt drag | One gesture per zone; window offset is tilt x 0.3. |
| GO demo with `LongPressGesture` | `onLongPressGesture(onPressingChanged:)` + default accessibility action | Progress ring runs while pressed and resets on early release. VoiceOver gets a one-step activate. |
| Stamp / join demos as tap targets inside the hero | Outlined pill buttons under the hero (44 pt), hero reacts (seal drops 14 pt, orbit 5 to 6) | Real buttons are accessible and testable; the hero stays decorative (`accessibilityHidden`). |
| Skip on a returning launch | `@AppStorage("onboarding.completed.v1")`: set on Create account and Guest; once set, launch opens on the last step | Spec asked for persistence; signed-out returning players should not re-watch the intro. |
| Welcome "..." menu in the nav bar | Same menu rendered as a 44 pt control in the pager top bar | Language switcher, saved drafts and Settings stay reachable; nav bar hidden. |

The signed-out Me tab (`WelcomeView` without `onBrowse`) keeps its compact page: the pager would fight the floating tab bar.

## Reduce Motion
`@QuestifyReduceMotion` everywhere: no tilt or idle drift, no scale/offset on step layers or copy (opacity only, `CYMotion.reduced`), orbit static (frozen at t=0), stamp lands without ring burst, demos stay interactive.
Reduce Transparency: the blurred specular highlight is dropped; the rim stays.

## Accessibility
- VoiceOver: wordmark (header), Skip, title (header), body, demo control, "Step n of 5", primary, guest. Hero and decorative hint are hidden; GO demo exposes label, hint and a default action; escape gesture = Skip.
- Dynamic Type: all copy uses text styles and `fixedSize(vertical)`; AX1+ hero 160 pt and demos stack; AX3+ hero hidden, content scrolls, footer stays pinned.
- Identifiers: `onboarding.skip`, `onboarding.primary`, `onboarding.title`, `onboarding.demo`, `onboarding.dots`, `onboarding.consent`; final step keeps `welcome.player` and `welcome.browse`.

## Not changed
Consent policy, guest path, gating, merchant choice hidden (`showsMerchantChoice = false`), no password login, no network calls, money-moving switches untouched. Release: nothing new is DEBUG-only except fixtures.
