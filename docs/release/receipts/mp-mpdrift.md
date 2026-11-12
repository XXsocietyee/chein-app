# mp-mpdrift: small player-visible drift items (inventory A2 / C #7)

Branch `ui/mpdrift` from `origin/ui/main`. Source of truth: `liboyang42-cpu/hengyin` `chengyinhub-xcx` @ 7fe779ceb (2026-11-12).
CODE-ONLY: not compiled or run here (integrator compiles). `swiftc -parse` passes on every touched file;
`tools/generate_project.py`, `tools/check_design_lint.py`, `tools/check_scaffold.py` pass.
Square composer pieces are out of scope (ui/mpsocial2). No mini-program screenshots were used or shared.

Every new string is in `Resources/Localizable.xcstrings` under `mpd.*` (EN + zh-Hans, 110 keys), written by
`tools/add_mp_drift_localizations.py` (idempotent, pure additions).

## Mapping (mp page → native file) and what was matched

| # | Mini-program source | Native before | Native now |
|---|---|---|---|
| 1 | `pages/play/index.wxml` 游玩工具 「紧急求助」 + `pages/play/utils/play-sos.js` (拨打 110 / 120 / 复制我的位置) | missing | `App/PlayInPlayTools.swift` `PlayEmergencyHelpSheet` + `PlayToolsMenu`; toolbar menu in city orientation (`PlayExperienceView`) and free exploration (`FreeExplorationViews`). CN 110/120, US 911, unknown market no dial rows; `tel:` goes through the system confirm; location copied as zh/en text + Amap (CN, `coordinate=wgs84`) or Apple Maps pin; read once on tap. |
| 2 | `pages/shezhi/shezhi.wxml` 「AI 对话记录」 + `subpackageMember/components/cy/ai-chat-records` (导出 / 清除) | `NPCChatDataReadSettingsEntry` labelled 「我的 NPC 聊天记录」, view + delete, no export | Row relabelled `mpd.aiChat.title` 「AI 对话记录」 (id `npcData.open` kept); `App/NPCChatDataExport.swift` adds 「导出对话记录」 (copies the already-loaded records in `formatReadable` shape) to `NPCChatDataView` toolbar. Delete unchanged. |
| 3 | `subpackageRoam/nearby/index.wxml` `.mt-report` 「举报队伍」 → `team-report-sheet` (POST /api/team/report) | team-detail only (`TeamOrientBoardView`) | `App/NearbyTeamReportEntry.swift` button on every non-leader nearby team card (`NearbyTeamViews.teamCard`), same sheet copy/limits/states, uses existing `TeamReportSubmission`; `SessionNearbyTeamView` now injects `teamOrientBoardAccess`. Hidden when access absent/disabled. |
| 4 | `pages/shezhi/components/post-governance` 「帖文处置与申诉」 (my enforcements + text appeal, 500 chars, unknown ⇒ re-read) | only inside Square governance page | `App/SettingsPostGovernanceView.swift` Settings row (id `settings-post-governance`) + sheet: intro, loading / signed-out / error / empty / list, type + state labels + notes exactly as `view-model.js`, inline appeal form with counter; writes via existing `SquareGovernanceCoordinator.prepare/confirm` (its capability gates untouched; disabled ⇒ submit disabled + note). |
| 5 | `subpackageB/pages/im/list` 「邀约提醒」 switch | missing | `App/IMDriftEntries.swift` `IMInviteReminderToggle` in `IMCoopInviteStripView` header (received tab). Hidden until a binding is injected (stub below). |
| 6 | `subpackageB/pages/im/chat` (type 2) 「我的举报」 entry with unread badge (举报进度 notices) | 「我的举报」 only from Square | `IMReportProgressEntry` as a top inset in `MessagingHistoryView` for system-notice conversations; destination `SquareReportProgressView` injected in `SessionMessagingHome`. Unread badge = stub. |
| 7 | chat route-card picker (`routePickerOpen`, /api/topic/list, search/loading/error/empty) | **already present** (`IMExpandedViews` chat info → `ContextualTopicPicker` / `IMRouteShareComposeView`) | No change. Placement differs (MP: composer 「+」 → 路线; native: chat info → 路线). |
| 8 | chat review-result sheet 「生成时记录」 (审核任务 # / 业务 # / outcome / reason / followUp / 当前审核记录) | outcome/reason/followUp only | `MessagingMessageDetailView` sheet adds task # and business # rows and `IMReviewCurrentRecordSection` (status + timeline, loading/error/retry; stub reader). |
| 9 | `playkit-journey-check` D20 三档 「简单/标准/困难」 + 「按住摇骰，松手掷出」 | 3D D20 canvas + plain roll button | `App/DesignSystem/CYDiceGestures.swift`: `CYDiceTierStrip` (uses `problem.tier`), `CYHoldToRollButton` (hold charges bar + haptics + shaking die, release/tap/VoiceOver rolls, Reduce Motion fallback), `.cyOnShake`. Wired in `PlayJourneyContentViews` (id `journey.check.roll` kept). |
| 10 | 摇一摇掷骰/硬币 (`playkit-diceroll`, `playkit-coinflip`) | buttons only | `.cyOnShake` on dice and coin in `PlayKitDecisionProgressViews` (UIKit shake event, no motion permission, never steals text focus). |
| 11 | 故事流 通关后回看/选章 + 城市定向多章 「切换章节」 (`chpick`) | chapter story links only | `PlayChapterPickerSheet` (all / per chapter, completed / locked / open + place counts, current checked, still available after the run) from the tools menu; filters the place list (orientation) or store grid (free exploration). 「再玩一次」: `PlayThemeReplayButton` in `PlayThemeRecordsView` (stub). 回看旅程手记 is the existing `journey.record.title` section. |
| 12 | `pages/play/look-tokens.wxss` `--lk-*` 4 looks × 5 palettes (+ cyber neon), `look-colors.js` | missing | `App/DesignSystem/CYThemeLook.swift`: all 20 palettes copied 1:1, legacy fallback, radius/typography/glass per look, `.cyThemeLook()`, `.cyLookCard()`, `.cyLookTitle()`, `CYLookButtonStyle`. Applied to city orientation, free exploration and the title card. |
| 13 | 主题开场标题卡 `.st-intro` (城瘾 · 模式 · AI 生成, title ≤2 lines, `introLine`, 开始游戏) | missing | `App/PlayThemePresentation.swift` `PlayThemeTitleCard` overlay, once per topic per device, for story routes (or free exploration that skips the pack); `PlayThemeIntro.line` ports `introLine`. |
| 14 | 卡包开场按主题类型 (`skipPack = productType !== 2`), pack printed with topic name | pack always shown, generic label | `FreeExplorationCardBrowser`: skips pack when facts say so, prints topic name, tear (shake/scale/haptic) then staggered deal; Reduce Motion opens at once. |
| 15 | AI 生成 label + 备案号 (`utils/aigc-label.js`; about page, publish simple AI section) | none | `App/AIGCDisclosure.swift` (`AIGCLabel`, `AIGCFilingNumberText`); filing line in `SettingsAboutView` app-section footer and `PublishingAIDraftSheet`; AI label in the title-card kicker. |

## Needs logic (Cursor) — binding stubs added, all hidden/no-op until injected

1. `PlayThemePresentationReading` (`\.playThemePresentationReader`): decode `topicAiGenerated`, `topicCover`, `productType` from `/api/play/nodes` and `look_json` (style, palette, params.neon) → `PlayThemePresentationFacts`. Without it: no look, no AI label, pack always shown, title card has no cover.
2. `PlayEmergencyLocationProviding` (`\.playEmergencyLocationProvider`): one-shot foreground location (reuse play location if held). Without it the 「复制我的位置」 row is hidden; dial rows still work.
3. `IMInviteReminderBinding` (`\.imInviteReminder`): notification preference for coop invites (permission prompt on enable).
4. `\.imReportProgressUnread`: count of unread REPORT_* community notifications + mark-read on open (`POST /api/v1/community/notifications/{id}/read`).
5. `IMReviewAuditReading` (`\.imReviewAuditReader`): audit-detail read for 当前审核记录.
6. `PlayThemeReplayBinding` (`\.playThemeReplay`): `replayAllowed` + `POST api/play/theme/replay` with unknown-outcome read-back.
7. `\.aigcFilingNumber`: `aigcFilingNo` from `/api/config/features`, injected at app root.
8. AI label on the club topic-story header (`pages/club/topic-story`): `TopicStoryParticipationHost` has no `publishMode`; once decoded use `AIGCDisclosure.isAIGenerated` + `AIGCLabel`.

## Not done / follow-ups
- Not compiled here; integrator build is the gate.
- Look tokens are applied at screen scope (tint, ink, colour scheme, title card); per-card `.cyLookCard()` adoption inside chapter story / chapter gate is left for a later layout pass.
- Route-card picker stays in chat info (see #7); moving it under the composer 「+」 would need composer changes owned by IM.
