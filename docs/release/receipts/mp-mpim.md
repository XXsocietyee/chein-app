# mp-mpim receipt: message channel / IM parity (layout side)

Source: liboyang42-cpu/hengyin chengyinhub-xcx `subpackageB/pages/im/list` and `im/chat` (WXML+WXSS read; page JS not translated).

## Mapping
| mp | native |
|---|---|
| im/list conversation row (avatar, name, 官方 tag, mute, time, preview, unread badge, swipe read/mute/delete) | `App/MessagingHomeView.swift`, `App/IMInboxViews.swift` `IMInboxRow` (already matched; added cy-fly-in rise, Reduce Motion safe) |
| im/list tabs, empty/error/skeleton/login states, channel grouping | `MessagingHomeView` (already matched) |
| im/chat hero name under nav | `MessagingHistoryView.transcript` hero (`messaging.history.hero`) |
| im/chat system notice full-width card | `MessagingBubble.noticeCard` for `.system` conversations |
| im/chat bubbles, composer (+ and send inside field), loadMore, 4-state empty, disabled/readonly notices | already present (`ChatMessageBubble`, `MessageActionComposer`, `NativeChannelTextComposer`, `MessagingHistoryView`) |

## Changed
- `App/MessagingHistoryView.swift`, `App/IMInboxViews.swift`. No new keys, no new files. Lint and scaffold checks pass; not compiled (integrator).

## Needs logic / Cursor
- Optimistic `sending` spinner and `failed` tap-to-resend on own bubbles (needs pending-message state from `MessageActionCoordinator`).
- Inline time beside sender name on received bubbles (mp `name · time`); native keeps tail timestamp + day dividers.
- Location/route/signup card messages (mp msgType 3) as left/right cards with route fetch cache: native has `IMStaticLocationCardView`; route/signup cards need a topic reader binding.
- "Refreshing messages" floating pill and refresh-failed-keep-list inline error need a `MessagingReadScreenModel` refresh state.
- Route picker sheet for sending a route card; privacy gate sheet; "我的举报" entry row in system chat (report-notices data).

## MISSING (noticed, no native counterpart verified)
- Predict-inbox row (`canSettlePredict`) exists via `predictionEntry`; merchant invite strip via `imCoopInviteStrip` (merchant surfaces stay hidden behind merchantSurfaceHiddenInV1).
- Full app.json page audit was not done in this brief; only IM pages were audited.
