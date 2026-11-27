# Receipt · components r1 · lane C5 social (`comp/r1-social`)

Brief: `origin/design/handoff-r2:docs/briefs/components-r1.md` (lane C5: channel messages + community). Base `origin/ui/combined-r7` @ `64a344358`.
Lane C3 (`origin/comp/r1-kit`) had not pushed when this round started, so C5 uses its own small social helpers. When `CYWaveform` / `CYLiveCounter` land, `CYSocialVoiceWaveform` / `CYSocialCountLabel` can wrap them; the call sites stay the same.

## Added

| What | Where |
|---|---|
| `CYSocialVoiceWaveform`: bar waveform for voice notes. It draws the clip's own recorded levels (`IMVoiceReference.waveform`, base64, ≤256 bytes, bucket-max resampled and normalised). With no usable data it uses a stable pattern seeded by the message id. `progress` fills played bars with primary ink and leaves the rest tertiary, so it reads in both sent and received bubbles. Scaled with Dynamic Type; decorative (`accessibilityHidden`). | `App/NativeR2/Social/CYSocialComponents.swift:12` (levels `:35`, seed fallback `:51`) |
| `CYSocialCountLabel`: like / comment / reaction counter. System `Label`, digits roll with `.contentTransition(.numericText(value:))`, compact notation for large counts (1.2K / 1.2万). The symbol swaps (`heart` → `heart.fill`) with `.symbolEffect(.replace)`, bounces once when the viewer's own state turns on, and takes one accent (system red). A zero count shows the MP title (「赞」/「评论」). `QuestifyReduceMotion` makes every change instant. | `App/NativeR2/Social/CYSocialComponents.swift:70` |
| `CYSocialVoiceProgress.fraction`: the played share for a TimelineView. | `App/NativeR2/Social/CYSocialComponents.swift:107` |
| `#Preview("Social components")`: dark, with real-sample, seeded, liked, 1.2k and zero states. | end of the same file |

## Adopted

- **Channel voice bubble**, `NativeChannelInlineVoiceView` (`App/NativeChannelInlineMediaViews.swift:133-175, 211, 247`). The animated `waveform` SF Symbol is replaced by `CYSocialVoiceWaveform` inside a `TimelineView(.animation(minimumInterval: 1/15, paused: !playing))` that fills as the clip plays (1 s steps under Reduce Motion). While the clip plays, the duration becomes a system countdown, `Text(timerInterval:countsDown: true)`, so the view keeps no per-second state. Playback, the authorize → read → re-authorize sequence and the per-second authorization re-check are unchanged.
- **Club community post action bar**, `ClubCommunityPostRow` (`App/ClubCommunityViews.swift:658, 666, 749`). 赞 · n and 评论 · n use `CYSocialCountLabel`, and the liked heart fills, tints and bounces. The cross-club count row uses it too. The unused `countedTitle` helper is removed. Write paths (`model.prepare(.toggleLike…)`) are untouched.
- **Comment thread**, `ClubPostDiscussionPanel` (`App/ClubPostDiscussion.swift:91-97, 112-115`). The thread title shows the comment count (rolling digits), and each comment is drawn as a received-style bubble (`.fill.quaternary`, 16 pt continuous corners). Content follows the MP `pages/club/detail/index.wxml:137`: name and text only, with no time.
- **Unread badges**:
  - `IMUnreadBadge` (`App/IMInboxViews.swift`) already had `.numericText` but no animation driving it. It now has `.animation(.snappy, value: text)`, which is instant under Reduce Motion, so inbox rows, entry badges and in-game channel entries roll when the count changes.
  - The channel history's remaining-unread readout (`App/NativeChannelHistoryView.swift:116`) gets the same content transition.
  - The club channel list keeps the system `.badge`.

## MP references

- `subpackageB/pages/im/chat/index.wxml`: bubbles keep "received on the left, sent on the right". There are no typing or presence indicators and no message reactions in the MP chat, so C5 adds none (the brief says "where MP has it").
- The MP IM has no voice messages. The native voice bubble is a native superset (G-024), and this round only restyles its waveform and time.
- `pages/club/detail/index.wxml:137-142`: comment rows show the name and content plus delete/report. The existing safety menu is kept.
- MP cy-post-card 赞/评论: the count rides on the action label, and the title shows when the count is 0.

## Gates (run before push)

- `python3 tools/generate_project.py` adds the new file under `App/NativeR2/**`.
- `python3 -B tools/check_scaffold.py`: PASS structural checks.
- `python3 -B tools/check_a11y_lint.py`: PASS, 0 new.
- `python3 -B tools/contract_ratchet.py --check`: see the push commit; new findings must be 0.
- No new strings. Every label reuses existing keys (`club.community.like`, `club.community.comments`, `d7.imVoice.*`).
- No compiler in the cloud. APIs were grepped and checked against iOS 17: `symbolEffect(_:options:value:)`, `contentTransition(.symbolEffect(.replace))`, `numericText(value:)`, `Text(timerInterval:countsDown:)`, `TimelineView(.animation(minimumInterval:paused:))`, `IntegerFormatStyle.notation(.compactName)`.

## For the coordinator

- No capabilities, entitlements or profiles are needed for this lane.
- Please build `Questify` once. The likeliest compile-risk spots are `CYSocialCountLabel.icon` (`AnyShapeStyle(ForegroundStyle())`) and the `TimelineView` closure in `NativeChannelInlineVoiceView`.
- C3 follow-up: once `CYWaveform` / `CYLiveCounter` exist, make the two C5 views thin wrappers over them.
