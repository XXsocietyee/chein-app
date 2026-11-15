# Haptics Map (`HapticsService`)

All tactile feedback in Questify flows through `HapticsService` (`Core/HapticsService.swift` + `App/DesignSystem/HapticsService+UIKit.swift`) and `CYHaptics` (`App/DesignSystem/CYMotion.swift`). Views and coordinators never instantiate `UIImpactFeedbackGenerator`, `UINotificationFeedbackGenerator`, or `UISelectionFeedbackGenerator` directly.

## Gating & Throttling Rules

1. **System setting**: UIKit feedback generators natively respect iOS **Settings > Sounds & Haptics > System Haptics**. `HapticsService` additionally consults `HapticsPreferenceReading.isSystemHapticsEnabled()` (backed on iOS by hardware/system availability and testing overrides, and injectable in `CoreTests`).
2. **In-app toggle**: Reads `SettingsSoundPreferences.haptics` from `UserDefaults.standard` under `"scene_sound_haptics"` (default `true` when unset). Toggling Haptics off in Settings immediately suppresses every `HapticsService` event.
3. **Cooldown (`>= 120 ms`)**:
   - Repeating / streaming events (`diceRoll`, `sensorShakeHit`, `sensorQuietWarn`, `sensorCompassAlign`, `sensorShoutTick`, `sensorStepsProgress`, `scratchRub`, `selection`, `impactLight`, `impactMedium`, `impactHeavy`, `impactRigid`) share a `120 ms` continuous cooldown bucket.
   - Discrete / terminal events (`checkInSuccess`, `wrongAnswer`, `diceLand`, `rewardOrMedal`, `medalCycle`, `claimSuccess`, `levelUp`, `sensor*Complete`, `sensorStillFailed`, `scratchReveal`, `jigsawSwap`, `jigsawSolved`, `success`, `warning`, `error`) are each debounced per event at `120 ms` so stacked updates never double-buzz while terminal confirmations after a roll/tick are never dropped.

## Event-to-Generator Mapping

| Event (`HapticEvent`) | UIKit Generator | Style / Notification | Trigger Surface |
|---|---|---|---|
| `checkInSuccess` | `UINotificationFeedbackGenerator` | `.success` | POI check-in confirmed (`RoamPOIActions`, `PlayExperienceView` `.arrive`/`.scan`) |
| `wrongAnswer` | `UINotificationFeedbackGenerator` | `.error` | Rejected QA/reasoning answer, hangman wrong guess, accusation wrong suspect, failed check-in (`PlayExperienceView`, `PlayKitQuestoViews`, `RoamPOIActions`) |
| `diceRoll` | `UIImpactFeedbackGenerator` | `.medium` | Hold-to-roll pulse, dice roll start, coin flip trigger (`CYDiceGestures`, `PlayJourneyCheckView`, `PlayKitDecisionProgressViews`) |
| `diceLand` | `UIImpactFeedbackGenerator` | `.heavy` | Dice/coin outcome landed (`PlayJourneyCheckView`, `PlayKitDecisionProgressViews`) |
| `rewardOrMedal` | `UINotificationFeedbackGenerator` | `.success` | Reward card unlock / verdict win / medal reveal (`PlayExperienceView`, `CYPlayVerdict`, `CYMedalStack`, `CYCelebrationViews`) |
| `medalCycle` | `UISelectionFeedbackGenerator` | selection changed | Swiping / stepping through stacked medals (`CYMedalDeck`, `CYMedalScreen`) |
| `claimSuccess` | `UINotificationFeedbackGenerator` | `.success` | Reward pledge claimed, city badge/pass acquired, slow task claimed, daily sign-in claimed (`RewardPledgeViews`, `CityAcquisitionView`, `PlayKitLegacyViews`, `PlayKitDecisionProgressViews`) |
| `levelUp` | `UINotificationFeedbackGenerator` | `.success` | Player growth level increases (`GrowthCenterView`) |
| `sensorShakeHit` | `UIImpactFeedbackGenerator` | `.rigid` | Ball shake impulse recorded (`PlayKitSensorChallengeView`) |
| `sensorShakeComplete` | `UINotificationFeedbackGenerator` | `.success` | Ball shake challenge measured/completed (`PlayKitSensorChallengeView`) |
| `sensorQuietWarn` | `UINotificationFeedbackGenerator` | `.warning` | Quiet-hold ambient noise exceeded (`PlayKitSensorChallengeView`) |
| `sensorQuietComplete` | `UINotificationFeedbackGenerator` | `.success` | Quiet-hold duration completed (`PlayKitSensorChallengeView`) |
| `sensorStillComplete` | `UINotificationFeedbackGenerator` | `.success` | Stillness timer completed (`PlayDeviceTaskViews`) |
| `sensorStillFailed` | `UINotificationFeedbackGenerator` | `.error` | Stillness interrupted by movement (`PlayDeviceTaskViews`) |
| `sensorCompassAlign` | `UISelectionFeedbackGenerator` | selection changed | Compass heading enters alignment band (`PlayKitSensorChallengeView`) |
| `sensorCompassComplete` | `UINotificationFeedbackGenerator` | `.success` | Compass alignment held & measured (`PlayKitSensorChallengeView`) |
| `sensorShoutTick` | `UIImpactFeedbackGenerator` | `.heavy` | Shout threshold crossed (throttled `>= 120 ms`) (`PlayKitSensorChallengeView`) |
| `sensorShoutComplete` | `UINotificationFeedbackGenerator` | `.success` | Shout challenge measured/completed (`PlayKitSensorChallengeView`) |
| `sensorStepsProgress` | `UIImpactFeedbackGenerator` | `.light` | Step counter advances / sensor sample read (`NativeMotionReminderViews`) |
| `sensorStepsComplete` | `UINotificationFeedbackGenerator` | `.success` | Step goal completed / receipt awarded (`NativeMotionReminderViews`) |
| `scratchRub` | `UIImpactFeedbackGenerator` | `.soft` | Continuous scratch gesture feedback (`CYScratchCard`, throttled) |
| `scratchReveal` | `UINotificationFeedbackGenerator` | `.success` | Scratch card threshold crossed & revealed (`CYScratchCard`) |
| `jigsawSwap` | `UISelectionFeedbackGenerator` | selection changed | Jigsaw tile selected or swapped (`PlayKitNewGameForms`) |
| `jigsawSolved` | `UINotificationFeedbackGenerator` | `.success` | Jigsaw order verified & solved (`PlayKitNewGameForms`) |
| `selection` | `UISelectionFeedbackGenerator` | selection changed | Tab switch, chip/segment pick (`CYHaptics.selection`) |
| `success` | `UINotificationFeedbackGenerator` | `.success` | Generic confirmation (`CYHaptics.success`) |
| `warning` | `UINotificationFeedbackGenerator` | `.warning` | Validation warning / blocked action (`CYHaptics.warning`) |
| `error` | `UINotificationFeedbackGenerator` | `.error` | Rejection / failure notification (`CYHaptics.error`) |
| `impactLight` | `UIImpactFeedbackGenerator` | `.light` | Pull-to-refresh / subtle snap (`CYHaptics.impactLight`) |
| `impactMedium` | `UIImpactFeedbackGenerator` | `.medium` | Primary commit press (`CYHaptics.impactMedium`) |
| `impactHeavy` | `UIImpactFeedbackGenerator` | `.heavy` | Heavy trigger press (`CYHaptics.impactHeavy`) |
| `impactRigid` | `UIImpactFeedbackGenerator` | `.rigid` | CITY defense held (`CYHaptics.impactRigid`, City Monopoly spec §5) |
