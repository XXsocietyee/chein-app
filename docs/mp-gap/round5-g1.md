# G1 Round 5 Alignment Report (`gap/g1-player`)

Source reviews & briefs:
- `origin/review/r7-rev-c:docs/review/r7-rev-c.md` (`owner=Gemini`, G1 areas: `player-content`, `play-roam`, `member`)
- `origin/design/handoff-r2:docs/briefs/owner-decisions-1124.md`
- `origin/cursor/mp-assets:App/MPAssets/MPAsset.swift` & `docs/mp-assets/mapping.md`

## 1. `r7-rev-c.md` Findings Closed (`owner=Gemini`, G1)

| ID | Severity | Area | Resolution |
| --- | --- | --- | --- |
| F-C01 | P0 | Shared/Core | Verified `Core/MPGap/MPGapHTTP.swift` uses `APIClient` / `PlayRequestEncoding` cleanly; no invented `APIError` cases. |
| F-C03 | P0 | Core/MPGap | Switched URL-encoded form POSTs in `PlayerContentGapService.swift`, `PlayerContentRound2Service.swift`, `PlayRoamGapService.swift`, `PlayRoamRound2Service.swift`, `MemberGapService.swift`, `MemberRound2Service.swift` to `form:` encoding matching MP `application/x-www-form-urlencoded` calls. |
| F-C04 | P0 | Core/MPGap | Fixed drifted endpoints: `reportPeerMember` -> `api/im/report`; `submitOrientAppeal` -> `api/orient/scoring/appeal`; `fetchOrdersPage` -> `POST api/registration/my-joined`; `fetchOrientScoring` -> `GET api/orient/scoring/session/<sessionId>`. |
| F-C05 | P0 | Core/MPGap | Removed invented endpoints: `recoverOfficialBroadcast` (`api/official/broadcast/recover`), `fetchMyTemplateDetail` (`api/template/my/info`), `greetRunner` (`api/roam/greet`), `fetchCityStrip` (`api/roam/city-strip`). |
| F-C06 | P0 | Core/MPGap | Fixed HTTP method mismatches (GET -> POST): `fetchMerchantCategories`, `fetchMerchantPrefillInfo`, `fetchMerchantRegistrations`, `fetchMerchantChapterApplications`, `fetchCoopFinance`, `fetchNearbyRunners`, `fetchTeamApplications`, `fetchWithdrawalsPage`. |
| F-C07 | P0 | Core/MPGap | Aligned request parameter keys: `fetchNearbyRunners` (`latitude`, `longitude`, `radius`), `leadStart`/`leadSettle` (`activityId`), `fetchTeamApplications` (`teamId`). |
| F-C26 | P0 | Core/MPGap | Removed `URLComponents!` force-unwraps across all G1 `Core/MPGap` services; switched integer IDs from `.number(Double(id))` to `.integer(Int64(id))` in `PlayerContentGapService`, `PlayerContentRound2Service`, `PlayerContentRound4Models`, `PlayRoamGapService`, `MemberGapService`. |
| F-C12 | P2 | Member | Added `.confirmationDialog` before destructive `onSync` and `onSettle` actions in `App/MPGap/Member/OrientScoreGapViews.swift`. |
| F-C13 | P2 | All G1 | Replaced all `.cyText(.micro)` and `.cyText(.caption)` usages with `.cyText(.meta)` across 9 `App/MPGap` files. |
| F-C14 | P2 | PlayRoam | Replaced 1-letter monogram in `App/MPGap/PlayRoam/NearbyAndHistoryGapViews.swift` with `CYAvatarView(url:name:size:.sm)` + `// TODO: MPAsset.AvatarDefault.dProfile` fallback note. |
| F-C15 | P2 | All G1 | Replaced placeholder SF Symbols in `TopicTemplateDeckPreviewView`, `PlayRoamRound2Views`, `SearchMapExplorerGapView`, and `PlayerContentRound4Views` with exact `MPAsset` accessors from `App/MPAssets/MPAsset.swift` (`MPAsset.BannerCover.homeRouteCityPlaceholder`, `MPAsset.BadgeMedal.medalGold`, `MPAsset.MapMarker.dSmapicon`, `MPAsset.BrandLogo.cyLogoMark`). |
| F-C25 | P2 | PlayRoam | Restored team leader avatar rendering via `CYAvatarView` in `NearbyAndHistoryGapViews.swift`. |

## 2. Owner Decisions Applied (`owner-decisions-1124.md`)

- **#9 Two-decimal money:** Updated `JourneyFinishOfferResolver` in `Core/MPGap/PlayRoam/PlayRoamRound4Models.swift` so fen-to-yuan formatting always renders two decimal places (`¥39.00`, `¥68.00`).
- **#8 GPS arrival lock & #3/#6/#12 TEST-only money:** Preserved in G1 views/services; no Release money mutations or manual arrival bypasses added.

## 3. MP Assets (`App/MPAssets/MPAsset.swift`)

- Merged `origin/ui/combined-r7` (`82388e4a5`), bringing in `App/MPAssets/MPAsset.swift` and `JourneyRankBoardContract`.
- Wired `MPAsset.BannerCover.homeRouteCityPlaceholder` (`TopicTemplateDeckPreviewView.swift`), `MPAsset.BadgeMedal.medalGold` (`PlayRoamRound2Views.swift`), `MPAsset.MapMarker.dSmapicon` (`SearchMapExplorerGapView.swift`), and `MPAsset.BrandLogo.cyLogoMark` (`PlayerContentRound4Views.swift`).

## 4. Localization & Tests

- Added `orientScore.syncTasks.confirmTitle`, `orientScore.settleRun.confirmTitle`, and `common.cancel` (`zh-Hans` + `en`) to `docs/port/strings/gap-g1-player.json`.
- Updated `Tests/CoreTests/MPGap/MPGapG1Round2Tests.swift` and `Tests/CoreTests/MPGap/MPGapG1Round4Tests.swift` to match the Round 5 service paths and two-decimal money output.
