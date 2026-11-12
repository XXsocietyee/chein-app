# Wave 3 B7: CYMorphButton, club joined, tab pill

Code-only; the integrator compiles and records. Spec: `specs/design-wave3.md` §4.5, §4.8, §5E.

## Mounted
| Where | What |
|---|---|
| `App/DesignSystem/CYMorphButton.swift` (new) | `CYMorphButton` (idle / working / done, width fixed by an invisible idle-label sizer), `CYOrbitDots`, `CYClubJoinStage` (pill -> dots -> green check -> avatar flies to member strip, count rolls +1 -> status chip), DEBUG `CYHapticLog` |
| `App/ClubActionPanel.swift` `membershipButton` | LIVE: Join/Apply render `CYClubJoinStage`. Dots while `isWorking`; on `.acknowledged` after confirm the check, flight, then Joined (or Pending for Apply) chip. Leave keeps the destructive style. `club.action.join/apply` identifier now sits on the Button itself |
| `App/DesignSystem/CYClubCards.swift` `CYClubCardTrailing` | Join/Apply pills are `CYMorphButton`; new `morph:` param (default `.idle`), action change crossfades pill to chip. Identifiers unchanged |
| `App/DesignSystem/CYNightTabBar.swift` (new) + `QuestifyApp.swift` `playerTabs` overlay, `IATabsFixture` | Violet capsule: stretches x1.35 toward the destination (120 ms), springs into the slot, relaxes. Non-interactive and accessibility-hidden overlay on the native bar, so tab taps, identifiers and VoiceOver are untouched (deliberate deviation: bar is not hidden) |

Haptics: selection when the check lands, success +250 ms, once per transition (`[CYHaptic] selection #n` / `success #n` in the console, DEBUG). Reduce Motion: no dots travel, crossfade states, no stretch/flight, pill crossfades. No new strings (reuses `club.action.*`, `club.membership.*`).

## Fixtures to record (`xcrun simctl launch <udid> invalid.example.questify.ios --design-fixture <name>`)
- `d4-join-confirm`: tap Confirm in the sheet; stage auto-plays: Join pill 500 ms, dots 1100 ms, green check (same width), avatar flies from pill into strip (+300 ms), count 12 -> 13, chip at ~+900 ms.
- `ia-tabs`: tap each tab; pill stretches, lands, relaxes; violet only on the pill/selected icon.
- `clubcards-join`: self-playing card pill: Join -> dots -> check -> Joined chip.
Record each with and without `--uitesting-reduce-motion`.
