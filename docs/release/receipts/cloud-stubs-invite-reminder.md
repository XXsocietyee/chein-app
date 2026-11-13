# Cloud stubs — IM invite reminder (ledger row 30)

Branch `ui/cloud-stubs-invite-reminder`. Parent `origin/ui/next` `11e7c2c4559ee3a210fdcfacf8abee717c312ff9`.

Stub-ledger row 30 only. `SessionMessagingHome` still calls `IMCoopInviteStripFactory.make(reader: session.cooperationReader)` once and still writes that closure to `\.imCoopInviteStrip`. The same home now holds one `IMInviteReminderController` and writes it to `\.imInviteReminder`. No second factory call. `App/AppSession.swift`, `App/AppCompositionRoot.swift`, and `Core/ChinaReviewedRouteCapability.swift` are unchanged. No route was marked live. The contract-failing baseline was not raised.

The mini-program does not store a preference. `subscribe.request(['coopInvited'])` is a one-shot WeChat card. This switch does not write a server preference and does not register a push topic. `registerForRemoteNotifications` is not called. No `UNNotificationRequest` is scheduled.

The choice is `UserDefaults` key `imCoopInviteReminderEnabled` on this device. Turning it on reads notification authorization. When that status is not determined, the existing `CYPermissionSystemPrompt.precede(.notification)` card runs before `requestAuthorization`. A denied card, or no window scene to present the card, leaves the switch off and does not request permission. XCTest still skips the card, matching the existing primer. An already-authorized visible alert stores the local choice without a second prompt. Provisional, ephemeral, denied, and alerts-off stay off. Turning the switch off clears only the local choice.

Unknown authorization, or an authorized status whose alert setting cannot be classified, stays unknown. The switch is off. The caption is an em dash (U+2014) in English and Simplified Chinese. VoiceOver uses “Invite alert status unknown” / “邀约提醒状态未知”. The on and denied captions are not used for that state.

## Copy

Table `Resources/Localizable.xcstrings`:

| Key | en | zh-Hans |
|---|---|---|
| `mpd.im.inviteReminder.unknown` | — | — |
| `mpd.im.inviteReminder.unknownLabel` | Invite alert status unknown | 邀约提醒状态未知 |

`mpd.im.inviteReminder`, `.on`, and `.denied` were already in that table.

## Files

- Changed: `App/SessionMessagingEntry.swift`, `App/IMDriftEntries.swift`, `Resources/Localizable.xcstrings`, `tools/add_mp_drift_localizations.py`, `Tests/ContractChecks/test_im_coop_invite_strip_wiring.py`, `Questify.xcodeproj` (regenerated).
- Added: `App/IMInviteReminderController.swift`, `Tests/AppUnitTests/IMInviteReminderControllerTests.swift`.
- Not touched: `App/AppSession.swift`, `App/AppCompositionRoot.swift`, `Core/ChinaReviewedRouteCapability.swift`.

`tools/check_scaffold.py` and `tools/check_design_lint.py` passed before push. The contract check `Tests/ContractChecks/test_im_coop_invite_strip_wiring.py` passed. This VM has no Swift compiler, so `IMInviteReminderControllerTests` was not executed.

## 中文

只补账本第 30 行。消息首页仍只调用一次 `IMCoopInviteStripFactory.make(reader: session.cooperationReader)`。同一页放入 `IMInviteReminderController`，写入 `\.imInviteReminder`。没有服务端偏好，也没有推送主题。说明卡被拒绝，或没有窗口可以展示说明卡时，开关保持关闭，不会当成已经授权。读不到通知权限时，开关关闭，说明是破折号「—」（英文和简体中文相同），旁白为 “Invite alert status unknown” / “邀约提醒状态未知”。`AppSession` 与 `AppCompositionRoot` 没有加行。合同失败基线没有上调。本机没有 Swift 编译器，所以 `IMInviteReminderControllerTests` 没有执行。`tools/check_scaffold.py` 与 `tools/check_design_lint.py` 已通过。
