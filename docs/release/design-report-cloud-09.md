# UI-CLOUD-09 design report

NOT COMPILED locally (no Xcode in this environment). Xcode Cloud is the build check.

Mobbin search was not available from this runner. Patterns below are the coordinator benchmarks that match these screens, plus the in-repo kit (`CYHeroHeader` / `cyHeroScreen`, `CYImageCard`, `CYListRow` rhythm, `CYPillButton`, `CYEmptyState`, `CYSkeleton`).

## Benchmarks

- Activity chooser: Meetup event detail (https://mobbin.com/screens/ec972fea-0cf4-4006-a80c-a2de330fbdd5) — one title, date/time under the name, one commit path. The report form stays the existing command form.
- Badge list: collection rows with a leading mark, title, meta, and one secondary award action. Create stays the single primary.
- Chat entry: one explanation and one enter/retry pill. No second title in the bar.
- Check-in rail: status is icon plus words. Embedded in the governance list, so it keeps a section title and does not clear the parent bar.
- Community feed: Eventbrite-style stack (https://mobbin.com/screens/96206b7a-7611-464e-9250-6f16fa276a9c) — page title, then cards. Photos stay on the existing gallery. Compose is the one primary when the viewer can post.

## Screens

| File | What changed | Theme | New keys |
|---|---|---|---|
| App/ClubActivityReportView.swift | Chooser and target use one `CYHeroHeader` (`cyHeroScreen`). Choice rows are cards. Empty/error/loading use the kit. Retry is secondary while choices exist, primary only as the empty/error action. | dark player | none |
| App/ClubBadgeManagementView.swift | One hero title. Create is the primary pill. Grant/refresh/recover stay secondary. Receipt lines stay on the ClubBadge table; an unknown state uses the existing unknown sentence. | dark player | none |
| App/ClubChatEntryView.swift | One hero title. Enter or retry is the only pill. | dark player | none |
| App/ClubCheckinRailView.swift | Rail and detail rows use kit type, 44pt stops, status chip (icon + text). Accessibility sizes stack. State titles resolve `titleKey` or a bilingual fallback, never the raw key. | dark player | `club.checkin.state.missing`, `club.checkin.state.denied`, `club.checkin.state.error` |
| App/ClubCommunityViews.swift | Feed, detail, composer, review, comments, and history each have one hero title. Compose/review/confirm is the primary pill. Counts stay verbatim, including 0. Blank comment or history text is an em dash. | dark player | none |

Skipped: none of the owned files contain Merchant, Coupon, Ledger, or Settlement. No file was missing.

## Self-score (no simulator shots)

| Screen | Delight | Interaction | Inclusivity | Visuals | Innovation | Social | Notes |
|---|---|---|---|---|---|---|---|
| Activity report | 7 | 8 | 8 | 8 | 6 | 8 | Form chrome is unchanged, so the target step is not fully image-led. |
| Badges | 7 | 8 | 8 | 8 | 6 | 8 | Named badges with an https icon use `CYImageCard`; unnamed stay a row. |
| Chat entry | 7 | 8 | 8 | 8 | 6 | 8 | Entry only; the thread is the existing messages screen. |
| Check-in rail | 7 | 8 | 8 | 7 | 6 | 9 | Embedded section. Unknown state copy is an em dash or the bilingual sentence, never 0. |
| Community | 7 | 8 | 8 | 8 | 6 | 8 | Gallery and author row stay in their own files. |

Nothing here is under 8 on interaction, inclusivity, or honesty. Delight and innovation stay with the existing flows (no new motion beyond kit press and Reduce Motion). Rework would mean editing files this lane does not own.
