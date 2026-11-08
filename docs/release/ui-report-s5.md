# UI-S5 report — pages owned by cloud/ui-12 .. cloud/ui-19 — NOT COMPILED

Lane S5 on `cursor/CA6`. Standard: `docs/release/ui-standard.md`. Presentation only. No Core, route, contract, or gate changes. `xcodebuild` was not run.

## Shared stubs
`CYBalanceHero`, `CYMoneyRow`, `CYSkeleton`, and `CYConfirmSheet` are not in this tree. Private stand-ins live in `App/ClubOwnerFundsView.swift`: `CYBalanceHeroLocal`, `CYMoneyRowLocal`, `CYSkeletonLocal`, `CYConfirmSheetLocal`. The unsuffixed names were not added.

The owner-funds section uses the hero, money rows, and skeleton. Unknown withdrawable and pending amounts render as an em dash. Contact is the one primary action; retry is secondary. The confirm sheet is the preview stand-in in that same file. Club owner funds has no destructive confirm, so the existing offer-withdrawal confirmation dialog was left in place.

## Other owned pages
Status colours that were still `.red` / `.orange` / `.green` / `.blue` on owned screens now use `CYColor.dangerText`, `warningText`, `successText`, or `infoText`. Missing capacity, friend-group position, series activity id, and desk anchor id render as an em dash. Project edit’s bottom bar uses `CYSpacing` instead of a raw 44pt height.

Wave-1 files were not edited: `ClubChannelMessagingView`, `ClubEventCalendarView`, `MerchantCoopCenterView`, `MerchantCustomerListParityViews`, `MerchantHomeView`, `MerchantNPCFieldEntry`, `MerchantPerkTemplatesView`, `MerchantReviewSummaryHeader`, `NativeChannelMessageActionSheet`, `NativeChannelReportSheet`, `NativeChannelTextComposer`.

Left as-is: image-processing `UIColor.white` fills, the group-code white plate behind a QR, authored colour values, and map viewport heights. Those are not chrome tokens.
