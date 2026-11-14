# ui/cur-permissions

Base: `origin/ui/main` `6feee423adc8962d7613f8ba93b77ffdc93ea1c4`.

Mini-program source: public `liboyang42-cpu/hengyin` `master` `73f4f7be45aa5b49381baa2c1aff57e1b2245fad` (`fix: 平台自玩路线走查第四轮`). Read over HTTPS. No SSH.

The explanation screen is the existing `CYPermissionPrimer` / `CYPermissionSystemPrompt.precede` (`App/DesignSystem/CYPermissionPrimer.swift`). Photos was added to that kind. No second permission stack. A missing window returns false from the primer window, so the system prompt does not run when the explanation cannot be shown. XCTest still skips the screen and keeps the existing request. English and zh-Hans.

Settings URLs already in this app: `UIApplication.openSettingsURLString` for location, camera, and Photos; `UIApplication.openNotificationSettingsURLString` for notifications (same call `NativeNotificationPermissionAdapter.openSettingsFromUserAction` already makes).

## Location

Mini-program explanation exists, and it is play-scoped.

- Pre-prompt: `chengyinhub-xcx/pages/play/index.js` `requestPlayLocation` shows a modal before `wx.getLocation`. Title `开启定位`. Body `仅在开局时检查你是否在起点约 300 米内，之后各站不再要求定位。位置只在本游玩页前台使用，锁屏、切到后台、暂停、结束或离开后停止。` Confirm `开启定位`. Cancel `先用扫码`.
- `chengyinhub-xcx/app.json` `permission.scope.userLocation.desc`: `用于确定首页城市、到点打卡判定与漫游足迹记录`.
- Denied: `chengyinhub-xcx/pages/play/utils/play-location-once.js` `GUIDE` (`打开定位` / `点右上角「···」→「设置」→「位置信息」，选「仅在使用小程序期间」。` / `去设置`) then `wx.openSetting`. `chengyinhub-xcx/utils/location/location-manager.js` `showPermissionGuide` (`需要位置权限` / `请在小程序设置中开启位置权限，以便继续使用位置功能` / `去设置`) then `wx.openSetting`.

The 300-meter sentence and the WeChat capsule path were not copied onto the global card. They describe one play session and a WeChat settings path this app does not have. The card body is the installed `NSLocationWhenInUseUsageDescription` in `Resources/InfoPlist.xcstrings` (English and zh-Hans).

Explanation is shown first. `precede(.location)` runs before `requestWhenInUseAuthorization` in `RuntimeNativeLocationProvider`, `PlayNativeDeviceProvider`, `PlayKitNativeSensorProvider`, and `PersonalLocationShareHost`. Roam GO shows `CYPermissionPrimerScreen(kind: .location)` and only then marks the kind primed.

Denied opens `UIApplication.openSettingsURLString` from `RoamLiveSessionView` (`roam.live.openSettings`), `NearbyMerchantView` (`nearbyMerchant.openSettings`), `RoamPOIActions`, `RoamLocationSettingsDestination`, `PlayLocationCaptureIssueView` (`playRecovery.location.settings`), and `CYPermissionPrimer.openSettings`.

## Camera

No mini-program explanation screen before the camera starts. `chengyinhub-xcx/components/cy/proto-cam/index.js` opens the camera when `scope.camera` is not false. If it is false, the line is `相机没授权，去设置里打开`. `chengyinhub-xcx/subpackageP3/pages/stamp-camera/index/index.js` `openSetting` calls `wx.openSetting` after `相机没能启动`.

Explanation is shown first. The card body is the installed `NSCameraUsageDescription`. `precede(.camera)` runs before `AVCaptureDevice.requestAccess` in stamp capture, the QR scanner, play photo/scan, the play-kit camera overlay, and spatial reveal. Not now does not request access.

Denied opens `UIApplication.openSettingsURLString` from `RoamStampCameraView` (`media.stamp.openSettings`), `NativeQRScanner` (`scanner.openSettings`), `PlayKitCameraOverlayButton` (`playkit.camera.openSettings`, label `scanner.openSettings`), and `PlayKitSpatialRevealButton` (`playkit.spatial.openSettings`, same label) when the status is denied or restricted.

## Notifications

No mini-program explanation before an OS notification prompt. `chengyinhub-xcx/utils/subscribe.js` calls `wx.requestSubscribeMessage` directly. `chengyinhub-xcx/pages/club/notify/index.js` is a role check, not a system notification prompt. There is no Info.plist usage string for notifications. The existing primer sentences in `CYPermissionPrimer` stay.

Explanation is shown first. `precede(.notification)` runs in `NativeNotificationPermissionAdapter.requestFromUserAction` and `AppleLocalReminderProvider.requestPermission` before `requestAuthorization`. `IMInviteReminderController.setEnabled(true)` calls `IMInviteReminderSystemPrimer` before `IMInviteReminderSystemPermission.request` when the status is not determined. A declined or unpresentable primer does not request.

Denied opens `UIApplication.openNotificationSettingsURLString` from `NativeNotificationPermissionAdapter.openSettingsFromUserAction` (nudge button `d7.notifyPermission.settings`) and from `IMInviteReminderToggle` when `offersSettings` is set (denied, or alerts off). A declined primer does not offer Settings.

## Photos

No mini-program explanation before the first save. `saveImageToPhotosAlbum` is called directly. On denial, `chengyinhub-xcx/components/cy/share-card/index.js` shows title `需要相册权限`, body `在设置里允许保存到相册后重试。`, confirm `去设置`, then `wx.openSetting`. `chengyinhub-xcx/pages/play/index.js` `saveFinishCard` calls `wx.openSetting` on an auth failure and does not show that modal.

Explanation is shown first. `RoamSharePhotoLibraryWriter.requestAuthorization` calls `precede(.photos)` before `PHPhotoLibrary.requestAuthorization(for: .addOnly)`. Not now returns `.notDetermined` and does not ask Photos. The card body is the installed `NSPhotoLibraryAddUsageDescription`. The denied card body is `roam.share.photoPermissionDenied`.

Denied opens `UIApplication.openSettingsURLString` from `RoamHistoryShareView` (`roam.share.openPhotoSettings`), `RoamMedalShareView` (`roam.medalShare.openPhotoSettings`), and `RoamStampSlipSaveRow` (`roam.share.openPhotoSettings`). `CYPermissionPrimer.openSettings` uses the same URL.

## Checks

`python3 tools/check_scaffold.py` PASS. `python3 tools/check_design_lint.py` PASS. Related contract tests `test_roam_share_photo_save`, `test_playkit_camera_presentation`, `test_playkit_spatial_rendering`, `test_im_coop_invite_strip_wiring`, and `test_playkit_glb_security` passed. Swift was not compiled. Tests that need `swiftc` were not run.
