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

### Run 13 (2026-11-27, half-hourly)

Merged `origin/ui/combined-r7` (one conflict in `RegistrationSheetView.swift`: took the base's restyled participant/ticket links, "Choose a saved participant…" / "Choose a ticket…", fine in English). Sweep build b3b03703a (23:07Z): looked at `mp-mine/sheet-en.jpg`, `mp-home/sheet-en.jpg`, `mp-club/sheet-en.jpg`.

| # | MP page → native view | Problem in English | Fix | Status |
|---|---|---|---|---|
| 52 | `pages/index/index` 编辑精选 subtitle → `HomeFeedView.swift:195` (`en-d2-home`) | "Editor's picks · entry conditions are on each detail page" repeats the heading right above it and reads as a translation | en → "Picked by our editors · see each page for entry requirements"; zh unchanged | Done |
| 53 | Club channel chat (MP `im/chat` `decorate` divider + burst header) → `Core/ChannelDiscordMessaging.swift` `formatDivider` (`en-d4-channel-chat`) | "Nov 7, 09:00" / "Today 08:30": 24-hour MP clock in US English | English (non-Chinese) clock via the locale hour cycle (`localeClock`, template `jmm`) → "Nov 7, 9:00 AM"; zh keeps MP `MM-dd HH:mm`. Pin `ChannelDiscordMessagingTests.swift:585/587` updated (reason: locale hour cycle) | Done |
| 54 | Club events / series occurrences / correction window / managed projects / invoice time → `Core/ClubOpsEventPresentation.swift:54,61`, `ClubActivityListContent.swift:135`, `ClubManagedProjectsSection.swift:42`, `InvoiceLaunchPresentation.swift:286` | Date templates used `HHmm`, which forces 24-hour time in English | Templates `HHmm` → `jmm` (locale hour cycle; zh-Hans still 24-hour). Pin `ClubOpsEventPresentationTests.swift:42` updated | Done |
| 55 | Me / balance ledger / order lookup / badge wall (`en-d2-me`, `en-e4-wallet-balance`, `en-t5-order-center`, `en-e5b-badge-wall`) | Checked: CN¥ vs ¥ is row 44; badge "First Stamp" grey with "Unlocked" is fixture art (data says unlocked); Search "Example content" is the fixture notice (same in zh) | No change | Checked |

### Run 14 (2026-11-28, hourly)

Merged `origin/ui/combined-r7` (clean, 793c3190b). No newer sweep than 23:37Z; worked from code on strings this merge added and on `pages/publish/*`.

| # | MP page → native view | Problem in English | Fix | Status |
|---|---|---|---|---|
| 56 | `pages/publish/fabu/topic-detail-sheet.wxml:144-185` 玩法规则 → `MPGap/AccountPublish/ProjectEditThemeRulesSection.swift` | 同场路线 read "Shared routes in a session" while play (`playerGap.trail.title`) says "Shared routes"; refusal footer named the toggle without quotes and used straight apostrophes | en → "Shared routes"; "Team play can’t be replayed alone. Turn off “Allow playing again.”" (catalog + `mp-r3-publish.json`); zh unchanged | Done |
| 57 | `pages/play/*` compass / shout kits → `NativeR2/Games/NativeGameSensorKit.swift:192,226`; music corner → `NativeR2/Games/ChoiceKits.swift:125` | "Aligned. Hold for 2 s more", "Keep it loud for 3 s in a row" (bare "s" after a number); "Healing music corner" (literal 治愈) | en → "Aligned. Hold steady for %@ more sec", "Stay loud for %@ sec straight", "Relaxing music corner" (catalog + `mp-journey-r3.json`) | Done |
| 58 | `pages/publish/*` quick publish / modes → `PublishingModesViews.swift` (`publishModes.quick.loadFailed`, `.readFailed`); 九宫格 completion → `ProjectEditView` (`projectEdit.completion.serverConditions`); publisher pricing → `publisherPricing.marginNote` | Read as translations: "The draft allowance didn't load. The network isn't connected. Try again.", "Edit the nine cells in S order", "Whatever the final price exceeds the cost floor by is…" | en → "Couldn’t load your draft allowance. Check your connection and try again." / "Couldn’t load the list. …" / "Edit the nine cells along an S-shaped path. Cell labels don’t change when a cell lights up." / "Anything the final price adds above the cost floor is the organizer’s gross margin. …"; zh unchanged | Done |

### Run 15 (2026-11-28, half-hourly)

Merged `origin/ui/combined-r7` (clean, 283dd3b52). Sweep 00:10Z has no en-layout sheet in my area beyond rows already done; worked from code on `pages/templatedetail/*` and `pages/publishkit/*`.

| # | MP page → native view | Problem in English | Fix | Status |
|---|---|---|---|---|
| 59 | `pages/templatedetail/templatedetail.wxml` → `DiscoveryTemplateDetailView.swift`, `DiscoveryTemplateDetailParitySections.swift`, `TopicTemplateUseSection.swift` (MP sections unchanged) | 主题模板 was "route template" in 7 strings and "topic template" in 4 (share, loading, open-failed, list-failed); notice "can’t start a group directly"; "Adoption conditions", "Categories and settings" (reads as app Settings); "This play could not be opened" | All → "route template" (`u10.template.shareTopic`, `discovery.topicsFailed`, `.topicTemplate.openFailed`, `.topicPreview.loading`); "This is a play template — you can’t host a session from it directly"; "Requirements to use"; "Categories and use cases"; "Couldn’t open this play" (catalog + `tools/add_u10_screens_localizations.py`); zh unchanged | Done |
| 60 | `pages/publishkit/index` → `TemplateAuthoringView.swift` | 玩法 was "play" in the create title but "gameplay"/"game" in edit title, save, advanced, preview; "Additional configuration families" | en → "Edit play template", "Save play", "Advanced play settings", "Preview this play", "You can try this play on the route.", "More modules" (catalog + `fix-r9-account-publish.json`); zh unchanged | Done |

### Run 16 (2026-11-28, hourly)

Merged `origin/ui/combined-r7` (clean, f8574edab). Sweep f8574edab (00:37Z): looked at `mp-roam`, `mp-nav`, `mp-journey`, `mp-mine`, `mp-club`, `mp-home` `sheet-en.jpg` and `mp-club/en-d4-detail.jpg`; no new English text/wrap problem in my area (row 41 action bar now fits in `en-d4-tab-posts`). Worked from code on `pages/publishkit/components/*` and player error copy.

| # | MP page → native view | Problem in English | Fix | Status |
|---|---|---|---|---|
| 61 | `pages/publishkit/components/look-preview` + 画面风格 panel → `MPGap/AccountPublish/AccountPublishR8Mounts.swift` `ProjectEditLook` (MP sections unchanged) | British "Theme colours" / "Use each chapter's colours" in the US build; font picker read "Song" / "Kai" / "Hei" (Chinese typeface pinyin, meaningless in English) | en → "Theme colors", "Use each chapter’s colors", "Serif", "Calligraphic", "Sans serif" (catalog + `fix-r8-account-publish.json`); zh unchanged | Done |
| 62 | `pages/publishkit/components/chapter-gate` + node player preview → `ConfigR4.xcstrings` `config.preview.*` | 玩法 read "gameplay" ("This gameplay has no story", "Untitled gameplay") while row 60 settled on "play"; "See failure / See success" buttons | en → "This play has no story", "Untitled play", "Show failure", "Show success"; chapter-gate (`chapterFlip.*`: "Chapter 1 of 3", "Prologue", "Tap to continue") checked, fine | Done |
| 63 | Play arrival / recovery (MP `pages/play/*` arrive errors) → `PlayRecovery.xcstrings`, `Core/BackendErrorCatalog.swift` (`ARRIVE_COORD_NOT_CONFIGURED`, `CONFIG_INVALID`); club create join-review switch → `DesignR1Club.xcstrings` | British "organiser" in 7 player-facing strings (US launch; row 58 and the rest of the catalog use "organizer") | en → "organizer" (catalog + `tools/backend_error_catalog.py --write` regenerated Swift/catalog/`docs/release/cb50-errors.md`, `tools/build_design_r1_localizations.py`); pin `BackendErrorCatalogTests.swift:55,67` updated (reason: US spelling). Merchant catalogs left (out of scope) | Done |
| 64 | `pages/roam/*` live cards team chip → `RoamLiveCardsStrip.swift:100` (`roam.live.cards.teamPeople`, arrived with this merge) | "1/1 people"; `check_locale_format.py` failed on the merged base (plural substitutions) | `tools/add_i18n_r2_substitutions.py` → en "%1$lld/%#@person@" ("1/1 person", "3/5 people"; catalog + `mp-r3-roam.json`); zh unchanged. Locale format PASS | Done |
| 65 | `pages/topic/components/cy/pass-reveal` 通行证已到账 → `TopicPurchaseRevealMount.swift:25` (`topicReveal.duration*`) | "Playable until 12/31 · Days left: 1" (form-label wording, no plural); "(when the topic ends)" in parentheses mid-line | en → "Playable until %1$lld/%2$lld · %#@day@ left" / "…, when the topic ends · …" ("1 day left", "5 days left") via `tools/add_i18n_r2_substitutions.py` (catalog + `i18n-r3-strings.json`); zh unchanged. `topicReveal.days %@` tile ("%@ days", String arg) left: needs an Int in the model to pluralize — not a strings-only change | Done |

### Run 17 (2026-11-28, half-hourly)

Merged `origin/ui/combined-r7` (clean, 907570051). Sweep 907570051 (01:10Z): looked at `mp-mine`, `mp-club`, `mp-home`, `mp-activity` `sheet-en.jpg`. No coordinator finding for en-layout open.

| # | MP page → native view | Problem in English | Fix | Status |
|---|---|---|---|---|
| 66 | `pages/club/detail` overview (declined non-member) → `ClubDetailView.swift` (`club.detail.members.lockedReview`, `.leaderboard.lockedReview`, `.joinPolicy.review`); screenshot `mp-club/en-d4-detail.jpg` | "Approved members can see the members" (repeats "members"), "Get approved to see the contribution board"; header meta "Approval to join" wraps to a second line after "· 3 members ·" | en → "Member list unlocks once you’re approved", "Contribution board unlocks once you’re approved", "Approval required" (catalog + `fix-r3-club-a.json`, `ui-strings-pages-club-detail-index.json`); zh unchanged; `club.ops.joinReview` (switch label) left | Done |
| 67 | `pages/activity/baoming` bottom button → `RegistrationSheetView.swift:605`; screenshot `mp-activity/en-t5-baoming.jpg` | Disabled button "Tick the sharing consent first": British "tick", and the control above it is a switch | en → "Turn on sharing consent first"; zh unchanged | Done |
| 68 | `subpackagePass/*` pass market cards + detail → `PassMarketViews.swift` (`mp.pass.cover %lld`, `mp.pass.coverSeats`, `mp.pass.detail.topics`); screenshot `mp-activity/en-t5-pass-market.jpg` | 作品 literal "works": "Includes 3 works · 2 people" (truncated), "Includes 1 work", "Playable works" | en → "Covers 3 plays · 2 people", "Covers 1 play", "Included plays" (plural variants kept); zh unchanged | Done |
| 69 | Login consent gate (`authEntry.gate.checkRequired`), play prep checklist | British "Tick the box to continue.", "Tick every prep item to start" | en → "Check the box to continue." (`tools/build_auth_entry_catalog.py` regenerated = same), "Check off every prep item to start" (catalog + `fix-r3-player-content-a.json`). Merchant "Tick every item on the checklist first" left (out of scope) | Done |
| 70 | `pages/topic/detail` hero / 包含内容 / route foot → `TopicXcxSections.swift:114,719,786` (MP sections unchanged) | "1 chapters", "1 stops", "1 games" (no plural; "games" vs the settled term "play"); club host line "Riverside Club \| Host club"; cover hint "Scroll down for games…" | Plural variants for `topicXcx.include.chapters/stops/plays`, `topicXcx.moreMerchants`; en → "%lld plays", "Hosted by %@", "Scroll down for plays, sessions and sign-up" (catalog + `docs/parity/w2-07-localizations.json`; the four plural keys leave that source because `build_w2_07_localizations.py` writes flat strings only — catalog now owns them); zh unchanged | Done |

### Run 18 (2026-11-28, hourly)

Merged `origin/ui/combined-r7` (clean). No new en-layout coordinator finding (latest sweep 01:50Z is activity zh / roam en). Worked from code on `pages/topic/components/cy/session-picker` and `self-play-checkout`.

| # | MP page → native view | Problem in English | Fix | Status |
|---|---|---|---|---|
| 71 | `pages/topic/components/cy/session-picker` (日期 → 票种, MP order unchanged) → `TopicSessionSelectionView.swift` | Session and ticket Start / End rows showed the raw server text "2026-12-01 10:00:00" | `LocaleDisplay.civil(_, locale:)` on all four rows → "Dec 1, 2026 at 10:00 AM"; Chinese keeps the MP text. `ticketDependency` copy is pinned by `test_topic_session_selection.py` ("ticket-to-activity"); left | Done |
| 72 | `pages/topic/components/cy/self-play-checkout` 通行证覆盖本主题 → `MPPassEntries.swift` (`mp.pass.checkout.covered`) | "Your pass covers this theme · this order is ¥0": 主题 is "topic" on every other player screen (204 vs 56 strings) and the clause reads as a translation | en → "Your pass covers this topic · ¥0 for this order"; zh unchanged. Other checkout strings (Breakdown / Single purchase / Total, `contextSelfPlay.*`) checked, fine | Done |
| 73 | `pages/topic/components/cy/date-range-sheet` (开始/结束 · 清除/确定) → `SearchMapFilterSheet.swift` (`mapDatePicker.*`) | Checked: "Choose start date" / "Choose end date", "The start date must be on or before the end date.", Confirm; Day / Month / Year labels | English reads well; no change. The MP 共 N 天 / N 晚 summary badge is not in the native sheet → For other lanes (mp-home owns search/map filters) | Checked |

### Run 19 (2026-11-28, half-hourly)

Merged `origin/ui/combined-r7` (clean). No new en-layout coordinator finding (latest sweep 02:20Z: journey zh / nav en, no findings). Worked from code on `pages/topic/components/cy/theme-records`.

| # | MP page → native view | Problem in English | Fix | Status |
|---|---|---|---|---|
| 74 | `pages/topic/components/cy/theme-records` 我的游玩记录 (rows: result title · scene · summary · ended date / 游玩中; empty / loading / error / 查看更多; result card sections; MP order unchanged) → `TopicThemeRecordsView.swift` | Row date showed the raw server `endedAt` text; 游玩中 read "In play" | Row date via `LocaleDisplay.civil(_, locale:)` ("Dec 1, 2026 at 10:00 AM"; zh keeps the MP text, unparsable text unchanged); `topicXcx.records.playing` en → "In progress" (catalog + `w2-07-localizations.json`). Other record/card strings checked (Run completed / Run ended / Endings found / Next scene / Play again / View run report), fine | Done |
| 75 | Wallet money symbol (gate) → `WalletCommerceViews.swift:1290` | After merging `ui/combined-r7`, `check_locale_format.py` FAILED (yuan 2 > 1): ds-consistency's `symbol(_:locale:)` compared `base == "¥"` | Same meaning without the literal: `base == symbol("CNY")`. Gate PASS | Done |
| 76 | `pages/topic/index` route map / 站点进度 / 附近队伍 / 参与商家 (MP order unchanged) → `MPGap/PlayerContent/TopicRouteMapAndTeamsSection.swift:48,85,88,111`, `TopicDetailView.swift:397`; pass bundle catalog `bundle.catalog.merchants` | Section headers in Title Case and "Merchants" while the same page says "Participating shops" (`topic.merchants`) and every other header is sentence case | en → "Stop progress", "Nearby teams", "View all teams", "Participating shops" (catalog + `gap-g1-player.json`); zh unchanged. Checked topic components `route-progress`, `merchant-cards`, `theme-badge`: no native counterpart strings (通关进度 / 到店礼 / 主题徽章) → For other lanes | Done |
| 77 | `pages/topic/components/cy/story-fan`, `route-sketch`, `npc-avatar` → topic preview cards (`topicPreview.tapToFlip`) | Checked: "Tap to flip" reads well. `route-sketch` 点开看真实地图 and `npc-avatar` 角色 have no native strings (the native route uses a real `Map` directly) | No change | Checked |

### Run 20 (2026-11-28, hourly)

Merged `origin/ui/combined-r7` (clean). Latest sweep is still 41374363f (02:10Z), no en-layout finding. Worked from code on `pages/publish/template-intro`.

| # | MP page → native view | Problem in English | Fix | Status |
|---|---|---|---|---|
| 78 | `pages/publish/template-intro/index.wxml` (精选示例 field → loading / error + 重试 → claim copy → 开始创建; MP order unchanged) → `TemplateAuthoringIntroExperience.swift:138-173` | Error "Featured examples could not be loaded." (passive, full stop on a label), retry "Retry examples", loading without the ellipsis the other 101 loading labels use; claim "Turn a stretch you have played" reads as a translation | en → "Couldn’t load featured examples", "Try again", "Loading featured examples…", "Turn a route you’ve explored / into a play others can follow" (`Localizable` + `CreatorIntroExamples` catalogs, `tools/build_publish_parity_localizations.py`, `ui-strings-pages-publish-template-intro-index.json`); zh unchanged | Done |
| 79 | `pages/publish/activity/index.wxml` 发布前摘要 / 发起人信息未加载 (MP order unchanged) → `Core/ActivityPublishingWizard.swift:109`, `fixr8.activity.organizerFailed` | "Summary before publishing" (literal), "Organizer details didn't load" (straight apostrophe, passive) | en → "Review before publishing", "Couldn’t load organizer details" (Swift `W8Text.t`, catalog, `ui-strings-pages-publish-activity-index.json`, `fix-r8-account-publish.json`); other activity-publish strings checked (edit-visibility note, Add ticket option), fine | Done |
| 80 | `pages/publish/components/start-prep` 开局前准备 (准备项 list → 添加准备项 → 建议) → `CreatorEditorUI.xcstrings` `creatorEditor.prep*`, play `play.prep.startHint` | Checked: "Before you start", "Add a prep item", "Check off every prep item to start" read well | No change | Checked |

### Run 21 (2026-11-28, half-hourly)

Merged `origin/ui/combined-r7` (up to date). Latest sweep ad55acd94 (03:04Z, home zh / club zh, no findings); looked at `mp-club/sheet-en.jpg` and `mp-home/sheet-en.jpg` from that build.

| # | MP page → native view | Problem in English | Fix | Status |
|---|---|---|---|---|
| 81 | `pages/talent/list` 发现俱乐部 rows (name · 成员数 · 简介 · 申请加入; MP order unchanged) → `ClubDirectoryView.swift:154` (`en-d4-directory`) | "3 members · Offline sa…": the member count + description line cut off after two words beside the Apply to join button | Discover rows allow 2 lines for the secondary line (your clubs stay 1); no type shrink | Done |
| 82 | `pages/index/index` hero action banners → `Core/HomeSearchTabParity.swift:79-81` (`en-d2-home`) | Title Case "Join Activities with Friends", "Become a Club" (reads as becoming a club), "Become a Merchant" | en → "Join activities with friends", "Become a club host" (same as the Settings row), "Become a merchant"; zh unchanged; `HomeSearchTabParityTests` pin updated | Done |
| 83 | `pages/index/index` greeting city picker (未定位 → 选择城市) → `Core/HomeSearchTabParity.swift:405`, `App/HomeSearchTabParityViews.swift:231` | "Select City" in Title Case while every other picker label is sentence case | en → "Select city" (reverse map keeps both spellings → 选择城市); test pin updated | Done |

### Run 22 (2026-11-28, hourly)

Merged `origin/ui/combined-r7` (clean). Not done row unchanged (owner decision). Worked `pages/publish/fabu/zero-hp-editor` and the same jargon on other player screens.

| # | MP page → native view | Problem in English | Fix | Status |
|---|---|---|---|---|
| 84 | `pages/publish/fabu/zero-hp-editor.wxml` 归零时对玩家说 (MP order unchanged) → `NativeZeroHPAuthorView.swift` / `NativeZeroHPAuthorPresentation.swift` (`zeroHP.copy.026`, `.065`) | Field label "Reply (up to 2,000 UTF-16 units)" and error "must not exceed 2,000 UTF-16 units": engineering jargon on a creator screen | en → "Reply (up to 2,000 characters)", "Keep the reply to 2,000 characters or fewer."; zh unchanged (already 字); counting logic unchanged | Done |
| 85 | Same jargon on player screens: club group poll (`poll.optionLimit`, `GroupPollViews.swift`), profile complaint (`profile.complaint.contactHint`, `.reasonHint`), Square comment report (`squareReport.invalid`, `SquareReportView.swift`), collect-set name (`collectSet.validation.titleTooLong`) | "UTF-16 units / text units" in both languages | en + zh → plain "characters / 个字符" with the same limits; validation code unchanged. Fragments `SquareReportLocalizations` + `ProfileComplaintPreparationLocalizations` kept equal to the catalog. Merchant strings with the same wording left (merchant out of scope) | Done |
| 86 | Creator walking-entrance editor (`ProjectEditView` → `NativeStoryWalkingAuthorView.swift`, validation `NativeStoryWalkingAuthorValidation.swift`; `WalkingValidation.xcstrings` label/source/floor/approach/alternative/businessTime) | "at most 300 UTF-16 units, with no null character" on six field errors (both languages) | en + zh → plain limits in characters ("Enter an entrance name of up to 300 characters.", "Keep the opening hours to 1,000 characters or fewer." …); validation unchanged | Done |

### Run 23 (2026-11-28, half-hourly)

Merged `origin/ui/combined-r7` (clean). No open coordinator finding for en-layout; Not done row unchanged (owner decision). Catalog-wide scan for "UTF-16 / text units" on non-merchant keys: `creatorRoot.*` and `playkitAuthor.validation.*` catalog values already read "characters" (their fragments keep older values pinned by contract tests; catalog wins at build).

| # | MP page → native view | Problem in English | Fix | Status |
|---|---|---|---|---|
| 87 | `pages/publish/temp` node narrative field (creator; MP order unchanged) → `ProjectNodeNarrativeFields.swift:132` (`projectNodeNarrative.tooLong`) | "The current editor allows 2,000 text units." — engineering jargon | en → "This field allows up to 2,000 characters. Shorten the text before saving; nothing has been cut."; zh → "最多 2,000 字。请缩短后保存；现有文字未被截断。" (catalog + fragment); limit logic unchanged | Done |
| 88 | US spelling on player + creator screens: club story answer notice (`pages/club/*`), club channel roles colour (`d7.channelRoles.color`), map search "Search around the map centre" (`pages/roam/*` map), registration sharing purpose (`pages/activity/baoming`), team members empty (`pages/team/*`), chapter atmosphere colour, template advanced scope, publish look tone | British spellings in the US English UI: organiser, colour, centre, travelling, recognise | en → organizer, color, center, traveling, recognize (catalog + `ClubStoryLocalizations`, `TeamLocalizations`, `fix-r3-club-a`, `mp-r3-publish`, baoming release strings); zh unchanged; merchant keys left (out of scope) | Done |

### Run 24 (2026-11-28, hourly)

Merged `origin/ui/combined-r7` (clean). No open coordinator finding for en-layout; Not done row unchanged (owner decision). Worked `pages/publish/fabu/*` sheets without a row.

| # | MP page → native view | Problem in English | Fix | Status |
|---|---|---|---|---|
| 89 | `pages/publish/fabu/survival-editor.wxml` (结果卡) → `MPGap/AccountPublish/ProjectEditThemeRulesSection.swift:278` (`ProjectEditResultCardSheet`) | Checked: Result card / Result card cover / cover fallback footer / Show on the card (nine fields in `CARD_FIELDS` order) / Show unlocked content / Restore the default result card / both errors | English reads well, short rows; no change | Checked |
| 90 | `pages/publish/fabu/cast-sheet.wxml` (角色) → `MPGap/AccountPublish/ProjectEditCastMemberEditor.swift` (`castMember.*`, `fixr8.cast.*`) | Checked: Edit character, Name *, One-line identity, Voice / Silent / Preview, Color, What you know / Add a line, Ending lines Low / Medium / High trust, Delete character | English reads well (US "Color"); no change | Checked |
| 91 | `pages/publish/fabu/step3.wxml` 票务 (票单价格 (¥) / 发行数量 (张); MP order unchanged) → `ProjectEditDetailForms.swift:509-510,652-653` | "Ticket price" field and review row give no currency, so an English creator can't tell the price is in yuan (draft sends yuan, `ProjectEditContract.swift:58`); "Total stock" is warehouse wording | en → "Ticket price (¥)", "Tickets issued"; zh → MP copy "票单价格 (¥)", "发行数量 (张)" (catalog); logic unchanged | Done |
| 92 | `pages/publish/fabu/look-sheet.wxml` (画面风格: 风格 → 主题配色 → 字体 → 文字动效) → `MPGap/AccountPublish/AccountPublishR8Mounts.swift:575` (`fixr8.look.*`, `mpPublish.look.*`) | Checked: Visual style, Style (Paper / Stardust / Night city / Wasteland), Theme colors, Story font (Serif / Sans serif / Calligraphic / Handwritten / Bold italic), Text effect / Match the style; summary "Paper · Black · Serif" | English reads well; no change | Checked |
| 93 | `pages/publish/fabu/topic-detail-sheet.wxml:139` 值域 card 没有实际效果时也消耗 (MP order unchanged) → `MPGap/AccountPublish/ProjectEditRuntimeValuesRows.swift:99` (`mpPublish.values.consume`) | Toggle "Use up even with no effect" — unclear what is used up; the footnote under it says a recovery "still costs and counts once" | en → "Count recoveries that have no effect" (catalog + `mp-r3-publish.json`); zh unchanged; logic unchanged. Other topic-detail-sheet labels checked (Topic description, Portrait cover, Landscape covers, Story details, Display name, Maximum, Bingo grid, Clues and items) | Done |

### Run 25 (2026-11-28, half-hourly)

Merged `origin/ui/combined-r7` (7a7d2708a). Sweep a4142df0d `mp-mine`, `mp-activity` `sheet-en.jpg`: no open coordinator finding for en-layout; Not done row unchanged (owner decision). Worked `subpackageMember/invoice*` (no row yet).

| # | MP page → native view | Problem in English | Fix | Status |
|---|---|---|---|---|
| 94 | `en-t5-baoming` "Listed ticket price ¥12.50", `en-t5-pass-market` "¥168.00" vs `en-d2-me` / `en-e4-wallet-balance` / `en-t5-order-center` "CN¥" | Two CNY spellings in English again (row 44 closed the ledger side) | Checked: registration uses `RegistrationUIMoney.display` (US r2 rule: order currency's narrow symbol in every locale, pinned by `Tests/CoreTests/RegistrationUIFormTests.swift:25-59`), while Me/ledger use `E1Money` (i18n r1: CN¥ in non-Chinese UI). Both rules are deliberate and test-pinned in other lanes; not overridden here. Listed in Not done for the coordinator to pick one | Checked |
| 95 | `subpackageMember/invoice`, `invoice-apply`, `invoice-detail`, `invoice-titles`, `invoice-title-edit` → `InvoiceLaunchHistoryView.swift:185`, `InvoiceLaunchApplyView.swift`, `InvoiceLaunchDetailView.swift`, `InvoiceLaunchTitlesView.swift`, `InvoiceLaunchTitleEditor.swift` (`InvoiceLaunchUI.xcstrings`; MP order unchanged) | History row "1 orders" (no plural); "withdraw"/"delete" used as nouns ("The withdraw is not confirmed yet", "Delete didn't finish"); "Tax number" (US reads "Tax ID") | `orderCountFormat` en plural one/other ("1 order" / "3 orders"; `String(format:)` on the bundle string honours the plural rule); "The withdrawal / deletion is not confirmed yet", "Withdrawal / Deletion didn't finish", "Withdrawal / Deletion not confirmed. Refresh to check."; "Tax ID", "Enter the full tax ID again", tax-ID validation message. zh unchanged; logic unchanged. Other invoice strings checked (status chips, filters, empty, apply total, issuer groups, notices) | Done |
| 96 | `subpackageMember/coupon-wallet`, `coupon`, `coupon-qr` → `AccountCollectionCouponsView.swift`, `AccountCollectionCouponDetailView.swift`, `CouponCodeView.swift`, `SessionRoamCouponWalletView.swift` (MP order unchanged) | Code screen "Coupon codes aren't available right now. No request was sent." (engineering wording); retry button "Fetch again" | en → "Coupon codes aren't available right now.", "Get a new code" (catalog + `NativeNavigationLocalizations`, `W205CouponsWithdrawalLocalizations` fragments, `tools/build_w2_05_localizations.py`); zh unchanged. Other coupon strings checked (filters All/Unused/Used/Expired, empty, validity rows, Directions, QR states, redeemed) | Done |

### Run 26 (2026-11-28, hourly)

Merged `origin/ui/combined-r7` (135f87720, clean). Sweep index still build 7a7d2708a (already checked in run 25): no open coordinator finding for en-layout; Not done rows unchanged (owner / coordinator decisions). Worked `pages/publish/fabu/runtime-editor`, `runtime-structure-editor`, `step3` 档期 / 招商 / 亲子票 rows (no row yet).

| # | MP page → native view | Problem in English | Fix | Status |
|---|---|---|---|---|
| 97 | `pages/publish/fabu/step3.wxml` 档期 · 商家招商 · 亲子票 (MP order unchanged) → `ProjectEditDetailForms.swift:509-520`, `ProjectEditView.swift` (`projectEdit.deadline`, `projectEdit.saleStart/saleEnd`, `projectEdit.validation.deadline`, `mpPublish.ticket.childAgeMin/Max`) | 招商截止日期 read "Recruitment deadline" (sounds like hiring players); "Sale start / Sale end"; child age limits read "Youngest child (age)" / "Oldest child (age)" (they are the allowed age range, MP: 超出年龄段的玩家不能下单) | en → "Merchant sign-up deadline" (+ validation message), "Ticket sales start / end", "Minimum child age" / "Maximum child age" (catalog + `docs/project-edit-localizations.json`, `mp-r3-publish.json`); zh unchanged. `cooperation.expires` (招募截止时间) and merchant keys keep "Recruitment deadline" | Done |
| 98 | `subpackageMember` order detail 亲子票 → `MPGap/Member/MemberRound2Views.swift:38` (`orderDetail.partyTicket`) | "Parent-child ticket" while the publish side and ticket names say "Family ticket (1 adult + 1 child)" | en → "Family ticket"; zh unchanged | Done |
| 99 | Order lifecycle refund explanation → `orderLifecycle.explanation.refundPolicy`; team settings → `ProjectTeamConfiguration.xcstrings` `projectTeamConfiguration.maximum`; bingo grid → `ProjectEditBingoPage.swift` (`mpPublish.bingo.configured`) | "Check the current **server** refund policy…" (engineering wording on a player screen); "Maximum selectable team size"; "3 of 9 set" (no noun) | en → "Check the latest refund policy and deadline.", "Maximum team size", "%lld of 9 cells set" (catalog + `docs/order-lifecycle-localizations.json`); zh unchanged | Done |
| 100 | `pages/publish/fabu/runtime-editor.wxml` (通关勋章 / 奖励 / 彩蛋 / 物品容量 sheets), `runtime-structure-editor.wxml` (进行方式 / 到达与引导 / 运行结局) | Checked: native has the bingo grid, "How do teams play together?", "If it can't be found"; the reward / egg / item-capacity sheets have no native strings (creator surface, see For other lanes) | No change | Checked |

### Run 27 (2026-11-28, half-hourly)

Merged `origin/ui/combined-r7` (clean). Sweep index still build 7a7d2708a (checked in run 25): no open coordinator finding for en-layout; Not done rows unchanged (owner / coordinator decisions). Worked `pages/publish/components/*` (no row yet).

| # | MP page → native view | Problem in English | Fix | Status |
|---|---|---|---|---|
| 101 | `pages/publish/components/collaborator-picker` 合作者可编辑内容，不参与结算 → `activityPublishing.review.collaboratorNotice` (`Core/ActivityPublishingWizard.swift:106`, `App/CoreLoopCopy.swift:86`) | "…don’t take part in **settlement**" (accounting jargon; the MP note exists so publishers know adding a collaborator doesn’t split money) | en → "Collaborators can edit the content but don’t share in earnings" (catalog, both Swift copies, `ui-strings-pages-publish-activity-index.json`); zh unchanged. Picker title / empty / failed / "Following: %@" already read well | Done |
| 102 | `pages/publish/components/story-rule-editor` 添加条件 / 添加效果 / 触发条件 / 产生效果 → `App/StoryRuleEditorView.swift:37,61,73,93` | Title Case "Add Condition", "Add Effect", "Trigger Conditions", "Resulting Effects" while the app uses sentence case ("Add clock", "Add trait") | en → "Add condition", "Add effect", "Trigger conditions", "Effects"; zh unchanged. `storyRule.stationCount` already plural | Done |
| 103 | `pages/publish/components/d20-settings`, `location-todos` | Checked: d20 strings (`mpPublish.d20.*`) sentence case, "Clocks %1$lld · Traits %2$lld"; location-todos (地点待办 / 替换地点 / 挡住发布) has no native strings or view (creator surface) | No change; "professional editor" (专业编辑器) is pinned by `PublishingModesFlowTests` / `ProjectOwnedEditorFlowTests`, left | Checked |

### Run 27b (2026-11-28, hourly; ran alongside run 27, rebased onto it)

| # | MP page → native view | Problem in English | Fix | Status |
|---|---|---|---|---|
| 104 | `pages/member` 我的项目 list → `PublishingManagementViews.swift:87`; collaborator validation `activityWizardValidation.collaborators` | "1 sign-ups" (count + a separate "sign-ups" noun concatenated, no plural); submit refusal "Nothing was sent. Access, configuration or the reviewed data changed."; "Select valid members without duplicates." | New plural key `publishModes.signupCount %lld` ("%lld sign-up" / "%lld sign-ups", zh "%lld 人报名"); notSent → "Nothing was sent. Your access or the content changed — refresh and check it again." (catalog + `tools/build_publish_modes_catalog.py`); "Check your collaborators. Choose each member only once."; zh unchanged | Done |
| 105 | `pages/publish/components/story-rule-editor` 换一个名字 → `StoryRuleEditorView.swift:230-232`, empty chapters `:393` | 换一个名字 read "Rename" (it picks a different target, it doesn't rename it) beside "Target: …" in one bordered button; empty chapters "once the theme publishes them" | en → "Change" (short, so "Target: …  Change" stays on one line at 375 pt); "Chapters appear here once they’re published."; zh unchanged | Done |

### Run 27c (2026-11-28, half-hourly; rebased onto 27b)

| # | MP page → native view | Problem in English | Fix | Status |
|---|---|---|---|---|
| 106 | `pages/play/*` 游玩工具 sheet (MP order unchanged) → `MPGap/PlayRoam/PlayToolsAndLeadSheetView.swift` (`playTools.*`) | One sheet mixed Title Case ("Play Tools", "Leader Tools", "Background Music", "Narration Autoplay", "Run Stats", "Remaining Games", "Station Rewards", "Settle Team" …) with sentence case ("Journey notes", "Record my trail", "My perks") | en → sentence case and plainer nouns: "Play tools", "This run", "Entry code", "Evidence cards", "Leader tools", "Release this stop", "Scan a member’s ticket", "Settle for the team", "Show group code", "Unlock next chapter", "Background music", "Autoplay narration", "Rewards by stop", "Games left", "Run stats" (catalog + `gap-g1-player.json`). "Reduce Motion" kept (Apple setting name); zh unchanged | Done |
| 107 | `pages/publish/temp` node-play editor (扫完回复 / 可触发的结果 / 状态不好时松一点) → `gap.template.*`; `pages/publish/components/attribute-binding-editor` | "Post-Scan Reply", "Triggerable Outcomes", "Relax on Low HP" (Title Case, jargon). attribute-binding-editor (启用的注册属性 / 注册定义差异) has no native view | en → "Reply after scanning", "Possible outcomes", "Go easier at low health" (catalog + `gap-g2-ops.json`); zh unchanged | Done |

### Run 28 (2026-11-28, hourly)

Merged `origin/ui/combined-r7` (xcstrings conflict resolved key by key: both sides' keys kept, no key edited on both sides). No open coordinator finding for en-layout; Not done rows unchanged (owner / coordinator decisions). Worked the Title Case scan of player `gap.*` keys and the team / seats / square views (no row yet).

| # | MP page → native view | Problem in English | Fix | Status |
|---|---|---|---|---|
| 108 | `pages/team/*` my-teams nav 加入码 → `App/NearbyTeamViews.swift:104`; `subpackageJourney/pages/seats` 保存邀请图 → `App/JourneyLandingViews.swift:904` | Title Case "Join Code" (toolbar label / VoiceOver) and "Save Image" in a sentence-case screen | en → "Enter join code", "Save invite image" (catalog + `gap-g2-ops.json`); zh unchanged | Done |
| 109 | `subpackageJourney/pages/seats` how-to 点「我到了」 → `mp.seats.howTo.arriveNote`; team review consequence 对方会在「我的队伍」里看到「未通过」 → `nearby.consequence.reject.1` | Quoted control names didn't match the real labels ("tap I'm Here" vs button "I'm here"; "sees Not Approved in My Teams" vs status "Not approved", tab "My teams") | en → "Walk into the place and tap “I’m here”", "The applicant sees “Not approved” under My teams"; zh unchanged. Other `gap.*` Title Case values are club director / coop admin / publish (level C or other lanes), left | Done |

## Not done

| Item | Why |
|---|---|
| `payoutReceiver.bind.mpOnly`, `payoutReceiver.bind.mpPathCopied`, `authEntry.deregister.wechatUnavailable` say "the Chengyin (WeChat) mini program" in English | These name the WeChat mini program, which is searched by its Chinese name; owner to decide whether English shows "Chein", "城瘾" or both. Not changed. |
| CNY in English: registration / pass market "¥12.50" vs Me / ledger / order lookup "CN¥" (row 94) | Two test-pinned rules from other lanes (US r2 `RegistrationUIMoney` narrow symbol vs i18n r1 `E1Money` CN¥); coordinator to pick one. |


## Next pages (no row yet)
Re-check rows 23, 37–41, 46, 56–57 in the next sweep. `pages/templatedetail/*` and `pages/publishkit/index` done from code (rows 59–60); `pages/publishkit/components/*` done (rows 61–62; reward-selector is coupon creation = merchant, out of scope); `pages/topic/catalog` is a redirect only (no content); pass-reveal done (row 65); topic detail includes/hero done (row 70); session-picker + self-play-checkout done (rows 71–72); theme-records done (row 74); topic route headers (row 76); story-fan / route-sketch / npc-avatar checked (row 77) — player `pages/topic/components/cy/*` complete (chapter-node-form, chapter-target-picker, node-npc-form are creator forms). template-intro done (row 78). activity publish done (row 79). Next: `pages/publish/temp`, start-prep checked (row 80). zero-hp-editor done (row 84). Survival / cast / step3 tickets / look / topic-detail-sheet done (rows 89–93). runtime-editor / runtime-structure-editor / step3 档期·招商·亲子票 done (rows 97–100). publish components done (rows 101–103). My projects sign-up plural + story-rule "Change" done (rows 104–105). Play tools sheet + `pages/publish/temp` Title Case + attribute-binding-editor (rows 106–107; `topic-state-keys` has no wxml). Team / seats Title Case (rows 108–109). Next: rest of `pages/publish/temp` (624 strings, 131 matched in the catalog; check the unmatched for native views), `choice-sheet`, Title Case scan of other `gap.*` player keys. `walkingValidation.*` done (row 86). Creator fragments `CreatorRootLocalizations` / `PlayKitAuthoringLegacyLocalizations` still contain "UTF-16 units" values (check the catalog values before changing). British spellings: non-merchant catalog values fixed (row 88); merchant values remain (out of scope). Catalog-wide: ~50 `publish*`/`projectEdit*` en values use straight apostrophes (not a layout problem; leave unless a screen is touched).

## For other lanes
- mp-publish: topic detail has no native counterpart for MP `pages/topic/components/cy/route-progress` (通关进度 / 护照进度 n/total), `merchant-cards` (到店礼 · gift, 去看看 / 去核销) or `theme-badge` (主题徽章 sheet, 走完全部章节获得) — no strings or views found; check against the MP topic page order.
- mp-home: map filter date sheet (`SearchMapFilterSheet.swift`) has no MP date-range-sheet summary badge (共 N 天 / N 晚 once both ends are picked).
- mp-club: `en-d4-detail` (declined non-member) — the floating "Apply again" button sits over the "Message to the club" field and the contribution-board header; the bottom action needs its own inset (`safeAreaInset(edge: .bottom)`) so content scrolls clear of it.
- mp-mine: balance ledger shows "¥" while the Me balance tile shows "CN¥" in English (row 44); public profile role line "— City explorer" shows a dash placeholder (`en-e4-member`).
- mp-journey: `en-d2-play` nav shows debug "Switch synthetic account"; t5-free-explore "DEBUG fixture" banner still visible.
- mp-activity: Square fixture post text "A synthetic city walk / 一次示例城市漫步" (`Core/SquareSyntheticFixtures.swift`, shared with Core tests) shows Chinese in English (`en-d2-square`).
- mp-journey: 19:15 items still visible in `en-*` journey shots (灯笼石门, 西湖夜游漫步, 老城茶街章节, free-explore "—" rows).
- mp-journey / mp-nav: City root entry reads "CITY ownership and original receipts" (`cityAcquire.entry`, all-caps CITY also in zh) — confirm CITY is the intended product name.
- `Tests/ContractChecks/check_wallet_earnings_overview.py` fails (2) on `ui/combined-r7` before any en-layout change (debt-r3).

- mp-publish: MP `pages/publish/fabu/runtime-editor.wxml` 通关勋章 / 添加奖励 / 彩蛋 / 物品容量 (每件占格, 允许丢弃, 发放时机) sheets have no native strings or views; check against the MP editor order.

## Gates
See the commit message of each push (generate_project, check_scaffold, a11y lint, contract ratchet new 0, design consistency PASS, locale format PASS).

### Pins updated (run 3)
- `Tests/ContractChecks/test_topic_reviews.py`, `test_activity_reviews.py`: review date token is now `Text(verbatim: LocaleDisplay.civil(date, locale: locale))`. Reason: English date format; plain-text rule unchanged.

### Pins updated (run 1)
- `Tests/ContractChecks/test_play_gameplay_mode_separation.py:69` and `test_play_experience_contracts.py:110`: read the English plural `other` form when a `playFree.*` / `playx.*` key carries plural variations (`playFree.meta.stores`, `playx.board.score`). Reason: count strings now vary by plural; the bilingual check itself is unchanged.
