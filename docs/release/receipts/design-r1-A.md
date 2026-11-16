# Design hand-off r1 · foundation and player pages · receipt

Branch `ui/d-r1-foundation-player` from `origin/ui/main` (15205f9b). Specs: `origin/design/handoff-r1:docs/design/handoff-r1/`
(review/full-player.md §2–§4, revise/player.md, revise/kit3.js geometry, mp-tokens.json, owner-figma-audit.md).

**Evidence boundary.** Swift is not installed in this environment, so nothing here was compiled, run in a simulator, or
screenshotted. Every type, initializer and modifier used was checked by hand against existing code and the iOS 17
deployment target. What did run: `check_scaffold.py` (pass), `contract_ratchet.py --check` (no new failures; the 2
failures it reports also fail on untouched `origin/ui/main`), `check_design_lint.py` (pass), `check_a11y.py` (pass),
`check_missing_string_keys.py` (0 missing), and the Tree-sitter parse on every changed Swift file (pass, except
`PlayExperienceView`, `PlayHelpLadderPanel` and `RoamBrowserView`, which fail the parser identically on `origin/ui/main`).
Unit tests were added or updated but not executed. Visual and motion checks are still owed on a device.

## Foundation (shared design system, for the config / club / merchant agents)

| Item | Files | Status |
|---|---|---|
| Handbook fixes: light border-strong `#8C8C8C`, inputs `#EFEFEF` in a card / `#E4E4E4` on the page (filled keeps the fill), light status-soft 18%, home feed count `#C2410C` | `App/DesignSystem/CYDomainPalette.swift` (`inputIdleBgOnPage`, `homeFeedCount`, `handbook*` constants) | done |
| White primary pill 44 / 52, `#1C1C1E` secondary with white label (surface-3 on a sheet), 15 pt 70% tertiary | `App/DesignSystem/CYPillButton.swift` (`CYPillSize`, `cyPillOnSheet`) | done |
| Neutral selected tab, 5 labelled tabs 首页 / 漫游 / 发布 / 俱乐部 / 我的, blank white pill fixed | `CYDomainPalette.swift` (`tabSelectedTint`, `tabSelectedCapsule`), `CYNightTabBar.swift`, `CYDomainTabBar.swift`, `Core/RootTab.swift` | done |
| One root header whose title matches the tab; 消息 first trailing action | `CYPlayerKit.swift` (`cyRootHeader`, `CYRootSubtitle`, `CYHeaderCircleLabel`), `SessionMessagingEntry.swift` | done (roam root: left, see PL-11) |
| Labelled status tags instead of dots | `CYPlayerKit.swift` (`CYStatusTag`, `CYStatusTagState`), `CYRoamKit.swift` (`CYRoamStatusTag`) | done |
| Resizable scrollable sheet (Kavsoft reference): §3 detent table, grows by drag, scrolls only at the largest detent, spring 0.38 / 0.86, `.selection` on settle, Reduce Motion cross-fade, map sheets interactive up through `.medium`, dirty sheets ask 放弃修改？, TE header (grey ✕ + black 完成 pill) and player header | `CYPlayerKit.swift` (`CYSheetKind`, `CYSheetSize`, `CYResizableSheet`, `cyResizableSheet`, `CYSheetHeader`, `cyFitSheetDetent`) | done |
| Unknown values "—", motion values, hold-to-start, level-up moment | `CYPlayerKit.swift` (`CYUnknownValue`, `CYMotion.sheetDetent` …, `CYHoldToStartButton`, `CYLevelUpMoment`) | done |
| Strings | `Resources/DesignR1.xcstrings` (new table, en + zh-Hans) | done |
| Tests | `Tests/AppUnitTests/DesignR1FoundationTests.swift` (new), `DesignSystemTokenMappingTests.swift`, `Tests/CoreTests/RootTabTests.swift`, `HomeSearchTabParityTests.swift`, UI tests' tab labels | written, not run |

How to adopt: `.cyResizableSheet(isPresented:kind:title:headerStyle:isDirty:primary:onDone:)` or `CYResizableSheet(kind:…)`
as a sheet root; add a row to `CYSheetKind` for a new sheet; `CYPillButton(…, size: .moment)` on full-screen moments;
`CYStatusTag(.recording)` or `CYStatusTag("key", state: .warning, tableName:)`; `.cyRootHeader(.club)` on a tab root.

## Player issues

| ID | Status | Files | Notes |
|---|---|---|---|
| PL-01 | done | `CYDomainPalette.swift`, `CYNightTabBar.swift`, `CYDomainTabBar.swift`, `Core/RootTab.swift`, `QuestifyApp.swift` (unchanged; reads `playerTitleKey`) | Ink at full opacity, Semibold, 12% capsule; unselected 60%. |
| PL-02 | partial | `PlayExperienceView.swift`, `PlayHelpLadderPanel.swift` | Play loop keeps the existing play screen; error twins already use the shared state views. No new N87 HUD layout. |
| PL-03 | partial | `JourneyLandingViews.swift`, `CYPlayerKit.swift` | 开局大厅 starts with a 0.8 s hold on the one primary. Cover strip and 怎么玩 three-liner not added (no 站数 / 时长 facts on the seats read). |
| PL-04, PL-05 | left | — | Figma seed text; no app strings found to change. |
| PL-06 | partial | `HomeFeedView.swift` | Home content now scrolls under a visible bar (tab-bar clearance already existed). |
| PL-10 | done (kit) | `CYPillButton.swift`, `CYPlayerKit.swift` | Twins elsewhere adopt as pages are touched. |
| PL-11 | partial | `HomeFeedView.swift`, `HomeSearchTabParityViews.swift`, `Core/HomeSearchTabParity.swift`, `AccountView.swift`, `ClubHomeView.swift`, `PublishTabRootView.swift`, `SessionHomeFeedView.swift`, `SessionMessagingEntry.swift` | 首页 / 发布 / 俱乐部 / 我的 titled by the tab, 消息 first trailing. 发布 and 俱乐部 keep their in-content large title. Roam root (map) not given the header. |
| PL-12 | partial | `JourneyReportViews.swift` | Settle: 完成 primary, 看排行榜 secondary. Checkout `重试` variant and join page already had their primaries. |
| PL-13 | done | `GrowthCenterView.swift`, `CityMonopolyTerritorySection.swift`, `CYPlayerKit.swift` | Level-up is a full-screen moment; 地盘已释放 is a fit sheet with 重新圈地. |
| PL-14 | partial | `CYRoamKit.swift`, `RoamLiveSessionView.swift` | Live HUD dot → tag. Map-pin and participation chips not changed. |
| PL-15 | done | `PlayHelpLadderPanel.swift`, `PlayExperienceView.swift` | fit → `.medium` sheet 要点提示吗; free count tag, "—" + 次数没取到 when unknown. Hint unblur motion not added. |
| PL-16 | done | `RoamBrowserView.swift`, `RoamTerritoryView.swift` | One CITY entry (N01); 收藏的据点 row and the A10 tools live in N01's 更多 menu. Maestro `city-game.yaml` now lands on N01. |
| PL-20 | partial | `RoamLiveSessionView.swift` | Tab bar hidden during a session; single 允许使用位置 consent, hold-to-start only after; numbers roll; medium impact on pause / resume. Full-bleed map + `.height(120)` sheet rebuild not done (the List HUD remains). |
| PL-21 | left | — | Roam root map-first layout. |
| PL-22 | partial | `HomeFeedView.swift` | Promo swiper moved below 附近活动. Theme card redesign not done. |
| PL-23 | partial | `TopicDetailView.swift` | Second preview button removed; the sticky action bar already existed. Hero / four-cell stats not rebuilt. |
| PL-24 | partial | `RegistrationSheetView.swift` | 选择票种 is a fit sheet; 积分抵扣 was already a switch row. Unknown activity rows stay "—" (task rule: show unknowns as "—"). |
| PL-25 | partial | `RoamLiveSessionView.swift` | Live roam consent has one button. Shared `PermissionPrimerView` not unified. |
| PL-26 – PL-29 | left | — | Payment results, pass stack, share card, search states. |
| PL-30 | done | `MemberHomeHeader.swift` | 积分 first and large; ¥ 账户余额 only when the server sent a balance (owner Q-B). |
| PL-31 – PL-34 | left | — | Team, official activity, 017 states, club creation (club pages belong to the club agent). |
| PL-35 | done (no change) | `SessionMessagingEntry.swift` | Owner Q-C: 合作池 stays at the top of 消息; IM keeps the Flutter-style chat. |
| PL-36 – PL-39 | left | — | |
| PL-40, PL-41 | partial | `CYPlayerKit.swift` | Motion values defined (`CYMotion.sheetDetent`, `fullScreenRise`, `pinSelect`, `slotDrop`, `flagPlant`). Zoom transitions already existed for feed cards. |
| PL-42 | done | `CYPlayerKit.swift` (`CYHoldToStartButton`) | Ring, unwind, VoiceOver action, haptics. No CHHaptic ramp or HUD morph. |
| PL-43, PL-44, PL-46, PL-47 | left | — | |
| PL-45 | partial | `CYPlayerKit.swift` (`CYLevelUpMoment`) | Level-up moment; d20 roll not changed. |
| PL-48 | partial | `CYPlayerKit.swift`, `RoamLiveSessionView.swift` | Sheet settle `.selection`, number roll, pause impact. |
| PL-50 – PL-56 | partial | `Core/HomeSearchTabParity.swift` | PL-54 greeting copy done; others left. |

## Rules held

- 积分 is the only currency; ¥ appears only for a real balance or ticket price.
- Unknown values read "—" (`CYUnknownValue`, hint free count, 积分 tile).
- No feature was removed: retired A10 tools and 收藏的据点 stay reachable from N01; the roam consent still records the same consent.
- Money switches untouched. Channel / IM pages untouched apart from the bell's position.
- Accessibility labels kept; new controls have labels, identifiers and Dynamic Type text styles.
