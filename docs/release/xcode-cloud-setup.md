# Xcode Cloud setup

Xcode Cloud is the primary CI path for this repository. The steps below are what an Account Holder or Admin on team **9VHY8N755R** does in App Store Connect and GitHub. This repository does not sign in to Apple, does not store a certificate or provisioning profile, and does not contain a secret.

## Recorded for this product

These values were confirmed by the owner. This file does not add a certificate, profile, API key, or token.

| Item | Value |
| --- | --- |
| Xcode Cloud product id | `1efa6d8b-ccc0-4b91-8c34-c6884c183a8a` |
| Workflow display name | `chein - 城瘾` |
| Start | Branches `rc/*`, with auto-cancel |
| Actions | Build iOS and Test iOS. Scheme `Questify`. Destination Recommended iPhones. Archive is off. |
| App Store Connect app id | `6832441069` |
| Bundle ID in the product docs | `com.chengyinhub.chengyinApp` |
| Repository access | Granted for `liboyang42-cpu/chengyin-app` only |

`xcodecloud/manifest.json` is absent. A search of this tree found no `xcodecloud` directory and no file at that path. On tip `5f9a01625e0f33ac47a843d95959f6f005c53f27` the Xcode Cloud setup document was this file. Other release notes mention Xcode Cloud, and none of them is a manifest. There is no manifest product id, workflow name, scheme, or bundle id to compare, so this note records neither a match nor a mismatch. This change does not add a manifest.

No Xcode Cloud build result and no Xcode Cloud test result are recorded here. This checkout cannot read Xcode Cloud, and `xcodebuild` was not run.

Real signing stays in `Config/Local.xcconfig`, which is gitignored. Do not commit that file. Do not change `Config/Base.xcconfig`. The placeholder `PRODUCT_BUNDLE_IDENTIFIER` there stays `invalid.example.questify.ios` (the unit-test bundle in `Config/AppUnitTests.xcconfig` stays `invalid.example.questify.ios.appunittests`).

## What a fresh checkout already has

`Questify.xcodeproj/xcshareddata/xcschemes/Questify.xcscheme` is a shared scheme. Its Test action uses the shared test plan `Questify.xcodeproj/xcshareddata/xctestplans/QuestifyAppUnitTests-Shards.xctestplan`. That plan includes `QuestifyAppUnitTests` and `QuestifyUITests`, and both skip lists are empty.

Before this change, the Questify scheme Test action did not run the AppUnit shards. It listed only `QuestifyUITests`. `QuestifyAppUnitTests.xcscheme` is still shared next to it and still runs the whole `QuestifyAppUnitTests` target, with no skipped tests.

The committed `Questify.xcodeproj/project.pbxproj`, `Questify.xcscheme`, `QuestifyAppUnitTests.xcscheme`, and `QuestifyAppUnitTests-Shards.xctestplan` match `python3 tools/generate_project.py` byte for byte. A fresh checkout can build the Questify scheme without running the generator. `ci_scripts/ci_post_clone.sh` does not run it.

`Vendor/GLTFKit2` is already built for iOS 17.0. The upstream project pin is `IPHONEOS_DEPLOYMENT_TARGET = 12.1`. `python3 tools/check_gltf_source.py` rebuilds those upstream bytes by reversing only that substitution, then checks the pinned Git blob and SHA-256. No tool script rewrites the deployment target, and the post-clone script does not either.

## Unsigned CI builds

`ci_scripts/ci_post_clone.sh` runs `python3 tools/xcode_cloud_prepare.py --checkout` on the temporary Xcode Cloud checkout. That writes `CODE_SIGNING_ALLOWED = NO` and `CODE_SIGNING_REQUIRED = NO` into:

- `Config/Base.xcconfig`
- `Config/AppUnitTests.xcconfig`
- every build-settings block in `Questify.xcodeproj/project.pbxproj`
- every build-settings block in `Vendor/GLTFKit2/GLTFKit2.xcodeproj/project.pbxproj` (the subproject does not inherit the app xcconfig)

Those edits stay on the CI machine. Do not run the prepare script in a local checkout. Do not commit the result. The repository copy of `Config/Base.xcconfig` stays unchanged, including the placeholder bundle id.

Also set the same value as a workflow environment variable (the remaining step below). That is the setting `xcodebuild` applies to every target, including the embedded framework. Leave it unredacted. It is not a secret. The owner-confirmed facts above do not say whether this variable is already set on the workflow.

## Test shards

The confirmed workflow has one Test iOS action, on scheme `Questify`, not four Test actions. The Questify scheme Test action uses `QuestifyAppUnitTests-Shards.xctestplan`. That plan’s `QuestifyAppUnitTests` entry has an empty skip list, so the single Test iOS action runs every app-unit class the four shard plans partition. Its `QuestifyUITests` entry also has an empty skip list, so the UI tests that the Questify scheme already ran stay in the Test action. Nothing in the shard plans was deleted. The shard schemes were not edited.

Four shared schemes still each point at one test plan. Those schemes remain for a run that selects them directly. The confirmed workflow does not select them.

| Scheme | Test plan | Classes included |
| --- | --- | --- |
| `QuestifyAppUnitTests-Shard01` | `Questify.xcodeproj/xcshareddata/xctestplans/QuestifyAppUnitTests-Shard01.xctestplan` | 202 |
| `QuestifyAppUnitTests-Shard02` | `QuestifyAppUnitTests-Shard02.xctestplan` | 208 |
| `QuestifyAppUnitTests-Shard03` | `QuestifyAppUnitTests-Shard03.xctestplan` | 224 |
| `QuestifyAppUnitTests-Shard04` | `QuestifyAppUnitTests-Shard04.xctestplan` | 217 |

The four plans together include each of the 851 `XCTestCase` classes under `Tests/AppUnitTests` once. A class is omitted from a shard plan only by that plan’s skip list. The full `QuestifyAppUnitTests` scheme has no skip list. `QuestifyAppUnitTests-Shards.xctestplan` has an empty skip list for `QuestifyAppUnitTests`, so it includes the same 851 classes.

After adding or renaming an app-unit class, run `python3 tools/generate_project.py` and commit the regenerated shard schemes and test plans. The Questify shards plan does not list class names; regeneration keeps its skip list empty. CI does not regenerate them.

## Core tests

Core tests are the Swift package target `QuestifyCoreTests` (`Package.swift`, sources in `Tests/CoreTests`). They are not an Xcode test target. `ci_scripts/ci_post_xcodebuild.sh` runs `swift test` only when the action is `build` and the scheme is `Questify`, which is while the source checkout is still present. The Test iOS action does not run it again. A later Archive action does not run it either. Archive is off on the confirmed workflow.

## Owner steps

Use team **9VHY8N755R**. The App Store Connect app record uses bundle ID **com.chengyinhub.chengyinApp**. App id **6832441069**.

### Done

The outcomes below are the owner-confirmed facts. This change did not open App Store Connect.

1. **Done.** Xcode Cloud is enabled for this app. Product id `1efa6d8b-ccc0-4b91-8c34-c6884c183a8a`.
2. **Done.** Repository access is granted for `liboyang42-cpu/chengyin-app` only.
3. **Done.** The app record exists. App Store Connect app id `6832441069`. Bundle ID in the product docs: `com.chengyinhub.chengyinApp`.
4. **Done.** The workflow display name is `chein - 城瘾`. Scheme `Questify`.
5. **Done.** Start condition: branches `rc/*`, with auto-cancel.
6. **Done.** Actions: Build iOS and Test iOS. Destination: Recommended iPhones. Archive is off. The workflow is the saved product above.
7. **Done in the repository.** The Questify scheme Test action uses `QuestifyAppUnitTests-Shards.xctestplan`, so Test iOS on scheme `Questify` runs the AppUnit shards and the UI tests. This is a file change. It is not an Xcode Cloud run.

### Not done

8. Open the workflow **Environment**. The confirmed facts do not include an Xcode version or any environment variable.
   1. Choose the newest Xcode version in the list. See “Not verified” below before assuming that entry is Xcode 27.
   2. Under environment variables, click **+**. Name: `CODE_SIGNING_ALLOWED`. Value: `NO`.
   3. Leave **Secret** / **Keep value redacted** unchecked. Add no other variable, API key, certificate, or profile.
9. Do not start a build from this change. On a branch that matches `rc/*`, a later **Start Build** is still an owner action. Each Test iOS run compiles the tests on that action. No build result and no test result are known from this checkout.

## Not verified

- **Current free compute hours** for team 9VHY8N755R. The remaining Xcode Cloud balance is on the Apple account. This change does not sign in, so that number was not read.
- **Whether an Xcode 27 environment is available in Xcode Cloud.** The workflow environment list for this team was not opened. The public [Xcode Cloud release notes](https://developer.apple.com/xcode-cloud/release-notes/), as read on November 8, 2026 (Pacific time), show Xcode 26.2 added on December 19, 2025, and do not list an Xcode 27 image. That page is not the team’s environment picker. If Xcode 27 is absent from the picker, keep the newest version that is listed.
- **Whether the workflow environment variable `CODE_SIGNING_ALLOWED` is set.** The owner-confirmed facts do not include it.
- **Any Xcode Cloud build or test result.** None was read. `xcodebuild` was not run.

## GitHub-hosted runners

[GitHub-hosted runners](https://docs.github.com/en/actions/reference/runners/github-hosted-runners) lists a standard macOS label `xcode-27` (3-core Apple silicon, 7 GB RAM) for public and private repositories. The image readme [xcode-27-arm64-Readme.md](https://github.com/actions/runner-images/blob/main/images/macos/xcode-27-arm64-Readme.md), image version `20261104.0337.1`, includes Xcode 27.1 (default) and the iOS 27.0 simulator SDK, with an iPhone 18 Pro simulator on iOS 27.0. No GitHub-hosted macOS workflow was added. Existing workflows were not edited. Xcode Cloud remains the primary path; private macOS minutes are a paid fallback, not a second workflow in this change.
