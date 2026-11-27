# Receipt: design round 2, social (`design/r2-social`)

Brief: `origin/design/handoff-r2:docs/briefs/round2-1127.md`, row `design-r2-social` (P13 items left open in `design-pass-social.md`). Principles: `design-principles.md` P6, P7, P11, P12, P13.
Base: `origin/ui/combined-r7`. Date: 2026-11-27. No Swift compiler in the cloud. Every API was checked by grep against existing call sites. **Run `build_sim` before merging.**

## Done

| Item | What changed | MP source | Files |
|---|---|---|---|
| **P13 one-tap answers in the chat** | A card that carries answers now shows them in the transcript under the bubble (`MessagingInlineCardAnswers`): the first non-reject answer is a prominent capsule, the rest are `.bordered` capsules (reject answers are `.destructive`). They sit side by side, or stack through `ViewThatFits` when the English is too long. They sit outside the row's `NavigationLink`, so tapping the bubble still opens the detail page. The `IMCardDestination` handling moved up into `MessagingHistoryView`, which has one `navigationDestination(item: $cardRoute)` with three cases: `.topic` → `TopicDetailView`, `.review` → the message detail (it owns the review sheet), and `.poll` → the poll. It uses the detail page's checks and broadcast-click report. The bubble drops its 「点开即可回应 / Tap to respond」 hint when the answers are shown inline. | `im/chat/index.wxml:135-137` draws `genericButtons` inside the card. `onCardBtn` (`index.js:1174`) only navigates, so the app's answers only navigate too. | `App/NativeR2/Social/MessagingCardAnswers.swift` (new), `App/MessagingHistoryView.swift` |
| **Polls answer in place** | A group poll message (type 4) gets a 「去投票 / Vote」 capsule that opens `GroupPollView` in one tap, with the same `current` guard as the detail page. The vote itself still goes through the poll's own review and confirm step, which is the write-safety contract. | The MP has no chat polls. This is native-only and was already shipped. | same |
| **Quiet system line after an answer** | `MessagingQuietSystemLine`: one small, secondary, centred line that wraps. It appears (a) after the viewer picks one of two or more MP buttons: 「你选择了「接受」 / You chose “Accept”」. Only the MP's own button text is used, never the generic 查看详情 fallback. (b) After the viewer comes back from a poll they voted in: 「你投给了「X」 / You voted for “X”」. This one is read from the `myOptionId` the poll coordinator already holds, with no extra request. Both lines are kept for this session only and are cleared when the identity changes. | MP answers write nothing, so there is no server record. The line records what this viewer tapped and does not claim a write. | same |
| **Club header face pile on every tab** | The member strip now loads once when the club opens, whatever the tab, with a key that does not depend on the tab, so switching tabs neither reloads nor clears it. The inline leaderboard still loads only on 概览. A tab switch while the strip is loading cancels the task, so cancelling now releases the key and the next tab loads it again (before, the strip could stay empty). | `club/detail/index.js:2226`: `if (canSeeRoster) that.loadMembers();` runs at detail load for any tab. | `App/ClubDetailView.swift` (`loadR8Mounts`), `App/ClubDetailR8Mounts.swift` (`loadMemberAvatars`) |
| **P7 at the first club join** | The MP's "first entry after joining" welcome (`maybeWelcome`, shown once per person per club) was already ported as `ClubMemberWelcomeSheet`, but it had no moment. Now the club symbol springs in and bounces once (`symbolEffect(.bounce)`), together with the existing success haptic. With Reduce Motion it appears in place with no bounce. There is no confetti, because `CYConfettiBurst` is deliberately empty in native r2. The stale "confetti" doc comment was corrected. | `club/detail/index.js:2593-2633` (`welcomeSeenKey`, `maybeWelcome`, `openWelcome`) | `App/ClubMemberWelcomeSheet.swift` |

Strings: 4 keys (`r2social.*`) in zh-Hans and en, fragment `docs/port/strings/design-r2-social.json`, merged into `Resources/Localizable.xcstrings` with `tools/merge_localization_fragments.py` (4 added, 0 overridden).

## Not done

- **P7 at the first post**: the MP has no first-post moment (a grep of `mp-source` for firstPost / 首帖 / 首次发帖 found nothing), so nothing was invented.
- **A shared "X is going" line for everyone**: MP card answers are navigations, not writes, and the server records nothing, so other members cannot see a viewer's choice. A shared line needs a backend event, so it was not faked.
- **Team and friend invites stay two taps.** They live outside the chat (friends → 队伍邀请), and the review/confirm step is a write-safety contract, kept on purpose as in round 1.
- **The type 9 poll result card** still opens through the bubble → detail. Only type 4 polls got the inline capsule.

## Risks for the first compile

- `MessagingQuietSystemLine<Content>` uses `@ViewBuilder let content: () -> Content` with the memberwise init (SE-0289) and a trailing-closure call.
- `MessagingInlineCardAnswers` / `MessagingInlinePollAnswer` have an `@ScaledMetric private var` with a default value and are built cross-file through the memberwise init. This is the same pattern as `MerchantMPIcon`.
- `MessagingHistoryView`: the `let answersInline / isOwnRow / isNoticeRow` declarations inside the `VStack` builder, `if … else if expanded?.pollCoordinator != nil, …` (a double optional flattened by `?.`), and `.onChange(of: cardRoute) { old, new in if new == nil, case .poll(let id) = old { … } }`.
- `.symbolEffect(.bounce, value: arrived && !reduceMotion)` on an `Image` that also has `.scaleEffect` and `.opacity`.

## Gates

- `python3 tools/generate_project.py`: 4076 native sources. The new file is under `App/NativeR2/**`.
- `python3 tools/check_scaffold.py`: PASS structural checks (19904 bilingual keys), typography lint PASS.
- `python3 -B tools/check_a11y_lint.py`: PASS, 0 new.
- `python3 -B tools/contract_ratchet.py --check`: RATCHET_RESULT

## For the coordinator

- No capabilities, entitlements or deploys. Merchant and the story-flow theme were not touched.
- UI test ids added: `messaging.card.inlineAnswers.<id>`, `messaging.card.choiceLine.<id>`, `poll.inlineEntry.<id>`, `poll.votedLine.<id>`. The existing `messaging.message.<id>`, `messaging.card.respondHint` and `club.detail.header.people` are unchanged.
