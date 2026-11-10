# ut-d4-directory

[x] ebaaf04fd6233e9a2a07cd882c3d6215e2aea04d

PR 1043. Branch `cursor/ut-d4-directory`. Parent `fd67ba2a1`. Base `rc/20261108`. +77/−0.

`Tests/AppUITests/Fixture_d4_directoryTests.swift` (+65) launches `--design-fixture d4-directory` in English and zh-Hans. It waits for a hittable element, rejects an unknown fixture, a raw dotted key, and the word Questify outside a DEBUG label, and keeps screenshots `d4-directory-en` and `d4-directory-zh`. `project.pbxproj` is +12/−0 and registers only this file in QuestifyUITests. No App view change. Not merged. Xcode Cloud has not run it.
