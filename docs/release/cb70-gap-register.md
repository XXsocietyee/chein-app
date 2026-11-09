# CB70 launch gap register

Ordered by launch impact for a reviewed client of the current production backend. This file records gaps already written on four notes. It does not close them.

The notes sit on branches whose parent is `67053ccb33c0e1ad35a7508f8546ae9076fd82e5`. That commit is an ancestor of this RC. This register is written on `origin/rc/20261108` at `88e981b3308558939e405606cd731b4b29fc9499`. The later commits are the D2–D4 UI merges. This file does not re-scan `App/` or `Core/`, does not re-run the release gate, and does not re-classify the public `codex/*` tips against the newer tip.

| Source | Tip | Note |
|---|---|---|
| `origin/cursor/cb12` | `0379fa0f0511ba39c9972624db8c52d8018d6d13` | `docs/release/cb12-staging-verify.md` |
| `origin/cursor/cb13` | `a8e8793fa1efb44333a8fe7e23e52c1fa2fd30f1` | `docs/release/cb13-route-matrix.md` |
| `origin/cursor/cb14` | `70bde9230af9d13874717d85ac93a8ea63ab8716` | `docs/parity/page-map.csv` (17 `CB14:` sentences) |
| `origin/cursor/cb19` | `eb468b89f3b83a925ecbfa382724da6fb47251d0` | `docs/release/cb19-codex-triage.md` |

Those four files are not in this RC. The counts below are the counts those notes recorded. CB19 also names the RC tree it merged against: `3588b12a8e8a2be199618de31c6df1b15ed4d3cf`.

## How to read this

The numbered list is the gap register. A lower number blocks a reviewed launch sooner. Owner decisions are a separate list. They are unset. This register does not pick them, and it does not treat an unset decision as a passed check.

Marketing version stays **0.1.0**. Build stays **1**. `Config/Base.xcconfig` on this RC already has `MARKETING_VERSION = 0.1.0` and `CURRENT_PROJECT_VERSION = 1`. This change does not edit that file.

## Ordered gaps

### 1. Release gate is not green, so the public codex queue stays unmerged

CB19 classified 93 public `codex/*` tips on `liboyang42-cpu/chengyin-ios`, read 2026-11-08 PT, into the RC at `67053ccb33c0e1ad35a7508f8546ae9076fd82e5`.

| Class | Count |
|---|---:|
| merge-now | 0 |
| skip | 13 |
| needs-change | 80 |

The release gate on that RC was not green. The note names the known-red item as the manifest audit / CI ledger. The lane did not re-run the gate and did not refresh the ledger. A branch is not merged there even if it were merge-now. No conflict-free merge changed the RC tree, so the hard-rule scan moved nothing. The 80 needs-change tips conflict and have to be replayed onto that RC before they can be taken. The 13 skip tips do not change the RC. Nothing was merged.

This is first because the queue that would change the client stays outside the RC while that gate fact stands, and this register does not replace the gate result.

### 2. Private backend staging did not run, and a repository HTTP 404 is not a pass

CB12 targeted private backend branch `claude/be-v2-fixes` on `liboyang42-cpu/chengyin`.

| Check | Result recorded |
|---|---|
| Routes executed | 0 of 370 |
| Runtime status | UNVERIFIED on every row |
| Migration files applied | 0 |
| MySQL integration tests executed | 0 |
| Full object id of `claude/be-v2-fixes` | not resolved |

The credential received HTTP 404 (`Repository not found`) from `https://github.com/liboyang42-cpu/chengyin.git` and from `gh api repos/liboyang42-cpu/chengyin`. That 404 is not a pass. It does not prove the branch is absent, present, or healthy. The remaining digits of the object id stay blank.

Public static tables on `liboyang42-cpu/chengyin-ios` branch `claude/backend-route-tables-20261108` (`24ab11622236fb9fca483ed4e1ddef05b50e9279`) record the prefixes `537e43c74` and `537e43c7`. Those prefixes are not a 40-digit object id. `gh api` found no commit `537e43c7` on the public repos that note queried. Public `hengyin` has no branch `claude/be-v2-fixes`. Its `master` is `147754ba8740abf208bda75cf86ed5901cac4c02`, and that tree has no `migration_g*_20261108.sql`.

A localhost MySQL 8.0.46 Ubuntu server was started and then stopped. The public funds gate continues only when the server identity is `8.0.45|MySQL Community Server - GPL`. This server was not that image. The scratch database `cb12_scratch` ended at 0 tables. No migration statement was sent. `mvn` was not on `PATH`. No backend process was started. No HTTP status was recorded. A printed HTTP code from a future run stays UNVERIFIED until the body is read against the static contract.

The five migration names cited by the static tables, and not applied, are `migration_g01_20261108.sql`, `migration_g02_20261108.sql`, `migration_g03_20261108.sql`, `migration_g04_20261108.sql`, and `migration_g08_20261108.sql`.

### 3. The default build stays unconfigured and does not call a backend

CB13 records that the default `Base.xcconfig` build uses `shippedComposition`, which passes `reviewed: nil` when the base URL is empty. That composition stays `.unconfigured`. It does not install a backend. The empty URL is what keeps that build dark.

On this RC, `Config/Base.xcconfig` still sets `QUESTIFY_API_BASE_URL` to empty and `QUESTIFY_DEPLOYMENT_ENVIRONMENT` to `unconfigured`. This register does not fill the URL and does not switch the composition to a reviewed deployment.

CB13's China admission check is on `cursor/cb13` only. It is not in this RC. Of the 608 live call sites in that note, 592 are eligible and 16 stay off. Those sixteen, with the fifteen live prefixes, expand to 658 production patterns the reviewed deployment may call. A missing literal under a prefix is not in the 658. A refused request throws `APIError.notConfigured` and does not fall through to sample JSON. None of that admission code is merged here.

### 4. 385 iOS call sites have no controller on the reviewed production snapshot

CB13 counts distinct `api/` string literals under `App/` and `Core/` on the note's base. Comments are ignored. The same literal in several files is one row.

| Mark | Count | Meaning in the note |
|---|---:|---|
| live-in-production | 608 | A controller mapping on production `014fc0d83afe9f53cf4a8b1f9544bcf634e9ce6c` matches the literal. |
| new-backend-only | 0 | Present on public snapshot `147754ba8740abf208bda75cf86ed5901cac4c02` and absent from production. None of the iOS literals are in that set. |
| missing | 385 | No controller mapping on either snapshot. |
| call sites | 993 | 608 + 0 + 385. |

The only route the note finds added between those two backend commits is `POST /api/author-write/receipt`. This app does not call it. The 385 missing literals are hidden. `isHiddenFromChinaReviewed` is true for every path the gate refuses. They have no capability that shows them.

Missing literals by the first two path segments, for families with at least five call sites (310 of 385):

| Prefix | Missing literals |
|---|---:|
| `api/im` | 74 |
| `api/merchant` | 31 |
| `api/club` | 28 |
| `api/city-game` | 26 |
| `api/friend` | 24 |
| `api/workshop` | 22 |
| `api/reward-pledge` | 17 |
| `api/topic` | 15 |
| `api/play` | 14 |
| `api/native` | 12 |
| `api/channels` | 10 |
| `api/approved-topic-release` | 8 |
| `api/rewards` | 8 |
| `api/public-catalog` | 6 |
| `api/channel-platform` | 5 |
| `api/channel` | 5 |
| `api/roam` | 5 |

The other 75 missing literals sit on prefixes with four or fewer call sites. Three of them are under `api/us`. One is under `api/pay`. One is under `api/location-share`. The US host and the payment route are owner decisions below. This gap does not choose either.

### 5. Sixteen live production routes stay off by capability

These sixteen are live on production `014fc0d83afe9f53cf4a8b1f9544bcf634e9ce6c` and still hidden. China verifies only `.domesticChinaPhone`. The route gate refuses them even if a caller builds the URL.

Password login (`.usernamePassword`):

- `/api/login`

Phone, Apple, and WeChat app login stay eligible when the route is live.

Bank withdrawal (`.merchantPayout`):

- `/api/withdrawal/create`
- `/api/fund/preflight/bank-withdrawal`
- `/api/fund/preflight/{}/`
- `/api/fund/preflight/{}/confirm`
- `/api/fund/preflight/{}/reject`

`/api/withdrawal/list` is history and stays readable. Team leave, offer withdraw, and chapter-application withdraw are not bank payouts.

Virtual goods (`.digitalContentPayment`):

- `/api/cart/cart/add`
- `/api/cart/delete`
- `/api/cart/list`
- `/api/cart/order/settlement`
- `/api/cart/settlement`
- `/api/cart/update`
- `/api/product/info`
- `/api/product/list`
- `/api/registration/pay`
- `/api/registration/pay/app`

`/api/pay/create` is missing, so it is hidden too. CB12 lists it outside the 370 as BLOCKED, no route, and not executed. Which payment route a launch uses is an owner decision. This row records the hold. It does not select a route.

### 6. Play, check-in, template use, and free-explore cancel stay hidden

CB14 read the tree at `67053ccb33c0e1ad35a7508f8546ae9076fd82e5` and appended one sentence per page. No Swift toolchain was present, so the cited tests were not re-run. No API URL was added. The sentences are not in this RC's `docs/parity/page-map.csv`.

| Page | What the note records |
|---|---|
| `pages/play/index` | `StoryParticipationWriterFactory.makeWriter` defaults to `GatedStoryParticipationWriter`. `ExternalGameLibraryPresentation.launchFlagKey` is `externalGames` and `linkDownloadAvailable` is false, so import only shape-checks. Stays hidden. |
| `pages/play/merchant/index` | `AppSession.playStoreDay` builds `PlayStoreDayService` with `gates: .disabled`, so `permitsProofWrites` is false. Check-in, photo, and answer send nothing. Stays hidden. |
| `pages/play/poi-challenge/index` | Status set to partial. `ChallengePOIWriterFactory.makeWriter` defaults to `GatedChallengePOIWriter`, whose `complete` returns `.unavailable` and sends nothing. `ChallengePOISubmissionTests.testSuccessUsesMiniRequestShapeAndShowsDoneOnlyAfterServerAnswer` uses a `FakeWriter`, not that factory. Not re-run. |
| `pages/template/index` | `TopicTemplateUseSection` has no caller outside its own file. `TopicTemplateUseFactory.makeUser` defaults to `GatedTopicTemplateUser`, and `use` returns `.unavailable` without sending. Stays hidden. |
| `subpackageA/pages/myproject/index` | `MyProjectMutationStatusView` has no caller outside its own file. `MyProjectMutationFactory.makeMutator` defaults to `GatedMyProjectMutator`, which returns `.unavailable`. Stays hidden. |
| `subpackageMember/free-explore/index` | `FreeExploreCancelFactory.makeCanceler` defaults to `GatedFreeExploreReservationCanceler`, whose `quote` and `cancel` return `.unavailable`. `BundleCancelView` has no caller outside its file. Stays hidden. |

### 7. Club, merchant, message, and complaint writes stay hidden

Same CB14 pass. Live writes on these pages stay off the production caller.

| Page | What the note records |
|---|---|
| `pages/club/create/index` | `ClubOperationsViews.content` shows `club.ops.writeGated` when `access.writeAvailability` is `.unverified`, including target `.create`. Live create stays hidden on that path. `ClubCreateQuotaTests` was not re-run. |
| `pages/club/edit/index` | The same unverified write gate covers live edit and dissolve. `ClubEditDissolveTests` was not re-run. |
| `pages/merchant/relation/index` | `CoopRelationPostFeedFactory.make` is called only from `CoopRelationPostFeedFactoryTests`. A nil community returns nil, so the Posts segment stays hidden. No production caller was added. |
| `pages/merchant/decor/index` | `MerchantOperationsHomeView` shows `CloseW5dGatedNotice` `merchant.decor.save.gated` when `reader.canSave` is false. Save stays hidden. The cited state tests were not re-run. |
| `subpackageB/pages/im/list/index` | `IMCoopInviteStripFactory.make` is called only from `IMCoopInviteStripFactoryTests`. A nil reader returns nil, and no production caller injects the strip. Stays hidden. |
| `subpackageMember/complaint/index` | `ProfileComplaintPreparationLink.submitterFactory` is nil, and the reader-only init sets `submitter` to nil. The report write stays unavailable and sends nothing. |

### 8. Invoice apply recovery and the play-guide refresh stay partial and unrerun

| Page | What the note records |
|---|---|
| `subpackageMember/invoice-apply/index` | `InvoiceLaunchCoordinator.recover` for an original apply throws `outcomeUnknown` unless `titleId`, `matches(command)`, and `applicationID` agree. The cited test now sets `titleId` to 11. Not re-executed. Stays partial. |
| `subpackageA/pages/infomation/infomation` | `ProfileGuideListReader.refresh` only bumps `revision` and does not call `informationList`. `ProfileGuideReadRoute.detail` treats a missing data key as removed, which `ProfileGuideAbsentDetailProducerTests` requires. `ProfileGuideReadRouteTests` still expects that body to throw. Production was not changed. Neither test was re-run. Stays partial. |

These stay below the hidden-write rows because the note did not execute a new failing run. It also does not record a pass.

### 9. Orient-score writes, character-card save, and roam presence stay off

| Page | What the note records |
|---|---|
| `subpackageMember/orient-score/index` | `OrientScoreReviewFactory.makeSubmitter` returns nil. `OrientScoreReviewSection` has no caller. `OrientScoreView` is constructed only in its own previews. Appeal and dispute writes stay hidden. |
| `subpackageMember/character/index` | Attribute level labels are wired. `CharacterCardReadback` stores `attributeLevels`, and `CharacterSheetDetailView` passes them to `CharacterSheetRules.levelLabel`. Save stays hidden: the view says saving is not wired to a server contract. No API URL was added. |
| `pages/roam/index` | `PersonalLocationShareHost` defaults `readApproval`, `writeApproval`, and `captureApproval` to nil, so presence sharing stays off. No new location collection was added. |

The character-card label sentence corrects an older "not wired" claim. The remaining gap on that page is the save. The roam sentence is a hold: the note does not turn presence sharing on. CB12 also leaves `/api/location-share/personal/*` outside the 370 as BLOCKED, no route, and not executed.

### 10. Static exceptions in the 370-route table remain runtime-unverified

This is not a second failure list. Gap 2 already marks all 370 routes UNVERIFIED. The static column was copied from public tables and was not re-checked against a running server. Rows whose copied cell is not a plain `registered` or `listed` word:

| Static cell | Routes |
|---|---|
| `registered, functionally dead` | `POST /api/merchant/authoring/releases` |
| `registered, functionally 503` | `GET /api/merchant/city-value/result/{id}` |
| `registered only if flag true` | `POST /api/club/open-settings/welcome-note-receipt` |
| `UNREGISTERED` | 24 city-value and city-game routes (ledger rows 18–20 and 41–61) |
| `UNREGISTERED, no registration helper` | 5 city-game routes (ledger rows 62–66): merchant operations availability, intent, and request, plus player-rules and state/deltas |

The other 338 rows are the plain `registered` (34) and `listed` (304) cells. Their runtime is still UNVERIFIED.

CB12 also names routes outside the 370 that this run did not execute. They include club activity join/cancel/detail, club events and notices, topic attribute-author reads, `workshop/purchased`, `PUT /api/im/members/{memberId}/roles`, `POST /api/im/unpin`, `POST /api/invite/revoke`, `/api/location-share/personal/*`, `/api/mod-commerce/*`, `/api/mod-installation/`, `/api/mod-owned-report/licenses/`, `/api/mod-upgrade/`, `/api/pay/create`, and `/api/team/original-request`. Several of those are marked BLOCKED, no route, in the static tables. Overlap with the 385 missing iOS literals is expected. None of them was executed, and none of them is a pass.

## Owner decisions

These five are unset. They are not ordered as launch work this register can finish. The gaps above stay open whether or not an owner later picks one of these.

| Decision | What the notes already say | What this register does |
|---|---|---|
| US API URL | CB13: United States `apiBaseURL` stays empty. No US host is invented. Three `api/us` literals are in the missing 385. This RC's `QUESTIFY_API_BASE_URL` is empty. | Does not choose a host. |
| Payment route | CB13 hides the live cart, product, and `/api/registration/pay` paths. `/api/pay/create` is missing there and BLOCKED with no route in CB12. | Does not choose WeChat Pay, StoreKit, `registration/pay`, or `pay/create`. |
| Legal text | None of the four notes supplies or approves legal text. | Does not write a privacy policy, an agreement, or a translation. |
| ICP number | None of the four notes records an ICP number. | Does not invent a filing number. |
| Deploy now | CB12, CB13, and CB19 each record that they did not deploy. | This file is not the phrase "deploy now". |

## Not done

No Swift edit. No xcconfig edit. No workflow edit. `tools/current_ci_manifest.json` was not refreshed. No merge of `cursor/cb12`, `cursor/cb13`, `cursor/cb14`, `cursor/cb19`, or any `codex/*` tip. No push of `main`, `master`, or `rc/20261108`. No SSH. No contact with `47.103.124.64`. No production database change. No secret. Version stays 0.1.0 (1).
