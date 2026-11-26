# Receipt: cursor/r9-player-content

- Branch: `cursor/r9-player-content`
- Base: `d9115273d70e5b88343b2a14f81d111bf515c561` (`ui/combined-r7` at start). Not rebased.
- Implementation SHA: `c9da95476cb8b7203b89cd8202c0220d0cc84a2e`
- Audit: `origin/audit/parity-r9-player-content` `docs/audit/parity-r9/player-content.md`. Owner column exactly `Cursor Core`.
- Mini-program: `liboyang42-cpu/hengyin` `chengyinhub-xcx` at `25eb6a0c1fbae79f124f109e19f7b7f97fd06aaf`.
- `App/AppSession.swift` stays 7994 lines. `App/AppCompositionRoot.swift` stays 4177 lines. `tools/check_appsession_ratchet.py` was not edited.
- `project.pbxproj` and `tools/current_ci_manifest.json` were not edited. No new Swift file.
- swiftc was not run. This receipt does not claim a parse.
- `pricingGrantEnabled` and `moneyEnabled` stay false. Quote, registration create, pricing confirm, pay, refund, payout, withdrawal, and gift claim do not build or send. Chapter invite, respond, apply, and withdraw stay false.

## Owned rows

| id | status | SHA | file:line |
|---|---|---|---|
| R8-PC-B1-1 | blocked | c9da95476cb8b7203b89cd8202c0220d0cc84a2e | `Core/PlayerContentMPContract.swift:158` throws `Refusal.moneyDisabled` before a request. `App/GlobalSearchLinksAndTemplates.swift:530` still catches that and throws `TopicSelfPlayFailure.unavailable`. Create is not sent. |
| R7-PC-B2-1 | blocked | c9da95476cb8b7203b89cd8202c0220d0cc84a2e | `Core/MerchantContentService.swift:124` keeps `chapterInvite`, `chapterRespond`, `chapterApply`, and `chapterWithdraw` default `false`. Invite, respond, apply, and withdraw stay off. |
| R7-PC-B4-1 | blocked | c9da95476cb8b7203b89cd8202c0220d0cc84a2e | `Core/PlayerContentMPContract.swift:12` `pricingGrantEnabled` stays false. `Core/RuntimeDependencyConfiguration.swift:115` still returns reads, ownership, and graduation only. No pricing publisher grant. |
| R8-PC-B4-1 | blocked | c9da95476cb8b7203b89cd8202c0220d0cc84a2e | `App/PublisherLifecycleViews.swift:281` `beginConfirm` does not call `coordinator.confirm`. `Core/PlayerContentMPContract.swift:396` still throws `Refusal.pricingGrantDisabled`. |
| R7-PC-A8-1a | fixed | c9da95476cb8b7203b89cd8202c0220d0cc84a2e | `Core/PublicTopicTemplateDetail.swift:126` `PublicTemplateNode.game` reads `gameTitle`, else `game`. `gameIcon` at line 128. `duration` at line 130 reads `gameDuration`, else `duration`. Blank and bad types stay nil and do not fail the node. The stop pill is not drawn here. |
| R7-PC-B1-4 | fixed | c9da95476cb8b7203b89cd8202c0220d0cc84a2e | Guest `POST api/topic/info-to-user` with a nil token. `App/AppCompositionRoot.swift:692` anonymous content detail is `.available`. `App/AppCompositionRoot.swift:3539` admits a nil-token public viewer for activity and topic info. `App/AppSession.swift:5448` treats a guest with both services as available. `Core/TopicReading.swift:56` no longer requires a session for `topicDetailDocument`. `App/PlatformConsumerSessionOwner.swift:48` opens the detail and routes 收藏 / buy / review through `promptGuestSignIn`. `App/TopicDetailView.swift:16` and `App/TopicDetailView.swift:640`. Theme history and theme card stay signed in. |
| R7-PC-B1-18 | fixed | c9da95476cb8b7203b89cd8202c0220d0cc84a2e | `Core/TopicContracts.swift:132` decodes the first stop merchant's `mmsMerchant.derivativeBenefits`. `Core/TopicContracts.swift:171` `shopGift`. `Core/TopicXcxFacts.swift:192` `giftStopCount`. `App/TopicXcxSections.swift:546` appends the route-note count. `App/TopicXcxSections.swift:616` shows 到店礼 on the stop row. Display only. Gift claim is not sent. Strings: `docs/port/strings/cursor-r9-player-content.json` (`en` and `zh-Hans`). |
| R8-PC-C6-2 | fixed | c9da95476cb8b7203b89cd8202c0220d0cc84a2e | `Core/OfficialEventService.swift:9` `OfficialReadFailure.explained`. Broadcast stats `get` at line 139 and `recoverBroadcast` at line 90 throw it when `msg` is non-empty. `通知不存在` stays `.unavailable`. Other reads still throw `.rejected`. `Core/OfficialEventContracts.swift:670` `serverNote`. `App/OfficialPrivateViews.swift:228`, `App/OfficialPrivateViews.swift:322`, and `App/OfficialPrivateViews.swift:340` pass that note into `failureLine(serverMessage:)`. |

## Not taken

Owner is not exactly `Cursor Core`:

- R7-PC-C1-5 — `Cursor Core → Claude App`
- R7-PC-C1-6 — `Claude App (picker) + Cursor Core (\`img_arr\`, cap)`
- R9-PC-D5-1 — `Claude App`

`submitNode`, `auditNode`, `cancelRegistration`, `auditApplication`, and `station` were not added.
