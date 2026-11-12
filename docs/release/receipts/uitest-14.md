# UITest 14 root cause (rc/20261108 @ 930acb848)

Root cause (single): `revealFixtureElement` (Tests/AppUITests/FailureScreenshot.swift) computes its scroll viewport
from the last `.toolbar`/`.navigationBar` in the AX snapshot. The signed-out welcome screen (`welcome.more` gear)
exposes a SwiftUI `Toolbar` wrapper whose frame is the whole screen ({0,0},{402,874}); `toolbar.minY - 4` then
made the viewport height 0, so `bounds.height > 80` failed and the helper returned false without ever swiping or
checking `welcome.player` (which was on-screen and hittable at y=724). Evidence: ia-final.xcresult failure trees for
all coupon tests show `welcome.player` Button + full-screen Toolbar; the Integrated tests fail at the same first
`tap("welcome.player")` (IntegratedNative…:95/198/205, IntegratedActivity…:94/210). Present on base 1b9db04ca too
(helper unchanged by IA), hence pre-existing.

Fix: `foregroundBarFrame` ignores bars taller than half the screen (container wrappers, not occluding bars).
Assertions untouched; contract test test_social_article_entry_visibility strings still present.

| test | cause | fix |
|---|---|---|
| CouponRuntimeFlowTests x5 | full-screen welcome Toolbar zeroes helper viewport at tap("welcome.player") | bar-height filter in helper |
| CouponRuntimeChineseFlowTests x1 | same | same |
| IntegratedActivityPlayJourneyFlowTests x2 | same (first tap of welcome.player) | same |
| IntegratedNativeAcceptanceFlowTests x6 | same (phoneSheet -> tap welcome.player) | same |

Not verified by simulator run (code-only task); the 8 Integrated tests' xcresult trees did not embed the AX dump, so
their attribution rests on identical failing call site, not on a dump. Re-run the 14 on the Test lane to confirm.

## Round 2 (after 47971cf50 reached the app)
The helper fix worked; the tests now fail on a second, separate cause found in ui14.xcresult (AX dump of
IntegratedNative…testActualSettings…: app already signed in on the Explore home, no phoneSignIn button):
AuthChannelView (e4) (a) renders the code field only after a code was sent (`smsSent || !code.isEmpty`) and
(b) auto-submits sign-in when the sixth digit is entered (`onChange(of: code)`), removing the sign-in button.

| test | cause | fix |
|---|---|---|
| CouponRuntimeFlowTests x5, CouponRuntimeChineseFlowTests x1 | code field absent: journey typed the code without sending one first | journey taps auth.channels.sendCode (fixture answers api/sms/send), matches the code field on any element type, types 5 digits, asserts the value, then the 6th digit |
| IntegratedActivityPlayJourney x2, IntegratedNativeAcceptance x6 | sign-in already auto-submitted, so tap(phoneSignIn) asserted on a missing button | tap phoneSignIn only if it still exists and is enabled; the following wait on accountID/tokenStored still proves sign-in |
Same one-line guard applied to IntegratedDenied and NonCashReward flows (identical pattern). Assertions are not removed.
Not simulator-verified (code-only).
