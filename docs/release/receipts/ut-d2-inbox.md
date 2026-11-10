# ut-d2-inbox

[x] 42255c2d1ea32558c66ff50220c82f65a2bf2646

PR 1052. Branch `cursor/ut-d2-inbox`. Parent `fd67ba2a1`. Base `rc/20261108`. +101/−0.

`Tests/AppUITests/Fixture_d2_inboxTests.swift` launches `--design-fixture d2-inbox` in English and zh-Hans. It waits for a hittable element, rejects an unknown fixture, a raw dotted key, and the word Questify outside a DEBUG label, and keeps screenshots `d2-inbox-en` and `d2-inbox-zh`. No App view change. Not in the Xcode target until the project is regenerated. Not merged. Xcode Cloud has not run it.
