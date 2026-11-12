# mp-mpsocial: community + clubs parity (layout side)

Branch `ui/mpsocial`, base `origin/ui/main`. Source: `liboyang42-cpu/hengyin` `chengyinhub-xcx/pages/{square,club}`. Code-only; not compiled (integrator builds).

## Changed
| mp page | native file | change |
|---|---|---|
| `square/detail` (`theme-dark`) | `App/SquareDetailView.swift` | Ink page ground and elevated card rows for the post and comment sections (`cyMiniListScreen` / `cyMiniCardRow`). Sticky comment bar is now an ink2 capsule with glass edge (mini `david_npl`), disabled state dimmed. Like button gets a bounce and numeric transition (spring; opacity-only under Reduce Motion). Identifiers kept. |

## Audited, already matching (no change needed)
- square detail states (loading/error/missing/empty), post head, overflow menu (edit/delete/report/block), comment thread with reply/delete/report, load-more: `SquareDetailView`, `SquareComponents`, `SquareXcxPostCard`.
- club list (hero header, create prompt, inline join pill, hero zoom, member strip): `ClubHomeView`, `CYClubCards`.

## MISSING / needs logic (Cursor) or follow-up
Not audited in depth (time): club enroll/apply/create/topic-detail/topic-story/governance/roles/notify/join-requests/workbench/settlement layout vs wxml. These map to existing `Club*` files, listed below; they were not restyled.
- Square avatar popover capsule (`square/components/cy/popover`, tap avatar to open profile/follow): no native counterpart (detail only has a "view author" row).
- Square post share (`square/utils/square-share.js`): no ShareLink; needs share URL logic.
- Square route map (`components/route-map`) and activity picker in compose (`components/activity-picker`): no native counterpart found.
- Square post-drafts sheet (`cy/post-drafts`): drafts exist in `SquareWorkspaceView`, layout not compared.
- Club `club-game-code-sheet` (game code sheet in club detail): no native counterpart found.
- Club director sheets (`club-director-*` broadcast/chapter/role/team/incident/recap) vs `ClubTerminalSessionView`/`ClubGovernanceViews`: unverified.
- Club `customers`, `customer-detail`, `badges`, `checkin-detail`: operator/merchant surfaces stay behind `merchantSurfaceHiddenInV1`; not built.
- Card/payment/payout/withdrawal surfaces in club settlement stay OFF.
