# cloud-ch-fixes — channels + friends + team pool, app side

Branch `ui/cloud-ch-fixes` from `origin/ui/main` `ec2e42ba8`. Code only on this Mac: no xcodebuild, simulator or live backend.
The integrator compiles the app target.

Sources:
- Contract `origin/ui/channels-contract` `b892c8e2b`, `docs/channels/contract.md` (§0 rules, §4 team pool, §5 in-team rank, §6 inventory, §7 mismatches, §8 friends).
- Backend `liboyang42-cpu/hengyin` `feature/im-channels` `bb4ee788a` (109/112 graph paths served; webhooks ×2 and the anchored audit log are deferred).

## §7 items

| § | Item | Files | Status | Notes |
|---|---|---|---|---|
| 7.1 | Catalog accepts `version >= 0` | `Core/ChannelDirectoryCatalogProducer.swift`, `Core/ChannelGovernanceProjection.swift` (`ChannelRulesCAS`), `Core/ChannelRulesAdmission.swift` | DONE | A channel created at `version "0"` opens at once. Missing, negative or non-canonical (`"01"`) versions still close the open. Test: `ChannelDirectoryCatalogProducerTests`. |
| 7.2 | `/api/im/mute`, `/api/im/read` body | none | NO CHANGE | The contract marks this resolved on the backend: the JSON variants are served beside the form routes (dispatched by `Content-Type`) and return the MUTE/ACK receipt the app's `NativeChannelNotificationService` validates. Switching the channel client to form fields would get the legacy form response instead, and the final-forward fence compares the exact JSON body it journaled. The ordinary-IM writer (`IMExpandedService`) already sends form fields. |
| 7.3 | `has_more` as integer or boolean | `Core/JSONFlexibleFlag.swift` (new), `NativeChannelMessageProjection`, `NativeChannelMessageContext`, `NativeChannelMessageSearch`, `NativeChannelManagementService` (roles), `NativeChannelChain`, `NativeChannelCheckin`, `NativeChannelProgressContracts`, `NativeFriendContracts`, `NativeFriendDirectoryContracts`, `MessagingContracts`; `JSONSerialization` sites in `NativeChannelAuditFlow`, `NativeChannelMentionTargets`, `NativeChannelRoleFlow`, `NativeChannelModerationFlow` | DONE | `true/false` or exactly `0/1`; any other number, a string or a fraction is malformed. Optional flags treat a missing key/`null` as nil. |
| 7.4 | Progress privacy shape | `Core/NativeChannelProgressService.swift`, `Core/NativeChannelProgressContracts.swift` | DONE | (a) The progress page never sends `GET /api/privacy/progress` without `channel_id` (it would get the settings shape); a nil channel now fails closed before sending. (b) A `FRIEND` aggregate decodes as the narrower `SELF` on the progress page instead of failing the read. (c) Both receipt routes stay as they are. |
| 7.10 | Team pool hint text | `Core/TeamPool.swift` (new), `App/TeamPoolHintSection.swift` (new), `App/PlayHelpLadderPanel.swift`, `App/PlayExperienceView.swift`, `App/SessionPlayRuntimeView.swift` | DONE | There was no pool client on `ui/main`; added one for §4 (`GET /api/team/pool`, `POST hint/skip/timer/start`, `GET requests/{id}`) with the §0.1 envelope rule (definite only when HTTP status == `code` and 4xx; HTTP 200 + 4xx code or 5xx is unknown). The hint dialog shows a team section only when the server returns `enabled: true`: hints/skips left, team score, timer expired, a "Use a team hint" action and the server's `hint{level,type,content}`. `consumed:false` says a teammate already opened it. Unknown results keep the same request id and offer "Check again" (receipt read, no resend). The team is the viewer's own live `play_team` for the topic from `/api/team/my` (owner type 1); without one there is no section. |
| 7.11 | Video receipt without cover/duration | `Core/IMVideoContracts.swift`, `Core/IMVideoService.swift`, `App/IMVideoViews.swift` | DONE | `coverSHA256/coverSize/durationMS/width/height` are optional (`nil` = unknown). Half a cover or half the dimensions is still invalid. `cover_review_state: null` is allowed when there is no cover; then only the video review decides `ready`. Preview skips the cover fetch when `coverURL` is null; the player shows no thumbnail and no duration rather than zero. |
| 7.12 | Voice without ASR or server duration | `Core/IMVoiceContracts.swift`, `Core/IMVoiceCoordinator.swift` | DONE | `asr_state` is no longer a send condition. The reference is built from the server's duration/waveform when sent, otherwise from the locally recorded clip; the server `size` must equal the clip's bytes. |
| 7.13 | File cap 10 MB | `Core/IMFileContracts.swift`, `Resources/Localizable.xcstrings` (`d7.imFile.readFailed`) | DONE | Picker, reference validation and the preview response ceiling follow `IMFileSelection.maximumBytes` = 10 MB. Copy updated in both languages. |
| 6.14 | Attach media via `/api/im/send` 10/11/12 | `App/ReviewedPlayerWriteLeases.swift` (`imMediaRoutes`, `sessionDependencies`) | DONE (send side) | The existing upload → receipt/scan → send flow (`IMFileCoordinator`, `IMVideoCoordinator`, `IMVoiceCoordinator`) already shows HOLD ("in review") and REJECTED states and sends the `original-im-*-v1` card. The shipped China business configuration now issues the upload, receipt, scan, video policy, send and send-receipt routes to player/club accounts when player writes are on. Recipient preview/playback routes are per-message paths that the static configuration cannot issue, so they stay unavailable (fail closed). |

## Other items

| Item | Files | Status | Notes |
|---|---|---|---|
| In-team member board (§5) | `App/PlayerJourneyReadBindings.swift`, `App/JourneyReportViews.swift`, `App/MPParityKit.swift` | DONE | The 队内 tab is now `/api/rank/list?scope=team&scopeId=<play_team id>&period=` (week/all picker shown) and appears only when the run carries a team id (`teamId` deep-link parameter). The between-teams board moved to the 队伍 tab (`/api/orient/team/ranking`). The board reads `entries`/`me`/`coverage` from ScopedLeaderboardVO (it only read `rows`/`list` before, so the quest board came back empty). A non-member's 403 shows the server message. |
| Friends (§8) | `App/ReviewedPlayerWriteLeases.swift`, `App/AppCompositionRoot.swift` | DONE | Metadata (remark, star, groups, progress scope), removal, directory, friend progress, channel invites, team invites and channel member source now get leases in the shipped composition; requests/accept/reject/cancel/list were already on the player grant. Views (`NativeFriendHomeView` and children, DM start via `conversation_id`) were already wired to these factories. The block list stays on `/api/im/block`/`/api/im/unblock` (already issued); `api/native/blacklist/*` is not served, so no blacklist lease is issued and that screen keeps its unavailable state. |
| Welcome + onboarding payload (§6.11) | same | DONE | `api/welcome-screen/get` and `api/onboarding/{get,submit}` + the admission receipt route are issued to player/club accounts. Onboarding options with effects are still refused by the existing client. |
| Admission requests (§6.10) | `App/ReviewedPlayerWriteLeases.swift` (`admissionPaths`, `acceptsPlayerWrite`) | DONE | `join-request/{submit,cancel,approve,reject}`, `space/{leave,join-pause}`, `invite/revoke` and `channel-platform/admission/requests/{adm-…}` pass the reviewed player-write route; approve/reject/pause/revoke are owner/admin writes the backend checks. The admission page (`ChannelAdmissionParent` from a channel conversation's members row) first reads `GET /api/channels/{id}`, which the route now also admits. |
| Channel management | `App/ReviewedPlayerWriteLeases.swift` (`channelManagement`) | DONE | Clubs (1) and teams (3) only; hangouts have no channels. The lease carries directory/detail reads for every member plus the write operations. A write is still built only after the server's own `my_permissions_list` shows MANAGE_CHANNEL (MANAGE_ROLE for overwrites), which only the space owner and club admins hold (`NativeChannelManagementCoordinator`), and the backend refuses everyone else. |

## Grants

- `ReviewedProductionGateLeases` (shipped China composition, `playerWritesEnabled`, role `player` or `club`): `socialWriters`, `friendChannelInvite`, `friendTeamInvite`, `friendChannelSource`, `channelManagement`, `imMediaRoutes`; the player-write grant gains `admission` and `teamPool` endpoints. `nativeChannelTextSendApproval` and `nativeFriendApproval` were already issued.
- `ChinaReviewedRouteCapability.channelsSocialOwnerGrant`: owner approval for the contract's served channel/messaging/friends/team-pool paths, so `refuseUnwiredChinaProduction` lets them through. Money is still refused first (`ReleaseMoneyWriteSwitch.blocks`, `forcedOff`); webhooks and `/api/im/audit-log` stay out.
- Tests: `Tests/CoreTests/ChannelsContractAppSideTests.swift` (decoding + route grant, money refused), `Tests/AppUnitTests/ReviewedSocialWriteLeaseTests.swift` (leases + player-write route, money refused; compiled by the integrator).

## Gates (this Mac, code only)

| Gate | Result |
|---|---|
| `tools/generate_project.py` | run (3 new sources + 1 new app-unit test) |
| `tools/check_scaffold.py` | PASS (structural, design lint, AppSession ratchet, page route table, privacy manifest) |
| `tools/check_design_lint.py` | PASS |
| `swiftc -parse`, all 40 changed/new Swift files | PASS |
| `swift build --build-tests` (Core) | QuestifyCore builds. The full test target does not build on the base tree (pre-existing: `IMChatSessionPageTests` tuple `Equatable`, `AuditBugTests` main-actor call, `IMSquareTests` optional), so the suites below were run with only their files in the test target. |
| `swift test` Core, 21 suites / 232 tests (new `ChannelsContractAppSideTests`, catalog, governance/rules, route capability, admission client, progress + final forward, message search/context/wire, chain, check-in, friend flow/directory, messaging contracts, CB93, journey lease, video bounty) | 228 pass. 4 fail on the base tree as well and are unrelated: `wiredPatternCount` 674 ≠ 672 (×3, the base list already has 674), `VideoBountySourceTests` affiliate summary, `MessagingContractTests` broadcast `bcId:true`. `CB93RouteAdaptationTests` was updated: `api/join-request/submit` and `api/space/leave` are now owner-granted, so the "hidden routes do not leave" case uses the deferred `api/im/webhook`/`api/im/audit-log`. |
| `Tests/ContractChecks` (`test_player_write_grant`, `test_allowlist_routes_have_backend`, `test_home_city_location_consent`) | OK. The AppCompositionRoot ratchet moved down 4307 → 4290 (`ReviewedPlayerWriteGrant` moved into `ReviewedPlayerWriteLeases.swift`). Other failing ContractChecks in that area are git-diff/whitelist checks that fail on the base tree too. |
| AppUnitTests (`ReviewedSocialWriteLeaseTests`), app target build | NOT RUN here (no xcodebuild); for the integrator. |

## Left

- Recipient previews for IM file/video/voice need per-message issuance (not static business routes); they stay unavailable.
- The play view has no team id outside `/api/team/my`, so a team run that is not owned by a topic (owner type 2, activity) gets no pool section yet.
- The in-team tab needs a `teamId` on the report/settle deep link; the play screen's own report link does not carry one yet.
- Not run here: app target build, AppUnitTests, UI tests, live backend.
