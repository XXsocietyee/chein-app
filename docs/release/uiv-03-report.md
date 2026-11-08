# UIV-03 report: orders / tickets / coupons (NOT COMPILED)
Refs: mini 035-player-orders, 036-player-tickets, 037-player-coupons, 042-ticket-before-play (chengyin docs/evidence/player-e2e-20260927).

## Files changed
- App/OrderLifecycleView.swift
- App/TicketWalletDetailView.swift
- App/AccountCollectionCouponsView.swift
New string keys: none (no ui-strings-uiv-03.json needed).

## Diffs fixed
- Raw system fonts/`.secondary` replaced by CYTypography / CYColor tokens in all three files.
- Order detail: loading shows CYSkeleton (was spinner); amount uses numericBody; reviewable actions render as one white primary CTA (first action) + secondary buttons (50pt, radius 12, press 0.97); review sheet confirm uses `.cyPrimary(fullWidth:)` instead of questifyPrimary.
- Coupons: menu Picker replaced by horizontal filter pills (selected = white fill `CYColor.accent`, others bgElevated), per mini 037; skeleton loading; card title/description tokens.
- Ticket detail: "play" is now the single white full-width CTA (mini 042 before-play); icon no longer accent-coloured (violet/accent outside tab); skeleton loading. All accessibilityIdentifiers unchanged.

## Diffs left
- Order summary/payment/timeline are still insetGrouped List sections (system radius ~10) rather than 16-radius cards with order-number header + thumbnail (mini 035); needs a restructure with order data (cover/location) that is not in OrderLifecycleDetail. UIV-TODO.
- Orders list screen and CYMoneyRow rows not present in these files (list lives elsewhere: TicketWalletView.swift, WalletCommerceViews.swift); not touched.
- Ticket card full-bleed poster layout (mini 036) not done.
- Coupon error state not converted to CYErrorStateView (AccountCollectionIssueView is shared).

## Compile risks
- `CYOrderActionButtonStyle` private in OrderLifecycleView; uses CYColor.actionSecondary/textOnAccent/accent, CYRadius.sm (all exist).
- `.listRowBackground` on Section in summary(); `reviewable.first` compares OrderLifecycleAction (Equatable).
- CYSkeleton is an unlabelled-height view inside List row.
