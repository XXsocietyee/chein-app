# WP-12 report (cloud builder, Linux — nothing compiled or run)

## Files written
- edit `App/NativeAttributeAuthorViews.swift`: new Section in `NativeAttributeAuthorView` with a `NavigationLink { QmodAuthorImportView() }` (id `nativeAttribute.qmodImport`). No coordinator/service/transport passed; no new route.
- new `Tests/CoreTests/WP12ModulePreflightDiagnosticsTests.swift`
- new `Tests/AppUnitTests/WP12QmodImportMountTests.swift`
- new `docs/owner-plan/wp-12-new-strings.md` (none needed), this report.
- `Core/NativeAttributeAuthorCoordinator.swift`: NOT edited. By reading, `readModulePreflight` already binds to the saved version (service decode throws `staleSource` on topic/version mismatch; result requires same binding + requestKey; post-send `check`). The tests encode that; if they show a gap on a real run, the coordinator edit is still pending.

## Tests written
- WP12ModulePreflightDiagnosticsTests: testFieldAndNodeDiagnosticsDecoded, testRevalidateBoundToSavedVersion, testReadyDoesNotImplyPublish, testStaleVersionPreflightDiscarded
- WP12QmodImportMountTests: testImportEntryReachableFromAuthorViews, testImportDoesNotIssueNetworkRequest

## NOT verified
- Nothing compiled or executed (no Swift toolchain here). Tests never run red or green.
- Mount tests are source-text checks plus constructing the model/view; no rendered-UI or navigation test.
- Assumed `QmodAuthorImportModel()` / `QmodAuthorImportView()` default inits are reachable via `@testable import Questify`, and that the versioned `load()` accepts the list fixture copied from the receipt-evidence tests.
- The "owner binding moves in flight" half of testStaleVersionPreflightDiscarded relies on the service's post-send `check`; unconfirmed.
- Placement is unconditional inside the author view (not gated on draft/edit state), since import is local-only; "existing author gate" is the entry that presents the view.
