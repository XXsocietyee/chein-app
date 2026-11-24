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
