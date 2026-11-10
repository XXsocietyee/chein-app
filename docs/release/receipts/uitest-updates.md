# UI test updates for onboarding and the "More info" disclosure

Code-only change (no build, simulator, or xcodebuild run). Static checks run: `tools/check_scaffold.py`, `tools/check_design_lint.py`.

## (a) Onboarding
Fresh installs open the onboarding pager; `welcome.player` exists only on the final (consent) step, and `onboarding.skip` is shown on every earlier step (`OnboardingStep.showsSkip`). No launch argument bypasses it, and `onboarding.completed.v1` is set only by register/guest. New shared helper `skipOnboardingIfPresent(in:)` taps skip when shown and is a no-op otherwise.

- `Tests/AppUITests/FailureScreenshot.swift`: adds the shared helper.
- `NonCashRewardFlowTests.swift`, `CouponRuntimeJourney.swift`, `IntegratedActivityPlayJourneyFlowTests.swift`, `IntegratedNativeAcceptanceFlowTests.swift`, `IntegratedDeniedAcceptanceFlowTests.swift`: call the helper before `welcome.player` in the sign-in entry.
- `EntryFlowTests.swift`: helper after each launch (setUp, relaunches, scanner cancel).
- `RegionalEntryFlowTests.swift`: helper in `launch(_:)`.
- `WeChatAppAuthFlowTests.swift`: helper after launch.
- `EntryUsageConsentFlowTests.swift`: unchanged. Its `welcome.player` taps are on the Me tab, which uses the compact page without the pager.
- `ActivityFlowTests.swift`: unchanged for this part (fixture mode never shows the welcome screen).

## (b) ActivityDetailView "More info" toggle (`activity.more.toggle`)
Hidden until expanded: activity.openTopic, about, reviews.*, openReview, detail.readOnly, openPlay, openCharacterCard, openPlayExperience, openPlayDirector.

- `ActivityFlowTests.swift`: `expandMoreInfo()` before the readOnly, reviews, reviews-empty and reviews-unknown checks.
- `SignedInContentDetailFlowTests.swift`: `expandActivityMoreInfo` before every `activity.openTopic` tap.
- `IntegratedActivityPlayJourneyFlowTests.swift`: expands the toggle in `tapActivityPlay`.
- `IntegratedDeniedAcceptanceFlowTests.swift`: no change (only asserts absence).

## Python contract tests (`Tests/ContractChecks`)
- `test_activity_reviews.py`: fixed and now passing. Tickets anchor is the `E1IconHeader` ticket header; review row is a `CYListRow`; load state uses `CYPhase`. Added guards that reviews and `activity.openReview` live only in `moreInfoSections`, behind the toggle.
- `test_activity_registration_parity_w2_06.py`: `test_meta_rows_follow_cancellation_and_precede_about` ordering updated to hero, info card, cancelled, map, tickets, toggle, about (behind the toggle). The test still fails later on the old `ActivityDetailMetaSection` unconfirmed-copy tokens.
- `test_activity_topic_accessible_summaries.py`: already passing, unchanged.
- `test_activity_design_structure.py`: unchanged. It is red identically at `ba9e471db^`, from earlier restyles.

## Known red, not caused by this change
Identical failures exist at `ba9e471db^`: `test_activity_design_structure.py` (8 tests), plus two `RegistrationCheckoutParityTests` in `test_activity_registration_parity_w2_06.py` (registration-sheet restyle). They need a separate triage so the pins are not weakened.
