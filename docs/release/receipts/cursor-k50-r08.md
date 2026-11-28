# K50-R8 mini-program analytics equivalents

Branch `cursor/1128-k50-r08`. Base `origin/ui/combined-r7`. The private hengyin tree was not read. Every event name below is already a string in this repo (`Core/AnalyticsEventClient.swift` allow-list, `Core/PlayGameStage.swift`, or `docs/release/receipts/ui-cur-analytics.md`). No other name was added.

Counts: **matched 21**, **added 9**, **not-found-in-repo 28**.

No phone, token, openid, street, shop name, meeting point, or pay parameters are written on the new events. `registrationId` is the same integer property `signup_submit` already sends on `/pages/activity/baoming/baoming`.

## Gates

`python3 tools/check_scaffold.py` PASS (AppSession.swift 7976 lines, ceiling 7977). `python3 -B tools/check_a11y_lint.py` 0 new. `python3 tools/contract_ratchet.py --check` 46 failing, baseline 46, new 0. No new `String(localized:)`. No `xcodebuild`.

`PlayerLaunch.merchantCenterEnabled` stays `false` outside `DEBUG || TEST` (`Core/PlayerLaunch.swift`). `RuntimeDependencyConfiguration` init order stays `devices`, `sensors`, `artworkHosts`. Pay amounts, pay calls, and money switches were not edited. The new `payment_success` calls run only after the existing server-paid transition.

## matched

These already have an app `track` the allow-list accepts. Not edited.

| Event | App site |
|---|---|
| `content_share` | `App/ActivityDetailView.swift`, `App/SquareDetailView.swift` |
| `signup_submit` | `App/RegistrationSheetView.swift` |
| `topic_publish_success` | `App/TopicCreatorToolsView.swift` |
| `activity_publish_success` | `App/PublishingModesViews.swift` |
| `template_reuse` | `App/TopicTemplateUseSection.swift` |
| `coupon_verify` | `App/CouponManagementView.swift` |
| `withdrawal_submit` | `App/BankWithdrawalView.swift` |
| `finish_route_recommendation_shown` | `App/PlayerParityBViews.swift` |
| `finish_route_recommendation_click` | `App/PlayerParityBViews.swift` |
| `roam_start` | `App/RoamBrowserView.swift` |
| `roam_poi_found` | `App/RoamLiveSessionView.swift` |
| `roam_finish` | `App/RoamLiveSessionView.swift` |
| `roam_route_story_shown` | `App/RoamFinishReportView.swift` |
| `roam_poi_meaning_shown` | `App/RoamLiveSessionView.swift` |
| `roam_share_channel` | `App/RoamHistoryShareView.swift` (includes channel `广场`) |
| `roam_share_complete` | `App/RoamHistoryShareView.swift` |
| `roam_share_fail` | `App/RoamHistoryShareView.swift` |
| `npc_profile_loaded` | `Core/G6NPCPresence.swift` |
| `npc_bubble_impression` | `Core/G6NPCPresence.swift` |
| `finish_offer_shown` | `Core/MPGap/PlayRoam/PlayRoamRound4Models.swift`, `App/JourneyReportViews.swift` |
| `finish_offer_click` | `Core/MPGap/PlayRoam/PlayRoamRound4Models.swift`, `App/JourneyReportViews.swift` |

## added

| Event | What changed |
|---|---|
| `stage_enter` | Added to `AnalyticsEventClient.allowedEvents`. `PlayStageAnalytics.track` already sends it (`Core/PlayGameStage.swift`, gate on, page `/pages/play/index`, bizType `topic_node`, properties `nodeId` / `kit` only). |
| `hint_open` | Same allow-list add. Existing hint-open call. |
| `stage_skip` | Same allow-list add. Existing skip call. |
| `stage_issue_report` | Same allow-list add. Existing report call. Property `issueKind` is one of `ALT_MATERIAL`, `NOT_FOUND`, `UNREADABLE`, `LOGIC_ERROR`. |
| `material_view` | Same allow-list add. Existing material call. |
| `payment_success` | `App/RegistrationAppPayRows.swift` and `App/RegistrationStripePaySection.swift`, once the registration read moves to paid. bizType `activity`, page `/pages/activity/baoming/baoming`, property `registrationId` only. |
| `roam_discover_reward_click` | `App/RoamFirstDiscoverySheet.swift` coupon and task rows (MP 领优惠券 / 做微任务). bizType `roam`, page `/pages/roam/index`, place id only. |
| `roam_exploreday_reco_shown` | Same sheet, when the explore-day row appears. Activity id only. One key per activity id. |
| `roam_exploreday_reco_click` | Same sheet, explore-day row tap. Activity id only. |

`stage_*` / `hint_open` / `material_view` are the five names in `PlayStageEvent` (`Tests/CoreTests/Verify1119PlayKitTests.swift` now asserts they sit on the allow-list). `docs/release/receipts/ui-cur-analytics.md` names `payment_success` and the three roam events as mini-program `track` calls that had no native site at that receipt. The paid transition and the 首次发现 sheet are in the app now.

## not-found-in-repo

No event name was taken from outside this repository. The 28 rows are names this repo already cites, and this repo has no app action that should send them. No call site was added.

`docs/release/receipts/ui-cur-analytics.md` says these allow-listed names have no production mini-program `track` call:

- `search_submit`
- `content_view`
- `content_like`
- `content_favorite`
- `solo_ticket_purchase`
- `play_arrive_success`
- `play_arrive_fallback`
- `drop_shown`
- `citymap_view`
- `citymap_share`
- `track_record_start`
- `track_record_finish`
- `track_to_topic`
- `xp_alloc_done`
- `become_leader_cta`
- `play_rec_swap`
- `npc_chat_open`

The same receipt says these production calls had no native action. That is still true in this tree (no share complete/cancel callback, no chapter-block parse reporter, no play-page abandon, no recommended-node accept, no player NPC chat sheet on `sendDialogue`):

- `square_share_complete`
- `square_share_fail`
- `chapter_blocks_parse_failed`
- `node_abandon`
- `play_rec_accept`
- `npc_chat_submit`
- `npc_chat_complete`
- `npc_chat_cancel`

`docs/audits/1128-ai-inventory.md` still marks the footprint hint missing (copy key `guide.footprint` only). Not sent:

- `roam_footprint_hint_shown`
- `roam_footprint_hint_dismissed`

`activity_update_success` is named in `docs/release/receipts/ui-cur-analytics.md`, which says `pages/publish/activity/index.js` passes it to `track` and it is not in `ALLOWED_EVENTS`, so the mini-program drops it. It was not added to the app allow-list.
