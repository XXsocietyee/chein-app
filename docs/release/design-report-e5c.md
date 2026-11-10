# Design report e5c: system polish (branch ui/e5)

Shots: `/Users/fanning/chengyin-refs/design-reports/e5c/` (batch 2, 16 shots) and `e5c-r1/` (batch 1, zh states). Contact sheets in `design-report-e5c-shots/`. Before/after (Pillow): `docs/release/design-report-e5c-before-after.png`.

## Benchmarks (Mobbin searches, iOS)
1. Empty/error/offline (5 searches): "empty state illustration with one button" - talabat https://mobbin.com/screens/be84c29b-7400-467d-b736-d722ca4d5414, Trainline https://mobbin.com/screens/4ae3a02a-7d4d-4fd2-a9b9-7e1b1f53dc89, Jomo https://mobbin.com/screens/f411397c-dd78-42b5-a0be-459254324774, PayPal https://mobbin.com/screens/760d6d29-b428-4028-80f7-bbfa7cd7e204; "no internet connection offline error screen" - Noom https://mobbin.com/screens/2419210e-0800-41b0-b0ce-d45c385858cc, Sesame https://mobbin.com/screens/2d85e6ae-5a90-44c0-9ceb-d0cff29fb561 (quiet inline offline banner), Opera https://mobbin.com/screens/af7f57a4-9493-4f22-bb2a-48bc94a93f3e. Borrowed: one object illustration, one-line title, one calm sentence, ONE pill action; offline as a quiet capsule strip over cached content, not an alert.
2. Permission priming (4 searches): "location permission request screen before system prompt" - TikTok https://mobbin.com/screens/328c5df0-872e-4a49-afbe-737d0d7628bc ("Not now" + primary), Neo Financial https://mobbin.com/screens/da9e8f86-9321-464f-998f-7a1925273d71 (art + benefit title + "Maybe later"), Cash App https://mobbin.com/screens/a83fa99d-5202-4250-898a-8ccb1745143d; camera: Lightyear https://mobbin.com/screens/b1dcf3c2-d916-4472-82c3-d1046498a348, Klarna https://mobbin.com/screens/e79dc9e0-830c-460d-bd79-1e1fc419ab4c (alternate path under the CTA). Borrowed: benefit-led title, one sentence, primary pinned at the bottom, free quiet decline.
3. Search home (4 searches): Neo Financial https://mobbin.com/screens/3760913d-5471-47ff-bd11-5d157ef7ad00 (recents + category tiles), talabat https://mobbin.com/screens/4d1a9321-88d9-4dff-8775-dcde29dcd9f1 (suggested chips), Fresha https://mobbin.com/screens/86a0b800-40fe-4cbe-a1b6-1355f84bd38d (recents with icon discs + Clear), LinkedIn https://mobbin.com/screens/0bb3e5af-46e1-449d-8513-3054ea3443b4; results tabs: Apple Books https://mobbin.com/screens/7d89078b-d431-4b9f-8b8d-c8df2d70ab07, ChatGPT https://mobbin.com/screens/bc9cf163-cafd-423b-917e-33fb054485f4.
4. Tab bar (1 search): "dark mode tab bar with five tabs selected state" - How We Feel https://mobbin.com/screens/d45755f7-165a-40a1-8ac0-b88d6da439c7, TikTok https://mobbin.com/screens/05d26d55-f1b0-4dc8-ae39-bf9289e74d84 (floating glass bar, one selected pill). Items 5 and 6 are spec/palette work (no new Mobbin cites beyond the above).

## What changed
- Kit `CYStateKit.swift`: `CYStateArt` (generated SwiftUI art, 12 kinds, hue per kind, never violet, floats unless Reduce Motion), `CYStateLayout`, `CYOfflineStrip`, `CYPermissionPriming` (location, camera, notifications-informational "no push", photos), `CYPermissionDeniedCard`. `CYEmptyState`, `CYErrorState`, `CYEmptyStateView`, `CYErrorStateView` now render the art (about 40 callers upgrade at once); `CYErrorState(offline:)` adds the offline variant.
- 6 lists: messages (auto), orders (`ProfileOrdersView`), favorites (topics + posts), notices (delivery log), search results (auto), my projects (`MyProjectEmptyView`). Shots: messages/orders/favorites/notices/projects empty, offline, error.
- Search home: recent-routes shelf (art tiles ordered by last use, stored locally), history rows with icon discs, capsule suggestion chips, category tiles on generated art with scrim; results keep type tabs (segmented, menu when tight).
- Nav: scroll-edge appearance is transparent (no hairline under a large title at the top), opaque + hairline once scrolled. `cyTabSelectionFeedback` and `CYCloseToolbarButton` added (adoption needs a one-line root change, see view-requests.md).
- Dark: player surface is #111111 (was #0A0A0B) so layers read #000 / #111 / #1C1C1E.
- Spec: `docs/release/app-icon-spec.md` (3 concepts + launch screen). No asset catalog exists, so no PNG was written.

## Contrast (dark, computed WCAG): secondary B7B7B7 on #000/#111/#1C1C1E = 10.5/9.4/8.5; tertiary 919191 = 6.7/6.0/5.4; placeholder 868686 on #1C1C1E = 4.67 (ok), on raised #2A2A2C = 3.93 (below 4.5, do not place text on raised). Kit text uses secondary/primary only.

## Self-score (D / I / Inc / V / Inn / S)
| Item | D | I | Inc | V | Inn | S | Note |
|---|---|---|---|---|---|---|---|
| 1 Empty/error/offline | 8 | 9 | 8 | 9 | 8 | 9 | art reads as a family; orders empty has no CTA (host supplies none in fixture) |
| 2 Permission priming | 8 | 9 | 8 | 8 | 8 | 9 | XL notifications screen shot and fixed (art shrinks, bar gets a ground); screens are NOT yet wired into the live permission flows (view request) so 7 for real adoption |
| 3 Search home | 8 | 8 | 8 | 8 | 8 | 9 | recent-routes title shows English default until the key is merged; category tiles shot with one category only |
| 4 Tab bar / nav | 8 | 8 | 8 | 8 | 7 | 9 | haptic and large-title edge cannot be seen in stills; haptic not wired (view request) |
| 5 Launch / icon | - | - | - | - | - | - | spec only, not implemented |
| 6 Dark polish | 8 | 8 | 9 | 8 | 7 | 9 | surface #111 applied; elevation uses surface step + hairline |
Under 8: none by scoring, but items 2 (adoption) and 4 (haptic) and 5 are NOT shipped end to end; they depend on Cursor-owned files.

## Known gaps / honest notes
- The EN shots show Chinese key-based copy: the app injects its own locale (zh) regardless of `-AppleLanguages`, so only verbatim kit copy and fixture titles were truly English. zh coverage is good; an EN-locale re-shoot needs the app language switch.
- Roam nearby sheet (`d2-roam`) rendered blank in the batch; not verified. Welcome and consent re-shots confirmed the e5b wordmark/consent card (zh); badges-en shows the progress ring and locked sockets.
- New string key `searchMap.routes.recent` is in `ui-strings-e5c.json` (Cursor merges). Kit defaults are bilingual verbatim (not catalog keys) for now.
- `ProfileSelfOrdersSection`, `ProfileSelfProjectsSection`, `ProfileReadScreen`, `AccountCollectionComponents` were left untouched (not UI-owned); requests filed.
