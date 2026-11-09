# Design report e1 (player discovery + commerce) — PARTIAL

Branch `ui/e1`, based on ui/main 357154584 (compiling). TEMP compile fixes dropped (ui/main has them).
Contact sheets (EN/zh-Hans/XL): /Users/fanning/chengyin-refs/design-reports/e1/contact-101908.png (batch 1), contact-105245.png (batch 2). No mini-program reference PNGs for these pages exist in this tree, so no Pillow compares.

## Done and shot (dark, EN + zh-Hans)
Fixtures (`--design-fixture e1-*`): topics, topic-detail, activities, activity-detail, official (+detail/inbox via `--uitesting-official-destination`), registration(+soldout), participants(+empty), discovery, bundle-shelf(+empty/error), bundle-detail(+off).
Restyled: TopicBrowser, ActivityBrowser/Detail, ProfileParticipants (kit skeleton/empty states); BundleShelf (image cards), BundleDetail (price hero, pinned single primary CTA), BundleWallet (unknown count = em dash), BundleVoucher, BundleReviewList (kit states; not shot, no fixture); Official events search capsule.
Already kit-styled by D2/D3 (not touched): home, search, square, orders list/detail, tickets, coupons, wallet.

## Left
Registration/order create + pay summary polish, cancel/refund views, participant form detail, bundle wallet/voucher/orders/transfer fixtures and restyle, shop NPC pages, workshop commerce, reviews (merchant-styled M02), activity detail hero, XL/AX3 review of most pages.
Demoted controls: none removed.
