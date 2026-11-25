# cursor/r8-play-roam

Base: `origin/ui/combined-r7` `f5f3006d781ac4d61c225a079ef74e2e2a86befd` (Integrate Cursor round 5). Branched from that SHA. Not rebased.
Area: Core and Core/contract tests only. No App screen edits. No `AppSession.swift`. No `AppCompositionRoot.swift`. No `RuntimeLocationProjection`. No `project.pbxproj`. No `tools/current_ci_manifest.json`.
swiftc was not run. This receipt does not claim a parse.

Mini-program source: public `liboyang42-cpu/hengyin` `chengyinhub-xcx` at `3a131849`.
`pages/roam/index.js:210` is `community.request({` inside `function req`. It is not a URL. No path was invented from that line. Nearby runners are the call at `_fetchRunners` (`POST /api/roam/nearby-runners` with `lat`, `lng`, `radius`). There is no greet request on that page.

## Rows taken

| ID | Owner | What Core does |
|---|---|---|
| RSTAMP-2 | owner decision, Core switch | `RoamExperienceCapabilities.stampExchange` and `mediaUpload` are `true`. Create fields are always `picUrl`, `caption` (including `""`), `idempotencyKey`. Exchange field stays `givenStampId`. |
| SCAM-1 | owner decision, same switch | `StampCameraPageContract.showsCreate` / `showsExchange` follow those flags, so the paths are `api/roam/stamp/create` and `api/roam/stamp/exchange`. `registersRoute` and `marksRouteLive` stay false. |
| ROAM-8 | Cursor Core | `RoamPassportHome.latestTrackThumbnail` and `latestStampImage` port `utils/roam-passport-tiles.js` from local history. Empty string means the page keeps its illustration. No `/api/medal/wall` fetch. |
| RTEAMS-3b | Cursor Core | `NearbyLeaderApplicantFact` for a recruiting team the viewer leads. Count is the existing `POST /api/team/applications` JSON `{teamId}` list length. Failed read is ` · 申请数没读到`. Zero draws no suffix. No GET was added. |
| RTEAMS-5 | Cursor test un-pin | `test_nearby_mine_read_provenance.py` no longer requires `LabeledContent("nearby.activeCount")`. The App row is still there. |
| OCARDS-3 | Cursor test un-pin | `test_native_ui_accessibility_semantics.py` no longer requires `Menu {`. The other object-card asserts stay. |
| JSETTLE-r8-1 | Cursor Core | `finish_offer_shown` and `finish_offer_click` are on `AnalyticsEventClient.allowedEvents`. `JourneyFinishOffer.trackPayload` matches `finish-offer.js`: `offerKind`, `planCode` for a pass, numeric `topicId` when it is an id, `bizType` `platform_pass` or `marketing_product`, product `bizID`, no name and no price. |
| ROAM-9 / PLAY-6 | Cursor Core | `PlayRoamGapService.fetchNearbyRunners` posts form `lat`, `lng`, `radius` (default radius 3000). `RoamNearbyRunner.normalized` ports `normalizeRunners`. Local preferences: `play.bgmOn`, existing `play.narrationOn`, `play_reduced_motion` / `roam_reduced_motion`, `roam_fog_off`, `cy_map_kind` (`white` / `black` / `paper` / `2077`, default black). |
| JSEAT-r8-1 | Cursor Core | `seatTransferPhone` posts JSON `{registrationId, seatNo, name, phone, requestId}` with numeric ids. Name is trimmed, 1–20. Phone is the normalized mainland mobile. Same form retries reuse `seatphone-…`. `seatClaimPhone` posts `{}` to `claim-phone/{token}`. `seatMine` is `GET /api/play/seat-invitations/mine`. All three are on `playerJourneyOwnerGrant`. `JourneySeatPhoneTransfer` has the page errors, `who`, and `canTransfer`. |
| BWALL-3 | Cursor test un-pin | `test_object_badge_wall_layout.py` no longer pins the list/wall switch, the segmented picker, or `ObjectBadgeWallLayoutControl`. The detail sha256 `ff26c06b901f71bfc5fa08210437e16772e85478532239840daa64c811ca8a1d` stays. SceneKit, RealityKit, and `AsyncImage(` stay forbidden. |

## Gates turned on

- `RoamExperienceCapabilities.mediaUpload = true`
- `RoamExperienceCapabilities.stampExchange = true`
- Player journey grant: `/api/play/seat-invitations/transfer-phone`, `/api/play/seat-invitations/claim-phone/{}`, `/api/play/seat-invitations/mine`

`wiredPatternCount` stays 679. Location, presence, settlement, voucher issue, redemption, and legacy hangout stay false. Stamp album `showsCapture` stays false. That constant is not the camera-page gate.

## Left off

- `JourneyLoopSource.moneyWritesEnabled` stays false. `giftClaim` still throws `JourneyRefusal.moneyOff` and sends nothing.
- Platform-pass refund-apply, cancel, and confirm still throw `PlatformPassWriteRefusal.unreachable` and send nothing.
- `PlayStageAnalyticsGate.enabled` stays false. Finish-offer events are the analytics allow-list, not that gate.
- `RuntimeLocationProjection` was not edited.
- `pages/roam/index.js:210` was not turned into a path. `api/roam/greet` was not added.
- Not taken (not a Core fix, or money, or needs a yes the audit does not give): JPROMO-3, JSEAT-8, JLAND-r7-1 (`claimsEnabled` stays false), RPOI-4, RPOI-5, SCAM-2, GROWTH-5, ROAM-7.

## App call sites for Claude

Do not mount parked `App/MPGap` sheets as-is. Do not edit `AppSession.swift` or `AppCompositionRoot.swift` for these.

- RSTAMP-2 / SCAM-1: `App/RoamStampCameraView.swift` already reads `StampCameraPageContract.showsCreate`. The flag is now true, so 存入集邮册 can enable. The one-tap upload-then-create sequence is still the App camera flow (`RoamStampCameraView`, `SessionRoamMediaViews`). `StampAlbumIndexPageModel.showsCapture` is still false, so the album page does not grow a capture button from this change. Exchange UI in `SessionRoamCityStampFlowView` should read `stampExchange`, which is now true. `AppSession.makeRoamStampCaptureCoordinator` already builds `RoamMediaMutationService(enabled: true)`.
- SALBUM-1: not a Core host list. `RoamStampViews` metadata `allowsRemoteImages` is still false. Use `RetainedImageOrigin.configured` (API origin plus `CYStampImageOrigins`). Do not hardcode hosts. Do not allow `http`.
- ROAM-8: bind `RoamPassportHome.latestTrackThumbnail` and `latestStampImage` on the passport history and stamp tiles. Empty means the existing illustration. Badge and 时光胶囊 layout stay App. Do not fetch `/api/medal/wall` for this row.
- RTEAMS-3b: for each recruiting team the viewer leads (`NearbyLeaderApplicantFact.asks`), call the existing `POST /api/team/applications` and show `NearbyLeaderApplicantFact.suffix`. Do not add a GET. `App/NearbyTeamViews.swift` `mineSection` is the row.
- RTEAMS-5: delete the duplicate `LabeledContent("nearby.activeCount")` in `App/NearbyTeamViews.swift`. The provenance test no longer pins it.
- OCARDS-3: the `Menu {` pin is gone. Mount the category sheet from `App/MPGap/PlayRoam/ObjectCardCategoryAndRenameSheets.swift` into `App/ObjectCardViews.swift`. Keep the frame, load, and `ObjectCardFlowTests` asserts.
- JSETTLE-r8-1: `App/JourneyReportViews.swift` should call `AnalyticsEventClient.track` with `JourneyFinishOfferAnalytics.shown` on appear and `.click` on tap, using `offer.trackPayload(topicID:)`. Do not set `PlayStageAnalyticsGate.enabled`.
- ROAM-9 / PLAY-6: call `fetchNearbyRunners` (body is now `lat`, `lng`, `radius`) and replace the list only when the reply is ok, using `RoamNearbyRunner.normalized`. A failed reply keeps the previous rows. Do not add greet. Bind `PlatformBGMPreference` (`play.bgmOn`), `PlatformNarrationAutoplayPreference` (`play.narrationOn`), `PlayReducedMotionPreference`, `RoamFogPreference` (`roam_fog_off`, default fog on), and `FreeMapKind` (`cy_map_kind`). `RoamMapStyleOption` (标准 / 卫星 / 夜间) is not the mini-program control. Sheet mounting stays Claude. `CastRosterButton` stays unmounted.
- JSEAT-r8-1: the seats sheet (`App/JourneyLandingViews.swift` and the seats page model) should call `seatTransferPhone`, `seatClaimPhone`, and `seatMine`. Show `JourneySeatPhoneTransfer.nameError` / `phoneError` before send. `who` and `canTransfer` are the row facts. Clear the form on success. A retry of the same trimmed name and normalized phone reuses the request id. Do not send gift claim.
- BWALL-3: the list/wall switch pin is gone. The detail view hash is unchanged. A 2-column grid can replace the switch in `App/ObjectBadgeViews.swift`. The parked grid that uses `CYCachedAsyncImage` must not be mounted as-is.
