# Receipt: `gap/g2-ops` (MP gap translate r1 + r2 — G2 ops)

- **Brief:** `origin/design/handoff-r2:docs/briefs/mp-gap-translate-r1.md`
- **Base:** `origin/ui/combined-r6`
- **Branch:** `gap/g2-ops`
- **Areas:** `club`, `merchant-coop`, `account-publish`
- **MP Source:** `liboyang42-cpu/hengyin` (`chengyinhub-xcx`)

## 1. Gap Inventory & Coverage Sweep
Walked all 168 MP pages in `chengyinhub-xcx/app.json` and confirmed coverage across all G2 ops pages:
- `club`: all 20 `pages/club/*` pages (`docs/mp-gap/club.md`, `CLB-G01`–`CLB-G19`)
- `merchant-coop`: all 35 `pages/merchant/*` + `pages/coop/*` pages (`docs/mp-gap/merchant-coop.md`, `MC-G01`–`MC-G18`)
- `account-publish`: all 22 `account-publish` pages (`docs/mp-gap/account-publish.md`, `AP-G01`–`AP-G16`); `pages/publishkit/index/index` confirmed as subpackage redirect placeholder only; `subpackageMember/complaint`, `pages/topic/merchant{info,apply}`, `pages/play/merchant`, `subpackageRoam/my-teams` confirmed owned by G1 (`member`, `player-content`, `play-roam`).
- Excluded: P1–P5 (`port/plan-r1` §2.2), `cursor/core-wiring-r6` (`POST /api/im/read`, `GET /api/club/settlement/summary`, `MKT-7-2`, `FIN-11-4`, `CLB-detail-11`), and restyle-only items.

## 2. Translated (New Files Only)
### Shared Core HTTP Helper
- `Core/MPGap/MPGapHTTP.swift`

### Club (`Core/MPGap/Club/`, `App/MPGap/Club/`)
- Round 1 (`CLB-G03`, `CLB-G04`, `CLB-G06`, `CLB-G08`, `CLB-G11`–`CLB-G13`, `CLB-G17`, `CLB-G19`):
  - `Core/MPGap/Club/ClubGapCoopPool.swift`, `Core/MPGap/Club/ClubGapTopicDirector.swift`, `Core/MPGap/Club/ClubGapReferenceSettlement.swift`
  - `App/MPGap/Club/ClubGapManageExtensions.swift`, `App/MPGap/Club/ClubGapTopicDirectorViews.swift`, `App/MPGap/Club/ClubGapReferenceSettlementView.swift`
- Round 2 (`CLB-G01`, `CLB-G02`, `CLB-G05`, `CLB-G07`, `CLB-G09`, `CLB-G10`, `CLB-G14`–`CLB-G16`):
  - `Core/MPGap/Club/ClubGapRemaining.swift`
  - `App/MPGap/Club/ClubGapRemainingViews.swift`

### Merchant-Coop (`Core/MPGap/MerchantCoop/`, `App/MPGap/MerchantCoop/`)
- Round 1 (`MC-G07`–`MC-G09`, `MC-G12`, `MC-G16`–`MC-G18`):
  - `Core/MPGap/MerchantCoop/MerchantGapAIInsight.swift`, `Core/MPGap/MerchantCoop/MerchantGapOperations.swift`
  - `App/MPGap/MerchantCoop/MerchantGapAIInsightViews.swift`, `App/MPGap/MerchantCoop/MerchantGapOperationsViews.swift`
- Round 2 (`MC-G01`–`MC-G06`, `MC-G10`, `MC-G11`, `MC-G14`, `MC-G15`):
  - `Core/MPGap/MerchantCoop/MerchantGapRemaining.swift`
  - `App/MPGap/MerchantCoop/MerchantGapRemainingViews.swift`

### Account-Publish (`Core/MPGap/AccountPublish/`, `App/MPGap/AccountPublish/`)
- Round 1 (`AP-G01`, `AP-G02`, `AP-G10`, `AP-G11`, `AP-G14`–`AP-G16`):
  - `Core/MPGap/AccountPublish/AccountPublishGapModels.swift`
  - `App/MPGap/AccountPublish/AccountPublishGapViews.swift`
- Round 2 (`AP-G03`–`AP-G08`, `AP-G12`, `AP-G13`):
  - `Core/MPGap/AccountPublish/AccountPublishGapRemaining.swift`
  - `App/MPGap/AccountPublish/AccountPublishGapRemainingViews.swift`

### Strings & Tests
- `docs/port/strings/gap-g2-ops.json`
- `Tests/CoreTests/MPGap/G2OpsGapTests.swift` (covers every `Core/MPGap` model and client)

## 3. Mount Hooks
All mount hooks (target file + location + snippet) are listed in:
- `docs/mp-gap/mounts-g2-ops.md`

## 4. Owner-Gated / Money-Gated Items (UI/Core translated, gates preserved)
- `CLB-G17`: `POST /api/fe/reference-settlement/settle` gated behind `allowsMoneyWrite: Bool` (default `false`)
- `CLB-G18`: `POST /api/club/payout-receiver/bind` (WeChat auth code owner decision)
- `MC-G12`: `POST /api/merchant/ai-npc/voice/enroll` (owner-gated `MerchantCityNPCParityGates`)
- `MC-G13`: `citynode` / `game-node` scan & writes (owner-gated)
- `MC-G16`: `POST /api/coop/deposit/create`, `/refund/retry` gated behind `allowsMoneyWrite: Bool` (default `false`)
- `AP-G09`: `POST /api/media/asset/{id}/retry` (owner-gated in `ChinaReviewedRouteCapability`)

## 5. Verification
- **Local:** `swiftc -parse` passed on all 19 new Swift files (`Core/MPGap/**/*.swift`, `App/MPGap/**/*.swift`, `Tests/CoreTests/MPGap/*.swift`). No local Xcode build or simulator tests run (disk-full / cloud-first rule).
- **Cloud acceptance:** `ci/acceptance` is currently failing on `origin/ci/acceptance` (checked via `gh run list --branch ci/acceptance`), so `origin/ci/acceptance` was not merged yet; ready to merge and run once `ci/acceptance` is green.

DONE-ROUND-2

## 6. Round 3 Alignment (against `origin/ui/combined-r7`)
- **Copy alignment:** [copy-g2-ops.md](docs/mp-gap/copy-g2-ops.md) — audited 632 `club`, 855 `merchant-coop`, and 1,384 `account-publish` MP strings against `Resources/Localizable.xcstrings` and area `.xcstrings` on `origin/ui/combined-r7`. Listed 16 near-mismatches in existing `Localizable.xcstrings` for the coordinator and verified all `MPGap` strings.
- **Contract alignment:** [contracts-g2-ops.md](docs/mp-gap/contracts-g2-ops.md) — audited 102 `club`, 131 `merchant-coop`, and 92 `account-publish` MP endpoints against `Core/`. Fixed all 8 mismatches inside `Core/MPGap/*` (`POST /api/ai/merchant/insight`, `POST /api/merchant/claims/submit`, split `POST /api/merchant/update` vs `decor/save`, `follow_member_id`/`follow` on `user/follow/action`, `POST /api/team/applications`, `GET /api/topic/cast/voice`, `ids: [Int]` on `fe/reference-settlement/settle`, `manualCaseId` on `manual-case-detail`) and updated `Tests/CoreTests/MPGap/G2OpsGapTests.swift`.
- **Swift symbol & signature audit (coordinator note):** checked every external type, case, method, and initializer in `Core/MPGap/*`, `App/MPGap/*`, and `Tests/CoreTests/MPGap/*` against `origin/ui/combined-r7` and fixed all mismatches:
  - `Core/MPGap/MPGapHTTP.swift`: replaced non-existent `APIError.serverMessage(...)` with `APIError.httpStatus(status)` and `APIError.businessCode(code)`.
  - `App/MPGap/Club/ClubGapManageExtensions.swift`: fixed `CYAvatarView(url:fallbackText:size:)` -> `CYAvatarView(url:name:size: .sm)` and `CYColor.surfaceSecondary` -> `CYColor.bgSurfaceSubtle`.
  - `App/MPGap/Club/ClubGapRemainingViews.swift`, `App/MPGap/MerchantCoop/{MerchantGapOperationsViews,MerchantGapRemainingViews}.swift`, `App/MPGap/AccountPublish/AccountPublishGapViews.swift`: fixed `CYColor.accent` -> `CYColor.brand`, `CYColor.warning` -> `CYColor.warningText`, `CYColor.danger` -> `CYColor.dangerText`.
  - `Tests/CoreTests/MPGap/G2OpsGapTests.swift`: fixed `APIConfiguration(baseURL:)` -> `try! APIConfiguration(baseURL:)` (throwing initializer).
- `swiftc -parse` passed on all 19 Swift files after final edits.

DONE-ROUND-3

## 7. Compile-Fix Pass (`docs/mp-gap/compile-errors-r7.md`)
- Merged `origin/ui/combined-r7` (`7fdfad1f1`) cleanly into `gap/g2-ops`.
- Fixed all remaining G2 `App/MPGap` compiler errors:
  - `App/MPGap/AccountPublish/AccountPublishGapRemainingViews.swift:159-164` & `App/MPGap/Club/ClubGapRemainingViews.swift:190-195`: replaced `CYEmptyState(..., verbatimTitle:, actionTitle:)` with `CYEmptyState(..., LocalizedStringKey(...), actionTitle: LocalizedStringKey(...), action:)`.
  - `App/MPGap/Club/ClubGapRemainingViews.swift:51-92`: extracted `pickerContent` `@ViewBuilder` to resolve SwiftUI type-checker timeout/failure in `ClubGapPlayRecordPickerRow`.
  - `App/MPGap/AccountPublish/AccountPublishGapViews.swift:19,261`, `App/MPGap/Club/ClubGapManageExtensions.swift:172,181`, `App/MPGap/Club/ClubGapRemainingViews.swift:43,181`, `App/MPGap/MerchantCoop/MerchantGapOperationsViews.swift:172`, `App/MPGap/MerchantCoop/MerchantGapRemainingViews.swift:31,103`: already aligned with `CYColor.brand`/`warningText`/`dangerText`/`bgSurfaceSubtle` and `CYAvatarView(url:name:size: .sm)` in commit `38ee5b52f`.
- `swiftc -parse` passed on all G2 `Core/MPGap`, `App/MPGap`, and `Tests/CoreTests/MPGap` Swift files.

DONE-COMPILE-FIX

## 8. Round 4 (`audit/parity-r7-*` Gemini Queue)
- Merged `origin/ui/combined-r7` first (`Already up to date` with `7fdfad1f1`).
- Read `origin/audit/parity-r7-{club,merchant-coop,account-publish}` and translated every Gemini-owned fix-queue item into new files:
  - **Club (`CLB-detail-09`, `CLB-r7-A-04`, `CLB-topic-story-04`, `CLB-apply-05`, `CLB-r7-D-01`, `CLB-group-code-05`):**
    - `Core/MPGap/Club/ClubGapRound4.swift`, `App/MPGap/Club/ClubGapRound4Views.swift`
  - **Merchant-Coop (`MC7-01..MC7-33` Gemini queue: claim DTO + search, batch voucher copy, AI insight store logo + daily heat grid + club pool cards, decor inactive `ContentUnavailableView`, AI NPC 3-sentence voice session state, city-node codeText + map preview, operator invite `api/merchant/operators/invite/accept`, deposit `api/coop/deposit/create/app` + polling behind `allowsMoneyWrite`, coop list & invite presets):**
    - `Core/MPGap/MerchantCoop/MerchantGapRound4.swift`, `App/MPGap/MerchantCoop/MerchantGapRound4Views.swift`
  - **Account-Publish (`C-F1` branch/gallery/line/speaker, `C-F5` cast editor sheet, `C-F7` prologue/ending/staffOpening, `C-T3` relaxOnLowHP/outcomes/scanReply/citynode, `C-D2` `team/handle {teamId, memberId, approved}`, `C-D11-r7` save invite image privacy gate, `A7-01/03/05` `MiniCropGapOverlay` `cropSize` fix):**
    - `Core/MPGap/AccountPublish/AccountPublishGapRound4.swift`, `App/MPGap/AccountPublish/AccountPublishGapRound4Views.swift`, `App/MPGap/AccountPublish/AccountPublishGapRemainingViews.swift`
- **Tests:** `Tests/CoreTests/MPGap/G2OpsRound4Tests.swift` covering all Round 4 Core models and clients.
- `swiftc -parse` passed on all 26 G2 Swift files (`Core/MPGap`, `App/MPGap`, `Tests/CoreTests/MPGap`).

DONE-ROUND-4

## 9. Round 5 (`r7-rev-c` + `owner-decisions-1124`)
- Closed all G2 `owner=Gemini` findings from `origin/review/r7-rev-c:docs/review/r7-rev-c.md`: `F-C03`, `F-C04`, `F-C06`, `F-C07`, `F-C08`, `F-C09`, `F-C20`, `F-C22`, `F-C23`, `F-C25`.
- Report written to [round5-g2.md](docs/mp-gap/round5-g2.md).
- `swiftc -parse` passed on all 26 G2 Swift files after final edits.
- Merged `origin/ui/combined-r7` (`82388e4a5`) and replaced G2 `App/MPGap` placeholder SF Symbols/TODOs with `MPAsset` accessors (`MPAsset.AvatarDefault.dProfile`, `MPAsset.BannerCover.{treasureHunter,flavorTour,midlifeDay,oldMovie}`, `MPAsset.FeatureIcon.{introTicketMap,pin,iconShop,iconStarFilled,iconStarOutline}`).
- `swiftc -parse` passed on all 26 G2 Swift files + `App/MPAssets/MPAsset.swift`.
