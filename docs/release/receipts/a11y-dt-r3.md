# a11y-dt r3 receipt (branch `design/r3-a11y`)

Lane area: Dynamic Type up to AX5, VoiceOver labels/order/traits, Reduce Motion, contrast, 44 pt targets on every player screen.
Code-only, cloud-verified (no Swift compiler / simulator in the cloud). Gates per run: generate_project, check_scaffold,
check_a11y_lint (0 current), contract_ratchet --check (new 0), check_design_consistency (PASS).
No MP section added, removed or reordered by this lane (OWNER RULE): fixes are sizing, traits and labels only.

## Run 1 (2026-11-27)

Whole-tree scans done first (player files; Merchant / Fixture / Diagnostics / *SectionView skipped):
- `repeatForever` animations without a Reduce Motion check: **0**.
- `onTapGesture` without a button trait / action nearby: 17 hits reviewed; all either have an adjustable/custom
  accessibility action (journey settle step dots, medal stack), are map coordinate pickers with a text alternative,
  are tap-to-skip on a moment that also has a Done button, or are fixtures. No change needed.
- Button labels with a fixed frame < 44 pt and no min-hit wrapper: 0 real (all hits already wrap to 44).
- **Text inside a fixed-size circle/tile** (clips at AX sizes): 13 hits → fixed below.

| MP page | Native view file | MP sections present | Optimization applied (a11y-dt) | Status |
|---|---|---|---|---|
| `pages/index/index` (Home tab root) | `HomeFeedView.swift`, `HomeSearchTabParityViews.swift` (hero) | ✓ (mp-home owns order) | Verified: rails switch to full-width rows at AX sizes, banner autoplay stops for Reduce Motion + VoiceOver, page dots hidden, avatar/city 44 pt, greeting header trait. No change needed. | Done |
| `pages/roam/index` (Roam map home) | `NativeR2/MapHome/RoamMapHomePanel.swift` | ✓ (mp-roam owns order) | Verified: panel handle is adjustable for VoiceOver (peek/medium/large value), peek height scaled for Dynamic Type and capped at 40 %. No change needed. | Done |
| `pages/member/index` (Me tab root, passport block) | `PassportView.swift` (`actions`) | ✓ (mp-mine owns order) | 票夹 / 钱包 / 消息 capsule row → `AnyLayout` VStack at AX sizes (same buttons, same order), so labels no longer break one glyph per line; stamp grid / badge rail already adapt (verified) | Done |
| City ordered run (`subpackageJourney` city route list) | `CityOrderedMapView.swift` | ✓ | Stop number circle 28 pt → `@ScaledMetric(relativeTo: .footnote)` | Done |
| `pages/activity` official route detail | `E1OfficialRouteParts.swift` | ✓ | Route node number circle 28 pt → `@ScaledMetric(relativeTo: .body)` | Done |
| Growth leaderboard (`subpackageMember` rank) | `GrowthLeaderboardView.swift` (podium) | ✓ | Podium place badge 28 pt → `@ScaledMetric(relativeTo: .caption)` | Done |
| `pages/club/*` rows | `ClubKit/ClubR1Kit.swift` (`ClubR1Row`) | ✓ | Initial tile 32 pt (`.headline`) → `@ScaledMetric(relativeTo: .headline)` | Done |
| Questo accusation (`pages/playkit`) | `PlayKitQuestoViews.swift` (`PlayKitAccusationView`) | ✓ | Suspect initial circle 52 pt → `@ScaledMetric(relativeTo: .title3)` | Done |
| `subpackageMember` participants (常用出行人) | `ProfileParticipantsView.swift` | ✓ | Name initial circle 40 pt → `@ScaledMetric(relativeTo: .headline)` | Done |
| City deed card (roam city board) | `CityKit/CityDeedCard.swift` | ✓ | Owner avatar letter 22 pt → `@ScaledMetric(relativeTo: .caption)` | Done |
| Settings › marketing consents | `AccountComplianceViews.swift` | ✓ | Merchant initial / logo tile 36 pt → `@ScaledMetric(relativeTo: .body)` (logo and initial stay the same size) | Done |
| Blind taste (`pages/playkit` legacy kit) | `PlayKitLegacyViews.swift` (`PlayKitBlindSteps`, new private view) | ✓ | Step number circle 36 pt → `@ScaledMetric(relativeTo: .body)`; three steps `ViewThatFits` HStack → VStack at AX sizes / long English; combined VoiceOver sentence kept | Done |
| Journey record (`subpackageJourney` narrative) | `JourneyNarrativeView.swift` | ✓ | Found-count ring 88 pt → `@ScaledMetric(relativeTo: .title)` capped at 132; number scales down (0.5) instead of clipping | Done |
| Club month calendar (design component) | `ClubComponents.swift` (`E3MonthGrid`) | ✓ | Seven 38 pt day circles capped at `.xxxLarge` (as Calendar's month grid); each day keeps its VoiceOver label | Done (only fixture-hosted today) |

## Not done (next run starts here)
- `CityOrientationRunView.swift:190` teammate initial on the map annotation (28 pt, `.caption.bold()`): Map annotation;
  decide whether to scale or cap. 
- Next pages without a row: Publish tab root (`PublishTabRootView`), Club home (`ClubHomeView`)
  full AX5 / VoiceOver order pass; `.lineLimit(1)` audit on tab-root rows (P12 + AX5).

## For other lanes
- none this run.
