# Worker G2 Report — Real Club/Channel Moderation & Rules Gate (`task_076e269e76e5`)

## 1. Defects Resolved

1. **False Moderation Success Claims (`App/ClubChannelMessagingView.swift:~398-430`)**:
   - **Before**: `submitMessageReport`, `submitUserReport`, `toggleBlockSender`, `toggleMuteChannel`, `deleteMessage`, and `removeMember` constructed a `ChannelSafetyModerationEndpoint`, discarded it via `_ = endpoint`, mutated local UI state immediately, and displayed `"Report submitted. Our safety team will review it within 24 hours"` without any Core/backend service call.
   - **After**: All moderation handlers (`reportMessage`, `reportUser`, `reportChannel`, `setSenderBlocked`, `setChannelMuted`, `deleteMessage`, `removeMember`, `banMember`, `unbanMember`) route asynchronously through `@StateObject private var moderationCoordinator: ClubChannelModerationCoordinator` backed by `ClubChannelSafetyServing` (`CoreClubChannelSafetyService`). Success banners and state mutations occur **only** after the underlying Core service returns without throwing; service or policy errors display an error banner (`club.channel.moderation.banner`) with an interactive **Retry (`重试` / `Retry`)** button (`club.channel.moderation.retryButton`) wired to `moderationCoordinator.retryLastFailedAction(locale:)`.

2. **Hardcoded Channel IDs `101 / 102 / 103` (`App/ClubChannelMessagingView.swift`)**:
   - **Before**: `ClubChannelMessagingHostView.loadChannelContext()` always called `ChannelDirectoryListing.defaultClubChannels(clubID:clubName:locale:)` with hardcoded IDs `101`, `102`, `103` and hardcoded messages.
   - **After**: `ClubChannelMessagingHostView.loadChannelContext()` calls `safetyService.loadChannelWorkspace(club:viewerMemberID:)`, which loads the club's real channel directory from `NativeChannelManagementCoordinator` (`service.directory()`) and/or `MessagingReading.messagingConversations()` projected via `NativeChannelSpace.project`, plus per-channel message history via `MessagingReading.messagingMessages(conversationID:cursor:)` and active bans via `ClubGovernanceAccess.read(.bans, ...)`. Synthetic fixtures are restricted to `#Preview` / XCTest helpers (`isPreviewOrTestFixture`).

3. **Bypassed Rules/EULA Gate (`Core/ChannelDiscordMessaging.swift`)**:
   - **Before**: `ChannelSafetyModerationPolicy.init` defaulted `hasAcceptedChannelRules: Bool = true`.
   - **After**: `ChannelSafetyModerationPolicy.init` defaults `hasAcceptedChannelRules: Bool = false`. Added `ChannelRulesAcceptanceStoring` (`UserDefaultsChannelRulesAcceptanceStore` and `InMemoryChannelRulesAcceptanceStore`) keyed by `(accountID, clubID, rulesVersion)`. When `hasAcceptedRules == false`, `ClubChannelMessagingView` renders the rules acknowledgement gate banner (`club.channel.rulesGate` / `club.channel.rulesGate.accept`) and locks the message composer (`club.channel.composer.rulesLocked`) and moderation actions until explicitly accepted.

4. **Missing Channel Reporting (`Core/ChannelDiscordMessaging.swift`, `App/ClubChannelMessagingView.swift`)**:
   - **Before**: Only message and user reporting existed in `ChannelSafetyModerationEndpoint`.
   - **After**: Added `.reportChannel(clubID: Int, channelID: Int, reasonCode: String, detail: String)` to `ChannelSafetyModerationEndpoint`, `validateReportChannel(channelID:reasonCode:detail:)` to `ChannelSafetyModerationPolicy`, `reportChannel` to `ClubChannelModerationCoordinator`, and UI triggers in both the channel header bar (`club.channel.reportChannelButton`) and channel sidebar context menu (`club.channel.reportChannel.menu`).

5. **Blocked User Content Hiding & Admin Tools (`Core/ChannelDiscordMessaging.swift`, `App/ClubChannelMessagingView.swift`)**:
   - **Blocked Users**: Added `ChannelBlockedUsersStoring` (`UserDefaultsChannelBlockedUsersStore` / `InMemoryChannelBlockedUsersStore`) so blocked sender IDs persist across sessions and immediately hide all messages from blocked senders in the active transcript via `ChannelContentFilterHook.filterTranscript`.
   - **Admin Tools**: Added admin message deletion (`deleteMessage`) on any member's message, plus member removal (`removeMember`), member banning (`banMember`), and member unbanning (`unbanMember` with an **Active Bans (`封禁名单（管理员）` / `Active Bans (Admin)`)** section) in `ClubChannelMemberRosterSheet`.

## 2. Coordinator / Worker G1 Composition Root Hook

Per task rules, `App/AppSession.swift`, `App/AppCompositionRoot.swift`, and `App/RegionalLaunchConfiguration.swift` were **not** modified.
Instead, `App/ClubSafetyComposition.swift` exposes `ClubSafetyComposition.makeSafetyService(session:club:management:community:)` and `AppSession.makeClubChannelSafetyService(club:management:community:)`.

To wire custom/approved Core safety writers in `AppCompositionRoot` / `AppSession` (owned by G1), add the following one-line property hook in `AppCompositionRoot` (or `AppSession`):

```swift
var clubChannelSafetyServiceFactory: @MainActor (AppSession, ClubRecord, ClubManagementContext?, ClubCommunityContext?) -> any ClubChannelSafetyServing = { ClubSafetyComposition.makeSafetyService(session: $0, club: $1, management: $2, community: $3) }
```

And in `AppCompositionRoot.makeSession(...)` when constructing `IMSafetyWriter`, `ClubGovernanceService`, and `ClubManagementService`, G1's non-nil runtime approvals (`IMSafetyWriteApproval`, `ClubGovernanceWriteApproval`, `ClubManagementApproval`) automatically flow into `ClubSafetyComposition.makeSafetyService` via `session.imSafetyWriter`, `session.imExpandedWriter`, `session.messageWriter`, `session.messagingReader`, and `management?.governance`.

## 3. What Remains Dead / Needs G1 Runtime Approval Wiring

- `AppCompositionRoot` (owned by G1) currently initializes `IMSafetyWriter`, `ClubManagementService`, and `ClubGovernanceService` with default `nil` runtime approvals until G1 wires the live session approval grants in `AppCompositionRoot.swift` / `AppSession.swift`. When those approvals are `nil`, `CoreClubChannelSafetyService` honestly throws `ChannelSafetyServiceError.serviceUnavailable` and the UI displays the error banner with retry instead of faking success.
- Dedicated server-side channel report (`POST /api/im/channel/report`) and admin message delete (`POST /api/im/channel/message/delete`) endpoints fall back to `IMSafetyWriting` (`POST /api/im/report` and `POST /api/im/conversation/hide`) unless custom closures (`channelReportDispatcher`, `channelMessageDeleteDispatcher`) are supplied to `CoreClubChannelSafetyService`.

## 4. Verification Gates

- **SwiftPM Core Tests**:
  - Command: `swift test --filter 'ChannelDiscordMessagingTests'`
  - Result: `Executed 15 tests, with 0 failures (0 unexpected) in 0.019 (0.020) seconds` (`TEST_EXIT=0`)
- **Serialized Xcode iOS Simulator Build**:
  - Command: `xcodebuild -project Questify.xcodeproj -scheme Questify -destination 'generic/platform=iOS Simulator' -derivedDataPath /private/tmp/questify-derived-shared CODE_SIGNING_ALLOWED=NO -UseModernBuildSystem=YES -parallelizeTargets -jobs 4 build`
  - Result: `** BUILD SUCCEEDED **` (`BUILD_EXIT=0`)
- **Scaffold & Localization Gate**:
  - Command: `/Users/fanning/.local/bin/python3.12 tools/check_scaffold.py`
  - Result: `PASS structural checks: 4117 Swift source files, 13462 bilingual keys, references, scheme, read-only expected project equivalence` (exit 0)
