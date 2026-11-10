# Dynamic Type static audit (up to AX5)

Branch `ui/e4`, code-only, cloud-verified. Universe: `tail-all-sorted.txt` + `App/DesignSystem/*` (388 files).
218 files were skipped because `ui/cloud-*` branches change them; 170 files audited.
Patterns scanned: fixed `.frame(height:)`/`width:` near text, `lineLimit(1)`, `minimumScaleFactor`, `.system(size:)`, `.dynamicTypeSize(...)` caps, HStack rows, unscaled icon tiles.

## Fixed

| File | Issue | Fix |
|---|---|---|
| DesignSystem/CYBalanceHero.swift | label and delta chip forced to one line; amount floor 0.6 truncates at AX | removed lineLimit(1) on label/delta; amount min scale 0.4 at accessibility sizes |
| DesignSystem/CYMoneyRow.swift | title/detail/amount in one HStack, all `lineLimit(1)` (truncated at AX) | stack vertically at accessibility sizes; title/detail may wrap; amount stays single line |
| DesignSystem/CYMapChrome.swift (CYMapCallout) | map callout text `lineLimit(1)` | `lineLimit(2)` |
| DesignSystem/CYListRow.swift (CYRowIcon) | 40pt icon tile next to scaling text | 56pt at accessibility sizes |
| DesignSystem/CYCityKit.swift (CYCollapsibleCard) | 36pt icon tile fixed | 52pt at accessibility sizes |
| DesignSystem/CYCityKit.swift (CYTimelineItem) | 28pt rail/dot fixed beside text | 40pt at accessibility sizes |
| CooperationBrowserView.swift | partner name `lineLimit(1)` (key info) | `lineLimit(2)` |
| RegistrationSheetView.swift | ticket price / checkout total squeezed by neighbouring text (scale 0.7/0.6 + one line) | `.layoutPriority(1)` so the neighbour wraps instead |
| WithdrawalSupportLandingView.swift | balance largeTitle `lineLimit(1)`, scale 0.6 floor | `lineLimit(2)` |

Env-based sizes (not `@ScaledMetric`) were used for the tiles so the memberwise inits that other files call stay unchanged.

## Reviewed, no change

| File | Item | Why |
|---|---|---|
| DesignSystem/CYCollectible, CYCoverArt, CYStateKit, CYSignature | `.system(size: size * k)` glyphs | decorative glyphs scaled to a container whose `size` comes from the caller; hidden from VoiceOver |
| DesignSystem/CYSignature.swift:54, CYMapChrome.swift:163 | 8/10pt fixed fonts | DEBUG-only placeholder labels |
| DesignSystem/CYMapChrome.swift:184 | 9pt callout tail glyph | decorative |
| DesignSystem/CYMapChrome.swift (CYGoLabel), CYConfirmSheet | fixed frames | already `@ScaledMetric` |
| DesignSystem/CYCollectible.swift:63, CYHeroBanner.swift:103 | minimumScaleFactor | already disabled at accessibility sizes / 3-line limit |
| Many files | `frame(width: 0/height: 0)`, `Color.clear.frame(height: 0)` | zero-size hosts and anchors, no text |
| RoamHistoryShareView.swift:223, SquarePostVideoViews.swift:169-201, RetainedImageSelectionView.swift:74, ProfileCurrentAvatarView.swift, SocialPublicProfileView.swift:393, NearbyMapDiscoveryView.swift:270 | fixed image/avatar/canvas frames | media, no adjacent text clipping; avatar sizes are intentional |
| RegistrationSheetView.swift:375 | checkout bar `.dynamicTypeSize(...accessibility1)` | deliberate cap on a pinned bottom bar so the CTA cannot swallow the screen; scroll content above is uncapped |
| ShopNPCFixtureView.swift:57, WalkingNavigationView.swift:69 | `.dynamicTypeSize(...)` overrides | test-fixture hook and user-chosen size, respectively |

## Not audited
218 files in the universe are touched by `ui/cloud-*` branches; they need the same pass after those merge.
Row-stacking (HStack to VStack at AX) was checked by pattern only; per-screen review needs a render at AX5.
