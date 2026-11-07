# gm-test2 -> gm-int: what was taken and what is deferred (round 4)

Per coordinator decision (b): `git checkout`-style per-file pick of `origin/wip/gm-test2` (2fa90ba6), NOT a merge commit. Taken: 55 test-side files under `Tests/` (the other 90 changed test files were already identical in gm-int) and `docs/parity/full-suite-triage.md`. Applied with a 3-way per-path script (`/private/tmp/gm-intc-pick.py`); no 3-way conflicts. Build + 220 AppUnit classes re-run (`/private/tmp/gm-intc-r4-app-b1..b3.log`), the 4 changed Core test classes re-run (87 tests pass, `/private/tmp/gm-intc-r4-core-*.log`). `ClubPostDiscussionReadTests`: all 10 tests pass, each in <0.2 s.

## Not taken (product files)
- `App/ClubPostDiscussion.swift`: gm-test2's version calls `ClubCommunityService.usesLegacyPagedComments`, which exists only in gm-test2's `Core/ClubCommunityService.swift` (hostname `.invalid` switch, plus `isDormantAdapter`). It does not compile without that Core file, so it was taken once, shown to break the build (`error: value of type 'ClubCommunityService' has no member 'usesLegacyPagedComments'`), and reverted. Also not taken: `Core/ClubCommunityService.swift`, `Core/ClubCommunityReadCursor.swift` (null `isPinned` tolerated).
- `Core/AccountComplianceCoordinator.swift`, `Core/AuthChannelService.swift` (hard conflicts with G1), and the rest of gm-test2's ~40 product-file changes (`Core/Account*`, `Core/APIConfiguration`, `Core/RuntimeDependencyConfiguration`, `Core/ClubOrdinaryAdmissionRuntime`, `Core/MerchantContentService`, `Core/PlayExperienceContracts`, ...). GM-TEST-C reconciles these separately.

## Tests likely depending on the deferred product changes (still failing here)
- Core: AccountComplianceTests (4), AccountDeregistrationParityTests (1), AccountDeregistrationRebaseSafetyTests (2) - gm-test2 reports AccountComplianceTests 13/0 with its Core changes.
- AppUnit: ClubCommunityReadCompositionTests (2), ClubOrdinaryAdmissionCompositionTests (1), ProfileGuideReadTests (1) - not confirmed, may be env.
- Remaining AppUnit failures (ProjectEditComposition 7, RoamShareNativeLifetime 7, RoamHistoryHubTools 6, RoamAnniversaryHistoryRecovery 6, OfficialPublicEventComposition 4, RoamCreatedStampReadLifetime 3, ...) match the triage doc's iOS 27.0 simulator host/AX baseline failures (env); the AX shim did not change the outcome for the classes in this audit.
