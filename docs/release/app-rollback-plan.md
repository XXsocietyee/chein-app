# App rollback plan

This is a plan for the iOS app. It does not roll anything back. It does not sign, submit, expire a TestFlight build, pause a phased release, or remove the app from sale. The owner does those steps. This plan is not a deploy, and it is not the phrase "deploy now".

Checked against `origin/rc/20261108` at `67053ccb33c0e1ad35a7508f8546ae9076fd82e5` (2026-11-08 PT).

## What this repo can name

The committed pair is marketing version `0.1.0` and build `1` in `Config/Base.xcconfig`. No older uploaded pair is recorded here. This plan does not invent one.

The parent commit of this note is `67053ccb33c0e1ad35a7508f8546ae9076fd82e5` on `rc/20261108`. That is the known tree before this documentation change. It is not a previously shipped binary.

Settings → About shows the installed pair: Version / 版本 and Build / 构建版本. Those rows read `CFBundleShortVersionString` and `CFBundleVersion`.

`Core/ProductionCanaryRolloutAndPhasedReleaseContract.swift` is an in-repo model of seven day-by-day percentages. It is not an App Store Connect phased release, and this plan does not call it.

## If a later build has to be withdrawn

1. Stop. Nothing in this file is permission to change App Store Connect.
2. Read the bad pair from the install's About screen, or from the archive Info.plist. Write it down outside this repo. Do not add an uploaded build number to this plan unless the owner already published that number.
3. Pick the last known-good commit. To undo this documentation change only, that commit is `67053ccb33c0e1ad35a7508f8546ae9076fd82e5`. Check it out in a separate worktree. Do not reset `rc/20261108`, `main`, or `master`.
4. A store rollback is a new build of that tree, not a second upload of the same pair. Apple refuses a repeated marketing version and build. In the worktree, set `CURRENT_PROJECT_VERSION` in `Config/Base.xcconfig` to one greater than every build this scheme has already issued, including the bad one. Keep `MARKETING_VERSION` unless the owner wants a new user-visible version; if it changes, it has to compare greater, and the build integer still increases. Follow `docs/release/version-scheme.md`. This plan does not edit the numbers.
5. Run `python3 -B tools/archive_unsigned.py`. Continue only when it exits 0 and prints the new pair, `signing: no`, and `upload: no`. On this commit it exits 1: the account-deletion check still expects `composition` itself to be `makeComposition(reviewed: nil, build: .current)`, and the property is `shippedComposition(build: .current)`. Do not pass `--archive` while that check fails. The preflight returns before `xcodebuild`. On a later green run, `--archive` on a Mac writes `.build/unsigned-archive/Questify.xcarchive` with signing forced off. The owner signs that archive on the signing machine. This plan does not sign, does not upload, and does not change the checker.
6. TestFlight: the owner can stop testing the bad build in App Store Connect. An older install stays on a device until that tester updates, or until the owner expires the older build. This repo cannot expire a build.
7. App Store: a released version is not replaced by turning an older build number back on. The owner can pause a phased release or remove the version from sale, then submit the new pair from step 4. This plan does not pause, remove, or submit.
8. After the owner installs the new signed build, confirm About shows the new pair. Then stop.

## Out of scope

- Do not roll the app back by deploying or restarting the backend. `docs/release/backend-deploy-plan.md` is a different plan. It does not run as part of this one. Do not contact `47.103.124.64`. Do not copy a route table or `application.yml` into this repo.
- Do not delete accounts, TestFlight groups, or tester data from this repo. The account-cancellation row stays the blocked explanation. `python3 -B tools/check_account_deletion_path.py` does not apply a deletion.
- Do not ship the unsigned archive as the rollback binary. `CODE_SIGNING_ALLOWED=NO` produces an archive the store will not take. The owner signs.
