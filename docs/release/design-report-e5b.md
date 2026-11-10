# Design report e5b: signature moments (branch ui/e5)

Owner target: Apple Design Award. Scope: welcome, home, roam, check-in/stamp/badge moments, club join, Me header.
Shots: `/Users/fanning/chengyin-refs/design-reports/e5b/` (one design-batch.sh run, EN + zh, XL for 4 screens).

## Benchmarks (Mobbin, iOS)
| Screen | Mobbin | Borrowed |
|---|---|---|
| Welcome | Viator onboarding https://mobbin.com/flows/bd0a2e3b-c3d4-4485-a20f-63e93973a5d6 | rounded photo cards as the hero, one filled CTA + one quiet secondary, consent sentence sitting directly above the CTA |
| Welcome | Mindtrip onboarding https://mobbin.com/flows/fa72a3aa-321a-46c0-a36c-89cf87f9127c | big layered-art hero over a plain title block, Next / Skip hierarchy (our guest path is the quiet text button) |
| Welcome | TikTok https://mobbin.com/screens/1fec5565-a22f-4dcc-8c02-8a3bf5a401ae, Abode https://mobbin.com/screens/3902705e-8f17-4ed5-81b9-8abe7f3eaa45 | single illustration, heavy headline, terms line right above the one primary button |
| Welcome | Wanderlog https://mobbin.com/flows/43df4d6b-29ef-484e-98bc-2164e5c193b7 | calm gradient + short copy, no skip trap |
| Home | Mindtrip https://mobbin.com/screens/81aeca17-1270-4f96-9737-1286923daf91 | photo-led rounded cards, small section titles, text over bottom scrim |
| Home | Polarsteps https://mobbin.com/screens/fe2d61dd-9505-424b-ac6a-f4d1efeb0c7f | hero card with the next card peeking, big place name over photo |
| Home | Expedia https://mobbin.com/screens/a08d2a97-d5e7-47f7-afbd-ba604019ab93, Agoda https://mobbin.com/screens/e0f22d65-3216-4518-a395-446842138d5e | carousel peek, horizontal shelves with "view more" |
| Roam | Zesty https://mobbin.com/screens/74ea45ee-cf53-4ca3-b8a0-bc9d0894de26, Pangea https://mobbin.com/screens/35d864c0-77f9-492e-8ffb-595593434807, Instagram map https://mobbin.com/screens/acd2d60c-9bff-473b-9617-3da9ff41a19e | full-bleed map, two small floating circular controls, grabber sheet with detents holding the list, one dominant action |
| Moments | StubHub https://mobbin.com/screens/c49485da-9605-4f1c-9099-2e42f2b135e6, Flo https://mobbin.com/screens/a1592b93-23d5-4a5f-baf2-3066dea8775d, Withings https://mobbin.com/screens/c52f7e0f-41e5-4e12-96d9-84b1b420f7f9 | confetti around one centred mark, short title + one sentence, one full-width Done/Close |
| Badges | Lyft https://mobbin.com/screens/db3b8807-fadc-4d58-98fd-88f415da4877, Duolingo https://mobbin.com/screens/021cfe8b-04e2-456b-821e-fe8a8ffb72ea, Me+ https://mobbin.com/screens/c4485d6d-f960-41f8-89df-4bb4d8f668c5, Withings https://mobbin.com/screens/300ba4e5-c007-459c-a33c-745eb5b290de | 2-3 column grid of round/seal medals, locked = desaturated socket + lock, name under, state line |
| Club join | Garmin https://mobbin.com/flows/e3e88193-56de-4cf3-a827-08166ddb21fa, Ulta https://mobbin.com/flows/8433f217-07ee-455b-8012-11cfab4ef47a | group identity first, Join as the one pill, confirmation then "you have joined" |
| Me header | Mimo https://mobbin.com/screens/2cb93321-7a3b-4673-9791-64b9708996e5, Alta https://mobbin.com/screens/cdff3d3f-7cb3-4145-a2f0-6588d77d588d, Discord https://mobbin.com/screens/70373c83-125c-4093-8868-e8f59ba35dd8 | big avatar with ring, stat tiles row, quick-action tiles |

## What changed
Kit (new): `CYSignature.swift` (generated cover art, press styles, GO ring pulse, staggered entrance, light confetti), `CYCollectible.swift` (badge medal locked/unlocked, tile, celebration moment, stamp slam).
1. Welcome (`WelcomeView`, `UsageConsentGateView`): three generated place cards fan out of a stack, drift, a seal stamps the top card; one primary pill with spring + medium haptic; guest path stays the quiet text button; consent gets a shield mark that flips to a check, selection haptic on the toggle, success haptic on agree.
2. Home: `CYHeroBanner` is a peeking pager with scale/dim of neighbours, parallax cover and selection haptic; shelf and hero cards fall back to generated art (DEBUG label) instead of grey boxes; continue-exploring is a photo-led card; search pill press feel; pull to refresh was already native.
3. Roam: `CYGoPressStyle` (spring scale-down, heavy impact on touch-down, ring burst on release, idle breathing ring) on the real GO link and the kit button; nearby rows lead with a 60pt art thumbnail; map chrome and detent sheet unchanged (already 3 controls).
4. Moments: `CYCelebrationMoment` (badge / stamp / check-in / club), stamp slam on the created-stamp result, badge receipt with medal + confetti, badge wall tiles (real `ObjectBadgeWallBadgeLabel`) with locked sockets.
5. Club join and Me: `ClubMemberWelcomeSheet` is a join moment (medal, confetti, success haptic, three steps card, one primary); `MemberIdentityCardSection` has 72pt ringed avatar, level capsule, three stat tiles and quick-action tiles (tickets, balance, dash when unknown).
Reduce Motion: every animation is gated; confetti is not drawn, haptics remain. All identifiers and string keys kept; no new string keys (fixtures use verbatim synthetic copy).

## Evidence
Batch run (build 0 errors): welcome en/zh/XL, consent zh, home en/zh/XL, roam en/zh, GO, unlock en/zh, stamp, check-in zh, badge wall en/zh/XL, join en/zh, me en/zh/XL. A second short batch (home, me, welcome XL) verified the fixes below. Before/after contact sheet (Pillow): `docs/release/design-report-e5b-before-after.png` (also `/Users/fanning/chengyin-refs/design-reports/e5b/before-after.png`). "Before" = the d2/d4 shots of the same fixtures; after = this branch.
Fixed after first review: Welcome nav title removed (CHENGYIN / 城瘾 wordmark instead); hero banner collapsed to a sliver inside the List row (height now fixed by an aspect-ratio box; slides carry title copy on art); Me header overflowed at AX sizes (rows become columns).

## Self-score (1-10): delight / interaction / inclusivity / visuals / innovation / social
| Screen | D | I | Inc | V | Inn | S | Note |
|---|---|---|---|---|---|---|---|
| Welcome + consent | 9 | 9 | 8 | 8 | 8 | 9 | cover-art hues are slightly muddy; XL title sits close to the CTA bar (scrolls) |
| Home | 8 | 9 | 8 | 8 | 8 | 9 | banner art is generated gradient until real covers arrive; XL banner caption now scales (3 lines) but was not re-shot |
| Roam | 9 | 9 | 8 | 8 | 9 | 9 | GO press/ring cannot be seen in a still; nearby rows with art thumbnails were NOT captured (sheet collapsed in the fixture), so that part is unverified visually |
| Moments (unlock, stamp, check-in, wall) | 9 | 9 | 8 | 9 | 9 | 9 | confetti/haptics not visible in stills; Reduce Motion path is code-gated, not shot |
| Club join | 9 | 9 | 8 | 9 | 8 | 9 | real sheet via the real presentation object |
| Me header | 8 | 8 | 8 | 8 | 7 | 9 | quick-action tiles are 2 (tickets, balance); unknown shows a dash |
Pages under 8: none by this scoring; caveats above are unverified items, not accepted gaps.

## Open
Roam nearby-row look and the banner XL caption need one more shot when the lock queue allows. Another agent shared this worktree (guide pages); its commit 65cb8ec19 is on the branch and untouched by e5b. `Questify.xcodeproj/project.pbxproj` was regenerated to add the new design-system and fixture files.
