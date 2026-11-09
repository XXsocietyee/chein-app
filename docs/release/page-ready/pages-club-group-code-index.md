# pages/club/group-code/index

PAGE-READY for 俱乐部团核销码签发页. Map status stays `partial` on `App/ClubGovernanceViews.swift`. This lane does not edit a view.

- Contract already in the repo: `ClubGovernanceRead.topicOverview` is `api/topic/info-to-user`, and `ClubGovernanceMutation.issueGroupCode` is `api/verify/groupcode/issue`. `ClubGroupCodePage` uses those two. `routeMarkedLive` is false. `api/club/group-code` and `api/club/group-code/save` stay unregistered.
- Capability: `ClubGroupCodeCapability` follows `club:event:checkin` (club-wide or one event access). A missing grant stays hidden and does not call the reader. Sessions outside that grant are omitted. `includedInPlayerFirstEntry` is false. `issuanceLive` is false, so this type never sends. The provider gate stays `club.gov.providerGate`.
- Model: `ClubGroupCodePage` in `Core/ClubGroupCodePort.swift` has loading, empty, error, unknown, and ready. A missing, null, numeric-string, or non-integer `headcount` displays `—`. A literal JSON 0 stays 0. The existing TTL default in `ClubGovernanceGroupCode` is unchanged.
- Tests: `testGroupCodePageStaysHiddenWithoutCheckInCapability`, `testGroupCodePageLoadingEmptyReadyAndLiteralZero`, `testGroupCodeUnknownHeadcountIsEmDashNeverZero`, `testGroupCodeLoadUsesTopicOverviewAndHidesADeniedGrant`, and `testGroupCodeIssueCommandUsesExistingContractAndDoesNotSend` in `Tests/CoreTests/ClubGroupCodePageReadyTests.swift`. `test_group_code_page_states_stay_off_player_entry` in `Tests/ContractChecks/test_club_group_code_page_ready.py`.
- Fixture: `ClubGroupCodePageFixtureData` is compiled only inside `#if DEBUG`.

## Missing EN and zh-Hans keys

These `ClubGroupCodePage.Copy` keys are absent from `Resources/Localizable.xcstrings` and `Resources/ClubGroupCodeDisplay.xcstrings`. `club.gov.providerGate` is already translated in both languages and is not listed.

| key | en | zh-Hans |
| --- | --- | --- |
| `club.groupCode.page.loading` | Loading sessions you can lead | 正在加载可带队场次 |
| `club.groupCode.page.empty` | No sessions you can lead right now | 暂无可带队的场次 |
| `club.groupCode.page.error` | The group code page didn't load | 团核销码页面加载失败 |
| `club.groupCode.page.unknown` | A headcount wasn't provided | 人数未提供 |
| `club.groupCode.page.retry` | Try again | 重试 |
| `club.groupCode.metric.headcount` | Headcount | 人数 |

Left: `App/ClubGovernanceViews.swift` still opens `.issueGroupCode` from the topic session row without this page model. Binding the phases is a later view change. Save to Photos and silent re-issue stay out. Xcode was not run.
