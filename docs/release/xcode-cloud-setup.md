# Xcode Cloud setup

Xcode Cloud is the primary CI path for this repository. The steps below are what an Account Holder or Admin on team **9VHY8N755R** does in App Store Connect and GitHub. This repository does not sign in to Apple, does not store a certificate or provisioning profile, and does not contain a secret.

## What a fresh checkout already has

`Questify.xcodeproj/xcshareddata/xcschemes/Questify.xcscheme` is a shared scheme. `QuestifyAppUnitTests.xcscheme` is shared next to it and still runs the whole `QuestifyAppUnitTests` target, with no skipped tests.

The committed `Questify.xcodeproj/project.pbxproj` and those two schemes match `python3 tools/generate_project.py` byte for byte. A fresh checkout can build the Questify scheme without running the generator. `ci_scripts/ci_post_clone.sh` does not run it.

`Vendor/GLTFKit2` is already built for iOS 17.0. The upstream project pin is `IPHONEOS_DEPLOYMENT_TARGET = 12.1`. `python3 tools/check_gltf_source.py` rebuilds those upstream bytes by reversing only that substitution, then checks the pinned Git blob and SHA-256. No tool script rewrites the deployment target, and the post-clone script does not either.

## Unsigned CI builds

`ci_scripts/ci_post_clone.sh` runs `python3 tools/xcode_cloud_prepare.py --checkout` on the temporary Xcode Cloud checkout. That writes `CODE_SIGNING_ALLOWED = NO` and `CODE_SIGNING_REQUIRED = NO` into:

- `Config/Base.xcconfig`
- `Config/AppUnitTests.xcconfig`
- every build-settings block in `Questify.xcodeproj/project.pbxproj`
- every build-settings block in `Vendor/GLTFKit2/GLTFKit2.xcodeproj/project.pbxproj` (the subproject does not inherit the app xcconfig)

Those edits stay on the CI machine. Do not run the prepare script in a local checkout.

Also set the same value as a workflow environment variable (step 11 below). That is the setting `xcodebuild` applies to every target, including the embedded framework. Leave it unredacted. It is not a secret.

## Test shards

Xcode Cloud runs separate Test actions in parallel. Four shared schemes each point at one test plan:

| Scheme | Test plan | Classes included |
| --- | --- | --- |
| `QuestifyAppUnitTests-Shard01` | `Questify.xcodeproj/xcshareddata/xctestplans/QuestifyAppUnitTests-Shard01.xctestplan` | 202 |
| `QuestifyAppUnitTests-Shard02` | `QuestifyAppUnitTests-Shard02.xctestplan` | 208 |
| `QuestifyAppUnitTests-Shard03` | `QuestifyAppUnitTests-Shard03.xctestplan` | 223 |
| `QuestifyAppUnitTests-Shard04` | `QuestifyAppUnitTests-Shard04.xctestplan` | 217 |

The four plans together include each of the 850 `XCTestCase` classes under `Tests/AppUnitTests` once. A class is omitted from a plan only by that plan's skip list. The full `QuestifyAppUnitTests` scheme has no skip list.

After adding or renaming an app-unit class, run `python3 tools/generate_project.py` and commit the regenerated shard schemes and test plans. CI does not regenerate them.

## Core tests

Core tests are the Swift package target `QuestifyCoreTests` (`Package.swift`, sources in `Tests/CoreTests`). They are not an Xcode test target. `ci_scripts/ci_post_xcodebuild.sh` runs `swift test` only when the action is `build` and the scheme is `Questify`, which is while the source checkout is still present. The shard test actions do not run it again. A later Archive action does not run it either.

## Owner steps

Use team **9VHY8N755R**. The App Store Connect app record uses bundle ID **com.chengyinhub.chengyinApp**.

The committed app identifier is still the placeholder `invalid.example.questify.ios` in `Config/Base.xcconfig` (the unit-test bundle is `invalid.example.questify.ios.appunittests`). This change does not replace that placeholder. If the workflow editor will not attach the product to the `com.chengyinhub.chengyinApp` record, stop and decide the bundle ID in a later change. Do not add a signing certificate to get past that screen.

1. Open [App Store Connect](https://appstoreconnect.apple.com) and sign in as an Account Holder or Admin on team 9VHY8N755R.
2. Click **Users and Access**.
3. Click the **Integrations** tab.
4. Select **Xcode Cloud**. If it is not enabled, click **Get Started** (or **Enable**), accept the Xcode Cloud agreement, and finish the Apple ID prompt.
5. In that Xcode Cloud integrations panel, next to GitHub, click **Connect** or **Grant Access**.
6. GitHub opens the **Xcode Cloud** GitHub App. Sign in as someone who can administer `liboyang42-cpu`.
7. Choose **Only select repositories**.
8. Select **liboyang42-cpu/chengyin-app**. Do not grant all repositories.
9. Click **Install** or **Save**. Return to App Store Connect and confirm that repository is listed as connected.
10. Create the app record if it is not already there:
    1. Open [Identifiers](https://developer.apple.com/account/resources/identifiers/list) for team 9VHY8N755R. If `com.chengyinhub.chengyinApp` is missing, register an explicit App ID with that exact bundle ID. Do not turn on extra capabilities.
    2. In App Store Connect, click **Apps**. If no app uses that bundle ID, click **+**, then **New App**.
    3. Platform: **iOS**. Name: the owner’s product name. Primary language: the owner’s choice. Bundle ID: **com.chengyinhub.chengyinApp**. SKU: `chengyin-app` (any unique string). User Access: **Full Access**.
    4. Click **Create**. Do not upload a build and do not create a certificate or provisioning profile.
11. Open that app, click the **Xcode Cloud** tab, then **Create Workflow** (or **Get Started**, then **Next**). Choose repository `liboyang42-cpu/chengyin-app`, project `Questify.xcodeproj`, and product scheme `Questify`. Name the workflow `rc build and test`.
12. Open **Environment**.
    1. Choose the newest Xcode version in the list. See “Not verified” below before assuming that entry is Xcode 27.
    2. Under environment variables, click **+**. Name: `CODE_SIGNING_ALLOWED`. Value: `NO`.
    3. Leave **Secret** / **Keep value redacted** unchecked. Add no other variable, API key, certificate, or profile.
13. Open **Start Conditions**.
    1. Remove a default condition that starts only on `main`, if one is present.
    2. Click **+** and choose **Branch Changes**.
    3. Set the branch filter to the custom pattern `rc/*` (this matches `rc/20261108`).
    4. Do not add a pull-request, tag, or schedule condition. `cursor/cb9` does not match `rc/*` and will not start this workflow.
14. Open **Actions**.
    1. Add or keep one **Build** action. Platform: **iOS**. Scheme: **Questify**. This is the action whose post-action script runs `swift test` (Core).
    2. For each of `QuestifyAppUnitTests-Shard01`, `QuestifyAppUnitTests-Shard02`, `QuestifyAppUnitTests-Shard03`, and `QuestifyAppUnitTests-Shard04`: click **+**, choose **Test**, platform **iOS**, that scheme, tests **Use Scheme Settings**, requirement **Required to Pass**. Click **+** under destinations and add one current iPhone simulator. Do not add a second destination.
    3. Do not add **Archive**, **Analyze**, or a TestFlight action. Archive stays a later workflow.
15. Click **Save**.
16. On a branch that matches `rc/*`, open the workflow and click **Start Build** to run it once. Each Test action compiles the app on its own machine, so four shards plus the build action add their compute time together even though they run at the same time.

## Not verified

- **Current free compute hours** for team 9VHY8N755R. The remaining Xcode Cloud balance is on the Apple account. This change does not sign in, so that number was not read.
- **Whether an Xcode 27 environment is available in Xcode Cloud.** The workflow environment list for this team was not opened. The public [Xcode Cloud release notes](https://developer.apple.com/xcode-cloud/release-notes/), as read on November 8, 2026 (Pacific time), show Xcode 26.2 added on December 19, 2025, and do not list an Xcode 27 image. That page is not the team’s environment picker. If Xcode 27 is absent from the picker, keep the newest version that is listed.

## GitHub-hosted runners

[GitHub-hosted runners](https://docs.github.com/en/actions/reference/runners/github-hosted-runners) lists a standard macOS label `xcode-27` (3-core Apple silicon, 7 GB RAM) for public and private repositories. The image readme [xcode-27-arm64-Readme.md](https://github.com/actions/runner-images/blob/main/images/macos/xcode-27-arm64-Readme.md), image version `20261104.0337.1`, includes Xcode 27.1 (default) and the iOS 27.0 simulator SDK, with an iPhone 18 Pro simulator on iOS 27.0. No GitHub-hosted macOS workflow was added. Existing workflows were not edited. Xcode Cloud remains the primary path; private macOS minutes are a paid fallback, not a second workflow in this change.
