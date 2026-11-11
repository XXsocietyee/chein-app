# finish-3: hosted-window test harness (ui/e3p)

Scope: tests only (`Tests/AppUnitTests/WorkshopPurchasedNormalAccountTests.swift`, the shared hosted helpers). No assertions changed.

Finding: the shared `HostedNavigationSceneWindow` already attached to a foreground-active scene and callers already call `makeKeyAndVisible()`, so the hypothesis was only partly right. Scene selection is unchanged on purpose: contract test `test_ci138_hosted_navigation_scene` requires exactly one foreground-active scene. Remaining gaps fixed in the one shared helper:
- `HostedSceneUIWindow.makeKeyAndVisible()` now lays out the root view and pumps the main run loop in a bounded slice (5 x 10 ms), so SwiftUI onAppear/sheet callbacks are delivered. Every caller gets it with no edits.
- `hostedWait` pumps the run loop each iteration (bounded by its existing timeout).
- Controller is retained by `window.rootViewController` (unchanged).

Not verified (code-only, no xcodebuild/simulator): that this clears the ~115 hosted failures. `NativeBlacklistEntryHostingTests.testHostedOwnerAuthorityRetirementRejectsOldCallbackAndCannotRevive`: static reading of `NativeBlacklistFlow` and `NativeBlacklistView` found no assertion/logic defect; it relies on the same hosted presentation, so it should benefit from the harness change, but this is unconfirmed and I made no test-specific edit.
