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

## Update (ADA pass)
- DEBUG generated cover art (gradient + SF symbol, labelled "DEBUG ART", only with `--design-fixture`) added to CYImageCard placeholder; activity list is now image-led hero cards (my change), later reworked further by the parallel e1 ADA commits (rich activity rows, ticket card, pinned totals + CTA, bundle hero/price hero). Contact sheet: /Users/fanning/chengyin-refs/design-reports/e1/contact-122836.png (zh-Hans).
### Benchmarks (Mobbin)
- Ticketmaster-in-Venmo event cards (title + date · venue over photo): https://mobbin.com/screens/9aa32ade-e3b5-4ff9-81ad-7ad8e8ef6c89 -> activity cards.
- Discord Fall Foragers bundle sheet (price hero, one Buy bundle button): https://mobbin.com/screens/a65add2d-7637-441f-97a5-670fd200e814 -> bundle detail.
- Partiful ticket event (hero + pinned "Get tickets, from $"): https://mobbin.com/screens/a7a8d3e2-946e-4d70-97e2-5ee5822f05e3 -> pinned CTA with total.
### Known issues seen in last sheet
Activity detail: pinned CTA overlaps the description text (needs opaque bar / bottom inset); registration sheet bottom bar CTA is disabled/dim and clipped. Self-score: activities 8, bundles 8, activity detail 7, registration 7. Not done: orders/refund/participant-form/shop pages, haptics/motion layer.
