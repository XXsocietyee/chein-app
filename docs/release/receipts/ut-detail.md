# ut-detail

[x] 055d307935f72715c7f7a59839c9bc3faa32b5dc

PR 1071. Branch `cursor/ut-detail`. Parent `be8d7b31e`. Base `rc/20261108`. +79/−0.

`Tests/AppUITests/Fixture_detailTests.swift` launches `--design-fixture detail` in English and zh-Hans. It waits for a hittable element, rejects an unknown fixture, a raw dotted key, and the word Questify outside a DEBUG label, and keeps screenshots `detail-en` and `detail-zh`. Parent is a docs-only rc commit. No App view change. Not in the Xcode target until the project is regenerated. Not merged. Xcode Cloud has not run it.
