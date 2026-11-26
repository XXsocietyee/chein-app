# Receipt: native-r2/me-account (Me / Account lane)

Branch: `native-r2/me-account`, cut from `origin/ui/combined-r7` (82bcf2c2d) and merged with it before every push.
Brief: `docs/briefs/native-r2.md` (design/handoff-r2): component rule, "EVERYTHING native", gates.

## Scope
- **Owned files:** App files whose names start with Account, Profile, Settings, Wallet, Ticket, Order, Member, Invoice, Coupon, Pass, Auth, Login, Consent, Privacy, Notification, Inbox, Messaging or IM. That is 190 files.
- **Changed:** 90 of them. These held custom chrome (`CY*` components, gradients, shadows, card surfaces, hex/`CYRGB`, forced dark).
- **Already native:** the other 100 needed no change.
- **Not touched:** `App/DesignSystem`, `CYDomainPalette`, `App/Theme`, `Core/`, and every file outside the prefixes.

## What changed (summary per area)
- **Account root, Settings, Passport:**
  - `CYListRow` + `CYRowIcon` became `Label(_, systemImage:)` inside `NavigationLink`, in an inset grouped `Form`/`List`; MP row icons stay through `MPAsset`.
  - Settings tiles are tint-filled with a white glyph, as in iOS Settings.
  - Sign-out is now `MemberConfirmSheet`: an inset grouped list with system buttons and `.presentationDetents`.
- **Member header (`MemberHomeHeader`, `ProfileCurrentAvatarView`):**
  - The card, gradient fade, avatar ring and stagger animation are gone.
  - The MP cover (`mer1`) is kept as the one plain header image of the first section.
  - The 7-day streak is a `LabeledContent` row.
- **Member popups (`MemberAreaPopupSurfaces`):**
  - All 22 `CYConfirmSheet` uses became `MemberConfirmSheet` (same arguments).
  - `CYModal` became `.alert`.
  - `CYOptionSheet` became a list sheet with detents.
- **Auth/Login:**
  - Both are `Form`s with `TextField`/`SecureField`, `.textContentType` and errors in section footers.
  - The six one-time-code boxes are one `.oneTimeCode` `TextField`.
  - One `.borderedProminent` button per screen.
- **Messaging/IM:**
  - In-page hero titles became `.navigationTitle`.
  - The chat "more" sheet is a toolbar `Menu`.
  - States use `ContentUnavailableView` / `ProgressView`.
  - The unread count is system text with `.contentTransition(.numericText())`.
  - Cover art is a system fill plus an SF Symbol.
- **Money flows (Wallet, Order, Invoice, Coupon, Ticket, Pass):** UI only.
  - Every amount, gate, `.disabled(...)`, request and `Task` is unchanged.
  - Buttons are `.borderedProminent` / `.bordered` / `.borderless` with `.controlSize(.large)`, one prominent per screen.
  - Skeletons are `ProgressView`; empty and error states are `ContentUnavailableView`.
  - The income-analysis bars use Swift Charts `BarMark`; source bars use `ProgressView(value:)`.
  - Filter chips became a segmented `Picker` (invoice history, pass library, pass market, favorites, score appeals) or a menu `Picker` (coupons).
- **Ticket pass:**
  - Removed: foil, tilt, glow, flip and tear animation, and forced dark.
  - Kept: the brightness boost, check-in logic and the QR quiet zone, because scanning needs it.

## Closest Apple control (no exact equivalent)
- **Coop invite cards:** `GroupBox`.
- **Badges and stamps:** SF Symbols (`rosette`, `seal.fill`) in place of foil medal art.
- **Compliance three-step header:** a linear `ProgressView` ("n/3").
- **Unlock-step dots:** a linear `ProgressView`.
- **Ticket pass:** keeps its notched outline (the closest match to a Wallet pass) on system backgrounds.
- **Copy toasts (`cyToast`):** kept, because iOS has no toast control.
- **Rows that push from a `Button` (state-driven navigation):** they draw `chevron.forward` in `.tertiary`. A `NavigationLink` would have changed the navigation logic.
- **The IM report unread count in a `safeAreaInset`:** secondary text, because `.badge` only renders in a `List`.

## Left on purpose
- **`IMScreenTitle` (`CYHeroHeader`):** shared with `IMFileViews` and `IMVideoViews`, which this lane doesn't own.
- **IM send-ghost fill:** it stops the field placeholder overlapping the text while sending.
- **`CYCarouselRail` in `TicketWalletView`:** a second ticket entry, kept so its action isn't lost. Owner to decide.
- **`cyPushedChrome`, `cyDomainScreen`, `cyPageTitle`:** they carry the domain and tab-bar behaviour and resolve to system values.
- **`InvoiceLaunchTitleEditor`:** keeps `CYFooterBar` around a `.borderedProminent` save button.
- **`CouponRuntimeFixture`:** a debug-only overlay.

## Identifiers
- Every `accessibilityIdentifier` from the base is still present. Identifiers that used to be passed into DS components are now on the replacement views.
- **Segmented pickers:** the per-segment identifiers (`passMarket.tab.*`, `passLibrary.kind.*`, `passDetail.for.*`) sit on the segment `Text`. XCUITest may not expose them. No UI test uses them.
- **`passOrder.rows`:** moved from the whole order card to its first row.

## Gates
- `python3 tools/check_scaffold.py` prints `PASS structural checks` on the pushed head.
- **No compiler in the cloud.** Every API was checked by grep in the repo or against the iOS 17 SDK: `ContentUnavailableView`, `LabeledContent`, `Picker(selection:content:label:)`, `.presentationDetents`, `Chart`/`BarMark`/`AxisMarks`, `.contentTransition(.numericText())`, `MemberConfirmSheet`, `themeDomain`, `CYColor.bgPage`/`bgSurface`.
- **Compile traps checked:**
  - braces and parentheses balance in every file;
  - no `@State` shadowing;
  - labelled trailing closures (`label:`, `icon:`, `header:`);
  - no `String(localized:)`;
  - no hex literals;
  - no `Color(...)` calls outside the design system (semantic styles `.quaternary` and `.background`, or `CYColor` tokens, are used instead).
- **Strings:** no new keys, so there is no `docs/port/strings/native-r2-me-account.json` fragment.

## Contract tests that now fail
Python contract checks were run (as `python3 <file>`) on the base and on the head. Five tests that passed on the base now fail. Every one pins a removed custom component or token in the source text; none pins a behaviour.
- **`test_accessibility_hardening_wave`:** expects `CYColor.textOnAccent` in `IMInboxViews` and `OrderCardComponents` (the old badge and filter-pill tokens).
- **`test_account_collection_structure`:**
  - expects `QuestifyImageEntityCard(` and `appLocalized("social.posts"…)`;
  - its catalog file `docs/account-collection-localizations.json` lacks two keys (`accountCollection.favorites.categories`, `.unknown`) that `Localizable.xcstrings` already has.
- **`test_design_token_unification_contract`:** expects the removed `CYOrderActionSecondaryLabel`.
- **`test_global_chrome_domain_contract`:** expects `CYFooterBar` in `OrderLifecycleView` and `InvoiceLaunchApplyView`.
- **`test_pkg03_favorites_closure`:** expects `CYTabs(... variant: .underline)`.

Two more tests already failed on the base and now pin more native-r2 changes:
- `test_pkg19_login_deletion_chain`: `CYConfirmSheet` on sign-out;
- `test_profile_reload_discard` and `test_social_guide_templates`: file hashes.

**Coordinator:** please re-pin these on the native components or retire them. They are test files outside this lane.

Two pins were kept green without any behaviour change:
- `test_ticket_wallet_play_entry`: the Present button is written as `Button(action:)`, so the Play gate parse reads the Play button again.
- `test_pages_privacy_index_page_ready`: the guide-unavailable state uses `ContentUnavailableView` with `.cyIdentifier`.
