# Integration batch 3 (2026-11-13)

Integrator branch `integ/next`, pushed to `ui/next` and `ui/main` (fast-forward only).

## Merged

| Branch | Head |
| --- | --- |
| `ui/e2e-fixes` | `4c5e89ecc` |
| `ui/cloud-h1-claude` | `15aa3dad9` |
| `ui/cloud-h4-claude` | `223ddb817` |
| `ui/citygame-prod` | `0808f6cfe` |

All parsed with `swiftc -parse`, added no duplicate top-level types, and added no money route.

## Integrator changes

- H1 template adoption: `/api/template/topic-template/binding`, `/binding-status` and `GET /api/media/asset/attribution`
  join the China wired patterns (`/use` was already there) and a new `templateAdoption` endpoint in the player-write
  lease. `makeSession` installs `TopicTemplateAdoptionService` when the reviewed China player-write grant is on.
  Test: `ReviewedChinaLaunchCompositionTests.testShippedChinaAdmitsTemplateAdoptionAndKeepsMoneyClosed`.
- CITY board region: `QUESTIFY_CITY_GAME_REGION[config=Debug] = gaps-a-test` in `Config/Base.xcconfig`.
  Release resolves empty (checked with `-showBuildSettings`).
- Citygame compile fixes: `mutating` CITY `notePlayerWrites` on the `AppCompositionRoot` struct; `nonisolated`
  `cityGameRegion`.
- Client data catalog: H3 chapter reading position (UserDefaults) and H4 offline pack cache (file).
- `wiredPatternCount` 672 → 677 (H8 help use/skip, H1 binding, binding-status, media attribution).
- QuestifyCoreTests compiles again (test-only repairs across about 20 files).

## Verification

- `build-for-testing` (Questify scheme, arm64, `-jobs 2`): succeeded.
- Gates: scaffold, design lint, appsession ratchet, release config, fixture exclusion, client-ops catalog: pass.
- Core UITests (Entry, RegionalEntry, TicketWallet, PageFlowGoldenPath): see the batch report.
- QuestifyCoreTests (SwiftPM, macOS host): AccountCompliance, RoamLiveSession, CityGameHTTPService,
  TopicTemplateAdoption, TopicTemplateUse, ChinaReviewedRouteCapability, PlayerJourneyProductionLease, VideoBountySource,
  PlayHelpLadder, TeamSeatFacts, PlayFullStoryH3 pass. PlayRecoveryH4Tests: two prefetch-store tests now skip off iOS,
  because `.completeFileProtection` writes fail on the macOS swift-test host (Cocoa 513). App behaviour is unchanged.

## KNOWN-FAIL (fix first in batch 4; both block the e2e rerun)

- (a) `ReviewedChinaLaunchCompositionTests.testShippedChinaAdmitsLivePlayerReadsAndKeepsMoneyClosed`: `ClubService.detailBody`
  `POST api/club/detail` returns `notConfigured` on the integrated tree. The `api/club/home` call just before it passes.
- (b) `ReviewedChinaLaunchCompositionTests.testShippedChinaAdmitsFreePlayerWritesAndKeepsMoneyClosed`: throws
  `CancellationError` at its `api/im/send` step. This failure was present before batch 3; e2e-fixes F4 did not clear it here.
