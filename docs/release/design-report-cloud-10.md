# UI-CLOUD-10 design report

Player-dark restyle of the club rules, meeting-time, directory, owned-clubs, enrollment roster, activity calendar, and governance feed post. Presentation only. NOT COMPILED here (no local Xcode). Logic, identifiers, routes, and existing string keys are unchanged.

Mobbin MCP is not available in this environment. Benchmarks below are the coordinator's cited iOS references in `design-bar-ada.md`, plus the in-repo kit screens `CityTaskCard`, `ActivityBrowserView`, and `DiscoveryTemplateBrowserView`.

## Benchmarks

- Directory / owned clubs: Eventbrite Discover photo cards (full-width cover, title and meta on the image) and a single status chip. https://mobbin.com/screens/96206b7a-7611-464e-9250-6f16fa276a9c
- Enrollment roster: Meetup registration rows (name, date, count, one status). https://mobbin.com/screens/ec972fea-0cf4-4006-a80c-a2de330fbdd5
- Activity calendar: Luma date badge + agenda rows, flattened to kit rows so Dynamic Type is not clipped inside a 56pt tile. https://mobbin.com/screens/054f5624-ea8a-4bf5-a3eb-ecf64a11805c

## Screens

| File | What changed | Theme | New keys | Could not do |
| --- | --- | --- | --- | --- |
| `App/ClubContextualViews.swift` | Rules and meeting-time use `CYHeroHeader` (one title via `cyHeroScreen`), 16pt gutters, `CYNoteBanner`, one primary preview and a secondary read-back. Save stays in the system confirmation. | dark | none | No fixture: meeting time needs a live coordinator. |
| `App/ClubDirectoryView.swift` | `CYHeroHeader` plus pinned search. Photo cards (`CYImageCard`) and `CYStatusChip`. Missing member count is an em dash; a real 0 stays "0 members". | dark | none | Cards need `ClubReading`. No DEBUG host. |
| `App/ClubEnrollmentView.swift` | Kit rows, cover art, status chips, skeleton, 16pt row insets, Dynamic Type stacking. Capacity 0 stays in the fraction. Unknown counts stay the catalog em dash. | dark | none | Nav bar title stays "Enrollment roster" because `ClubEnrollmentFlowTests` addresses `navigationBars["Enrollment roster"]`. A second hero would duplicate that title. `cyHeroScreen` would clear it. |
| `App/ClubEventCalendarView.swift` | `CYHeroHeader`, plain list, 16pt insets, day cells with a 44pt minimum and no fixed text box, kit event rows, month empty state, refresh as the only pill (primary only on failure). | dark | none | Needs governance access. Sessions title stays in the `ClubCalendarSessions` table so it is not a raw key. |
| `App/ClubGovernanceFeedPostView.swift` | Elevated post card, 16pt padding, scaled avatar, source row at 44pt. Leaf identifiers kept (`club.feed.post/time/source/images`). | dark | none | This is a row inside the governance list, not a screen, so it does not call `cyHeroScreen` (that would clear the parent title). |

No file in this lane contains Merchant, Coupon, Ledger, or Settlement. None were skipped as missing.

## Scores (structural; no simulator shot)

| Screen | Delight | Interaction | Inclusivity | Visuals | Innovation | Impact |
| --- | --- | --- | --- | --- | --- | --- |
| Rules | 7 | 8 | 8 | 8 | 6 | 9 |
| Meeting time | 8 | 9 | 8 | 8 | 6 | 9 |
| Directory / owned | 8 | 8 | 8 | 9 | 7 | 9 |
| Enrollment | 7 | 8 | 8 | 8 | 6 | 9 |
| Calendar | 8 | 8 | 8 | 8 | 7 | 9 |
| Feed post | 7 | 8 | 8 | 8 | 6 | 8 |

Innovation stays under 8 on purpose: these are operational club screens, not the roam/stamp moment, and a celebratory layer would be new behaviour. Press feedback and the meeting-time success haptic are the motion that fits.
