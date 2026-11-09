# Version and build scheme

Not submitted. Not signed. This note does not change the numbers.

Checked against `origin/rc/20261108` at `67053ccb33c0e1ad35a7508f8546ae9076fd82e5` (2026-11-08 PT).

## Committed pair

| What testers see | Build setting | Info.plist key | Committed value |
|---|---|---|---|
| Version (版本) | `MARKETING_VERSION` | `CFBundleShortVersionString` | `0.1.0` |
| Build (构建版本) | `CURRENT_PROJECT_VERSION` | `CFBundleVersion` | `1` |

Both assignments are in `Config/Base.xcconfig`, before `#include? "Local.xcconfig"`. No other committed file assigns either key. `Questify.xcodeproj/project.pbxproj` does not contain them. `tools/generate_project.py` does not name them. `Config/Info.plist` does not contain `CFBundleShortVersionString` or `CFBundleVersion`.

The Questify app target, Debug `6C7EFF6369083C8E1F2B1994` and Release `DD75E2CB1C510A828AC72D96`, uses that file (`baseConfigurationReference` `CAE662172FD450BB0CD710A7`) and does not override the pair. `GENERATE_INFOPLIST_FILE = YES`, so Xcode writes the two Info.plist keys from the build settings. Settings → About (`设置` → `关于`) reads those keys in `SettingsAppInformation`. An unresolved `$(...)` value is shown as not provided.

`QuestifyUITests` uses the same xcconfig and overrides `PRODUCT_BUNDLE_IDENTIFIER` only. `QuestifyAppUnitTests` uses `Config/AppUnitTests.xcconfig`, which does not set the pair. `Vendor/GLTFKit2` has its own `CURRENT_PROJECT_VERSION` and is not this app's build.

The display name `Questify` is `INFOPLIST_KEY_CFBundleDisplayName`. It is not part of the pair.

## Project rules

1. Change the pair only in `Config/Base.xcconfig`. One assignment of each key. Do not set either key in `Config/Local.xcconfig`, `Config/Local.*.xcconfig`, any other xcconfig, `Config/Info.plist`, the Xcode project, or `tools/generate_project.py`.
2. `Config/Base.xcconfig` includes `Local.xcconfig` after the pair. A later assignment replaces an earlier one, so a local file would silently replace `0.1.0` and `1`. `python3 -B tools/archive_unsigned.py` rejects that second assignment. It does not print the local value.
3. The marketing version is `major.minor.patch`. Each component is `0` or a decimal integer without a leading zero. No prerelease suffix and no build metadata.
4. The build is one positive decimal integer, with no dot and no leading zero. It is not a second copy of the marketing version.
5. The next archive that the owner intends to upload keeps the marketing version and increases the build by 1. Build `1` is not reused for `0.1.0`.
6. The build integer does not go back to `1` when the marketing version changes. It stays one greater than the last build this scheme issued.
7. A new user-visible release uses a marketing version that is greater in major, then minor, then patch. The owner decides when. This note does not pick the next version.
8. This change leaves the pair at `0.1.0` and `1`.

## Store rules this scheme follows

Xcode's help says to increment the build string before archiving a build you intend to upload or export, and to increment the version number when you create a new app version in App Store Connect. The pair identifies the build for crash reports and dSYM files.

Apple Technical Note TN2420 treats an iOS build number as unique inside one marketing version, and allows the same build number on a later marketing version. A macOS build number has to increase across versions. This target is iOS only: `IPHONEOS_DEPLOYMENT_TARGET = 17.0` and `TARGETED_DEVICE_FAMILY = 1,2`. Rule 6 is stricter than that iOS minimum so a pair cannot collide and the integer in Settings keeps moving forward.

Uploading is the owner's step. This scheme does not upload.
