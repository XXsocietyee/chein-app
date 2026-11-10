# Design report e1 (player discovery + commerce), ADA rework pass

Branch `ui/e1`, SHA at report time: see `git log -1` (rework commits "e1: ADA rework ...", "e1: polish ...").
Contact sheets: /Users/fanning/chengyin-refs/design-reports/e1/contact-122836.png (first rework batch, zh), contact-124656.png (EN/zh/XL batch, language args were mis-quoted so mostly zh), contact-132127.png (final EN/zh/XL batch). Individual shots: `batch-<page>-{en,zh,xl}.png`.

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

## Third pass (orders, tickets, forms, search)
Contact sheets: /Users/fanning/chengyin-refs/design-reports/e1/contact-141057.png (16 shots EN/zh/XL) and the follow-up rework batch (search rows, review sheet, registration XL). Earlier first-pass sheet contact-134958.png had a persisted-language mix (shots 1-8 were zh); the rework batch passes `-AppleLanguages '(en)'` explicitly.

### Benchmarks (Mobbin, new this pass)
- Order history list: Talabat https://mobbin.com/screens/dc389c20-f77b-4bb3-9dd8-ae52517fe5b2 (status chip + date on card top, order id, "View details" link + one pill), Swiggy https://mobbin.com/screens/06534016-d854-4961-bd02-10cab55d92f7 (segmented filter, state colour + icon), Wolt https://mobbin.com/screens/1571d997-30f5-4d0f-b371-91e0fb45358f (logo tile, status line with time, total) -> orders list keeps pill filters, art cover tile (generated art in fixtures), status chip, tabular total.
- Order detail / tracking: Talabat tracking sheet https://mobbin.com/screens/06aced2d-ab5a-4169-b943-823630279351 (vertical timeline, filled dot for done), Swiggy https://mobbin.com/screens/4f00d41c-8ce4-46aa-b7af-42184c6847a7 (item rows, bill total), ZARA https://mobbin.com/screens/d1df2138-5ed6-4503-a009-0471cc8bc2b9 (number, date, quiet sections) -> order summary gets an art tile beside the title; existing timeline kept.
- Ticket wallet / QR: Phantom https://mobbin.com/screens/4b9db92f-4966-4eb3-b58f-6f95d2e5fbf0 (dark QR card, one primary), Fuse https://mobbin.com/screens/6d23b320-a44f-4212-8e76-a82214143156 (white code tile on rounded card), Gojek ticket (first pass) -> ticket card: art band with title on scrim, info rows, dashed perforation with side notches, stub with "Show at the venue" (white tile + qrcode symbol, no fake code), checked-in / cancelled / expired stub states.
- Checkout summary: Wolt https://mobbin.com/screens/7e971f96-7130-4cb4-8cf9-3f607d5b5ee3 and Swiggy https://mobbin.com/screens/515414a4-8186-4bc0-863c-e5a0bbb7b8f4 (pinned total + pay button, reason/policy text), Talabat https://mobbin.com/screens/0bb94259-0bac-45cd-b573-854318be9d66 -> registration bar: Total + full-strength primary, one-line reason under it while blocked.
- Address / participant form: Wealthfront https://mobbin.com/screens/44c10c97-3721-40e0-8dfd-9bc49ce5c955 (labelled fields, pinned Save), Talabat https://mobbin.com/screens/c1f994cb-c09b-4397-b911-0cdbaaabc809 (grouped fields, label small above value), Swiggy https://mobbin.com/screens/6e85373c-2a46-4195-99ca-77057bb0bd4a -> participant form: icon labels above fields; list rows with initial avatar, name, phone, purpose line; pinned add button.

### Done
- Fixes first: registration CTA is no longer a grey slab while consent is missing: it keeps the white primary look, taps give a warning haptic and do nothing, and a one-line reason (consent / participant details / sold out / closed / checking price) sits under it; VoiceOver hint carries the reason. AX bundle validity is now a wrapping label (no truncation), buy bar and registration bar cap at Accessibility 1 so they no longer eat the screen, bundle hero title wraps with scale-down.
- Orders: art cover tile (OrderCoverTile now uses E1CoverArt: generated art in fixtures, neutral gradient in production), order detail summary with art tile, calmer cancel/refund/pay confirm sheet (icon, question title, refund caution, full-width destructive pill; detents unchanged), fixture `--design-auto-review` opens it.
- Tickets: new App/E1TicketCard.swift (perforated ticket, show-at-venue stub), ticket list rows use art tiles.
- Forms: participant rows (avatar, name, phone, purpose), labelled form fields; pinned CTA and bottom inset were already in place.
- Search: result kind tabs are now scrolling pills with counts (selection haptic), result rows are compact art-thumbnail rows with type chip, title, detail, tags and chevron.

### Self-score (6 ADA lenses)
Orders list 8, order detail 8, cancel/refund sheet 8, ticket detail 8.5, ticket wallet list 8, participant list/form 8, registration 8, global search results 8, bundle detail at XL 8. None under 8 after rework; the 8.0 pages are 8 rather than 9 because there are no real photos in fixtures and the one memorable moment is limited to the checked-in seal bounce.

### Last verified shots
Rework batch /Users/fanning/chengyin-refs/design-reports/e1/contact-143510.png (search EN/zh/XL, review sheet EN/zh, registration XL). The review sheet showed its confirm button below the fold at the medium detent, so detents were changed to large only after that shot (one-line change, built but not re-shot).

### Not done (honest list)
- Shop pages: ShopNPCView is the d2 NPC chat (d2-npc). WorkshopCommerceView needs a live WorkshopCommerceController and has no offline fixture; not restyled, no screenshot possible without logic changes.
- Map search list: owned by d6 (d6-search); not touched.
- Price breakdown on order detail: the order read model has only one payable amount, so no itemised rows were invented.
- QR: the stub shows a QR symbol, never a code; real verification stays with venue staff (the model has no code field).
- Debug fixture overlay ("Synthetic fixture · debug only") overlaps the title of orders-list at XL (fixture artifact only).

## Fourth pass: ticket holder (hero, code-only, cloud-verified)
Spec: `docs/release/motion-spec-tickets.md`. Kit: `App/DesignSystem/CYTicketPass.swift`. Fixtures: `e1-ticket-holder` (wallet stack), `e1-ticket-holder-valid | -pending | -used | -expired` (detail pass per ribbon state), `e1-ticket-holder-present` (present mode, honest staff tile). No local build or shots this pass (cloud build only); judge from the fixtures on device.

### Benchmarks (Mobbin, patterns borrowed)
- Luma ticket QR sheet https://mobbin.com/screens/fd60dbd4-6f2f-43e8-a2a8-dbf6954b3f59 (black backdrop, one white code tile, title small at top, X to close) -> present mode layout.
- Fly Delta boarding pass https://mobbin.com/screens/8eddb26c-f76b-4aff-ac16-12e734aa78fe (code on the pass itself, header band, big digits for the thing staff read) -> registration number in display type when no code factory exists.
- Fresha vouchers https://mobbin.com/screens/69616e9f-0d13-4ce1-961b-6e5201ec6231 (dark gradient passes, side notches, stacked in a list) -> wallet rows as notched passes with cover art and two sleeves behind.
- Trainline ticket https://mobbin.com/screens/57e53ad4-d677-47a4-a8b2-6ad795714605 (tear line separating the header from the details) -> perforation holes (real even-odd cut-outs) between art band and stub.
- X Money card https://mobbin.com/screens/924e3b0f-d877-45a2-8725-871c0c02addb (card stack peeking, light streaks on the material) -> stack depth and the scroll-driven light band.

### Done (real views)
- Wallet rows (`TicketWalletView`): notched + perforated pass shape, generated cover art (no grey gradient), corner status ribbon (valid / awaiting payment / verified / expired / cancelled / unknown; flat chip at AX sizes), stack sleeves, light band that moves with the scroll, first-screen stagger, iOS 18 zoom into the detail. Row identifiers unchanged (`ticketWallet.row.<id>`, pending-order button, schedule-sync and status-hint ids).
- Detail pass (`E1TicketCard`): same shape family at card scale, ribbon, hold-and-drag tilt with a moving specular highlight, tap sheen, layered shadows, retired passes sit back at 0.74. No fixed font sizes left (glyphs via `@ScaledMetric`); the file and `TicketWalletView.swift` are now clean in the design lint and their allowlist entries were removed.
- Present mode (`TicketPassPresentView`, full-screen cover zoomed from the pass): brightness to 100 % with restore on close / background, pass summary, real `VerificationCodeView` when the host injects the factory, otherwise the registration number in large type with the staff copy; code tile lands with the reveal (fade + scale + blur clear + one sheen) and a success tick. `Present pass` is the only primary on the detail; play start drops to the outlined style while it is shown.
- `VerificationCodeView`: the real QR tile uses the same `cyCodeReveal()` everywhere it appears (play entry, order pass).
- Honesty kept: no fake QR anywhere; the stub copy still says staff verify; the UI test expectation that the fixture detail never offers a code button holds (fixture ticket 901 is verified, so no Present button).

### Self-score (6 ADA lenses)
Wallet 8.5 (delight: stack + band + ribbon; interaction: native push, zoom; inclusivity: chip fallback, ids kept), detail pass 8.5 (tilt + sheen are the memorable moment, one primary), present mode 8 (the honest tile without a factory is plain by design; with the real code it is a 9). Nothing under 8.

### Not done (honest list)
- No stills this pass: code-only task, verified by the cloud build. Fixture names above are the review path.
- The "one visible title" rule: the detail keeps the inline `Ticket details` nav title because `TicketWalletFlowTests` pins `navigationBars["Ticket details"]`; the card title is the only large title.
- Tilt in the wallet rows was left out on purpose: the rows are NavigationLinks and a hold-then-drag there would fight the tap and the list scroll; the hero tilt lives on the detail pass.
- A DEBUG QR in the present fixture would need a `RuntimeDependencyContext` and a stub issuer; the fixture shows the staff tile instead.
