# ut-d4-badges

[x] 0e8ce43f1b31fb163c49fca65ba441066ddd9953

PR 1042. Branch `cursor/ut-d4-badges`. Parent `fd67ba2a1`. Base `rc/20261108`. +79/−0.

`Tests/AppUITests/Fixture_d4_badgesTests.swift` (+67) launches `--design-fixture d4-badges` in English and zh-Hans. It waits for a hittable element, rejects an unknown fixture, a raw dotted key, and the word Questify outside a DEBUG label, and keeps screenshots `d4-badges-en` and `d4-badges-zh`. `project.pbxproj` is +12/−0 and registers only this file in QuestifyUITests. No App view change. Not merged. Xcode Cloud has not run it.
