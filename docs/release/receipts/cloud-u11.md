# Cloud U11 — six visual fixes from the native screenshot pass

Base: `origin/ui/next` `fd8ddfe57148f1d05f784e43fce3f5a247d63149` (already contains `bed021d2`).
Branch: `ui/cloud-u11`. `origin/ui/cloud-u11` did not exist. No force-push.

This agent is Linux. There is no Xcode and no iOS Simulator, so these fixes were not viewed on a device. `swiftc` is not installed here, so `swiftc -parse` could not run. `python3 tools/check_scaffold.py` and `python3 tools/check_design_lint.py` are the checks that did run.

## 1. One Explore search

Explore showed two fields: the hero pill under the greeting, and `HomeFeedInlineSearch` ("搜索路线和活动") under "更多玩法". The inline field is gone. The remaining entry is the hero pill `homeIndex.hero.searchEntry`, placed in the home top bar above the greeting. It opens pages/search2 through `onOpenUnifiedSearch`. The session home wires that to the existing global-search sheet. The map button `homeIndex.hero.mapSearchEntry` stays on the same pill. The hidden navigation-bar search is still only attached when the bar is showing, so the hero does not draw a second field.

## 2. Offline copy in zh-Hans

The three Explore sentences ("You're offline", "Your map and lit tiles are here; new content waits for the network.", "Retry") lived only in `CYStateContent.offline` and followed the region locale, so a zh-Hans UI with an en_US region stayed English. They are now catalog keys `cy.kit.offline.title`, `cy.kit.offline.body`, and `cy.kit.offline.retry`, with zh-Hans 你离线了 / 地图和已点亮的格子还在；新内容等网络回来 / 重试. The offline strip and the server kit lines are `cy.kit.offline.saved`, `cy.kit.server.title`, and `cy.kit.server.body`. Lookup uses `AppLanguage.interfaceIsChinese`: an explicit language wins, System follows the bundle's preferred localization, and a nil runtime (unit tests) still trusts the locale passed in.

A scan of every `Resources/*.xcstrings` key found no other key missing a zh-Hans value. Latin-only zh-Hans values that remain are format strings (levels, identifiers), not English sentences. `CYKitCopy`, `ChannelCopy.isChinese`, and `Locale.pick` now share the same interface-language check, so other offline lines that go through those helpers follow zh-Hans too. Explore's own `CYStateLayout` title and detail (`homeFeed.unavailable`, `auth.notConfigured`) use the same lookup.

## 3. Welcome language row

The welcome "…" menu nested `LanguageSwitcher` with a globe and no title, so the submenu row was blank in both languages. That call now passes `showsMenuTitle`, and the row reads `settings.language` (Language / 语言). The toolbar switcher stays icon-only. `language.switcher` and the accessibility label are unchanged.

## 4. Onboarding step 5

The primary CTA no longer rests on a green check. `OBMorphPill` shows the check only while `registered` is true and Reduce Motion is off. The label stays at rest: catalog `onboarding.createAccount` (Create account / 创建账号). After the transition, `registered` returns to false, including the fixture auto-demo. Reduce Motion sends the tap and never morphs. `welcome.player` is unchanged.

## 5. Clubs 帖文 / 俱乐部

`ClubHomeView` keeps the existing `clubTab.topTabs` picker (帖文 / 俱乐部) and gives it a page background and z-index so the club list background cannot cover it. 帖文 is the existing `ClubCommunityFeedView` (not rebuilt), with `MPPassExploreCard` above it; the card still draws nothing when the pass-store binding is absent. 俱乐部 keeps the create row and the list, now grouped as 你的俱乐部 (`club.home.yours`, owned + joined) and 发现 (`club.home.discover`, nearby). Empty groups stay hidden. The tab still opens on 俱乐部.

## 6. Explore section order

The scroll is now: hero (avatar, greeting, city, and the single search), the location-consent card when the host supplies it, 编辑精选, 附近活动, 即将上线, then the Today card, banners, the pass-store card, and the continuation banner, then 主题 / 活动 with the existing infinite scroll. Today stays an app extra under the three rails, so it cannot push 编辑精选 below the fold. Empty rails still hide themselves. No new feed data is fetched.

## Left alone

`App/AppSession.swift`, `App/AppCompositionRoot.swift`, RegionalLaunchConfiguration grants, Release fixtures, the ledger, gitleaks, and workflows were not edited. No new Swift file was added, so `tools/generate_project.py` was not required to register a file.
