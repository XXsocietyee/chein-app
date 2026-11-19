# consist-1 receipt: type scale, chrome rules, codemod and ratchet (step 1, no screen edits)

Branch `ui/consist-1` from `origin/ui/main`. No screen files were edited; six other branches own the screens.
Rule card: [`docs/design/type-and-chrome.md`](../../design/type-and-chrome.md).

## What changed

| file | change |
|---|---|
| `App/DesignSystem/CYDesignTokens.swift` | `CYTextStyle` + `CYTypeSpec`: the one scale (size = rpx ÷ 2, MP weight, MP line height, tracking 0, Dynamic Type style). `.cyText(_:weight:monospacedDigit:)` = font + `lineSpacing` + `@ScaledMetric`; a `@_disfavoredOverload` `Text.cyText` so `Text + Text` and `-> Text` sites still type-check. `CYTypography` names unchanged, values read the table |
| `App/Theme/Theme.swift` | `Theme.Font.*` delegate to the same table (one source) |
| `App/DesignSystem/CYScreenStyle.swift` | `cyPageTitle(_:)` / `cyPageTitle(verbatim:)`, `cyGuardedBack(when:onBack:)`, `cyHeroChrome(heroScrolledAway:)`, `cyKeepsSwipeBack()`; explicit inits on `CYBareBackButton` / `CYHeroBackButton` |
| `App/DesignSystem/CYPlayerKit.swift` | `CYSheetHeader` title 20 pt → `.cyText(.sheetTitle)` (22 pt = MP 44rpx) |
| `tools/typography_scale.py` | scale + mapping table shared by the tools |
| `tools/codemod_typography.py` | codemod, dry run by default, `--apply`, `--upgrade-tokens`, `--paths`; idempotent |
| `tools/report_chrome.py` | back / title deviations with a suggested fix |
| `tools/check_typography_lint.py` + `tools/typography_lint_baseline.json` | ratchet; wired into `tools/check_design_lint.py` (so CI, `check_scaffold.py` and release preflight run it) |
| `Tests/ContractChecks/test_design_token_unification_contract.py` | pinned `pageTitle … weight: .heavy` and `static let button = …` in Theme.swift; now pins the delegation and the new table rows |

Visible token-level changes (every caller gets them, no screen edit): page title heavy → bold, card title bold →
semibold, `bodyMedium` medium → semibold, sheet header title 20 → 22 pt, `bodyCompact` tight leading (only through
`.cyText`). Line spacing and Dynamic Type scaling come only through `.cyText`, i.e. after the sweep.

## Gates (run on this branch)

| gate | result |
|---|---|
| `python3 tools/check_scaffold.py` | PASS (structural checks, page route table 263, appsession ratchet) |
| `python3 tools/check_design_lint.py` | PASS design lint (0 violations) + PASS typography lint (baseline below) |
| `python3 tools/contract_ratchet.py --check` | 185 failing, baseline 184, **new 1, fixed 0**. The one new id, `test_workshop_paid_professional.PaidProfessionalContracts.test_current_generic_draft_cas_reuses_real_reader_with_bounded_paging`, fails identically on untouched `origin/ui/main` (run before any edit here), so this branch adds no new failure. The baseline was not changed |
| codemod self-test + idempotence | `--apply` on a scratch copy of the tree: 2752 rewrites; second dry run 0; `--upgrade-tokens` then 3822 more, re-run 0; lint after apply PASS with 647 counts below baseline |
| Swift compile | **not run**: no Swift toolchain here. The optional Tree-sitter preflight (`tools/check_swift_syntax.py`) could not be installed either: the served `tree-sitter` wheel did not match the pinned hash, and hash checking was not bypassed. The Swift was written against existing patterns in the same files; CI's Xcode build is the first real compile |

## Ratchet baseline (`tools/typography_lint_baseline.json`)

raw text style **3785**, Theme.Font **183**, raw size **72**, back chevron **15** (pagers excluded), hidden back
**16**, non-root large title **26**. Per file; any increase fails; `--update` lowers it after a sweep and refuses to
raise it without `--allow-increase`.

## Sweep plan for the coordinator (after the screen branches merge)

1. `python3 tools/codemod_typography.py` (dry run) and compare with the numbers below.
2. `python3 tools/codemod_typography.py --apply`, then fix the "left for a human" list (test-pinned sites: update
   the test literal in the same commit).
3. Optional second pass `--upgrade-tokens`: `.font(CYTypography.x)` → `.cyText(.x)` (3822 sites today), which is
   what turns on the Chinese line height and Dynamic Type for existing token callers.
4. `python3 tools/check_typography_lint.py --update` to ratchet the baseline down; commit it with the sweep.
5. Chrome: work through `python3 tools/report_chrome.py` (hidden backs → `cyGuardedBack`, hero pages →
   `cyHeroChrome` + `CYHeroBackButton` keeping `heroBack.*` identifiers for UI tests, unset title modes →
   `cyPageTitle`).

Club scope alone (`--paths App/Club`): 176 rewrites in 40 files, 61 left for a human; 26 chrome items.

## Chrome report summary (`python3 tools/report_chrome.py`)

| count | kind |
|---:|---|
| 341 | title-mode-unset |
| 27 | large-title |
| 16 | hidden-back |
| 10 | chevron:back |
| 5 | hidden-bar |
| 4 | chevron:design-system |
| 4 | chevron:pager |
| 3 | custom-navbar |
| 3 | hero-chrome |
| 1 | chevron:step-back |

Full list: run the script (each line has file:line and the fix).

## Codemod

`--upgrade-tokens` dry run in addition: 6574 rewrites in 1041 files (3822 of them `CYTypography.x` → `.cyText(.x)`,
all exact), 1343 left for a human.

### Dry run (`python3 tools/codemod_typography.py`) on ui/consist-1

- replacements: **2752** in 630 files
- confidence: exact 1202, context 122, nearest 4, default 1424
- left for a human: **1281**

#### Replacements per mapping

| count | mapping | confidence |
|---:|---|---|
| 714 | `.caption -> meta` | exact 714 |
| 670 | `.footnote -> bodyCompact` | default 670 |
| 343 | `.headline -> cardTitle` | default 343 |
| 128 | `.subheadline.weight(.semibold) -> bodyMedium` | default 128 |
| 110 | `.caption2 -> caption` | exact 110 |
| 77 | `.caption.weight(.semibold) -> meta (weight .semibold)` | exact 77 |
| 61 | `.footnote -> meta` | context 61 |
| 52 | `Theme.Font.label -> label` | exact 52 |
| 51 | `.body -> body` | default 51 |
| 51 | `.caption2.weight(.semibold) -> caption (weight .semibold)` | exact 51 |
| 49 | `.subheadline.weight(.medium) -> bodyMedium` | default 49 |
| 31 | `.subheadline.weight(.bold) -> bodyMedium` | default 31 |
| 27 | `.caption2.weight(.bold) -> caption (weight .bold)` | exact 27 |
| 26 | `.title2.weight(.bold) -> sheetTitle` | exact 26 |
| 26 | `Theme.Font.sectionTitle -> sectionTitle` | exact 26 |
| 24 | `.caption.weight(.bold) -> meta (weight .bold)` | exact 24 |
| 24 | `.footnote.weight(.semibold) -> bodyMedium` | default 24 |
| 23 | `.title3.weight(.bold) -> sectionTitle` | default 23 |
| 16 | `.footnote.weight(.medium) -> bodyMedium` | default 16 |
| 15 | `.body.weight(.semibold) -> cardTitle` | default 15 |
| 15 | `.title3.weight(.semibold) -> sectionTitle` | default 15 |
| 15 | `.callout -> body` | default 15 |
| 14 | `Theme.Font.button -> button` | exact 14 |
| 13 | `Theme.Font.cardTitle -> cardTitle` | exact 13 |
| 13 | `.footnote -> numericBody` | context 13 |
| 13 | `.title2 -> sheetTitle` | exact 13 |
| 12 | `.caption2.weight(.medium) -> caption (weight .medium)` | exact 12 |
| 12 | `.caption.weight(.medium) -> label` | exact 12 |
| 10 | `.largeTitle.weight(.bold) -> dataXL` | context 10 |
| 10 | `.title3 -> sectionTitle` | default 10 |
| 8 | `.largeTitle.weight(.bold) -> pageTitle` | default 8 |
| 8 | `.title2.weight(.bold) -> dataXL` | context 8 |
| 7 | `.title.weight(.bold) -> display` | exact 7 |
| 7 | `.largeTitle.weight(.heavy) -> pageTitle` | default 7 |
| 7 | `.largeTitle.weight(.heavy) -> dataXL` | context 7 |
| 6 | `Theme.Font.sheetTitle -> sheetTitle` | exact 6 |
| 4 | `.body.weight(.bold) -> cardTitle` | default 4 |
| 4 | `.title.weight(.heavy) -> dataXL` | context 4 |
| 4 | `.body -> numericBody` | context 4 |
| 4 | `.subheadline -> numericBody` | context 4 |
| 3 | `.footnote.weight(.bold) -> bodyMedium` | default 3 |
| 3 | `.title.weight(.heavy) -> display` | exact 3 |
| 3 | `.title2.weight(.heavy) -> dataXL` | context 3 |
| 3 | `Theme.Font.pageTitle -> pageTitle` | exact 3 |
| 2 | `.subheadline -> body` | default 2 |
| 2 | `.title3.weight(.heavy) -> sectionTitle` | default 2 |
| 2 | `.title2.weight(.heavy) -> sheetTitle` | exact 2 |
| 2 | `.system(size: 13) -> label` | nearest 2 |
| 2 | `.subheadline.weight(.semibold) -> numericBody` | context 2 |
| 2 | `.title3.weight(.medium) -> sectionTitle (weight .medium)` | default 2 |
| 2 | `.largeTitle -> dataXL` | context 2 |
| 2 | `Theme.Font.dataXL -> dataXL` | exact 2 |
| 1 | `.body.weight(.medium) -> bodyMedium` | default 1 |
| 1 | `Theme.Font.caption -> caption` | exact 1 |
| 1 | `.title.weight(.semibold) -> dataXL` | context 1 |
| 1 | `.body.weight(.medium) -> numericBody` | context 1 |
| 1 | `.callout.weight(.semibold) -> cardTitle` | default 1 |
| 1 | `.largeTitle.weight(.semibold) -> pageTitle` | default 1 |
| 1 | `.system(size: 17) -> cardTitle` | nearest 1 |
| 1 | `Theme.Font.body -> body` | exact 1 |
| 1 | `.headline.weight(.heavy) -> cardTitle (weight .heavy)` | default 1 |
| 1 | `.system(size: 11) -> caption (weight .bold)` | exact 1 |
| 1 | `.system(size: 12) -> meta (weight .semibold)` | exact 1 |
| 1 | `.system(size: 10) -> micro` | exact 1 |
| 1 | `.system(size: 15) -> body` | nearest 1 |
| 1 | `.footnote.weight(.bold) -> numericBody` | context 1 |
| 1 | `.title.weight(.bold) -> dataXL` | context 1 |
| 1 | `.title2.weight(.semibold) -> sheetTitle` | exact 1 |
| 1 | `.largeTitle.weight(.light) -> pageTitle (weight .light)` | default 1 |
| 1 | `.largeTitle -> pageTitle` | default 1 |
| 1 | `Theme.Font.label -> label (weight .bold)` | exact 1 |
| 1 | `Theme.Font.label -> label (weight .semibold)` | exact 1 |

#### Left for a human, by reason

| count | reason |
|---:|---|
| 672 | pinned by a contract test; update the test in the same commit |
| 314 | SF Symbol icon size (keep the text style or match the adjacent text token) |
| 227 | monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand |
| 49 | dynamic expression (ternary / variable / computed size) |
| 6 | monospaced design (code / ticket number) |
| 4 | rounded design on .title3 (number?) |
| 4 | unsupported modifier italic() |
| 2 | rounded design on .headline (number?) |
| 1 | decorative size 120 pt (illustration / emoji / glyph); keep or use an image |
| 1 | rounded design on .caption (number?) |
| 1 | design .serif |

#### Ambiguous sites

- `App/AccessibilityReadinessSectionView.swift:137` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/AccountCollectionComponents.swift:156` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/AccountCollectionCouponDetailView.swift:81` `.font(.footnote)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/AccountComplianceViews.swift:68` `.font(.footnote.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/AccountComplianceViews.swift:237` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/AccountComplianceViews.swift:272` `.font(.headline)` — pinned by a contract test; update the test in the same commit
- `App/AccountComplianceViews.swift:275` `.font(.headline)` — pinned by a contract test; update the test in the same commit
- `App/AccountComplianceViews.swift:318` `.font(.subheadline.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/AccountComplianceViews.swift:322` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/AccountComplianceViews.swift:362` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/AccountComplianceViews.swift:364` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/AccountComplianceViews.swift:365` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/AccountComplianceViews.swift:367` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/AccountComplianceViews.swift:484` `.font(.headline)` — pinned by a contract test; update the test in the same commit
- `App/AccountComplianceViews.swift:490` `.font(.system(.headline, design: .rounded, weight: .bold))` — rounded design on .headline (number?)
- `App/AccountComplianceViews.swift:495` `.font(.headline)` — pinned by a contract test; update the test in the same commit
- `App/AccountComplianceViews.swift:506` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/AccountComplianceViews.swift:644` `.font(.title2.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/AccountComplianceViews.swift:660` `.font(.caption2.weight(.heavy))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/AccountDeletionAndGDPRPIPLSectionView.swift:135` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/AccountDeregistrationImpactSection.swift:33` `.font(.system(.subheadline, weight: .semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/AccountDeregistrationImpactSection.swift:46` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/AccountDeregistrationImpactSection.swift:62` `.font(Theme.Font.body)` — pinned by a contract test; update the test in the same commit
- `App/AccountDeregistrationImpactSection.swift:81` `.font(.system(.title3, design: .rounded, weight: .semibold))` — rounded design on .title3 (number?)
- `App/AccountDeregistrationImpactSection.swift:98` `.font(Theme.Font.body)` — pinned by a contract test; update the test in the same commit
- `App/ActiveDestinationSummary.swift:24` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/ActivityAssociatedPlaysSection.swift:26` `.font(.headline)` — pinned by a contract test; update the test in the same commit
- `App/ActivityAssociatedPlaysSection.swift:27` `.font(.headline)` — pinned by a contract test; update the test in the same commit
- `App/ActivityDetailView.swift:478` `.font(.footnote.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/ActivityDetailView.swift:738` `.font(.title3)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/ActivityHostCancelView.swift:186` `.font(.title2)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/ActivityPeopleSection.swift:48` `.font(.title2)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/ActivityPeopleSection.swift:54` `.font(.caption)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/ActivityPresentationComponents.swift:42` `.font(.footnote.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/ActivityPresentationComponents.swift:158` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/ActivityReviewsSection.swift:91` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/AppStoreConnectMetadataAndScreenshotSectionView.swift:157` `.font(.footnote.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/AppStoreConnectMetadataAndScreenshotSectionView.swift:173` `.font(.caption2.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/AppStorePrivacyManifestSectionView.swift:148` `.font(.footnote.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/AppStorePrivacyManifestSectionView.swift:158` `.font(.caption2.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/AppStorePrivacyManifestSectionView.swift:170` `.font(.caption2.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/AppStoreReviewDemoAccountAndFixtureSectionView.swift:168` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/AppStoreReviewDemoAccountAndFixtureSectionView.swift:171` `.font(.caption.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/AppStoreSubmissionFinalPreflightGateView.swift:144` `.font(.footnote.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/AppStoreSubmissionFinalPreflightGateView.swift:161` `.font(.caption2.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/AppStoreSubmissionReadinessSectionView.swift:194` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/AppStoreSubmissionReadinessSectionView.swift:231` `.font(.caption2.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/AppStoreSubmissionReadinessSectionView.swift:247` `.font(.caption2.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/AssetPointsAndOrderCancellationSectionView.swift:216` `.font(.subheadline.monospaced().weight(.semibold))` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/AudioAndMediaPipelineSectionView.swift:154` `.font(.footnote.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/AudioAndMediaPipelineSectionView.swift:159` `.font(.footnote.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/AudioAndMediaPipelineSectionView.swift:164` `.font(.footnote.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/AudioAndMediaPipelineSectionView.swift:176` `.font(.caption2.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/AuthAndSessionAdmissionSectionView.swift:171` `.font(.caption.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/AuthAndSessionAdmissionSectionView.swift:183` `.font(.caption.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/AuthAndSessionAdmissionSectionView.swift:205` `.font(.caption.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/AuthAndSessionAdmissionSectionView.swift:219` `.font(.caption.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/AuthChannelView.swift:174` `.font(.system(.title3, design: .rounded).monospacedDigit())` — rounded design on .title3 (number?)
- `App/AuthChannelView.swift:265` `.font(.footnote.weight(.medium))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/BackendRolloutAllowlistSwitchboardSectionView.swift:188` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/BackendRolloutAllowlistSwitchboardSectionView.swift:231` `.font(.caption2.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/BackendSyncAndContractGateSectionView.swift:163` `.font(.caption.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/BackendSyncAndContractGateSectionView.swift:178` `.font(.caption2.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/BackendSyncAndContractGateSectionView.swift:188` `.font(.caption2.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/BundleAppealView.swift:120` `.font(.footnote.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/BundleShelfView.swift:72` `.font(.footnote.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/BundleVoucherView.swift:53` `.font(.body.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/ChannelAdmissionGovernanceView.swift:78` `.font(.footnote.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/ChapterReplacementInvitationView.swift:186` `.font(.footnote.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/ChapterReplacementInvitationView.swift:230` `.font(.footnote.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/ChapterStoryView.swift:288` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/CityAcquisitionPresentationStyle.swift:8` `.font(Theme.Font.body)` — pinned by a contract test; update the test in the same commit
- `App/CityAcquisitionPresentationStyle.swift:23` `.font(Theme.Font.body)` — pinned by a contract test; update the test in the same commit
- `App/CityGamePanel.swift:201` `.font(.system(.title3, design: .rounded).weight(.bold))` — rounded design on .title3 (number?)
- `App/CityKit/CityBoardScreens.swift:159` `.font(.body.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/CityKit/CityBoardScreens.swift:167` `.font(.footnote.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/CityKit/CityDeedCard.swift:65` `.font(.title2)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/CityKit/CityMapLayer.swift:120` `.font(.footnote.weight(.bold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/CityKit/CityMapLayer.swift:124` `.font(.footnote.weight(.bold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/CityKit/CityMapLayer.swift:128` `.font(.caption.weight(.bold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/CityKit/CityMapLayer.swift:146` `.font(.caption2.weight(.bold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/CityKit/CityMapLayer.swift:149` `.font(.caption2.weight(.black))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/CityKit/CityPropertySheet.swift:83` `.font(.footnote.weight(.bold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/CityKit/CityPropertySheet.swift:212` `.font(.footnote.weight(.bold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/CityKit/CityRoamRootView.swift:155` `.font(.caption2.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/CityKit/CityTokens.swift:89` `.font(.system(.caption2, design: .rounded).weight(.black))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/CityKit/CityTokens.swift:176` `.font(.body.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/CityMerchantOperationsView.swift:55` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/CityMerchantOperationsView.swift:65` `.font(.body.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/CityMerchantOperationsView.swift:73` `.font(.body.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/CityMerchantOperationsView.swift:96` `.font(.footnote.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/CityMerchantOperationsView.swift:173` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/CityMerchantOperationsView.swift:175` `.font(.body.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/CityMerchantValueView.swift:46` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/CityMerchantValueView.swift:55` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/CityMonopolyTerritorySection.swift:112` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/CityOrderedMapView.swift:115` `.font(.footnote.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/CityParticipationRuntimeHostView.swift:44` `.font(.largeTitle)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/CityPlayerValueNodeView.swift:33` `.font(.largeTitle)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/CityPlayerView.swift:298` `.font(.footnote.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/CitySwitchAndCrossCityRoamingSectionView.swift:136` `.font(.caption.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/CitySwitchAndCrossCityRoamingSectionView.swift:151` `.font(.caption.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/CitySwitchAndCrossCityRoamingSectionView.swift:181` `.font(.caption.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/CityTaskHistoryRuntimeHostView.swift:38` `.font(.largeTitle)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/CloudCIShardStatusSectionView.swift:157` `.font(.caption.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/CloudCIShardStatusSectionView.swift:178` `.font(.caption2.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/ClubAIDesignView.swift:63` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/ClubAIDesignView.swift:65` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/ClubAccessAndSettlementSectionView.swift:156` `.font(.footnote.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/ClubAccessAndSettlementSectionView.swift:166` `.font(.footnote.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/ClubAccessAndSettlementSectionView.swift:178` `.font(.caption2.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/ClubActivityListContent.swift:56` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/ClubActivityListContent.swift:57` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/ClubActivityListContent.swift:58` `.font(.caption)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/ClubActivityReportView.swift:227` `.font(.footnote.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/ClubAndTeamCoopGovernanceSectionView.swift:179` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/ClubAndTeamCoopGovernanceSectionView.swift:216` `.font(.caption2.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/ClubChannelMessagingView.swift:670` `.font(.caption)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/ClubChannelMessagingView.swift:725` `.font(.subheadline.weight(.bold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/ClubChannelMessagingView.swift:933` `.font(.caption2)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/ClubChannelMessagingView.swift:959` `.font(.caption)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/ClubChannelMessagingView.swift:991` `.font(.caption2)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/ClubCheckinRailView.swift:61` `.font(.body.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/ClubComponents.swift:57` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/ClubComponents.swift:61` `.font(.footnote)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/ClubComponents.swift:198` `.font(.caption.weight(.bold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/ClubComponents.swift:199` `.font(.caption.weight(.bold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/ClubComponents.swift:261` `.font(.body.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/ClubComponents.swift:319` `.font(.subheadline)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/ClubComponents.swift:345` `.font(.title3)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/ClubComponents.swift:352` `.font(.title3)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/ClubComponents.swift:369` `.font(.title3)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/ClubComponents.swift:405` `.font(.body.weight(selected == day || today == day ? .semibold : .regular))` — dynamic expression (ternary / variable / computed size)
- `App/ClubEnrollmentView.swift:257` `.font(.footnote.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/ClubEnrollmentView.swift:267` `.font(.footnote.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/ClubEventCalendarView.swift:310` `.font(.footnote.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/ClubGovernanceFeedPostView.swift:105` `.font(.footnote.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/ClubGovernanceViews.swift:639` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/ClubGovernanceViews.swift:1506` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/ClubGovernanceViews.swift:1901` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/ClubGroupCodePresentation.swift:23` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/ClubManagementView.swift:308` `.font(.footnote.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/ClubManagementView.swift:361` `.font(.footnote.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/ClubMerchantDiscoveryView.swift:93` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/ClubMerchantDiscoveryView.swift:94` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/ClubNodeAnswerContent.swift:28` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/ClubOperationsViews.swift:276` `.font(.title2)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/ClubOperationsViews.swift:283` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/ClubOperationsViews.swift:483` `.font(flow.canEnterManagement ? .headline : .body)` — dynamic expression (ternary / variable / computed size)
- `App/ClubOperationsViews.swift:1207` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/ClubOperationsViews.swift:1224` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/ClubOpsCustomerViews.swift:363` `.font(.footnote.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/ClubParticipationTrendSection.swift:114` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/ClubPostDiscussion.swift:60` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/ClubProfileChoiceEditor.swift:60` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/ClubProfileChoiceEditor.swift:61` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/ClubSettlementDetail.swift:239` `.font(.footnote.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/ClubSettlementDetail.swift:248` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/ClubSettlementDetail.swift:249` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/ClubSettlementDetail.swift:281` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/ClubTopicMerchantContent.swift:36` `.font(.title3)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/ClubTopicMerchantContent.swift:40` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/ClubTopicMerchantContent.swift:41` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/ClubWelcomeNoteEditor.swift:24` `.font(Theme.Font.body)` — pinned by a contract test; update the test in the same commit
- `App/ClubWelcomeNoteEditor.swift:102` `.font(Theme.Font.body)` — pinned by a contract test; update the test in the same commit
- `App/ClubWelcomeNoteEditor.swift:186` `.font(Theme.Font.body)` — pinned by a contract test; update the test in the same commit
- `App/ClubWelcomeNoteEditor.swift:242` `.font(Theme.Font.body)` — pinned by a contract test; update the test in the same commit
- `App/CommerceAndWalletSafetySectionView.swift:158` `.font(.footnote.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/CommerceAndWalletSafetySectionView.swift:175` `.font(.caption2.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/CommerceAndWalletSafetySectionView.swift:200` `.font(.caption2.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/CoopFinanceSummarySection.swift:11` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/CoopListParitySections.swift:83` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/CoopListParitySections.swift:84` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/CoopPoolApplicationEditor.swift:75` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/CoopPoolApplicationEditor.swift:187` `.font(.headline)` — pinned by a contract test; update the test in the same commit
- `App/CoopPoolApplicationEditor.swift:188` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/CoopPoolApplicationEditor.swift:193` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/CoopRelationCardDetails+Port.swift:18` `.font(.footnote)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/CoopRelationCardDetails+Port.swift:31` `.font(.footnote)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/CooperationFlowEditors.swift:33` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/CooperationFlowEditors.swift:39` `.font(name == nil ? .body : .caption)` — dynamic expression (ternary / variable / computed size)
- `App/CooperationFlowEditors.swift:174` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/CooperationFlowEditors.swift:293` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/CooperationFlowEditors.swift:381` `.font(.headline)` — pinned by a contract test; update the test in the same commit
- `App/CooperationFlowWorkbench.swift:191` `.font(.headline)` — pinned by a contract test; update the test in the same commit
- `App/CouponAndSponsoredRewardSafetySectionView.swift:131` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/CouponCodeView.swift:49` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/CouponCodeView.swift:50` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/CouponCodeView.swift:117` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/CouponCodeView.swift:145` `.font(.title.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/CouponManagementView.swift:146` `.font(.body.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/CrashResilienceAndMetricKitDiagnosticsSectionView.swift:177` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/CrashResilienceAndMetricKitDiagnosticsSectionView.swift:214` `.font(.caption2.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/CrashResilienceAndMetricKitDiagnosticsSectionView.swift:224` `.font(.caption2.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/CreatorContentViews.swift:37` `.font(.largeTitle)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/DeepLinkSafetyDiagnosticsSectionView.swift:290` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/DeepLinkSafetyDiagnosticsSectionView.swift:293` `.font(.caption.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/DeepLinkSafetyDiagnosticsSectionView.swift:315` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/DeepLinkSafetyDiagnosticsSectionView.swift:318` `.font(.caption.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/DesignFixtures/E3Fixtures.swift:195` `.font(.footnote.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/DesignFixtures/E3Fixtures.swift:268` `.font(.title3.weight(.medium))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/DesignFixtures/E3Fixtures.swift:272` `.font(.subheadline.weight(.bold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/DesignFixtures/E3Fixtures.swift:320` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/DesignFixtures/IAFixtures.swift:15` `.font(.largeTitle)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/DesignSystem/CYAlbum.swift:117` `.font(.system(size: size * 0.14, weight: .semibold, design: .rounded))` — dynamic expression (ternary / variable / computed size)
- `App/DesignSystem/CYAlbum.swift:121` `.font(.system(size: size * 0.30, weight: .bold, design: .rounded))` — dynamic expression (ternary / variable / computed size)
- `App/DesignSystem/CYAlbum.swift:225` `.font(.caption.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/DesignSystem/CYBadgeCraft.swift:146` `.font(.system(size: size * (kind == .medal ? 0.36 : 0.30), weight: .semibold))` — dynamic expression (ternary / variable / computed size)
- `App/DesignSystem/CYBusinessComponents.swift:115` `.font(.system(size: 56, weight: .regular))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/DesignSystem/CYBusinessComponents.swift:148` `.font(.system(size: 11, weight: .bold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/DesignSystem/CYBusinessComponents.swift:385` `.font(.system(size: 12, weight: .bold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/DesignSystem/CYBusinessComponents.swift:389` `.font(.system(size: 11, weight: .semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/DesignSystem/CYBusinessComponents.swift:521` `.font(.system(size: 16, weight: .semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/DesignSystem/CYBusinessComponents.swift:746` `.font(.caption.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/DesignSystem/CYBusinessComponents.swift:1013` `.font(.system(size: 13, weight: .bold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/DesignSystem/CYCelebrationViews.swift:359` `.font(.system(size: s * 0.38, weight: .bold))` — dynamic expression (ternary / variable / computed size)
- `App/DesignSystem/CYCelebrationViews.swift:361` `.font(.system(size: s * 0.38, weight: .bold))` — dynamic expression (ternary / variable / computed size)
- `App/DesignSystem/CYCelebrationViews.swift:397` `.font(.system(size: 22, weight: .semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/DesignSystem/CYCelebrationViews.swift:674` `.font(.system(size: 44, weight: .regular))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/DesignSystem/CYCelebrationViews.swift:735` `.font(emphasis == .hero ? .system(size: heroSize, weight: .bold, design: .rounded) : CYTypography.dataXL)` — dynamic expression (ternary / variable / computed size)
- `App/DesignSystem/CYChapterFlip.swift:25` `.font(.system(size: 120, weight: .heavy, design: .rounded))` — decorative size 120 pt (illustration / emoji / glyph); keep or use an image
- `App/DesignSystem/CYChapterFlip.swift:109` `.font(.system(size: 72))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/DesignSystem/CYChapterFlip.swift:110` `.font(.system(size: 30, weight: .bold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/DesignSystem/CYChromeBars.swift:162` `.font(.system(size: 16, weight: .semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/DesignSystem/CYChromeBars.swift:170` `.font(.system(size: 18, weight: .semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/DesignSystem/CYCityBoard.swift:168` `.font(.system(size: size * 0.38, weight: .semibold))` — dynamic expression (ternary / variable / computed size)
- `App/DesignSystem/CYCityKit.swift:17` `.font(.body.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/DesignSystem/CYCityKit.swift:101` `.font(.body.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/DesignSystem/CYCityKit.swift:145` `.font(.title3)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/DesignSystem/CYCityKit.swift:234` `.font(.body.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/DesignSystem/CYCityKit.swift:241` `.font(.footnote.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/DesignSystem/CYCityKit.swift:277` `.font(.caption.weight(.bold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/DesignSystem/CYCollectible.swift:25` `.font(.system(size: size * 0.32, weight: .semibold))` — dynamic expression (ternary / variable / computed size)
- `App/DesignSystem/CYCollectible.swift:35` `.font(.system(size: size * 0.38, weight: .semibold))` — dynamic expression (ternary / variable / computed size)
- `App/DesignSystem/CYCollectible.swift:139` `.font(.system(size: 92, weight: .semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/DesignSystem/CYCollectible.swift:153` `.font(.system(size: 64, weight: .bold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/DesignSystem/CYCollectible.swift:201` `.font(.system(size: size * 0.26, weight: .bold, design: .rounded))` — dynamic expression (ternary / variable / computed size)
- `App/DesignSystem/CYConfirmSheet.swift:190` `.font(.system(.title2, design: .rounded).weight(.heavy))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/DesignSystem/CYCoverArt.swift:51` `.font(.system(size: size * 0.2, weight: .semibold))` — dynamic expression (ternary / variable / computed size)
- `App/DesignSystem/CYDesignComponents.swift:203` `.font(.caption.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/DesignSystem/CYDesignComponents.swift:271` `.font(.system(size: 14, weight: .bold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/DesignSystem/CYDomainTabBar.swift:222` `.font(.system(size: 20, weight: isSelected ? .semibold : .regular))` — dynamic expression (ternary / variable / computed size)
- `App/DesignSystem/CYDomainTabBar.swift:415` `.font(.footnote.weight(.bold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/DesignSystem/CYExploreKit.swift:129` `.font(.footnote.weight(isChinese ? .medium : .semibold))` — dynamic expression (ternary / variable / computed size)
- `App/DesignSystem/CYExploreKit.swift:156` `.font(.system(size: 22, weight: .semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/DesignSystem/CYField.swift:251` `.font(.system(size: 16, weight: .semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/DesignSystem/CYGoHold.swift:156` `.font(.system(size: 20, weight: .heavy))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/DesignSystem/CYJoinReward.swift:89` `.font(.system(.title3, design: .rounded).weight(.heavy))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/DesignSystem/CYListRow.swift:232` `.font(.footnote.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/DesignSystem/CYListRow.swift:255` `.font(.body.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/DesignSystem/CYMapChrome.swift:79` `.font(.system(.body).weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/DesignSystem/CYMapChrome.swift:140` `.font(.system(.title).weight(.heavy))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/DesignSystem/CYMapChrome.swift:142` `.font(.system(.title, design: .default).weight(.heavy).italic())` — unsupported modifier italic()
- `App/DesignSystem/CYMapChrome.swift:279` `.font(.system(size: 9))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/DesignSystem/CYMedalStack.swift:60` `.font(.system(size: side * 0.36, weight: .semibold))` — dynamic expression (ternary / variable / computed size)
- `App/DesignSystem/CYMedalStack.swift:220` `.font(.headline)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/DesignSystem/CYMedalStack.swift:298` `.font(.title3)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/DesignSystem/CYMorphButton.swift:80` `.font(.system(.body).weight(.heavy))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/DesignSystem/CYOnboarding.swift:208` `.font(.system(.title3, design: .rounded).weight(OBType.isChinese(locale) ? .semibold : .heavy))` — dynamic expression (ternary / variable / computed size)
- `App/DesignSystem/CYOnboarding.swift:325` `.font(.footnote.weight(zh ? .medium : .semibold))` — dynamic expression (ternary / variable / computed size)
- `App/DesignSystem/CYOnboarding.swift:332` `.font(zh ? .system(size: zhTitleSize, weight: .semibold) : .system(.largeTitle, design: .rounded).weight(.heavy))` — dynamic expression (ternary / variable / computed size)
- `App/DesignSystem/CYOnboarding.swift:567` `.font(.system(.title, design: .rounded).weight(.heavy))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/DesignSystem/CYOnboarding.swift:590` `.font(.caption2.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/DesignSystem/CYOnboarding.swift:591` `.font(.system(.caption, design: .rounded).weight(.bold).monospacedDigit())` — rounded design on .caption (number?)
- `App/DesignSystem/CYOnboardingLight.swift:166` `.font(.system(size: fontSize, weight: heavy ? .heavy : .semibold, design: .rounded))` — dynamic expression (ternary / variable / computed size)
- `App/DesignSystem/CYOnboardingLight.swift:322` `.font(.system(.title3).weight(.heavy))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/DesignSystem/CYOnboardingLight.swift:355` `.font(.system(size: 17))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/DesignSystem/CYPassVerified.swift:83` `.font(.system(size: 28, weight: .semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/DesignSystem/CYPassVerified.swift:90` `.font(.system(.largeTitle, design: c.isChinese ? .default : .rounded).weight(c.isChinese ? .semibold : .heavy))` — dynamic expression (ternary / variable / computed size)
- `App/DesignSystem/CYPermissionPrimer.swift:196` `.font(.system(size: glyphSize, weight: .regular))` — dynamic expression (ternary / variable / computed size)
- `App/DesignSystem/CYPlayVerdict.swift:115` `.font(.system(size: 88, weight: .semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/DesignSystem/CYPlayVerdict.swift:122` `.font(.system(size: 72, weight: .semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/DesignSystem/CYPlayVerdict.swift:127` `.font(.system(size: 72, weight: .semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/DesignSystem/CYPlayerKit.swift:185` `.font(.body.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/DesignSystem/CYPlayerKit.swift:482` `.font(.subheadline.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/DesignSystem/CYPlayerKit.swift:867` `.font(.largeTitle.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/DesignSystem/CYPlayerKit.swift:882` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/DesignSystem/CYPurchaseMotion.swift:151` `.font(.body.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/DesignSystem/CYPurchaseMotion.swift:246` `.font(.footnote.weight(.bold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/DesignSystem/CYRoamKit.swift:326` `.font(.footnote.weight(.bold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/DesignSystem/CYRoamKit.swift:466` `.font(.title3.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/DesignSystem/CYScreenStyle.swift:228` `.font(.body.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/DesignSystem/CYScreenStyle.swift:255` `.font(.subheadline.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/DesignSystem/CYScreenStyle.swift:352` `.font(.body.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/DesignSystem/CYShareCard.swift:337` `.font(.system(size: valueSize, weight: .bold, design: .rounded))` — dynamic expression (ternary / variable / computed size)
- `App/DesignSystem/CYShareCard.swift:375` `.font(.system(size: size * 0.4, weight: .semibold))` — dynamic expression (ternary / variable / computed size)
- `App/DesignSystem/CYShareCard.swift:407` `.font(.system(size: ratio.metric(34, 26), weight: .heavy))` — dynamic expression (ternary / variable / computed size)
- `App/DesignSystem/CYShareCard.swift:444` `.font(.system(size: ratio.metric(28, 22), weight: .heavy))` — dynamic expression (ternary / variable / computed size)
- `App/DesignSystem/CYShareCard.swift:513` `.font(.system(size: ratio.metric(40, 30), weight: .bold, design: .serif))` — dynamic expression (ternary / variable / computed size)
- `App/DesignSystem/CYShareCard.swift:534` `.font(.system(size: ratio.metric(20, 17), weight: .semibold, design: .rounded))` — dynamic expression (ternary / variable / computed size)
- `App/DesignSystem/CYShareComposer.swift:73` `.font(.title3)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/DesignSystem/CYShareComposer.swift:154` `.font(.footnote.weight(.bold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/DesignSystem/CYSharedStates.swift:280` `.font(.system(size: 16, weight: .semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/DesignSystem/CYSheetModal.swift:66` `.font(.system(size: 14, weight: .semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/DesignSystem/CYSheetModal.swift:246` `.font(.system(size: 18, weight: .semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/DesignSystem/CYSheetModal.swift:266` `.font(.system(size: 14, weight: .bold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/DesignSystem/CYSheetModal.swift:384` `.font(.system(size: 13, weight: .semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/DesignSystem/CYSignature.swift:48` `.font(.system(size: min(proxy.size.width, proxy.size.height) * 0.42, weight: .semibold))` — dynamic expression (ternary / variable / computed size)
- `App/DesignSystem/CYSignature.swift:54` `.font(.system(size: 8, weight: .bold, design: .monospaced))` — monospaced design (code / ticket number)
- `App/DesignSystem/CYStampContinuity.swift:33` `.font(.title3.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/DesignSystem/CYStampContinuity.swift:39` `.font(.title3)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/DesignSystem/CYStarBloom.swift:94` `.font(.system(size: 10 + Double(i % 3) * 4))` — dynamic expression (ternary / variable / computed size)
- `App/DesignSystem/CYStateKit.swift:132` `.font(.system(size: size * 0.30, weight: .semibold))` — dynamic expression (ternary / variable / computed size)
- `App/DesignSystem/CYStateKit.swift:142` `.font(.system(size: size * 0.14, weight: .bold))` — dynamic expression (ternary / variable / computed size)
- `App/DesignSystem/CYStateKit.swift:149` `.font(.system(size: size * 0.11))` — dynamic expression (ternary / variable / computed size)
- `App/DesignSystem/CYStateKit.swift:150` `.font(.system(size: size * 0.07))` — dynamic expression (ternary / variable / computed size)
- `App/DesignSystem/CYStateKit.swift:264` `.font(.footnote.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/DesignSystem/CYStateView.swift:94` `.font(.system(size: glyphSize, weight: .regular))` — dynamic expression (ternary / variable / computed size)
- `App/DeviceOrientationAndSplitViewAdaptationSectionView.swift:155` `.font(.caption2.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/DiscoveryComponents.swift:108` `.font(.footnote.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/E1ActivityDetailParts.swift:35` `.font(.system(dynamicTypeSize.isAccessibilitySize ? .title : .largeTitle, design: .default).weight(.bold))` — dynamic expression (ternary / variable / computed size)
- `App/E1CommerceComponents.swift:47` `.font(.title)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/E1CommerceComponents.swift:87` `.font(.caption.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/E1OfficialRouteParts.swift:33` `.font(.footnote.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/E1OfficialRouteParts.swift:98` `.font(.system(dynamicTypeSize.isAccessibilitySize ? .title : .largeTitle).weight(.bold))` — dynamic expression (ternary / variable / computed size)
- `App/E1OfficialRouteParts.swift:124` `.font(.subheadline.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/E1OfficialRouteParts.swift:169` `.font(.title3)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/EditorKitCards.swift:33` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/EditorKitCards.swift:39` `.font(.footnote.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/EditorKitCards.swift:136` `.font(.subheadline.weight(state == .current ? .semibold : .regular))` — dynamic expression (ternary / variable / computed size)
- `App/EditorKitCards.swift:141` `.font(.caption2.weight(.bold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/EditorKitCards.swift:186` `.font(.caption2.weight(.bold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/EditorKitCards.swift:229` `.font(.footnote.weight(index == progress.current ? .semibold : .regular))` — dynamic expression (ternary / variable / computed size)
- `App/EditorKitCards.swift:269` `.font(.body.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/EditorKitFeedback.swift:136` `.font(.footnote.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/EditorKitFeedback.swift:137` `.font(.subheadline.weight(state == .added ? .semibold : .regular))` — dynamic expression (ternary / variable / computed size)
- `App/EditorKitFields.swift:45` `.font(.footnote)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/EditorKitFields.swift:246` `.font(.footnote.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/EditorKitFields.swift:311` `.font(.body)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/EditorKitFields.swift:324` `.font(.footnote)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/EditorKitFields.swift:329` `.font(.footnote.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/EditorKitFields.swift:332` `.font(.footnote.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/EditorKitFields.swift:388` `.font(.body.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/EditorKitFields.swift:393` `.font(.title3)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/EditorKitFields.swift:428` `.font(.footnote.weight(.medium))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/EditorKitFields.swift:432` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/EditorKitFields.swift:435` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/EditorKitLists.swift:34` `.font(.body.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/EditorKitLists.swift:67` `.font(.body.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/EditorKitLists.swift:132` `.font(.body.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/EditorKitLists.swift:313` `.font(.title3)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/EditorKitResults.swift:41` `.font(.largeTitle)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/EditorKitResults.swift:49` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/EditorKitResults.swift:127` `.font(.title2)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/EditorKitResults.swift:194` `.font(.footnote.weight(.bold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/EditorKitResults.swift:260` `.font(.subheadline)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/EditorKitResults.swift:302` `.font(.subheadline.weight(category == value ? .semibold : .regular))` — dynamic expression (ternary / variable / computed size)
- `App/EditorKitResults.swift:325` `.font(.largeTitle)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/EditorKitResults.swift:327` `.font(.title3)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/EditorKitSheet.swift:78` `.font(.body.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/EditorKitSheet.swift:148` `.font(.subheadline.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/EndToEndReleaseCandidateGateSectionView.swift:142` `.font(.footnote.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/EndToEndReleaseCandidateGateSectionView.swift:159` `.font(.caption2.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/EnvironmentBranchAndRewardLedgerSectionView.swift:44` `.font(.caption.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/EnvironmentBranchAndRewardLedgerSectionView.swift:61` `.font(.caption.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/EnvironmentBranchAndRewardLedgerSectionView.swift:73` `.font(.caption.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/EnvironmentBranchAndRewardLedgerSectionView.swift:204` `.font(.caption.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/EnvironmentBranchAndRewardLedgerSectionView.swift:217` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/EnvironmentBranchAndRewardLedgerSectionView.swift:220` `.font(.subheadline.monospaced().weight(.semibold))` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/EnvironmentBranchAndRewardLedgerSectionView.swift:231` `.font(.caption.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/EnvironmentBranchAndRewardLedgerSectionView.swift:240` `.font(.caption.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/EnvironmentBranchAndRewardLedgerSectionView.swift:253` `.font(.caption.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/ExplorationPrivateToolsAndCapsuleSectionView.swift:140` `.font(.caption.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/ExplorationPrivateToolsAndCapsuleSectionView.swift:152` `.font(.caption.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/ExplorationPrivateToolsAndCapsuleSectionView.swift:174` `.font(.caption.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/ExploreCompletionView.swift:165` `.font(.headline)` — pinned by a contract test; update the test in the same commit
- `App/ExploreCompletionView.swift:169` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/ExploreCompletionView.swift:184` `.font(.headline)` — pinned by a contract test; update the test in the same commit
- `App/ExploreCompletionView.swift:185` `.font(.headline)` — pinned by a contract test; update the test in the same commit
- `App/ExploreCompletionView.swift:187` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/ExploreCompletionView.swift:193` `.font(.headline)` — pinned by a contract test; update the test in the same commit
- `App/ExploreCompletionView.swift:199` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/FinalReleaseSignoffAndZeroGapCertificateView.swift:247` `.font(.caption.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/FinalReleaseSignoffAndZeroGapCertificateView.swift:252` `.font(.caption2.monospaced().weight(.bold))` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/FinalReleaseSignoffAndZeroGapCertificateView.swift:277` `.font(.caption2.monospaced().weight(.semibold))` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/FinalReleaseSignoffAndZeroGapCertificateView.swift:285` `.font(.caption2.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/FinalThreeDocumentAndSevenDayGoalCompletionView.swift:132` `.font(.caption2.monospaced().weight(.bold))` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/FinalThreeDocumentAndSevenDayGoalCompletionView.swift:175` `.font(.caption2.monospaced().weight(.semibold))` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/FinalTwentyBatchMasterCompletionView.swift:160` `.font(.caption.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/FinalTwentyBatchMasterCompletionView.swift:170` `.font(.subheadline.monospaced().weight(.semibold))` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/FreeExplorationViews.swift:50` `.font(.largeTitle)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/FreeExplorationViews.swift:70` `.font(.title)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/FreeExplorationViews.swift:169` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/FreeExplorationViews.swift:180` `.font(.headline)` — pinned by a contract test; update the test in the same commit
- `App/FreeExplorationViews.swift:342` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/FreeExplorationViews.swift:347` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/FreeExplorationViews.swift:348` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/FreeExplorationViews.swift:350` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/FreeExplorationViews.swift:355` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/FreeExplorationViews.swift:357` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/FreeExplorationViews.swift:358` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/FreeExplorationViews.swift:368` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/GameJournalCompositionAndPlaySummarySectionView.swift:195` `.font(.title3)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/GlobalSearchView.swift:337` `.font(.caption2.weight(.bold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/GrowthAndLeaderboardParitySectionView.swift:220` `.font(.caption.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/GrowthAndLeaderboardParitySectionView.swift:234` `.font(.caption2.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/GrowthAndLeaderboardParitySectionView.swift:239` `.font(.caption2.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/GrowthAndLeaderboardParitySectionView.swift:255` `.font(.caption2.monospaced().weight(.bold))` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/GrowthAndLeaderboardParitySectionView.swift:293` `.font(.caption2.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/GrowthAndLeaderboardParitySectionView.swift:313` `.font(.caption.monospaced().weight(.bold))` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/GrowthAndLeaderboardParitySectionView.swift:341` `.font(.caption.monospaced().weight(.semibold))` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/GrowthCenterView.swift:37` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/GrowthCenterView.swift:115` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/GrowthCenterView.swift:143` `.font(.footnote.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/GrowthCenterView.swift:278` `.font(.title3)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/GrowthCenterView.swift:349` `.font(.headline)` — pinned by a contract test; update the test in the same commit
- `App/GrowthLeaderboardView.swift:145` `.font(.headline)` — pinned by a contract test; update the test in the same commit
- `App/GrowthLeaderboardView.swift:150` `.font(.headline)` — pinned by a contract test; update the test in the same commit
- `App/GrowthLeaderboardView.swift:155` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/GrowthLeaderboardView.swift:168` `.font(.headline)` — pinned by a contract test; update the test in the same commit
- `App/GrowthLeaderboardView.swift:169` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/GrowthLeaderboardView.swift:238` `.font(place == 1 ? .largeTitle.weight(.heavy) : .title.weight(.heavy))` — dynamic expression (ternary / variable / computed size)
- `App/HomeSearchTabParityViews.swift:65` `.font(.body.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/HomeSearchTabParityViews.swift:153` `.font(.caption2.weight(.bold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/HomeSearchTabParityViews.swift:238` `.font(.system(.title3, design: .rounded).weight(.heavy))` — rounded design on .title3 (number?)
- `App/HomeSearchTabParityViews.swift:370` `.font(.title2)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/HomeSearchTabParityViews.swift:381` `.font(.title2)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/HomeSearchTabParityViews.swift:450` `.font(.subheadline)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/HomeSearchTabParityViews.swift:452` `.font(.caption2.weight(isSelected ? .semibold : .regular))` — dynamic expression (ternary / variable / computed size)
- `App/HomeSearchTabParityViews.swift:1396` `.font(.title3)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/HomeSearchTabParityViews.swift:1450` `.font(.footnote.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/IMAndSocialSafetyParitySectionView.swift:130` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/IMExpandedViews.swift:457` `.font(.footnote.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/IMExpandedViews.swift:983` `.font(.title3.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/IMFlowPresentation.swift:9` `.font(Theme.Font.body)` — pinned by a contract test; update the test in the same commit
- `App/IMInboxViews.swift:129` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/IMInboxViews.swift:153` `.font(.caption)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/ImageAndVideoDiskCacheBudgetSectionView.swift:140` `.font(.caption2.monospaced().weight(.bold))` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/ImageAndVideoDiskCacheBudgetSectionView.swift:154` `.font(.caption.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/ImageAndVideoDiskCacheBudgetSectionView.swift:163` `.font(.caption.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/JourneyLandingViews.swift:592` `.font(.body.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/JourneyLandingViews.swift:726` `.font(.body)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/KeychainAndBiometricSessionSecuritySectionView.swift:150` `.font(.footnote.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/KeychainAndBiometricSessionSecuritySectionView.swift:155` `.font(.footnote.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/KeychainAndBiometricSessionSecuritySectionView.swift:177` `.font(.caption2.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/LBSGeofenceAndBatteryThermalSectionView.swift:118` `.font(.caption.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/LBSGeofenceAndBatteryThermalSectionView.swift:130` `.font(.caption.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/LBSGeofenceAndBatteryThermalSectionView.swift:148` `.font(.caption.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/LocalizationCompletenessSectionView.swift:111` `.font(.caption2.monospaced().weight(.bold))` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/LocalizationCompletenessSectionView.swift:124` `.font(.caption.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/LocalizationCompletenessSectionView.swift:148` `.font(.subheadline.monospaced().weight(.medium))` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/LocalizationCompletenessSectionView.swift:158` `.font(.caption2.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/LocalizationPluralAndFormatterConsistencySectionView.swift:175` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/LocalizationPluralAndFormatterConsistencySectionView.swift:178` `.font(.caption.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/LocalizationPluralAndFormatterConsistencySectionView.swift:182` `.font(.caption.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/LocationShareAndSideQuestSectionView.swift:117` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/LocationShareAndSideQuestSectionView.swift:225` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/LocationShareAndSideQuestSectionView.swift:318` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/LoginView.swift:74` `.font(.footnote.weight(.medium))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/LoginView.swift:93` `.font(.footnote.weight(.medium))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/LoginView.swift:187` `.font(.system(.subheadline, weight: .semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/MapCoreEntryHubView.swift:114` `.font(.footnote.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/MapCoreEntryHubView.swift:147` `.font(.body.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/MapCoreEntryHubView.swift:280` `.font(.caption.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/MapPublicLayerSectionView.swift:172` `.font(.headline)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/MapPublicLayerSectionView.swift:205` `.font(.caption)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/MapVisualLayerControlSectionView.swift:42` `.font(.caption.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/MapVisualLayerControlSectionView.swift:72` `.font(.caption.monospaced().weight(.semibold))` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/MapVisualLayerControlSectionView.swift:88` `.font(.caption.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/MapVisualLayerControlSectionView.swift:130` `.font(.caption2.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/MapVisualMV01ToMV41ComplianceSectionView.swift:245` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/MapVisualMV01ToMV41ComplianceSectionView.swift:248` `.font(.caption.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/MemberHomeHeader.swift:227` `.font(.title3)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/MemberIdentityAvatarView.swift:151` `.font(.title3)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/MemberScoreAppealListView.swift:169` `.font(.footnote.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/MemberScoreAppealListView.swift:237` `.font(.caption2.weight(.bold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/MemberSubscriptionAndOrderInvoiceSectionView.swift:159` `.font(.footnote.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/MemberSubscriptionAndOrderInvoiceSectionView.swift:180` `.font(.caption2.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/MerchantAcceptedProjectView.swift:104` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/MerchantAcceptedProjectView.swift:107` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/MerchantAftercareEvidenceFlow.swift:270` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantAftercareEvidenceFlow.swift:289` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantAftercareEvidenceFlow.swift:301` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantAftercareEvidenceFlow.swift:311` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantAndPublishAuthoringSectionView.swift:167` `.font(.caption.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/MerchantAndPublishAuthoringSectionView.swift:182` `.font(.caption2.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/MerchantAndPublishAuthoringSectionView.swift:192` `.font(.caption2.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/MerchantAuthoringLocalization.swift:24` `.font(Theme.Font.body)` — pinned by a contract test; update the test in the same commit
- `App/MerchantAuthoringLocalization.swift:48` `.font(Theme.Font.body)` — pinned by a contract test; update the test in the same commit
- `App/MerchantBusinessEditor.swift:403` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/MerchantBusinessRecordViews.swift:19` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/MerchantBusinessRecordViews.swift:59` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/MerchantBusinessRecordViews.swift:64` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/MerchantBusinessRecordViews.swift:72` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/MerchantBusinessRecordViews.swift:100` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantBusinessRecordViews.swift:103` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantBusinessRecordViews.swift:149` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/MerchantBusinessRecordViews.swift:151` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantBusinessRecordViews.swift:254` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantBusinessViews.swift:599` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantBusinessViews.swift:822` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantBusinessViews.swift:1059` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantCRMDateRangePicker.swift:84` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantCityNodeCreateView.swift:136` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/MerchantCityNodeCreateView.swift:145` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/MerchantCityNodeCreateView.swift:187` `.font(.caption.weight(states[index] == .doing ? .bold : .regular))` — dynamic expression (ternary / variable / computed size)
- `App/MerchantCityNodeCreateView.swift:205` `.font(.caption.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/MerchantCityNodeHubView.swift:168` `.font(.largeTitle)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/MerchantCityNodeHubView.swift:170` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/MerchantCityNodeHubView.swift:214` `.font(.largeTitle)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/MerchantCityNodeHubView.swift:216` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/MerchantCityNodeHubView.swift:229` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/MerchantCityNodeHubView.swift:409` `.font(.largeTitle)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/MerchantCityNodeHubView.swift:426` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/MerchantCityNodeHubView.swift:513` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/MerchantCityQuotaSummary.swift:29` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/MerchantContentEditor.swift:213` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantContentEditor.swift:238` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantContentEditor.swift:261` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantContentEditor.swift:264` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantContentEditor.swift:266` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantContentEditor.swift:270` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantContentEditor.swift:304` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantContentEditor.swift:330` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantContentEditor.swift:334` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantContentEditor.swift:385` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/MerchantContentEditor.swift:386` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/MerchantContentEditor.swift:390` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantContentViews.swift:86` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantContentViews.swift:138` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantContentViews.swift:156` `.font(.headline)` — pinned by a contract test; update the test in the same commit
- `App/MerchantContentViews.swift:166` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantContentViews.swift:186` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantContentViews.swift:212` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantContentViews.swift:249` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/MerchantContentViews.swift:334` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantContentViews.swift:354` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantContentViews.swift:377` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantContentViews.swift:400` `.font(.title2)` — pinned by a contract test; update the test in the same commit
- `App/MerchantContentViews.swift:412` `.font(.headline)` — pinned by a contract test; update the test in the same commit
- `App/MerchantContentViews.swift:427` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/MerchantContentViews.swift:452` `.font(.headline)` — pinned by a contract test; update the test in the same commit
- `App/MerchantContentViews.swift:475` `.font(.headline)` — pinned by a contract test; update the test in the same commit
- `App/MerchantContentViews.swift:547` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantContentViews.swift:560` `.font(.headline)` — pinned by a contract test; update the test in the same commit
- `App/MerchantCoopCenterView.swift:314` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/MerchantCustomerContactSummary.swift:29` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantCustomerEmptyRecoverySection.swift:13` `.font(.headline)` — pinned by a contract test; update the test in the same commit
- `App/MerchantCustomerEmptyRecoverySection.swift:16` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantCustomerEmptyRecoverySection.swift:23` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantDecorAndShopApplyWizardSectionView.swift:203` `.font(.caption.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/MerchantDecorAndShopApplyWizardSectionView.swift:215` `.font(.caption2.monospaced().weight(.semibold))` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/MerchantDecorAndShopApplyWizardSectionView.swift:229` `.font(.caption2.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/MerchantDecorAndShopApplyWizardSectionView.swift:232` `.font(.caption2.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/MerchantDecorAndShopApplyWizardSectionView.swift:238` `.font(.caption2.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/MerchantDecorAndShopApplyWizardSectionView.swift:260` `.font(.caption2.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/MerchantDecorAndShopApplyWizardSectionView.swift:268` `.font(.caption.monospaced().weight(.bold))` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/MerchantDecorAndShopApplyWizardSectionView.swift:278` `.font(.caption2.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/MerchantDecorAndShopApplyWizardSectionView.swift:310` `.font(.caption2.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/MerchantDecorAndShopApplyWizardSectionView.swift:322` `.font(.caption2.monospaced().weight(.semibold))` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/MerchantDecorAndShopApplyWizardSectionView.swift:326` `.font(.caption2.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/MerchantDecorTagEditor.swift:95` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantDeskSkuPage.swift:65` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantDiscoverView.swift:110` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/MerchantEngagementViews.swift:80` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantEngagementViews.swift:102` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantEngagementViews.swift:119` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantEngagementViews.swift:152` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantEngagementViews.swift:157` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantEngagementViews.swift:167` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantEngagementViews.swift:210` `.font(.headline)` — pinned by a contract test; update the test in the same commit
- `App/MerchantEngagementViews.swift:218` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantFeaturedActivityPicker.swift:107` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantFeaturedActivityPicker.swift:109` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantFeaturedClearControl.swift:30` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantGameNodeEntryView.swift:34` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/MerchantGameNodeView.swift:193` `.font(.largeTitle)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/MerchantGameNodeView.swift:195` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/MerchantGameNodeView.swift:275` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/MerchantGameNodeView.swift:359` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/MerchantGameNodeView.swift:381` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/MerchantGameNodeView.swift:411` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/MerchantGameNodeView.swift:529` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/MerchantGameNodeView.swift:536` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/MerchantGameNodeView.swift:562` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/MerchantGameNodeView.swift:660` `.font(.title3)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/MerchantGameNodeView.swift:663` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/MerchantHomeView.swift:752` `.font(.title3.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/MerchantInsightRecentVisitorsSection.swift:22` `.font(.headline)` — pinned by a contract test; update the test in the same commit
- `App/MerchantInsightRecentVisitorsSection.swift:23` `.font(.headline)` — pinned by a contract test; update the test in the same commit
- `App/MerchantInsightRecommendationRows.swift:12` `.font(.headline)` — pinned by a contract test; update the test in the same commit
- `App/MerchantInsightRecommendationRows.swift:14` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/MerchantInsightRecommendationRows.swift:15` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/MerchantLedgerNetSummary.swift:8` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/MerchantMarketingView.swift:123` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantMarketingView.swift:184` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantMarketingView.swift:189` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantMarketingView.swift:192` `.font(.headline)` — pinned by a contract test; update the test in the same commit
- `App/MerchantMarketingView.swift:199` `.font(.headline)` — pinned by a contract test; update the test in the same commit
- `App/MerchantMarketingView.swift:213` `.font(.headline)` — pinned by a contract test; update the test in the same commit
- `App/MerchantMarketingView.swift:252` `.font(.headline)` — pinned by a contract test; update the test in the same commit
- `App/MerchantMarketingView.swift:271` `.font(.headline)` — pinned by a contract test; update the test in the same commit
- `App/MerchantMarketingView.swift:281` `.font(.headline)` — pinned by a contract test; update the test in the same commit
- `App/MerchantMarketingView.swift:318` `.font(.headline)` — pinned by a contract test; update the test in the same commit
- `App/MerchantNPCConversationHistoryView.swift:8` `.font(.headline)` — pinned by a contract test; update the test in the same commit
- `App/MerchantNPCConversationHistoryView.swift:9` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantNPCConversationHistoryView.swift:11` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantNPCConversationHistoryView.swift:26` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/MerchantNPCGreetingPreview.swift:55` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantNPCGreetingPreview.swift:57` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantNPCGreetingPreview.swift:81` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantNPCGreetingPreview.swift:84` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/MerchantNPCGreetingPreview.swift:94` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantNPCKnowledgeDraftView.swift:37` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantNPCKnowledgeDraftView.swift:63` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantNPCKnowledgeDraftView.swift:64` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantNPCKnowledgeDraftView.swift:147` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantNPCKnowledgeDraftView.swift:171` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantNPCKnowledgeDraftView.swift:185` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantNPCKnowledgeDraftView.swift:198` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantNPCKnowledgeDraftView.swift:210` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantNPCKnowledgeDraftView.swift:222` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/MerchantNPCMapPointView.swift:64` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/MerchantNPCRecoveryPresentation.swift:117` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantNPCRecoveryPresentation.swift:120` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantNPCRecoveryPresentation.swift:122` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantNPCViews.swift:39` `.font(.headline)` — pinned by a contract test; update the test in the same commit
- `App/MerchantNPCViews.swift:40` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantNPCViews.swift:58` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/MerchantNPCViews.swift:90` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantNPCViews.swift:132` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/MerchantNPCViews.swift:134` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/MerchantNPCViews.swift:137` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantNPCViews.swift:204` `.font(.headline)` — pinned by a contract test; update the test in the same commit
- `App/MerchantOfferWithdrawalOriginalView.swift:60` `.font(Theme.Font.body)` — pinned by a contract test; update the test in the same commit
- `App/MerchantOnboardingHoursEditor.swift:50` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantOnboardingHoursEditor.swift:64` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantOnboardingView.swift:356` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/MerchantOnboardingView.swift:463` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantOnboardingView.swift:618` `.font(.title3)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/MerchantOperationsEditor.swift:132` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantOperationsEditor.swift:163` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantOperationsEditor.swift:167` `.font(.body)` — pinned by a contract test; update the test in the same commit
- `App/MerchantOperationsEditor.swift:171` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantOperationsEditor.swift:224` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantOperationsEditor.swift:252` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantOperationsEditor.swift:465` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantOperationsEditor.swift:500` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/MerchantOperationsEditor.swift:571` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantOperationsEditor.swift:621` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantOperationsEditor.swift:636` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantOperationsEditor.swift:641` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantOperationsEditor.swift:672` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/MerchantOperationsEditor.swift:677` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/MerchantOperationsEditor.swift:681` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantOperationsEditor.swift:699` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantOperationsEditor.swift:702` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/MerchantOperationsEditor.swift:718` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantOperationsEditor.swift:719` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantOperationsEditor.swift:729` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantOperationsEditor.swift:759` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantOperationsEditor.swift:761` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantOperationsEditor.swift:773` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantOperationsEditor.swift:787` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantOperationsEditor.swift:790` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/MerchantOperationsEditor.swift:812` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantOperationsEditor.swift:815` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/MerchantOperationsEditor.swift:844` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantOperationsEditor.swift:850` `.font(.headline)` — pinned by a contract test; update the test in the same commit
- `App/MerchantOperationsEditor.swift:860` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantOperationsEditor.swift:879` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantOperationsEditor.swift:883` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantOperationsEditor.swift:898` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/MerchantOperationsEditor.swift:899` `.font(.headline)` — pinned by a contract test; update the test in the same commit
- `App/MerchantOperationsEditor.swift:906` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantOperationsEditor.swift:927` `.font(.headline)` — pinned by a contract test; update the test in the same commit
- `App/MerchantOperationsEditor.swift:930` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/MerchantOperationsViews.swift:366` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantOperatorInvitationReceiptView.swift:87` `.font(.headline)` — pinned by a contract test; update the test in the same commit
- `App/MerchantOperatorInvitationReceiptView.swift:94` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantOperatorInvitationReceiptView.swift:95` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantOperatorInvitationReceiptView.swift:97` `.font(.system(.body, design: .monospaced))` — monospaced design (code / ticket number)
- `App/MerchantOperatorInvitationReceiptView.swift:108` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantOperatorInvitationReceiptView.swift:110` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantOperatorInvitationReceiptView.swift:113` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantOperatorRolePermissionSection.swift:17` `.font(.subheadline.bold())` — pinned by a contract test; update the test in the same commit
- `App/MerchantOperatorRolePermissionSection.swift:18` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantOperatorRolePermissionSection.swift:35` `.font(.caption.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/MerchantPerkValidityCalendar.swift:63` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantPerkValidityCalendar.swift:112` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantPerkValidityCalendar.swift:114` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantPerkValidityCalendar.swift:125` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantProjectBrowserControls.swift:30` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/MerchantReviewPhotoGallery.swift:243` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantStationLiveCodeView.swift:136` `.font(.headline)` — pinned by a contract test; update the test in the same commit
- `App/MerchantStationLiveCodeView.swift:141` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantStationLiveCodeView.swift:145` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantStationServiceTimeFields.swift:62` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantStationServiceTimeFields.swift:64` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantStationServiceTimeFields.swift:79` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantStationSubmissionImportView.swift:176` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantStationSubmissionImportView.swift:177` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantStationSubmissionImportView.swift:181` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantStationSubmissionImportView.swift:182` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantStoreCharacterView.swift:353` `.font(.footnote)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/MerchantStoreCharacterView.swift:372` `.font(.largeTitle)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/MerchantStoreCharacterView.swift:410` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/MerchantStoreCharacterView.swift:669` `.font(.caption.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/MerchantStoreCharacterView.swift:677` `.font(.caption.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/MerchantTemplateAssistSheet.swift:32` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantTemplateAssistSheet.swift:52` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantTemplateAssistSheet.swift:69` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantTemplateAssistSheet.swift:72` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/MerchantTemplateAssistSheet.swift:79` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantTemplateBrowserView.swift:226` `.font(Theme.Font.body)` — pinned by a contract test; update the test in the same commit
- `App/MerchantTemplateSuggestionEditSheet.swift:42` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantTemplateSuggestionReviewPanel.swift:14` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/MerchantTemplateSuggestionReviewPanel.swift:18` `.font(.headline)` — pinned by a contract test; update the test in the same commit
- `App/MerchantTemplateSuggestionReviewPanel.swift:19` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/MerchantTemplateSuggestionReviewPanel.swift:22` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/MerchantTemplateSuggestionReviewPanel.swift:25` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/MerchantTemplateSuggestionReviewPanel.swift:50` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/MerchantTopicDetailSection+Wire2.swift:111` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/MerchantTopicIntroSection+Port.swift:24` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/MerchantTopicIntroSection+Port.swift:33` `.font(.subheadline)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/MessagingHistoryView.swift:442` `.font(.body)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/MiniProgram99PageParitySectionView.swift:211` `.font(.caption2.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/MiniProgram99PageParitySectionView.swift:214` `.font(.caption2.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/MiniProgram99PageParitySectionView.swift:238` `.font(.caption2.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/MiniProgram99PageParitySectionView.swift:245` `.font(.caption2.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/MiniProgram99PageParitySectionView.swift:248` `.font(.caption2.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/ModCreatorIncomeViews.swift:125` `.font(.footnote.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/ModInstallationNativeActionReceiptView.swift:96` `.font(.body.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/ModInstallationTemplateEditorView.swift:177` `.font(.caption.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/ModInstallationTopicEditor.swift:54` `.font(.caption.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/ModInstallationTopicEditor.swift:72` `.font(.caption.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/ModInstallationTopicEditor.swift:77` `.font(.caption.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/NPCAISceneGuardSectionView.swift:159` `.font(.caption.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/NativeAuthorPresentation.swift:31` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/NativeAuthorPresentation.swift:46` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/NativeAuthorPresentation.swift:68` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/NativeBlacklistView.swift:108` `.font(.footnote.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/NativeBlacklistView.swift:139` `.font(.footnote.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/NativeBlacklistView.swift:221` `.font(.footnote.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/NativeChannelAppealEntry.swift:163` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/NativeChannelAppealEntry.swift:186` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/NativeChannelAttachmentPreviewEntry.swift:73` `.font(Theme.Font.body)` — pinned by a contract test; update the test in the same commit
- `App/NativeChannelAuditEntry.swift:121` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/NativeChannelAuditEntry.swift:146` `.font(.caption.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/NativeChannelFlowPresentation.swift:8` `.font(Theme.Font.body)` — pinned by a contract test; update the test in the same commit
- `App/NativeChannelFlowPresentation.swift:32` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/NativeChannelForegroundUnreadEntry.swift:19` `.font(Theme.Font.body)` — pinned by a contract test; update the test in the same commit
- `App/NativeChannelForegroundUnreadEntry.swift:64` `.font(Theme.Font.body)` — pinned by a contract test; update the test in the same commit
- `App/NativeChannelManagementPresentation.swift:9` `.font(.callout.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/NativeChannelManagementPresentation.swift:23` `.font(Theme.Font.body)` — pinned by a contract test; update the test in the same commit
- `App/NativeChannelMessageActionSheet.swift:60` `.font(Theme.Font.body)` — pinned by a contract test; update the test in the same commit
- `App/NativeChannelMessageActionSheet.swift:197` `.font(.footnote)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/NativeChannelMessageConversationHost.swift:358` `.font(Theme.Font.body)` — pinned by a contract test; update the test in the same commit
- `App/NativeChannelModerationEntry.swift:96` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/NativeChannelModerationEntry.swift:98` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/NativeChannelReportRecoveryEntry.swift:25` `.font(Theme.Font.body)` — pinned by a contract test; update the test in the same commit
- `App/NativeChannelReportRecoveryEntry.swift:167` `.font(Theme.Font.body)` — pinned by a contract test; update the test in the same commit
- `App/NativeChannelRoleEntry.swift:68` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/NativeChannelRoleEntry.swift:105` `.font(.callout.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/NativeChannelRoleEntry.swift:147` `.font(.callout.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/NativeChannelTextComposer.swift:71` `.font(.title2)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/NativeChannelTextComposer.swift:85` `.font(Theme.Font.body)` — pinned by a contract test; update the test in the same commit
- `App/NativeChannelTextComposer.swift:109` `.font(Theme.Font.body)` — pinned by a contract test; update the test in the same commit
- `App/NativeChannelTextComposer.swift:138` `.font(.footnote)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/NativeConditionAuthorView.swift:289` `.font(.system(.footnote, design: .monospaced))` — monospaced design (code / ticket number)
- `App/NativeConditionAuthorView.swift:373` `.font(.system(.footnote, design: .monospaced))` — monospaced design (code / ticket number)
- `App/NativeEntryLandingView.swift:126` `.font(.largeTitle)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/NativeFriendChannelInviteEntry.swift:22` `.font(Theme.Font.body)` — pinned by a contract test; update the test in the same commit
- `App/NativeFriendChannelInviteEntry.swift:51` `.font(Theme.Font.body)` — pinned by a contract test; update the test in the same commit
- `App/NativeFriendChannelInviteEntry.swift:204` `.font(Theme.Font.body)` — pinned by a contract test; update the test in the same commit
- `App/NativeFriendChannelSourceEntry.swift:24` `.font(Theme.Font.body)` — pinned by a contract test; update the test in the same commit
- `App/NativeFriendChannelSourceEntry.swift:79` `.font(.title2)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/NativeFriendChannelSourceEntry.swift:117` `.font(Theme.Font.body)` — pinned by a contract test; update the test in the same commit
- `App/NativeFriendChannelSourceEntry.swift:141` `.font(Theme.Font.body)` — pinned by a contract test; update the test in the same commit
- `App/NativeFriendMetadataView.swift:149` `.font(.body.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/NativeFriendPickerView.swift:59` `.font(.body.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/NativeFriendTeamInviteEntry.swift:105` `.font(Theme.Font.body)` — pinned by a contract test; update the test in the same commit
- `App/NativeRpgConditionAuthorView.swift:78` `.font(.caption.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/NativeRpgEnvironmentAuthorView.swift:81` `.font(.caption.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/NativeRpgGrowthAuthorView.swift:62` `.font(.caption.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/NativeRpgPassiveRulesAuthorView.swift:87` `.font(.caption.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/NativeRpgResourceAuthorView.swift:68` `.font(.caption.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/NativeSharedRecoveryAuthorView.swift:101` `.font(.caption.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/NativeSupersetOverMiniProgramSectionView.swift:201` `.font(.caption.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/NativeWebhookDeliveryLogView.swift:36` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/NativeWebhookDeliveryLogView.swift:39` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/NativeWebhookDeliveryLogView.swift:49` `.font(.caption.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/NativeWebhookEndpointEditor.swift:27` `.font(.body.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/NativeWebhookInboundLogView.swift:34` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/NativeWebhookOneTimeCredentialView.swift:21` `.font(.body.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/NativeWebhookOneTimeCredentialView.swift:29` `.font(.body.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/NearbyTeamMapViews.swift:19` `.font(.caption2)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/NearbyTeamMapViews.swift:207` `.font(.title2)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/NearbyTeamViews.swift:478` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/NetworkReachabilityAndRetryBackoffSectionView.swift:136` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/NonCashRewardDetailReadSupport.swift:128` `.font(Theme.Font.body)` — pinned by a contract test; update the test in the same commit
- `App/ObjectBadgeViews.swift:293` `.font(.title2)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/ObjectBadgeWallParityViews.swift:41` `.font(Theme.Font.body)` — pinned by a contract test; update the test in the same commit
- `App/ObjectBadgeWallParityViews.swift:50` `.font(Theme.Font.body)` — pinned by a contract test; update the test in the same commit
- `App/ObjectCardViews.swift:256` `.font(.largeTitle)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/OfficialActionViews.swift:61` `.font(.body.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/OfficialActionViews.swift:226` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/OfficialEventComponents.swift:49` `.font(copy == nil ? .headline : .footnote)` — dynamic expression (ternary / variable / computed size)
- `App/OfficialEventComponents.swift:221` `.font(.footnote)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/OfficialEventComponents.swift:288` `.font(.footnote.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/OfficialEventDetailView.swift:136` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/OfficialEventDetailView.swift:358` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/OfficialOrganizerConsoleView.swift:284` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/OfflineDurableRecoverySectionView.swift:157` `.font(.caption.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/OfflineDurableRecoverySectionView.swift:172` `.font(.caption2.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/OfflineDurableRecoverySectionView.swift:182` `.font(.caption2.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/OpsSafetyViews.swift:18` `.font(.footnote)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/OrderLifecycleView.swift:211` `.font(.title3)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/OwnedTemplateSensorConfigurationView.swift:25` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/OwnerDraftBrowserView.swift:65` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/OwnerDraftBrowserView.swift:99` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/PassportView.swift:180` `.font(.title3)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/PassportView.swift:292` `.font(.footnote.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/PaymentProviderReturnSheet.swift:19` `.font(.largeTitle)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/PaymentProviderReturnSheet.swift:22` `.font(.largeTitle)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/PersonalLocationShareView.swift:86` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/PersonalLocationShareView.swift:87` `.font(.caption.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/PlayAdvancedView.swift:180` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/PlayAdvancedView.swift:184` `.font(.footnote.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/PlayBranchHistoryView.swift:68` `.font(.headline)` — pinned by a contract test; update the test in the same commit
- `App/PlayBranchHistoryView.swift:72` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/PlayBranchHistoryView.swift:80` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/PlayComponents.swift:10` `.font(Theme.Font.body)` — pinned by a contract test; update the test in the same commit
- `App/PlayExperienceView.swift:511` `.font(.headline)` — pinned by a contract test; update the test in the same commit
- `App/PlayExperienceView.swift:637` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/PlayExperienceView.swift:1308` `.font(.headline)` — pinned by a contract test; update the test in the same commit
- `App/PlayFinishRouteCardView.swift:45` `.font(.footnote.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/PlayJourneyContentViews.swift:14` `.font(.title3)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/PlayKitAlbumView.swift:55` `.font(.largeTitle)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/PlayKitLegacyViews.swift:60` `.font(.caption2)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/PlayKitQuestoViews.swift:154` `.font(.system(.title, design: .serif).weight(.bold))` — design .serif
- `App/PlayKitQuestoViews.swift:333` `.font(.body.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/PlayKitScreen.swift:338` `.font(.largeTitle)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/PlayKitTimedChallengeView.swift:100` `.font(.title2.monospaced().bold())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/PlayPrefabRuntimeView.swift:99` `.font(.title3.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/PlayRouteMapCameraControls.swift:37` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/PlayRouteMapView.swift:103` `.font(.body)` — pinned by a contract test; update the test in the same commit
- `App/PlayRouteMapView.swift:107` `.font(.body)` — pinned by a contract test; update the test in the same commit
- `App/PlayRouteMapView.swift:392` `.font(.title2)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/PlayRuntimeAndAuxiliaryBindingSectionView.swift:144` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/PlayRuntimeGapViews.swift:35` `.font(.title3)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/PlaySessionView.swift:118` `.font(.title3)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/PlaySessionView.swift:126` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/PlaySessionView.swift:137` `.font(.caption)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/PlaySharedPlanLifecycleView.swift:32` `.font(.caption.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/PlaySharedPlanLifecycleView.swift:40` `.font(.caption.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/PlaySharedPlanLifecycleView.swift:62` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/PlaySharedPlanLifecycleView.swift:155` `.font(.footnote.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/PlaySharedPlanLifecycleView.swift:240` `.font(Theme.Font.body)` — pinned by a contract test; update the test in the same commit
- `App/PlayStoreDayMerchantView.swift:162` `.font(.largeTitle)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/PlayStoreDayMerchantView.swift:213` `.font(.title3)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/PlayTaskOutcomeSection.swift:70` `.font(Theme.Font.body)` — pinned by a contract test; update the test in the same commit
- `App/PlayTeamBackpackView.swift:168` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/PlayThemeRecordsView.swift:10` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/PlayerJourneyViews.swift:190` `.font(.subheadline)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/PlayerJourneyViews.swift:196` `.font(.subheadline)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/PlayerJourneyViews.swift:208` `.font(.title2)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/PrivacyAndSecurityRedactionSectionView.swift:136` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/ProductionSigningAndLocalXcconfigSectionView.swift:141` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/ProductionTelemetryAndPrivacyRedactionSectionView.swift:142` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/ProfileAvatarDraftSection.swift:146` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/ProfileAvatarDraftSection.swift:199` `.font(.headline)` — pinned by a contract test; update the test in the same commit
- `App/ProfileAvatarDraftSection.swift:200` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/ProfileComplaintPreparationView.swift:72` `.font(.system(.largeTitle, design: .rounded, weight: .bold))` — pinned by a contract test; update the test in the same commit
- `App/ProfileComplaintPreparationView.swift:97` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/ProfileComplaintPreparationView.swift:100` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/ProfileContactQREditor.swift:15` `.font(.caption)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/ProfileCurrentAvatarView.swift:34` `.font(.title2)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/ProfileCurrentAvatarView.swift:63` `.font(.system(.largeTitle))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/ProfileDraftReviewSection.swift:17` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/ProfileDraftReviewSection.swift:23` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/ProfileEditView.swift:732` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/ProfileEditView.swift:736` `.font(.caption)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/ProfileOrdersView.swift:516` `.font(.headline)` — pinned by a contract test; update the test in the same commit
- `App/ProfileOrdersView.swift:519` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/ProjectAlbumImageAuthorField.swift:25` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/ProjectAlbumPhotoRemovalButton.swift:83` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/ProjectChapterAudioField.swift:80` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/ProjectChapterAudioField.swift:94` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/ProjectDraftNodeOverview.swift:86` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/ProjectDraftNodeOverview.swift:115` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/ProjectDraftNodeOverview.swift:126` `.font(.headline)` — pinned by a contract test; update the test in the same commit
- `App/ProjectDraftNodeOverview.swift:127` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/ProjectDraftNodeOverview.swift:131` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/ProjectDraftStoryPreviewView.swift:62` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/ProjectDraftStoryPreviewView.swift:97` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/ProjectDraftStoryPreviewView.swift:98` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/ProjectDraftStoryPreviewView.swift:99` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/ProjectDraftStoryPreviewView.swift:144` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/ProjectDraftStoryPreviewView.swift:147` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/ProjectDraftStoryPreviewView.swift:154` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/ProjectDraftStoryPreviewView.swift:155` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/ProjectDraftStoryPreviewView.swift:156` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/ProjectDraftStoryPreviewView.swift:157` `.font(.headline)` — pinned by a contract test; update the test in the same commit
- `App/ProjectDraftStoryPreviewView.swift:160` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/ProjectDraftStoryPreviewView.swift:162` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/ProjectDraftStoryPreviewView.swift:168` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/ProjectDraftStoryPreviewView.swift:174` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/ProjectEditDatePicker.swift:96` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/ProjectEditDatePicker.swift:102` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/ProjectEditDatePicker.swift:105` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/ProjectEditDatePicker.swift:140` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/ProjectEditDatePicker.swift:146` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/ProjectEditDetailForms.swift:143` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/ProjectEditDetailForms.swift:155` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/ProjectEditDetailForms.swift:193` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/ProjectEditDetailForms.swift:200` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/ProjectEditDetailForms.swift:204` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/ProjectEditDetailForms.swift:257` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/ProjectEditDetailForms.swift:492` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/ProjectEditDetailForms.swift:500` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/ProjectEditDetailForms.swift:539` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/ProjectEditDetailForms.swift:566` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/ProjectEditFlowParity.swift:26` `.font(.footnote)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/ProjectEditPendingPresentation.swift:17` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/ProjectEditPendingPresentation.swift:18` `.font(.headline)` — pinned by a contract test; update the test in the same commit
- `App/ProjectEditPendingPresentation.swift:21` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/ProjectEditRichStoryForms.swift:135` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/ProjectEditRichStoryForms.swift:173` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/ProjectEditRichStoryForms.swift:232` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/ProjectEditRichStoryForms.swift:234` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/ProjectEditRichStoryForms.swift:236` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/ProjectEditRichStoryForms.swift:244` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/ProjectEditRichStoryForms.swift:252` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/ProjectEditView.swift:543` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/ProjectEditView.swift:1152` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/ProjectEditView.swift:1200` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/ProjectEditorAudioPreview.swift:95` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/ProjectEndingConditionPicker.swift:110` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/ProjectEndingConditionPicker.swift:117` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/ProjectInitialAttributesEditor.swift:126` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/ProjectInitialAttributesEditor.swift:130` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/ProjectInitialAttributesEditor.swift:136` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/ProjectInitialAttributesEditor.swift:148` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/ProjectInitialAttributesEditor.swift:156` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/ProjectInitialStateEditor.swift:100` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/ProjectNodeBusinessHoursField.swift:98` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/ProjectNodeBusinessHoursField.swift:113` `.font(.headline)` — pinned by a contract test; update the test in the same commit
- `App/ProjectNodeBusinessHoursField.swift:148` `.font(.headline)` — pinned by a contract test; update the test in the same commit
- `App/ProjectNodeDurationField.swift:84` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/ProjectNodeDurationField.swift:86` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/ProjectNodeGameplayRemovalField.swift:53` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/ProjectNodeImageCrop.swift:56` `.font(.headline)` — pinned by a contract test; update the test in the same commit
- `App/ProjectNodePhotoRemovalField.swift:72` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/ProjectNodePhotoRemovalField.swift:78` `.font(.headline)` — pinned by a contract test; update the test in the same commit
- `App/ProjectNodePhotoRemovalField.swift:79` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/ProjectNodePlacePicker.swift:204` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/ProjectNodeRouteMappingEditor.swift:82` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/ProjectNodeRouteMappingEditor.swift:99` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/ProjectNodeTemplateCreationField.swift:100` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/ProjectNodeTemplateSelectionField.swift:16` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/ProjectStoryVariablePicker.swift:80` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/ProjectStoryVariablePicker.swift:82` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/ProjectStoryVariablePicker.swift:111` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/ProjectSubmissionEvidenceViews.swift:12` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/ProjectSubmissionEvidenceViews.swift:23` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/ProjectSubmissionEvidenceViews.swift:27` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/ProjectSubmissionEvidenceViews.swift:30` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/ProjectTeamConfigurationEditor.swift:71` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/ProjectTeamConfigurationEditor.swift:96` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/ProjectTeamConfigurationEditor.swift:105` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/ProjectTeamConfigurationEditor.swift:106` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/ProjectThoughtDefinitionsEditor.swift:136` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/ProjectThoughtDefinitionsEditor.swift:150` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/ProjectThoughtDefinitionsEditor.swift:154` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/ProjectThoughtDefinitionsEditor.swift:234` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/ProjectTicketMeetingPointFields.swift:178` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/PublicPlayTemplateFixtureHost.swift:68` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/PublishMediaEditorSectionView.swift:24` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/PublishMediaEditorSectionView.swift:41` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/PublishMediaEditorSectionView.swift:45` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/PublishTopicAndCommentModerationSectionView.swift:163` `.font(.caption.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/PublishTopicAndCommentModerationSectionView.swift:185` `.font(.caption2.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/PublishTopicAndCommentModerationSectionView.swift:188` `.font(.caption2.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/PublishTopicAndCommentModerationSectionView.swift:195` `.font(.caption2.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/PublishTopicAndCommentModerationSectionView.swift:198` `.font(.caption2.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/PublishTopicAndCommentModerationSectionView.swift:215` `.font(.caption2.monospaced().weight(.bold))` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/PublishTopicAndCommentModerationSectionView.swift:244` `.font(.caption2.monospaced().weight(.bold))` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/PublisherLifecycleHostHooks.swift:71` `.font(Theme.Font.body)` — pinned by a contract test; update the test in the same commit
- `App/PublishingContextHandoffViews.swift:63` `.font(on ? .title2.weight(.semibold) : .title3.weight(.semibold))` — dynamic expression (ternary / variable / computed size)
- `App/PublishingContextHandoffViews.swift:127` `.font(Theme.Font.body)` — pinned by a contract test; update the test in the same commit
- `App/PublishingContextHandoffViews.swift:144` `.font(isError ? .body : .footnote)` — dynamic expression (ternary / variable / computed size)
- `App/PublishingContextHandoffViews.swift:184` `.font(Theme.Font.body)` — pinned by a contract test; update the test in the same commit
- `App/PublishingContextHandoffViews.swift:233` `.font(Theme.Font.body)` — pinned by a contract test; update the test in the same commit
- `App/PublishingContextHandoffViews.swift:252` `.font(Theme.Font.body)` — pinned by a contract test; update the test in the same commit
- `App/PublishingContextHandoffViews.swift:259` `.font(Theme.Font.body)` — pinned by a contract test; update the test in the same commit
- `App/PublishingManagementViews.swift:144` `.font(.caption.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/PublishingManagementViews.swift:163` `.font(.footnote.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/PushNotificationAndLiveActivitySectionView.swift:254` `.font(.caption.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/QmodAuthorImportView.swift:290` `.font(.caption.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/QmodAuthorImportView.swift:301` `.font(.subheadline.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/QuestifyDensityMap.swift:158` `.font(.headline)` — pinned by a contract test; update the test in the same commit
- `App/QuestifyDensityMap.swift:206` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/QuestifyDensityMap.swift:305` `.font(.headline)` — pinned by a contract test; update the test in the same commit
- `App/QuestifyDensityMap.swift:306` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/QuestifyImageEntityCard.swift:45` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/QuestifyImageEntityCard.swift:49` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/QuestifyImageEntityCard.swift:93` `.font(.largeTitle.weight(.light))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/QuestifyImageEntityCard.swift:151` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/QuestifyImageEntityCard.swift:156` `.font(.headline)` — pinned by a contract test; update the test in the same commit
- `App/QuestifyMotionComponents.swift:44` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/QuestifyMotionComponents.swift:62` `.font(.caption.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/QuestifyMotionComponents.swift:92` `.font(.title2)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/QuestifyMotionComponents.swift:176` `.font(.body.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/QuestifyMotionComponents.swift:213` `.font(Theme.Font.body)` — pinned by a contract test; update the test in the same commit
- `App/ReceivedStampsAndPassportToolsSectionView.swift:130` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/ReformWorkPackagesW02ToW20SectionView.swift:169` `.font(.caption.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/ReformWorldHostWorkbenchView.swift:155` `.font(.footnote.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/ReformWorldHostWorkbenchView.swift:162` `.font(.caption2.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/ReformWorldHostWorkbenchView.swift:165` `.font(.caption2.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/RegionalEndpointAllowlistSectionView.swift:247` `.font(.subheadline.monospaced().weight(.medium))` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/ReleaseArchiveChecklistSectionView.swift:208` `.font(.subheadline.monospaced().weight(.medium))` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/ReleaseArchiveChecklistSectionView.swift:218` `.font(.caption.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/ReleasePreflightDiagnosticsView.swift:164` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/ReleasePreflightDiagnosticsView.swift:178` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/ReleasePreflightDiagnosticsView.swift:198` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/ReleasePreflightDiagnosticsView.swift:206` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/ReleasePreflightDiagnosticsView.swift:209` `.font(.caption.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/ReleasePreflightDiagnosticsView.swift:238` `.font(.caption.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/ReleasePreflightDiagnosticsView.swift:241` `.font(.caption2.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/ReleasePreflightDiagnosticsView.swift:265` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/ReleasePreflightDiagnosticsView.swift:268` `.font(.caption.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/RoamBrowserView.swift:363` `.font(.footnote.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/RoamBrowserView.swift:550` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/RoamBrowserView.swift:652` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/RoamBrowserView.swift:654` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/RoamBrowserView.swift:658` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/RoamBrowserView.swift:661` `.font(.caption)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/RoamExperienceComponents.swift:280` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/RoamExperienceComponents.swift:388` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/RoamExperienceHubView.swift:45` `.font(.largeTitle)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/RoamExperienceHubView.swift:108` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/RoamExperienceHubView.swift:113` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/RoamExperienceHubView.swift:241` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/RoamExplorationExportView.swift:326` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/RoamFinishReportView.swift:99` `.font(.title3.weight(.medium))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/RoamFinishReportView.swift:127` `.font(.system(.largeTitle, design: .default).weight(.black).italic())` — unsupported modifier italic()
- `App/RoamHistoryViews.swift:44` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/RoamHistoryViews.swift:86` `.font(.subheadline.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/RoamHistoryViews.swift:315` `.font(.title3.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/RoamHistoryViews.swift:338` `.font(.title3)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/RoamHomeTabsView.swift:55` `.font(.title3.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/RoamHomeTabsView.swift:57` `.font(.system(.caption2, design: .monospaced).weight(.semibold))` — monospaced design (code / ticket number)
- `App/RoamHomeTabsView.swift:140` `.font(.caption)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/RoamHomeTabsView.swift:160` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/RoamHomeTabsView.swift:179` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/RoamHomeTabsView.swift:285` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/RoamItemDetailView.swift:177` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/RoamItemDetailView.swift:274` `.font(.headline)` — pinned by a contract test; update the test in the same commit
- `App/RoamItemDetailView.swift:275` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/RoamLiveSessionView.swift:122` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/RoamLiveSessionView.swift:607` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/RoamLiveSessionView.swift:900` `.font(.body.italic())` — unsupported modifier italic()
- `App/RoamLocationSettingsDestination.swift:106` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/RoamMonthlyRecapDetailView.swift:39` `.font(Theme.Font.body)` — pinned by a contract test; update the test in the same commit
- `App/RoamPOIActions.swift:152` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/RoamPOIActions.swift:155` `.font(.subheadline)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/RoamPOIActions.swift:158` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/RoamPOIActions.swift:160` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/RoamPassportToolsViews.swift:242` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/RoamPassportToolsViews.swift:500` `.font(Theme.Font.body)` — pinned by a contract test; update the test in the same commit
- `App/RoamPassportToolsViews.swift:859` `.font(.body.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/RoamPreflightRulesView.swift:33` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/RoamRecoveryView.swift:17` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/RoamStampCameraView.swift:123` `.font(.title2)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/RoamStampViews.swift:226` `.font(.title2.weight(.medium))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/RoamStampViews.swift:441` `.font(.caption.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/RoamStampViews.swift:448` `.font(.largeTitle)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/RoamStampViews.swift:501` `.font(.largeTitle)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/RoamStampViews.swift:520` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/RoamSubpageParityViews.swift:23` `.font(.system(.title3, design: .rounded).weight(.heavy).italic())` — unsupported modifier italic()
- `App/RoamSubpageParityViews.swift:100` `.font(.caption)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/RoamSubpageParityViews.swift:109` `.font(.system(.headline, design: .rounded).weight(.bold).monospacedDigit())` — rounded design on .headline (number?)
- `App/RoamSubpageParityViews.swift:135` `.font(.title3)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/RoamSubpageParityViews.swift:135` `.font(.caption.weight(.medium))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/RoamSubpageParityViews.swift:189` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/RoamSubpageParityViews.swift:406` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/RunAuthorityHostSectionView.swift:90` `.font(.caption.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/RunAuthorityHostSectionView.swift:101` `.font(.footnote.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/RunAuthorityHostSectionView.swift:106` `.font(.caption2.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/SQLiteAndJSONJournalCorruptionRecoverySectionView.swift:172` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/SQLiteAndJSONJournalCorruptionRecoverySectionView.swift:209` `.font(.caption2.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/ScheduleAndLeadProgressPollingSectionView.swift:164` `.font(.caption.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/ScheduleAndLeadProgressPollingSectionView.swift:179` `.font(.caption2.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/ScheduleAndLeadProgressPollingSectionView.swift:189` `.font(.caption2.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/SearchMapCanvas.swift:102` `.font(.body.bold())` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/SearchMapCanvas.swift:113` `.font(.body.bold())` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/SearchMapComponents.swift:73` `.font(.footnote.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/SearchMapExplorerView.swift:80` `.font(.headline)` — pinned by a contract test; update the test in the same commit
- `App/SearchMapExplorerView.swift:267` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/SearchMapExplorerView.swift:283` `.font(.headline)` — pinned by a contract test; update the test in the same commit
- `App/SearchMapExplorerView.swift:291` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/SearchMapExplorerView.swift:376` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/SearchMapExplorerView.swift:379` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/SearchMapExplorerView.swift:407` `.font(.headline)` — pinned by a contract test; update the test in the same commit
- `App/SearchMapExplorerView.swift:423` `.font(.headline)` — pinned by a contract test; update the test in the same commit
- `App/SearchMapExplorerView.swift:426` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/SearchMapExplorerView.swift:437` `.font(.headline)` — pinned by a contract test; update the test in the same commit
- `App/SearchMapExplorerView.swift:452` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/SearchMapExplorerView.swift:464` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/SearchMapExplorerView.swift:469` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/SearchMapExplorerView.swift:479` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/SearchMapExplorerView.swift:497` `.font(.headline)` — pinned by a contract test; update the test in the same commit
- `App/SearchMapExplorerView.swift:499` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/SearchMapExplorerView.swift:507` `.font(.headline)` — pinned by a contract test; update the test in the same commit
- `App/SearchMapExplorerView.swift:508` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/SearchMapExplorerView.swift:509` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/SearchMapFilterSheet.swift:61` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/SearchMapFilterSheet.swift:68` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/SearchMapFilterSheet.swift:78` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/SearchMapFilterSheet.swift:81` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/SearchMapFilterSheet.swift:176` `.font(.headline)` — pinned by a contract test; update the test in the same commit
- `App/SearchMapFilterSheet.swift:213` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/SessionLocationHoldsSection.swift:21` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/SettingsAboutView.swift:132` `.font(.largeTitle)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/SettingsSupportSections.swift:167` `.font(.subheadline.weight(.semibold))` — pinned by a contract test; update the test in the same commit
- `App/SettingsView.swift:233` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/SettingsView.swift:237` `.font(.footnote.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/SevenDayLaunchCriticalPathSectionView.swift:231` `.font(.caption.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/SevenDayLaunchCriticalPathSectionView.swift:242` `.font(.caption2.monospaced().weight(.bold))` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/SevenDayLaunchCriticalPathSectionView.swift:269` `.font(.caption2.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/SevenDayLaunchCriticalPathSectionView.swift:273` `.font(.caption2.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/SevenDayLaunchCriticalPathSectionView.swift:277` `.font(.caption2.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/SevenDayLaunchCriticalPathSectionView.swift:298` `.font(.caption.monospaced().weight(.bold))` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/ShopNPCScriptedGuideView.swift:18` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/ShopNPCScriptedGuideView.swift:23` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/ShopNPCScriptedGuideView.swift:27` `.font(.headline)` — pinned by a contract test; update the test in the same commit
- `App/ShopNPCScriptedGuideView.swift:30` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/ShopNPCView.swift:87` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/ShopNPCView.swift:117` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/ShopNPCView.swift:237` `.font(.headline)` — pinned by a contract test; update the test in the same commit
- `App/ShopNPCView.swift:243` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/ShopNPCView.swift:245` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/ShopNPCView.swift:253` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/ShopNPCView.swift:257` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/SideQuestAndPersonalFogAuditSectionView.swift:181` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/SideQuestAndPersonalFogAuditSectionView.swift:184` `.font(.caption.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/SocialGraphAndProfilePrivacySectionView.swift:175` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/SocialGraphAndProfilePrivacySectionView.swift:212` `.font(.caption2.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/SocialGraphAndProfilePrivacySectionView.swift:228` `.font(.caption2.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/SocialGuideTemplateSection.swift:144` `.font(.headline)` — pinned by a contract test; update the test in the same commit
- `App/SocialGuideTemplateSection.swift:146` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/SocialGuideTemplateSection.swift:150` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/SocialGuideViews.swift:100` `.font(large ? .largeTitle.weight(.thin) : .title3.weight(.light))` — dynamic expression (ternary / variable / computed size)
- `App/SocialGuideXcxParity.swift:29` `.font(.title3.weight(.medium))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/SocialPublicProfileView.swift:470` `.font(.title2)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/SquareCloudComposerView.swift:91` `.font(.largeTitle)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/SquareCloudComposerView.swift:275` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/SquareCloudComposerView.swift:286` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/SquareCloudComposerView.swift:326` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/SquareCloudComposerView.swift:330` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/SquareCloudComposerView.swift:339` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/SquareCloudComposerView.swift:380` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/SquareCloudFeedViews.swift:103` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/SquareCloudFeedViews.swift:199` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/SquareCloudFeedViews.swift:425` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/SquareCloudFeedViews.swift:468` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/SquareCloudFeedViews.swift:501` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/SquareCloudFeedViews.swift:537` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/SquareComponents.swift:113` `.font(.subheadline)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/SquareComponents.swift:127` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/SquareDetailView.swift:365` `.font(.caption)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/SquarePostVideoViews.swift:170` `.font(.largeTitle)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/SquareWorkspaceView.swift:45` `.font(.footnote)` — pinned by a contract test; update the test in the same commit
- `App/SquareWorkspaceView.swift:89` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/SquareWorkspaceView.swift:94` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/SquareWorkspaceView.swift:120` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/SquareWorkspaceView.swift:125` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/SquareWorkspaceView.swift:148` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/SquareWorkspaceView.swift:178` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/SquareXcxPostCard.swift:40` `.font(.largeTitle)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/StoreKit2SubscriptionAndRefundSectionView.swift:160` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/StoreKit2SubscriptionAndRefundSectionView.swift:179` `.font(.caption.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/StoreKit2SubscriptionAndRefundSectionView.swift:182` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/StoryRuleEditorView.swift:140` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/StoryRuleEditorView.swift:144` `.font(.caption2)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/StoryRuleEditorView.swift:170` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/StoryRuleEditorView.swift:330` `.font(.caption2)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/StoryRuleEditorView.swift:346` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/StoryRuleEditorView.swift:349` `.font(.caption)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/TeamComponents.swift:112` `.font(.title)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/TeamMeetingHandshakeSectionView.swift:134` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/TeamMeetingHandshakeSectionView.swift:159` `.font(.caption2.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/TeamMeetingHandshakeSectionView.swift:234` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/TeamMeetingHandshakeSectionView.swift:237` `.font(.caption2.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/TeamReportReasonSheet.swift:130` `.font(.largeTitle)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/TemplateAuthoringCoverHeader.swift:29` `.font(.title)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/TemplateAuthoringCoverHeader.swift:49` `.font(.body.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/TemplateAuthoringDetailForms.swift:49` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/TemplateAuthoringMineView.swift:57` `.font(.footnote.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/TemplateAuthoringMineView.swift:148` `.font(.headline)` — pinned by a contract test; update the test in the same commit
- `App/TemplateAuthoringMineView.swift:152` `.font(.headline)` — pinned by a contract test; update the test in the same commit
- `App/TemplateAuthoringPublishResultPresentation.swift:70` `.font(.largeTitle)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/TemplateAuthoringSavedResultPresentation.swift:70` `.font(.largeTitle)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/TemplateAuthoringView.swift:700` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/TemplateBlindOptionEditor.swift:86` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/TemplateChoiceMemoryFields.swift:63` `.font(.caption.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/TemplateChoiceOptionRowsEditor.swift:102` `.font(.title3)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/TemplateD6RehearsalView.swift:99` `.font(.largeTitle)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/TemplateDetailXbChrome.swift:76` `.font(.title3)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/TemplateDetailXbChrome.swift:196` `.font(.caption.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/TemplateHintLadderFields.swift:22` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/TemplateMiniGameConfigurationView.swift:42` `.font(.caption.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/TemplatePreferenceDraftEditor.swift:33` `.font(.system(.body, design: .monospaced))` — monospaced design (code / ticket number)
- `App/TestFlightInternalAndExternalSmokeSectionView.swift:146` `.font(.footnote.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/TestFlightInternalAndExternalSmokeSectionView.swift:163` `.font(.caption2.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/ThreeDocumentMasterCrosswalkSectionView.swift:157` `.font(.subheadline.monospaced().weight(.semibold))` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/ThreeDocumentMasterCrosswalkSectionView.swift:169` `.font(.caption2.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/TicketWalletDetailView.swift:319` `.font(.subheadline)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/TicketWalletDetailView.swift:321` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/TicketWalletDetailView.swift:323` `.font(.caption)` — pinned by a contract test; update the test in the same commit
- `App/TicketWalletTeamView.swift:196` `.font(.footnote.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/TicketWalletView.swift:43` `.font(.headline)` — pinned by a contract test; update the test in the same commit
- `App/TicketWalletView.swift:50` `.font(.headline)` — pinned by a contract test; update the test in the same commit
- `App/TicketWalletView.swift:240` `.font(.headline)` — pinned by a contract test; update the test in the same commit
- `App/TicketWalletView.swift:241` `.font(.caption.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/TicketWalletView.swift:374` `.font(.footnote.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/TopicComponents.swift:8` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/TopicDetailView.swift:236` `.font(.title2.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/TopicReviewsContent.swift:88` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/TopicSelfPlaySheet.swift:32` `.font(.footnote)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/TopicThemeRecordsView.swift:16` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/TopicUnlikeControls.swift:18` `.font(.title3)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/TopicXcxSections.swift:252` `.font(.caption2.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/TopicXcxSections.swift:388` `.font(.caption)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/TopicXcxSections.swift:463` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/UITestFlowReadinessAnchorSectionView.swift:180` `.font(.caption.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/UITestFlowReadinessAnchorSectionView.swift:182` `.font(.caption2.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/UltimateReleaseReadinessExecutiveSummaryView.swift:202` `.font(.caption2.monospaced().weight(.bold))` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/UnifiedDecisionsU01ToU08SectionView.swift:187` `.font(.caption.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/UnifiedDecisionsU01ToU08SectionView.swift:202` `.font(.caption2.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/UnifiedDecisionsU01ToU08SectionView.swift:212` `.font(.caption2.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/UnifiedReleaseAuditHubView.swift:209` `.font(.caption2.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/UnifiedReleaseAuditHubView.swift:229` `.font(.caption.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/UnifiedTicketExecutionMatrixSectionView.swift:413` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/UnifiedTicketExecutionMatrixSectionView.swift:420` `.font(.caption.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/UnifiedTicketExecutionMatrixSectionView.swift:437` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/UnifiedTicketExecutionMatrixSectionView.swift:440` `.font(.caption.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/UnifiedTicketExecutionMatrixSectionView.swift:460` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/UnifiedTicketExecutionMatrixSectionView.swift:463` `.font(.caption.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/UnifiedTicketExecutionMatrixSectionView.swift:483` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/UnifiedTicketExecutionMatrixSectionView.swift:486` `.font(.caption.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/UsageConsentGateView.swift:135` `.font(.footnote.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/VerificationCodeView.swift:92` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/WalletCommerceViews.swift:15` `.font(.largeTitle)` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/WalletCommerceViews.swift:282` `.font(.caption2.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/WalletCommerceViews.swift:1050` `.font(.title3.weight(.semibold))` — SF Symbol icon size (keep the text style or match the adjacent text token)
- `App/WalletEarningsOverview.swift:180` `.font(Theme.Font.body)` — pinned by a contract test; update the test in the same commit
- `App/WalletIncomeAnalysisView.swift:193` `.font(Theme.Font.body)` — pinned by a contract test; update the test in the same commit
- `App/Wave3HandoffStatusSectionView.swift:124` `.font(.caption.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/Wave3HandoffStatusSectionView.swift:132` `.font(.caption.monospaced().weight(.bold))` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/Wave3HandoffStatusSectionView.swift:148` `.font(.caption.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/Wave3HandoffStatusSectionView.swift:172` `.font(.caption2.monospaced().weight(.semibold))` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/WeChatAndAppleSignInNonceStateSectionView.swift:118` `.font(.caption2.monospaced().weight(.bold))` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/WeChatAndAppleSignInNonceStateSectionView.swift:167` `.font(.caption2.monospaced().weight(.semibold))` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/WeChatShareCardAndPosterExportSectionView.swift:127` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/WebViewAndExternalSafariSandboxSectionView.swift:133` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/WorkshopCommerceView.swift:63` `.font(Theme.Font.body)` — pinned by a contract test; update the test in the same commit
- `App/WorkshopCommerceView.swift:135` `.font(Theme.Font.body)` — pinned by a contract test; update the test in the same commit
- `App/WorkshopCommerceView.swift:137` `.font(Theme.Font.label.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/WorkshopCommerceView.swift:194` `.font(Theme.Font.body)` — pinned by a contract test; update the test in the same commit
- `App/WorkshopCommerceView.swift:276` `.font(Theme.Font.body)` — pinned by a contract test; update the test in the same commit
- `App/WorkshopCommerceView.swift:284` `.font(Theme.Font.body)` — pinned by a contract test; update the test in the same commit
- `App/WorkshopCommerceView.swift:289` `.font(Theme.Font.label.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/WorkshopCommerceView.swift:301` `.font(Theme.Font.body)` — pinned by a contract test; update the test in the same commit
- `App/WorkshopCommerceView.swift:345` `.font(Theme.Font.label.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/WorkshopCommerceView.swift:381` `.font(Theme.Font.label.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/WorkshopCommerceView.swift:400` `.font(Theme.Font.body)` — pinned by a contract test; update the test in the same commit
- `App/WorkshopCommerceView.swift:440` `.font(Theme.Font.body)` — pinned by a contract test; update the test in the same commit
- `App/WorkshopLicenseLibraryView.swift:38` `.font(Theme.Font.body)` — pinned by a contract test; update the test in the same commit
- `App/WorkshopLicenseLibraryView.swift:43` `.font(Theme.Font.body)` — pinned by a contract test; update the test in the same commit
- `App/WorkshopLicenseLibraryView.swift:99` `.font(Theme.Font.body)` — pinned by a contract test; update the test in the same commit
- `App/WorkshopModUpgradeSheetView.swift:71` `.font(.footnote.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/WorkshopModUpgradeSheetView.swift:84` `.font(.footnote.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/WorkshopModUpgradeSheetView.swift:97` `.font(.footnote.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/WorldAndCityLifecycleSectionView.swift:187` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/WorldAndCityLifecycleSectionView.swift:190` `.font(.caption.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/XcodeGenAndScaffoldDiagnosticsSectionView.swift:141` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/ZeroRegressionLegacyServerIsolationSectionView.swift:169` `.font(.subheadline)` — pinned by a contract test; update the test in the same commit
- `App/ZeroRegressionLegacyServerIsolationSectionView.swift:206` `.font(.caption2.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand
- `App/ZeroRegressionLegacyServerIsolationSectionView.swift:216` `.font(.caption2.monospaced())` — monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand

