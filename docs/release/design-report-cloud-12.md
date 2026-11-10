# UI-CLOUD-12 design report

NOT COMPILED on this agent (Linux checkout, no iOS simulator). Scores are from the code against the design bar, not from screenshots.

Mobbin search was not available in this environment. Patterns below are the coordinator's cited iOS references in `design-bar-ada.md`.

## Benchmarks

- Meetup event detail (hero, fact rows, one registration action): club management detail and the operations review sheet.
- Eventbrite / Viator photo rows (image, title, meta, one trailing mark): join-request rows, member rows, audience rows. Avatars use the member photo when it is HTTPS; otherwise the kit monogram.
- One full-width primary, everything else secondary or destructive: refresh on the management list, approve on a request, confirm on the review sheet.

## Screens

| File | Mini-program | What changed | Theme | New keys |
|---|---|---|---|---|
| `App/ClubManagementView.swift` | `pages/club/join-requests/index` | Hero title via `cyHeroScreen`, plain list, 16pt gutters, avatar rows, skeleton, empty kit, one primary (refresh, or approve on a request). Reject and remove stay destructive. Blank server or member names render as an em dash. | dark player | none |
| `App/ClubMembersView.swift` | club member roster (opened from club detail) | Hero title, club name under it, avatar rows, role chips, Dynamic Type stacks the report flag. Existing identifiers and the profile/customer choice stay. | dark player | none |
| `App/ClubMemberReportView.swift` | platform report from the member row | Target card uses kit type, 16pt gutters, and the elevated surface. The embedded `ClubGovernanceCommandForm` already sets the one bar title `club.gov.action.report`. A second hero would repeat it, and that form is outside this lane. | dark player | none |
| `App/ClubNotificationAudienceView.swift` | `pages/club/notify/index` audience block | Not its own screen. Rows use `CYRowIcon`, title, meta, and a count. A missing count is an em dash; a real 0 still uses the existing people string. Reload is secondary so the notify send stays the one primary. | dark player | none |
| `App/ClubOperationsReviewView.swift` | club create/edit review | Hero title via `cyHeroScreen`, one confirm primary, cancel stays in the toolbar. Blank draft text is an em dash. An empty reserved quota is still shown as 0 because that is the value the draft submits. | dark player | none |

No file was skipped. None of the owned names contain Merchant, Coupon, Ledger, or Settlement. No fixture host: every screen needs a live reader, access, or coordinator.

## Scores (code review, no screenshot)

| Screen | Delight | Interaction | Inclusivity | Visuals | Innovation | Social impact |
|---|---|---|---|---|---|---|
| Management | 8 | 8 | 8 | 8 | 7 | 8 |
| Members | 8 | 8 | 8 | 8 | 7 | 8 |
| Report target | 7 | 8 | 8 | 8 | 7 | 8 |
| Audience rows | 7 | 8 | 8 | 8 | 7 | 8 |
| Review | 8 | 8 | 8 | 8 | 7 | 8 |

Innovation stays at 7: these are admin lists, not the roam/stamp moment. The report screen cannot take a `cyHeroScreen` title without a second title or an edit to `ClubGovernanceCommandForm`. Audience rows stay inside the notify form for the same reason.
