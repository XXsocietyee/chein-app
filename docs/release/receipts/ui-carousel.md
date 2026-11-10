# Receipt: glass carousel (DES-e2)

Spec: `/Users/fanning/chengyin-refs/specs/glass-carousel.md`. Deviations and reasons: `docs/release/motion-spec-carousel.md`.

## Delivered
- `App/DesignSystem/CYGlassCarousel.swift`: `CYGlassCarousel`, `CYCarouselRail` (load phases + Dynamic Type fallback), `CYCarouselCard`, `CYCarouselArt`, `CYCarouselCaption`, `CYGlassSliver`, `CYGlassGroup`, `CYCarouselBackdrop`, `CYScrubHandle`, `CYCarouselSkeleton`, pure `CYCarouselState.reduce(_:)`.
- Wired: Home `Editor's picks` and `Upcoming` (`HomeFeedView.carouselRail`; `Nearby` unchanged) and the ticket wallet (`TicketWalletView.ticketCarousel`, shown for 2+ openable tickets). Accessibility Dynamic Type sizes keep the vertical list.
- DEBUG fixtures: `carousel-events`, `carousel-tickets`, `carousel-empty`, `carousel-loading`, `carousel-ax` (`App/DesignFixtures/CarouselFixtures.swift`, registered in the registry).
- Strings: `docs/release/ui-strings-carousel.json` (EN + zh-Hans), merged into `Resources/Localizable.xcstrings` with `tools/merge_localization_fragments.py` so catalog coverage stays at 0 gaps. `Questify.xcodeproj` regenerated with `tools/generate_project.py` (three new source entries).
- No Core/Tests/Config edits; no network, verification or view-model calls changed; no money-moving switch touched.

## Cloud evidence
- `93b9a4d1b`: Build PASS, 150 warnings, 0 errors. Test queued at the time of writing (known-red on the base tree per the UI cloud conventions).
- Before push: `check_scaffold.py` PASS (gaps 0), `check_design_lint.py` PASS.

## Not verified
Nothing was run on a device or simulator. Visual look of iOS 26 glass, 120 Hz fling hitches, VoiceOver paging and Reduce Motion behaviour still need a device or fixture pass.
Known gap against the spec: the backdrop cross-fades on settle rather than interpolating while dragging (iOS 17 target).
