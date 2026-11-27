# App Store pack: Chein 1.0 (player app)

Draft for the first TestFlight / App Store submission. Not submitted, not signed, not uploaded. Docs and config only. The owner approves every field before it goes into App Store Connect.

Voice follows `ux-strategy.md` §4.6: second person, present tense, verbs first, no "please", no "sorry", no "successfully", no exclamation marks, unknown shown as "—". Glossary: 章 stamp, 格 tile, 徽章 badge, 漫游 roam, 俱乐部 club, 护照 passport.

`OWNER-TO-PROVIDE` marks a value this repo does not hold. Nothing marked that way is invented here: no legal text, no ICP number, no URLs, no demo credentials.

Version in the tree: `MARKETING_VERSION = 0.1.0`, build `1` (`Config/Base.xcconfig`). The listing says 1.0; the owner bumps the version (`tools/bump_version.py`) before archiving. This pack does not change it.

## 1. Store fields

Limits: name 30, subtitle 30, promotional text 170, description 4000, keywords 100, what's new 4000.

### Name

| Locale | Value |
|---|---|
| en-US | Chein |
| zh-Hans | 城瘾 |

Owner decision 2026-11-27: the English brand is **Chein**; Chinese stays 城瘾. One App Store app (`com.chengyinhub.chengyinApp`) serves China and the US. The home-screen name is localized in `Resources/InfoPlist.xcstrings` (`CFBundleDisplayName`: en Chein, zh-Hans 城瘾); the unlocalized fallback `INFOPLIST_KEY_CFBundleDisplayName` is `Chein`.

### Subtitle

| Locale | Value |
|---|---|
| en-US | Walk the city. Light it up. |
| zh-Hans | 走到哪，亮到哪 |

### Promotional text

en-US:

```text
Turn on location. Walk, and it lights up. Collect stamps, earn badges, and fill your passport one trip at a time.
```

zh-Hans:

```text
打开定位，走到哪，亮到哪。盖章、集徽章，一趟一趟把护照填满。
```

### Description

en-US:

```text
Chein turns your city into a map you light up by walking it.

Hold Go and walk. Every tile you pass lights up. Stop at a place and get a stamp, so you were here and it shows. Finish a walk and see the numbers: distance, tiles, stamps. Collect badges along the way.

Your passport keeps all of it in one place. Your first stamp is waiting.

Explore activities, routes and topics from people nearby. Join a club, follow its channels, and show up. Hold a ticket for an activity and open it at the door. You're in. Have fun.

Location is used only while the app is open and only when you choose it. Chein never tracks you in the background and never shares your location unless you start sharing with someone you pick.

Not ready to sign in? Look around first. Sign in with Apple or your phone number when you want to keep your passport.

Chein is for walking, not for racing. Mind the road, the weather and other people.

Requires iOS 17. Works in English and 简体中文.
```

zh-Hans:

```text
城瘾把整座城市变成一张地图，你走到哪，它亮到哪。

按住「走起」，开始走。经过的每一格都会点亮。到一个地方，盖一枚章，算你来过。走完一趟，看看这一趟：几公里、几格、几枚章。路上还能集徽章。

护照把这一切收在一起。第一枚章在等你。

看附近的人发起的活动、路线和主题。加入俱乐部，逛逛频道，露个面。活动的门票放在票夹里，到场出示就好。已入场，玩得开心。

定位只在应用打开时、由你主动选择后使用。城瘾不会在后台追踪你；只有你主动选择某个人开始共享时，才会把位置分享给对方。

还没想好登录？先逛逛。想留住护照时，再用 Apple 或手机号登录。

城瘾是用来走的，不是用来赛的。留意路况、天气和身边的人。

需要 iOS 17。支持 English 和简体中文。
```

### Keywords

en-US (no spaces, does not repeat name or subtitle words):

```text
walk,map,passport,stamps,badges,tiles,clubs,tickets,explore,local,routes
```

zh-Hans:

```text
漫游,护照,徽章,盖章,城市,俱乐部,地图,门票,探索,路线,散步
```

### What's new (1.0)

en-US:

```text
First release. Hold Go, walk, and light up the city. Collect stamps and badges, keep them in your passport, join clubs, and open your tickets at the door.
```

zh-Hans:

```text
首个版本。按住「走起」，走一走，点亮这座城。盖章、集徽章，收进护照；加入俱乐部；到场出示门票。
```

### Release-claim guard

The description names features by what the voice table and the shipped screens call them (Go, tiles, stamps, badges, passport, clubs, tickets). Before pasting, the owner confirms each is reachable in the archived build. Deliberately not claimed anywhere in the listing: payments, withdrawals, payouts, virtual goods, password sign-in, rewards for steps, merchant tools, a US service.

## 2. URLs and legal

| Field | Value |
|---|---|
| Privacy policy URL | OWNER-TO-PROVIDE |
| Support URL | OWNER-TO-PROVIDE |
| Marketing URL | OWNER-TO-PROVIDE (optional) |
| Support contact (email or phone, for App Review) | OWNER-TO-PROVIDE |
| Terms of use / EULA link | OWNER-TO-PROVIDE |
| China ICP filing number | OWNER-TO-PROVIDE |
| Copyright line | OWNER-TO-PROVIDE |
| Demo account for App Review (if the reviewer must sign in) | OWNER-TO-PROVIDE, created outside this repo; never committed |

`https://www.chengyinhub.com/prod-api/` is the reviewed China API base URL (`Config/China.Production.xcconfig`). It is an API build input, not a privacy-policy or support URL.

## 3. Age rating answers

Proposed answers for the App Store Connect age-rating questionnaire, from source evidence. The owner confirms each; Apple computes the final rating.

| Question | Proposed answer | Evidence / note |
|---|---|---|
| Cartoon or fantasy violence, realistic violence | None | Map walking game; no combat content found |
| Sexual content or nudity, profanity or crude humor | None | No such content authored by the app |
| Horror or fear themes | None | |
| Alcohol, tobacco, drug use or references | None | |
| Medical or treatment information | None | Step counts are not health advice (`NSMotionUsageDescription`) |
| Simulated gambling, contests, loot boxes | None | Virtual goods and rewards are off (`workshopCommerceApproval` nil; step reward audit-only) |
| Unrestricted web access | OWNER-TO-CONFIRM | No in-app general browser was proven |
| User-generated content | Yes | Topics, stories, club channel messages (`ClubChannelMessagingView`, `NativeChannelMessageService`) |
| Messaging or chat between users | Yes | Club channels (IM) |
| Advertising | No | No ad SDK; tracking off in the privacy manifest |
| In-app purchases or payment | No | Not offered in 1.0; payouts and withdrawals are disabled (section 5) |
| Location sharing with other users | Yes, opt-in only | Personal location sharing starts only when the person picks someone (`PersonalLocationShareCoordinator`) |
| Parental controls, age assurance | No | |

Expected result: a rating driven by user-generated content and messaging. Report and moderation entry points exist in club views (`ClubCommunityViews`, `MemberReportProgressDetailView`); the owner confirms the Guideline 1.2 set (report, block, filtering, contact) is complete before submission.

## 4. Privacy nutrition label

Source of truth for the manifest: `Resources/PrivacyInfo.xcprivacy`, checked by `tools/check_privacy_manifest.py` (wired into `tools/check_scaffold.py`). Tracking is No everywhere; there are no tracking domains. Every declared type is Linked to the person, purpose App Functionality.

"Collected" follows Apple's meaning: leaves the device to the developer's service for longer than serving that request. Evidence paths are from `docs/release/cb67-privacy-data-flow.md` and source.

| Apple data type | In label | Linked | Tracking | Code evidence | Status |
|---|---|---|---|---|---|
| Contact Info > Phone Number | Yes | Yes | No | `AuthChannelService.sendSMSCode`, `loginWithPhone`; `RegistrationService.create` | Proven |
| Contact Info > Name | Yes | Yes | No | `RegistrationCreateIntent` writes `realName` | Proven |
| Location > Precise Location | Yes | Yes | No | `PersonalLocationShareCoordinator.publishOne`, `PersonalLocationShareHTTPService.publish`; when-in-use only (`NSLocationWhenInUseUsageDescription`), no `UIBackgroundModes` | Proven, only on opt-in sharing |
| Identifiers > User ID | Yes | Yes | No | `Account` decodes `id` / `userId` from the service; account-linked requests carry the session token | Declared; owner confirms the id is retained server-side |
| Identifiers > Device ID | Yes | Yes | No | `deviceKeyId` (App Attest key id) on the step request; not the advertising id | Proven, service off by default |
| Purchases > Purchase History | Yes | Yes | No | Ticket and registration reads (`TicketWallet*`, registration pay parameters); no StoreKit purchases in 1.0 | Declared; reads only, owner confirms |
| User Content > Photos or Videos | Yes | Yes | No | `ProfileAvatarUpload`, image uploads to `api/common/uploadOSS` | Proven (JPEG) |
| User Content > Audio Data | Yes | Yes | No | `MerchantNPCVoiceUpload`, IM voice upload after confirmation | Proven, gated |
| User Content > Other User Content | Yes | Yes | No | `NativeChannelMessageContracts`, `NativeChannelMessageService` (`api/im/message/edit`) | Proven |
| Health & Fitness > Fitness | Yes | Yes | No | `NativeStepContract.unsignedPayload` (`cumulativeSteps`, from `CMPedometer`, not HealthKit); audit-only, no reward | Proven, service off by default |
| Contact Info > Email Address | Yes | Yes | No | `RegistrationCreateIntent` can encode `email`; current form does not pass it | Declared conservatively; remove if unused at submission |
| Contact Info > Physical Address | Yes | Yes | No | `ParticipantForm.detailAddress` written back only if already present | Declared conservatively; remove if unused at submission |
| Tracking (any) | No | n/a | No | `NSPrivacyTracking = false`, `NSPrivacyTrackingDomains = []`; no analytics or ad SDK, no `MXMetricManager` | Checked |

The manifest declares four types (User ID, Purchase History, Email Address, Physical Address) more broadly than CB67 could prove. Over-declaring is safe for review; under-declaring is not. The owner trims them only after confirming against the production service.

Required-reason APIs (checked against source by the script):

| Category | Reason | Evidence |
|---|---|---|
| User Defaults | CA92.1 | Preferences and consent versions: `App/QuestifyApp.swift`, `App/UsageConsentGateView.swift` |
| File Timestamp | C617.1, 3B52.1 | Own temp files `App/IMVoiceDevice.swift`; user-selected files `App/TemplateAudioDocumentPickerAdapter.swift`, `App/ProjectStoryAudioSelectedDocumentReader.swift`, `Core/QmodArchiveInspection.swift` |
| System Boot Time | 35F9.1 | `ProcessInfo.systemUptime` for local deadlines: `App/MerchantStationLiveCodeView.swift`, `App/PlayKitSensorChallengeView.swift` |
| Disk Space | not declared | No `volumeAvailableCapacity`, `systemFreeSize` or `statfs` use found; the script fails if one appears without a declaration |

Vendored `Vendor/GLTFKit2/GLTFKit2/PrivacyInfo.xcprivacy` ships its own manifest (no collection, no accessed APIs).

## 5. Review notes (App Review Information > Notes)

Paste-ready. The owner appends demo credentials in the dedicated App Store Connect fields, not here.

```text
Chein is a walking game for iPhone. Hold Go, walk, and tiles light up on the map; stops give stamps and badges; a passport keeps them. Clubs and tickets are included.

Sign in. You can look around without an account ("Look around first" on the welcome screen). To keep a passport, sign in with Apple or with a mainland China phone number and an SMS code. Sign in with Apple is offered on the sign-in sheet. The SMS code goes to the phone number you enter. Password sign-in is not compiled into this build. If you need a signed-in account to review, use the demo account in the App Review Information fields: [OWNER-TO-PROVIDE].

Location. Requested only while the app is open and only after an in-app explanation card. No background location, no always-location permission.

Payouts and withdrawals are disabled. This version has no way to withdraw money, no bank-card entry and no payout. The wallet payout switch (WalletPayoutCapability) is off in this build, and withdrawal screens are not reachable. No virtual goods or in-app purchases are offered. Tickets are for entering activities; the app does not take payment in this version.

User content. Club channels and topics contain user-generated content. Report entries are in the club views. Contact: [OWNER-TO-PROVIDE].

Account deletion. [OWNER-TO-PROVIDE: describe the in-app path the owner confirms for this release.]

Privacy policy: [OWNER-TO-PROVIDE]. Support: [OWNER-TO-PROVIDE].
```

Evidence for the claims above (not for pasting): `App/AuthChannelView.swift` and `AuthChannelAppleButton.swift` (Apple button shows only when the Apple configuration is verified); `AuthChannelCoordinator` (phone code); `AppSession.passwordLoginCompiledIn` (false outside DEBUG); `App/WalletCommerceViews.swift:91` (`WalletPayoutCapability.isOn = false`) gating every withdrawal entry; `docs/release/app-review-notes.md` for the unconfigured-build facts.

Before submission the owner must confirm: the archived build selects the reviewed service (otherwise lists are empty), Sign in with Apple is enabled on the App ID, and the demo account works.

## 6. Owner checklist

- [ ] Approve en-US and zh-Hans fields above.
- [ ] Fill every OWNER-TO-PROVIDE value in section 2 and the review notes.
- [ ] Confirm age-rating answers (section 3) and Guideline 1.2 report/block coverage.
- [ ] Enter the nutrition label per section 4; trim conservative rows only after confirming with the service.
- [ ] Set bundle id, team and version; export compliance (`ITSAppUsesNonExemptEncryption` is unset).
- [ ] Screenshots (6.9-inch and 6.5-inch, en-US and zh-Hans), captured from the final build.
- [ ] No one submits from this file.

## 7. What this pack could not verify

No build, simulator or Xcode run. Feature names in the copy were checked against the voice table and source strings, not against a running archive. The tab layout in this tree is still the five-tab shell; the copy avoids naming tabs. The privacy script is a source scan, not Apple's validator.
