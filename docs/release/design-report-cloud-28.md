# Design report — UI-CLOUD-28

Lane: channel management and channel message presentation. Player dark. No behaviour change.

## Benchmarks

Mobbin search was not available in this environment (no Mobbin tool). Patterns taken from the brief and the in-repo kit screens named in the lane:

- Activity browser: empty, failure, and loading are states, not blank rows (`CYEmptyState`, `CYSkeleton`).
- City task card: one call to action for the step that can move forward (`CYPillButton` primary). Secondary and destructive actions stay visually quieter.
- Discovery template browser: a missing photo is generated cover art (`CYCoverArt`), never a grey box and never a remote fetch.
- Design-bar chat template: channel rows are icon, title, status chip, chevron. Message context keeps the sender and the existing bubble.

## What changed

| Screen | Title | Primary action | Notes |
|---|---|---|---|
| Channel directory | `directory` via `CYHeroHeader` + `cyHeroScreen` | Create, when the server allows it | Rows use `CYListRow`. Archived and private are chips with an icon and text. |
| Channel detail | Channel name, or `detail` before it loads | None added | Facts, then the same gated pages. Unknown member count is an em dash. A real 0 stays 0. Slowmode 0 stays off. |
| Channel editor | `create` or `settings` | Review | Archive, restore, and unarchive are secondary. Delete stays destructive and still opens the review sheet. |
| Channel review | `review` | Confirm | Delete confirm stays destructive. |
| Attachment | Existing media screen keeps its own title. The blocked state uses `attachment.open` | None added | Legal image path is still `SocialMessageMediaView`. No new image request. |
| Message bubble | Not a screen, so no second title | Open actions are secondary | Voice, file, and video keep their cards and routes. Red packet is not given a new action. |
| Message context | `d7.channelContext.title` | None. Earlier and later are tertiary | Sections use `CYSectionHeader`. |
| Pins | `pins.title` | None. Unpin stays a swipe. Reorder stays Edit | Empty and closed use `CYEmptyState`. |

Skipped for Merchant / Coupon / Ledger / Settlement: none. Those names are not in this lane's files. All five files exist.

No new string keys. Existing keys and tables are unchanged. No Core, route, capability, Vendor, or project file edits.

## Scores (not from a simulator)

This environment cannot run the iOS simulator, so these are structure scores, not a visual sign-off.

| Lens | Score | Note |
|---|---|---|
| Delight | 7 | Cover art on a missing attachment and on image bubbles. No extra motion beyond kit press feedback. |
| Interaction | 8 | One primary where the screen already had one. Swipe, reorder, sheets, and routes kept. |
| Inclusivity | 8 | Text grows with Dynamic Type. Icon-only controls that remain have labels. Reduce Motion stays inside the kit. |
| Visuals | 8 | Dark tokens, 16pt gutters on scrolling pages, system grouped insets on lists, one hero title. |
| Innovation | 7 | These are management and message screens, not the roam map. |
| Social impact | 8 | Unknown values use an em dash. Counts of 0 stay 0. No new payout or virtual-goods path. |
