# CB250 PAGE-READY — pages/club/notify/index

俱乐部群发通知. Map status stays `exists` on `App/ClubOpsNotifySections.swift`. This lane does not edit a view.

- Contract already in the repo: `ClubGovernanceRead.audienceCounts` is `api/club/event-notification/audience-counts`, `notificationPreview` is `api/club/event-notification/preview`, and `notificationStatus` is `api/club/event-notification/status`. Send and retry stay `ClubGovernanceMutation.sendNotification` and `retryNotification`. `ClubNotifyPage.routeMarkedLive`, `sendMarkedLive`, and `retryMarkedLive` are false. No route was added. `api/club/notices` is not wired.
- Capability: `ClubNotifyCapability` follows `club:notify:send` for club broadcast and `club:event:operate` only when the scope already has an activity. A missing grant stays hidden and does not call the reader. `includedInPlayerFirstEntry` is false. The page is not on the player-first welcome or search entry.
- Model: `ClubNotifyPage` and `ClubNotifyDeliveryPage` in `Core/ClubOpsNotifyPresentation.swift` have loading, empty, error, unknown, and ready. Unknown, null, a numeric string, a decimal, and a negative display `—`. A literal JSON 0 stays `0`. The older `ClubOpsNotifyCampaign` null-to-0 receipt path is unchanged.
- Broadcast: `broadcastOffered` needs the notify grant and a revealed audience fact. An all-zero audience does not offer it. Event audiences are not opened by the club-wide grant. Retry needs a known status and a known failed count greater than 0. This model never sends.
- Tests: `testNotifyPageStaysHiddenWithoutTheBroadcastGrant`, `testAudienceLoadingEmptyReadyAndLiteralZero`, `testUnknownAudienceCountsAreEmDashNeverZero`, `testDeliveryUnknownIsEmDashWhileLiteralZeroStaysZero`, and `testLoadUsesTheExistingReadsAndDoesNotSend` in `Tests/CoreTests/ClubNotifyPageTests.swift`. `test_page_uses_existing_routes_and_stays_off_player_entry` and `test_unknown_counts_are_an_em_dash_and_broadcast_stays_gated` in `Tests/ContractChecks/test_club_notify_page_ready.py`.
- Fixture: `ClubNotifyFixtureData` is compiled only inside `#if DEBUG`.

## Missing EN + zh-Hans keys

None. The screen and this model use keys that already have `en` and `zh-Hans` in the `translated` state. No catalog key was added.

| Key | Catalog |
|---|---|
| `club.loading` | `Resources/Localizable.xcstrings` |
| `club.audience.chooseEvent` | `Resources/Localizable.xcstrings` (the screen's table). `Resources/ClubNotificationAudience.xcstrings` has a different bilingual pair for the same key and is not the table this screen reads. |
| `club.audience.countsUnavailable` | `Resources/Localizable.xcstrings` |
| `club.gov.denied`, `club.gov.refresh`, `club.gov.deliveryPending`, `club.gov.unavailable`, `club.gov.signedOut`, `club.gov.malformed`, `club.gov.changed`, `club.gov.busy`, `club.gov.unknown`, `club.gov.conflict`, `club.gov.invalid`, `club.gov.rejected` | `Resources/Localizable.xcstrings` |
| `club.gov.choice.ALL_MEMBERS`, `ADMINS`, `REGISTERED`, `WAITLIST`, `NO_SHOW`, `INACTIVE` | `Resources/Localizable.xcstrings` |
| `action.retry` | `Resources/Localizable.xcstrings` |
| `clubOpsJN.notify.*` including `people %lld`, phase, preview, fields, and send/retry outcomes | `Resources/ClubOpsJoinNotify.xcstrings` |
| `clubOpsNotify.denied.title`, `clubOpsNotify.denied.body`, `clubOpsNotify.failed`, `clubOpsNotify.retry` | `Resources/ClubOpsJoinNotify.xcstrings` |

`ClubNotifyPage.Copy` reuses `club.loading`, `clubOpsJN.notify.preview.empty`, `clubOpsNotify.failed`, `clubOpsNotify.retry`, and `clubOpsNotify.denied.title` / `body`. The em dash is not a catalog key.

Left: `App/ClubOpsNotifySections.swift` and `App/ClubNotificationAudienceView.swift` still use `ClubOpsNotifyCampaign` and a blank null count. Binding these phases is a later view change. `WelcomeView.showsMerchantChoice` and the four money switches stay false. Xcode was not run. No Xcode Cloud result is claimed.
