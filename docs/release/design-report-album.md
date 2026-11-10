# Design report: collection album (HERO, branch `ui/e2`)

Owner reference: "Access the collection album page" (stamp album, badge wall, passport/object cards as one collectible layer).
Motion system: `docs/release/motion-spec-album.md`. Kit: `App/DesignSystem/CYAlbum.swift`. Cloud-verified only (no local builds on this machine); see "Verification".

## Benchmarks (Mobbin, iOS)
| Pattern borrowed | Source |
|---|---|
| Locked badges as grey embossed silhouettes next to full-colour earned ones; the state is also written ("Not obtained") | Me+ Achievement Badges https://mobbin.com/screens/c4485d6d-f960-41f8-89df-4bb4d8f668c5 |
| Earned badges in colour, unearned fully desaturated, one grid for the whole year | Duolingo Monthly Badges https://mobbin.com/screens/021cfe8b-04e2-456b-821e-fe8a8ffb72ea |
| "Unlocked 0/30" count under the section title, locked photo tiles blurred with a lock chip | Withings Badges https://mobbin.com/screens/300ba4e5-c007-459c-a33c-745eb5b290de |
| Progress ring around the badge art; a number in the ring, caption below | Tripadvisor Your Achievements https://mobbin.com/screens/4e3f7f91-bf4a-4c57-b970-a9921eacfd41 |
| Dark celebration: confetti from above, one large medal, one value line | Runna Fastest 1K https://mobbin.com/screens/0e8a24e7-31ae-4657-bc16-6ace3abc70ea |
| Playful collectible objects you can poke ("Shake them!"), each with a time stamp | stoic. your badges https://mobbin.com/screens/7180e326-50b9-4800-a8f4-ea7f2cbb3a83 |

Not borrowed: per-badge progress rings (Tripadvisor). Our API has no per-badge progress, so only the collection total gets a ring.

## What changed (real views, presentation only, no Core edits)
| Surface | File | Change |
|---|---|---|
| Stamp album | `App/RoamStampViews.swift` | Cover: gold seal ring counting up to the stamp total next to the one visible title (`cyHeroScreen`). "Recently collected" album pager (≤ 6 pages, page-turn on the spine), each page a flip card (front art + caption, back number/date/caption). Grid tiles keep `CYCollectionGrid`, gain foil sheen, "New" pulse (≤ 7 days) and a shared-element zoom into the stamp detail. Existing total header, notice, errors, paging and camera entry untouched. |
| Badge wall | `App/ObjectBadgeWallParityViews.swift`, `App/ObjectBadgeViews.swift` | Header: count-up ring (unlocked / total, hidden when the medal read failed) beside the honest collected/locked tiles. Wall layout: "Lit up" showcase pager of unlocked badges (newest first, ≤ 8) with flip cards (medal / how it was earned). Tiles: foil sheen when unlocked, desaturated dashed silhouette when locked, "New" pulse until first opened, zoom into detail. |
| Badge detail | `App/ObjectBadgeViews.swift` | Stage is a flip card (medal / facts). First open of a badge unlocked in the last 7 days plays the unlock moment once (confetti, ring pulse, success haptic), remembered locally; later opens keep the quiet success tick. Share pill unchanged. |
| Object cards (passport) | `App/ObjectCardViews.swift` | List rows became `CYCollectionGrid` tiles (artwork plate, title, one state chip, place); foil cards catch the light, generating cards say so. Detail artwork is a flip card (front keeps the drag-to-rotate frames, back shows the facts). Zoom from tile to detail. |

## Fixtures (DEBUG, `App/DesignFixtures/AlbumFixtures.swift`)
`--design-fixture album-kit | album-stamps | album-stamps-empty | album-badges | album-badges-new | album-badges-locked | album-cards | album-unlock`.
States covered: unlocked (foil), locked (silhouette), new (pulse + first-open moment), unknown total (dash), empty, generating. Add `--uitesting-reduce-motion` for the fallbacks.

## ADA self-score (1–10)
| Page | Delight | Interaction | Inclusivity | Visuals | Innovation | Social impact | Note |
|---|---|---|---|---|---|---|---|
| Stamp album | 9 | 8 | 8 | 8 | 9 | 9 | one moment per flow (page turn, flip); honest counts |
| Badge wall | 9 | 8 | 8 | 8 | 9 | 9 | showcase + silhouettes; ring hidden when partial |
| Badge detail | 9 | 8 | 8 | 8 | 8 | 9 | unlock moment once, remembered locally |
| Object cards | 8 | 8 | 8 | 8 | 8 | 9 | foil follows the API's style flag |

Nothing under 8. Remaining risk, not a score: the pages' fixed heights (300/312 pt) under AX5 Dynamic Type clip long captions to two lines on the front; the back face wraps and the grid below shows the full text, so no information is lost.

## Verification
- `python3 tools/check_scaffold.py` and `python3 tools/check_design_lint.py` pass before every push.
- Xcode Cloud "Build - iOS" on each pushed commit (the first batch failed on one unknown member and was fixed in the second).
- Stills cannot show motion; judge with the fixtures above. No simulator run on this machine (builds forbidden by the coordinator).
