# ui-cur-ugc-tests — Core tests for UGCContentSafetyService

Parent: `ui/h-ugc` `ac61545ebb471416f514597b3ce99bce880f8cb4`.
Tip of `ui/h-ugc` was checked after fetch and still matches that SHA. This branch starts there. It does not branch from `ui/main` and does not merge `ui/cur-ugc-fixtures`.

Tests only. No restyle. No layout, color, or spacing change. No second safety service. `UGCContentSafetyHTTPService` and `UGCBlockedUsersStore` in `Core/UGCContentSafetyService.swift` are the types under test.

`App/RegionalLaunchConfiguration.swift` was not edited. No methods were added to `App/AppSession.swift` or `App/AppCompositionRoot.swift`. `docs/release/contract-failing-baseline.txt` was not raised. `ReviewedAreaSwitch` was not redeclared. Money stays behind that existing switch. The production host `www.chengyinhub.com` stays closed. The tests call the service with `https://8120.example.test` and assert the request URL does not use the production host.

Unknown money elsewhere in Core stays an em dash (U+2014). This service does not format money. A missing server message on this type stays `nil`. It does not invent an em dash. A numeric `code` of 0 stays 0 and is rejected. A block-list row whose first id field is 0 stays 0 and is not replaced by a later id field. Cursor `0` is sent as the query value `0`.

## What is on this tip

| Behavior | Where | Test |
|---|---|---|
| Report reasons | `UGCReportReasonOption.fallbackTaxonomy` (13 codes, three urgent) and `UGCContentSafetyHTTPService.fetchCapabilities` / `submitReport` | `testFallbackReportReasonsMatchTheCommunityTaxonomy`, `testReportTargetRoutesStayOnTheExistingPaths`, `testCapabilitiesReadServerReasonsAndANumericZeroCodeStaysRejected`, `testFormReportsSendTheLabelAndCommunityReportsSendTheDetailText`, `testReportRejectsASignedOutCallerAnEmptyReasonAndAZeroIdentifier` |
| Block-list filtering for feeds, chats, and comments | `UGCBlockedUsersStore.isBlocked(memberID:authorName:)`. The same predicate is what `UGCBlockedFilterContainer` applies to feed rows, chat rows, and comment rows. | `testBlockListKeepsCursorZeroAndDropsADecodedZeroMember`, `testBlockedAuthorsDropOutOfFeedsChatsAndComments` |
| Moderation precheck | `UGCContentSafetyHTTPService.precheckContent` → `POST api/ai/safety/precheck` | `testPrecheckPassesBlankTextAndReadsTheModerationFlags` |

Form report writes (`topic`, `template`, `comment`, `team`, and the other form routes) send the reason label only. Community and mod writes append details with a hyphen-minus (`"label - details"`), not an em dash. That is the current service, and the tests pin it.

## Not present on this tip

These names are not on `UGCContentSafetyService`. They were not added.

- No `filterFeed`, `filterChats`, or `filterComments` method. There is no collection filter on the service. The tests pass feed, chat, and comment rows through the existing `isBlocked` predicate.
- Keyword masking stays on `ChannelContentFilterHook` in `Core/ChannelDiscordMessaging.swift`. That is a different type. This task does not add a second safety service and does not add tests for that hook.
- This service does not render unknown money as an em dash. That formatting stays on the existing money types and was not changed.

## Gates

`command -v swiftc` and `command -v swift` print nothing on this VM. No typecheck is claimed. `swift test` was not run.

`python3 tools/generate_project.py` was run. It reported 3632 native sources and 809 app-unit sources. The new file lives under `Tests/CoreTests`, which `Package.swift` already picks up by directory. It is not an App or Core app source. The generated Xcode project did not change.

`python3 tools/check_scaffold.py`: pass (release config, privacy manifest, page route table, structural checks, design lint, appsession ratchet). `App/AppCompositionRoot.swift` stayed at 4171 lines, under the existing ceiling 4184.
`python3 tools/check_design_lint.py`: pass (1634 App Swift files; allowlist unchanged, 46 existing violations).
