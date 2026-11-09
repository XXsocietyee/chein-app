# CB82 Release build

A Release build was not run.

Read from `origin/rc/20261108` at `89dcba807e7e5439182ff8852d6600d1fa9fdd49`. The project file is unchanged. Signing is unchanged. Version stays 0.1.0 (1).

`xcodebuild` is not installed in this environment. No archive was produced. No binary size is recorded.

## Questify target Release

`Questify.xcodeproj/project.pbxproj`, object `DD75E2CB1C510A828AC72D96`, `isa = XCBuildConfiguration`, `name = Release`. It belongs to target `Questify` (`34A04005BCAF206EEC990BD9`) through configuration list `1B672BF3DA427763BF644BE3`.

`baseConfigurationReference` is `CAE662172FD450BB0CD710A7`, file reference `Config/Base.xcconfig`.

`buildSettings` as written:

| Key | Value |
|---|---|
| `PRODUCT_NAME` | `$(TARGET_NAME)` |
| `SUPPORTED_PLATFORMS` | `iphoneos iphonesimulator` |
| `SWIFT_EMIT_LOC_STRINGS` | `YES` |
| `FRAMEWORK_SEARCH_PATHS` | `$(inherited) $(BUILT_PRODUCTS_DIR)` |
| `LD_RUNPATH_SEARCH_PATHS` | `$(inherited) @executable_path/Frameworks` |
| `SWIFT_OBJC_BRIDGING_HEADER` | `$(SRCROOT)/App/Questify-Bridging-Header.h` |
| `CODE_SIGN_ENTITLEMENTS` | `Config/Questify.entitlements` |
| `SWIFT_OPTIMIZATION_LEVEL` | `-O` |
| `DEBUG_INFORMATION_FORMAT` | `dwarf-with-dsym` |
| `EXCLUDED_SOURCE_FILE_NAMES` | `$(inherited) AppStoreReviewDemoAccountAndFixtureSectionView.swift` |

## Project Release

Same file, object `0B0C687DF8B6B8DC790B519C`, `name = Release`. It is the project configuration list `76F8DEC3DFE0BDB465198890` (`buildConfigurationList` of `PBXProject` `244210E48437B6556980A702`). `defaultConfigurationName` is `Release`.

`buildSettings` as written:

| Key | Value |
|---|---|
| `SDKROOT` | `iphoneos` |
| `CLANG_ENABLE_MODULES` | `YES` |

This block assigns no strip key, no `DEBUG_INFORMATION_FORMAT`, no optimization key, and no `CODE_SIGN*` key.

`Questify.xcodeproj/xcshareddata/xcschemes/Questify.xcscheme` sets `ArchiveAction` `buildConfiguration="Release"`. That is the scheme name for archive. It is not a build result.

## Strip

No strip setting is assigned on the Questify target Release block, the project Release block, or `Config/Base.xcconfig`.

These keys are absent from all three:

- `STRIP_INSTALLED_PRODUCT`
- `STRIP_STYLE`
- `STRIP_SWIFT_SYMBOLS`
- `SEPARATE_STRIP`
- `COPY_PHASE_STRIP`
- `DEPLOYMENT_POSTPROCESSING`
- `DEAD_CODE_STRIPPING`

## dSYM

`DEBUG_INFORMATION_FORMAT = dwarf-with-dsym` is set on the Questify target Release block (`DD75E2CB1C510A828AC72D96`).

`DEBUG_INFORMATION_FORMAT` is absent from the project Release block and from `Config/Base.xcconfig`.

## Optimization

`SWIFT_OPTIMIZATION_LEVEL = -O` is set on the Questify target Release block (`DD75E2CB1C510A828AC72D96`).

`GCC_OPTIMIZATION_LEVEL`, `SWIFT_COMPILATION_MODE`, and `LLVM_LTO` are absent from the Questify target Release block, the project Release block, and `Config/Base.xcconfig`.

## CODE_SIGNING

Settings present in those files:

| Where | Key | Value |
|---|---|---|
| Questify target Release `DD75E2CB1C510A828AC72D96` | `CODE_SIGN_ENTITLEMENTS` | `Config/Questify.entitlements` |
| `Config/Base.xcconfig` line 15 | `CODE_SIGN_STYLE` | `Automatic` |

`CODE_SIGN_STYLE` is on the base configuration the Questify target Release references. The target Release `buildSettings` do not assign `CODE_SIGN_STYLE` themselves.

These keys are absent from the Questify target Release block, the project Release block, and `Config/Base.xcconfig`:

- `CODE_SIGNING_ALLOWED`
- `CODE_SIGNING_REQUIRED`
- `CODE_SIGN_IDENTITY`
- `DEVELOPMENT_TEAM`
- `PROVISIONING_PROFILE`
- `PROVISIONING_PROFILE_SPECIFIER`

`Config/Local.xcconfig` is not in this checkout (`Config/Local.xcconfig` is gitignored). `Config/Local.xcconfig.example` leaves `DEVELOPMENT_TEAM` as a comment. No team or signing identity was added.

## Version

`Config/Base.xcconfig` sets `MARKETING_VERSION = 0.1.0` and `CURRENT_PROJECT_VERSION = 1`. The Questify target Release `buildSettings` do not assign either key. Version stays 0.1.0 (1).
