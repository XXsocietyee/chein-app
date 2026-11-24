# Contract Alignment — G2 ops (`club`, `merchant-coop`, `account-publish`)

- **MP Source:** `liboyang42-cpu/hengyin` (`chengyinhub-xcx`)
- **App Base:** `origin/ui/combined-r7` (`Core/` + `Core/MPGap/`)
- **Endpoint Sweep Totals:**
  - `club`: 102 unique MP endpoints (all 102 paths exist in `Core/`)
  - `merchant-coop`: 131 unique MP endpoints (8 not found literally in `Core/`)
  - `account-publish`: 92 unique MP endpoints (3 not found literally in `Core/`)

---

## 1. Mismatches in `Core/MPGap/*` (fixed in this branch)

| MP file:line | MP call | app file:line | difference | fix |
|---|---|---|---|---|
| `pages/merchant/marketing/ai-insight/index.js:194` | `POST /api/ai/merchant/insight` | `Core/MPGap/MerchantCoop/MerchantGapAIInsight.swift:136` | Used `GET /api/merchant/ai-insight?days=` | Change to `POST /api/ai/merchant/insight` with JSON `{days}` |
| `pages/merchant/components/merchant-claim-sheet/index.js:38,123` | `GET /api/merchant/claims/status`, `POST /api/merchant/claims/submit` | `Core/MPGap/MerchantCoop/MerchantGapRemaining.swift:145` | Used `POST /api/merchant/claim` | Change to `POST /api/merchant/claims/submit` + add `GET /api/merchant/claims/status` |
| `pages/merchant/decor/index.js:35-38,523-526` | `POST /api/merchant/update` (phone/wechat), `POST /api/merchant/decor/save` (decor) | `Core/MPGap/MerchantCoop/MerchantGapRemaining.swift:169` | Sent `phone` & `wechat` to `decor/save` | Split `saveBrandContact` (`POST /api/merchant/update`) vs `saveDecorDisplay` (`POST /api/merchant/decor/save`) |
| `pages/club/detail/index.js:3224` | `POST /api/user/follow/action` (`{follow_member_id, follow: 1\|0}`) | `Core/MPGap/Club/ClubGapRemaining.swift:92` | Sent `{targetUserId, action}` | Change body/params to `follow_member_id` & `follow` (`1`/`0`) |
| `pages/team/detail/index.js:344` | `POST /api/team/applications` (`{teamId}`) | `Core/MPGap/AccountPublish/AccountPublishGapModels.swift:129` | Used `GET /api/team/applications?teamId=` | Change to `POST /api/team/applications` with JSON `{teamId}` |
| `pages/publish/fabu/theme-cast.js:312` | `GET /api/topic/cast/voice` (`?topicId=&preset=`) | `Core/MPGap/AccountPublish/AccountPublishGapModels.swift:106` | Used `POST /api/topic/cast/voice` | Change to `GET /api/topic/cast/voice` with query `topicId` & `preset` |
| `components/cy/fe-reference-settlement/index.js:68` | `POST /api/fe/reference-settlement/settle` (`{ids: [Int], voucherNo?}`) | `Core/MPGap/Club/ClubGapReferenceSettlement.swift:68` | Sent `{id: Int}` | Change payload to `ids: [Int]` + optional `voucherNo` |
| `pages/merchant/aftercare/detail/index.js:109` | `GET /api/merchant/aftercare/manual-case-detail?manualCaseId=` | `Core/MPGap/MerchantCoop/MerchantGapOperations.swift:116` | Sent query `id=` | Change query param to `manualCaseId=` |

---

## 2. Missing / Mismatched Contracts in `Core/` on `origin/ui/combined-r7` (for coordinator)

| MP file:line | MP call | app file:line | difference | fix |
|---|---|---|---|---|
| `pages/merchant/bundle-reservations/index.js:123` | `POST /api/free-explore/bundle/merchant/reservation/{id}/no-show` | `Core/` | Prefix literal missing (`MerchantBundleReservations.swift` uses full path or missing) | Verify prefix/route in `MerchantBundleReservations.swift` |
| `pages/merchant/verify-records/index.js:156` | `GET /api/merchant/desk/arrivals/today` | `Core/` | Endpoint not in `Core/` | Add read method to `MerchantBusinessService` if desk arrivals needed |
| `pages/merchant/index/index.js:1468` | `POST /api/merchant/desk/redeem/resolve` | `Core/` | Endpoint not in `Core/` | Add to `MerchantBusinessService` / desk scanner |
| `pages/merchant/coop-center/index.js:178` | `GET /api/merchant/recruit-routes` | `Core/` | Endpoint not in `Core/` | Wire into `CooperationFlowService` / `MerchantCoopCenter` |
| `pages/merchant/reviews/index.js:626` | `POST /api/merchant/reviews/manage/report` | `Core/` | Endpoint not in `Core/` | Add review report action to `MerchantReviewsService` |
| `pages/merchant/reviews/reply-recovery.js:69-71` | `POST /api/merchant/reviews/reply{,/update,/delete}` | `Core/` | Endpoints not in `Core/` | Wire review reply CRUD if un-gated |
| `pages/mylike/mylike.js:399` | `POST /api/city/nodes/{id}/favorite` | `Core/` | Literal prefix not matched | Verify `PlayerGapViews` uses exact path |
| `pages/privacy/index.js:203` | `POST /api/media/asset/{id}/retry` | `Core/ChinaReviewedRouteCapability.swift` | Owner-gated (no mark in capability table) | Keep gated per owner rule |
| `pages/publish/fabu/theme-fe-visit.js:40` | `GET/POST /api/topic/free-explore/visit-config` | `Core/` | Covered by P2 (`FreeExplorationVisitConfig.swift`) | Handled in `port/p2-play-runtime` |
