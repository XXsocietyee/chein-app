# Design report K: shared UI kit (branch `ui/kit`)

Build: `design-run.sh k <worktree> --design-fixture <name>`, BUILD_EXIT=0, no logic changes. Files in `App/DesignSystem/`, fixtures in `App/DesignFixtures/` (`#if DEBUG` only).
Theme: components read `@Environment(\.cyPalette)`; set the domain once with `.themeDomain(.player | .merchant)` (player = dark, merchant = light). Violet is not used by any kit component.

## Components and initialisers
| Component | Initialiser |
|---|---|
| `CYHeroHeader` | `CYHeroHeader(_ title: LocalizedStringKey, subtitle: LocalizedStringKey? = nil)` or `…(_ title, subtitle:, @ViewBuilder illustration:)` |
| `CYPillButton` | `CYPillButton(_ title, style: CYPillStyle = .primary, systemImage: String? = nil, fullWidth: Bool = true, action:)`; `CYPillStyle` = `.primary` (solid) / `.secondary` (outlined) / `.tertiary` (text) |
| `CYSectionHeader` | `CYSectionHeader(_ title, subtitle: … = nil, actionTitle: … = nil, action: (() -> Void)? = nil)` (in `CYDesignComponents.swift`) |
| `CYListRow<Leading>` | `CYListRow(_ title, meta: … = nil, trailing: CYListRowTrailing = .chevron, card: Bool = false) { leading }` (leading closure optional); `CYListRowTrailing` = `.none/.chevron/.value(String)/.valueChevron(String)`; `CYRowIcon(systemImage:)` for the leading tile |
| `CYImageCard` | `CYImageCard(_ title, meta: … = nil, imageURL: URL? = nil, aspectRatio: CGFloat? = nil, style: .hero / .shelf = .hero)`; `.hero` 16:10 full width, `.shelf` 3:2 and 280pt wide for horizontal shelves. HTTPS only, placeholder tile without URL |
| `CYStatusChip` | `CYStatusChip(_ text, tone: CYStatusTone = .neutral, systemImage: String? = nil)`; tones `.neutral/.success/.warning/.danger/.info` |
| `CYEmptyState` | `CYEmptyState(systemImage: String = "tray", _ message, actionTitle: … = nil, action: (() -> Void)? = nil)` |
| `CYErrorState` | `CYErrorState(_ message = "Couldn't load this. Check your connection.", retryTitle: = "Retry", onRetry:)` |
| `CYSkeleton` | `CYSkeleton()` (layout-shaped bars, no spinner) |

Registry: `DesignFixtureRegistry.make(_:)` in `App/DesignFixtures/DesignFixtureRegistry.swift`. Fixtures: `kit`, `kit-2` (dark), `kit-merchant`, `kit-merchant-2` (light). Screen workers add one `case` each.

## Screenshots (dark = player, light = merchant)
- Dark top: `docs/release/design-report-K-shots/kit.png`; dark lower: `kit-2.png`
- Light top: `kit-merchant.png`; light lower: `kit-merchant-2.png`
Top screen: hero, primary/secondary/tertiary pills, section header with See all, hero image card, shelf cards. Lower screen: list rows (value, unknown "—"), chips, skeleton, empty state, error state.

## Fixes made in this pass
- `CYSkeleton` hung the main thread (blank white window) because of `containerRelativeFrame` inside a ScrollView; replaced by a small `Layout` giving a fraction of the width.
- Gallery applied the page background outside `.themeDomain`; fixed.
- `CYImageCard`: added `.shelf` style; scrim is now short and only behind the text.
- `CYDomainCardModifier`: shadow moved onto the card background so it no longer haloes the text on the light theme.
- Empty/error state vertical padding reduced (xxl) so both fit one screen.

## Checklist notes
Not yet checked (open): Dynamic Type XL and 简体中文 renders of the kit; light scrim over real photos (only placeholder tiles seen); secondary outline on dark is subtle (visible but low contrast).
