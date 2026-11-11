# Test triage wave 2-3 (code-only)

Base: `origin/ui/main` 87a8b3de2, failing list `/private/tmp/full-failing.txt` (serial full unit run: 7358 passed / 222 failed).
Method: read each failing test and its production type; no build, simulator or xcodebuild was run, so every fix below is
**unverified until the Build lane and a unit run**. `python3 tools/check_scaffold.py`, `tools/check_design_lint.py`,
`swiftc -parse` on every touched file and the related contract tests (`test_workshop_creator_pending_synthetic_storage`,
`test_template_sensor_draft`, `test_workshop_paid_install`) pass.

## Did our UI commits since 201bf147f touch these production types?

No. `git diff 201bf147f..HEAD` touches only `App/` views, DesignSystem/DesignFixtures, `Resources/Localizable.xcstrings`,
UI tests and tooling. None of `AppSession`, `AppCompositionRoot`, `Core/Workshop*`, `Core/TemplateShelf*`, `Core/Project*`,
`NativeZeroHP*`, nor the Workshop catalogs changed (only `App/OfficialEventComponents.swift`, a card restyle that
`OfficialPublicEventCompositionTests` does not assert). All eight classes already fail at the older baseline e3ba3c1b
(see `docs/parity/full-suite-triage.md`). Verdict: **not caused by the UI commits**.

## `WorkshopPurchasedNormalAccountTests.swift:46` `InvalidTransition{idle -> failed(deinit)}`

Line 46 is `try XCTUnwrap(activeScenes.count == 1 ...)` in `HostedNavigationSceneWindow.init` (a `throws` initializer for
hosted sheets). `InvalidTransition` is not a Questify type (no match in App/Core/Tests); it is raised by the iOS 27 XCTest/hosted
runtime when a hosted test case is torn down in the idle phase after the hosted scene never became foreground-active or SwiftUI
sheets exposed no AX nodes. `docs/parity/full-suite-triage.md` already lists exactly this (`cnt=0` + `InvalidTransition`) as the
iOS 27 simulator hosted-AX family. Verdict env; not fixed in code, no test deleted.

## Table

| class | root cause | verdict | fix | SHA |
|---|---|---|---|---|
| TemplateShelfReadCompositionTests (7) | `CompositionHTTPTransport.send` chain: the reviewed merchant baseline route (`ReviewedMerchantOperationsRoute.kind`, added 2026-11-07 in bef0a1390) also accepts the canonical `api/template/myinfo` id read and sits earlier than the `TemplateShelfReadRoute` branch. For a non-merchant viewer it throws `notConfigured` before the request reaches the wire, so every owned-shelf detail / owner-configuration read dies (hence the 2 s `fulfillment` timeouts); page reads still work. | regression (production shadowing bug, predates the UI commits) | In `AppCompositionRoot.send`, `templateShelfDetailClaimed` (exact shelf detail route + signed-in viewer + matching shelf read approval) skips the merchant branch so the shelf branch admits the read with its own approval. Merchant branch and its gate unchanged when no shelf approval exists. | 92c8a656b |
| WorkshopPaidProfessionalNormalFlowTests (11), WorkshopCreatorConsentNormalFlowTests (5), WorkshopPaidInstallNormalFlowTests (4), WorkshopPaidInstalledTextNormalFlowTests (2) | Controllers call `PendingStore.load/save` on `templateAuthoringSecureStorage` = `TemplateAuthoringSecureStorage` (real Keychain). Unsigned simulator test host returns -34018, so `appear()`/recovery fails before any assertion; tests that never touch the store (default factory, transport clones) pass. Hosted-sheet tests in these classes additionally hit the iOS 27 hosted AX family. | env (Keychain -34018) + test-host wiring | DEBUG-only `AppScopedStorageFactory.syntheticTemplateAuthoringStorage` (nil default, absent in Release) used by `AppSession.templateAuthoringSecureStorage`; the four harnesses inject the existing `TemplateAuthoringMemoryStorage` through `WorkshopSyntheticStorage.factory`. Store validation and byte-exact readback still run. Hosted tests may still fail for the AX reason, not fixable from here. | 92c8a656b |
| WorkshopCreatorPendingNormalFlowTests (3) | `testEveryCreatorLabel...`: 17 expectations carried the pre-snapshot long copy; the catalogs `WorkshopCreatorConsent/Pending.xcstrings` ship the reviewed plain-language copy (changed in f9ca1f424). Two hosted tests are the AX family. | stale (label test) / env (2 hosted) | Test expectations updated to the shipped en and zh-Hans catalog values (key-by-key script), same keys, same locales asserted. Hosted tests untouched. | 92c8a656b |
| OfficialPublicEventCompositionTests (4) | `testCanonicalCity...`: `api/official/my-published` is now a deliberately reviewed signed-in read (`ReviewedOrientOfficialRoute`, `.liveInProduction`, fc5be9a66) but the test still listed it as always denied. The other three (default-closed grant/source, US/revoked/removed/foreign source, role round trip) not root-caused by reading: the guards read correct. | stale (1) / unknown (3) | `my-published` removed from the denied list and asserted separately: guest not admitted, exact signed-in GET admitted (2 wire requests). Other eight private paths still must be `notConfigured`. | 92c8a656b |
| ZeroHPNormalHostRegressionTests (4) | The four failing tests need a successful author-input read; `NativeZeroHPAuthorController.open()` bails (`message`, no read) when `coordinator.snapshot/session` is nil, which follows `ProjectEditModel.load()` over `ProjectEditSecureStorage` (Keychain). The two tests that expect inputs to stay nil pass. | env (Keychain, medium confidence) | none: `ProjectEditSecureStorage(scope:)` is constructed in about 40 places in `AppSession`; a seam needs its own wave and the Build lane. | - |

## Not changed / follow-ups

- `ui/e3` carries `tools/check_appsession_ratchet.py` (f50793db0). This branch adds 4 lines to `AppSession.swift` and 15 to
  `AppCompositionRoot.swift`; raise the ratchet or re-measure when the two meet.
- The shelf branch now admits the exact myinfo id read for any viewer holding a shelf read approval, including a merchant
  who also holds the merchant baseline gate. The request shape is the one the shelf transport already issues.
