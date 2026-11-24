# cursor/core-play-roam — Core play-roam

Base: `origin/ui/combined-r7` `7fdfad1f177fadb76f7fd54a82b27fa69b82f1f8`.
Area: `play-roam` Core and Core tests only. No App screen edits. No `project.pbxproj`. No `tools/current_ci_manifest.json`. No new Swift folder, so `tools/generate_project.py` is unchanged (`Core/*.swift` and `Core/MPGap/**/*.swift` already glob).
`RuntimeLocationProjection` is untouched. `PlayStageAnalyticsGate.enabled` stays `false`. `POOL_TRIM` stays off (`poolTrimEnabled` default `false`).
Money stays off: `JourneyLoopSource.moneyWritesEnabled` is `false`, and `giftClaim` still throws `JourneyRefusal.moneyOff` before any HTTP.
swiftc was not run. This receipt does not claim a parse.

Mini-program source: public `liboyang42-cpu/hengyin` `chengyinhub-xcx` (`subpackageJourney/utils/journey-api.js`, `utils/journey-view.js`, `utils/roam-passport-read.js`, and the play-roam pages). There is no top-level `api/` folder.

## Closed (Cursor)

| ID | What Core now does |
|---|---|
| RHIST-r7-1 | Removed `PlayRoamRound2Service.fetchRoamHistory` and `api/roam/history/list`. Merged history stays `GET /api/roam/passport/history` via `RoamPassportHistoryReadRoute` (`before` then `limit=30`; `"0"` is rejected). |
| JREPORT-5 | `JourneyEnvelope.reasonCode` is the top-level string only. `JourneyReportRead.reject` : 401 → auth; report `RUN_NOT_FOUND` or `RUN_SCOPE_MISMATCH` → gone; report 403 → denied; settle only `RUN_NOT_FOUND` → gone; every other non-OK is failed (暂未加载), including a 404 without those reason codes. `runDisagrees` is gone on both surfaces when both run ids are present and differ. |
| JREPORT-3 | Rank wire is `GET /api/rank/list` with `scope`, `scopeId`, `period` only (`JourneyRankBoard.query` / `idQuery`). `topicId`, `cityCode`, `teamId` are not sent. `JourneyRankBoard.menu` puts quest and team on the tabs and city, country, world, club in 更多. Country codes are uppercased when they are two letters. `teamID(choicesJSON:)` is the first `choices[].teamCapacity.teamId` that is an id. `LinkCodes.parse` keeps raw `cityCode` / `countryCode` and keeps `clubId` only when it is an id. |
| JREPORT-2 field | `PostGameRunReport.Node.photoURL` from `photoUrl`. Empty stays nil. The row mount is App. |
| JSETTLE-4 | `assistedCount` counts nodes whose mode is SKIPPED or REVEALED. `showsAssistedCount` is that count above 0. `startModeText` is 桌面完成 for DESK and 替代站开局 for ALT. Anything else, including a missing field, is nil. `showsStartMode` is that label. |
| PLAYM-2 | `PlayStoreDayNode.perk` is `{name, redeemRule, redeemBlockedText}`. All empty → nil. `redeemBlockedNotice` is the blocked text only while `!done`. |
| JSEAT-6 | `JourneySeatsSessionGate`: no valid session → `.auth`. 403 → `.denied`. Other non-OK → `.failed`. OK with `data` → `.ready`. |
| JSEAT-r7-1 | `JourneyHeldSeatInviteRule.hold` keeps `invitationId` + `token` only when both are valid. `afterRead` drops the hold unless that seat is still `INVITED`. |
| RPOI-3 | `RoamPendingCheckInJournal` in `PlayRoamRound2Models.swift`. Key `cy_roam_poi_checkin_pending:v1:{owner}:{poi}`. Record is `v`, `ownerId`, `poiId`, `attemptId`, `uncertain`. No coordinates, answers, photos, or scan text. Photo sibling is `:photo`. Fresh begin needs an empty slot. Reverify reuses the attempt and sets `uncertain`. `markUncertain` only flips an existing certain record. `clear` removes the record and `:photo` only when the attempt matches. `step` : a known 500 prewrite rejection while `unknownBefore` is `.keepPreviousUnknown` and does not clear. `receiptAccepted` is the page `ok` for `POST /api/city/nodes/{poiId}/complete` (code `"200"`, matching poi when present, coupon when `needRedeem`, bool `needRedeem`, `completed` null or a bool that differs from `needRedeem`, `alreadyClaimed` null or a bool). |
| JLAND-r7-1 | `JourneyGiftClaimBody.fields` is `{token, requestId}` for `POST /api/marketing/product/gifts/claim`. It is not sent. Store key `JourneyRequestKey.giftClaim` is `journey-claim:gift:` + the last 24 of the token. `JourneyLandingClaim` classifies an envelope only: unconfirmed keeps the id (查询领取结果); refused drops it; seat refused may offer 自己购买; gift claimed can view only when the target id is an id; seat claimed carries `seatNo`. |

Core tests: `Tests/CoreTests/PlayRoamCoreContractTests.swift` (history GET, rank GET, gift claim not sent, report/settle reason codes, seats gate, invite hold, rank menu, pending journal). `PostGameReportTests.testAssistedCountStartModeAndNodePhoto`. `PlayStoreDayTests.testPerkDecodesNameRuleAndBlockedText`. `MPGapG1Round2Tests` no longer calls `fetchRoamHistory` and still expects the four remaining paths.

## App caller notes for the Claude F-agent

Do not mount parked `App/MPGap`. Do not redo the P2/P4 mounts on `cursor/r7-wiring`.

- PLAYM-2: `PlayStoreDayMerchantView` shows 本店权益 when `perk.name` is set, subtitle `redeemRule`, and replaces the primary CTA with `redeemBlockedNotice` when that string is non-nil.
- JSEAT-6: `PlayerJourneySeatsModel.reload` (`PlayerJourneyReadBindings.swift`) currently sets `.denied` when there is no token. Use `JourneySeatsSessionGate`. No valid token → `.auth`. Add that phase and a 登录 path through `PlayerJourneySignInBridge`, then reload when the sheet closes. Keep `.denied` for 403 only. `JourneySeatsPhase` has no `.auth` today.
- JSEAT-r7-1: After `seatInvite` succeeds, store `JourneyHeldSeatInviteRule.hold(invitationID:token:)`, not only the URL. After each seats read, replace the hold with `afterRead`. A claimed, expired, or missing seat clears `inviteURL` so the next 邀请 mints a fresh token.
- JSETTLE-4: `JourneyReportViews` shows the assisted cell only when `showsAssistedCount`, and the start-mode cell only when `showsStartMode`. Labels are the strings already on the report (桌面完成 / 替代站开局).
- JREPORT-2: `PostGameRunReport.Node.photoURL` is ready. `JourneyNodeRow` still has no photo URL. Mount the viewer in App.
- JREPORT-3: `JourneyRunScope` (`App/MPParityKit.swift`) needs `cityCode`, `countryCode`, and `clubID` from `JourneyRankBoard.LinkCodes.parse`. After the report is ready, the choices read feeds `JourneyRankBoard.teamID`. Tabs and 更多 come from `JourneyRankBoard.menu`. `playerJourneyRank` currently returns `.empty` for city, country, and club. Call `JourneyLoopSource.rank(scope:scopeID:period:)` or `PlayRoamRound2Service.fetchLeaderboard` with `scopeID`. Do not send `topicId` / `cityCode` / `teamId` as query keys.
- JREPORT-5: `PlayerJourneyProjection.report` and the settle reload must use `JourneyReportRead.reject`. A non-OK that is not auth, 403, or a reason-code gone is `.failed` (暂未加载 + 重新加载), not `.missing` (链接已失效). A 404 without `RUN_NOT_FOUND` / `RUN_SCOPE_MISMATCH` is failed, not gone. Settle treats only `RUN_NOT_FOUND` as gone (`RUN_SCOPE_MISMATCH` on settle is failed unless the run ids disagree). `runDisagrees` → gone on both.
- JLAND-r7-1: Use `JourneyLandingClaim` when the owner opens claims. Core `giftClaim` still throws `moneyOff`. Request id key is `JourneyRequestKey.giftClaim`. Unconfirmed keeps the id and the button 查询领取结果. Refused drops the id. Seat refused may offer 自己购买 when an activity or topic id exists. Gift claimed → 礼物已领取, and 去看看 only if the target id is an id. Seat claimed → seat number and 进入本局. Account switch re-reads (`landing` `onShow`) stay in App. `MPCommerceGate.claimsEnabled` stays false.
- RPOI-3: `RoamPOIActions` / the detail screen use `RoamPendingCheckInJournal`, not the parked `PlayRoamRound2Views` pending UI. 查询当前状态 reloads the node. 重新现场核验 is `begin` with `reverify` and the same attempt. Do not persist coordinates, answers, photos, or scan text in the pending record. A late prewrite rejection must not clear an uncertain record (`step` == `.keepPreviousUnknown`).
- RHIST-r7-1: Delete any caller of `fetchRoamHistory`. Merged history reads `RoamPassportHistoryCoordinator` / `RoamPassportHistoryReadRoute`. Do not mount Gemini’s `GET api/roam/history/list`.

## Skipped as in flight or out of this lane

- `restyle/r5-play-roam-city`, `gap/g1-player`, `gap/g2-ops`, `port/p1`–`port/p6`.
- P2/P4 mounts. `cursor/r7-wiring` was not present to redo.
- B-10 (`PlayArrivalService`): `.server` already uses `playArrival.rejected` and keeps `message` separate. No change.
- g1 `PlayerJourneyService.completed` already POSTs `api/play/my-completed` through `AuthRequestBuilder.makeFormRequest`. Not flipped to GET. `completedForPublicReference` is a different GET.
- Review A had no findings table. Review C F-C05 invented routes are Gemini/owner.

## Leftovers

- Owner P0: RSTAMP-2, SCAM-1, SALBUM-1 (media upload, stamp exchange, stamp image hosts).
- Owner P1: ROAM-7 guest nearby, RPOI-4 share / universal link, RPOI-5 and RROUTES-2 glossary, JSEAT-8 empty bar title, and opening the landing money gate.
- Gemini: ROAM-13 city strip and the invented `fetchCityStrip`, RNEAR-2, JSETTLE-r7-1 完局优惠卡, BWALL-2/3, B3D-1, OCARDS-2. F-C05: `api/roam/city-strip`, `api/roam/stamp/album` (MP is POST `api/roam/stamp/list`), `api/roam/greet`. SALBUM-6 must not mount the GET album helper.
- Claude: the P1 UI rows and the App caller list above. RTEAMS-3: do not use `fetchTeamApplications` (GET); the existing POST applicants load stays. PLAYC-r7-1 `inviteCode` / `registrationId` is an App deep link.
- g1 still unwired, and not confirmed against the mini-program this pass: `api/play/run/profile`, `api/topic/cast/voice`, `api/play/run/branch`. The gap doc listed those methods as POST/GET.
- JSETTLE-1 / JREPORT-1 referral token stays `moneyOff`.
