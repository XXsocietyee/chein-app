# Receipt: club photo cards (DES-e3, W3-4)

Source: `ux-strategy.md` W3-4 / §3.6 (Cal AI groups list with inline Join; Discord server preview card with one green Join), `design-bar-ada.md`, motion in `motion-spec.md` (press scale and Reduce Motion reuse `CYImageCard` / `CYPillButtonStyle`; no new animation).

## Delivered
- `App/DesignSystem/CYClubCards.swift`: `CYClubPhotoCard` (cover + scrim via `CYImageCard`, footer = avatar stack + count left, ONE trailing control right), `CYClubRowCard` (56 pt logo, name, count, status chip), `CYClubMemberStrip` (5 avatars + "+N"; unknown count = em dash, a real 0 stays "0 members"), `CYClubCardTrailing`, `CYClubCardAction`, `ClubRecord.cardAction(viewerIsMerchant:)`.
- `CYPillButton` / `CYPillButtonStyle`: new `compact:` (default false, 44 pt scaled) for inline footers; existing call sites unchanged.
- `ClubHomeView`: "Your clubs / 你的俱乐部" row cards (owned, joined), then "Discover / 发现" photo cards with the inline Join pill. Headers appear only when their group has rows. Merchant scope keeps its locality flow and gets cards without a pill.
- `ClubDirectoryView` / `ClubOwnedView`: photo cards with the same footer. Card and pill open the detail via `navigationDestination(item:)` (hero matched transition kept).
- `ClubDetailView`: avatar stack is 5 + "+N" from the source count; hidden when the count is unknown (the meta line already shows the dash).
- One pill per card: only `.join` / `.apply` render a pill; pending, joined, owner are chips; merchant viewers get none.
- Strings: `club.home.yours`, `club.home.discover` (EN + zh-Hans) merged into `Resources/Localizable.xcstrings`; fragment kept in `docs/release/ui-strings-clubcards.json`. Pill text reuses `club.action.join` / `club.action.apply` through the catalog.
- DEBUG fixtures (`App/DesignFixtures/ClubCardFixtures.swift`, registered): `clubcards-home`, `clubcards-directory`, `clubcards-states` (join/apply/pending/joined/owner/none), `clubcards-strip` (0, unknown, 3, 5, 120), `clubcards-ax`. Cover art is the generated DEBUG art, no photos.
- `Questify.xcodeproj` regenerated with `tools/generate_project.py` (two new sources). No Core/Tests/Config edits.

## Behaviour and gating
Unchanged. The inline Join pill only navigates to the detail; the join/apply request, application message, confirm sheet and `ClubActionAvailability` gating still live in `ClubActionPanel`. Nothing is sent from a card. Known deviation from "inline join": the one-tap send is not in the card because it would duplicate the coordinator state machine outside UI-owned files.

## Not done / data gaps
- Unread pill on "Your clubs" rows: `ClubRecord` has no unread count, so none is shown (no invented data).
- Detail still uses the existing gated `ClubActionPanel` button (already a single capsule) rather than a pinned pill.

## Verification
- `swiftc -parse` on every changed Swift file: clean. `check_scaffold.py`: PASS, gaps 0. `check_design_lint.py`: PASS.
- Nothing was built or run; Xcode Cloud result recorded below once it reports.

## Not verified
Type-checking, nested Button-in-List tap behaviour, VoiceOver order (card button then footer), AX3 layout, and zh-Hans wrapping need a build and a fixture pass.
