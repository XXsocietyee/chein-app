# Receipt: ui/c-cont-im (continuity r1, item 9: 消息 inbox row to chat, chat continuity)

Brief: `origin/design/continuity-brief:docs/briefs/continuity-r1.md`. Base: `origin/ui/main` 6ceb69fc7.
Swift was not available here: nothing was compiled or run. Every API used was checked against existing repo usage and the iOS 17 deployment target (see "Compile notes"). The integrator must build, check and screenshot it.

Skills: all three repos were cloned and read (apple-design-motion + references, choreograph, write-swift, make-interfaces-feel-better). Rules applied are cited per item.

## Files touched

| File | Owner area | Why |
|---|---|---|
| `App/IMInboxViews.swift` | mine (IM*) | unread badge count-down, avatar dot, new continuity helpers `IMSendFlight`, `imSendFlight`, `imChatRowTransition`, `IMSendGhost` |
| `App/MessageActionComposer.swift` | **outside IM\***, flagged | the send button and the status row live here; there is no other way to morph Send |
| `App/MessagingHistoryView.swift` | **outside IM\***, flagged | the chat transcript, its refresh and its title live here |

**OWNER FLAG:** the task names `App/IM*.swift`, but the chat screen is `MessagingHistoryView` and the composer is `MessageActionComposer`. Neither belongs to the areas the brief gives to other workers (CityKit, DesignSystem, tab roots, editor, merchant, club). I made small, additive changes to both. `MessagingHomeView.swift` (inbox list) was **not** touched, and no router or navigation structure changed. `ClubChatEntryView` / `InGameChannelEntryViews` / `NativeFriendSessionEntry` use `MessagingHistoryView` unchanged; they get the same chat motion automatically.

## 1. Inbox row to chat (title carry)

- **Approach:** a standard push, not the zoom. The task gave a choice. Only the standard push keeps both things it asked for: the inbox title shrinking into the Back button (system behaviour of `appNavigationTitle` + push) and the native edge-swipe back. Per apple-design-motion §2.4, the zoom replaces the push, so the nav-bar title does not morph into Back. In the chat's nav bar, the principal avatar + name (the row's own `CYIMCoverArt` seed + `MessagingConversationName`) now use the product's `cyHeroTitleRise()`: it settles from 16 pt below at 0.5 opacity, on the entrance spring, while the push runs. So the row's identity reads as rising into the bar.
- **First frame:** the inbox with its large/inline title. The chat page sits off-screen right, with its principal title 16 pt low at 50%.
- **Last frame:** the chat as before (title at rest, opacity 1). Back reverses the system way. The rise is not replayed on pop.
- **Rules:** apple-design-motion "zoom … handles push natively", but the owner asked for the system back-title morph. choreograph Step 1: the title is the Lead and the transcript is Static, with no stagger. Brief: the gesture follows the finger, because the system edge-swipe is untouched.

## 2. Send: input text becomes the bubble

- **Approach:** a shared element matched by id. When Send is tapped, `IMSendFlight.launch` keeps the sent text in the field as a ghost (`IMSendGhost`): same font, same 11/16 pt inset, secondary colour. This replaces the field's cleared text, so nothing disappears. When the server acknowledges, the ghost is keyed to the receipt's message id (`land(on:)`). The history now runs `refreshInPlace()` (below) instead of the blanking `reload()`. In **one** `withAnimation` transaction it inserts the page and removes the ghost. Both carry `matchedGeometryEffect(id: messageID, properties: .position, anchor: .bottomTrailing)`, so the new bubble starts at the field's trailing-bottom corner and travels to its slot. **Position only, never size:** no frame or padding is animated (brief: "transforms, never frame size"). The ghost fades out in 0.12 s (≈34% of the 0.35 s move: "start-only content fades out in the first 25–35%"). The landing bubble uses `.identity` as its insert transition, so it stays opaque: it is the moving element. The other rows make room through the bottom-anchored `LazyVStack` in the same transaction.
- **Timing:** `easeInOut(CYMotion.Duration.standard)` 0.35 s (brief: "moves within a screen use ease-in-out").
- **First frame:** the field shows the sent text where it was typed. The send button is the accent circle with a spinner.
- **Last frame:** exactly the old post-send state: the transcript reloaded from page 0, scrolled to the newest, the new bubble in place, the field empty.
- **Failure paths:** rejected, outcome unknown, closed, acknowledged while the history is not ready, `perform` denied, refresh failed or cancelled, or the composer disappearing all call `cancel()`. The ghost fades and the existing issue row, with `pendingText` and Retry, shows as before. Retry never launches a ghost; its bubble just inserts.
- **Rules:** choreograph "Carry" relationship (one object moves into its target). mifb §4: interruptible, because a new send re-launches, `landingID` resets and the ghost is replaced. Brief "one element, not two".

## 3. Send button morphs: sending, then sent (no toast)

- **Approach:** the `正在发送…` ProgressView row and the `消息已发送，不代表对方已读。` receipt row above the field are gone as rows (`case .sending:` / `case .acknowledged:` render nothing). Instead:
  - **Sending:** the accent circle holds its fill. The arrow goes to scale 0.25, blur 4, opacity 0, and a small spinner (tinted `CYChat.onSent`) comes from 0.25/4/0 to 1/0/1. This is mifb §7, the contextual icon swap, with exact values. Spring `CYMotion.standard`. The button's VoiceOver label stays "Send", with the value "Sending…".
  - **Sent:** the reverse swap. The circle returns to the quiet grey because the draft is empty. The receipt text (same key, same `message.send.receipt` identifier, same words) appears **inside the empty field**, in place of the placeholder, at footnote size. It fades in after 0.175 s (50% of the move: "end-only content fades in after 45–55%"). It hides while the field is focused or has text, and comes back on blur while the state is still acknowledged.
- **First and last frames:** at rest before a send, the composer is pixel-identical to before. After a send, the composer no longer grows a status row, and the receipt sits in the field. This is the requested "in place, no toast". It is the one intentional at-rest difference.
- **Contract tests kept:** `case .sending:`, `message.send.accepted`, `accessibilityIdentifier("message.send.receipt")`, no `checkmark` (a server receipt is not a delivery or read mark), exact `.onDisappear { model.retire(); confirmsRetry=false; typing=false }`.

## 4. Incoming / refreshed messages insert in place

- **Approach:** `refreshInPlace()` reads the same page 0 with the same reducer (`MessagingHistory.replace`), the same block bookkeeping and the same lease rebinding (`replyAuthority.invalidate()` before state changes), and ends in the same state as `reload()`. The difference is that the transcript stays on screen while it loads, instead of switching to the full-screen loading view and back. It is used after an acknowledged send and by pull-to-refresh. Any non-ready transcript (error, signed out, first load) still takes the full `reload()`. Failures end in exactly `reload()`'s failure state. New rows use `imChatRowTransition`: insert = scale from 0.96 + fade (the same values as `cyRowTransition`), removal = fade. Under Reduce Motion they fade only. An earlier-page read that started during the refresh is dropped (`generation` bump), as `reload()` already did.
- **First frame:** the current transcript. **Last frame:** page 0, scrolled to the newest (same as before).
- **Rule:** choreograph Hard Rule 2: no stagger on chat rows (high-frequency). mifb "skip animation on page load": the initial load is not animated, because the transcript branch appears unanimated.

## 5. Unread badges count down

- **Approach:** `IMUnreadBadge` text uses `.contentTransition(.numericText(value:))` with `cyAnimation(CYMotion.standard)`, so `12 → 3` rolls digits instead of redrawing. Under Reduce Motion it is `.opacity`. In `IMInboxRow`, the badge and the avatar's red dot leave or arrive with scale + fade, driven by `cyAnimation(value: conversation.unread)`. The entry badge (`IMUnreadEntryBadge`) benefits too.
- **OWNER FLAG (limitation):** the inbox list is fed by `MessagingReadScreenModel` (`MessagingComponents.swift`, not mine). Its refresh deliberately clears the snapshot (`clearSnapshot()` in `prepareRefresh`), so a pull-to-refresh or invalidation re-creates the rows. The count-down plays wherever a row survives a count change, which is not the case after a list reload. To make the inbox count down after reading a chat, that model would need to keep showing its last value while refreshing. That is a state-machine change (docs/release/state-machines/views.md), so I left it for owner approval.

## 6. Load older keeps the scroll anchored

- **Approach:** there is no pull-to-load-older in this screen. Older pages come from the existing "更早的消息" row at the top, and pull-down is refresh. I did not add a gesture, because that would change what an action does. `loadEarlier()` now (a) takes the anchor at *completion* (the message at the top now, since the reader may have scrolled while it loaded), falling back to the one at start, and (b) applies the prepend and `visibleMessageID = anchor` in one transaction with animations disabled. Nothing slides under the finger, and the earlier rows simply exist above.
- **Rule:** apple-design-motion "never block input". Brief: "at rest, every screen must look exactly as before".

## Compile notes (unverified, please build)

- `matchedGeometryEffect(id:in:properties:anchor:isSource:)` (iOS 14), `contentTransition(.numericText(value:))` (iOS 17), `withTransaction(_:_:)` with a throwing body (rethrows), and `TextField(axis:)` inside a `ZStack` were all checked against existing uses in the repo (`MPParityKit`, `CityDiceKit`, `OrientScoreView`).
- `IMSendFlight` is a `@MainActor ObservableObject`. The history owns it (`@StateObject`), and the composer observes it through a private `MessageComposerFieldSlot` (`@ObservedObject`). The composer has a never-launched `@StateObject idleFlight` fallback, so other hosts (`MessageActionFixture`, any future caller) behave as before.
- `AnyTransition` values are built as typed locals to avoid the iOS 17 `Transition` protocol overload ambiguity.

## Gates (run here)

- `python3 -B tools/check_scaffold.py`: PASS (structural, 4910 Swift files).
- `python3 -B tools/check_design_lint.py`: PASS (0 violations).
- `python3 -B tools/contract_ratchet.py --check`: 185 failing vs baseline 184. The one NEW entry is `test_workshop_paid_professional…test_current_generic_draft_cas_reuses_real_reader_with_bounded_paging`. It asserts a `value.businessType == "TOPIC"` literal in a Workshop file this branch does not touch (the diff is only the three files above). It is pre-existing on `origin/ui/main` 6ceb69fc7, not caused here. My one IM regression from the first run (an exact `.onDisappear` token) is fixed.
- Targeted contract suites: OK for test_reference_chat_task, test_acceptance_r2_club_chat, test_im_conversation_reply_policy, test_im_message_visibility, test_accessibility_hardening_wave, test_design_system_component_contracts, test_im_history_bridge, test_group_polls, test_ugc_1_2_completeness, test_rm02_request_reference, test_im_expanded_integration, test_im_conversation_row_actions and test_im_conversation_read_all.

## LOCAL VERIFICATION CHECKLIST (integrator)

Run `--uitesting-module messaging` and `--uitesting-module composer` (fixtures exist), plus a live TEST account.

1. **Row to chat:** tap a row. The inbox title slides into Back the system way, and the avatar + name rise 16 pt into the bar. Edge-swipe back, cancel half-way, release: the swipe follows the finger, and on cancel the chat stays with its title at rest. Go back mid-push: no stuck offset.
2. **Long and short names:** a long nickname in the bar still truncates the same (`cyWrapText`). An AX text size hides the name as before.
3. **Missing images:** avatars are always the `CYIMCoverArt` symbol, so nothing changes. Group rows show `person.3.fill`.
4. **Send short text:** the spinner sits in the accent circle and the text stays in the field (grey). On ack the bubble rises from the field's trailing edge into the last slot, the others move up, the arrow returns grey, and the receipt fades in the field. Scrub at 10% speed (mifb): the ghost should be gone by about a third of the move, and the bubble must not change size.
5. **Send 5-line text:** the ghost wraps the same as the field (lineLimit 1...5). The bubble lands with its full height.
6. **Empty chat (first message), first and last item:** the bubble lands in an empty transcript, and the empty hint leaves with a fade.
7. **Scrolled up, then send:** the transcript animates to the newest. The bubble should still read as coming from the field. Check that it is not clipped strangely behind the composer.
8. **Fast repeated taps:** a second send while sending is disabled (unchanged). Send, then send again right after the ack: the first landing finishes, and the second ghost replaces any leftover.
9. **Rejected / outcome unknown / pending fixtures** (`--reference-message-rejected`, `--reference-message-unknown`, `--reference-message-pending`): the ghost fades, the issue row with pending text and Retry shows as before, and the existing UI tests pass (`ReferenceChatTaskFlowTests`, `ModuleFlowTests` 365).
10. **Pull to refresh in a ready chat:** the transcript does not blank. New messages scale/fade in and the scroll ends at the newest (as before). In an error state, pull still runs the full reload.
11. **Load earlier:** tap the top row, scroll a little while it loads, and the message you are looking at stays put. Earlier rows appear above with no slide. A failure shows the existing error row.
12. **Unread badge:** change a count in place (fixture or live) and the digits roll down. At 0, the badge and avatar dot scale and fade out. 99+ and the em dash still render.
13. **Light and dark:** the ghost uses `.secondary` and the receipt sits on `bgRaised(in: domain)` (same as the field), with no seams in either mode.
14. **Reduce Motion** (system, in-app, or `--uitesting-reduce-motion`): no matched move (namespace nil), the bubble and ghost cross-fade, rows fade, badge digits cross-fade, the send button swaps without scale or blur, and the title rise is off.
15. **VoiceOver:** Send reads "Send", and "Sending…" while sending. The receipt text is reachable in the field area. Focus after a send stays on Send (unchanged). The ghost is hidden from VoiceOver. Row to chat: focus lands as with the system push.
16. **At rest:** the inbox rows, the chat transcript and an idle composer look exactly as before. The only at-rest difference is the post-send receipt inside the field instead of a row above it, as requested.
