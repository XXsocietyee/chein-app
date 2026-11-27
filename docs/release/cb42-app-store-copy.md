# CB42 App Store copy (draft)

Draft only. The owner must approve this text before anyone pastes it into App Store Connect or submits a version. This file is not a submission. It was not entered in App Store Connect. Nothing here was signed or uploaded.

Base: `origin/rc/20261108` at `67053ccb33c0e1ad35a7508f8546ae9076fd82e5`. Marketing version stays `0.1.0`. Build stays `1` (`Config/Base.xcconfig`). This draft does not change either value.

Locales below are the App Store Connect locales `en-US` and `zh-Hans`. In-app strings cited here use the catalog keys `en` and `zh-Hans` in `Resources/Localizable.xcstrings`.

Paste-ready blocks are the only text intended for the store fields. The notes around them stay in this file.

## Owner still fills

These stay blank here. Do not invent them from this draft.

- Privacy policy URL, support URL, support contact, and marketing URL. `docs/release/app-store-metadata-checklist.md` already records that none is committed.
- A China ICP number.
- Age rating, export compliance, pricing, and availability.
- The United States service address. `ReviewedMarketLaunch` records a China host only. The United States market has no reviewed host (`Core/RegionalConfiguration.swift`). This draft does not name one.

## Paste-ready fields

Limits: name 30, subtitle 30, promotional text 170, description 4000, keywords 100, What's New 4000. Counts are Unicode scalar values. Keywords use commas and no spaces, and they do not repeat the name or the subtitle.

### Name

en-US (8):

```text
Chein
```

zh-Hans (2):

```text
城瘾
```

Owner decision 2026-11-27: the English brand is **Chein**; Chinese stays 城瘾. The built display name is localized in `Resources/InfoPlist.xcstrings` (`CFBundleDisplayName`: en Chein, zh-Hans 城瘾), with the fallback `INFOPLIST_KEY_CFBundleDisplayName = Chein` in `Config/Base.xcconfig`. In-app, the catalog key `Questify` reads Chein (en) / 城瘾 (zh-Hans) (`Localizable.xcstrings`).

### Subtitle

en-US (29):

```text
Activities, routes, and clubs
```

zh-Hans (9):

```text
活动、路线与俱乐部
```

### Promotional text

en-US (122):

```text
Home, Roam, Publish, Clubs, and Me. Browse activities, route topics, and clubs, or continue as a guest. Version 0.1.0 (1).
```

zh-Hans (48):

```text
首页、漫游、发布、俱乐部和我的。浏览活动、路线主题和俱乐部，或先逛一逛。版本 0.1.0（1）。
```

### Description

en-US (1018):

```text
Chein is an iPhone and iPad app. The five tabs are Home, Roam, Publish, Clubs, and Me.

Home is the screen for activities and route topics. It includes search and categories. Opening an item shows that activity or topic.

Roam is a read-only browser for an area you choose, including a map of that area. That screen does not ask for your location, follow you, or start a roam. If another screen asks for location, the request is while the app is open, and only when you choose it. Location is not used in the background.

Publish opens the Templates screen and read-only route previews. Publishing a template to other people is not part of this description.

Clubs opens the club list.

Me shows a welcome screen until an account is present. That screen has player entry, merchant entry, and Browse as a guest. Merchant entry does not grant merchant access.

The language control can follow the system, or stay on English or Simplified Chinese. The choice is kept on the device.

Version 0.1.0 (1). Requires iOS 17.
```

zh-Hans (345):

```text
城瘾是一款 iPhone 与 iPad 应用。五个分页是首页、漫游、发布、俱乐部和我的。

首页用来查看活动和路线主题，并包含搜索和分类。点开一条即可查看该活动或主题。

漫游是你所选区域的只读浏览，包含该区域的地图。这个页面不会索取定位、不会跟随你，也不会开始一次漫游。如果其他页面索取定位，只在应用打开时、并且由你主动选择后才会请求。不会在后台使用定位。

发布页打开「模板」，以及只读的路线预览。向其他人发布模板不在这段说明之内。

俱乐部页打开俱乐部列表。

在账号出现之前，「我的」显示欢迎页。欢迎页有玩家注册、商家注册和「先逛一逛」。商家注册不会开通商家权限。

语言可以跟随系统，也可以固定为英文或简体中文。这个选择保存在本机。

版本 0.1.0（1）。需要 iOS 17。
```

### Keywords

en-US (54):

```text
roam,map,topics,search,templates,events,language,guest
```

zh-Hans (20):

```text
漫游,地图,主题,搜索,模板,语言,游客
```

### What's New

en-US (42):

```text
First store listing for version 0.1.0 (1).
```

zh-Hans (19):

```text
版本 0.1.0（1）的首次商店文案。
```

## Screenshot captions

No screenshot was captured for this draft. No image is added to the repo. The same captions apply to the 6.9-inch and 6.5-inch iPhone sets in `docs/release/app-store-metadata-checklist.md`, for en-US and zh-Hans. The target family includes iPad (`TARGETED_DEVICE_FAMILY = 1,2`). This draft does not add a separate iPad caption set and does not state a pixel size.

Each row is overlay text for one shot, in tab order. Capture the named screen. Do not add a password field, a bank-card form, a withdrawal receipt, or a virtual-goods purchase to the frame.

| # | Screen in the binary | en-US caption | zh-Hans caption | The frame shows |
|---|---|---|---|---|
| 1 | `App/WelcomeView.swift` | Browse as a guest | 先逛一逛 | Player entry, merchant entry, and Browse as a guest (`welcome.browse` = "Browse as a guest" / "先逛一逛"). |
| 2 | `App/SessionHomeFeedView.swift` | Activities and route topics | 活动与路线主题 | The Home tab for activities and topics. An empty or unavailable list is an acceptable frame. |
| 3 | Home search and categories on that same feed | Search and categories | 搜索与分类 | Search and category controls. Do not invent results. |
| 4 | `App/RoamBrowserView.swift` (`RoamMapView`) | Read-only area map | 只读区域地图 | A chosen area and its map. Not a live follow and not a location prompt. |
| 5 | `ActivityDetailView` or `SessionTopicDetailView` | Activity or topic detail | 活动或主题详情 | One opened activity or route topic. |
| 6 | `App/ClubHomeView` via the Clubs tab | Club list | 俱乐部列表 | The Clubs tab. An empty list is an acceptable frame. |
| 7 | `App/DiscoveryTemplateBrowserView.swift` | Templates | 模板 | The Publish tab title Templates / 模板 (`discovery.templateTab.title`). Do not show a publish success. |
| 8 | `App/LanguageSwitcher.swift` | English or Simplified Chinese | 英文或简体中文 | The language menu: Follow system, English, 简体中文. |

## Where each claim comes from

| Claim in the paste-ready text | Source |
|---|---|
| Five tabs Home, Roam, Publish, Clubs, Me / 首页、漫游、发布、俱乐部、我的 | `Core/RootTab.swift` and `tabBar.home`, `tabBar.roam`, `tabBar.publish`, `tabBar.club`, `tabBar.mine` |
| iPhone and iPad, iOS 17 | `Config/Base.xcconfig`: `TARGETED_DEVICE_FAMILY = 1,2`, `IPHONEOS_DEPLOYMENT_TARGET = 17.0` |
| Home activities, route topics, search, categories | `Core/RootTab.swift` comment (activities and topics are inside Home); `homeFeed.activities`, `homeFeed.editorsPicks`, `homeFeed.allCategories`, `homeFeed.emptyHint` |
| Opening an item shows that activity or topic | `App/QuestifyApp.swift` routes roam and home destinations to `ActivityDetailView` and `SessionTopicDetailView` |
| Roam is a read-only area browser with a map, and that screen does not request location or start a roam | File comment and `RoamMapView` in `App/RoamBrowserView.swift` |
| Location elsewhere is while-in-use, only when chosen, and never in the background | `INFOPLIST_KEY_NSLocationWhenInUseUsageDescription` in `Config/Base.xcconfig`. `docs/release/ship-prep.md` records no always-location strings and no `UIBackgroundModes` |
| Publish opens Templates; publishing to other people is not claimed | Navigation title `discovery.templateTab.title` = Templates / 模板. README states production publishing remains disabled |
| Read-only route previews | README "Current implemented slices" |
| Clubs opens the club list | `RootTab.club` installs `ClubHomeView` in `App/QuestifyApp.swift` |
| Welcome: player entry, merchant entry, Browse as a guest | `App/WelcomeView.swift`; `role.player` = "Register as a player" / "玩家注册"; `role.merchant` = "Register as a merchant" / "商家注册"; `welcome.browse` |
| Merchant entry does not grant merchant access | README: merchant entry intent never grants merchant permission. `welcome.intentNotice`: "Merchant access depends on account approval." / "商家权限以账号审核结果为准。" |
| Language: system, English, or 简体中文, kept on the device | `App/LanguageSwitcher.swift` |
| Version 0.1.0 (1) | `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `Config/Base.xcconfig` |
| Keyword `roam`, `map`, `topics`, `search`, `templates`, `events`, `language`, `guest` | The Roam tab and its map, topic detail, home search, the Templates screen, the official-event and nearby-event readers already wired from the root, the language menu, and Browse as a guest. `events` names those read-only destinations. It does not name a ticket sale |

Live lists depend on the build selecting the reviewed China service. The default base configuration leaves `QUESTIFY_API_BASE_URL` empty, and `RegionalLaunchConfiguration.composition` stays `makeComposition(reviewed: nil, build: .current)` (`App/RegionalLaunchConfiguration.swift`). An empty or unavailable Home, Roam, or Clubs frame matches that build. This draft does not say those lists are populated.

## Left out of the listing on purpose

- Password sign-in. Release builds compile `canUsePassword` to false (`App/AppSession.swift`). `App/LoginView.swift` shows the username and password section only when that value is true. The words are not in the paste-ready fields.
- Bank-card withdrawal. A destination exists on the session. It is not described here.
- Virtual goods, wallet purchases, workshop purchases, and coupon redemption. Account rows for some of those exist in `App/AccountView.swift`. They are not described here.
- WeChat, phone, and Apple sign-in as available services. `docs/cn-native-session-contract.md` says Apple, WeChat, and US login remain independently closed, and that the phone contract does not claim a usable deployed login. The United States sign-in row says sign-in is not available in that region yet (`region.usLoginPending`).
- A United States API host. None is recorded. This file does not add one.
- Camera, microphone, motion, and photo-library-add usage strings. They are in the binary. This listing does not advertise those flows.
- Messages, payments, QR redemption, and completed gameplay. The README records those as incomplete or gated.
- Legal copy, a support contact, and a China ICP number.

## Approval

- [ ] Owner approves the en-US and zh-Hans paste-ready fields.
- [x] Store names: en-US Chein, zh-Hans 城瘾 (owner 2026-11-27). Home-screen name localized the same way.
- [ ] Owner supplies the 6.9-inch and 6.5-inch screenshots, using the captions above, or rejects a row.
- [ ] Owner fills the blank URLs and the ICP line outside this file, if a submission needs them.
- [ ] No one submits, signs, or uploads from this draft.
