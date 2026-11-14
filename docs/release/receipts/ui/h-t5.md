# Template 5 Restyle Receipt — `ui/h-t5`

- **Branch:** `ui/h-t5`
- **Base:** `origin/ui/h-design-v1` (`5d652cc08`, includes `origin/ui/main` `5ba7b0f2c`)
- **Scope:** Template 5 (checkout, booking, pricing, passes, market, gift claim — 15 mini-program routes) restyled onto shared `DesignSystem` tokens (`CYColor`, `CYTypography`, `CYSpacing`, `CYRadius`, `CYDomainPalette`) and components (`.cyDomainScreen()`, `.cyPushedChrome()`, `.cyDomainCard()`, `.cyPlayerSheetGlass()`, `CYFooterBar`, `CYHeroHeader`, `CYLoadingStateView`, `CYEmptyState`, `CYErrorState`, `MPParityKit` wrappers) with borderless elevated cards, tabular figures (`.monospacedDigit()`), explicit reasons/em dashes instead of fake zeros, and Accessibility Dynamic Type support.

## Screen Inventory (`screen -> mini-program route -> sections in order -> components`)

1. **Registration Sheet / Sign-up** (`RegistrationSheetView`, `WP07CommerceViews`) -> `pages/activity/baoming/baoming`
   - **Sections in order:**
     1. Recovered order section (`recoveredOrderSection`, when present)
     2. Participant section (`participantSection` / `RegistrationParticipantsSection`)
     3. Waitlist status/action section (`waitlistSection` / `RegistrationWaitlistSection`)
     4. Ticket card & price section (`activitySection`: `E1TicketArtwork`, `E1Perforation`, `ViewThatFits` ticket name + tabular price)
     5. Ticket picker section (`ticketSection`)
     6. Quote breakdown section (`quoteSection`: base price, member discount, coupon usability read-only `CouponUsabilitySection`, points switch/deduction row, payable amount)
     7. Confirmation / pinned bottom checkout bar (`confirmationSection`, `safeAreaInset(edge: .bottom)` checkout CTA bar behind `ReviewedAreaSwitch`)
   - **Components:** `.listStyle(.insetGrouped)`, `.scrollContentBackground(.hidden)`, `.themeDomain(.player)`, `.cyDomainPageBackground()`, `.cyDomainCard(radius: CYRadius.lg, padding: 0)`, `E1Perforation`, `ViewThatFits`, `.cyPlayerSheetGlass()`, `CouponUsabilitySection`, `.monospacedDigit()`
   - **DEBUG Fixtures:** `t5-baoming` (`RegistrationFixtureHostView(scenario: .standard)`), `t5-baoming-error` (`RegistrationFixtureHostView(scenario: .quoteError)`), plus existing `e1-registration` / `e1-registration-soldout`

2. **Topic Pricing** (`PublisherPricingView`) -> `pages/topic/pricing/index`
   - **Sections in order:**
     1. Hero header (`CYHeroHeader`)
     2. Subtype selector (`PublisherPriceSubtype` selfPlay / guided) & guided lead-cost/group-size inputs (`PublisherPricingView`)
     3. Cost floor breakdown (`CYTypography.dataXL.monospacedDigit()`, `TopicPricingXcx.moneyText`, floor/margin explanations)
     4. Reference comparison (`TopicPricingXcx.delta` with `CYColor.warningText` / `CYColor.textSecondary`)
     5. Partner lineup list (`NavigationLink` -> `PublisherPartnerView`)
     6. Phase gate notice & confirm CTA (gated behind `showsConfirm`)
   - **Components:** `.listStyle(.insetGrouped)`, `.scrollContentBackground(.hidden)`, `.cyHeroScreen()`, `.cyPushedChrome(domain: .merchant)` (`#F3F4F4` light canvas), `CYHeroHeader`, `CYEmptyState`, `CYColor.dangerText`, `CYColor.warningText`, `CYColor.textPrimary`, `CYColor.textSecondary`, `CYTypography.dataXL`, `CYTypography.meta`, `.monospacedDigit()`
   - **DEBUG Fixtures:** `t5-pricing`, `t5-pricing-error`

3. **Partner Preview Detail** (`PublisherPartnerView`) -> `pages/topic/pricing/partner/index`
   - **Sections in order:**
     1. Hero header (`CYHeroHeader`: Partner Club / Hosting Merchant)
     2. Invalid link empty state (`publisher.partner.invalid`, when link params invalid) or partner profile (`CYSkeleton`, `publisher.partner.error`, `publisher.partner.unknown` `—`, or partner name / description / `LabeledContent` terms rows)
   - **Components:** `.listStyle(.insetGrouped)`, `.scrollContentBackground(.hidden)`, `.cyHeroScreen()`, `.cyPushedChrome(domain: .merchant)`, `CYHeroHeader`, `CYSkeleton`, `CYColor.textPrimary`, `CYColor.textSecondary`, `CYTypography.cardTitle`
   - **DEBUG Fixtures:** `t5-partner`, `t5-partner-error`

4. **Member Orders List** (`ProfileOrdersView`, `OrderCardComponents`, `ProfileOrderFilterSection`) -> `subpackageMember/order/order`
   - **Sections in order:**
     1. Owner filter header & status filter chips (`ProfileOrderFilterSection`)
     2. Order cards list (`ProfileOrderRow` inside borderless `OrderCardSurface`, `OrderStatusChip`, `OrderAmountHero`, `OrderPillLabel`) or loading / empty / error states
     3. Navigation to `ProfileOrderDetailView` / `OrderLifecycleView`
   - **Components:** `.cyPushedChrome(domain: .player)`, `OrderCardSurface` (`.cyDomainCard(radius: CYRadius.lg)`), `OrderStatusChip`, `OrderAmountHero`, `OrderPillLabel`, `@Environment(\.dynamicTypeSize)` adaptive wrapping, `.monospacedDigit()`
   - **DEBUG Fixtures:** existing `orders-list`, `orders-empty`

5. **Order Detail / Lifecycle & Order Center Lookup** (`ProfileOrderDetailView`, `ProfileOrderSourceDetailSections`, `OrderLifecycleView`, `OrderCenterEntryView`) -> `subpackageMember/orderinfo/orderinfo`
   - **Sections in order (`ProfileOrderDetailView` / `OrderLifecycleView`):**
     1. Summary & status header (`OrderCardComponents`)
     2. Amount breakdown, coupons/points & time timeline rows (`ProfileOrderSourceDetailSections`, `OrderLifecycleView`)
     3. Payment / refund / cancel review icon & action CTA (`ReviewedAreaSwitch` gated)
     4. Support lookup section
   - **Sections in order (`OrderCenterEntryView`):**
     1. Order number lookup input
     2. Loading (`CYLoadingStateView(rows: 2)`) / Error / Registration link or commerce `LabeledContent` summary (`title`, `orderNo`, `statusText`, `amountText`, `createdAtText`)
   - **Components:** `.listStyle(.insetGrouped)`, `.scrollContentBackground(.hidden)`, `.cyPushedChrome(domain: .player)`, `CYLoadingStateView`, `CYColor.textSecondary`, `CYTypography.display`, `CYTypography.meta`, `.monospacedDigit()`
   - **DEBUG Fixtures:** existing `order-detail`, `core-order-info`, `core-order-info-unknown`, plus `t5-order-center`, `t5-order-center-error`

6. **Ticket Wallet & Ticket Detail** (`TicketWalletView`, `TicketWalletDetailView`, `E1CommerceComponents`) -> `subpackageMember/signup/index`
   - **Sections in order (`TicketWalletView`):**
     1. Filter menu toolbar / read-only notice
     2. Loading / partial failure / empty `ContentUnavailableView` card (`.cyDomainCard()`) or `E1TicketCard` list
   - **Sections in order (`TicketWalletDetailView`):**
     1. `TicketWalletDetailHeader` (`E1TicketCard`)
     2. Redemption notice, schedule & chapter entitlement rows (`TicketWalletEntitlementRow`)
     3. Present / Play actions
   - **Components:** `.listStyle(.insetGrouped)`, `.scrollContentBackground(.hidden)`, `.cyDomainScreen(.player)` / `.cyPushedChrome(domain: .player)`, `.cyDomainCard(radius: CYRadius.lg)`, `E1TicketCard`, `E1Perforation`, `TicketWalletEntitlementRow`, `CYTypography.micro`, `CYColor.textSecondary` (fixed font & violet lint violations removed and allowlist cleaned)
   - **DEBUG Fixtures:** existing `ticket-list`, `e4-tickets`, `ticket-detail`

7. **Free-Explore Bundle Launch** (`FreeExploreBundleLaunchView`) -> `subpackageMember/free-explore/index`
   - **Sections in order:**
     1. Bundle screen phase (`CYEmptyState`, `CYLoadingStateView`, `CYNoteBanner` + retry, `CYInfoCard` unknown outcome, or `readyContent` chapter/store/reservation date selection)
     2. Review & confirm modal `.sheet` (`Form` with notice, order/unit/offer/date `LabeledContent`, `CYPillButton` confirm/cancel)
   - **Components:** `.listStyle(.insetGrouped)`, `.scrollContentBackground(.hidden)`, `.cyPushedChrome(domain: .player)`, `CYLoadingStateView(rows: 2)`, `CYEmptyState`, `CYNoteBanner`, `CYInfoCard`, `CYPillButton`, `.cyPlayerSheetGlass()`
   - **DEBUG Fixtures:** `t5-free-explore`, `t5-free-explore-error`, plus existing `e5-free-explore`

8. **Pass Market** (`PassMarketView`) -> `subpackageMember/market/passes/index`
   - **Sections in order:**
     1. Points balance card (`balanceCard`, borderless `.cyDomainCard`)
     2. Platform membership entry card (`memberCard`, `CYColor.bgElevated`)
     3. Segmented tabs (`MPChipTabs`: shop / orders / gifts)
     4. Product card list (`PassProductCardView`, `.cyDomainCard`, adaptive `ViewThatFits` footer) / Order rows / Gift rows
   - **Components:** `.cyDomainScreen(.player)`, `MPChipTabs`, `.cyDomainCard(radius: CYRadius.lg)`, `ViewThatFits`, `MPCard`, `MPRow`, `PassPriceText`, `CYNight` artwork accents
   - **DEBUG Fixtures:** `t5-pass-market`, `t5-pass-market-error`

9. **Pass Product Detail & Gated Purchase** (`PassDetailView`, `WP07CommerceViews`) -> `subpackageMember/market/pass/index` and `subpackageMember/market/pass-order/index` (gated)
   - **Sections in order:**
     1. Ticket hero (`PassTicketHero`)
     2. Product facts card (`MPCard`: kind, city, validity, seats, user)
     3. Self vs Gift toggle, plus `GroupCheckoutPanel` (when `groupQuote != nil`) or checkout breakdown `MPCard` (`price`, `cash`, `points` with `note` reason when off)
     4. `PassActivatePanel` wrapped in `MPCard`
     5. Pinned `MPBottomBar` (`CYFooterBar`: loading / unavailable reason / group checkout link / `buyable` modes wrapped via `ViewThatFits` + `MPGatedNote` behind `MPCommerceGate`)
     6. `PassUnlockStepsView` overlay & `PassGiftReadySheet` (`.cyPlayerSheetGlass()`)
   - **Components:** `.cyPushedChrome(domain: .player)`, `MPBottomBar` (`CYFooterBar`), `MPCard`, `MPRow`, `MPDivider`, `GroupCheckoutPanel`, `PassActivatePanel`, `ViewThatFits`, `.cyPlayerSheetGlass()`
   - **DEBUG Fixtures:** `t5-pass-detail`, `t5-pass-detail-unavailable`

10. **Pass Gift Claim** (`PassGiftClaimView`) -> `subpackageMember/market/gift/index`
    - **Sections in order:**
      1. Animated gift / claimed / expired emblem (`Circle` with `CYColor.bgElevated` or glow)
      2. Status headline & reason copy (`failedReason` / claimed confirmation)
      3. Pinned claim / open-gifts CTA (`CYPillButton`)
    - **Components:** `.cyPushedChrome(domain: .player)`, `CYPillButton`, `CYColor.bgElevated`, `CYNight.glow`
    - **DEBUG Fixtures:** `t5-pass-gift`, `t5-pass-gift-expired`

11. **Pass Membership** (`PassMembershipView`) -> `subpackageMember/market/membership/index`
    - **Sections in order:**
      1. Membership status hero card (`card` with `.cyDomainCard` & `PassKeyEmblem`)
      2. Plan cards (`ViewThatFits` `HStack`/`VStack` layout, flat borderless `CYColor.bgElevated` when unselected, `CYColor.selection` highlight only when selected)
      3. Library entry link (`PassLibraryView`)
      4. Pinned purchase/renew action or gated note (`MPGatedNote`)
    - **Components:** `.cyPushedChrome(domain: .player)`, `.cyDomainCard`, `ViewThatFits`, `CYColor.bgElevated`, `CYColor.bgRaised`, `MPGatedNote`, `CYTypography.dataXL`, `.monospacedDigit()`
    - **DEBUG Fixtures:** `t5-membership`, `t5-membership-off`

12. **Pass Library** (`PassLibraryView`) -> `subpackageMember/market/library/index`
    - **Sections in order:**
      1. Kind filter chips (`MPChipTabs`: all / city / free)
      2. Empty state (`CYEmptyState`) or `PassLibraryCardView` cover cards
    - **Components:** `.cyPushedChrome(domain: .player)`, `MPChipTabs`, `CYEmptyState`, `CYCachedAsyncImage`, `PassLibraryCardView`
    - **DEBUG Fixtures:** `t5-library`, `t5-library-empty`

13. **Journey Seats Lobby** (`JourneySeatsView`) -> `subpackageJourney/pages/seats/index`
    - **Sections in order:**
      1. Header banner (`headName` / cover)
      2. Seat circles grid (host, invited, open slots with `CYColor.bgElevated` fill) & participant row
      3. Invited management list & informational mode tiles
      4. Pinned bottom bar (`MPBottomBar` / `CYFooterBar`) & `JourneyInviteSheet` (`.cyPlayerSheetGlass()`)
    - **Components:** `.cyPushedChrome(domain: .player)`, `MPCard`, `MPRow`, `MPBottomBar` (`CYFooterBar`), `.cyPlayerSheetGlass()`, `CYColor.bgElevated`, `.monospacedDigit()`
    - **DEBUG Fixtures:** `t5-seats`, `t5-seats-error`

14. **Journey Settle / Report** (`JourneySettleView`) -> `subpackageJourney/pages/settle/index`
    - **Sections in order:**
      1. Overview summary card (`CYColor.bgElevated`, score/nodes/elapsed tabular metrics)
      2. Rank board sheet/step (`JourneyRankBoardView`)
      3. Rating chips & multiline review card (`CYColor.bgRaised` / `CYColor.bgElevated`) + thanks overlay
      4. Share step (`JourneyShareCard`)
    - **Components:** `.cyPushedChrome(domain: .player)`, `CYColor.bgPage`, `CYColor.bgElevated`, `CYColor.bgRaised`, `CYPillButton`, `JourneyRankBoardView`, `CYNight` reward glow illustration, `.monospacedDigit()`
    - **DEBUG Fixtures:** `t5-settle`, `t5-settle-error`

## Modified Files

- `App/OrderCardComponents.swift`
- `App/E1CommerceComponents.swift`
- `App/MPParityKit.swift`
- `App/PublisherLifecycleViews.swift`
- `App/RegistrationSheetView.swift`
- `App/TicketWalletView.swift`
- `App/OrderLifecycleView.swift`
- `App/ProfileOrdersView.swift`
- `App/ProfileOrderFilterSection.swift`
- `App/ProfileOrderSourceDetailSections.swift`
- `App/OrderCenterEntryView.swift`
- `App/FreeExploreBundleLaunchView.swift`
- `App/PassMarketViews.swift`
- `App/PassMembershipViews.swift`
- `App/JourneyLandingViews.swift`
- `App/JourneyReportViews.swift`
- `App/DesignFixtures/DesignFixtureRegistry.swift`
- `App/DesignFixtures/DesignFixtureReleaseExclusionAudit.swift`
- `tools/check_design_lint.py` (removed cleared allowlist entries for `App/TicketWalletView.swift`, `App/E1CommerceComponents.swift`, `App/OrderLifecycleView.swift`)
- `docs/release/receipts/ui/h-t5.md`

## Per-File `xcrun swiftc -parse` Verification

```text
App/DesignFixtures/DesignFixtureRegistry.swift -> parse=0 debug_parse=0
App/DesignFixtures/DesignFixtureReleaseExclusionAudit.swift -> parse=0 debug_parse=0
App/E1CommerceComponents.swift -> parse=0 debug_parse=0
App/FreeExploreBundleLaunchView.swift -> parse=0 debug_parse=0
App/JourneyLandingViews.swift -> parse=0 debug_parse=0
App/JourneyReportViews.swift -> parse=0 debug_parse=0
App/MPParityKit.swift -> parse=0 debug_parse=0
App/OrderCardComponents.swift -> parse=0 debug_parse=0
App/OrderCenterEntryView.swift -> parse=0 debug_parse=0
App/OrderLifecycleView.swift -> parse=0 debug_parse=0
App/PassMarketViews.swift -> parse=0 debug_parse=0
App/PassMembershipViews.swift -> parse=0 debug_parse=0
App/ProfileOrderFilterSection.swift -> parse=0 debug_parse=0
App/ProfileOrderSourceDetailSections.swift -> parse=0 debug_parse=0
App/ProfileOrdersView.swift -> parse=0 debug_parse=0
App/PublisherLifecycleViews.swift -> parse=0 debug_parse=0
App/RegistrationSheetView.swift -> parse=0 debug_parse=0
App/TicketWalletView.swift -> parse=0 debug_parse=0
```

