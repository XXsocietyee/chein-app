# Design spec D3: orders, tickets, wallet, coupons (player, dark)

Direction: Revolut-style on the mini-program information order. Player theme: black page, `#1C1C1E` cards, white
selected pill / white CTA, violet nowhere. Tabular numerals for every amount. Unknown amount = em dash, never 0.
No kit branch exists yet (`ui/kit` == `ui/merge`), so no new shared component is created: every new view is a private
type inside the screen file it serves (`Order…`, `Ticket…`) and uses only `CY*` tokens that already exist.
The `--design-fixture` registry does not exist yet either; the existing DEBUG fixtures are used (args below).

## Screens

### 1. Orders list (`ProfileOrdersView`, `ProfileOrderRow`, `ProfileOrderFilterSection`)
Reference: `player-e2e-20260927/035-player-orders.png`, source `scene-member-order-history/index.wxml` (D04 row card).
Fixture: `--uitesting-profile-order-filters` (and `--profile-order-filters-empty`).
```
 My orders                              (large title)
 ( All )( Pending )( Not started )( In progress )( Done )   pill filters, selected = white
 ┌──────────────────────────────────────┐
 │ Order no.  A2026…          [Non-refundable] status chip
 │ ─────────────────────────────────────│
 │ ┌──────┐ City orienteering  (mode tag)
 │ │cover │ Prefab Life · Station 1
 │ └──────┘ ◷ 09.27 00:00 – 10.04 23:59
 │          ⌖ Huangpu, People's Ave 100
 │ ─────────────────────────────────────│
 │ Paid  ¥0.00                [ View details ] (one white pill CTA)
 └──────────────────────────────────────┘
```
Stays: order number, status, mode tag, title, time range, place, paid amount, order of those. Filter chips unchanged.
Demoted: nothing removed. The row is still one NavigationLink; the "View details" pill is a visual label of that link
(the whole card is the control), so there is exactly one primary per card and no extra tap target.
Cover: `ProfileOrder` carries no image URL (Core is out of scope), so a placeholder tile (mode symbol on a raised surface)
is drawn; when a cover URL is added to Core, `QuestifyCardArtwork` slots into the same 88x88 frame.
States: loading/error/empty are owned by `ProfileReadScreen` (unchanged); filtered-empty keeps the existing block.
Unknown paid amount: em dash.

### 2. Order detail (`OrderLifecycleView`)
Reference: source order detail sections (summary, payment, timeline, refund, actions); Revolut hero.
Fixture: `--uitesting-order-lifecycle-fixture --uitesting-order-lifecycle-scenario paid|pending|refunding|expired|unknown`.
```
 Order                                   [⟳]
   (status chip)  Paid
   Prefab Life · Station 1               title
   explanation text
   ¥ 0.00                                 amount hero, data2XL tabular (— when unknown)
 ┌ Order ─────────────────────────────┐
 │ Order no.            A2026…        │  label/value group
 │ Ticket               Standard      │
 └────────────────────────────────────┘
 ┌ Payment ── label/value + caution
 ┌ Timeline ─ ● Created 10:00 │ ● Paid 10:01 │ ○ Verified   (vertical rail)
 ┌ Refund ── (only when present)
 [ Primary action ]  (white pill, only the first reviewable action)
 Secondary actions: quiet text rows
 > Pass preview (link row)
```
Stays: every section and field, order of sections, all accessibilityIdentifiers, offline note, reconsent button.
Demoted: toolbar refresh stays (system pull-to-refresh also exists); secondary reviewable actions move from full-width
grey buttons to quiet text rows (same buttons). The production caution is last, caption size.
States: loading skeleton (kept), login, issue, offline, attempt states unchanged.

### 3. Ticket wallet list (`TicketWalletView`, `TicketWalletRow`)
Reference: `036-player-tickets.png` (poster ticket) + `042-ticket-before-play.png`; list form follows the order card.
Fixture: `--uitesting-module ticketWallet` (+ `--uitesting-ticket-wallet-scenario empty|failure|partial|guest`).
Row: status chip, title, date, place, one white pill "action" strip replacing the tinted strip (still not a second
button: the card is the link). Team link stays as a quiet row at the end. Loading uses `CYSkeleton` instead of a spinner.
Empty/error/partial keep their `ContentUnavailableView` / issue views.

### 4. Ticket detail (`TicketWalletDetailView`)
Reference: `042-ticket-before-play.png`: centred heavy title, quiet sub line (status), large artwork card.
Header card: status chip + expiry, heavy title, poster tile, date/place rows. Play stays the single white pill CTA.
Registration info / entitlements / redemption notice keep their sections as label/value groups; the order lifecycle link
and team entry are quiet link rows (demoted from standalone sections to the end of the info group).

### 5. Coupons (`AccountCollectionCouponsView`, `AccountCollectionCouponRow`)
Reference: `037-player-coupons.png`, `056-coupons-player-recheck.png`: "All / To use / Used / Expired" pills, white selected;
error = title + sub + white "Retry" pill; empty = title + sub.
Fixture: `--uitesting-module accountCollections` (+ scenarios).
Filter pills: white selected (`CYColor.accent` is `#F8F8F8` in the player domain), others `bgElevated`.
Row: ticket-stub card, status chip, name, description, validity lines. Search stays (system searchable). Refresh stays.

### 6. Wallet home (`WalletCommerceHomeView`)
Reference: `impl-player-me/shots/pm05-earnings-1700ms-after.png` (centred label, huge tabular amount).
Fixture: `--wallet-commerce-fixture`.
Balance section becomes a hero (`CYBalanceHero`, label + `dataXL` amount); unknown / error keeps `WalletIssueView`;
the empty note stays. Link rows keep order and ids.

## Type / spacing
Page title = system large title; hero `CYTypography.data2XL` / `dataXL`; card radius `CYRadius.lg` (20) on `#1C1C1E`;
pills `CYRadius.pill`, 44pt min height; paddings `CYSpacing.lg`; all money `.monospacedDigit()` (CY numeric fonts).
Dynamic Type XL: card header rows switch to a vertical stack for accessibility sizes (`ViewThatFits`/`isAccessibilitySize`).
