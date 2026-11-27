# Receipt: design pass, clubs + social (`design/pass-social`)

Brief: scheduled lane prompt. Principles from `origin/design/handoff-r2:docs/briefs/design-principles.md` (P2, P5, P6, P7, P11, P12 for this lane). Rules and gates from `components-r1.md` and `COORDINATOR-HANDOVER.md` §4.
Base: `origin/ui/combined-r7` @ `fc95e6a19`. `origin/comp/r1-kit` and `origin/comp/r1-social` were merged first, but both were already part of combined-r7 ("Already up to date").
Date: 2026-11-27. There is no compiler in the cloud. Every API was checked by grep and by hand against the §4 traps. **Run `build_sim` before merging.**

## New shared pieces (`App/NativeR2/Social/CYPeopleComponents.swift`)

| Piece | What it does | Principle |
|---|---|---|
| `CYFacePile` | Overlapping `CYAvatarView`s (initials when there is no HTTPS avatar) plus a "+N" capsule. The capsule's digits roll with `.numericText` (Reduce Motion turns the roll off). VoiceOver reads it as one element: the visible names plus "还有 N 人 / N more". | P6, P2 |
| `CYInviteCard` | An invite card: icon tile in one accent, kicker, title (what), fact lines (when / where / who), an optional taped-note line with the inviter's own message on `CYColor.warningSoft`, the people already in, then the answers. Every line wraps. At accessibility sizes the icon tile drops out and the note stops tilting. | P11, P7, P12 |
| `CYInviteAnswers` | One `.borderedProminent` capsule for yes, one `.bordered` (optionally destructive) for no, and an optional borderless 稍后/Later. Uses `ViewThatFits`: the buttons sit side by side and stack when the English is too long. Accessibility identifiers can be passed in, so existing UI test ids are kept. | P3, P11, P12 |

Strings: 5 keys (`comp.social.*`) in zh-Hans and en. Fragment `docs/port/strings/design-pass-social.json` is already merged into `Resources/Localizable.xcstrings`.

## Screen-by-screen: principles failed → fix

| Screen | Failed before | Fix in this pass | File |
|---|---|---|---|
| **Club detail header** | P6: members appear only deep in 概览 (overview), and the header shows a text count only. P2: the count is static. | A face pile of the members the viewer may see (MP 成员 strip data, `r8Mounts.memberAvatars`) under the 「类型 · N 名成员」 meta line. Its "+N" rolls when the total changes. Shown only when `club.canSeeMembers`, so the MP gating is kept. | `App/ClubDetailView.swift` (`ClubDetailHeader.people`, call site in `pageHeader`) |
| **Club events (活动 tab + calendar list)** | P2/P1: the start time is static even minutes before start. P2: sign-up counts don't move. | In the last hour, a recruiting activity shows a live 「距开始 mm:ss」 (C3 `CYCountdown`, the system timer clock). At zero it switches to 进行中. Date-only starts never count down. Sign-ups, stations and km roll with `.numericText` (Reduce Motion: off). | `App/ClubActivityListContent.swift` (`ClubActivityCard.soonStart`, `stat`) |
| **Chat card messages (route / signup / location / generic system cards)** | P5: each card kind looked like plain text with a label, so the same object looked different in the bubble and in the detail view. P11: cards that carry answers (MP `genericButtons`) gave no sign of that in the transcript. | Every card kind gets one icon tile and tint (location green, route blue, signup orange, generic neutral) in the bubble and on the detail page. In the transcript, a card with answers adds 「点开即可回应 / Tap to respond」. The answers stay on the detail page, where `IMCardActionsView` already runs them (MP `onCardBtn` only navigates). | `App/MessagingMessageDetailView.swift` (`MessagingCardContent`, `MessagingMessageContent.inTranscript`), `App/MessagingHistoryView.swift` |
| **Team invites (friends → 队伍邀请)** | P11: a title plus a status line, with 加入 / 拒绝 as plain list rows of equal weight. P6: no face for the inviter. P3: no single obvious answer. | Each offer is a `CYInviteCard` showing team, state with its symbol, and the inviter's face plus 「X 邀请你加入」. The recipient gets 加入 / 申请加入 as the prominent answer, 拒绝 as the quieter one, and 稍后, which leaves the invite open and pops back. Revoke, view team and view invitation are unchanged. The write path is unchanged: each answer still opens the existing review (confirm) section. | `App/NativeFriendTeamInviteEntry.swift` |
| **Friend requests (好友 home → 收到的申请)** | P11: name plus two equal `.bordered` buttons. P6: every person drawn as the same `person.crop.circle.fill` glyph. | Incoming requests are invite cards. The requester's message is the taped note. 接受 is prominent and 拒绝 is quieter. Ids `friend.accept.<id>` / `friend.reject.<id>` / `friend.row.<id>` are kept. Every friend row now shows a face (`CYAvatarView` initials) instead of the glyph. | `App/NativeFriendHomeView.swift` |
| Community feed / post / comments | P2: like and comment counters already roll (C5 `CYSocialCountLabel`). P6: the comment rows follow the MP (name and text, no avatar, `club/detail/index.wxml:137`). P7 (first post / milestones): not met, because the MP has no first-post moment to copy. | No change this pass. Open item: a first-post or milestone moment needs an owner decision, since the MP has none. | — |
| Channels / messages inbox | P2: unread already rolls (C5). P6: presence and typing don't exist in the MP chat (C5 receipt), so nothing was invented. P10: loading and failure states already say what is happening. | No change beyond the card work above. | — |
| Club home / members / governance player views | P6: the members list already shows avatars (MP). P12: lists use system rows that wrap. | No change in this pass. The face pile can be reused on club cards next. | — |
| Merchant cooperation invites (`IMCoopInviteStripView`) | — | Out of scope (merchant). | — |

## Not done / for the next pass

- One-tap answers inside the chat bubble itself. `MessagingBubble` has no navigation state for `IMCardDestination`, and the MP answers are navigations, not writes. To do this, lift the destination handler into the history view.
- Team and friend answers still go through the existing review/confirm section, so a yes is two taps. That step is a write-safety contract and I kept it on purpose.
- The club header face pile appears once `ClubDetailR8MountModel` has loaded the member strip, which happens on 概览. Other tabs show it after that first load.
- No P7 moments were added. Neither surface in this lane has an MP "first" or "milestone" event to hang one on.

## References (self-found, added for the principles log)

- **Apple Messages, Apple Pay / Cash request bubbles**: the request sits in the transcript as a card with its own answer button (P11, answers inside chat).
- **Slack huddle and Discord scheduled-event cards in channels**: event card in the stream with "Interested / Join" and attendee faces (P11 + P6).
- **Instagram "Liked by X and N others", Strava club header, Meetup attendees**: a face pile plus a count next to the thing it qualifies (P6, P2).
- These come from product knowledge. I did not browse them again during this scheduled run.

## Gates

- `python3 tools/generate_project.py`: the new file was added under `App/NativeR2/**`.
- `python3 -B tools/check_scaffold.py`: PASS structural checks (19775 bilingual keys). The typography lint flagged `.caption2` in the face pile; I fixed it to `.caption`.
- `python3 -B tools/check_a11y_lint.py`: PASS, 0 new.
- `python3 -B tools/contract_ratchet.py --check`: baseline before my changes was 104 failing / new 0. The result after is in the commit message.

## For the coordinator

- No capabilities, entitlements or profiles are needed.
- `build_sim` compile-risk spots:
  - The generic `CYInviteCard<Answers>` init with a `@ViewBuilder` closure that contains `if case .offer = mode, offer.canAct`.
  - `let name` inside the `ForEach` in `NativeFriendHomeView`.
  - `ForEach(Array(shown.enumerated()), id: \.element.id)` in `CYFacePile`.
