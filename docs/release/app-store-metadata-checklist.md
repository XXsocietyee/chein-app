# App Store metadata checklist

Not submitted. Not signed. The owner fills App Store Connect and submits. This file does not contain a signing identity, a privacy-policy URL, or store listing copy.

Checked against `origin/rc/20261108` at `a6871477c497c6440ce06417035572d7278ea830` (2026-11-08 PT). `RegionalLaunchConfiguration.composition` calls `shippedComposition(build: .current)`. An empty URL or realm still uses `makeComposition(reviewed: nil, build: .current)`. The default build does not call the China host.

## Already in the tree

- [x] Privacy manifest `Resources/PrivacyInfo.xcprivacy`. Tracking off. Collected types are linked, not used for tracking, purpose App Functionality: Phone Number, User ID, Precise Location, Photos or Videos, Audio Data, Other User Content, Name, Email Address, Physical Address, Purchase History, Fitness, Device ID. Required-reason APIs: UserDefaults `CA92.1`, File Timestamp `C617.1` and `3B52.1`, System Boot Time `35F9.1`. Nutrition-label answers are drafted in `docs/release/cb55-privacy.md` and are not submitted.
- [x] Vendored `Vendor/GLTFKit2/GLTFKit2/PrivacyInfo.xcprivacy`. Tracking off. Collected-data and accessed-API arrays are empty.
- [x] Usage strings in English and zh-Hans. `NSCameraUsageDescription`, `NSMotionUsageDescription`, `NSLocationWhenInUseUsageDescription`, and `NSMicrophoneUsageDescription` are `INFOPLIST_KEY_*` values in `Config/Base.xcconfig` (English) and both locales in `Resources/InfoPlist.xcstrings`. `NSPhotoLibraryAddUsageDescription` is the English string in `Config/Info.plist` and both locales in the same catalog. `NSPhotoLibraryUsageDescription` stays out of `Config/Info.plist`.
- [x] ATS has no exception. `Config/Info.plist` and the xcconfig files have no `NSAppTransportSecurity`, `NSAllowsArbitraryLoads`, `NSAllowsLocalNetworking`, or `NSExceptionDomains`.
- [x] No always-location strings and no `UIBackgroundModes` in `Config/Base.xcconfig`, `Config/Info.plist`, `Resources/InfoPlist.xcstrings`, or `Resources/PrivacyInfo.xcprivacy`.
- [x] Sign in with Apple entitlement, because the app target already has the capability slot (`CODE_SIGN_ENTITLEMENTS` on Questify Debug and Release). The file is `com.apple.developer.applesignin` = `[Default]` only. No entitlement was added for a missing slot.
- [x] Account-deletion path check: `python3 -B tools/check_account_deletion_path.py`. It does not delete an account. The unconfigured composition shows the blocked 账号注销 / Account cancellation row.
- [x] Unsigned archive script: `python3 -B tools/archive_unsigned.py`. It does not sign or upload. `--archive` is opt-in and still forces `CODE_SIGNING_ALLOWED=NO`.
- [x] Display name: `INFOPLIST_KEY_CFBundleDisplayName = Chein`, localized in `Resources/InfoPlist.xcstrings` (en Chein, zh-Hans 城瘾; owner 2026-11-27). Marketing version `0.1.0`, build `1`, in `Config/Base.xcconfig`. The owner confirms what App Store Connect shows.
- [x] Shipped composition calls `shippedComposition(build: .current)`. An empty URL or realm still uses `makeComposition(reviewed: nil, build: .current)`. China `https://www.chengyinhub.com/prod-api/` with realm `cn-prod` is admitted only for market China when the bundle and realm form a storage scope.

## Owner fills before submission

- [ ] Bundle id. The committed id is `invalid.example.questify.ios`. `com.chengyinhub.chengyinApp` is not in the tree.
- [ ] Team. No committed xcconfig sets `DEVELOPMENT_TEAM`. `9VHY8N755R` is not in the tree. Put the team in gitignored `Config/Local.xcconfig` on the signing machine.
- [ ] Enable Sign in with Apple on the App ID. The entitlement file does not flip that portal switch.
- [ ] Distribution certificate and provisioning profile. They are not in the tree.
- [ ] Sign the archive and upload it. `tools/archive_unsigned.py --archive` produces `.build/unsigned-archive/Questify.xcarchive` only.
- [ ] App privacy nutrition labels in App Store Connect, matching the manifest above. Tracking stays off. This checklist does not submit the labels.
- [ ] Privacy policy URL, support URL, and marketing URL. None is committed here. `https://www.chengyinhub.com/prod-api/` in `Config/China.Production.xcconfig` is an API build input. It is not a privacy policy URL, and it does not approve the shipped composition.
- [ ] Store listing for en-US and zh-Hans: name, subtitle, description, keywords, promotional text, and what's new. This repo does not hold that copy.
- [ ] Screenshots: 6.9-inch and 6.5-inch iPhone, zh-Hans and en-US. They are not in this repo.
- [ ] Age rating questionnaire.
- [ ] Export compliance. `ITSAppUsesNonExemptEncryption` is unset (`docs/parity/fix-plan.md` FP-M2). This checklist does not set it.
- [ ] Account deletion answer for App Review. The in-app row is the blocked explanation and the cancellation notice. It does not call apply. Whether that is enough to ship is an owner decision.
- [ ] Pricing, availability, and content rights.
- [ ] Do not submit from this branch.

## Commands

```bash
python3 -B tools/check_account_deletion_path.py
python3 -B tools/archive_unsigned.py
```

The second command stops after the preflight. It does not run `xcodebuild`. Pass `--archive` only on a Mac when an unsigned archive is wanted. Do not add a team, a signing identity, a profile, or an upload flag.
