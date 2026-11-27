# Roam fog: location permission copy (DRAFT, owner confirmation required)

Status: **not approved**. Nothing here ships behind a flag flip; `PersonalFogFeature.liveRevealEnabled` and
`RoamExperienceCapabilities.location` stay off. Spec: `roam-fog-engine.md` §1d and open item 1.

## Finding: the usage key is already installed

`NSLocationWhenInUseUsageDescription` is **not** missing any more. It is already an `INFOPLIST_KEY_*` in
`Config/Base.xcconfig` (merged by `GENERATE_INFOPLIST_FILE = YES`) with en + zh-Hans in `Resources/InfoPlist.xcstrings`,
and `tools/check_personal_location_share.py` asserts the two stay equal. That reviewed string is broader (it covers
personal location sharing). This change therefore does **not** touch `Config/Info.plist`, the xcconfig or the catalog,
because overwriting it would regress the sharing disclosure and break that check.

## Draft fog copy (owner decides: replace, merge, or keep the existing key)

| | Text |
|---|---|
| EN | Chengyin uses your location while the app is open to light up the places you walk and show what is nearby. It never runs in the background. |
| ZH (zh-Hans) | 城瘾仅在你使用时获取位置，用来点亮你走过的地方并显示附近内容，不会在后台定位。 |

If approved as the *only* description, personal location sharing would need its own disclosure elsewhere. A merged
sentence is the safer option.

## Priming and denied cards (`App/DesignSystem/CYPermissionPrimer.swift`)

> i18n-r2-strings (11-27): the "only while the app is open / never in the background" draft below contradicted
> actual behaviour (roam and city orienteering keep recording in the background via `SessionBackgroundLocationTracker`,
> as `NSLocationWhenInUseUsageDescription` says). The priming card now says so in both languages; points are
> "Only when you start something" and "A roam keeps recording in the background until you pause or finish".

Priming (first GO, before the OS prompt): title "Light up where you walk" / 点亮你走过的地方; body is the draft sentence
above; points "Only while the app is open", "Never in the background", "You can turn it off anytime in Settings";
buttons Continue / Not now.

Denied: title "Location is off" / 定位已关闭; body "Turn it on in Settings to light up the places you walk. You can
still look around a place you pick."; buttons Open Settings / Not now.

The spec also asks the explainer to say "nothing is uploaded" and "how to delete". Both are left out on purpose: reveal
sync is a separate reviewed contract, and no delete path exists to describe yet.

Preview with `--design-fixture permission-primer`, `permission-primer-denied` (suffix `-zh` for Chinese).
