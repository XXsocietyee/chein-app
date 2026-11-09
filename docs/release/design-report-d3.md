# Design report D3: orders, tickets, wallet, coupons (player, dark)

Shots (dark, accessibility-XL, zh-Hans) in /Users/fanning/chengyin-refs/design-reports/d3/:
order detail shot-221525, orders list shot-223522, ticket detail shot-223917, coupons shot-224016, wallet fixture shot-224114.
Compare images: compare-orders-list / compare-tickets / compare-coupons / compare-order-detail (reference left, ours right; ticket and order-detail references are the closest available, not exact).

Fixtures (DEBUG, App/DesignFixtures/OrdersWalletFixtures.swift, via registry): orders-list, orders-empty, order-detail (scenario via existing --uitesting-order-lifecycle-scenario), ticket-list, ticket-detail, coupons, wallet.

## Done
Shared card/pill/chip/amount-hero/value-row pieces in App/OrderCardComponents.swift; orders list rows (status chip, cover tile, one white "view details" pill), pill filters (white selected), order detail amount hero + label/value groups, ticket list/detail cards, coupon rows and pills. Strings in docs/release/ui-strings-d3.json. No logic changes; identifiers kept.

## Demoted
Secondary order actions: grey buttons to quiet text rows (same buttons). Ticket order link / team entry: quiet link rows. Nothing removed.

## Checklist
1 order kept; 2 one primary per screen/card; 3 <=3 other controls; 4 dark; 5 no violet; 6 kit tokens (CY*), but OrderCardComponents is D3-local, not folded into ui/kit components; 7 loading skeleton/empty/error kept from existing screens; 8 XL: orders/coupons/ticket pass (filter rows scroll horizontally); 9 zh verified, EN not re-shot; 10 builds 0 errors.

## Open issues
- Wallet home hero (CYBalanceHero) NOT done: WalletCommerceViews only has a small edit; the "wallet" fixture is the existing nav-list host, not the home screen.
- Cover image is a placeholder tile (ProfileOrder has no URL).
- Orders-list fixture host shows a pre-existing debug inset that overlaps content at XL (fixture artifact, not product UI).
- Order-detail timeline/refund sections and ticket detail lower sections were not screenshotted; EN and light not shot.

## Round 2 (coordinator review)
- Order detail: separator inset unified, title one step smaller (amount is focal), primary action pinned at the bottom (first reviewable action; secondary actions stay as quiet outlined rows in the Actions section). Below-fold view: shot-230421 (fixture order-detail-full, scaled), compare-order-detail-fold.png.
- Wallet home (WalletCommerceHomeView): CYBalanceHero balance, 4 circular quick actions (Assets, Income, Points, Withdrawal records), funds stages, then CYListRow cards with leading icon (Analysis, Invites, Mall, Withdrawal support = demoted from the main list). Gates and destinations unchanged. shot-225943, compare-wallet.png (vs pm05-earnings).
- Fixture host: Sign out moved into an overflow menu; fixture label is a small footer. These exist only in the DEBUG fixture (the real home has no sign-out).
- Open: row meta lines omitted (no existing localisation keys; xcstrings not editable); the hero shows "128.5 —" because currency is unknown in the synthetic data (existing formatter behaviour); EN/light still not shot.
