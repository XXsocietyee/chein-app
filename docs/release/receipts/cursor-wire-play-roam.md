# cursor/wire-play-roam

Base: `origin/ui/combined-r7` `82388e4a5e7391e0c5a286735d6b30613a860ae8`.

Merged before the wiring commit, screen work kept:

- `origin/fix/r3-play-roam-a` `c3962da048e980d4644bf0773fb172fae8a1417e`
- `origin/fix/r3-play-roam-b` `45e4ff27d363912672667c4b59fd0bcb09f02a8f`

Caller list is `docs/release/receipts/cursor-core-play-roam.md`, plus PLAYC-r7-1. Rank board type used here is `JourneyRankBoardContract`. `struct JourneyRankBoard` in `App/JourneyReportViews.swift` was not duplicated.

This VM has no `swiftc` or `xcodebuild`. This receipt does not claim a parse. `python3 tools/check_typography_lint.py` passed (444 counts below baseline, baseline not ratcheted).

## Call sites

| ID | Wired | Where |
|---|---|---|
| PLAYM-2 | yes | `App/PlayStoreDayMerchantView.swift`. When `perk.name` is set, a 本店权益 block shows the name and `redeemRule`. A non-nil `redeemBlockedNotice` replaces the primary button. Copy is verbatim, not a `playStoreDay.*` catalog key. |
| JSEAT-6 | yes | `PlayerJourneySeatsModel.reload` in `App/PlayerJourneyReadBindings.swift` uses `JourneySeatsSessionGate`. No valid token → `.auth`. 403 → `.denied`. Any other non-OK → `.failed`. `JourneyRefusal.invalidRequest` stays `.missing`. The sign-in sheet and its reload stay the ones from `fix/r3-play-roam-b`. |
| JSEAT-r7-1 | yes | After `seatInvite` succeeds, `JourneyHeldSeatInviteRule.hold(invitationID:token:)` is stored. After each seats read, `afterRead` replaces it. A claimed, expired, or missing seat clears `inviteURL`. |
| JSETTLE-4 | yes | `JourneySettleView` in `App/JourneyReportViews.swift` shows the assisted cell only when `showsAssistedCount`, and the start-mode cell only when `showsStartMode`. The words are the report strings (桌面完成 / 替代站开局). The `r3prb-settle-assisted` fixture sets `assistedCount: 2` and `startModeText: "桌面完成"` so that screen still shows both. |
| JREPORT-2 | yes | `JourneyNodeRow.photoURL` comes from `PostGameRunReport.Node.photoURL`. An https URL opens a sheet in `JourneyReportView` (`mp.report.photos.title`, close, `AsyncImage`). `App/MPGap` `JourneyReportNodePhotoViewerSheet` is not mounted. |
| JREPORT-3 | yes | `JourneyRunScope` in `App/MPParityKit.swift` stores `cityCode`, `countryCode`, and `clubID` from `JourneyRankBoardContract.LinkCodes.parse`. After the report is ready, `choices` feeds `JourneyRankBoardContract.teamID`. Tabs and 更多 come from `JourneyRankBoardContract.menu`. `playerJourneyRank` calls `JourneyLoopSource.rank(scope:scopeID:period:)` for quest, team, city, country, club, and world. The teams probe (`/api/orient/team/ranking`) is unchanged. Settle stays 全体 + 队内, `more` empty. |
| JREPORT-5 | yes | `PlayerJourneyProjection.report` and the settle reload call `JourneyReportRead.reject` with `.report` or `.settle`. Non-OK that is not auth, 403, or a gone reason is `.failed`. A 404 without `RUN_NOT_FOUND` / `RUN_SCOPE_MISMATCH` is failed. Settle treats only `RUN_NOT_FOUND` as gone. `runDisagrees` is gone on both. Missing activity and topic before the request stays `.missing`. An undecodable OK body is `.failed`. |
| JLAND-r7-1 | yes | `PlayerJourneyLandingModel.primary` in `App/PlayerJourneyReadBindings.swift`. 去看看, 自己购买, and 进入本局 open the existing routes. Gift and seat claim run only while `MPCommerceGate.claimsEnabled` is true. That flag is still `false`, so neither request is sent. `giftClaim` still throws `JourneyRefusal.moneyOff` before HTTP. The unsent body is `JourneyGiftClaimBody.fields`. The request id key is `JourneyRequestKey.giftClaim`. `JourneyLandingHost` re-reads when the sign-in sheet closes. |
| RPOI-3 | yes | `RoamPOIActionModel` / `RoamPOIActionRows` in `App/RoamPOIActions.swift`, reloaded from `App/RoamItemDetailView.swift`. The journal is `RoamPendingCheckInJournal` (`cy_roam_poi_checkin_pending:v1:{owner}:{poi}`). Owner is `reader.identity.accountID` when it is an id; with no owner the journal is skipped. 查询当前状态 reloads the node. 重新现场核验 calls `begin` with `reverify` and the same attempt. Coordinates, answers, photos, and scan text are not stored, and the `:photo` sibling is not written. A fresh begin is rolled back on location or sign-in failure. `step == .keepPreviousUnknown` does not clear the record. `unknownOutcome` becomes `.unknown` and `markUncertain`. A success receipt uses `needRedeem`, `alreadyClaimed`, `poiId`, and `completed` (`true` only when `!needRedeem`). No `couponId` is invented, so `needRedeem == true` fails `receiptAccepted` and stays uncertain. `Core/RoamService` was not edited. Parked `App/MPGap` pending UI was not mounted. |
| RHIST-r7-1 | already absent | No caller of `fetchRoamHistory`. `GET api/roam/history/list` was not mounted. No edit. |
| PLAYC-r7-1 | yes, from the merged A commit | `App/MPReviewedPageScreen.swift` passes `inviteCode` / `registrationID` into `SessionPlayRuntimeView`. `App/SessionPlayRuntimeView.swift` calls `circle.open(inviteCode:)` once, after `loadOffers()`. Not redone. |

## Left as they were

- `giftClaim` throws `JourneyRefusal.moneyOff` and sends nothing.
- `MPCommerceGate.claimsEnabled` stays `false`.
- `PlayStageAnalyticsGate.enabled` stays `false`.
- `POOL_TRIM` / `poolTrimEnabled` stays default `false`.
- `RuntimeLocationProjection` was not edited.
- `FreeExplorationStoreView` `arrivalLocation:` stays the last argument in `PlayExperienceView.freeStoreDestination`.
- Cast modifiers stay on `PlayExperienceCastMounts` / `castMounts(_:)`. They were not moved back into `PlayExperienceView.body`. `PlayStoryMapGround` from `fix/r3-play-roam-a` stays.
- `project.pbxproj` and `tools/current_ci_manifest.json` were not edited.
- No new Core type. No second `JourneyRankBoard`.
