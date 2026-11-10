# Receipt: onboarding flow (DES-e3, branch ui/e3)

## Delivered
- `App/DesignSystem/CYOnboarding.swift`: state machine (`OnboardingStep/State/Action/Reducer/Effect`), pager `OnboardingFlow`, backdrop, dots, copy, consent note, city-disc hero with per-step layers, three demos.
- `App/WelcomeView.swift`: launch path (`onBrowse != nil`) renders the pager; Create account opens the existing `LoginView(.player)` sheet, Guest calls `onBrowse`. Me-tab page unchanged.
- DEBUG fixtures: `onboarding-1`..`onboarding-5`, `onboarding-ax` (last step, accessibility3, zh-Hans).
- Strings: `docs/release/ui-strings-onboarding.json` (EN + zh-Hans, 30 keys), merged into `Resources/Localizable.xcstrings`.
- `docs/release/motion-spec-onboarding.md`: deviations from the advisor spec and why.
- `Questify.xcodeproj` regenerated (`tools/generate_project.py`).

## Constraints held
Consent, guest path, gating and "no merchant choice" unchanged; password login not in Release; no Core/Tests/Config edits; no network or verification changes; money-moving switches off.

## Notes for reviewers
- Existing UI tests that tap `welcome.player` on a fresh install now land on step 1; `onboarding.skip` reaches the final step, where `welcome.player` and `welcome.browse` keep their identifiers. Tests were not edited (out of scope).
- Ticket step from the advisor spec was dropped (see motion spec).

## Verification
Code-only. Local lint: `check_scaffold.py`, `check_design_lint.py`, `check_catalog_coverage.py`. Cloud: see the commit check-runs listed below.
