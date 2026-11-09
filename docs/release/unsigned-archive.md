# Unsigned archive

Not signed. Not uploaded. The owner signs and submits. This note does not run `--archive`.

Checked against `origin/rc/20261108` at `67053ccb33c0e1ad35a7508f8546ae9076fd82e5` (2026-11-08 PT). `docs/release/ship-prep.md` describes the same script against an earlier commit. The version check below was added after that note.

## What the script does

`tools/archive_unsigned.py` is a preflight. With no arguments it does not run `xcodebuild`.

```bash
python3 -B tools/archive_unsigned.py
```

This command was run in this workspace. It exited 1. It did not run `xcodebuild`. The version lines are printed by the script; the other lines are the checks it already ran:

```text
Sign in with Apple entitlement: kept. Capability slot already exists. No other entitlement added.
FAIL: shipped composition is not makeComposition(reviewed: nil, build: .current)
deleted an account: no
marketing version: 0.1.0
build: 1
version source: Config/Base.xcconfig
FAIL: account-deletion path check failed
```

`marketing version`, `build`, and `version source` come from `Config/Base.xcconfig`. The script reads those numbers. It does not write them. `preflight: ok` is printed only when every check passes. It was not printed.

The privacy manifest, English and zh-Hans usage strings, and ATS checks produced no failure on this run. The Sign in with Apple slot is the existing one. `tools/check_account_deletion_path.py` was not edited. It prints `deleted an account: no` and does not send `POST api/user/deregister/apply`. It exits 1 because `RegionalLaunchConfiguration.composition` is `shippedComposition(build: .current)`, while the checker still requires that property body to be the `makeComposition(reviewed: nil, build: .current)` call. `shippedComposition` returns that call when its `admitsShippedChina` guard fails. The Swift tests `ReviewedChinaLaunchTests` and `WP04OwnerDecisionGuardTests` already expect `shippedComposition`. This note does not change the checker or the composition. Until they agree, `--archive` returns at the preflight and does not create an archive.

## Gap this change closes

Before this change the preflight could pass while the archive's version came from somewhere else. `Config/Base.xcconfig` includes `Local.xcconfig` after `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION`. A later xcconfig assignment replaces an earlier one, and `Config/Local.xcconfig` is gitignored, so a signing machine could archive a pair that is not the committed pair. The project file could also have grown its own copy.

The preflight now fails unless all of these hold:

- `Config/Base.xcconfig` assigns each key once, before the `Local.xcconfig` include.
- The marketing version matches `major.minor.patch` and the build is one positive integer.
- No other file under `Config/` ending in `.xcconfig` assigns either key. That includes a gitignored `Local.xcconfig` or `Local.*.xcconfig` when the file is present. The failure names the file and the key. It does not print the local value.
- A symlink at `Config` or at one of those xcconfig paths fails the preflight unread.
- `Config/Info.plist` does not contain `CFBundleShortVersionString` or `CFBundleVersion`.
- `Questify.xcodeproj/project.pbxproj` and `tools/generate_project.py` do not name either build setting.

The current numbers stay `0.1.0` and `1`. The scheme is `docs/release/version-scheme.md`.

## Archive command

`python3 -B tools/archive_unsigned.py --archive` is the only archive command. It is opt-in. It still runs the preflight first. The `xcodebuild` invocation is fixed:

- scheme `Questify`, configuration `Release`, destination `generic/platform=iOS`
- archive path `.build/unsigned-archive/Questify.xcarchive` (`.gitignore` already ignores `.build/`)
- `CODE_SIGNING_ALLOWED=NO`
- `CODE_SIGNING_REQUIRED=NO`
- `CODE_SIGN_IDENTITY=`
- `AD_HOC_CODE_SIGNING_ALLOWED=NO`
- the action is `archive`

That command does not export an IPA. It does not pass a team, a profile, or a certificate. The script rejects any extra argument that names upload or signing, including a team, a profile, `altool`, `notarytool`, Transporter, `appstoreconnect`, an API key, `.p12`, `.p8`, and `.mobileprovision`. The refusal exits 2 and does not archive.

Release uses `Config/Base.xcconfig`, not `Config/China.Production.xcconfig`. The committed bundle id is `invalid.example.questify.ios`. `QUESTIFY_API_BASE_URL` and `QUESTIFY_SESSION_REALM` are empty, so `RegionalLaunchConfiguration.shippedComposition` stays `makeComposition(reviewed: nil, build: .current)`.

This workspace did not pass `--archive`. It did not create `Questify.xcarchive`.
