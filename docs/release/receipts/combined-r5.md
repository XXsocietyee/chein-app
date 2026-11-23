# Receipt: combined-r5 (six parity-fix branches on combined-r4)

Branch `ui/combined-r5`, cut from `origin/ui/combined-r4` @ 341025c50 (verified). Local Mac, Xcode, own DerivedData
`DES-ag6-c4v`, simulator Questify-iPhone17-Lane2 (2337B386, iOS 27). Every build, test run and simulator batch held
`lockf /private/tmp/design-build.lock` (15-minute holds, released between batches); free disk stayed above 7 GB.
`ui/main` was not touched.

## 1. Merges (no squash, in order)

| # | branch | head | conflicts |
|---|---|---|---|
| 1 | fix/parity-club | 0b69fc6a9 | none |
| 2 | fix/parity-play-roam | 68b6e276c | Localizable.xcstrings |
| 3 | fix/parity-player-content | 4da6a580c | Localizable.xcstrings, typography baseline, MPReviewedPageScreen, MiniProgramPageLink |
| 4 | fix/parity-member | 126da3c62 | Localizable.xcstrings, typography baseline, MPReviewedPageScreen, OrientScoreView |
| 5 | fix/parity-account-publish | bb96350d9 | Localizable.xcstrings, typography baseline, MPReviewedPageScreen, PublishingModesViews, MiniProgramPageLink |
| 6 | fix/parity-merchant-coop | ec4836820 | Localizable.xcstrings, typography baseline, MPReviewedPageScreen, CoopRelationDiscoveryView, MerchantBusinessEditor |

## 2. Conflict resolutions

- **Localizable.xcstrings** (5 merges): a 3-way JSON merge per key (base = merge base, ours, theirs; union of keys, a key
  changed on both sides takes the fix branch's value, a key deleted on one side and untouched on the other is deleted).
  No key was changed on both sides in any merge. The output round-trips byte-exactly through `json.dumps(indent=2,
  ensure_ascii=False)` like the committed file; it parses; 17 039 keys at the end; scaffold's bilingual check passes.
- **tools/typography_lint_baseline.json**: not hand-merged (kept ours during each merge), then regenerated once with
  `python3 -B tools/check_typography_lint.py --update`. Totals vs combined-r4: raw text style 1199 → 1173, back chevron
  15 → 12, hidden back 15 → 7, large title 26 → 11, Theme.Font 63 =, raw size 67 =. No file's count went up.
- **Core/MiniProgramPageLink.swift**: kept every side's page rules (play/roam rules, player-content `queryPages`,
  account-publish rules); the `openPages` list drops every page either side moved into a rule. A checker confirmed no
  duplicate rule keys, no open page that is also a rule except the four intentional "set last" overrides.
- **App/MPReviewedPageScreen.swift**: all new cases kept (club, play/roam, player-content search, member invoice /
  free-explore, account-publish settings / marketing / mylike / addressinfo, merchant-coop merchant pages). Two
  `signIn()` versions met: kept player-content's (dismiss the link, open 我的) because member's bridge sheet is mounted
  only in the pass host, so it would have been a dead tap here. `pages/gerenziliao` keeps both play-roam's signed-in
  guard (JSEAT-3) and account-publish's `initialField` (A3-08). Search cases: player-content's PC-A-3-2 query versions
  replace merchant-coop's plain `SessionGlobalSearchView`. Helpers: `clubQueryID` / `queryID` / `reviewedID(key:)` /
  `positiveID` kept once each.
- **App/PublishingModesViews.swift**: combined-r4's commit there only restored contract-pinned bytes; account-publish
  C-A3 removes the principal toolbar title (one system inline title), so the inline title mode stays and the
  duplicate principal title goes. `test_activity_publishing_wizard` is unchanged (already in the base list).
- **App/CoopRelationDiscoveryView.swift, App/MerchantBusinessEditor.swift**: combined-r4 had only restored pinned bytes;
  merchant-coop removes the author-delete row (relation P1) and the storage-key field (aftercare-detail P1). Took the
  parity removals; the rest of each file keeps r4's bytes.
- **App/OrientScoreView.swift**: member's `cyPushedChrome(domain: .game)` + 选择其他对局 toolbar + sign-in sheet replace
  play-roam's `cyHideTabBar(true)` (cyPushedChrome hides the tab bar too).
- **AppUnit shard test plans**: the play-roam generator run had re-sharded them; restored combined-r4's plans (no new
  AppUnit test class came in, so nothing to add to the skip lists).

## 3. Build and compile fixes

The merged tree compiled first time for the app (`BUILD SUCCEEDED`). Building needed `ONLY_ACTIVE_ARCH=YES` in
`extraArgs` (the project leaves it unset, so Xcode built x86_64 against the arm64-only vendor GLTFKit2 framework).

| commit | fix |
|---|---|
| b67e59559 | QuestifyCoreTests did not compile: the CLB-topic-detail-04 test was appended after `Port1ClubTopicDetailTests`'s closing brace and `#endif` was truncated to `#endi`; PLY-26-1 renamed `publishTarget` → `statusTarget` but two test files still used it |
| 2abfd3439 | 11 Core test classes still asserted pre-parity rules (gift token optional MKT-3-2, merchants may join CLB-detail-01, customer paging CLB-customers-01, categoryIds apply-P0b, points empty copy FIN-18-3, template detail link PC-A-8-1, market status 3 PLY-26-1, page-link table filling every required key) |
| 33b3a4334 | App: `AppSession.logout(matching:)` (B-SZ-02 server-first) let a duplicate confirmation send a second `/api/logout` while the first was pending — in-flight guard, AppSession still 8171 lines; `MPParityRoute` default branch now applies the Core link rule (club governance without `clubId` no longer opens); DEBUG onboarding fixture carries `categoryIds` |
| bb16a8323 | AppUnit tests for the intended changes (B-SZ-02 sign-out, apply-P0a/b onboarding, deep-link samples, SALBUM-1 album capture) |
| 7b2329bc7 | three contract byte pins re-pinned for intended parity changes (coop relation view, merchant station protected views, global search view) |

## 4. Fixes found while verifying on the simulator

| commit | found on | fix |
|---|---|---|
| 0da90c1c8 | B-SZ-01 | `pages/shezhi/shezhi` crashed (missing `NativeOriginalUnreadBadgeState` EnvironmentObject on the link sheet) |
| ecf1ccdc7 | PC-A-3-2 / PC-A-4-1 | search2 links filled the keyword but never searched (task ran before onAppear set `isVisible`) |
| b6054558e | FIN-11-1 | 我的发票 showed "My invoices" (`invoiceString` ignored the in-app language) |
| 868c17f64, bc02a2bd4 | CLB-detail-02 / -20 | club 活动 tab: empty Group never appeared (no read), the first fix exposed an appear/disappear loop (hang); lifecycle now on one stable anchor row; 发布主题 had two chevrons |
| b2203d8a2 | A2-01 | 个人主页 link opened an empty page: `SocialReadScreen` re-ran its task on the List child swap and the cancelled read left nothing; an answered key now keeps its answer |
| 487606770 | C-A1, X5 | the link sheet's 关闭 was white on light-domain pages (empty pill) |
| d0cfb709d | — | DEBUG `--debug-open-url <url> [--debug-open-url-delay s]`: the app registers no URL scheme, so `simctl openurl chein://…` cannot reach links |

## 5. Gates (final tree)

| gate | result |
|---|---|
| `python3 -B tools/check_scaffold.py` | PASS (4 942 Swift files, 17 039 bilingual keys, project equivalence, AppSession 8171 / AppCompositionRoot ratchets) |
| `python3 -B tools/check_design_lint.py` (+ typography) | PASS; typography 1173 / 63 / 67 / 12 / 7 / 11 (all at or below combined-r4) |
| `python3 -B tools/contract_ratchet.py --check` | 185 failing, baseline 184, new 1 = `test_workshop_paid_professional…bounded_paging` — identical to combined-r4 |
| Core `swift test --disable-sandbox` | 17 008 tests, **27 unique failing = baseline 27, 0 new** (names compared with combined-r4's log) |
| AppUnit, 4 shards (xctestruns from the shard plans, `test_sim`) | 6 / 16 / 30 / 29 failing → 81 names. Against the 72-name baseline (combined-r4 bundles 11-22 19:08–19:14): new before fixes = the merchant onboarding, deep-link route, sign-out and album-capture tests (all fixed in §3, targeted re-run 92/94 pass) and the 4 `OwnAccountRefreshOrderingTests` names, which crash inside `XCTSwiftErrorObservation` — the intermittent class combined-r4 already reported. After the §4 fixes a targeted run of the 15 classes nearest the changed views: 106 pass, the 5 failures are baseline names |

## 6. P0 verification on TEST (per receipt "local verification" column)

TEST = `--e2e-test-host https://8120-…instabox.tech`, accounts 9009 (player), 9003 (club owner), 9002 (merchant),
SMS codes read from TEST Redis. Screenshots and per-P0 notes: `/Users/fanning/chengyin-refs/combined-r5-verify/<area>/index.md`.

| area | P0s | verified | broken → fixed | broken / open | partial | can't-test | not checked |
|---|---|---|---|---|---|---|---|
| club | 24 | 6 | 0 | 1 (CLB-detail-02) | 1 | 4 | 12 |
| play-roam | 29 | 5 | 0 | 0 | 1 | 0 | 23 |
| player-content | 12 | 6 | 1 (PC-A-4-1) | 0 | 1 | 0 | 4 |
| member | 24 | 5 | 1 (FIN-11-1) | 0 | 3 | 0 | 15 |
| account-publish | 12 | 5 | 1 (A2-01) | 0 | 0 | 0 | 6 |
| merchant-coop | 12 | 1 | 0 | 0 | 2 | 3 | 6 |
| **total** | **113** | **28** | **3** | **1** | **8** | **7** | **66** |

What limited the pass, stated plainly:
- The E2E route gate refuses several reads on TEST (app log `[E2E] composition refused … notConfigured`):
  `api/user/public-info` (A2-01 body), `api/club/crm/customers/detail`, `api/club/crm/topic-manage-stats`,
  `api/merchant/finance/redemptions` (X5), `api/merchant/operators/list`, `api/merchant/business-status`. Those screens
  route correctly and show their failure state; their content cannot be seen on TEST.
- TEST data/account state: 9003 is at the club-creation limit (CLB-create-01), 9002 is already an approved merchant
  (apply-P0a/b), club 7001 has one customer (CLB-customers-01 paging), 9009 has no platform-pass orders.
- 66 P0s were not reached in this pass (mostly play-roam journey/landing pages that need server tokens, flows that
  need in-app navigation several levels deep, and write flows behind TEST-only switches). They are listed as
  "not checked" in each index, not counted as passing.

Open after this pass:
- **CLB-detail-02**: on TEST the club 活动 tab's public-topics read never reaches the network and the tab stays on
  正在加载俱乐部…; the blank/hang the merge produced is fixed, the read itself needs a follow-up.
- Topic overview rows show the form label 「开始日期，YYYY-MM-DD」 (`club.gov.field.startDate`) as a display label
  (seen on CLB-topic-detail-01); pre-existing copy, not changed here.

## 7. Backend items

Every "blocked-backend" / "Backend needed" item from the six receipts: `docs/release/backend-needed-r5.md`.
