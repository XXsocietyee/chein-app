# mp-mpaudit: mini-program parity, layout side (branch ui/mpaudit)

Source of truth: `liboyang42-cpu/hengyin` `chengyinhub-xcx` (head 2026-11-12), 171 pages in `app.json` (5 main + subpackages). Code-only: nothing built or run.
Direction (owner rule): mini-program -> app. No mini-program screenshots were shared.

## What changed (layout only)
| change | file | mp source |
|---|---|---|
| Home-city location consent card (non-blocking card above the feed; hidden when host passes no handlers) | `App/HomeCityLocationConsentCard.swift`, wired as `HomeFeedView.cityLocationConsent` | `pages/index` `v3-locprompt` |
| Public city catalog list + detail (loading / error / empty / content / load-more / more-retry / city sheet; detail loading / gone / error / ok) | `App/PublicCatalogViews.swift` | `pages/topic/catalog/index`, `catalog/detail` |
| Chapter story: loading and failed states no longer collapse into the "locked" empty state | `App/ChapterStoryView.swift` | app-own flow (story play) |
| 23 EN + zh-Hans strings (`homeCityConsent.*`, `publicCatalog.*`) | `Resources/Localizable.xcstrings` | |

## Round 1 comparison (Explore, Roam, Passport, search/map)
| mp page | native file | gaps found | fixed |
|---|---|---|---|
| pages/index/index | `HomeFeedView`, `HomeHeroHeaderSectionView`, `HomeSearchTabParityViews` | banner, greeting+city, editor picks / nearby / upcoming rails with loading+error+empty, topic/activity feed with paging states all present. Missing: home-city location consent card | card added (view only) |
| pages/roam/index + subpackageRoam/* | `RoamBrowserView`, `RoamLiveSessionView`, `RoamHomeTabsView`, `RoamNearbyTeamsView`, `RoamHistory*`, `RoamPassport*` | roam hub tap-navigation not touched (ui/rbug owns it). copy-gap detector reports 112/172 mp strings without an exact catalog match (mostly dynamic/rephrased); `subpackageRoam/nearby` 22/43: team-map hints (只看主题队伍, 举报这支队伍, 照片来源与许可, 网上怎么说 external-notes block, 玩家评价 compose) need a per-string review | not fixed this pass |
| pages/member/index (+ passport) | `PassportView`, `AccountView`, `MemberHomeHeader` | not re-audited in depth (10-line wxml delegating to components) | n/a |
| pages/search2 (+result) | `GlobalSearchView`, `SessionGlobalSearchView` | not re-audited in depth | n/a |
| pages/searchmap | `SearchMapExplorerView`, `SearchMapFilterSheet`, `SearchRoutePreviewView` | list states, refresh vs page error, no-coordinate count, related-topic button, date/price/sort filter all present | none needed |

## Round 2 (activity / team / topic)
| mp page | native file | gaps found | fixed |
|---|---|---|---|
| pages/activity/* | `ActivityBrowserView`, `ActivityDetailView`, `Official*`, `SessionRegistrationSheet` | `baoming` 26/57 strings unmatched, `official-organizer` 14/22 | not fixed (needs per-string review) |
| pages/team/* | `TeamHomeView`, `TeamCreateView`, `NearbyTeam*` | team detail: copy-gap 17/39: report-team entry, join code + team QR block, join-request read/loading/empty states, ranking loading/empty/error, "abort un-executed request" wording | not fixed; verify per string |
| pages/topic/index | `TopicDetailView`, `SessionTopicDetailView` | copy-gap 23/51: reviews compose / first-review empty, share topic, Beta note, hand-over-to-club (merchant side) | not fixed |
| pages/topic/catalog/* | none | whole page missing | `PublicCatalogViews.swift` (see above) |

## Round 3 (member / growth)
| mp page | native file | gaps found | fixed |
|---|---|---|---|
| subpackageP3 growthcenter index | `GrowthCenterView`, `GrowthCenterComponents` | loading/empty/auth/issue states, badge disclosure with obtained time present | none needed |
| growthcenter leaderboard | `GrowthLeaderboardView` | not re-audited | n/a |
| subpackageMember orient-score | `OrientScoreView` | copy-gap 22/32: 刷新计分, 申诉漏记任务, 提交历史操作人工核对, 结算本局, 其他对局 picker | not fixed; needs logic review (settlement) |
| subpackageMember orders/coupons/mylike/signup | `ProfileOrdersView`, `AccountCollection*`, `RegistrationSheetView` | not re-audited | n/a |

## MISSING (mini-program feature with no native counterpart found)
| mp page | note | action |
|---|---|---|
| subpackageA/pages/video-bounty | creator video bounty: submissions + accruals tabs, submit form only via ops campaign link; money accruals | MISSING; build read-only, payout stays OFF; needs a logic reader |
| pages/topic/catalog/index, detail | public city catalog | view built, host + reader wiring needed (Cursor) |
| subpackageMember/market/passes, pass, gift, membership, library | pass / membership / gift / library market: payments + virtual goods | MISSING; gate stays OFF; build read-only later |
| subpackagePass/reveal | pass key-reveal intro animation (frame sequence, skip, reduced-motion) | MISSING; tied to membership (gated) |
| subpackageJourney landing, seats, promo, settle, report | journey purchase / settle flow | MISSING; payment-related, gate OFF |
| merchant / coop / club operator pages | stay hidden behind `merchantSurfaceHiddenInV1`; not audited this pass | deferred per owner |

All other pages in `app.json` already have a route entry in `Core/MiniProgramPages.swift`; presence was not verified screen by screen.
Copy-gap detector (CJK string in wxml not found verbatim in catalogs or Swift) is only a hint list; native uses English keys with zh values and often rephrases.

## Added scope: app-own flows (no mini-program page)
| flow | screens in order | gaps | fixed | needs logic |
|---|---|---|---|---|
| Story chapter read | node detail -> `ChapterStoryView` -> return | loading shown as "locked"; failed read had no retry | loading + error states with retry | none |
| Project edit (professional) | `ProjectEditLaunchView` -> `ProjectEditView` (rules, chapters, audio, cover) -> review -> submit/handoff | exit guard, discard confirm, autosave observation, locked/read-only already present; deeper per-screen trace (NPC forms, date-range/session pickers, publish result) not done this pass | none | trace pending |
| Chapter nodes / NPC forms / pickers / drafts / publish | `Project*`, `Merchant*Authoring*`, `PublishingAIDraftSheet` | not traced screen by screen | none | trace pending |
| Play finish (medals, verdict, journey check) | `PlayFinishRouteCardView`, `RoamMedalShareView`, `PlayExperienceView` | not traced | none | trace pending |

## APP-ONLY (owner clarification: features the app added; keep intact, never MISSING)
| feature | native files | note |
|---|---|---|
| Message channel (channel messaging, history, pins, search, progress board, notifications) | `NativeChannel*`, `ClubChannelMessagingView`, `Messaging*` | app superset of mini-program IM |
| City-themed Monopoly game | `App/CityGamePanel.swift`, `Core/CityGameBoardProjection.swift` | untouched in this branch |
| Improved community | `ClubCommunity*` (feed, read composition) | untouched |

Floor rule for older-version areas (IM `subpackageB/pages/im/*`, square `pages/square/*`): the app must keep every mini-program behaviour plus its extras. IM and square were only checked for native-file presence (`IM*Views`, `Messaging*`, `Square*View`) in this pass; a behaviour-by-behaviour IM/square check (e.g. `subpackageB/pages/im/chat` has 16/31 unmatched copy strings per the detector) is still to do.

## For Cursor
- Host `PublicCatalogView` / `PublicCatalogDetailView`: feed from `PWaveCatalogCard`/`PWaveCatalogCity` (Core `PWaveP3ThemeCollection`), paging, filters (`/api/public-catalog/filters`), routes.
- Pass `HomeFeedView.cityLocationConsent` while the home-city consent is pending; record consent `privacy_policy/home_city_location` on agree, `saveLocationDeclined` on decline.
- Compile check pending (integrator): `CYErrorStateView(retryTitle:)` use in `ChapterStoryView`, `CYImageCard(verbatim:)` in catalog.
