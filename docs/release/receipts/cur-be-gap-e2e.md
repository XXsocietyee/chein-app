# cur-be-gap-e2e

Branch `ui/cur-be-gap-e2e` from `origin/ui/main` `c50b449dd6d2f8083416ba99b17232f018d86b4f`.

The integrator activity sign-up button is unchanged. This branch only opens a free confirmation path when that sheet's creation policy is still disabled.

## What player 9004 can do

9004 is a signed-in player with no production registration approval, so the session policy is `.disabled`. The sheet replaces only that policy with `.free`. An approved grant is left as issued.

On `.free`, 9004 fills a name and an 11-digit phone, ticks the confirmation, and records consent. That posts `api/compliance/consents` with `docType` `activity_host_data_sharing`, `scene` `activity_signup`, `eventType` `AGREE`, and a `requestId` of at most 64 characters. The client does not send a document version or a pay channel.

The sheet then quotes `api/registration/quote`. That read is admitted on the shipped China composition only as a flat body with no money fields. Confirm runs only when the quote is fresh and `payAmount` is a known zero. Create still sends `usesAppPaymentChannel: false` and no `payChannel`. A positive amount is `.paymentRequired` and is not sent. A missing amount stays unknown and is shown as `—` in English and zh-Hans. Money writes on `www.chengyinhub.com` stay closed.

`AppSession.swift`, `AppCompositionRoot.swift`, and `RegionalLaunchConfiguration.swift` were not edited.

swiftc is not available here, so this receipt does not claim the Swift compiled. `python3 tools/check_scaffold.py` and `python3 tools/check_design_lint.py` are the checks run before push.
