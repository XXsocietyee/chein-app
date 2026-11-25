# cursor/r8-club

Base `f5f3006d781ac4d61c225a079ef74e2e2a86befd` (`Integrate Cursor round 5`). Audit `origin/audit/parity-r8-club` `docs/audit/parity-r8/club.md`. Core only. App screens, `AppSession.swift`, `AppCompositionRoot.swift`, `project.pbxproj`, and `tools/current_ci_manifest.json` were not edited. `swiftc` was not run.

`coopStatus` stays a subscribe request. No HTTP path was added. Settlement mine stays `POST {}`. Settlement summary stays `POST {clubId}`; `personal: true` only when the caller passes personal. Neither was flipped to GET.

## Gates turned on

| Gate | State |
|---|---|
| `POST /api/club/settlement/mine` body `{}` | On for production. Moved out of `moneyAreaOwnerGrant` into `ownerDecisionGuardGrant`. |
| `GET /api/fe/reference-settlement/payer` | On. `feReferenceSettlementReadGrant`. Query `from` / `to` only when set. |
| `GET /api/fe/reference-settlement/merchant` | On. Same query rule. |
| `GET /api/fe/reference-settlement/payer/export` | On. |
| `GET /api/fe/reference-settlement/merchant/export` | On. `ClubFEReferenceExportClient.exportMerchantCSV`. |
| `ClubScanWrite.enabled` | On. Club verify posts the mini-program body. |
| `.issueGroupCode` without `clubID` | On. Body is exactly `{activityId}`. |

## Left off (money, TEST-only, send nothing)

`FEReferenceSettlementMoneyWrite.enabled` is false. `markSettled` (`POST api/fe/reference-settlement/settle` `{ids, voucherNo?}`) and `dispute` (`POST api/fe/reference-settlement/dispute` `{id, note}`) return without sending, even if the caller passes `allowsMoneyWrite: true`.

Still off: registration pay / paid orders (`PlayerContentMPContract.moneyEnabled` is false and throws before send), personal-receiver bind and unbind, settlement withdraw, wallet / asset withdraw, payout-account save, direct-ledger writes, refunds. `CLB-payout-receiver-01` (`weChatCode`) was not taken.

## Rows taken

P0

- **CLB-G02.** `ClubScanRoute` matches `utils/verification-scan.js`. Group codes post `{code}` to `api/verify/groupcode/redeem`. Activity, topic, and `activity_seat_*` post `{code}` to `api/registration/scan_dynamic_code`. `cq1.` (four segments) and JSON `type=coupon` post `{code}` to `api/coupon/verification`. JSON `type` activity/topic posts `{type, code}` to `api/registration/scan_qr_code`. `topic_seat_*`, `citynode_*`, and other codes send nothing. `mayScan` is `canGovern || canManageActivities`.
- **CLB-G17 / CLB-settlement-02.** The four reference-settlement reads above are granted. Settle and dispute stay default-off.

P1

- **CLB-detail-30.** `ClubShareLink.httpsURL()` builds `https://<the one verified origin><path>` and returns nil while `UniversalLinkConfiguration.verifiedHTTPSOrigins` is empty. No host was invented. Associated domains stay empty.
- **CLB-topic-detail-11.** `ClubTopicMerchantRow.phone` and `contactText` (`maskPhone`, or `未确认，暂无联系方式`). `phoneText`, `mobile`, and nested contact stay off the row.
- **CLB-G15.** `ClubOpsEventTopicNames.facts` carries `sessionTicketCount` and `paymentNotice` (`这个主题暂不能在线收款，玩家无法在线报名付费场次` when `onlinePaymentAvailable` is false and `sessionPrice > 0`). `windowWarning` is kept only while the selected topic is still the submitted topic.
- **CLB-event-ops-03.** Roster accepts `phoneIncluded` true or false. A callable `^1\\d{10}$` number is kept only when the flag is true. A callable number while the flag is false is malformed. Roster validation no longer strips `phone`.
- **CLB-event-ops-06.** `ClubOpsEventTopicFact.sessionTicketCount` and `showsCapacity` (`ClubEventOpsFormRules.showsCapacity`).
- **CLB-settlement-06.** `ClubOwnerFundsAvailability.allowsWithdraw` is true only for a known positive withdrawable stage. No withdrawal is sent.
- **CLB-group-code-06.** `.issueGroupCode` no longer requires `clubID`. `ClubGroupCodeIssueBody.command(activityID:)` sends `{activityId}` only.
- **CLB-detail-11** (owner decision, not a paid order). `TicketSourceRegistrationFields.payload` sends `sourceClubId` and `sourceChannelCode` (from `clubCode`) only when the share card is for that topic. Paid registration stays off and sends nothing. `TopicClubShareLink` still uses `Self.clubCode(trimmed)` and `init(clubCode:)`.
- **CLB-settlement-05** (owner decision). Mine read is admitted. Body stays `POST {}`. Bind, unbind, and withdraw stay closed.
- **CLB-apply-04** (owner decision). The mini-program has no role-switch HTTP API. It already posts `api/merchant/access/me` with `{}`. No path was added.

P2

- **CLB-event-ops-05.** Series and event-topic failure copy uses `clubOpsGov.retryAction` (`重试`). A missing club link title is `链接已失效`. `ClubOpsNetworkFailureClassifier.ClubOpsEventHubAction` is `返回` for `.invalidRequest` and `重新加载` otherwise.
- **CLB-roles-03.** `ClubRoleAssignableMember.avatarURL` from `avatar`. Nil is the placeholder.
- **CLB-apply-10** and **CLB-create-07.** `ClubPlayerCopy` looks up `club.player.*` and falls back to the same literals. The keys are in `docs/port/strings/cursor-r8-club.json` (en and zh-Hans). `Resources/Localizable.xcstrings` was left as the combined catalog.
- **CLB-enroll-08.** `pages/club/enroll/index` no longer requires `clubId`. `ClubEnrollMissingClubCopy` is `还没有可管理的俱乐部` / `成为俱乐部主理人后，可在这里查看报名名册`, and `clubID(explicit:ownedClubIDs:)` uses the one owned club.
- **CLB-r7-A-08.** `POST api/club/my` `{}` is already granted. `ClubService.owned` and `SettingsClubPickerService.resolveEntry` already open the single owned club. No second path was added.
- **CLB-detail-42.** Not deleted. `ClubDetailOverviewFactsGrid` is still referenced by the App view. Deleting it here would break that screen.

Not taken: rows whose owner is Claude App, and owner-decision rows whose fix is an App screen (`CLB-detail-35`, `CLB-detail-34`, `CLB-workbench-03`, `CLB-r7-C-04`, `CLB-r7-D-05` overlaps A-08).

## App call sites left for Claude

- **CLB-G02.** Mount 扫码 and `scan=1`. `App/MPGap/Club/ClubGapRemainingViews.swift` (the scan action is unmounted). Call `ClubScanClient.submit`.
- **CLB-G17.** Mount `ClubGapFEReferenceSettlementSection` (`App/MPGap/Club/ClubGapReferenceSettlementView.swift:6`) and `ClubGapFEReferenceRangeBar` (`App/MPGap/Club/ClubGapRound4Views.swift:210`) on the settlement branch.
- **CLB-G15 / event-ops-06.** Mount `ClubGapEventOpsExtrasSection` (`App/MPGap/Club/ClubGapRemainingViews.swift:159`). `App/ClubOpsEventFormFields.swift:21` always shows capacity; call `ClubOpsEventTopicFact.showsCapacity` and `ClubEventOpsFormRules.offerWindowText`. Show `paymentNotice` and `ClubOpsEventTopicNames.windowWarning`.
- **CLB-event-ops-03.** `App/ClubRosterBucketContent.swift` has no `tel:` button. Use `ClubRosterMember.phone`.
- **CLB-event-ops-05.** `App/ClubOpsEventView.swift:51` still uses `action.retry`. `:147` sets `.invalidRequest` for a missing club. Use `eventOpsHubTitle` (already `链接已失效`) and `ClubOpsEventHubAction` (`返回` / `重新加载`). Series and event-topic views already read `retryKey`.
- **CLB-topic-detail-11.** `App/ClubTopicMerchantContent.swift:38` shows the name only. Add the copy button for `row.phone`.
- **CLB-roles-03.** `App/ClubRoleAssignmentPicker.swift:199` uses `ClubMPAvatar(url: nil)`. Pass `member.avatarURL`, and fall back to MPAsset `d_profile`.
- **CLB-detail-30.** `App/ClubMPAssetViews.swift:9` `ClubShareURL` still builds `chein://mp`. `App/ClubKit/ClubWorkbenchKit.swift:223` and `:235`, plus the members and community invite buttons, should use `httpsURL()` once the owner supplies the one origin.
- **CLB-detail-11.** `App/GlobalSearchLinksAndTemplates.swift:531` passes `sourceChannelCode: nil`. Pass `TicketSourceRegistrationFields.payload` when a TEST caller is allowed to send a paid registration. Do not turn `moneyEnabled` on.
- **CLB-settlement-05.** `App/ClubPayoutReceiverView.swift:234`, `:267`, and `:351` still return before the mine and personal summary reads unless `PayoutReceiverBridge.payoutOpen`. The Core grant already admits `POST {}` and `POST {clubId}`.
- **CLB-settlement-06.** `App/ClubPayoutReceiverView.swift:345` always links to withdraw support. Disable it unless `ClubOwnerFundsAvailability.allowsWithdraw`. Do not send a withdrawal.
- **CLB-group-code-06.** `App/MPReviewedPageScreen.swift:306` builds `issueGroupCode` with no `clubID`. `App/ClubGovernanceCommandForm.swift:786` then throws `staleReview` unless both `clubID` and `activityID` are set, which drops a real code. Call `ClubGroupCodeIssueBody.command(activityID:)`.
- **CLB-enroll-08.** `App/MPReviewedPageScreen.swift:297` shows unavailable with no club id. Load `api/club/my` and use `ClubEnrollMissingClubCopy`.
- **CLB-r7-A-08.** `App/MPReviewedPageScreen.swift:279` and `:739` `ownedClubs` opens the list. `owner=1` with one owned club should call `SettingsClubPickerService.resolveEntry`.
- **CLB-apply-04.** `App/ClubGovernanceViews.swift:1390` always opens merchant apply. When `api/merchant/access/me` says `active`, open the merchant home; otherwise open apply. There is no switch endpoint.
- **CLB-detail-42.** Delete `ClubDetailOverviewFactsGridView` in `App/ClubDetailTabBar.swift:70`, then the Core grid in `Core/ClubDetailTabs.swift` can go.
