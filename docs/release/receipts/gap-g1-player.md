# Receipt: `gap/g1-player`

- **Branch:** `gap/g1-player` (based on `origin/ui/combined-r6` at `f1115875e`)
- **Areas:** `player-content`, `play-roam`, `member`
- **Strings:** [`docs/port/strings/gap-g1-player.json`](file:///Users/fanning/orca/workspaces/native-ios/DES-ag3/docs/port/strings/gap-g1-player.json)
- **Mount hooks:** [`docs/mp-gap/mounts-g1-player.md`](file:///Users/fanning/orca/workspaces/native-ios/DES-ag3/docs/mp-gap/mounts-g1-player.md)

## Verification
- **Local macOS:** No Xcode build, simulator, or test run executed (disk nearly full, per brief).
- **Syntax check:** `swiftc -parse` passed with exit code 0 on all new Swift files in `Core/MPGap/**`, `App/MPGap/**`, and `Tests/CoreTests/MPGap/**`.
- **Static scaffold gate:** `python3 -B tools/check_scaffold.py` passed on base; re-run after all new files.
- **Cloud acceptance (`acceptance.yml`):** `.github/workflows/acceptance.yml` does not exist on `origin/ui/combined-r6` yet (only `ios-ci.yml`, `native-ios.yml`, `native-targeted.yml` exist). Pushed `gap/g1-player` to GitHub; ready for `gh workflow run acceptance.yml --ref gap/g1-player` once `acceptance.yml` lands.

## Gaps Found, Translated & Left

### `player-content` (`docs/mp-gap/player-content.md`)
- **Translated (Core + SwiftUI + Tests):**
  - `PC-A-7-2`: `TopicTemplateDeckPreviewView` + `TopicTemplatePreviewData.fromWire` (`POST /api/template/topic-template/info`)
  - `PC-B-1-5`: `TopicRouteMapAndTeamsSection` + `PlayerContentGapService` (`GET /api/play/nodes`, `POST /api/team/nearby`, `POST /api/free-explore/bundle/catalog`)
  - `PC-C-2-3` / `C-2-4` / `C-2-6`: `ActivityRegistrationGapSections` + `requestHostReservation` (`POST /api/club/event-ops/host/request`)
  - `PC-C-4-2`: `OfficialEventLeaderboardSection`
  - `PC-B-4-2` / `B-4-4`: `TopicPricingGapSection` + `sale-status` / `settlement-pending` (`GET /api/topic/pricing/sale-status`, `GET /api/topic/pricing/settlement-pending`) *(confirm remains owner-gated)*
  - `PC-B-2-3`: `MerchantHostWorkbenchSection` *(writes remain owner-gated)*
  - `PC-B-1-4` / `PC-C-6-2` (Core service): `checkOrientSafety` (`POST /api/orient/safety/check`), `recoverOfficialBroadcast` (`POST /api/official/broadcast/recover`)
- **Left for follow-up (documented in `docs/mp-gap/player-content.md`):**
  - `PC-A-5-1/2/3` (`SearchMapExplorerView` full-bleed map rewrite — existing file is SHA-pinned by `test_global_search_category_recovery`)
  - `PC-B-3-2/3` (`MerchantContentEditor` map/photo picker — existing file owned by restyle/merchant)
  - `PC-D-9-1/3/4` (`MessagingHistoryView` IM read/report/composer — deferred pending Flutter IM reference)
  - Remaining `S`-sized mount/deep-link tweaks (`PC-A-1-3/5/6/7`, `PC-A-2-1/2/5`, `PC-A-4-2`, `PC-A-6-2/3`, `PC-B-1-2` owner-gated, `PC-B-1-6/11/14`, `PC-B-5-2/4`, `PC-B-6-1`, `PC-C-1-1/2/5/6`, `PC-C-4-4`, `PC-C-7-1`, `PC-D-1-3/6/8`, `PC-D-3-2`, `PC-D-4-2/5`, `PC-D-5-1/2`, `PC-D-6-2`).

### `play-roam` (`docs/mp-gap/play-roam.md`)
- **Translated (Core + SwiftUI + Tests):**
  - `PLAY-6` / `PLAY-8`: `PlayToolsAndLeadSheetView` + `PlayRoamGapService` (`POST /api/club/lead/start`, `POST /api/club/lead/settle`, `POST /api/registration/scan_group_member_ticket`)
  - `ROAM-9`: `RoamSessionToolsSheetView` + `fetchNearbyRunners` / `greetRunner` (`GET /api/roam/nearby-runners`, `POST /api/roam/greet`)
  - `RSTAMP-3`: `CityStampTearScratchCardView` (tear + 60% scratch reveal; create/exchange remain owner-gated)
  - `OCARDS-3` / `OCARDS-4`: `ObjectCardCategorySheetView` + `ObjectCardRenameSheetView` + `ObjectCardRenameValidator`
  - `RPOI-7` / `JSETTLE-3` (Core service): `deleteComment` (`POST /api/comment/delete`), `fetchTopicInfo` (`POST /api/topic/info-to-user`)
- **Left for follow-up:**
  - `PLAY-2/3`, `ROAM-3/4/8/13`, `RNEAR-2/7`, `RHIST-1/2`, `RPOI-2/3/4/8`, `SCAM-2`, `BWALL-2/3`, `B3D-1`, `JREPORT-2/3`, `ROAM-7` (backend-blocked), `PLAYM-2` (backend-blocked), and `S` items.

### `member` (`docs/mp-gap/member.md`)
- **Translated (Core + SwiftUI + Tests):**
  - `MKT-7-1` / `MKT-7-3`: `FreeExploreBundleReceiptView` + `MemberGapService` (`GET /api/free-explore/bundle/order/receipt`, `GET /api/free-explore/bundle/catalog`)
  - `PLY-25-2` / `25-3` / `25-4` / `25-5`: `OrientScoreLeaderboardSheetView`, `OrientScoreAppealSheetView`, `OrientScoreSettlementGapSection` *(sync/settle owner-gated)*, `submitOrientAppeal` (`POST /api/orient/appeal`)
  - `PLY-29-4`: `ReportAppealSheetView` (6-phase sheet with persistent `requestId`) + `submitReportAppeal` (`POST /api/report/appeal`)
  - `MKT-10-1`: `MerchantCouponSummaryTilesView` + `fetchMerchantCouponSummary` (`GET /api/merchant/coupon-summary`)
  - `MKT-5-3`: `PlatformPassOrderCancelRefundSheetView` *(owner-gated)*
  - `FIN-17-3` (Core service): `checkInvoiceOrderEligible` (`POST /api/invoice/orders/eligible`)
- **Left for follow-up:**
  - `FIN-17-4` (order detail team/seats/club mounts), `FIN-16-2` / `FIN-18-2` / `FIN-19-1` (Core pager protocol changes), `PLY-23-3/4/6`, `PLY-26-5`, `MKT-3-1` / `MKT-4-1/6` (owner-gated), and `S` items.
