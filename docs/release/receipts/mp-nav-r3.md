# mp-nav r3 — navigation, app-style (receipt)

Brief: `origin/design/handoff-r2:docs/briefs/round3-1127.md` (OWNER RULE + OWNER RULE 2). MP source: `origin/mp-source:chengyinhub-xcx`.
Branch `mp/r3-nav` from `origin/ui/combined-r7`. Not compiled (no Swift toolchain here); every member used already exists in the repo.

One native pattern: tab roots = `NavigationStack` + large top-left title (`cyRootHeader` / `.large`); pushed pages = inline title;
MP popups / half-screens = `.sheet` with detents; full-screen only for camera, game and map play (and photo/pass viewers).

## Pattern fixes

| # | where | before | after |
|---|---|---|---|
| P1 | App/HomeFeedView.swift (首页 root) | inline transparent bar over the banner, logo leading, list bled under the status bar (mp-home r3) | large top-left 首页 (`appNavigationTitle("homeFeed.title")` + `.large`); banner → greeting → … stay in MP order under it (OWNER RULE 2 correction of the 13:34 note) |
| P2 | App/NativeR2/MapHome/RoamMapHomeSheet.swift (漫游 root panel) | inline 漫游 | `cyRootHeader(.roam)` large title like the other four roots; peek height 120 → 172 pt (RoamMapHomeModel.swift) so title + search fit |
| P3 | App/PublishingManagementViews.swift:107 (我的项目, pushed) | `.large` on a pushed page | `.inline` |
| P4 | 48 pushed / sheet titles in 37 files (IM location/route/map/voice, channel views, friend home/directory, blacklist, webhook logs, template authoring/sample/config, play task/tools/advanced, journey questions, city finish summary, discovery topic preview, enrollment …) | no display mode → inherited the large title when pushed from a tab root | explicit `.navigationBarTitleDisplayMode(.inline)` |

Audited, unchanged (allowed by the rule): hidden nav bar only in live roam / free-explore map / finish report (game & map play) and the story walking author (story-flow, out of scope); full-screen covers only for cameras/scanners, live roam, city board, game finish/cast, ticket pass presentation and photo viewers.

## MP edge → native control

| MP edge (from → to) | MP control | native control | status |
|---|---|---|---|
