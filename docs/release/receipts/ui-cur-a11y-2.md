# ui-cur-a11y-2

Accessibility only, on the screens handovers 59–64 added. Those screens were not on `origin/ui/main` `3ac970ec20191014b4b9a8779a3a94b961e99c9c`. This branch merged them in, then labeled the player-visible controls with the copy already on each screen.

## Merged

| Branch | SHA |
|---|---|
| `ui/cur-fixtures-6` | `e18da8f4860439030041d1708afa3ee10cecab01` |
| `ui/cur-fixtures-7` | `631d5aeaaee45b080240b08245517cf3e2c46e1b` |

Conflicts kept both sides where both added a fixture symbol, an exclusion name, or an Xcode project entry. `CurFixtures6.swift` and `Cur7Fixtures.swift` both stay, and both stay on the Release exclusion list. No `Cur*` fixture file was deleted. The features were not reimplemented. Handovers 63 and 64 were not redone.

`App/RegionalLaunchConfiguration.swift` is the fixtures-7 merge as it arrived, including `ReadRetryHTTPTransport`. This accessibility pass did not edit it. No methods were added to `App/AppSession.swift` or `App/AppCompositionRoot.swift`. `docs/release/contract-failing-baseline.txt` was not raised. `ReviewedAreaSwitch` was not redeclared. Money stays behind that switch. `www.chengyinhub.com` stays closed.

Unknown stays an em dash (`—`). A decoded `0` stays `0` (price fields, shelf counts already on screen, character Strength, momentum `0/5`, merchant revenue `¥0.00`, sync failure count `0`). An error code `0` is still the catalog em dash, which is the sentence those notices already show.

`swiftc` is not on this machine. This receipt does not claim a typecheck or an XCTest run. `python3 tools/check_scaffold.py` PASS. `python3 tools/check_design_lint.py` PASS. `python3 tools/check_design_fixture_release_exclusion.py` PASS.

## Screens labeled

Each control below gained an accessibility label, value, and hint from copy already on that screen.

| Screen | Where |
|---|---|
| Permission pre-prompt (location, camera, notifications, photos; priming and denied) | `CYPermissionPrimer` primary and secondary buttons. The label is the button title, the value is the card title, the hint is the card body. |
| Photos denied Open Settings | `RoamHistoryShareView`, `RoamMedalShareView`, `RoamStampSlipSaveRow` |
| Camera denied Open Settings | `PlayKitCameraOverlayButton`, `PlayKitSpatialRevealButton`, `NativeQRScanner`, `RoamStampCameraView` |
| Location denied Open Settings | `RoamLiveSessionView`, `NearbyMerchantView`, `PlayLocationCaptureIssueView` |
| Invite reminder | `IMInviteReminderToggle` and its Settings button. Unknown stays the existing em dash, spoken with `mpd.im.inviteReminder.unknownLabel`. |
| Usage consent gate | Agree, decline, both document links, review, and the legal-sheet close button |
| Privacy protection | Guide, agreement, consent status, withdraw |
| Privacy and location, home city | On and off, plus the confirm and decline buttons. No saved setting is `—`. |
| Cancellation time | `DeregistrationExecuteAfterRow`. A missing time is `—`. The hint is the existing server-decides line. |
| Cancellation pending and unknown step | Withdraw button, and the unknown step. The missing execute time stays on the time row as `—`. |
| Pledge error notice | `PledgeNoticeText`. The spoken sentence is `BackendErrorCatalog.playerFacing`, including `—` for blank, `0`, and `unknown`. |
| Search filters | List sort (最近 / Recent only), minimum and maximum. An empty bound is `—`. A typed `0` or `0.0` stays that text. |
| Discovery shelf | Search fields, shelf chips, 全部分类 sheet, clear filters, clear topic name. |
| Offline banners | `CYStatusOfflineBanner` (kept its existing label), `SearchMapOfflineBannerView`, and the queued-write sync control. A missing cache time is `—`. |
| Sync status | The roam session uses `CYStatusOfflineBanner` with `roam.sync.offline`. Failure count `0` is not rewritten. |
| Challenge POI | Progress, photo field, confirm photo, choices, answer field, verify receipt, submit. An unknown submission value is `—`. |
| My-project mutations | Done, failed, unavailable, confirm, and cancel. An empty failure sentence is `—`. |
| Merchant home chip | Business-status chip. The value is the open or closed title already on the chip. Closed is the decoded `0`, not an em dash. Revenue value is `MerchantMoney.display` (`—` or `¥0.00`). |
| Character sheet detail | Header status, dice, attribute rows (a missing level is `—`; Strength `0` stays `0`), momentum and trait rows, and the unknown phase (`CharacterCardPageModel.unknownStat`, already `—`). |
| NPC chat export | Export button. A null record time stays `—` inside the existing readable text. `createTime` `0` is not rewritten. |

## Not present

These were named in handovers 59–64 and are not screens on the merged tree. None was invented.

| Screen | Reason |
|---|---|
| Minor protection | No mini-program screen. Handover 61 did not add one. |
| Anti-addiction | No mini-program screen. Handover 61 did not add one. |
| Privacy-policy body | Not in the mini-program repo. `cur6-privacy-policy-missing` still shows the missing reader. No clause was added. |
| Play-only 300-meter location modal | Not copied onto the global permission card. |
| Search-list 最热 | Not in the rendered search-list sheet. Not added. |
