# ut-d4-settings

[x] b389758471459a6f0a20dcfe64ce55c82d0201e2

PR 1068. Branch `cursor/ut-d4-settings`. Parent `fd67ba2a1`. Base `rc/20261108`. +81/−0.

`Tests/AppUITests/Fixture_d4_settingsTests.swift` launches `--design-fixture d4-settings` in English and zh-Hans. It waits for a hittable element, rejects an unknown fixture, a raw dotted key, and the word Questify outside a DEBUG label, and keeps screenshots `d4-settings-en` and `d4-settings-zh`. The test file is +69. project.pbxproj is +12/−0 and registers only this file in QuestifyUITests. Not merged. Xcode Cloud has not run it.
