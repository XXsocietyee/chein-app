# ut-d4-confirm

[x] e321bcefc77c61c4f055c1e32da16bea37a3eb65

PR 1038. Branch `cursor/ut-d4-confirm`. Parent `fd67ba2a1`. Base `rc/20261108`. +63/−0.

`Tests/AppUITests/Fixture_d4_confirmTests.swift` launches `--design-fixture d4-confirm` in English and zh-Hans. It waits for a hittable element, rejects an unknown fixture, a raw dotted key, and the word Questify outside a DEBUG label, and keeps screenshots `d4-confirm-en` and `d4-confirm-zh`. No App view change. Not in the Xcode target until the project is regenerated. Not merged to rc. Xcode Cloud has not run this test yet.
