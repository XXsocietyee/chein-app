# App Privacy answers

Not filed in App Store Connect. Not a privacy-policy URL. Tracking is none.

Source of the manifest: `Resources/PrivacyInfo.xcprivacy`. This pass grepped `App/` and `Core/` and did not add or remove a row. `NSPrivacyTracking` is false. `NSPrivacyTrackingDomains` is empty. Every declared type is linked to the person, is not used for tracking, and lists App Functionality as its only purpose.

The China market in `Config/Base.xcconfig` is `CN`. Background location on `ui/wp-11` is the same Precise Location row. 后台位置在 `ui/wp-11` 上与精确位置是同一行。This branch does not call that tracker. 本分支不调用那个追踪器。

## English

### Tracking

| Question | Answer |
|---|---|
| Do you or your third-party partners use data from this app to track users? | No |
| Tracking domains | None |
| App Tracking Transparency | Not used. No `ATTrackingManager`, `ASIdentifierManager`, `AdSupport`, or `NSUserTrackingUsageDescription` in `App/` or `Core/`. |

### Collected data types

| Apple type | Collected | Linked | Tracking | Purpose | Evidence |
|---|---|---|---|---|---|
| Contact Info > Phone Number | Yes | Yes | No | App Functionality | `Core/AuthChannelService.swift` sends a phone number for the SMS code and phone sign-in. |
| Contact Info > Name | Yes | Yes | No | App Functionality | `Core/RegistrationContracts.swift` writes `realName`. |
| Contact Info > Email Address | Yes | Yes | No | App Functionality | `Core/RegistrationContracts.swift` can encode `email`. The current form may omit it. The manifest keeps the type. |
| Contact Info > Physical Address | Yes | Yes | No | App Functionality | `Core/ParticipantForm.swift` carries `detailAddress`. |
| Contact Info > Contacts | No | — | No | — | No `import Contacts`, `CNContact`, or address-book read in `App/` or `Core/`. Not declared. |
| Location > Precise Location | Yes | Yes | No | App Functionality | When-in-use location. `NSLocationWhenInUseUsageDescription` is set. `App/PersonalLocationShareHost.swift` sets `allowsBackgroundLocationUpdates = false` and requests when-in-use authorization. |
| Location > Coarse Location | No | — | No | — | No separate coarse fix is sent. Not declared. |
| Location, background | Same Precise Location row | Yes | No | App Functionality | `ui/wp-11` `1e48434` `App/SessionBackgroundLocationTracker.swift` sets `allowsBackgroundLocationUpdates = true` and `showsBackgroundLocationIndicator = true` only while a roam hold is active and the location background mode is present. Authorization stays when-in-use. It does not call `requestAlwaysAuthorization`. Play holds stay foreground-only. That file is not in `origin/ui/main` `9209d33`, so this branch's binary does not call it. Apple's manifest has no separate background-location type. The declared type stays Precise Location. No required-reason API was added. |
| User Content > Photos or Videos | Yes | Yes | No | App Functionality | Image uploads, including `api/common/uploadOSS`. Picks use `PHPickerViewController`. Saving a card uses `PHPhotoLibrary` add-only in `App/RoamSharePhotoSaveModel.swift`. |
| User Content > Audio Data | Yes | Yes | No | App Functionality | `NSMicrophoneUsageDescription`. IM voice and NPC voice can upload after confirmation. A sound-peak play path measures amplitude on device. |
| User Content > Other User Content | Yes | Yes | No | App Functionality | Club and IM messages, including `api/im/message/edit`. |
| Health & Fitness > Fitness | Yes | Yes | No | App Functionality | `App/IPhonePedometerProvider.swift` reads `CMPedometer`. It is not HealthKit. |
| Health & Fitness > Health | No | — | No | — | No `HealthKit` or `HKHealthStore`. Not declared. |
| Identifiers > User ID | Yes | Yes | No | App Functionality | Account `id` / `userId` from the service. Requests carry the session token. |
| Identifiers > Device ID | Yes | Yes | No | App Functionality | `App/AppAttestStepAssertionProvider.swift` calls `generateAssertion`. This is not the advertising identifier. |
| Purchases > Purchase History | Yes | Yes | No | App Functionality | Registration pay parameters name `api/registration/pay/app` in `Core/OrderLifecycleDormantAdapter.swift`. This build does not complete a StoreKit purchase. |
| Purchases > Payment Info | No | — | No | — | No card number is collected. This pass does not add a card charge. Not declared. |
| Diagnostics > Crash Data, Performance Data, Other Diagnostic Data | No | — | No | — | No crash or metric SDK. Not declared. |
| Advertising Data | No | — | No | — | No ad SDK. Not declared. |

### Required-reason APIs

Declared, because the code uses them:

| Category | Reason | Why this reason |
|---|---|---|
| User Defaults | `CA92.1` | App-scoped `UserDefaults` and `@AppStorage`. `UserDefaults(suiteName:)` under `App/` is a fixture suite, not an app group. |
| File Timestamp | `C617.1` | Timestamps of files the app owns in its container or temporary directory. Examples: `App/IMVoiceDevice.swift`, `App/MerchantNPCVoiceDevice.swift` (`contentModificationDateKey`), `Core/ParticipantFileJournal.swift`, `Core/ContentDraftSystemStorage.swift`. |
| File Timestamp | `3B52.1` | Timestamps of a file the person selected. `fstat` / `st_mtimespec` after a security-scoped read in `App/TemplateAudioDocumentPickerAdapter.swift`, `App/ProjectStoryAudioSelectedDocumentReader.swift`, and `Core/QmodArchiveInspection.swift`. |
| System Boot Time | `35F9.1` | `ProcessInfo.processInfo.systemUptime` measures elapsed time inside the app (`Core/WalkingNavigationContracts.swift`, `Core/OrderPaymentVerifier.swift`, `Core/PersonalLocationShareCoordinator.swift`). |

Left out, because the code does not use them:

| Category | Reason codes not declared |
|---|---|
| Disk Space | `85F4.1`, `E174.1`, `7D9E.1`, `B728.1`. No `volumeAvailableCapacity`, `systemFreeSize`, `NSFileSystemFreeSize`, `statfs`, or `statvfs` in `App/` or `Core/`. |
| Active Keyboards | `3EC4.1`, `54BD.1`. No `activeInputModes` or `UITextInputMode` in `App/` or `Core/`. |
| User Defaults, other reasons | `1C8F.1`, `C56D.1`, `AC6B.1`. No app-group entitlement. |
| File Timestamp, other reasons | `DDA9.1`, `0A2A.1`. |
| System Boot Time, other reasons | `8FFB.1`, `3D61.1`. No `mach_absolute_time` and no boot time inside a bug report. |

`Vendor/GLTFKit2/GLTFKit2/PrivacyInfo.xcprivacy` stays tracking-off with empty collected-data and accessed-API arrays. This note does not edit it.

## 简体中文

### 追踪

| 问题 | 回答 |
|---|---|
| 你或第三方是否使用本 App 的数据追踪用户？ | 否 |
| 追踪域名 | 无 |
| App Tracking Transparency | 未使用。`App/` 与 `Core/` 中没有 `ATTrackingManager`、`ASIdentifierManager`、`AdSupport` 或 `NSUserTrackingUsageDescription`。 |

### 收集的数据类型

| Apple 类型 | 是否收集 | 是否关联 | 是否追踪 | 用途 | 依据 |
|---|---|---|---|---|---|
| 联系信息 > 电话号码 | 是 | 是 | 否 | App 功能 | `Core/AuthChannelService.swift` 用手机号发送短信验证码并完成手机号登录。 |
| 联系信息 > 姓名 | 是 | 是 | 否 | App 功能 | `Core/RegistrationContracts.swift` 写入 `realName`。 |
| 联系信息 > 电子邮件 | 是 | 是 | 否 | App 功能 | `Core/RegistrationContracts.swift` 可以编码 `email`。当前表单可能不传。清单仍保留该类型。 |
| 联系信息 > 物理地址 | 是 | 是 | 否 | App 功能 | `Core/ParticipantForm.swift` 带有 `detailAddress`。 |
| 联系信息 > 通讯录 | 否 | — | 否 | — | `App/` 与 `Core/` 没有 `import Contacts`、`CNContact` 或通讯录读取。不声明。 |
| 位置 > 精确位置 | 是 | 是 | 否 | App 功能 | 仅在使用期间。已设置 `NSLocationWhenInUseUsageDescription`。`App/PersonalLocationShareHost.swift` 将 `allowsBackgroundLocationUpdates` 设为 false，并只请求使用期间授权。 |
| 位置 > 粗略位置 | 否 | — | 否 | — | 没有单独发送的粗略定位。不声明。 |
| 位置，后台 | 与精确位置同一行 | 是 | 否 | App 功能 | `ui/wp-11` `1e48434` 的 `App/SessionBackgroundLocationTracker.swift` 只在漫游占用存在且已声明定位后台模式时，把 `allowsBackgroundLocationUpdates` 和 `showsBackgroundLocationIndicator` 设为 true。授权仍是使用期间。它不调用 `requestAlwaysAuthorization`。游玩占用保持仅前台。该文件不在 `origin/ui/main` `9209d33`，所以本分支的二进制不会调用它。Apple 的清单没有单独的后台位置类型。声明的类型仍是精确位置。没有新增需说明原因的 API。 |
| 用户内容 > 照片或视频 | 是 | 是 | 否 | App 功能 | 图片上传，包括 `api/common/uploadOSS`。选取使用 `PHPickerViewController`。保存卡片时，`App/RoamSharePhotoSaveModel.swift` 以仅添加方式调用 `PHPhotoLibrary`。 |
| 用户内容 > 音频数据 | 是 | 是 | 否 | App 功能 | 已设置 `NSMicrophoneUsageDescription`。即时消息语音和 NPC 语音可在确认后上传。声音峰值玩法在设备上测量振幅。 |
| 用户内容 > 其他用户内容 | 是 | 是 | 否 | App 功能 | 俱乐部与即时消息，包括 `api/im/message/edit`。 |
| 健康与健身 > 健身 | 是 | 是 | 否 | App 功能 | `App/IPhonePedometerProvider.swift` 读取 `CMPedometer`。不是 HealthKit。 |
| 健康与健身 > 健康 | 否 | — | 否 | — | 没有 `HealthKit` 或 `HKHealthStore`。不声明。 |
| 标识符 > 用户 ID | 是 | 是 | 否 | App 功能 | 服务端返回的账户 `id` / `userId`。请求携带会话令牌。 |
| 标识符 > 设备 ID | 是 | 是 | 否 | App 功能 | `App/AppAttestStepAssertionProvider.swift` 调用 `generateAssertion`。这不是广告标识符。 |
| 购买 > 购买历史 | 是 | 是 | 否 | App 功能 | `Core/OrderLifecycleDormantAdapter.swift` 的报名支付参数写有 `api/registration/pay/app`。此构建不完成 StoreKit 购买。 |
| 购买 > 付款信息 | 否 | — | 否 | — | 不收集卡号。本文件不增加银行卡扣款。不声明。 |
| 诊断 > 崩溃数据、性能数据、其他诊断数据 | 否 | — | 否 | — | 没有崩溃或指标 SDK。不声明。 |
| 广告数据 | 否 | — | 否 | — | 没有广告 SDK。不声明。 |

### 需说明原因的 API

已声明，因为代码使用了它们：

| 类别 | 原因码 | 原因 |
|---|---|---|
| User Defaults | `CA92.1` | 应用范围内的 `UserDefaults` 与 `@AppStorage`。`App/` 下的 `UserDefaults(suiteName:)` 是夹具套件，不是 App Group。 |
| 文件时间戳 | `C617.1` | 应用在容器或临时目录中自有文件的时间戳。例如 `App/IMVoiceDevice.swift`、`App/MerchantNPCVoiceDevice.swift`（`contentModificationDateKey`）、`Core/ParticipantFileJournal.swift`、`Core/ContentDraftSystemStorage.swift`。 |
| 文件时间戳 | `3B52.1` | 用户所选文件的时间戳。在安全范围读取之后，`App/TemplateAudioDocumentPickerAdapter.swift`、`App/ProjectStoryAudioSelectedDocumentReader.swift` 和 `Core/QmodArchiveInspection.swift` 使用 `fstat` / `st_mtimespec`。 |
| 系统启动时间 | `35F9.1` | `ProcessInfo.processInfo.systemUptime` 测量应用内经过的时间（`Core/WalkingNavigationContracts.swift`、`Core/OrderPaymentVerifier.swift`、`Core/PersonalLocationShareCoordinator.swift`）。 |

未声明，因为代码没有使用：

| 类别 | 未声明的原因码 |
|---|---|
| 磁盘空间 | `85F4.1`、`E174.1`、`7D9E.1`、`B728.1`。`App/` 与 `Core/` 中没有 `volumeAvailableCapacity`、`systemFreeSize`、`NSFileSystemFreeSize`、`statfs` 或 `statvfs`。 |
| 活跃键盘 | `3EC4.1`、`54BD.1`。`App/` 与 `Core/` 中没有 `activeInputModes` 或 `UITextInputMode`。 |
| User Defaults 的其他原因 | `1C8F.1`、`C56D.1`、`AC6B.1`。没有 App Group 授权。 |
| 文件时间戳的其他原因 | `DDA9.1`、`0A2A.1`。 |
| 系统启动时间的其他原因 | `8FFB.1`、`3D61.1`。没有 `mach_absolute_time`，错误报告中也不含启动时间。 |

`Vendor/GLTFKit2/GLTFKit2/PrivacyInfo.xcprivacy` 仍关闭追踪，收集数据与访问 API 数组均为空。本说明不修改该文件。

## Lane T addendum (2026-11-26) · 补充

`Resources/PrivacyInfo.xcprivacy` now declares four more collected types, each linked, not tracking, App Functionality only. Evidence is pinned in `Tests/ContractChecks/test_privacy_manifest_contract.py`. The tables above predate these rows; use this list in App Store Connect.

| Apple type | Evidence |
|---|---|
| Search History / 搜索历史 | Search terms go to `api/search/unified` (`Core/MPGap/PlayerContent/PlayerContentRound2Service.swift`), `api/im/search`, `api/map/place-search` with the session. |
| Gameplay Content / 游戏内容 | Play runs and endings saved to `api/play/run-session/save` (`Core/PlayRuntimeGap.swift`) and `api/play/ending`. |
| Customer Support / 客户支持 | Play feedback `/api/play/feedback/submit` (`Core/JourneyLoopSource.swift`) and profile complaints. |
| Other Data Types / 其他数据类型 | Resident ID number (`idCard`) for China real-name publisher registration (`Core/PublisherIdentityRegistration.swift`). |

Required-reason APIs are unchanged and re-verified against source: User Defaults `CA92.1`; File Timestamp `C617.1` (own container: `App/IMVoiceDevice.swift`, `App/MerchantNPCVoiceDevice.swift`, the `Core/*Journal.swift` `attributesOfItem` checks) and `3B52.1` (user-picked documents); System Boot Time `35F9.1` (`ProcessInfo.processInfo.systemUptime` for in-app elapsed time). No disk-space or active-keyboard API. The Live Activity extension uses none of these APIs.
