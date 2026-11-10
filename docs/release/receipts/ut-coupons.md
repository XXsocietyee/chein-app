# ut-coupons

[x] d822e830915335fd2542ef2a0445cd9900b4acad

PR 1037. Branch `cursor/ut-coupons`. Parent `fd67ba2a1`. Base `rc/20261108`. +63/−0.

`Tests/AppUITests/Fixture_couponsTests.swift` launches `--design-fixture coupons` in English and zh-Hans. It waits for a hittable element, rejects an unknown fixture, a raw dotted key, and the word Questify outside a DEBUG label, and keeps screenshots `coupons-en` and `coupons-zh`. No App view change. Not in the Xcode target until the project is regenerated. Not merged to rc. Xcode Cloud has not run this test yet.
