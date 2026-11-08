# close-w6b: W6 partial rows (index % 3 == 1)

Nothing was compiled or run here (no Swift toolchain). `tools/check_scaffold.py` is the only check observed.
Convention: new Core logic is appended to the existing Core file (new Core/App files would need project.pbxproj regeneration, which is not allowed here); new Core tests live in Tests/CoreTests (SwiftPM, no project registration).

| row | what you built (file:line) | test (file::name) | remaining gap | hook needed |
|---|---|---|---|---|
| pages/club/badges/index | Core/ClubBadgeManagementFlow.swift:249 (`screenState`: loading/notAvailable/error/empty/ready), :259 (`showsOwnerOnlyNotice`), :261 (`memberPickerState`); App/ClubBadgeManagementView.swift:14-80 (error+retry, empty, owner-only notice, badge description, member picker loading/error-retry/empty/owner mark, 44pt targets); Resources/ClubBadge.xcstrings (8 new en+zh-Hans keys) | Tests/CoreTests/ClubBadgeScreenStateTests.swift::testEmptyListShowsEmptyStateAndOwnerKeepsCreate, ::testNonOwnerSeesReadOnlyListWithOwnerOnlyNotice, ::testFirstLoadFailureIsErrorStateAndRetryRecovers, ::testUnconfiguredReadIsHonestNotAvailable, ::testMemberPickerErrorRetryThenReady, ::testMemberPickerEmptyRoster (fake HTTPTransport); grant main action already in ClubBadgeGrantFlowTests | Admin vs ordinary member are indistinguishable (both read-only, as in the mini-program: owner only). Create-unknown "I have confirmed" dismissal from the mini-program is covered by the journal recover button, not a separate control. Not compiled. | none |
