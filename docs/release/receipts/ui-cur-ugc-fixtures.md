# ui-cur-ugc-fixtures — App Store 1.2 safety fixtures

Branch `ui/cur-ugc-fixtures`, cut from `ui/h-ugc` at `ac61545ebb471416f514597b3ce99bce880f8cb4`. That tip had not moved.

DEBUG only. Launch with `--design-fixture ugc-<id>`. Each screen mounts the existing `UGCSafetyComponents` (report sheet, block confirm, blocked-content placeholder, moderation precheck notice, support contact) for one named surface. The in-process service returns the fallback report reasons, an empty block list, and a local precheck result. It builds no URL and does not send to `www.chengyinhub.com`.

Unknown author text is an em dash (`—`). A member id of 0 stays `0`. Workshop money is a label behind the existing `ReviewedAreaSwitch.moneyPayments(apiHost:)`. The closed fixture passes `ReviewedAreaSwitch.productionAPIHost`, so the amount is an em dash. The switch is not redeclared.

`App/RegionalLaunchConfiguration.swift`, `App/AppSession.swift`, and `App/AppCompositionRoot.swift` were not edited. `docs/release/contract-failing-baseline.txt` was not raised.

## Surfaces

All ten named surfaces are on this tip. None are listed as not present.

| Surface | On this tip | Fixture ids | Normal | Non-happy |
|---|---|---|---|---|
| Square | `SquareBrowserView`, `SquareDetailView` | `ugc-square`, `ugc-square-hidden` | post visible, report footer, block confirm | author already blocked, placeholder replaces the post |
| Club post | `ClubCommunityViews` | `ugc-club-post`, `ugc-club-post-signed-out` | post visible, safety menu | no token; block reports the existing signed-out copy |
| Club comment | `ClubPostDiscussion`, `ClubCommunityViews` | `ugc-club-comment`, `ugc-club-comment-hidden` | comment visible, safety menu | author already blocked |
| Club channel | `ClubChannelMessagingView` | `ugc-club-channel`, `ugc-club-channel-precheck` | channel line visible, safety menu | local precheck refused; the detail line is an em dash |
| IM DM | `MessagingHomeView`, `MessagingHistoryView` | `ugc-im-dm`, `ugc-im-dm-hidden` | direct-message line visible, safety menu | sender already blocked |
| Profile | `SocialPublicProfileView` | `ugc-profile`, `ugc-profile-blocked` | profile actions and a post | blocked banner, post hidden |
| Topic review | `TopicReviewsContent`, `TopicDetailView` | `ugc-topic-review`, `ugc-topic-review-unknown` | review visible, report footer | author unknown (`—`), member id `0` |
| Template | `DiscoveryTemplateDetailView` | `ugc-template`, `ugc-template-precheck` | template line visible, safety menu | local precheck refused; the detail line is an em dash |
| Merchant review | `PublicMerchantReviewsView` | `ugc-merchant-review`, `ugc-merchant-review-hidden` | review visible, safety menu, merchant light theme | author already blocked |
| Workshop mod | `WorkshopPurchasedLibraryView` | `ugc-workshop-mod`, `ugc-workshop-mod-closed` | mod line visible; amount `12.00` because `fixture.example` opens the switch in DEBUG | host `www.chengyinhub.com`, amount `—`, no pay control |

Accessibility labels use copy that was already on the screen: `UGCSafety` catalog keys on the shared report, block, unblock, support, and moderation notice; `square.report` / `square.block` / `social.actions`; `club.community.report`; the channel strings already passed to `copy(...)`; `im.chat.more` and its item titles; `im.safety.hide.rowAction`; `merchant.publicHome.report`.

## UI test

`Tests/AppUITests/UGCSafetyFixtureFlowTests.swift` launches `--design-fixture ugc-square`. It taps report, checks that the sheet’s submit button is on screen, dismisses with Close, taps block, confirms, and expects the post identifier to disappear behind `ugc.safety.blockedBanner`. It does not tap `ugc.safety.submitReportButton` and does not open the support contact.

This VM cannot run XCUITest. The test was not run. `swiftc` is absent. This receipt does not claim a typecheck.

## Gates

- `python3 tools/generate_project.py` registers the new fixture and the UI test.
- `python3 tools/check_design_fixture_release_exclusion.py --write`, then the check without `--write`.
- `python3 tools/check_scaffold.py` and `python3 tools/check_design_lint.py` before push.
