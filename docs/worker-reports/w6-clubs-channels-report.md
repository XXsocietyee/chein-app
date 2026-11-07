# W6 Worker Report — Clubs and Discord-Style Channel Messaging (`task_e9face30a6ad`)

## 1. Summary of Deliverables (Priority Order: 2 → 3 → 1 → 4 + 5)

### Priority 2: Discord-Style Channel Messaging Inside Club Detail
- **Core Domain (`Core/ChannelDiscordMessaging.swift`)**:
  - `ChannelCategoryDirectoryProjection`, `ChannelDiscordCategoryGroup`, `ChannelDiscordItemProjection`: Groups club channels by category (`kind == 0` category headers, `kind == 1` text channels, `kind == 2` read-only announcement channels) sorted by `position` then `id`. Computes per-channel and per-category unread counts and `@mention` badges (`99+` cap via `IMInboxSummary.badgeText`), excludes muted channels (`notifyPref == 2` or local mute override) from club-level unread totals (matching `ImServiceImpl.unreadTotal`), keeps `@mention` badges visible even when muted, and fails closed when `readStateAvailable == false` (never fabricating `0`).
  - `ChannelMessageBurstGrouper`, `ChannelMessageBurstGroup`, `ChannelBurstMessageItem`: Groups consecutive visible messages from the same `senderID` within a 5-minute (`300s`) window into Discord-style author/time bursts, breaking bursts on author changes, `>5m` time dividers (`IMInboxTime.dividers`), system notifications (`senderID <= 0`), or tombstone states (`recalled`/`deleted`/`blocked`).
  - **Replies/Threads & Attachments (`ChannelReplyThreadReference`, `ChannelAttachmentProjection`)**: Extracts inline reply/thread references (`> #<message_id>`) with parent author/preview and thread reply counts, and projects backend media types (`type == 2` image with HTTPS origin validation, `type == 3` poll/activity/route card, `type == 13` location pin, plus `MessagingAttachment` items).
  - **Reactions**: Confirmed in `ApiImController.java` and `ApiImPollController.java` that the backend has no emoji reaction endpoints; `ChannelMessageBurstGrouper.backendSupportsReactions` is explicitly `false` per spec (*"reactions only if the backend supports them"*).
  - **Member List with Roles (`ChannelMemberRoleRoster`, `ChannelMemberRoleSection`, `ChannelMemberRoleItem`)**: Groups members by role tier (`CLUB_OWNER`, `CLUB_CO_OWNER`, `CLUB_OPERATOR`, `EVENT_LEAD`/`EVENT_CHECKIN`, `CLUB_MEMBER`) with role badges and delegation expiry.
  - **Optimistic Send, Send-Receipt Contract (`POST /api/im/send-receipt`), and Retry State Machine (`ChannelSendStateMachine`)**:
    - Tracks `.pending`, `.sending`, `.sent`, `.failed`, and `.verifyingReceipt`.
    - When retrying a failed/uncertain send, transitions to `.verifyingReceipt` and consults `OrdinaryIMSendReceiptResult` (`POST /api/im/send-receipt`) first: if `.found(serverMessage)`, reconciles directly to `.sent` without re-posting `POST /api/im/send`; if `.notFound`, re-sends using the identical `clientMessageID`.
    - Deduplicates optimistic records against polled server messages by `clientMessageID` and `id`.
  - **Real-Time Transport, Polling Backoff, Paging Up & New-Message Jump (`ChannelPollingBackoffSchedule`, `ChannelTranscriptViewportState`)**:
    - Confirmed in `subpackageB/pages/im/chat/index.js` (`POLL_MS = 8000`) that the mini-program uses 8-second polling on `POST /api/im/messages` while visible (no WebSocket endpoint exists).
    - Implements `8_000ms` base interval, exponential backoff (`16s`, `32s`, capped at `60s`) on transient failures, reset to `8s` on success, and immediate stop on terminal `401/403/409` (`IM_HISTORY_ACCESS_DENIED`, `IM_CONVERSATION_CLOSED`, `HANGOUT_CLOSED`).
    - Preserves `preservedScrollAnchorMessageID` when paging up (`cursor_id`) and surfaces the "Jump to new messages" pill when new messages arrive while scrolled `>120pt` from the bottom.
- **Native SwiftUI View (`App/ClubChannelMessagingView.swift`)**:
  - `ClubChannelMessagingView`, `ClubChannelMemberRosterSheet`, `ClubAdminParityOverviewSheet` provide the embedded Discord-style collapsible category sidebar, burst-grouped transcript, reply banner, send-receipt retry indicator, new-message jump pill, and role-grouped member sheet inside the club detail hierarchy without adding new top-level pages.

### Priority 3: Safety (App Store Guideline 1.2) & Admin Moderation
- **Content Filtering Hook (`ChannelContentFilterHook`)**:
  - Immediately hides messages from `blockedSenderIDs` (`shouldHideMessageImmediately`), masks objectionable keywords in visible payloads, and preserves fail-closed tombstones for `recalled`, `deleted`, and `blocked` messages (`MessagingMessage.isPayloadVisible`).
- **Safety & Moderation Policy (`ChannelSafetyModerationPolicy`, `ChannelSafetyModerationEndpoint`)**:
  - Report message (`POST /api/im/report`) and report club user (`POST /api/club/governance/cases/report`), forbidding self-report (`CU-C-52`).
  - Block/unblock user (`POST /api/im/block`, `POST /api/im/unblock`) and mute/unmute channel (`POST /api/im/mute`).
  - Admin moderation: delete/recall message (`POST /api/club/post/delete`), remove member (`POST /api/club/remove-member`, blocking removal of `CLUB_OWNER` or members holding active role assignments per `ApiClubController.holdsActiveRoleAssignment`), ban/unban member (`POST /api/club/governance/ban`, `POST /api/club/governance/unban`, enforcing `ClubOpsBanRow.platformOnly` so `PLATFORM` bans cannot be unbanned by club admins).
  - Respects `ChannelRulesAdmission` (`hasAcceptedChannelRules`) and `ChannelRevokeIsolation` (`isChannelAccessRevoked`); never weakens existing `Core/Channel*` rules.

### Priority 1 & 4: Clubs Tab & Club Admin Parity (`ClubTabAndAdminParityCatalog`)
- **Clubs Tab Parity**: Verified and cataloged across `Core/Club*.swift`, `App/Club*.swift`, and `ClubTabAndAdminParityCatalog.clubsTabSurfaces` (`list`, `detail`, `apply/join`, `enroll`, `create/edit`, `roles`, `badges`, `notices`, `group-code`).
- **Club Admin Parity**: Verified and cataloged across `Core/ClubGovernance*.swift`, `Core/ClubOperations*.swift`, `App/ClubGovernanceViews.swift`, `App/ClubOperationsViews.swift`, and `ClubTabAndAdminParityCatalog.clubAdminSurfaces` (`workbench` unified into `detail?tab=manage`, `customers` read-only CRM, `event-ops`, `join-requests`, and `settlement` read-only reconciliation with `pages/coop/withdraw` bank withdrawal explicitly flagged off).

### Deliverable 5: Unit Tests (`Tests/CoreTests/ChannelDiscordMessagingTests.swift`)
- 8 comprehensive unit tests covering:
  1. Message list burst grouping (5-minute same-author window, author change, >5m divider break, system/recalled isolation, reply/thread extraction, attachment projection, reactions unsupported flag).
  2. Send state machine (`pending` → `sending` → `failed` → `verifyingReceipt` → `.reconciledFromReceipt` vs `.resendRequired`, plus polling deduplication).
  3. Unread & mention badge aggregation (category grouping, muted channel exclusion from unread totals, `@mention` retention on muted channels, `99+` badge cap, `readStateAvailable == false` fail-closed, read cursor clear).
  4. Safety & moderation permission matrix (self-report denial, author vs admin delete, owner & active-role-assignment removal protection, platform-ban unban protection, channel rules admission & revoke isolation, content filter immediate block + keyword masking).
  5. Polling backoff (`8s` → `16s` → `32s` → reset on success → stop on terminal `403`) & viewport new-message jump banner.

## 2. Files Created / Modified
- `Core/ChannelDiscordMessaging.swift`
- `App/ClubChannelMessagingView.swift`
- `Tests/CoreTests/ChannelDiscordMessagingTests.swift`
- `docs/worker-reports/w6-clubs-channels-strings.json`
- `docs/worker-reports/task_e9face30a6ad-strings.json`
- `docs/worker-reports/w6-clubs-channels-report.md`
