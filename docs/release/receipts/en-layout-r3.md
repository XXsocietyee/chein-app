# en-layout r3 — receipt

Lane **en-layout**, branch `i18n/r3-en-layout` (from `origin/ui/combined-r7`). Brief: `origin/design/handoff-r2:docs/briefs/round3-1127.md` (Lane areas row: every player screen in English for the US launch — untranslated text, truncation, wrapping, plural/number/date/currency formats, "Chein" brand, long English at large Dynamic Type). OWNER RULE / OWNER RULE 2: string and layout fixes only; no MP section is added, dropped or reordered, no navigation chrome changes.

No Swift compiler in the cloud: fixes are catalog values and stock SwiftUI modifiers already used in the repo.

## Run log

### Run 1 (2026-11-27, hourly)

| # | MP page → native view | Problem in English | Fix | Status |
|---|---|---|---|---|
| 1 | `pages/play/*` clue unlock, free-explore meta, play tools, lead bar → `CYBusinessComponents.swift:716`, `FreeExplorationViews.swift:174`, `MPGap/PlayRoam/PlayToolsAndLeadSheetView.swift:161`, `MPGap/PlayRoam/PlayLeadBar.swift:55` | `check_locale_format.py` FAILED: 4 multi-argument count strings read "1 points / 1 chapters · 1 shops / 1 shops · … / finished 1/1 stops" | `tools/add_i18n_r2_substitutions.py` run: English plural substitutions (catalog + the `i18n-r3-strings` / `mp-journey-r3` fragments). Gate now PASS | Done |
| 2 | `pages/topic/*` purchase reveal → `TopicPurchaseRevealMount.swift:22` | Pass card kind read "Chengyin · Free Explore pass" / "Chengyin · City Orienteering pass"; the English brand is **Chein** (InfoPlist `CFBundleDisplayName`, owner 11-27) | `topicReveal.kind.free` / `.city` en → "Chein · …" (catalog + `i18n-r3-strings.json`) | Done |
| 3 | 21 single-count strings on player screens: topic detail (`topic.chapterCard.games`, `topic.depart.sharedBy`, `topic.depart.stops`, `topic.reviews.basedOn`, `topic.teams.count`, `topicXcx.routeNote.freeShops`, `topicXcx.routeNote.stops`), roam (`roam.w208.intro.live`, `design.roam.teamsOnRoute` on the city-run map pill, `附近共有 %lld 支队伍`, `附近共 %lld 个结果 · 最近`), play (`playFree.meta.stores`, `playx.board.score`, `play.nr2.route.stops`, `cyBiz.clue.spend`, `cyBiz.clue.unlockFor`), club (`club.topic.card.chapters`, `club.strip.all`, `clubR3b.notify.sendTo`), publish/me (`templateAuthor.mine.useNum`, `fixr9.ap.tickets.missing`) | Read "1 teams on the route", "1 stops", "Based on 1 reviews", "Used 1 times" … The r1 plural tool skipped every key a `docs/port/strings` fragment spells, so later lanes' count strings never got plural variants | `tools/add_i18n_r1_plurals.py`: a key spelled only in a byte-stable fragment is now converted and the fragment's English entry updated (same rule as the r2 substitutions tool), so a fragment merge keeps the plural. `club.settings.customerCount` stays plain (`String(format:)` call site, host-only). 21 keys converted, 13 fragments updated; `check_locale_format.py` PASS | Done |

| 4 | `pages/topic/index` bottom bar (price left, one primary right; MP order unchanged) → `TopicXcxSections.swift` `TopicXcxActionBar.barContent` | Price ("$12.50 from", "Free") + "Sign up now" / "Play any time" (`minWidth: 132`) in one `HStack` overflow the bar at accessibility sizes in English | `AnyLayout`: `HStackLayout` as before at standard sizes; `VStackLayout(alignment: .leading)` with the price above the primary button at accessibility sizes (spacer only in the row form). Same pattern as `ParticipationParityViews.swift:40` | Done |

### Run 2 (2026-11-27, hourly)

| # | MP page → native view | Problem in English | Fix | Status |
|---|---|---|---|---|
| 5 | `pages/club/*` inline leaderboard row → `ClubDetailR8Mounts.swift:472` | `clubR8.lb.meta` read "1 runs · 3.2 km · time 40 min"; the call site ran `String(format:)`, which drops a plural substitution | Call site now interpolates (`appLocalized("clubR8.lb.meta \(row.clearCount) \(mileageText(row)) \(durationText(row))")`, same key); `runs` added to the r1 plural nouns; r2 tool converted the key + `fix-r8-club.json` fragment. The r1 tool also converted `mp.rank.unattributed %lld` (journey report, interpolated call site): one form hand-fixed to "%lld run lacks a frozen location and isn't counted" | Done |
| 6 | `subpackageMember/components/cy/profile` `pc-actions` (MP: [开始探索][票夹][···]) → `MemberHomeHeader.swift` `actionRow` | Coordinator 16:37 `d2-me` en-US: "Start exploring" wrapped to four lines inside the button at 375 pt | Labels `lineLimit(1)`; `ViewThatFits(in: .horizontal)` keeps the MP row when it fits, otherwise stacks the same buttons vertically (MP order unchanged); accessibility sizes always stack as before. Buttons stay `.borderedProminent` / `.bordered` large | Done |
| 7 | MP badge-wall (`subpackageP3/badge-wall`) fixture → `DesignFixtures/E5bFixtures.swift` `E5bBadgeWallFixture` | Coordinator 16:53 `e5b-badge-wall` zh-Hans: badge names and unlock conditions English | Fixture names/hints go through the fixture's `tt(en, zh)`. The zh date `2026-10-01` is deliberate: MP `displayDate` keeps `YYYY-MM-DD` in Chinese (`LocaleDisplay.civil`, pinned by `LocaleDisplayTests.swift:47`); English reads "Oct 1, 2026". Not changed | Done |
| 8 | `pages/search2/index` 推荐搜索 + 类别 → `GlobalSearchView.swift` (`capsuleLayout`) → shared `TemplateChipFlow` (`TemplateDetailXbChrome.swift:201`) | Coordinator 16:37 `d2-search`: category card renders as one tall narrow pill. The flow layout always placed a chip at its one-line ideal width, so a long English category name ran past the row | `TemplateChipFlow.chipSize`: a chip wider than the row is proposed the row width (wraps inside); zero/unknown widths keep the ideal size. MP order unchanged. Suggested chips (骑行, 外滩 …) are the MP fixed China-market keyword list sent to search (`Core/GlobalSearchRecommendedKeywords.swift`, pinned by `GlobalSearchRecommendedKeywordsTests`); US market shows none, so Chinese in the China-market fixture is correct. Not changed. Needs a simulator look to confirm the tall-pill symptom is gone (mp-home / polish-search own the page) | Done (layout), verify on device |

### Run 3 (2026-11-27, hourly)

Sweep `docs/sweeps/latest` (build 070117595) was taken under build load (coordinator 17:40: ignore); the mp-mine / mp-club en sheets show launch logos only, so this run works from code.

| # | MP page → native view | Problem in English | Fix | Status |
|---|---|---|---|---|
| 9 | `pages/roam/*` roam tools 清除缓存 confirm → `MPGap/PlayRoam/RoamSessionToolsSheetView.swift` | `roamTools.clearCache.confirmMessage` en: "Records already uploaded to **Chengyin** aren't affected" — app brand in English is Chein | en → "…uploaded to Chein…" (catalog + `mp-r3-roam.json` fragment). Catalog-wide scan: no other English value names the app "Chengyin" except the three WeChat mini-program strings in Not done | Done |
| 10 | `pages/topic/index` publisher row (avatar · name · 发布 · owner review chip, wxml 89-91/101) → `TopicXcxSections.swift` `TopicXcxHero` | One `HStack`: "Name posted Under review" runs past the row at accessibility sizes in English | Accessibility sizes: `VStackLayout` with the review chip under the publisher line (same `AnyLayout` pattern as the action bar in this file); "posted" `fixedSize` so the name truncates, not the verb. MP order unchanged | Done |
| 11 | Me tabs (MP `profileTabs` 项目/帖文/成就/关于) → `AccountView.swift:65` | Checked: "Achievements" in a 4-segment picker at 375 pt | Already `cyAdaptiveSegmented()` (segmented when it fits, menu otherwise / at AX sizes). No change | Checked |
| 12 | Ticket wallet detail → `TicketWalletDetailView.swift:378` | Checked: pass expiry is Chinese from Core (`今天过期`, `N 天内过期`) | `CoreLoopCopy.tr` maps both to "Expires today" / "Expires in N day(s)" with plural. No change | Checked |
| 13 | `subpackageRoam` roam-place-card (photo → facts → 导航/分享 row; activity time section) → `NativeR2/MapHome/RoamMapHomePlaceCard.swift` | Activity / search-activity start and end showed raw server text "2026-12-01 10:00:00" in English; the action row (primary · Navigate · View details · Share, caption labels) is one `HStack` that cannot fit four English captions at accessibility sizes | Dates → `LocaleDisplay.civil` (English "Dec 1, 2026 at 10:00 AM"; Chinese keeps the MP text unchanged). Action row → `AnyLayout`: `HStackLayout` as before, `VStackLayout` at accessibility sizes, same buttons and order | Done |
| 14 | Raw server timestamps on player screens: topic reviews (`TopicReviewsContent.swift`), activity reviews (`ActivityReviewsSection.swift`), ticket pass present date (`TicketPassPresentView.swift`), order row fallback date (`ProfileOrdersView.swift` `ProfileOrderRow`), wallet ledger timestamp + withdrawal time (`WalletCommerceViews.swift`), club post time (`ClubPostDiscussion.swift`) | English showed "2026-10-01 14:30:00" as the server sent it | `LocaleDisplay.civil(_, locale:)` (same helper as Growth / badges / club editions): English "Oct 1, 2026 at 2:30 PM"; Chinese and unparsable/relative text unchanged (MP parity). Pins `test_topic_reviews.py` / `test_activity_reviews.py` updated to the new token (reason inline) | Done |

### Run 4 (2026-11-27, hourly)

Sweep `docs/sweeps/latest` en sheets (build 070117595): `mp-mine/sheet-en.jpg` (`en-t5-order-center`), `mp-journey/sheet-en.jpg` (`en-t5-free-explore`), `mp-home/sheet-en.jpg` (`en-rep3-activity-detail`).

| # | MP page → native view | Problem in English | Fix | Status |
|---|---|---|---|---|
| 15 | `subpackageMember/orderinfo` order-center-entry → `OrderCenterEntryView.swift` | `en-t5-order-center`: Created read the raw server text "2026-11-14 10:00" | `LocaleDisplay.civil(created, locale:)` → "Nov 14, 2026 at 10:00 AM"; Chinese unchanged. Status "已支付" and title are server text in the CN-market fixture (doc comment: status shown as sent); not changed | Done |
| 16 | Me 帖文 tab club posts (MP `MM-dd HH:mm` slice) → `AccountPublishR8Mounts.swift` `OwnProfileClubPostsSection` | English showed the MP slice "10-21 10:00" (reads as a range / day-month) | English: `LocaleDisplay.civil(post.createTime)`; Chinese keeps the MP slice (pinned by `AccountPublishMPContractTests`) | Done |
| 17 | `pages/activity/*` detail hero live line → `NativeR2/Explore/ExploreDesignPass.swift` `ExploreStartsInLine` | `en-rep3-activity-detail`: "In progress · Ends in Ended" on an event that ended Nov 21. The explicit `TimelineView` hands back a past entry date, so the line thought the event was running while the inner countdown (real clock) said Ended | The line compares against `max(context.date, Date())`; an ended event shows no live line (as designed). Shared component (Home / Explore cards too) | Done |
| 18 | `pages/play/free-explore` → `FreeExploreBundleLaunchView.swift:60` | `en-t5-free-explore`: "1 chapters ready to book" | English singular "1 chapter ready to book" | Done |
| 19 | City deed card (City tab) → `CityKit/CityDeedCard.swift:446` | "1 points per visit" | English singular form | Done |
| 20 | MP 余额明细 / ledger rows → `WalletCommerceViews.swift` `WalletLedgerView.ledgerRow` | `en-e4-wallet-balance`: money row time read raw "2026-11-06 18:20:00"; delta and code ran together "+58.00CNY" (2 pt gap) | Money rows: `LocaleDisplay.civil` (points rows keep the MP short time); delta/currency gap 4 pt. Chinese text unchanged | Done |

### Run 5 (2026-11-27, hourly)

Sweep `docs/sweeps/latest` build 1300a48db (18:54Z) en sheets: `mp-mine/sheet-en.jpg`, `mp-club/sheet-en.jpg`, `mp-home/sheet-en.jpg`, `mp-journey/sheet-en.jpg`. Search category pill now wraps correctly (row 8 confirmed). Me "Star… / Tick…" truncation (`en-d2-me`) is fixed on `mp/r3-mine` 09a676793 (owner of the 18:15 note); not touched here to avoid a conflict. Wallet ledger raw time in the sheet predates row 20 (not in that build).

| # | MP page → native view | Problem in English | Fix | Status |
|---|---|---|---|---|
| 21 | Club enrollment roster → `ClubEnrollmentView.swift:497` (`en-d4-enroll`) | "My club · 1 groups" | `groups` added to the r1 plural nouns; `u9cde.clubEnroll.subLineMine` plural, `u9cde.clubEnroll.subLine %@ %lld` substitution | Done |
| 22 | Plural tools (`tools/add_i18n_r1_plurals.py`, `add_i18n_r2_substitutions.py`) | r1 counted keys named in receipts/briefs (`docs/**/*.md`) as contract pins and **demoted** existing plurals back to "1 runs/1 teams/1 comments" (5 keys, incl. this lane's run-2 `mp.rank.unattributed`) whenever a receipt mentioned the key; the one-shot `add_u9_cde_localizations.py` seeder also pinned its keys | r1 skips `docs/**/*.md` (same rule r2 already had); seeder listed in `GENERATORS` for both tools. Result: 7 more count strings now plural on player screens: `club.ops.clubLimit.count`, `cooprelation.venue.capacity` ("Up to 1 person"), `d7.checkin.streak.value` ("1 day"), `g6.promo.remain.days`, `orientScore.pendingReview`, `roam.passport.play.routes.count`, `club.settings.topicCount`; fragments `fix-r3-member-b`, `fix-r3-play-roam-a`, `fix-r9-club-a` updated. All call sites interpolate (no `String(format:)`) | Done |
| 23 | MP 票夹 ticket wallet / pass → `TicketWalletView.swift` `TicketWalletRow`, `E1TicketCard.swift:86`, `TicketPassSheet.swift:299`, `RoamEnrolledChaptersView.swift:199` (`en-e4-tickets`) | Participation date raw "2030-04-20" in English | `LocaleDisplay.civil(date, locale:)` → "Apr 20, 2030"; Chinese keeps the MP text (same helper as `TicketPassPresentView`) | Done |
| 24 | Club channel chat (`en-d4-channel-chat`) → `Core/ChannelDiscordMessaging.swift` `formatDivider(.date)`; channel message search day headers → `NativeChannelMessageSearchView.swift` | Divider + sender time read "11-07 09:00" (MP `MM-dd HH:mm` slice; reads as a range in English); search headers raw "2026-11-07" | English → "Nov 7, 09:00" (locale short month symbols); Chinese unchanged `11-07 09:00` (test added in `ChannelDiscordMessagingTests.testPlaceholdersAndTierTitlesFollowLocale`). Search headers → `LocaleDisplay.civil` | Done |
| 25 | Onboarding (`en-onboarding-1`) → `DesignSystem/CYOnboarding.swift` top bar, `CYOnboardingLight.swift` `OBWordmarkBloom` (disc wordmark); login logo label `LoginView.swift:271`; MP about (`about/index.wxml:24`) → `SettingsAboutView.swift` `appName` | English UI showed the brand as "城瘾" (top-left and on the disc) while the next page says "Welcome to Chein"; About title and the login logo's VoiceOver label also "城瘾" | English → "Chein" (owner brand, `CFBundleDisplayName`), Chinese keeps 城瘾. Wordmark stays the drawn logo (baseline note updated to "城瘾 / Chein"). No section/navigation change | Done |
| 26 | MP `pages/im/list` (name + one-line preview, time right) → `IMInboxViews.swift` conversation row (`en-d2-inbox`) | "Open conversation to view messages" wrapped to 2-3 lines in every row and "Fixture conversation 3" wrapped under the Official chip | Compact sizes: name `lineLimit(1)`, preview `lineLimit(1)` (2 at accessibility sizes); the large-type branch keeps its wrapping name. MP order unchanged | Done |
| 27 | `pages/topic/index` route stop address → `TopicXcxSections.swift:649` | Checked: address truncating at AX sizes | Already 3 lines at accessibility sizes (a11y-dt r3). No change | Checked |
| 28 | `subpackageMember/orderinfo` amount → `OrderCenterEntryView.swift:78` | Checked: "Amount 168.00" has no currency sign in English | The order-center contract sends a bare decimal (`OrderCenterDetailService.swift:83`, no currency field); adding ¥/$ would guess the market. No change | Checked |
| 29 | Square post age (`en-d2-square`) → `SquareXcxPostCard.swift:112` | Checked: "330 d ago" | Same compact family as "h ago" / "min ago" (MP `N天前`); reads correctly. No change | Checked |

### Run 6 (2026-11-27, hourly)

Merged `origin/ui/combined-r7` (conflicts: `LoginView.swift` took the single-mark logo from mp-nav and kept this lane's "Chein" VoiceOver label; `IMInboxViews.swift` took upstream, which already keeps name/preview to one line in English). Sweep build 3568fe51b (19:36Z) en sheets: mp-home, mp-activity, mp-club, mp-mine, mp-journey.

| # | MP page → native view | Problem in English | Fix | Status |
|---|---|---|---|---|
| 30 | `pages/search2/index` 推荐搜索 → fixtures `D2Fixtures.swift` (`d2-search-results`, offline), `SearchMapFixtureSupport.swift` (`d2-search`) | Coordinator 19:50 `en-d2-search`: suggestion chips 骑行 / 城市 / 外滩 … in the English UI | Fixture-only `SearchMapFixtureKeywords.list`: zh-Hans keeps the MP China-market list, English shows the same terms in English ("Cycling", "The Bund", "Suzhou Creek" …). Real app unchanged (`GlobalSearchRecommendedKeywords.keywords(for: market)`, US shows none) | Done |
| 31 | `subpackageMember/orderinfo` → `T5OrderCenterTransport` fixture (`en-t5-order-center`) | Order "杭州老城畅玩卡", status "已支付", error "订单不存在" in English | Fixture payload follows the UI language ("Hangzhou Old Town Play Pass", "Paid", "Order not found"); zh-Hans unchanged | Done |
| 32 | `subpackagePass` pass market (`en-t5-pass-market`) | Pass names / city Chinese in English | Already done on `mp/r3-activity` (`tt(en, zh)` in `T5PageFixtures`); not duplicated here to avoid a conflict | Checked |
| 33 | Ticket wallet date (`en-e4-tickets` "2030-04-20"), channel divider (`en-d4-channel-chat` "11-07 09:00"), enrollment "1 groups" (`en-d4-enroll`) | Still visible in build 3568fe51b | Fixed in rows 21/23/24 on this branch (not yet in that build) | Waiting for integration |
| 34 | `subpackagePass` pass market product row → `PassMarketViews.swift:485` `PassProductCardView` | Checked: "Includes 3 works · 2 people" + "¥168.00 / 1,200 points" at AX sizes | Already `ViewThatFits`: row form when it fits, stacked otherwise. No change | Checked |
| 35 | Wallet ledger row → `WalletCommerceViews.swift:706` (`en-e4-wallet-balance`) | Checked: "Weekend city walk share" wraps to 2 lines next to "+58.00 CNY" | The title wraps and the amount stays whole (stacked layout at AX sizes); correct list behaviour. No change | Checked |
| 36 | Club enrollment roster topic row (`en-d4-enroll`) | Checked: "Date to be set · 8 registered" | Fits on one line at 375 pt in the sweep. No change | Checked |

### Run 7 (2026-11-27, hourly)

Merged `origin/ui/combined-r7` (conflict `LoginView.swift`: kept the "Chein" VoiceOver label and restored the `locale` environment the upstream side dropped). Sweep build a250afd77 (20:11Z) en sheets: rows 21 ("My club · 1 group", `en-d4-enroll`) and 24 ("Nov 7, 09:00", `en-d4-channel-chat`) confirmed; rows 30/31 (search chips, order center) not in that build yet (branch not integrated).

| # | MP page → native view | Problem in English | Fix | Status |
|---|---|---|---|---|
| 37 | Remaining raw server timestamps on player screens: bundle reviews (`BundleReviewListView.swift`), club feed post (`ClubGovernanceFeedPostView.swift`), club roster "Joined …" (`ClubPublicRosterView.swift`), club join requests "Requested …" (`ClubManagementView.swift`, 2 rows), coupon used time (`CouponCodeView.swift`), free-explore story archive "Visited …" (`FreeExplorationViews.swift`, `NativeR2/FreeExplore/NativeFreeExploreMapView.swift`) | English showed "2026-10-02 12:00:00" as the server sent it | `LocaleDisplay.civil(_, locale:)` (same helper as rows 14/23): English "Oct 2, 2026 at 12:00 PM"; Chinese and unparsable text unchanged (MP parity). Text only, no layout/order change | Done |

### Run 8 (2026-11-27, hourly)

Merged `origin/ui/combined-r7` (clean). Sweep build bb76e327c (20:45Z) en sheets: roam, home, mine, club, journey. Row 30 confirmed (search chips English in `en-d2-search`), row 31 confirmed (`en-t5-order-center`), rows 21/24 still good. Roam en (`en-d2-roam`, `en-d6-roam`, `en-e2-stamp-album`, `en-e5b-stamp`): no English layout problem.

| # | MP page → native view | Problem in English | Fix | Status |
|---|---|---|---|---|
| 38 | `subpackagePass` free-explore pass catalog store row → `FreeExploreBundleLaunchView.swift:198`; native bundle detail store row → `NativeR2/FreeExplore/NativeFreeExploreBundleDetailView.swift:131`; swap-merchant targets → `BundleExitSwapView.swift:92` | `en-t5-free-explore`: store validity read raw "2026-12-31" | `LocaleDisplay.civil(_, locale:)` → "Dec 31, 2026"; Chinese keeps the MP text. Text only, no order/layout change. `BundleMerchantStallView` is not mounted (doc comment); not touched | Done |
| 39 | `pages/topic/index` 场次 session chip (`周X M.D HH:mm`) → `TopicXcxSections.swift` `TopicXcxSessionChip` (topic detail activity rows, `TopicDetailView.swift:476`) | English read "Sat 12.6 14:00" (M.D reads as a decimal, 24 h clock) | English: one locale-formatted string "Sat, Dec 6 · 2:00 PM" (China wall time, time omitted at 00:00 as the MP does). Chinese keeps the MP three-part text; Core `sessionChip` and its tests unchanged | Done |
| 40 | `pages/publish/*` activity publish wizard draft chip ("Saved · HH:mm") → `PublishingModesViews.swift` `draftTimestampNow` → `ActivityPublishingWizardView.swift:117` | English showed a 24 h "19:30" | English: locale short time "7:30 PM"; Chinese keeps the MP `HH:mm` | Done |

### Run 9 (2026-11-27, hourly)

Merged `origin/ui/combined-r7` (clean). Sweep build 405948d58 (21:09Z) en sheets: mine, journey, activity, home, club. Confirmed: search Categories pill now wraps correctly and suggestions are English (`en-d2-search`, row 8/30). Rows 23, 37–40 not yet in that build (free-explore store date still "2026-12-31" in `en-t5-free-explore`). No coordinator finding for en-layout since 16:53 that is still open.

| # | MP page → native view | Problem in English | Fix | Status |
|---|---|---|---|---|
| 41 | `pages/club/*` club detail Posts tab, MP `cy-post-card` action bar (赞 / 评论 / 转发 / 分享) → `ClubCommunityViews.swift` `tileActions` (`en-d4-tab-posts`) | Row read "Like / Com… / Re… / Shar…" (wrapped and truncated) at 375 pt | `ViewThatFits(in: .horizontal)`: the MP row as before when it fits; the same row with tighter spacing; else icon-only labels (each button keeps its explicit VoiceOver label + value). Same four actions, MP order; accessibility sizes still stack | Done, verify in next sweep |
| 42 | `pages/play/*` settle wrap-up (`本关第 N 名`) → `mp.settle.rank %lld` (`en-t5-settle`) | "This level: No. 3" | en → "Ranked #3 on this level"; zh unchanged | Done |
| 43 | `subpackagePass` pass market points balance → `PassMarketViews.swift` `balanceRow` (`en-t5-pass-market`) | Hero "1280" next to rows "1,200 points" | `Text(balance, format: .number)` (locale grouping: "1,280"; zh "1,280" as the system formats) | Done |
| 44 | Me balance (`en-d2-me`) "CN¥0.00" vs balance ledger (`en-e4-wallet-balance`) "¥128.50" | Two CNY spellings in English | Checked: Me follows the i18n r1 rule (non-Chinese UI names the currency, `E1Money.yuan`); the ledger draws a single glyph beside the number (`WalletCurrencySymbol`, `count == 1` checks at `WalletCommerceViews.swift:668`, `WalletNumberLocalization.swift:49`), so switching it needs a wallet layout change. Not changed; listed for mp-mine | Checked |
| 45 | `pages/playkit/*` reaction game result → `NativeR2/Games/NativeGameTimedKit.swift:306` `playkit.reaction.bestOf %lld` | Merged from mp-journey without plural: "Fastest of 1 rounds"; `check_locale_format.py` FAILED after the merge | `tools/add_i18n_r1_plurals.py`: catalog + `mp-journey-r3.json` fragment ("Fastest of 1 round"); gate PASS | Done |

### Run 10 (2026-11-27, hourly)

Merged `origin/ui/combined-r7` (clean). Sweep is still build 405948d58 (same as run 9), so this run works from code: remaining raw server dates on player screens.

| # | MP page → native view | Problem in English | Fix | Status |
|---|---|---|---|---|
| 46 | Me 关于 tab join date → `MemberHomeHeader.swift` `MemberAboutSection`; public profile About → `SocialPublicProfileView.swift:297`; Me 项目 project start → `ProfileSelfProjectsSection.swift`; withdrawal history row + detail → `WithdrawalHistoryView.swift`; pass market order rows + pass order paid time → `PassMarketViews.swift` (`PassMarketView`, `PassOrderDetailView`); roam stamp detail date → `RoamStampViews.swift` `RoamStampCard`; stamp capture left-at → `NativeR2/FreeExplore/NativeStampCaptureView.swift`; monthly recap occurred-at → `RoamMonthlyRecapDetailView.swift` | English showed raw server text "2026-10-01 14:30:00" / "2026-10-01" | `LocaleDisplay.civil(_, locale:)` (same helper as rows 14/23/37): English "Oct 1, 2026 at 2:30 PM"; Chinese and unparsable text unchanged (MP parity). Text only, no layout/order change | Done |

### Run 11 (2026-11-27, half-hourly)

Merged `origin/ui/combined-r7` (clean). Sweep build 8fa84e4d3 (22:11Z) en: `mp-club/en-d4-tab-posts.jpg` shows the post action bar as one icon row at 375 pt (row 41 confirmed); `en-d4-enroll` "1 group", `en-d4-channel-chat` "Nov 7, 09:00", `en-d4-members` "Joined Feb 3" good.

| # | MP page → native view | Problem in English | Fix | Status |
|---|---|---|---|---|
| 47 | `pages/club/*` feed repost line → `ClubCommunityViews.swift` `ClubCommunityFeedView` (repost time); club calendar sessions (start / end / updated) → `ClubCalendarSessionRows.swift` `ClubCalendarSessionsView` | English showed raw server text "2026-10-01 14:30:00" | `LocaleDisplay.civil(_, locale:)` (same helper as rows 14/23/37/46); Chinese unchanged. Text only | Done |
| 48 | `SupportTicketReadView`, `CityTaskHistoryView` | Checked: raw timestamps next to raw ids / enum values (`sender_type`, `event_type`, board/season ids) | Diagnostic/record surfaces with ISO instants, not MP player pages; left as sent. No change | Checked |
| 49 | `pages/template/*` 我的节点玩法 → `TemplateAuthoringMineView.swift` (cover use count, shelf state rows) | Checked: "Used 1 time" plural, shelf states via `LabeledContent` (value wraps under long English labels); market state copy is pinned by `test_template_shelf_state_projection.py` | No change |  Checked |

### Run 12 (2026-11-27, hourly)

Merged `origin/ui/combined-r7` (clean). Sweep still build 8fa84e4d3 (22:11Z). Looked at `mp-nav/sheet-en.jpg` (inbox, tabs, login, onboarding, welcome: no English layout problem) and `mp-activity/sheet-en.jpg`. Catalog scan: no English value contains CJK, no CJK key without an English value (merchant excluded).

| # | MP page → native view | Problem in English | Fix | Status |
|---|---|---|---|---|
| 50 | `pages/activity/baoming` 选择参与人信息 half-screen + 选择票种 links → `RegistrationSheetView.swift:729`, `:828` (`en-t5-baoming`) | Link labels read "Select participant sheet" / "Choose ticket sheet" (internal wording) | en → "Choose participant details" / "Choose a ticket" (MP titles); zh unchanged. Fixture names ("Offline fixture activity", "Standard fixture ticket") and the ticket price "—" are mp-activity's (coordinator 22:20) | Done |
| 51 | Workshop creator consent / pending (`WorkshopCreatorConsentView`, `WorkshopCreatorPendingView`) | Checked: `declaredAt` / `expiresAt` raw next to version ids and hashes | Record surfaces with ISO instants (same as row 48); left as sent | Checked |

## Not done

| Item | Why |
|---|---|
| `payoutReceiver.bind.mpOnly`, `payoutReceiver.bind.mpPathCopied`, `authEntry.deregister.wechatUnavailable` say "the Chengyin (WeChat) mini program" in English | These name the WeChat mini program, which is searched by its Chinese name; owner to decide whether English shows "Chein", "城瘾" or both. Not changed. |


## Next pages (no row yet)
Re-check rows 23, 37–41, 46 in the next sweep. Then the rest of publish (`pages/publish/*`, `pages/templatedetail/*`, no en sheet in the sweep yet: work from code) and nav English sheets.

## For other lanes
- mp-mine: balance ledger shows "¥" while the Me balance tile shows "CN¥" in English (row 44); public profile role line "— City explorer" shows a dash placeholder (`en-e4-member`).
- mp-journey: `en-d2-play` nav shows debug "Switch synthetic account"; t5-free-explore "DEBUG fixture" banner still visible.
- mp-activity: Square fixture post text "A synthetic city walk / 一次示例城市漫步" (`Core/SquareSyntheticFixtures.swift`, shared with Core tests) shows Chinese in English (`en-d2-square`).
- mp-journey: 19:15 items still visible in `en-*` journey shots (灯笼石门, 西湖夜游漫步, 老城茶街章节, free-explore "—" rows).
- mp-journey / mp-nav: City root entry reads "CITY ownership and original receipts" (`cityAcquire.entry`, all-caps CITY also in zh) — confirm CITY is the intended product name.
- `Tests/ContractChecks/check_wallet_earnings_overview.py` fails (2) on `ui/combined-r7` before any en-layout change (debt-r3).

## Gates
See the commit message of each push (generate_project, check_scaffold, a11y lint, contract ratchet new 0, design consistency PASS, locale format PASS).

### Pins updated (run 3)
- `Tests/ContractChecks/test_topic_reviews.py`, `test_activity_reviews.py`: review date token is now `Text(verbatim: LocaleDisplay.civil(date, locale: locale))`. Reason: English date format; plain-text rule unchanged.

### Pins updated (run 1)
- `Tests/ContractChecks/test_play_gameplay_mode_separation.py:69` and `test_play_experience_contracts.py:110`: read the English plural `other` form when a `playFree.*` / `playx.*` key carries plural variations (`playFree.meta.stores`, `playx.board.score`). Reason: count strings now vary by plural; the bilingual check itself is unchanged.
