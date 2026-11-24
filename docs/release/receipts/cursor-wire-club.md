# cursor/wire-club

Base: `origin/ui/combined-r7` `82388e4a5e7391e0c5a286735d6b30613a860ae8`.

Merged before the call-site edits, and their screen work kept:

- `origin/fix/r3-club-a` `e3da0d7aa5048c12a3b72a2a565171496490928e` as `94cacbef0d7face5be73290935cadeae3253a10b`. The only conflict was `tools/check_typography_lint.py`. The resolution keeps the combined-r7 rule: semantic Dynamic Type from `.largeTitle` through `.caption` is allowed, and only `.caption2` counts as a raw text style.
- `origin/fix/r3-club-b` `5adb7e1bccfc66eff31b45ede030720518578f51` as `5584897e946b3ab9a152f58d94d9d9a9895b74fe`. Clean merge.

No `swiftc` or `xcodebuild` was run. This receipt does not claim a parse.
`project.pbxproj` and `tools/current_ci_manifest.json` were not edited.
Club settlement was not flipped. Production `ClubGovernanceRead.settlement` stays `POST api/club/settlement/summary`. `CoopFlowRead.clubSettlementSummary` stays the unmounted GET.
Payouts were not enabled. No gate was turned on. `memberPricePerk` is display text only.

`docs/port/strings/cursor-core-club.json` was not merged into a catalog. The views below show the Core sentence (`literalTitle`, `memberGovernanceDenial`, `weeklyHorizonMessage`, `memberPricePerk`) rather than looking those keys up. 返回 / Back is `Locale.pick`, so both languages are in the call site and no new `.xcstrings` file was added. The generic `club.schedule.error.weeklyHorizon` key was not catalogued: the label shows `weeklyHorizonMessage(now:)`, which already carries the real maximum.

## Call sites

| Mount | File | What it does |
|---|---|---|
| Club share | `App/ClubKit/ClubWorkbenchKit.swift` `ClubHeaderShareButton` | Shares `ClubShareLink.club(id:)?.path`. The toolbar passes `club.id`. 邀请朋友加入 is unchanged. |
| Post share | `App/ClubCommunityViews.swift` | The post `ShareLink` uses `ClubShareLink.post(clubID:postID:)?.path`. `ClubPostShareText` is gone. |
| Now card | `App/ClubDetailView.swift`, `App/ClubLeadProgressView.swift` `ClubOwnerStageNow`, `App/ClubKit/ClubWorkbenchKit.swift` | The manage tab loads the same topics, invitations, and projects the lead page already reads, then `ClubOwnerStageMachine.resolve`. Admins resolve immediately. A failed read leaves the approvals card. When a resolution exists, the card shows `label` and `hint` and does not keep the 去处理 button. The 待审批 tile still opens 入会申请. |
| Lead primary | `App/ClubLeadPrimaryActionView.swift` | The button title is the stage `label` only when that stage maps onto an existing `ClubLeadPrimaryAction` (`publish`, `merchants`, `sentInvitations`, `topics`, `events`). Other stages show `label` / `hint` and do not navigate. No enum case was added. |
| Page failure | `App/ClubOpsJoinNotifyViews.swift` `ClubOpsPageFailureSection` | Shows `literalTitle` when set (notify, series, event topics, topic overview). `prefersBack` replaces reload with 返回 and pops. |
| Customer / settlement failure | `App/ClubOpsCustomerViews.swift` `ClubOpsFailureSection` | Shows `literalTitle` when set. `backTitle` replaces retry with 返回 and pops. Settlement keeps retry (`backTitle` is nil). |
| Event ops hub | `App/ClubOpsEventView.swift` | The failure title is `ClubOpsNetworkFailureClassifier.eventOpsHubTitle`. Retry stays. |
| Ban row | `App/ClubOpsGovernanceSections.swift` `ClubOpsBanExpiryReview` | Shows `durationDays` through the existing `clubOpsGov.days %lld` catalog string (「N 天」 / “%lld days”) when the day is 7, 30, or 90. It no longer reads `expiresAtEpochMs`. The generic fact list skips `durationDays` so the row is not also a raw integer. |
| Welcome perk | `App/ClubMemberWelcomeSheet.swift` | Renders `memberPricePerk` when it is non-nil. No payment. |
| `memberPostAllowed` | `App/AppSession.swift` `communityEvidence` | Passes `membership.memberPostAllowed`. Nil stays nil, which the composer still treats as allowed. The pending probe in `ClubCommunityViews` is unchanged. |
| `canGovernMembers` | `App/ClubGovernanceViews.swift`, `App/ClubOpsGovernanceSections.swift` | 临时封禁 and the 封禁 list open only when `canGovernMembers` is true. If `club:member:manage` is present and `canGovernMembers` is false, the row shows `memberGovernanceDenial`. `ClubMemberAction.menu` is unchanged. |
| Dissolve cleanup | `App/ClubOperationsViews.swift`, `App/ClubGovernanceCommandForm.swift` | The edit-page dissolve link puts the current `ClubProfileLocalDraftFlow` in the environment. After a confirmed dissolve receipt, the form calls `clearAfterConfirmedDissolve()`. It does not send the dissolve. |
| Workbench tiles | `App/ClubKit/ClubWorkbenchKit.swift` | 待核销 and 本周场次 are omitted when the optional count is nil. `display()` of an unknown count is still 「—」. 待审批 stays. No new calendar or overview read was added. |
| Group code | `App/MPReviewedPageScreen.swift`, `App/ClubGovernanceViews.swift`, `App/ClubGovernanceCommandForm.swift` | A topic-only `pages/club/group-code/index` link opens topic overview. The issue form, the one-tap issue task, and the event issue link require `activityID > 0`. The command is not submitted without one. |
| Schedule error | `App/ClubSeriesScheduleEditor.swift` `ClubSeriesScheduleIssueLabel`, `App/ClubGovernanceCommandForm.swift` | `.weeklyHorizon` shows `weeklyHorizonMessage(now:)`. Other issues keep their existing keys. |

## Left as they were

- `ClubLeadPrimaryAction` cases.
- Invite shares (`ClubHeaderInviteButton`, the members invite `ShareLink`).
- `TopicClubShareLink` registration writes.
- Settlement GET versus POST.
- Payout and withdrawal flags.
