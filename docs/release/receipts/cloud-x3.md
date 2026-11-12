# cloud-x3: AppUnit families (ui/cloud-x3-unit)

Base: `origin/ui/main` `72d2eb9ec`. No test was deleted, skipped, or loosened. Money, merchant writes, and password login stay off. This runner has no Xcode, so the AppUnit suite was not executed. The remaining failure count is unmeasured.

## iOS 27 hosted window

`NativeChannelTextReadOnlyPresentationTests` and `NativeChannelHistoryTextHTTPRecoveryTests` mounted the real composer and history view in `UIWindow(frame:)`. That window is not in the foreground scene. On the iOS 27 simulator the view never appears, so `onAppear` does not run and the original receipt is never requested. Their waits also only `Task.sleep`; sheet and navigation updates are delivered on run-loop turns, and that sleep does not return to the run loop.

Both classes now use the existing `HostedNavigationSceneWindow` plus `hostedMount` (placeholder, then the real root), and the waits pump the main run loop inside the same bounds. Assertions are unchanged. `NativeFriendRequestReviewHostingTests` and `NativeFriendDirectoryNavigationHostingTests` already used the scene window; their waits now pump the run loop the same way so a presented sheet is visible to `hostedPresented`.

## NativeFriend hosting

`NativeFriendHomeView`, `NativeFriendDirectoryView`, and `NativeFriendSessionEntry` applied `.navigationDestination(isPresented:)` after `.toolbar`. On iOS 27 that modifier is outside the `NavigationStack` and the runtime logs `misplaced navigationDestination(isPresented:)`. The push never happens, so the list's `onDisappear` purge never runs and the hosted waits never see the child. The destinations now sit before `.toolbar`. Sheet content, grants, and the "destination survives the row purge" rule are unchanged. The confirmation sheet's own cancel toolbar stays inside that sheet.

## NativeChannel route rejects

Not a remaining parser defect on this base. `fcba93a1a` already replaced the harness client ids `"readonly-original-0001"` and `"history-text-http-0001"` with 32-character lowercase hex, which is what `MessageTextIntent` requires. `NativeChannelTextService` builds the canonical multipart send and send-receipt forms and sets `httpShouldHandleCookies = false`, which is what `NativeChannelTextRoute` admits. `MessagingService.messages` builds the canonical `api/im/messages` form that `MessagingHistoryReadRoute` admits. The wire's `invalidRequest` was the old id failing that parse, thrown before any hosted view ran. The route code was not loosened. What still stopped these classes was the scene-less window above: the composer never issued the request.

## MerchantReviewOriginalRecoveryEntry `.invalid` host

Already corrected on this base by `a8098abfb`. `APIConfiguration` rejects a host ending in `.invalid` (`invalidConfiguration`). The harness now uses `https://merchant-review.example.test`, the same `*.example.test` rule as the other synthetic hosts. No production URL, and the reader still performs no review write. No further edit.

## TemplateShelfReadComposition shadowing

Already corrected on this base by `92c8a656b`. `ReviewedMerchantOperationsRoute.kind` also matches the canonical `api/template/myinfo` id read and used to run before `TemplateShelfReadRoute`. A non-merchant viewer then got `notConfigured` and the owned detail never reached the wire. `templateShelfDetailClaimed` skips that merchant branch only when the request is the exact shelf detail route, the viewer is signed in, and the shelf read approval matches. With no shelf approval the merchant branch and its merchant-only gate are unchanged. Merchant writes are not admitted by this claim. Page reads were never on that route. No further edit.
