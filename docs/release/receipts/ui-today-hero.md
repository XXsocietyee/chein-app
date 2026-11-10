# ui-today-hero (W1-6)

Explore (`App/HomeFeedView.swift`): the `List` is now a `ScrollView` + `LazyVStack`. No `List`, `listStyle` or `listRow*` remains in the file.

**Today card** (`HomeTodayCard`, `HomeTodayChoice.resolve`): one focal point at the top of the feed. Priority: a ticket starting within 24 h (or started up to 3 h ago) > a club event today (same calendar day) > "Start a roam". A candidate with no start time never wins; an unknown time shows an em dash, never a made-up value. One pill: Show ticket / See event / Start a roam.

**Rails**: the carousel and shelf rails keep `CYGlassCarousel` / `CYImageCard`; each is a titled VStack in the scroll view. The segmented kind picker, category picker, stream, load-more and footer are unchanged, now under an "Explore" header.

**Unchanged**: every feed data source (banners, sections, categories, page stream, continuation cards), the `model.canOpen`/permit gating, the configuration-unavailable state, search, refresh and skeleton timing.

**Wiring**: `HomeFeedView` gains optional `todayTicket`, `todayClubEvent`, `onOpenTodayTicket`, `onOpenTodayClubEvent`, `onStartRoam`. `SessionHomeFeedView`/`QuestifyApp` pass `onStartRoam` (switches to the Roam tab). Tabs are untouched (W1-1 not approved).

**Open for the integrator**: no ticket or club-event read is added (data unchanged), so on device the card shows "Start a roam" until the host supplies `todayTicket`/`todayClubEvent` from an existing ticket-wallet / club-calendar source. `HomeHeroHeaderSectionView` and `PlayContinuationBannerView` still wrap their content in `Section`; this renders inline in a stack but may need padding tuning on the first build.

**Strings**: Today-card copy uses the kit's `CYKitCopy` (EN + zh-Hans pair), like `CYStateView`. Section titles use the existing catalog keys.

**Fixtures** (DEBUG, `HomeFeedFixtureSupport.swift`): `--design-hero --design-today ticket|club` for the ticket and club states; default is the roam state; `HomeTodayFixtures.unknownTime` previews the em-dash/roam fallback. Four `#Preview`s in `HomeFeedView.swift`.

**Checks**: `swiftc -parse` on the four edited files, `check_scaffold.py`, `check_design_lint.py` and `check_design_fixture_release_exclusion.py` pass. Nothing was built or run on a simulator.
