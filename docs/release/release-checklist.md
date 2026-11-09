# Release checklist

Not submitted. Not signed. Not deployed. The owner signs. This checklist does not refresh `tools/current_ci_manifest.json` and does not delete tests.

Base: `origin/rc/20261108` at `67053ccb33c0e1ad35a7508f8546ae9076fd82e5` (2026-11-08 PT). The committed pair stays `0.1.0` (`1`).

`docs/release-readiness-checklist.md` is an older readiness note. It is still in the tree. This file does not replace it and does not follow its sample `Local.xcconfig` URL. `docs/release/app-store-metadata-checklist.md` and `docs/release/ship-prep.md` were checked against `a6871477c497c6440ce06417035572d7278ea830`. They stay as they are.

## In this change

- [x] Version scheme: `docs/release/version-scheme.md`
- [x] Unsigned archive notes: `docs/release/unsigned-archive.md`
- [x] TestFlight notes, English and zh-Hans: `docs/release/testflight-notes.md`
- [x] App rollback plan: `docs/release/app-rollback-plan.md`
- [x] `tools/archive_unsigned.py` reports the pair and rejects a second assignment. It still does not sign or upload.

## Run before the owner signs

These commands do not take a team, a profile, or an upload flag.

- [x] `python3 -B tools/check_account_deletion_path.py` prints `deleted an account: no` and exits 1. Its only failure is `shipped composition is not makeComposition(reviewed: nil, build: .current)`. `composition` is `shippedComposition(build: .current)`. The script was not edited and does not apply a deletion.
- [x] `python3 -B tools/archive_unsigned.py` prints `marketing version: 0.1.0`, `build: 1`, and `version source: Config/Base.xcconfig`, then exits 1 with `account-deletion path check failed`. It does not print `preflight: ok`. It does not run `xcodebuild`.
- [x] The same script with an upload or team argument exits 2 before the preflight and does not archive.
- [ ] Make the account-deletion check and `shippedComposition` describe the same unconfigured return, without opening the apply route. This checklist does not do that.
- [ ] On a Mac, and only after the preflight exits 0: `python3 -B tools/archive_unsigned.py --archive`. This workspace did not run it. The product would be `.build/unsigned-archive/Questify.xcarchive` with signing forced off. It is not an IPA. A failing preflight returns before that command.

`Config/Local.xcconfig` may hold the team and the production bundle id on the signing machine. It must not assign `MARKETING_VERSION` or `CURRENT_PROJECT_VERSION`. The preflight fails if it does.

## Owner only

- [ ] Confirm Settings → About shows `0.1.0` and `1` on a signed install of this pair, or the later pair the owner actually built.
- [ ] Replace the placeholder bundle id `invalid.example.questify.ios`. Put the team in gitignored `Config/Local.xcconfig`. No committed xcconfig sets `DEVELOPMENT_TEAM`.
- [ ] Sign the archive. This repo does not hold a distribution certificate or a profile.
- [ ] Upload the signed build. Paste `docs/release/testflight-notes.md` into the matching TestFlight locale. Do not treat that file as already submitted.
- [ ] Decide export compliance, the privacy-policy URL, screenshots, and the account-deletion answer. Those items are still open in `docs/release/app-store-metadata-checklist.md`.
- [ ] Submit. Do not submit from this branch.

## Not in this checklist

- No deploy. Backend deploy stays `docs/release/backend-deploy-plan.md`, and that plan is not approval.
- No visual restyle.
- No CI ledger refresh.
- No test deletions.
