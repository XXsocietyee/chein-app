# ut-consent

[x] 171c3db3b1a00ee52e772a8a3ff592842fd49c6a

PR 1035. Branch `cursor/ut-consent`. Parent `fd67ba2a1`. Base `rc/20261108`. +74/−0.

`Tests/AppUITests/Fixture_consentTests.swift` launches `--design-fixture consent` in English and zh-Hans. It waits for a hittable element, rejects an unknown fixture, a raw dotted key, and the word Questify outside a DEBUG label, and keeps screenshots `consent-en` and `consent-zh`. No App view change. The Xcode project was not regenerated, so this file is not in the UI-test target until `generate_project.py` runs. Not merged to rc. Xcode Cloud has not run this test yet.
