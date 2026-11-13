# Cloud stubs home — ledger row 17

Branch `ui/cloud-stubs-home`, parent `origin/ui/next` `bdd0a90b3b3c1abb52c767d2fe877effed428755`.

Stub ledger row 17 only: `HomeFeedView.cityLocationConsent`. The card was already built in `HomeFeedView` and left unwired at `SessionHomeFeedView`.

## What the home does now

The card stays the non-blocking row above 编辑精选 / 附近活动 / 即将上线. Those rails are in the same order. The hero search field is the only search field.

The card is passed only while a signed-in player with usage consent and account-compliance writes still needs a home-city decision, and this device has not saved “暂不定位”. No row, or any event that is not a current agreement or a revoke, asks. A current agreement is `privacy_policy` / `home_city_location` / `AGREE` at privacy version `v2.1` with a request id. A revoke hides the card. A failed latest read hides it. Guests and a compliance build that cannot record stay hidden.

Agree calls the existing consent recorder (`AccountComplianceService.consent`) for `privacy_policy` / `home_city_location` / `AGREE`, including `expectedRequestId` from the latest row (empty when there is no row). Decline calls `saveLocationDeclined(true)` and does not record consent. Agree clears that local flag with `saveLocationDeclined(false)`. The storage key is `home_city_location_declined`.

A failed save shows `homeCityConsent.saveFailed` (EN “Location consent was not saved. Try again.” / zh-Hans “定位同意记录未保存，请重试”). The card copy that was already in the catalog is unchanged.

A blank city token or the word UNKNOWN is an em dash (`—`, `homeCityConsent.unknown` in both EN and zh-Hans). That does not replace the hero city label and does not invent 上海市.

Device location and reverse geocode are not started. This row records the consent decision.

## Files

- `App/SessionHomeFeedView.swift` passes the card handlers.
- `App/HomeCityLocationConsentHost.swift` stores the decline and calls the recorder.
- `Core/HomeCityLocationConsent.swift` is the ask / expected-request-id / echo rule.
- `Core/AccountComplianceContracts.swift` adds `ComplianceSubject.homeCityLocation`.
- `Core/AccountComplianceService.swift` and `Core/AccountComplianceCoordinator.swift` perform the latest read and the agree write.
- `App/AppSession.swift` allows that subject on the existing legal-approval line. The file stays 8176 lines. `App/AppCompositionRoot.swift` is not edited (4307 lines).

`docs/release/contract-failing-baseline.txt` is not changed.
