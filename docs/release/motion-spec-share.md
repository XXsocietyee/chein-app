# Share card composer: motion, haptics and privacy (e3 share hero)

Code: `App/DesignSystem/CYShareCard.swift` (artboard, three templates, silhouette, renderer), `App/DesignSystem/CYShareComposer.swift` (carousel, chips, ratio, swatches, caption), `App/DesignSystem/CYShareComposerState.swift` (state machine, prepare button, ready row, foil sheen, announcer), `App/RoamHistoryShareView.swift`, `App/RoamMedalShareView.swift`, `App/CatalogShareCardView.swift` (routes and activities). Entries: route detail toolbar (`officialRoute.share`), activity detail toolbar (`activity.share`), saved-walk detail (`roam.share.open`, `roam.medalShare.open.*`).

Fixtures (DEBUG): `--design-fixture e3-share-walk | e3-share-medal | e3-share-route | e3-share-route-card | e3-share-activity | e3-share-activity-card | e3-share-templates`.

## State machine (motion-system spec, subsystem B)
`CYShareComposerMachine` (value type in `@State`) replaces the former `image` / `renderFailed` / `sourceChanged` booleans in all three share surfaces:

```
editing --prepare--> rendering --rendered(img)--> ready | --rendered(nil)--> renderFailed
ready | done --styleChanged | captionChanged | invalidate--> editing   (image dropped, ready row fades out)
ready | done --export(photos | system | albumGuide)--> exporting --exportFinished(true)--> done | (false) --> ready
any --sourceChanged--> stale   (terminal until the page is dismissed)
```
Adaptations to the real code: `exporting` and `done` carry the bitmap so the ready row stays on screen while Photos or the system sheet is up; a late `rendered` after `editing` is ignored (the user changed something mid-render); the roam history page keeps its `renderedRecord` / `renderedIncludeRoute` / `renderedOwner` receipt as privacy gates beside the machine; `invalidate` covers privacy toggles and owner re-checks that drop the image without making the page stale. Photos results map through `RoamSharePhotoSaveModel.state.phase` (`.saved` = success; denied / restricted / unavailable / failed / sourceChanged = failure); the system sheet maps through `completionWithItemsHandler`, and a dismissed sheet without a completion falls back to `ready` in `onDismiss`.

Rendering runs in a `Task` after the press so `.rendering` commits before `ImageRenderer` blocks the main actor. `CYSharePrepareButton` shows a spinner only after 150 ms of rendering (a fast export never flashes one). `CYShareRenderBudget` times each 3x export against the 120 ms budget and logs an overrun in DEBUG. `readyTick` / `doneTick` make the `.impactLight` and `.success` haptics fire once per transition, and `CYShareAnnouncer` posts "Card ready" / "Saved to Photos" / "Shared" to VoiceOver.

## Principle
The preview is the export. One `CYShareCard` view is scaled for the carousel and rendered by `ImageRenderer` at 3x (1080×1920 story, 1080×1350 portrait, 1080×1080 square). The carousel is the live preview: style changes re-render SwiftUI, never a bitmap, until `prepare`. What the user approves on screen is byte-for-byte what leaves the device. The artboard is fixed, so it uses fixed type sizes on purpose; everything around it (hero title, chips, toggles, caption field, pills) is Dynamic Type.

## Flow
1. Hero title (`CYHeroHeader`, one visible title, bar title empty via `cyHeroScreen`) with the privacy sentence as its subtitle.
2. Live card carousel: three templates side by side, view-aligned paging, the chosen one marked with a check. Swiping or tapping a chip switches template.
3. Ratio segmented control (Story 9:16 / Portrait 4:5 / Square 1:1) and six background swatches (ink, ember, ocean, moss, sunset, gold; no violet, that stays on the selected tab).
4. Caption field, 80 characters, single line, counter.
5. Privacy toggles (caller-owned): place name, route sketch.
6. Primary action. `Prepare card` renders the PNG off the press frame; the "Card ready" row (exact image, one foil sheen) then appears with the export pills. Roam: `Save to Photos` (primary) and `system sheet` (secondary). Catalog: a system `ShareLink` with a `SharePreview`.

## Templates
| Template | Idea | Borrowed from |
|---|---|---|
| Poster | image-led: generated cover art, tint wash, bottom scrim, white route line, large heavy title, stat row | adidas Running "Create image" (image, stats strip under the title) |
| Ticket | stats-led: paper stub on a tinted ground, dashed perforation with notches, big rounded numbers | Garmin Connect share card (card pager with framed numbers) |
| Minimal | typographic: solid tint ground, serif title, large silhouette, stat list with hairlines | Runna share card (route line on a quiet ground) |

Medal content swaps the silhouette for a `CYFoilMedal` built on generated art; activity content draws a single pin only when the place toggle is on.

## Motion
| Piece | Spec | Reduce Motion |
|---|---|---|
| Carousel paging | `scrollTargetBehavior(.viewAligned)`, neighbours `scaleEffect 0.92` + opacity 0.65 via `scrollTransition(.interactive)` | no scale, opacity only |
| Template switch from a chip | `CYMotion.standard` spring (0.30 / 0.85) scrolls the carousel; check mark cross-fades | `CYMotion.reduced` 0.18 s cross-fade, position jumps |
| Ratio change | artboard frame (640 / 450 / 360 pt scaled) and siblings reflow with `CYMotion.standard` | 0.18 s cross-fade |
| Tint change | card ground cross-fades `easeInOut` 0.18 s (`quick`) | same |
| Prepare | `.rendering` state; spinner only after 150 ms | same |
| Ready row foil sheen | one diagonal `blendMode(.screen)` sweep, 1.1 s easeOut, never loops (`CYFoilSheen`) | static highlight |
| Swatch select | selected ring, 1.08 scale with `CYMotion.standard` | ring only |
| Card ready row / share pill | `cyEntrance` (0.9 scale + fade + rise); state switch animates with `CYMotion.standard` | appears at once / 0.18 s cross-fade |
| Toast | `cyToast` bottom capsule, slide + fade, 2.5 s | fade only (kit) |
| Keyboard | `scrollDismissesKeyboard(.interactively)` | same |
Durations stay within 0.18 to 0.35 s; navigation and the ShareLink never wait for an animation. All gates go through `@QuestifyReduceMotion` (system, in-app setting, or `--uitesting-reduce-motion`).

## Haptics (`CYHaptics`)
| Case | When |
|---|---|
| `.selection` | template, ratio or tint changes |
| `.impactLight` | `ready` entered (`readyTick`, all three surfaces); ShareLink tapped (catalog) |
| `.success` | `done` entered (`doneTick`): Photos save completed (toast "Saved to Photos"), system sheet reported a completed activity (toast "Shared") |
One haptic per user-visible outcome. `ShareLink` exposes no completion callback, so the catalog composer confirms the tap, not the outcome; the roam surfaces use `UIActivityViewController.completionWithItemsHandler` and do confirm the outcome.

## Privacy
- Place name is opt-in (`roam.share.includePlace`, `share.card.includePlace`), default off. Off or unknown renders an em dash, never a zero or a guess.
- Roam route sketch is opt-in and uses `RoamShareRoutePrivacy.sketch` (10% of the polyline clipped at each end). Catalog route silhouettes are the relative shape of the stops only; coordinates, addresses and node names never enter the image. Activity location is a single pin, drawn only with the place toggle on.
- No link, token, account or server identifier is written into the card. Roam export keeps the existing owner and record re-checks before Photos access and before the system sheet (`RoamHistorySystemShareRequest`, `RoamMedalShareAuthority`).

## Accessibility
- Card previews are one VoiceOver element whose label is the full card text (eyebrow, title, date, place, every stat with its label, caption). Selected card, chip and swatch carry `.isSelected`.
- Chips and swatches are 44pt targets; chips stack vertically at accessibility sizes.
- Ratio uses a native segmented control; the caption field has a visible counter hidden from VoiceOver (count is announced through the field).
- `UIAccessibility` announcements on `ready` ("Card ready") and `done` ("Saved to Photos" / "Shared").

## Spec items adapted, not adopted literally
- `ShareComposerModel` as an `@Observable` class: implemented as a value-type `CYShareComposerMachine` in `@State`, matching the surrounding `@State` style and keeping `Equatable` for `.animation(value:)`.
- Spring `hero` for the carousel snap: view-aligned paging snaps with the system scroll spring, which SwiftUI does not expose. `CYMotion.hero` (0.55 / 0.78) and `Duration.slow` (0.60) exist as tokens.
- Foil sheen 1.1 s exceeds the 0.60 s ceiling by the spec's own acceptance check 7; it is a one-shot decoration, not a state change.

## Benchmarks (Mobbin, iOS)
- pliability share "Activity": card pager over a dark ground, swatch row, single share button: https://mobbin.com/screens/056b480b-e560-468d-ba84-a01ba2e18055
- adidas Running "Create image": Stories / Square toggle, image with a stats strip, template tiles: https://mobbin.com/screens/1a274ff9-d2d2-4e05-8bcc-90d46aaea784
- Garmin Connect "Share Activity": framed card pager, Share / Save / Copy row: https://mobbin.com/screens/405bad9a-3513-4926-b085-1d143e607388
- Runna route card with "Tap card to edit" and a Save to device bar: https://mobbin.com/screens/0d8088e6-2e9f-4bc7-8cbe-7ab42a1b9e4d
- Gentler Streak share: map card, background choice tiles, Cancel / Share: https://mobbin.com/screens/af890a31-6cbb-43c3-8c38-f88ad2673d2e
- Brilliant streak share: "Saved successfully" toast over the card: https://mobbin.com/screens/82d868ed-7158-496e-b24c-74eb38ea82ba

## Self-score (ADA lenses, 1 to 10)
| Page | Delight | Interaction | Inclusivity | Visuals | Innovation | Social | Notes |
|---|---|---|---|---|---|---|---|
| Walk share composer | 9 | 8 | 8 | 9 | 8 | 9 | channel picker is still a menu row; kept for parity and UI tests |
| Medal share composer | 9 | 8 | 8 | 9 | 8 | 9 | |
| Route / activity share | 8 | 9 | 8 | 9 | 8 | 9 | ShareLink confirms the tap only (platform limit) |

## Verification
Cloud build only for this batch (no local simulator run). Spec acceptance 9 (preview equals export at 3x for each template × ratio × tint, export within 120 ms, ready row enters once with `.impactLight`) is wired but not yet measured on a device; `CYShareRenderBudget` prints an overrun in DEBUG. Stills cannot show motion; use the fixtures above with and without `--uitesting-reduce-motion`. Unit tests that pin the export gates (`RoamHistorySystemShareSourceTests`, `RoamMedalSystemShareSourceTests`, `RoamShareNativeLifetimeTests`) keep their identifiers: `roam.share.prepare`, `roam.share.system`, `roam.medalShare.prepare`, `roam.medalShare.preview`, `roam.medalShare.system`, `roam.medalShare.sourceChanged`.
