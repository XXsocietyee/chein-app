# Design report UI-CLOUD-11

Lane: club home, governance workspace, invitation feedback, lead progress.
Role theme: player dark (tokens follow the role root; these screens do not force a scheme).
New string keys: none. Existing catalog keys are unchanged. Unknown values render as an em dash; a real 0 stays 0.

## Benchmarks

Mobbin search was not available in this environment, so these are the coordinator's published iOS references for this family, not new search hits:

- Community club: Partiful club profile (https://mobbin.com/screens/7c595947-0cb2-424d-8dd0-0bd981fdc1b1) — cover tile, name, one join/create action. Borrowed: keep `ClubRow` cover cards; one create action above the list.
- Group list: Reddit Communities (https://mobbin.com/screens/d5f8357a-24e8-49ab-a401-a07406cdfd50) — row with icon, title, one trailing cue. Borrowed: `CYListRow` + `CYRowIcon` for directory, governance, and invitation rows.
- Status: Meetup event detail (https://mobbin.com/screens/ec972fea-0cf4-4006-a80c-a2de330fbdd5) — hero title, fact rows, one registration action. Borrowed: `CYHeroHeader` / `cyHeroScreen` (one visible title) and one `CYPillButton` primary.

## What changed

| Screen | Follows | Theme | Notes |
|---|---|---|---|
| `ClubHomeView` | talent/list club tab | dark for players; merchant nearby stays on the merchant root | Hero title, 16pt row insets, kit empty/loading, directory rows. Create stays the existing primary control so its sheet does not inherit a new button style. |
| `ClubGovernanceViews` | club settings sheet and topic/story reads | player | One hero title per read, skeleton loading, kit rows, one filled action (host apply, otherwise refresh). Null facts show an em dash. Story and event lists use the same title rule. |
| `ClubInvitationFeedbackView` | sent/received invitations | player | Hero, status chip, em dash for a missing partner, topic, status, or amount. Refresh/retry is the one filled action. |
| `ClubLeadProgressView` / `ClubLeadPrimaryActionView` | creator lead timeline | player | Stage chip, tabular counts (0 stays 0), one filled next action. Merchant discovery keeps its own section title; the extra bar title is cleared. |

No `CloudFixtures_11` host: every screen needs a live reader or governance controller.

## Self-score (1–10)

Delight / interaction / inclusivity / visuals / innovation / social.

- Club home: 7 / 8 / 8 / 8 / 6 / 8. Under 8 on delight and innovation: the list is still the mini-program's club tab, and the create control cannot switch to `CYPillButton` without restyling the sheet it presents.
- Governance workspace: 7 / 8 / 8 / 7 / 6 / 8. Under 8 on delight, visuals, and innovation: it remains an operations list. Actions stay, styled secondary, because removing them would change behaviour.
- Invitations: 8 / 8 / 8 / 8 / 6 / 9.
- Lead progress: 8 / 8 / 8 / 8 / 6 / 8.

Innovation stays under 8 on purpose: these are not the roam map or the stamp cabinet.

## Not compiled here

Xcode Cloud is the build. GLTFKit2 test errors are out of this lane.
