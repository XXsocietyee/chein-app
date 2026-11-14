# ui-cur-uitests

One XCUITest golden path per journey named for this task. `docs/release/workflows.md` is not in this tree (`origin/ui/main` `3e2dca3ec5d5c732ea7d286cbb0fe856944ffce6`). The journeys below are the ones named in the task. No journey was skipped.

The tests are in `Tests/AppUITests/WorkflowJourneyGoldenPathUITests.swift`. Each one launches an existing DEBUG fixture. This change does not add a transport, a fixture host, or a success response. Money, payout, merchant writes, and password login stay off. `ReviewedAreaSwitch` was not redeclared. `App/RegionalLaunchConfiguration.swift`, `App/AppSession.swift`, `App/AppCompositionRoot.swift`, and `docs/release/contract-failing-baseline.txt` were not edited.

XCUITest was not executed. This workspace has no `swiftc`. `python3 tools/check_scaffold.py` and `python3 tools/check_design_lint.py` were run on this tree. No curl was run.

| Journey | Test method | Fixture |
|---|---|---|
| Sign up / login | `testSignUpLoginShowsThePhoneFormAndDoesNotSend` | `--design-fixture e4-auth-phone` in English and zh-Hans. The phone form is prefilled (`13812345678`, three code digits, cooldown). Send and sign-in stay disabled. The password control `auth.signIn` is absent. |
| Discover → activity sign-up | `testDiscoverOpensAnActivityThenRegistrationReviewsOffline` | `--uitesting-module home-feed` (`content`) opens `homeFeed.nearby.activity.7`. That host stops at the synthetic activity destination and does not mount `SessionRegistrationSheet`. The sign-up half is the existing `--uitesting-registration-fixture standard` sheet: consent, review, `Create demo registration`, then `registration.form.readStatus`. No Pay control. |
| Play session, including team | `testPlaySessionOpensATaskAndTheTeamBackpack` | `--uitesting-module playExperience` scenario `classic` opens `playx.node.701` (`Journey task`) and does not confirm. `--uitesting-module playTeamBackpack` shows `play.teamBackpack.item.tea`. |
| Roam | `testRoamHomeThenHistorySession` | `--uitesting-roam-home` scenario `content` shows `roam.home.tabs`. `--uitesting-roam-experience` scenario `content` opens history and `roam.experience.session` (`Saved local journey`). |
| City | `testCityAcquireReviewCanBeCancelled` | `--uitesting-module cityGame`. Acquire review opens, then Cancel. `cityGame.recorder.submissions` stays `0`. No pay control. |
| Club / channel / IM | `testClubChannelAndDirectMessageFixtures` | `--club-community-fixture` shows post `20` and opens the composer, then Cancel (no confirm). `--design-fixture d4-channel-chat` shows the seeded channel line. `--im-expanded-fixture message-success` (last argument) opens `messaging.conversation.901` to `messaging.message.10`. |
| Community post | `testCommunityPostSavesOnDeviceAndDoesNotPublish` | `--uitesting-module square-workspace`. Local save reports `Saved on this device`. `squareWorkspace.saveServer` stays disabled. |
| Creator publish + review status | `testCreatorReviewCanBeCancelledAndStatusStaysApproved` | `--uitesting-module projectEdit` reviews a name and cancels. It does not show “Simulation completed. No project was published.” `--uitesting-module creatorContent` opens the center; status is `Approved creator`. |
| External game submit / catalog | `testExternalGameCatalogAndSubmissionsFailClosed` | `--design-fixture e5-external-game` (`ExternalGameLibrarySection` with no session). Catalog and My submissions show the fail-closed errors, not the empty-success lines. `externalGame.submitReview` is on screen and is not tapped: it opens the system file importer, and this fixture has no offline archive. No catalog or submission success is claimed. |
| Merchant | `testMerchantCustomerTimelineOpensWithoutAWrite` | `--uitesting-merchant-business-fixture` scenario `ready`. Customers → customer `61001` shows `Example follow-up`. No note is submitted. |
| Wallet | `testWalletIncomeDetailOpensWithoutPay` | `--wallet-commerce-fixture`. Income row `wallet.income.detail.open.4` opens. No Pay control. |
| Report / appeal | `testReportStaysUnsubmittedAndAppealReasonCanCancel` | `--uitesting-profile-complaint` scenario `content` reaches `profile.complaint.notSubmitted` and has no submit control. `--square-governance-fixture` opens appeal `91` and Cancel. `square.gov.confirm` is absent. |
| Account deletion | `testAccountDeletionReviewShowsImpactAndDoesNotComplete` | `--design-fixture e4-deregister` (`E4ComplianceFixture` review step, stub transport). The review warning and the points impact line are on screen. `compliance.completed` and `compliance.cancellationConfirmed` are absent. The type-to-confirm control is not used. |

## Skipped

None. Every named journey has an existing DEBUG fixture that mounts a screen with no network.
