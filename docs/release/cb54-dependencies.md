# CB54 — vendored dependencies

Base `origin/rc/20261108` `88e981b3308558939e405606cd731b4b29fc9499`. Branch `cursor/cb54`.

No dependency was added. `Package.swift` has no external package. The tree has no `Podfile`, `Package.resolved`, `.xcframework`, or static archive. `Vendor/` contains only GLTFKit2. Version stays `MARKETING_VERSION` `0.1.0` and `CURRENT_PROJECT_VERSION` `1` in `Config/Base.xcconfig`. `xcodebuild` was not run.

## What is vendored

GLTFKit2 0.5.15, upstream revision `e69e354c4f31ea07b7816b8cbe2ddb28e897d073`. `Vendor/GLTFKit2/PROVENANCE.json` lists 32 files. All 32 are present. `PROVENANCE.json` itself is the 33rd file and is not in that list. The excluded set in that file is libktx, Basis Universal, Draco, and the upstream prebuilt XCFramework. The nested project has no shell-script phase, no remote package reference, and no `ktx.xcframework`.

`App/PlayKitGLBAssets.swift` imports `GLTFKit2`. `tools/generate_project.py` links and embeds `Vendor/GLTFKit2/GLTFKit2.xcodeproj`. The app target's `SUPPORTED_PLATFORMS` is `iphoneos iphonesimulator`. The GLTFKit2 target still lists `appletvos appletvsimulator iphoneos iphonesimulator macosx xros xrsimulator`, so Xcode evaluates that project's macOS, tvOS, and visionOS deployment targets while building the iOS app.

`GLTFAssetReader.m` defines `CGLTF_IMPLEMENTATION` and imports `cgltf.h`, so the cgltf loader and the JSMN copy inside that header are compiled. `cgltf_write.h` is a Headers-phase file. No app or framework source defines `CGLTF_WRITE_IMPLEMENTATION`. The header defines it only for the IntelliSense guard. The writer is vendored and is not compiled.

These are not vendored app dependencies: Apple SDK frameworks; the WeChat OpenSDK (not in this tree); the settings credit strings for game-icons.net and ansimuz in `Core/SettingsAboutContracts.swift` (source-app credits, no artwork files).

## Deployment targets

Project-level values in `Vendor/GLTFKit2/GLTFKit2.xcodeproj/project.pbxproj`, Debug and Release:

| Setting | Upstream pin | This tree | App setting |
|---|---|---|---|
| `IPHONEOS_DEPLOYMENT_TARGET` | 12.1 | 17.0 | `Config/Base.xcconfig` and `Config/AppUnitTests.xcconfig` are 17.0. `Package.swift` is `.iOS(.v17)`. |
| `MACOSX_DEPLOYMENT_TARGET` | 11.0 | 11.0 | The app target does not set it. `Package.swift` `.macOS(.v14)` is the QuestifyCore test platform. |
| `TVOS_DEPLOYMENT_TARGET` | 12.1 | 12.1 | Not set. |
| `XROS_DEPLOYMENT_TARGET` | 1.0 | 1.0 | Not set. |

Commit `f9ca1f42405122d54561193546a351753ac63c8b` changed only the two `IPHONEOS_DEPLOYMENT_TARGET` lines from 12.1 to 17.0. That is the value the app already uses, so this branch does not bump it again and does not put 12.1 back.

Apple's published deployment-target ranges are on [SDK and system requirements](https://developer.apple.com/xcode/system-requirements/). Xcode 26, which is the range for the `macos-26` runner, supports iOS 15–26, tvOS 15–26, macOS 11–26, and visionOS 1–26. Xcode 27 supports iOS 15–27, tvOS 15–27, macOS 12–27, and visionOS 1–27. The page describes that column as the OS range for uploading to App Store Connect. Xcode prints a deployment-target warning when a target's value is outside the range.

- iOS 12.1 is below the Xcode 16, 26, and 27 floor of 15. The tree is already at 17.0, which those ranges include.
- tvOS 12.1 is below the Xcode 16, 26, and 27 floor of 15. That warning remains. The app does not declare a tvOS deployment target, so this branch does not raise it.
- macOS 11.0 is inside the Xcode 26 range and below the Xcode 27 floor of 12. It was not raised. The package's macOS 14 test platform is not a GLTFKit2 setting.
- visionOS 1.0 is inside the Xcode 26 and 27 ranges.

`python3 -B tools/check_gltf_source.py` exits 1. The other 31 pinned files match. The project file does not:

| | git blob | SHA-256 |
|---|---|---|
| `PROVENANCE.json` for `GLTFKit2.xcodeproj/project.pbxproj` | `f8ac472100e0fb7ce91d6dfff66e7e81e6c5e2e0` | `30b4ca5ada1cec58ee2ac11e9514691e54d2eeba5d3985f4935111de1b55bf00` |
| bytes in this tree | `58b29a55a98a86b2651fd6027da58b74d46bd251` | `331e3021a54e1e400dec64f2154f46fbac404b87ba7311381f48dab6f6cba3cc` |

Those provenance fields are the upstream blob. They were not rewritten. Rewriting them would record the local 17.0 edit as the upstream file.

## Licenses

Every MIT block already in the vendored tree is copied into [`cb54-oss-notices.txt`](cb54-oss-notices.txt). The blocks are the file bytes, or the named line range, with no sentence added inside a block.

| Block | Copyright line in the vendored text |
|---|---|
| `Vendor/GLTFKit2/LICENSE` | Copyright (c) 2021 Warren Moore |
| `GLTFKit2/GLTFKit2.h` lines 1–16 | Copyright (c) 2021 Warren Moore |
| `README.md` lines 181–196 | Copyright (c) 2021—2024 Warren Moore |
| `deps/cgltf/LICENSE` | Copyright (c) 2018-2021 Johannes Kuhlmann |
| `cgltf.h` lines 6811–6835 | Copyright (c) 2010 Serge A. Zaitsev (JSMN) |
| `cgltf.h` lines 7154–7175 | Copyright (c) 2018-2021 Johannes Kuhlmann |
| `cgltf_write.h` lines 1544–1565 | Copyright (c) 2019-2021 Philip Rideout |

`Resources/GLTFKit2Notices.txt` is already a Questify resource (`tools/generate_project.py` copies `Resources/*Notices.txt`). It contains the GLTFKit2 `LICENSE` text, the cgltf `LICENSE` text, and the JSMN block. It does not contain the README year range, the umbrella-header line wrapping, or the Philip Rideout block. That resource was not edited. The new notice file is under `docs/release/`, so the generator does not copy it into the app.

## Settings screen

The notice text is not shown. No settings row and no view were added.

`tools/check_scaffold.py` requires every `App/*.swift` file to be a member of `Questify.xcodeproj/project.pbxproj`. That project file is one of the exact inputs in `tools/club_customer_directory_admission.py`. Neither file was edited, so a view was not added.

The existing placeholder is `SettingsUnavailableFeatureView` in `App/SettingsSupportSections.swift`: a `Form` whose first section is `Label("settingsNative.blocked.unavailable")`. A later view must keep that body, and must not read `docs/release/cb54-oss-notices.txt`, until the owner approves showing the notices.
