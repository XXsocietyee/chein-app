# 城瘾 glossary and voice (EN / zh-Hans)

Canonical terms, tone rules and length budgets for every player-visible string. When a screen disagrees with this file, the screen is wrong. Counts are occurrences in `Resources/*.xcstrings` zh-Hans values on 2026-11-09 (before the e1 copy pass).

## 1. Brand

| Use | Text |
|---|---|
| In-app brand, both languages | **城瘾** |
| Store / About / marketing name | **chein - 城瘾** |
| Never in visible text | `Questify`, `Chengyin`, `Chengyin - 城瘾`, `CityFog` (only the legacy share-card lockup `城瘾 · CityFog` remains; owner: roam share) |
| Allowed internal identifiers | bundle id, `questify.mod` file format, keychain service names. These never render as prose. |

EN sentences keep the Chinese brand as a proper noun: "Reviewed by 城瘾", "Not yet on 城瘾". The assistant sender is "城瘾 assistant".

## 2. Core terms

| Concept | zh-Hans | EN | Notes |
|---|---|---|---|
| Playable experience | 玩法 | game / play | A template or mode. Never "玩儿法". |
| Route | 路线 | route | **Not 线路** (10 strings fixed). Official ones: 官方路线 / official routes. |
| Topic (authored project) | 主题 | topic | Not 专题. |
| Activity (event with a time) | 活动 | activity | Not "event" in player UI except official events (官方活动 / official events). |
| Club | 俱乐部 | club | Not 社团 except the fixed value "校园社团 / campus club". |
| Badge (identity or overall) | 徽章 | badge | Lit up / not lit: 已点亮 / 未点亮. |
| Medal (earned for an achievement) | 勋章 | medal | A distinct object from 徽章 in the code (`.medal` vs `.identity`). Do not mix inside one screen. |
| Stamp (photo collectible) | 邮票 | stamp | Not 印章 (印章 = seal; legacy fixtures only). |
| Stamp collecting | 集邮 | stamp book / collecting stamps | Album title: 集邮册 / Stamp book. |
| Daily city note | 城市签 | city note | The daily verse. EN was inconsistent (city stamp / daily verse / city note): use **city note**. |
| Roam | 漫游 | roam | The live walking mode with fog. |
| Footprints | 足迹 | trail / footprints | Walk record. Use 轨迹 only for the drawn line. |
| Check in at a place | 打卡 | check in | At a point of interest. |
| Event sign-in | 签到 | sign in (event) | Roster sign-in at an activity. |
| Ticket wallet | 票夹 | ticket wallet | One ticket: 票 / ticket. Voucher: 券 / voucher. |
| Sign up | 报名 | join / sign up | |
| Team | 队伍 | team | 团队 only for organisation-level. |
| Post (feed item) | 动态 | post | Not 帖文 in player UI. |
| Review (of a route / merchant) | 评价 | review | Not 点评. |
| Redeem | 核销 | redeem | |
| Merchant / store | 商家 / 门店 | merchant / store | 商家 = account, 门店 = physical store. |
| Close account | 注销账号 | close account | Not "delete" (deletion happens after a cooling-off). |

## 3. Tone rules

1. Friendly, plain, second person. "You" / 你, never 用户, never 您.
2. Short. One idea per sentence. A state says what happened, then offers **one** action.
3. Honest. Say what we know. Unknown is `—` (never `0`, never "N/A", never a fake count). A save that is not confirmed says "We couldn't confirm", not "Failed" and not "Saved".
4. No urgency or guilt. No "Only 2 left!", no streak-loss language, no countdown pressure, no pre-ticked consent boxes.
5. No dark patterns. The decline button is always visible and equal weight ("Not now / 暂不同意"). Browsing without signing in is always offered.
6. No system jargon. Never show API field names (`userStamps`, `loadUserStamps`), "writer", "readback", "original request/receipt", "synthetic", "fixture", "DEBUG". "Original request" prose in author/ops tools is flagged in `copy-audit.md` for rewrite as "your earlier request".
7. Errors name the thing and give one next step: "Couldn't load routes. Check your connection and try again."
8. Permissions explain the benefit first and when we read the data: "Allow location in Settings to check in. We only read it when you tap Check in."
9. Empty states are an invitation, not an apology: say what lives here and how it gets filled.

## 4. Length budgets

| Element | zh-Hans | EN |
|---|---|---|
| Button / chip label | ≤ 14 chars | ≤ 18 chars |
| Navigation title | ≤ 10 chars | ≤ 24 chars |
| Card / row title | ≤ 2 lines at default size | ≤ 2 lines |
| Empty / error headline | ≤ 2 lines | ≤ 2 lines |
| Helper text | ≤ 3 lines | ≤ 3 lines |

If a string is longer, shorten it; do not shrink the font.

## 5. Capitalisation and punctuation

- EN: **Sentence case** everywhere (titles, buttons, tabs). Proper nouns only: 城瘾, Apple, WeChat, Settings.
- EN: "Sign in", "Log out" never "Login" as a verb; "check in" (verb) / "check-in" (noun).
- EN loading is "Loading…" with the ellipsis character.
- zh: full-width punctuation `，。？！：` ; quotes “ ” ; a thin space between CJK and Latin/digits is **not** required, but keep one consistently (current catalogue: none).
- Numbers use format specifiers (`%lld`), never string concatenation; keep the specifier set identical in EN and zh (checked by `tools/check_catalog_coverage.py`).
- Placeholders in EN and zh must match 1:1 (count, order, type).

## 5b. Terms added in round 2

| Concept | zh-Hans | EN |
|---|---|---|
| Growth points | 经验 | XP (not bare "EXP" in zh) |
| City board action points | 行动额度 | action points |
| Logo image slot | 标志 | logo |

Share lockup is **城瘾** only, never `城瘾 · CityFog`.

## 6. Where DEBUG words are allowed

`fixture`, `synthetic`, `sample`, `DEBUG` may appear only inside `#if DEBUG` fixture hosts and design-fixture screens, always labelled. A release screen that shows them is a bug (none found in the player path on 2026-11-09).

## 7. Core state copy (reference)

| State | EN | zh-Hans |
|---|---|---|
| Loading | Loading… | 加载中… |
| Offline | You're offline. Showing what's saved. | 现在没有网络，先显示已保存的内容 |
| Search empty | No places match · Try a different keyword, or loosen the filters. | 没有找到匹配的地点 · 换个关键词，或放宽筛选条件。 |
| Ticket wallet empty | No tickets yet. Join an activity and your ticket lands here. | 票夹还是空的。报名活动后，票会放在这里。 |
| Camera off | Camera is off · Allow the camera in Settings to take a stamp photo. We only use it when you tap the shutter. | 相机未开启 · 到“设置”里允许相机，就能拍邮票照片。只有你按下快门时才会拍照。 |
| Location off | Location is off | 定位未开启 |
| Unconfirmed write | That didn't go through. Refresh to check, then try again. | 没有完成。刷新确认状态后再试一次。 |
