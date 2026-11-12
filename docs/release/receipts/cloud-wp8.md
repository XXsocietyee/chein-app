# cloud-wp8 receipt — WP-08 deep-link safety audit on the real entry

Base: `origin/ui/main` `72d2eb9ec498de21ded7cf9215f2638d7195786f`. Branch: `ui/cloud-wp8-deeplink`. Not pushed to `main`, `rc`, or `ui/main`.

## What changed

`DeepLinkSafetyAudit` was only a name in `docs/owner-plan/gap-pl-4.md` (C05 / Top-15 #6). Classification already lived in `Core/DeepLinkAndUniversalLinkSafetyAudit.swift` and was not called from the app entry.

`AppSession.receiveNativeURL` now calls `consumeDeepLinkSafetyAudit` before the existing `chein://` handler, the WeChat payment callback, the WeChat auth callback, and the empty `NativeEntryLinkPolicy`. The function stayed at 8181 lines (the ratchet ceiling). `QuestifyApp.onOpenURL` is unchanged and still calls `receiveNativeURL`.

The intake records the decision on `DeepLinkSafetySnapshot.latestIntake`, which `DeepLinkSafetyDiagnosticsSectionView` can show. Payment and password routes render as CLOSED.

## Decisions

- Unsafe schemes (`http`, `javascript`, `file`, and any other non-`https` scheme that is not `chein` or `wx…`) are inert: no `nativeEntry`, no pending link, no network.
- Unknown, cross-realm, incomplete-profile, and unauthenticated protected links are inert. They no longer present the unsupported-route sheet.
- A verified public topic (`/topic` or `/pages/topic/index` with a positive id) sets `NativeEntryIntent.content(.topic)` and `AuditedContentEntry` shows `SessionTopicDetailView`. The topic screen keeps its own sign-in gate. Team invites and public merchant homes can also be presented. Profile, orders, order detail, club workspace, and merchant workbench are classified by the existing audit and are not opened.
- Payment and password routes are rejected as `.paymentOrPasswordRoute` before any other classification. That covers path segments (`pay`, `payment`, `checkout`, `cashier`, `password`, `login`, `sign-in`, `withdraw`, `reset-password`), credential query names (`password`, `passwd`, `pwd`), a URL userinfo password, and `weixin://…/pay`. None of those call `receiveNativeIntent`.
- `verifiedHTTPSHosts` stays empty in production, so an https link is untrusted until a test or a later owner change supplies a host. No production host, entitlement, or associated domain was added.
- `chein://` and non-payment `wx…` callbacks still fall through to the existing handlers. A `chein://` link still only records `pendingDeepLink`.

## Tests

Added, not executed (this machine has no Swift compiler):

- `Tests/AppUnitTests/WP08ReceiveNativeURLAuditTests.swift`
  - `testUnsafeSchemeIsInertNoNavigation`
  - `testUnauthenticatedProtectedLinkDoesNotNavigate`
  - `testWrongRealmRejected`
  - `testSafePublicTopicLinkRoutes`
  - `testPaymentAndPasswordRoutesDoNotNavigate`
  - `testCheinLinkStillRecordsPendingWithoutOpeningPayment`
- `Tests/CoreTests/WP08DeepLinkAuditCoverageTests.swift`
  - `testEveryAppEntryURLShapeHasAClassification`
  - `testNavigationIntentOpensOnlyPublicTopicTeamAndMerchant`
  - `testClosedSegmentsCannotBeReclassifiedAsSafeDestinations`

## Checks observed

- `python3 -B tools/check_scaffold.py` — PASS (4463 Swift sources, appsession ratchet, design lint, page route table).
- `python3 -B -m unittest Tests.ContractChecks.test_account_marketing_entry_integration Tests.ContractChecks.test_universal_link_associated_domains Tests.ContractChecks.test_wechat_payment_adapter` — 17 tests, OK.

Nothing was compiled. No simulator, preview, or Xcode run.
