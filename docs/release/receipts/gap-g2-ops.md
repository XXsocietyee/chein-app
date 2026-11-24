# Receipt: `gap/g2-ops` (MP gap translate r1 — G2 ops)

- **Brief:** `origin/design/handoff-r2:docs/briefs/mp-gap-translate-r1.md`
- **Base:** `origin/ui/combined-r6`
- **Branch:** `gap/g2-ops`
- **Areas:** `club`, `merchant-coop`, `account-publish`
- **MP Source:** `liboyang42-cpu/hengyin` (`chengyinhub-xcx`)

## 1. Gap Inventory (Step 1)
All remaining MP functions not covered by `ui/combined-r6`, P1–P5, Cursor C2, or restyle-only sweeps are catalogued in:
- `docs/mp-gap/club.md` (19 entries: `CLB-G01`–`CLB-G19`)
- `docs/mp-gap/merchant-coop.md` (18 entries: `MC-G01`–`MC-G18`)
- `docs/mp-gap/account-publish.md` (16 entries: `AP-G01`–`AP-G16`)

## 2. Translated (New Files Only)
### Shared Core HTTP Helper
- `Core/MPGap/MPGapHTTP.swift`

### Club (`Core/MPGap/Club/`, `App/MPGap/Club/`)
- **`CLB-G04` (L) + `CLB-G11` (S):** `Core/MPGap/Club/ClubGapCoopPool.swift`, `App/MPGap/Club/ClubGapManageExtensions.swift` (`ClubGapCoopPoolSection`, coop pool list + `申请带队` modal + `我的合作` hook; `ClubEditionsEmptyReasonClient`).
- **`CLB-G06` (S), `CLB-G08` (S), `CLB-G19` (S):** `App/MPGap/Club/ClubGapManageExtensions.swift` (`ClubGapMemberAvatarStrip` `4 + +N`, `ClubGapSettingsSheet` with `改为转让主理人`).
- **`CLB-G12` (M) + `CLB-G13` (L):** `Core/MPGap/Club/ClubGapTopicDirector.swift`, `App/MPGap/Club/ClubGapTopicDirectorViews.swift` (`ClubGapTopicDirectorEmbeddedSection` for `准备总览`, `章节放行`/`队伍进度`/`角色分配`/`现场事件`/`定向广播`, `排行榜` toggle, K8 unknown-write recovery banner; `ClubGapTopicMoreMenu`).
- **`CLB-G17` (L):** `Core/MPGap/Club/ClubGapReferenceSettlement.swift`, `App/MPGap/Club/ClubGapReferenceSettlementView.swift` (`ClubGapFEReferenceSettlementSection` for `自由探索结算（参考）`; `标记已结清` money write gated behind `allowsMoneyWrite: Bool` = `false` by default).

### Merchant-Coop (`Core/MPGap/MerchantCoop/`, `App/MPGap/MerchantCoop/`)
- **`MC-G07` (L):** `Core/MPGap/MerchantCoop/MerchantGapAIInsight.swift`, `App/MPGap/MerchantCoop/MerchantGapAIInsightViews.swift` (`MerchantGapAIInsightDashboardSection`: `近7天`/`近30天`/`近90天` window picker, `到店`/`打卡`/`核销` metric switch, `客源主题` bars, `经营解读` `机会`/`问题`, permission-gated `经营优化` tips).
- **`MC-G08` (M), `MC-G09` (M), `MC-G12` (L), `MC-G16` (L), `MC-G17` (M), `MC-G18` (M):** `Core/MPGap/MerchantCoop/MerchantGapOperations.swift`, `App/MPGap/MerchantCoop/MerchantGapOperationsViews.swift` (`MerchantGapExportTaskBanner`, `MerchantGapManualAftercareSection`, `MerchantGapAINPCIntroSheet` 4-step intro, `CoopGapSupplyStationPickerSection`, `CoopGapNearbyReplacementSheet`, and TEST-only gated deposit/refund client).

### Account-Publish (`Core/MPGap/AccountPublish/`, `App/MPGap/AccountPublish/`)
- **`AP-G01` (M), `AP-G02` (L), `AP-G10` (L), `AP-G11` (M), `AP-G14` (M), `AP-G15` (M), `AP-G16` (S):** `Core/MPGap/AccountPublish/AccountPublishGapModels.swift`, `App/MPGap/AccountPublish/AccountPublishGapViews.swift` (`AccountGapOwnProfileComposerRow`, `SocialPublicProfileGapCoopBar`, `ProjectEditGapCastAndLookSection`, `SquareDetailGapPlayCardSection`, `TeamDetailGapApplicantsSection`, `TeamJoinGapManualCodeSection`).

### Strings & Tests
- `docs/port/strings/gap-g2-ops.json`
- `Tests/CoreTests/MPGap/G2OpsGapTests.swift`

## 3. Mount Hooks
All mount hooks (target file + location + snippet) are listed in:
- `docs/mp-gap/mounts-g2-ops.md`

## 4. Gaps Left (with reasons)
- **Owner-gated / Money-gated (UI/Core gated, not opened):**
  - `CLB-G17` (`POST /api/fe/reference-settlement/settle` — gated behind `allowsMoneyWrite: Bool`)
  - `CLB-G18` (`POST /api/club/payout-receiver/bind` — WeChat auth code owner decision)
  - `MC-G12` (`POST /api/merchant/ai-npc/voice/enroll` — owner-gated `MerchantCityNPCParityGates`)
  - `MC-G13` (`citynode`/`game-node` scan & writes — owner-gated)
  - `MC-G16` (`POST /api/coop/deposit/create`, `/refund/retry` — TEST-only money gate)
  - `AP-G09` (`POST /api/media/asset/{id}/retry` — owner-gated in `ChinaReviewedRouteCapability`)
- **Remaining S/M UI/deep-link wiring (needs existing-file edits at integration or follow-up pass):**
  - `CLB-G01`, `CLB-G02`, `CLB-G05`, `CLB-G07`, `CLB-G09`, `CLB-G10`, `CLB-G14`, `CLB-G15`, `CLB-G16`
  - `MC-G01`–`MC-G06`, `MC-G10`, `MC-G11`, `MC-G14`, `MC-G15`
  - `AP-G03`–`AP-G08`, `AP-G12`, `AP-G13`

## 5. Verification
- **Local:** `swiftc -parse` passed on all 13 new Swift files (`Core/MPGap/**/*.swift`, `App/MPGap/**/*.swift`, `Tests/CoreTests/MPGap/*.swift`). No local Xcode build or simulator tests run (disk-full rule).
- **Cloud acceptance:** `.github/workflows/acceptance.yml` is not yet present on `liboyang42-cpu/chengyin-app` (`gh workflow list` checked). Ready for `gh workflow run acceptance.yml --ref gap/g2-ops` once the workflow lands.
