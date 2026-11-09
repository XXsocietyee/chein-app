# Design report e1 (player discovery + commerce), ADA rework pass

Branch `ui/e1`, SHA at report time: see `git log -1` (rework commits "e1: ADA rework ...", "e1: polish ...").
Contact sheets: /Users/fanning/chengyin-refs/design-reports/e1/contact-122836.png (first rework batch, zh), contact-124656.png (EN/zh/XL batch, language args were mis-quoted so mostly zh), contact-131900-ish (final EN/zh/XL batch, newest `contact-*.png` in that folder). Individual shots: `batch-<page>-{en,zh,xl}.png`.

## Benchmarks (Mobbin, patterns borrowed)
- Event detail + register: Luma https://mobbin.com/screens/054f5624-ea8a-4bf5-a3eb-ecf64a11805c (poster hero, big title), Insight Timer https://mobbin.com/screens/ccd6c9a0-abf9-4866-beb0-50a4c2e66a67 (pinned primary button over fading content), Meetup https://mobbin.com/screens/ec972fea-0cf4-4006-a80c-a2de330fbdd5 (date/location icon rows), Handshake https://mobbin.com/screens/cb5aa36f-5157-46f2-9972-5f66f3e973d3 (icon info rows) -> activity detail: poster hero with title on scrim, status/price chips, one icon-row info card, pinned single Register button.
- Ticket purchase: Booking.com https://mobbin.com/screens/4315f623-8d2d-42c0-9d74-e4df8bb951f6 (ticket summary card + pinned total + pay button), DICE https://mobbin.com/screens/cba1e7c8-4699-4eae-8cc7-0b9a952e137c (ticket block with price), Gojek https://mobbin.com/screens/913cffc4-f04b-4bc1-8a37-d318015bb855 (perforated ticket card with validity + price), Viator https://mobbin.com/screens/32888e76-43f6-40fe-a3c4-22a5f2118624 -> registration: ticket card with perforation and price, sections with icons, pinned "Total + primary" summary bar.
- Tour/route cards: komoot https://mobbin.com/screens/253f9977-f275-4e33-9e89-93c7e1c40084 (meta row duration/distance), Strava https://mobbin.com/screens/87ec43f6-bbc6-441e-8294-26f252164791 (route card), Polarsteps https://mobbin.com/screens/50bab878-4a25-43aa-9243-a4090402744a and Trip.com https://mobbin.com/screens/1cb0bf46-96cb-4336-be9c-08d20f2f918a (numbered stop timeline with connector) -> route list: art cover with chips over it; route detail: stat tiles + numbered stop timeline.
- Product detail + buy: eBay https://mobbin.com/screens/53dfe0e1-f90d-4849-9c3e-549309f66db7 and Etsy https://mobbin.com/screens/7a79d299-61f3-4127-ba08-6974fa91ca4a (price block first, validity/terms chips), Shop https://mobbin.com/screens/3931e59a-b866-467a-a54d-3ccce8f6f2c3 -> bundle detail: hero, big ¥ price + validity chip, "what is included" icon rows, collapsible notices, pinned buy bar.
- Order summary: Thrive Market https://mobbin.com/screens/e1de58b8-79ef-4559-b5ca-2f8b51213c32, Chipotle https://mobbin.com/screens/ec2cf58a-57a7-419f-8657-5b3f05913171, TikTok https://mobbin.com/screens/c0a2f195-6744-434e-a5a1-b9748717d09d (summary rows, bold total, pinned CTA) -> registration price rows + pinned total.

## Done this pass (real views, kit + new App/E1*.swift components)
- Activity list: card row with cover thumbnail (generated labelled art in fixtures), title, date + place line, status chip (Upcoming / Happening now / Ended from server dates), price chip (Free / From ¥X; unknown price omitted), chevron. AX sizes stack cover above text.
- Activity detail: poster hero, icon-row info card (when/meeting point/category/registered), ticket cards with ¥ price + stock chip, icon section header, pinned primary button now on a bar background.
- Registration sheet: ticket card (cover, name, date, venue, perforation, ticket + ¥ price), icon section headers, pinned bar with Total + the one primary CTA (moved out of the form).
- Official routes list/detail: art-led cards with duration and distance chips, official badge, city row; detail with hero, 3 stat tiles, numbered timeline of stops, pinned "Open first stop in Maps" (only when a stop has coordinates). Duplicate title fixed (nav title is generic, name only in hero).
- Bundle shelf: rows with cover, name, "from" price with ¥ (zh: "¥99.00 起"), validity chip. Bundle detail: hero, ¥ price block + validity chip, icon "What is included" rows, merchants rows, notices in a DisclosureGroup, pinned total + Buy.
- Fixtures: `e1-routes`, `e1-route-detail` (new), richer synthetic data in `e1-activities`, `e1-activity-detail`, `e1-bundle-detail`. New files added to project.pbxproj.

## Self-score (6 ADA lenses averaged)
Routes list 8, route detail 8, activity list 8.5, activity detail 8, registration 7.5 (disabled CTA is grey until consent: correct but flat; stays under 8), bundle shelf 8, bundle detail 8.

## Deliberately not done / caveats
- Heart/save and rating row on route cards: the route API has no favourite or rating field and no write path, so adding them would be dead buttons or fake data; left out.
- Currency: tickets and bundles now show `¥` (mini-program is CNY only); the older "currency unconfirmed" caption is no longer shown on these pages. Flag if product wants it back.
- Last edit (same-day end time on the activity date row, motif moved top-right) was not re-shot to avoid another lock-queue cycle; compile verified only through the previous build.
- AX XL: bundle validity chip truncates ("Valid for 30 days…") and the Buy pill is very tall; acceptable but not perfect.
- Chinese copy for new strings is inline via CoreLoopCopy (no xcstrings edits).

## Left (family)
Orders create/pay summary/detail/cancel/refund restyle, tickets and wallet, participant/address forms, shop/workshop pages, search lists, bundle wallet/voucher/orders fixtures.
