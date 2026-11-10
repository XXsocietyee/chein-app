# ut-d2-search

[x] 40bb3243b26dc07226ab812775b24abe76a1328d

PR 1036. Branch `cursor/ut-d2-search`. Parent `fd67ba2a1`. Base `rc/20261108`. +74/−0.

`Tests/AppUITests/Fixture_d2_searchTests.swift` launches `--design-fixture d2-search` in English and zh-Hans. It waits for a hittable element, rejects an unknown fixture, a raw dotted key, and the word Questify outside a DEBUG label, and keeps screenshots `d2-search-en` and `d2-search-zh`. The app may be foreground or background. No App view change. The Xcode project was not regenerated, so this file is not in the UI-test target until `generate_project.py` runs. Not merged to rc. Xcode Cloud has not run this test yet.
