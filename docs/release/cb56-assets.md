# CB56 assets

The owner supplies the art. This file is a completeness checklist. It does not add an app icon, a launch image, or any other marketing bitmap. `PRODUCT_BUNDLE_IDENTIFIER` stays `invalid.example.questify.ios`. `MARKETING_VERSION` stays `0.1.0` and `CURRENT_PROJECT_VERSION` stays `1`.

Checked from source on `origin/rc/20261108` at `88e981b3308558939e405606cd731b4b29fc9499` (2026-11-09 12:34 AM PT). No `xcodebuild` and no `actool` run is recorded here. Store listing copy, screenshots, and the privacy manifest stay in `docs/release/app-store-metadata-checklist.md`.

## Left unchanged

- [x] Marketing version `0.1.0` and build `1` in `Config/Base.xcconfig`.
- [x] Bundle id `invalid.example.questify.ios` in `Config/Base.xcconfig`. Test ids stay `invalid.example.questify.ios.appunittests` and `invalid.example.questify.ios.uitests`.
- [x] Display name `INFOPLIST_KEY_CFBundleDisplayName = Questify`.
- [x] `TARGETED_DEVICE_FAMILY = 1,2` and `IPHONEOS_DEPLOYMENT_TARGET = 17.0`. The icon set has to cover iPhone and iPad. It does not need a macOS, watchOS, or visionOS idiom.
- [x] `Resources/SettingsBrandMark.png` is still the only committed raster outside `docs/release/`. It was not replaced or upscaled.

## Already in the tree

- [x] Settings mark, not an app icon. `Resources/SettingsBrandMark.png` is 128×128, 8-bit RGBA, 4360 bytes, sha256 `76382e6289eb12acf7579c3f608c80ac36dd9a8727add7adf246cc40f59b4023`. 10269 of 16384 pixels are fully transparent. The opaque pixels are mostly `#7A5CFF`, and the image is not full-bleed. `App/SettingsAboutView.swift` draws it with `Image("SettingsBrandMark")` at 54×54 pt and hides it from accessibility. `tools/generate_project.py` copies that one PNG into the Questify resources phase (`Resources/SettingsBrandMark.png` in `Questify.xcodeproj/project.pbxproj`).
- [x] Generated launch screen only. `Config/Base.xcconfig` sets `INFOPLIST_KEY_UILaunchScreen_Generation = YES`. There is no `LaunchScreen.storyboard`, no `UILaunchStoryboardName`, and no `INFOPLIST_KEY_UILaunchScreen_UIColorName` or `INFOPLIST_KEY_UILaunchScreen_UIImageName`. `Config/Info.plist` has no `UILaunchScreen` dictionary (`UINavigationBar`, `UITabBar`, and `UIToolbar` are absent).
- [x] The first screen after launch is `UsageConsentGateView` (`authEntry.gate.*`). It calls `.themeDomain(.player)`, which forces dark, and paints `CYColor.bgPage`. In dark that page color is `#000000` (`App/DesignSystem/CYDesignTokens.swift`). The generated launch screen does not name that color, so it follows the system background. `docs/release/smoke-flows.md` already skips the launch screen because it has no accessibility identifier.
- [x] No asset catalog. A search of the tree finds no `.xcassets`, `.appiconset`, `.imageset`, `.colorset`, or `.storyboard`, including under `Vendor/GLTFKit2`.
- [x] No app-icon build setting. Questify Debug (`6C7EFF6369083C8E1F2B1994`) and Release (`DD75E2CB1C510A828AC72D96`) inherit `Config/Base.xcconfig` and do not set `ASSETCATALOG_COMPILER_APPICON_NAME`. `Config/Base.xcconfig` does not set it either. There is no `CFBundleIcons` or `CFBundleAlternateIcons` entry, and no `setAlternateIconName` call.
- [x] The project generator will not pick up a catalog by itself. `tools/generate_project.py` resources are `Resources/*.xcstrings`, `Resources/*Notices.txt`, `Resources/PrivacyInfo.xcprivacy`, and `Resources/SettingsBrandMark.png`.
- [x] No `AccentColor` color set. SwiftUI `Color.accentColor` is the system accent. Content color lives in `CYColor` and `Theme.Generated`, not in a catalog.
- [x] `Vendor/GLTFKit2` sets `ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS` and ships no catalog. That flag is not the Questify icon.

## Gaps

### App icon

- [ ] Owner supplies a 1024×1024 px PNG, sRGB, no alpha channel, square, no pre-rounded corners, and no text baked into the pixels. One file fills the iOS universal slot that Xcode 14 and later uses for iPhone and iPad on this deployment target.
- [ ] That file lives in an `AppIcon` app-icon set inside an asset catalog the Questify target compiles. `Contents.json` names `platform` `ios`, `idiom` `universal`, and `size` `1024x1024`. Every `filename` in that file exists. Do not leave a slot that points at a missing file.
- [ ] `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon` is set for the Questify target, through `Config/Base.xcconfig` or the generated project, after the set exists.
- [ ] `tools/generate_project.py` includes the catalog, and `Questify.xcodeproj` is regenerated from it. A catalog that is only on disk is not in the app.
- [ ] App Store Connect uses that same 1024×1024 image. `Resources/SettingsBrandMark.png` is the wrong file: it is 128×128 and has an alpha channel.
- [ ] No second hand-drawn size grid (20 pt, 29 pt, 40 pt, 60 pt, 76 pt, 83.5 pt) unless the owner rejects the single 1024 slot. The single slot is the complete required set for this target.

### App icon, optional

- [ ] iOS 18 dark appearance: a second 1024×1024 in the same `AppIcon` set, appearance `luminosity` / `dark`.
- [ ] iOS 18 tinted appearance: a third 1024×1024, appearance `luminosity` / `tinted`.
- [ ] Alternate icons, only if the product asks for them. None are declared today.
- [ ] An `AccentColor` color set, only if the system accent should stop being the default. Do not move `CYColor` into the catalog for this.

### Launch screen

- [ ] The launch screen matches the consent gate, which is a dark page (`#000000`), not a logo splash. A centered marketing image is the wrong asset. The settings mark is the wrong asset.
- [ ] If the blank system background is not acceptable, the owner supplies a catalog color that is `#000000` in every appearance and the build sets `INFOPLIST_KEY_UILaunchScreen_UIColorName` to that color. A SwiftUI `CYColor` is not available to the launch screen. A light/dark pair that follows the system still flashes on a Light Mode device, because the player domain forces dark after launch.
- [ ] A launch image is added only when a static first frame needs pixels the color cannot provide. It is a catalog image, referenced by `INFOPLIST_KEY_UILaunchScreen_UIImageName`, with `INFOPLIST_KEY_UILaunchScreen_UIImageRespectsSafeAreaInsets` set when the image must stay inside the safe area. The image has no text.
- [ ] `UINavigationBar`, `UITabBar`, and `UIToolbar` stay out of the launch screen. The consent gate hides the navigation bar.
- [ ] `INFOPLIST_KEY_UILaunchScreen_Generation` stays `YES` unless a storyboard is an explicit later decision. There is no storyboard to adopt now.
- [ ] Maestro still does not assert the launch screen. Do not add an accessibility identifier to it for the smoke flow.

### Asset catalog

- [ ] One catalog is committed and is a member of the Questify resources phase.
- [ ] The catalog contains the `AppIcon` set above, the launch color if one is supplied, and the launch image if one is supplied.
- [ ] No empty image set, color set, or icon slot. No unreferenced marketing image.
- [ ] `SettingsBrandMark` may stay the loose PNG. Moving it into an image set is optional and does not make it the app icon. Do not upscale it to 1024.
- [ ] `Resources/` still has exactly one product PNG until the owner’s icon files land. The PNGs under `docs/release/design-report-*-shots/` are review shots, not catalog images.

## Owner handoff

Drop the art, then change the build. This branch does not do that step.

| Need | File the owner supplies | Build change after the file exists |
|---|---|---|
| Home screen and App Store icon | 1024×1024 PNG, no alpha | `AppIcon` set, `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon`, catalog added in `tools/generate_project.py` |
| Dark and tinted icons | Two more 1024×1024 PNGs, optional | Same `AppIcon` set, extra appearance entries |
| Launch background | Catalog color `#000000` for every appearance, only if the system background is rejected | `INFOPLIST_KEY_UILaunchScreen_UIColorName` |
| Launch image | Catalog image with no text, only if a color is not enough | `INFOPLIST_KEY_UILaunchScreen_UIImageName` |

Version stays `0.1.0` (`1`). Bundle id stays `invalid.example.questify.ios`.
