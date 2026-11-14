# ui-cur-analytics

Branch `ui/cur-analytics`. Parent `9209d33cb2d7ceed6f95a1b9d90b556e531a63b0` (`origin/ui/main`).

Source: `chengyinhub-xcx/utils/analytics.js` (`ALLOWED_EVENTS`, queue `p3_analytics_queue_v1`, `MAX_QUEUE` 100, `MAX_BATCH` 50, one batch in flight, ack only when the batch is accepted) and every production `track` call under that repo. `AnalyticsEventClient` already implements that queue, allow-list, sanitizer, and `flush`. New call sites only call `track`, which enqueues and flushes. They do not POST events one by one.

`activity_update_success` is passed to `track` from `pages/publish/activity/index.js` when an activity is edited. It is not in `ALLOWED_EVENTS`, so `track` drops it. It is not sent.

`swiftc` is not installed on this machine, so `swiftc` / `xcodebuild` / XCTest were not run.

## Events added

Each row is a new `AnalyticsEventClient.track` at a native action that already existed. `bizId` uses the mini-program rule (`value || null`): missing or non-positive ids are omitted. `name` is still passed where the mini-program passes it; the existing sanitizer drops that key.

| Event | Native site | Parameters sent |
|---|---|---|
| `content_share` | Activity detail share button | `bizType` `activity`, `bizId` activity id, page `/pages/activity/detail/index` |
| `content_share` | Square detail paper-plane | `bizType` `square`, `bizId` post id, page `/pages/square/detail/index` |
| `signup_submit` | Free registration response (`responseReceived` without pay params) | `bizType` `activity`, `bizId` activity id, `properties.registrationId`, `properties.payableAmount` when present, `idempotencyKey` `signup_submit_registration_<id>` (`eventKey`), page `/pages/activity/baoming/baoming` |
| `topic_publish_success` | Creator tools draft publish after a receipt appears | `bizType` `topic`, `bizId` topic id, `properties.name`, page `/pages/publish/fabu/index` |
| `activity_publish_success` | Activity publish receipt with a committed activity id | `bizType` `activity`, `bizId` activity id, `properties.name`, page `/pages/publish/activity/index` |
| `template_reuse` | Template use when `scope != "my"` | `bizType` `template`, `bizId` template id, page `/pages/templatedetail/templatedetail` |
| `coupon_verify` | Coupon publish confirm after `acknowledgedDefinitionID` | `bizType` `coupon`, `bizId` definition id, `properties.action` `coupon_publish`, `name`, `publishCount`, `couponType`, page `/subpackageMember/couponInfo/couponInfo` |
| `withdrawal_submit` | Bank withdrawal submit success | `bizType` `withdrawal`, `bizId` application id, `properties.amount`, page `/subpackageA/pages/assetcenter/earnings/index` |
| `roam_start` | Roam browser first appear | `bizType` `roam`, page `/pages/roam/index` |
| `roam_poi_found` | Discover button after a new confirmation | `bizType` `roam`, `bizId` place id, page `/pages/roam/index` |
| `roam_finish` | Settled session | `bizType` `roam`, `bizId` server session id, `properties.shops`, `properties.pois`, page `/pages/roam/index` |
| `roam_route_story_shown` | Finish report when the story is non-empty | `bizType` `roam`, page `/pages/roam/index` |
| `roam_poi_meaning_shown` | Place-memory section appear | `bizType` `roam`, page `/pages/roam/index` |
| `roam_share_channel` | Photo save (`保存`) and album guides (`朋友圈`, `小红书`) | `bizType` `roam`, `bizId` server session id, `properties.channel` raw label, page `/pages/roam/index` |
| `roam_share_complete` | Same actions when the save succeeds | `properties.channel` `album` / `moments` / `xhs` |
| `roam_share_fail` | Same actions when the save fails | `properties.channel` code, `properties.reason` `failed` |
| `npc_profile_loaded` | Roam NPC coordinator after a profile id | `bizType` `roam`, `bizId` session id, page `/pages/roam/index` |
| `npc_bubble_impression` | Roam NPC coordinator after the line is shown | `bizType` `roam`, `bizId` session id. `eventType` and `lineLen` stay off the wire, matching `normalizePayload`, and the line text is not sent |

## Events already present

`FinishRouteAnalyticsModifier` on `PlayFinishRouteCardView` already sends these. They were not added again.

- `finish_route_recommendation_shown`
- `finish_route_recommendation_click`

## Events skipped because there is no native call site

Production mini-program calls with no matching native action:

- `payment_success` — paid signup has no native pay-success callback
- `square_share_complete`, `square_share_fail` — the square share sheet has no success or cancel callback
- `chapter_blocks_parse_failed` — no chapter-block parse reporter
- `node_abandon`, `play_rec_accept` — no play-page abandon or recommended-node accept
- `roam_footprint_hint_shown`, `roam_footprint_hint_dismissed` — no footprint hint
- `roam_discover_reward_click` — no discover-reward card
- `roam_exploreday_reco_shown`, `roam_exploreday_reco_click` — no explore-day recommendation
- `npc_chat_submit`, `npc_chat_complete`, `npc_chat_cancel` — merchant NPC chat is not the roam chat sheet
- `roam_share_channel` / `roam_share_complete` / `roam_share_fail` for channel `广场` — no native square post from the roam share card. The system share sheet is not one of `广场` / `保存` / `朋友圈` / `小红书`, so it sends nothing

Allow-listed names with no production `track` call (tests only, or the allow-list alone):

- `search_submit`, `content_view`, `content_like`, `content_favorite`
- `solo_ticket_purchase`, `play_arrive_success`, `play_arrive_fallback`, `drop_shown`
- `citymap_view`, `citymap_share`, `track_record_start`, `track_record_finish`, `track_to_topic`
- `xp_alloc_done`, `become_leader_cta`, `play_rec_swap`, `npc_chat_open`
