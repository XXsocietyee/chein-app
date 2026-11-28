# Design levels per screen (OWNER RULE 3, 11-28)

Owner: "Most pages need to be clean, uncluttered and professional, but game pages, the story flow, payment and maps
need their own character … Overall, it still needs to have a sense of design. You can decide on the level of design."

Every player screen belongs to one level. Lanes put the level in each receipt row. MP content and order still decide
**what** is on a page (OWNER RULE); the level decides **how much character** it gets. Navigation and type stay native
everywhere (OWNER RULE 2): large title on tab roots, inline title on pushed pages, Dynamic Type text styles only.

| Level | Gets | Never |
|---|---|---|
| **A · Signature** | The restored effect kit (`CYBurst`, `CYConfettiBurst`, `CYStarBloom`, `CYFogLayer`, `CYEdgeGlow`, `CYFoil`, `cyStampSlam`, `cyCelebrations`), choreographed motion, sound and haptics, the brand colour used boldly. Each effect has a Reduce Motion fallback (fade / static end state) and honours Low Power via `CYLightBudget`. | Blocking input, slowing a list, playing more than once per moment |
| **B · Crafted** | System navigation and components plus designed objects: hero image/art at the top; people visible (face pile + "Mia and 23 others"); one collection object per concept (a badge looks the same everywhere); big numbers with units; a map snippet for every place; floating primary bar (`safeAreaInset(edge: .bottom)` + material); quiet motion only (`.scrollTransition`, `matchedTransitionSource` + `.navigationTransition(.zoom)`, `.contentTransition(.numericText())`, `symbolEffect`). Designed empty states (`ContentUnavailableView` + the real action). | Glow, foil, particles, decorative gradients |
| **C · Utility** | Plain grouped `List` / `Form` done perfectly: SF Symbols in tinted rounded squares (`CYRowIcon`), correct row types, inline validation, footnotes, one `.borderedProminent` primary action. | Any decoration or decorative motion |

One brand voice across all levels: a single accent (`CYColor.brand`) plus semantic colours, one count style, imagery
does the expressive work. Gate: `tools/check_design_consistency.py` kind **effect on clean page** fails when an
effect-kit component is called from a B/C screen file.

## Screen map

Screen names follow `docs/audits/1128-functions.md` (origin/audit/1128-functions). Lane = owner in round 3.

### Tab 首页 (home) — mp-home

| Screen | Native view | Level | Notes |
|---|---|---|---|
| 首页 feed + hero (banner, greeting/city, 编辑精选, 附近活动, 即将上线, feed tabs) | `SessionHomeFeedView`, `HomeFeedView` | B | banner art first; cards `.scrollTransition`; zoom to detail |
| 首页 search (in-place + global) | `SessionHomeFeedView`, `GlobalSearchView` | B | P18 empty state; results as text rows when no image |
| Map search | `SearchMapExplorerView` | A | map surface (fog/trail not required here; pulsing position) |
| Topic detail | `SessionTopicDetailView` | B | hero cover, map snippet per place, bottom action bar |
| Activity detail | `ActivityDetailView` | B | P28 facts, face pile, map snippet, bottom bar |
| Public profile | `SocialPublicProfileView` | B | same collection objects as Me |
| Template detail / topic-template deck | `DiscoveryTemplateDetailView`, `TopicTemplateUseSection` | B | |
| Official events browser | `OfficialEventsBrowserView` | B | |

### Tab 漫游 (roam) — mp-roam

| Screen | Native view | Level | Notes |
|---|---|---|---|
| Roam map home + place card + nearby sheet | `RoamMapHomeView`, `RoamMapHomePlaceCard`, `RoamBrowserView` | A | fog lifting, lit trail, pulsing position; map panel is settled (`CYMapChrome`, coordinator 02:05) |
| Live roam + tools sheet | `RoamLiveSessionView` | A | |
| City roam / territory / city player | `CityRoamRootView`, `RoamTerritoryView`, `CityPlayerView` | A | the city "lighting up" |
| Roam finish report | `RoamFinishReportView` | A | P30 result; celebration once |
| Stamp camera / stamp collected | `SessionRoamStampCameraView` | A | `cyStampSlam` + burst + success haptic |
| Roam experience hub (passport, tools), exploration export | `RoamExperienceHubView`, `RoamExplorationExportView` | B | |
| Stamp album | `StampAlbumParityViews` | B | P24 stamp's own shape, desaturated when not collected; no foil sheen |
| Item detail, poster | `RoamItemDetailView`, `SessionRoamPosterView` | B | |
| Coupon wallet | `SessionRoamCouponWalletView` | C | |
| Nearby teams, team detail, team create, invitation entry | `NearbyTeamViews`, `TeamDetailView`, `TeamHomeView` | B | team create form = C |
| Location share settings | `PersonalLocationShareEntry` | C | |

### Tab 发布 (publish) + IM — mp-publish / mp-nav

| Screen | Native view | Level | Notes |
|---|---|---|---|
| 发布 tab root (template shelf) | `DiscoveryTemplateBrowserView` | B | |
| Play template detail / topic template deck | `DiscoveryTemplateDetailView` | B | |
| Project editor (fabu, chapter story, node) | `ProjectEditView` | C | forms; P31 composer |
| 我的项目, 内容草稿 | project / draft lists | C | |
| IM inbox, friends, system conversation, report result | `MessagingHomeView`, `IMDriftEntries` | B | inbox is B (avatars, unread); report progress = C |
| IM chat (+ attach, 更多) | `MessagingHistoryView` | B | bubbles, system components; chat settings = C |
| Square / feed | `SquareBrowserView` | B | |

### Tab 俱乐部 (clubs) — mp-club

| Screen | Native view | Level | Notes |
|---|---|---|---|
| Club home | `ClubHomeView` | B | P17 order, P25 rows |
| Club detail (概览, 活动, 帖文, action panel) | `ClubDetailView`, `ClubCommunityViews` | B | P26 hero, face pile, bottom bar |
| Post detail, comments, post tile | `ClubCommunityViews` | B | |
| Composer | club post composer | C | P31 |
| Club joined | join result | A | celebration once (mp-club) |
| Create club form | create form | C | |
| Club management, roles/governance, ops 客户 / 活动运营 / 通知 | `ClubManagementView`, `ClubGovernanceViews`, `ClubOpsEventView`, `ClubNotificationAudienceView`, `ClubOpsCustomerViews` | C | admin |

### Tab 我的 (mine) + sign-in — mp-mine / mp-nav

| Screen | Native view | Level | Notes |
|---|---|---|---|
| Welcome (launch, signed-out root) | `WelcomeView` | A | onboarding fog disc |
| Login, phone sign-in | `LoginView`, `AuthChannelView` | C | P27 / P33: system `SignInWithAppleButton`, phone with +86/+1 |
| Me / passport (identity card, 项目 / 推文 / 成就 / 关于 tabs) | `AccountView`, `MemberHomeHeader` | B | cover + avatar, big numbers with units |
| Badge wall, badge detail | `ProfileBadgesView`, `ObjectBadgeViews` | B | P24; badge **unlocked** moment = A (mp-mine) |
| Level up | level result | A | celebration once (mp-mine) |
| Points history, balance ledger | ledger lists | C | P23 |
| Profile edit, settings, participants, legal, compliance | `ProfileEditView`, `SettingsView`, `AccountComplianceViews` | C | `CYRowIcon` rows |

### Cross-tab: registration, payment, orders, tickets — mp-activity

| Screen | Native view | Level | Notes |
|---|---|---|---|
| Registration sheet (baoming) | `RegistrationSheetView` | B | P32 checkout stays clean |
| Pay moment (WeChat / Alipay / Apple Pay / card) | `RegistrationPaySection`, `RegistrationStripePayRows` | A | button → progress → check, success haptic, ticket slides into the wallet; failure = shake + warning |
| Payment success result | pay result | A | celebration once |
| Order detail, refund, transfer, bundle cancel | `OrderLifecycleView`, `BundleRefund…`, `BundleTransfer…`, `BundleCancelView` | C | |
| Ticket wallet, ticket pass | `TicketWalletView`, `TicketPassSheet` | B | ticket card is a designed object; no foil sheen |
| Pass market, pass detail, gift claim | `PassMarketViews` | B | |
| Host tip, workshop purchases | `HostTipViews`, `WorkshopPurchasedLibraryView` | C | |

### Play / games / story — mp-journey

| Screen | Native view | Level | Notes |
|---|---|---|---|
| Play HUD, game shell, dice, game stages, quiz | `PlayGameStageViews`, `PlayRPGComponents`, `PlayKitQuestoViews`, `App/NativeR2/Games/*` | A | game motion, particles, sound and haptics on game events |
| City orienteering, journey maps, free explore map | `NativeFreeExploreMapView`, journey map views | A | map surface; one light map style |
| Wrap-up / run finished | wrap-up result | A | P30: score, two-column facts, `ShareLink` + leaderboard, celebration once |
| Story flow (chapter, narration, chapter video) | story / chapter views | A | motion layer only; theme direction from the owner (on hold) |
| Free-explore pass / bundle launch | `FreeExploreBundleLaunchView` | B | |
| AI NPC chat records | `NPCChatDataView` | C | |

## How a lane uses this

1. Find your screen above; write its level in the receipt row (`Level B`).
2. A-level effects: call the shared kit only; never copy an effect into a page file.
3. A screen not listed: pick the level of its closest sibling here and add a row in the same commit.
