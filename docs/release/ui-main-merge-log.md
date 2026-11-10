# ui/main merge log

Base: cfbc9aa75 (already contained ui/d6 b85ae2741, an older ui/d2/ui/d4/d7 via ddd3589da).

| Merged | SHA | Result |
|---|---|---|
| ui/d2 round 4 | 0f44c1f59 | conflicts in 7 files; design side for views, registry union, pbxproj regenerated (2f22c9920) |
| ui/d4 round 5 | 12bf99e8e | clean |
| DES-D7 round 4 | 3654c85d0 | clean |

Strings: all ui-strings-*.json keys are in Resources/Localizable.xcstrings (check_catalog_coverage.py passes); ui-strings-d1.json targets the separate AuthEntry table.

Build 1 (design-batch int) failed on kit compile errors, fixed by reading only (not yet rebuilt; builds paused by owner for machine load):
CYCachedAsyncImage:101, CYConfirmSheet (cancelIdentifier/titleIdentifier missing), CYHeroHeader:48, CYScreenStyle:28 and :150.

Build 2-4 (after GO): cherry-picked e3 5a0e12706 (duplicate score) and e1 f01d48935 (RoamStamp tint); added CYListRow verbatim init without leading (MerchantMarketingView:159, rc error); dropped `?` on earlyAccuse allowed (ContentContractV1:520).
Remaining: App/QuestifyApp.swift:262 `var body` "failed to produce diagnostic" (file identical to rc cfbc9aa75, so likely an rc error hidden inside the body); no other error lines in the log.

Build 5 (design-batch int): BUILD_EXIT=0, six fixtures shot. QuestifyApp fix: `bankWithdrawalDestination` ternary `{closure} : nil` against `(@MainActor () -> AnyView)?` made the body diagnostic fail; now typed explicitly. QuestifyApp body is also split (per-tab properties, chain helpers).

## Cycle 1 (2026-11-09 ~10:50)
| Merged | SHA |
|---|---|
| origin/rc/20261108 | 86fa48b0c |
| ui/e1 | 0ae8513cc |
| ui/e2 | 8c45fb0f1 |
| ui/e3 | f8e6f98cb |
| ui/e4 | de676a0b7 (only a merge of ui/main) |
| ui/e5 | no branch yet |
Registry: union (e1, e2, e3 cases); project regenerated each time. design-batch int: BUILD_EXIT=0, 8 fixtures (e1-topics, e1-activity-detail, e2-dice, e2-chapters(loading state), e3-inbox, e3-chat, e4-settings-support, d2-home) render. Note: designers' refs are local branches in the shared repo; origin has no ui/e*.

## Cycle 2 (2026-11-09 ~12:15)
Merged rc (no new), ui/e1, ui/e3, ui/e4 (ProfileParticipantsView: design side), ui/e5 ec87e4c6a (CreatorContentViews, FreeExploreBundleLaunchView: design side). Title sweep: `View.cyHeroScreen()` applied inside CYHeroHeader (inline + empty nav title); duplicate navigationTitle removed in 7 hero screens. design-batch int BUILD_EXIT=0, 14 shots.

## Cycle 3 (2026-11-09 ~14:15) — compiled, BUILD_EXIT=0, 6 fixtures
Merged: rc abc2fec0f, ui/e1, ui/e2, ui/e3, ui/e4, DES-e5 (b55631335 and later; note e5 lives on branch liboyang42-cpu/DES-e5, there is no ui/e5). Kit dedupes: CYCoverArt (CYSignature canonical, + cornerRadius; e3 variant -> CYIMCoverArt; e2 duplicate struct removed, CYProgressRing/other e2 kit types kept), e5 ring -> CYCountRing. Design side won on view conflicts (FreeExploreBundleLaunchView, ObjectBadgeViews, TicketWalletView, IMInboxViews, MessagingHistoryView, ObjectBadgeWallParityViews).

## Cycle 4 (2026-11-09 ~15:50) — pushed before local build (Xcode Cloud is the compile check)
Merged: rc 7c105ecd2, ui/e1 719238623, ui/e2 aa15d01fb, ui/e3 1b5bd2ec9, ui/e4 eb8b6ff90, DES-e5 cd5c9f89d. Fixes: CYIMCoverArt rename in Club*/IM callers; GlobalSearchView static stored property moved out of a generic type; `searchMap.routes.recent` merged into the catalog with tools/merge_localization_fragments.py.
