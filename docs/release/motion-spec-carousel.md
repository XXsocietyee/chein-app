# Glass carousel — what changed vs the advisor spec

Source: `/Users/fanning/chengyin-refs/specs/glass-carousel.md`. Kit: `App/DesignSystem/CYGlassCarousel.swift`.
Wired into: Home `Editor's picks` and `Upcoming` rails (`HomeFeedView.carouselRail`; `Nearby` keeps the compact shelf) and the
ticket wallet (`TicketWalletView.ticketCarousel`, a deck above the rows). Fixtures: `carousel-events|tickets|empty|loading|ax`.

## Kept as specified
- Layout tokens (`CYCarouselMetrics`): card = `min(W − 2(peek+gutter), 0.74W, 320)`, 3:4, peek 28 (24 on ≤ 375 pt), gutter 16, radius `xl`.
- `viewAligned(limitBehavior: .always)`, `scrollPosition(id:)`, `contentMargins`, `scrollClipDisabled`; one `cyHaptic(.selection)` on the rail.
- Card scale 1 → 0.92, art parallax `phase · 32 pt`, caption slides `−phase · 18` and is gone by |phase| 0.55, all via `scrollTransition(.interactive)`.
- Sliver: glass on iOS 26 (`#available`, one `GlassEffectContainer` via `CYGlassGroup`), `ultraThinMaterial` + edge gradient before, `black 0.55` under Reduce Transparency.
- Backdrop: seed hue gradient + radial glow, blurred 40 once and `drawingGroup()`; flat `bgElevated` + 12 % tint under Reduce Transparency.
- Scrub handle (24 pt, 44 pt hit area, adjustable for VoiceOver), `n of N` labels, `pageScrolled` announcement on settle.
- Accessibility Dynamic Type sizes keep the existing vertical `CYImageCard(.hero)` list (rail `accessibilityFallback`).

## Changed, and why
| Spec | Implemented | Why |
|---|---|---|
| Generic `CYGlassCarousel<Item, Card>` with a card closure | Non-generic `CYGlassCarousel(slides: [CYCarouselSlide])` + `CYCarouselCard` | Both call sites need the same portrait card; one model avoids `AnyView` and generic inference cost. Callers map their own rows to slides. |
| `CYTicketPassShape(notchY:perforation:)` | Existing `TicketStubShape` + a dashed perforation drawn by the card | `CYTicketPass.swift` does not exist on this tree; `TicketStubShape` is the real pass outline the wallet rows already use. |
| `onScrollPhaseChange` (iOS 18) for dragging/settling | `DragGesture` via `simultaneousGesture` + `selectedID` changes, folded through a pure `CYCarouselState.reduce(_:)` | Deployment target is iOS 17. The reducer is value-typed so it can be unit-tested later without a view. |
| Backdrop interpolates by |phase| while dragging | Backdrop follows the state machine: holds during a drag, cross-fades (`CYMotion.standard`, `reduced` under Reduce Motion) when the swipe lands | Without iOS 18 scroll APIs, per-frame offset needs a `GeometryReader` per card. A settle cross-fade is cheaper and never re-rasterises the blur mid-scroll. **Acceptance check 3 is met for the settle, not for in-drag interpolation.** |
| Backdrop bleeds above the section header | Backdrop is the rail's own frame, faded top and bottom with a mask | Inside a `List` row the rail cannot paint outside its row; the mask avoids a hard edge. |
| Sliver is a mask of width `peek` with a 1.18 horizontal stretch | Whole neighbour card is covered by the glass fill; only the `peek` strip is on screen | The neighbour is clipped by the screen edge anyway; no extra mask or stretch means no per-frame cost. Reduce Motion shows the sliver whenever the card is off-centre. |
| `cyPassTilt` on long press | Not added | The modifier does not exist in the kit; adding it is outside this task. |
| Loading skeleton via `CYPhaseView` | `CYCarouselSkeleton` (one card silhouette at card size), `CYPhaseView` for empty/failed/loaded | Keeps the rail height constant so nothing jumps when content arrives. |
| Rail height from a `GeometryReader` | `CYCarouselRail` measures width once (assumes 402 pt until measured) | A `GeometryReader` has no intrinsic height inside a `List`. |
| Cap items at 12 | Cap at 12 in both call sites; remaining items stay in the explore stream / wallet rows | As specified. |

## Not changed
Network, verification and view-model calls are untouched: the rail maps already-loaded `HomeFeedItem`/`TicketWalletTicket` values and opens
the same guarded destinations (`model.canOpen`, `TicketWalletDetailView`). Failed sections still show the existing retry row. No switch that
moves money changed. Ticket rows stay below the deck (full list, pending-order and non-openable tickets).

## Strings
`docs/release/ui-strings-carousel.json` (EN + zh-Hans): `carousel.position %lld %lld`, `carousel.scrub`, `carousel.loading`, `carousel.empty`,
`carousel.error`, `carousel.editorsPicks`, `carousel.upcoming`, `carousel.tickets`.

## Not verified here
No local build or device run (cloud-only). 120 Hz fling hitches (acceptance 8) and on-device glass look need an Instruments / device pass.
