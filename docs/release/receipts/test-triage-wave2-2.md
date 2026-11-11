# Test triage wave 2-2 (code-only, no builds/simulators run)

Source: `/private/tmp/full-failing.txt` (serial full unit run on ui/main 87a8b3de2). Fixes are unverified by a run; each is a root cause found by reading the test and production type.

| class | root cause | verdict | fix | SHA |
|---|---|---|---|---|
| NativeChannelHistoryTextHTTPRecoveryTests (7) | Rig `init` throws `APIError.invalidRequest` before any wire call: `MessageTextIntent` requires a 32-char lowercase-hex `clientMessageID` (Core/MessageActionService.swift:14-15); the test used `"history-text-http-0001"`. | stale | fixture key replaced with a 32-hex id (validator untouched) | see commit |
| NativeChannelTextReadOnlyPresentationTests (7) | Same: `"readonly-original-0001"` fails the 32-hex check in the harness. | stale | fixture key replaced with a 32-hex id | see commit |
| ClubCommunityLifecycleTests (2) | `ClubCommunityFeedItem(row:)` requires an `isPinned` 0/1 number (ClubCommunityReadCursor.swift:28); the DEBUG `ClubCommunityFixture` rows omit it, so every post/feed read throws `.invalid` and `snapshot` is nil. | stale | added `"isPinned":0` to fixture post/feed rows | see commit |
| ClubCommunityReadCompositionTests (2) | Same missing `isPinned` in inline post rows. | stale | added `"isPinned":0` to the two post rows | see commit |
| RuntimeSessionRoleConsistencyTests (1) | `AuthChannelService.currentAccount` rejects an empty role (`guard [player,club,merchant].contains(role)`, AuthChannelService.swift:111) unless login supplied a fallback, so login with a missing role never commits; the test expects success with `effectiveRole` derived from `userType`. Loosening it changes an authorization-role gate. | unknown (owner decision: regression vs stale) | none (safety gate) | - |
| NativeChannelPinLocalizationTests (3), NativeChannelAppealEntryLocalizationTests (3), Template{CoverReferenceClear,LocalMediaClearGroup,MediaReviewController,TimerOutcomeEditor,MetadataRead*}Tests | Shipped xcstrings carry shorter copy than the reviewed copy the tests assert (see docs/parity/full-suite-triage.md). | stale/owner copy decision | none | - |
| NativeChannelMessageHostBindingTests (2), NativeBlacklistEntryHostingTests (2), NativeAttributeAuthorProjectHostTests (2), NativeRpg{Environment,Condition}AuthorClosureTests, NearbyMapDiscoveryRecoveryTests, OfficialEventComponentsClosureTests, Profile{FavoriteDetail,FavoriteTopicRead,ParticipantHostRecovery,SettingsFavorites,WeeklyPointsSection}Tests | Hosted-AX family on iOS 27 simulator (no AX nodes / InvalidTransition) per full-suite-triage.md; not individually re-read. | env | none | - |
| ContentDraftSystemStorageTests, PlayRecoverySystemStorageTests | Keychain -34018 on unsigned test host (triage doc). | env | none | - |
| OwnMedia{Audio,Model}PreviewHostTests | Password gate; owner decision (triage doc). | unknown (owner) | none | - |
| ProjectOwnedEditorTests (7), ProjectChapterAtmosphereLifecycleTests (1) | Use the ProjectEdit model/fixtures (same family as ProjectEdit* owned by another worker); not root-caused here. | unknown | none | - |
| ApprovedReleaseOriginalRecoveryTests (2), IMConversationReadAllAppTests (1), IMConversationRowActionsAppTests (2) | Not root-caused (no failure messages available, code-only). | unknown | none | - |

Checks: `check_scaffold.py` PASS, `check_design_lint.py` PASS, `swiftc -parse` clean on touched files.
