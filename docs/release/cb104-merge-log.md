# CB104 merge

Base: `origin/rc/20261108` `027e4985c53164127fd7bfd2b4845efbfc4c9e0b`.
Branch: `cursor/cb104`.
Checked: 2026-11-09 04:58 America/Los_Angeles. Source inspection and the two Python commands below. This VM did not run Xcode.

Merged with `git merge --no-ff`, in this order:

| Order | Tip | Merge |
|---|---|---|
| 1 | `origin/cursor/cb99` `df74c98e16eb6fa7b2c44d09051436b70a6385a9` | `cbc5ef38724b89adcff805d4c7aa2bda9dc437e5` |
| 2 | `origin/cursor/cb100` `4e5430de8037319d34028335ea3cf962c957f7c1` | `d65dd6c7c879210ee4993aaa2f52ede6a177c5e3` |
| 3 | `origin/cursor/cb101` `4b272dadafd211bc3fecb96a7a06203d1bfe63f9` | `5c0b9e62324bbdb4dc8010ff11e35ee9784fd2e7` |

Each parent is already an ancestor of the base, so each merge brings that tip only. All three applied with the `ort` strategy and no conflicts.

## What landed

- CB99 adds `docs/release/cb99-accessibility-ids.md`. It records accessibility identifiers against this base and `origin/ui/d6` `b85ae2741cba5afe0a1320097833e69cb9eb23a0`. It does not change a view and does not add an identifier. `ui/d6` was not merged.
- CB100 changes `NSPhotoLibraryAddUsageDescription` and adds `docs/release/cb100-privacy.md`. The installed sentence is the only product edit. English in `Config/Info.plist` and `Resources/InfoPlist.xcstrings`, and zh-Hans in the catalog, now say the app saves a walk card, a medal card, or a city stamp slip picture to Photos when the person chooses Save to Photos. No other usage key changed.
- CB101 adds `docs/release/cb101-codex-picks.md`. It records that the next ten Codex branch names after the CB87 rows are absent. No code was taken from them.

## Left as it was

`Resources/PrivacyInfo.xcprivacy` is byte-identical to the base (`8504d5b4b26eed92258296ed7ef52d994372e35c`). File Timestamp still lists `C617.1` and `3B52.1`. User Defaults stays `CA92.1`. System Boot Time stays `35F9.1`. `NSPrivacyTracking` is false and `NSPrivacyTrackingDomains` is empty.

CB100's note was written against `576e869a995c280f325799ad8ea9a2729ac30781`, where `3B52.1` is absent, and that commit does not edit the manifest. This merge does not treat that sentence as an instruction to drop the reason. The required-reason code already on the base stays.

No tracking SDK was added. Outside `docs/`, the diff against the base is only the photo-library add sentence in `Config/Info.plist` and `Resources/InfoPlist.xcstrings`.

`origin/ui/d7` was not fetched and was not merged.

`.github/workflows/ios-ci.yml` (`3af977942405d29e9cae0fdafd75737f1a3408f8`) and `tools/current_ci_manifest.json` (`743958754af4608942e3a86019e71fa499eba78b`) were not edited. Version stays `0.1.0` (`1`) in `Config/Base.xcconfig`. No test path was deleted.

`python3 -B tools/archive_unsigned.py` (no `--archive`) reported preflight ok, signing no, upload no, and `xcodebuild: not run`. `Tests.ContractChecks.test_app_store_privacy_launch_contracts` and `Tests.ContractChecks.test_privacy_manifest_contract` reported 10 tests OK. `test_add_only_usage_description_and_localization_fragments_exist` reported OK. Those checks read source files. They do not compile Swift.

## Scaffold

`python3 tools/generate_project.py` exited 0:

```
Generated Questify.xcodeproj: 3296 native sources, 200 catalogs
Included 781 app-unit sources in the separate QuestifyAppUnitTests scheme
Wrote 4 shared app-unit shards covering 851 classes: 202, 208, 224, 217
```

Every file under `Questify.xcodeproj` had the same SHA-256 after that command as before it. The checkout project already matches the generator, so the generator output is the file already on this branch. It was not rewritten and it was not hand-edited.

`python3 -B tools/check_scaffold.py` exited 0:

```
missing_keys: 0
untranslated_values: 0
key_identifier_mismatches: 0
gaps: 0
PASS design lint: scanned 1458 App Swift files outside DesignSystem and Theme; allowlist 11 files (13 existing violations)
PASS structural checks: 4354 Swift source files, 14346 bilingual keys, references, scheme, read-only expected project equivalence
SCOPE: this script does not run Swift/Xcode, previews, simulator/device, accessibility or live backend checks; see separate evidence
```
