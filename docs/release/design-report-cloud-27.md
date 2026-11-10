# UI-CLOUD-27 design report

NOT COMPILED locally (no Xcode in this environment). Xcode Cloud Build is the check.

Mobbin search was not available from this runner. Patterns below are the coordinator benchmarks that match these screens, plus the in-repo kit (`CYHeroHeader` / `cyHeroScreen`, `CYImageCard`, `CYListRow`, `CYCoverArt`, `CYStatusChip`, `CYSectionHeader`, `CYEmptyState`, `CYSkeleton`, `CYPillButton`).

## Benchmarks

- Blocked people: settings-style grouped list with a leading mark, name, and one destructive review (Meetup-style one commit path, https://mobbin.com/screens/ec972fea-0cf4-4006-a80c-a2de330fbdd5). Unblock stays behind the existing confirmation.
- Chain: Eventbrite-style page title then one photo card (https://mobbin.com/screens/96206b7a-7611-464e-9250-6f16fa276a9c). Join, update, or create is the single primary. Withdraw and close stay destructive.
- Check-in: one streak figure, icon plus words for today, history rows with a status chip. The stamp bounce, success haptic, and confetti stay, and they stay quiet under Reduce Motion.
- History: one pinned title (the history key) and the conversation name as body text under it. Message rows keep the existing bubble. Paging actions are secondary so they do not compete with the composer.
- Permissions: one hero, grouped pickers, review as the only primary, remove as destructive.

## Screens

| File | What changed | Theme | New keys |
|---|---|---|---|
| App/NativeBlacklistView.swift | One `CYHeroHeader` (`cyHeroScreen`). Rows are `CYListRow` plus generated cover. Empty, closed, and failure use `CYEmptyState`. Loading uses `CYSkeleton`. Return-to-list is the primary only after a result; retry is primary only when that result is absent. | dark player | none |
| App/NativeChannelChainView.swift | One hero. The chain name is a `CYImageCard` (empty name is an em dash). Status is a chip with an icon. Entries are kit rows. Join, update, create, or confirm is the one primary. A real slot count of 0 still means unlimited. | dark player | none |
| App/NativeChannelCheckinView.swift | One hero on the check-in screen and one on the rank screen. Streak stays the real number, including 0. Check-in or confirm is the primary. Rank uses a cover or https avatar. A missing rank stays an em dash. | dark player | none |
| App/NativeChannelHistoryView.swift | The bar title and the principal conversation title are one pinned hero plus the conversation name. Unread count stays a real number, including 0. Avatars are `CYCoverArt`. | dark player | none |
| App/NativeChannelManagementPermissionsView.swift | One hero from the existing permissions key. Review is the primary pill. Remove stays destructive. A blank role name is an em dash. Allow and deny masks of 0 stay 0. | dark player | none |

Skipped: none of these file names contain Merchant, Coupon, Ledger, or Settlement. No owned file was missing. `App/CityActionBudgetView.swift` was not edited.

## Self-score (no simulator shots)

| Screen | Delight | Interaction | Inclusivity | Visuals | Innovation | Social | Notes |
|---|---|---|---|---|---|---|---|
| Blacklist | 7 | 8 | 8 | 8 | 6 | 9 | Unblock stays a confirmed destructive action. |
| Chain | 7 | 8 | 8 | 8 | 6 | 8 | Photo card is generated when the chain has no https image. |
| Check-in | 8 | 8 | 8 | 8 | 7 | 9 | Existing stamp moment kept and gated on Reduce Motion. |
| History | 7 | 8 | 8 | 8 | 6 | 8 | Composer stays in its own view, so this screen does not add a second primary. |
| Permissions | 7 | 8 | 8 | 8 | 6 | 8 | Tri-state pickers and CAS submit are unchanged. |

Delight and innovation stay with the existing flows. Rework past the kit would mean new motion or files this lane does not own.
