# Re-point report 07 (chunk-07.tsv, 34 routes) — NOT COMPILED

Evidence base: `chengyin` checkout at 5e23cd52 (commit 014fc0d8 is NOT in the clone, so "production" is judged by
`origin/cloud/doc-5:docs/release/backend-contract-for-ios.md` Appendix A plus HEAD code). Controllers under
`chengyinhub-admin/src/main/java/com/chengyinhub/web/controller/api/` (J/). grep of all non-test Java and
`chengyinhub-xcx/{pages,utils,components}` found no route, string or feature for: merchant authoring, city-value,
npc avatar generate/status, knowledge-review, voice/script, offer-withdrawal/request/{current,result}, any `mod-*`.

| iOS route | production equivalent | evidence | status | new files |
|---|---|---|---|---|
| merchant/authoring/main-line | none | no controller/xcx hit | TRUE-GAP | - |
| merchant/authoring/player | none | same | TRUE-GAP | - |
| merchant/authoring/player/{}/game | none | same | TRUE-GAP | - |
| merchant/authoring/player/{}/requests/{} | none | same | TRUE-GAP | - |
| merchant/authoring/player/{merchantId}/game | none | same | TRUE-GAP | - |
| merchant/authoring/player/{merchantId}/requests/{requestId} | none | same | TRUE-GAP | - |
| merchant/authoring/public | none | same | TRUE-GAP | - |
| merchant/authoring/releases | none | same | TRUE-GAP | - |
| merchant/authoring/releases/{}/withdraw | none | same | TRUE-GAP | - |
| merchant/city-value/event/{}/benefit | none | no hit | TRUE-GAP | - |
| merchant/city-value/events | none | no hit | TRUE-GAP | - |
| merchant/city-value/report | none | no hit | TRUE-GAP | - |
| merchant/city-value/result/{} | none | no hit | TRUE-GAP | - |
| merchant/crm/customers/61001/contact | fixture id only; real route `POST /api/merchant/crm/customers/{}/contact` is already EXACT | J/ApiMerchantCrmController.java:182 (Appendix A) | FIXTURE (no repoint needed) | - |
| merchant/crm/customers/61001/detail | real `POST .../customers/{}/detail` | ApiMerchantCrmController.java:173 | FIXTURE | - |
| merchant/crm/exports/74001/download | real `GET .../exports/{}/download` | ApiMerchantCrmController.java:288 | FIXTURE | - |
| merchant/crm/exports/74001/status | real `POST .../exports/{}/status` | ApiMerchantCrmController.java:279 | FIXTURE | - |
| merchant/insight | `POST /api/ai/merchant/insight`, no body, token | J/ApiAiController.java:290 (HEAD; :404 in Appendix); xcx pages/merchant/marketing/ai-insight/index.js:105 | REPOINTED (already, by existing `Adapt2MerchantTopicRoutes`; not changed here) | existing |
| merchant/poi/detail | `POST /api/merchant/public-detail`, JSON `{id}`, anon | ApiMerchantController.java:444 (Appendix), :408 HEAD | REPOINTED (existing Adapt2) | existing |
| merchant/shop/apply | `POST /api/merchant/merchant_registration`, JSON | ApiMerchantController.java:2009 (Appendix); xcx pages/merchant/apply/index.js:548 | REPOINTED (existing Adapt2) | existing |
| merchant/npc/avatar/generate | none (xcx only saves a preset/photo `avatar` string via npc/save) | xcx node-npc-form/index.js | TRUE-GAP | - |
| merchant/npc/avatar/status | none | no hit | TRUE-GAP | - |
| merchant/npc/knowledge-review | none | no hit | TRUE-GAP | - |
| merchant/npc/knowledge-review/request | none | no hit | TRUE-GAP | - |
| merchant/npc/voice/reset | `POST /api/merchant/npc/voice/reset` exists at HEAD (ApiMerchantController.java:965) but is NOT in Appendix A (014fc0d8) | iOS already targets it (Adapt2MerchantTopicRoutes.swift:19) | NEEDS-OWNER (is it live in production?) | existing |
| merchant/npc/voice/revoke | closest = voice/reset (same caveat); Adapt2 maps it | Adapt2MerchantTopicRoutes.swift:40 | NEEDS-OWNER | existing |
| merchant/npc/voice/script | none | no hit | TRUE-GAP | - |
| merchant/offer-withdrawal/request | `POST /api/coop/offer/withdraw`, JSON `{offerId, reason}` -> `data.enrollmentPaused`, token, COOP_MANAGE; only the `withdraw` leg exists, `current`/`result` legs have no equivalent (outcome after failure = UNKNOWN) | J/ApiCoopController.java:698-722; xcx pages/topic/merchantinfo/merchantinfo.js:539 | REPOINTED (withdraw leg only) | Core/RePoint07OfferWithdrawal.swift; Tests/CoreTests/RePoint07OfferWithdrawalTests.swift (SYNTHETIC) |
| mod-commerce | none | no hit | TRUE-GAP | - |
| mod-installation | none | no hit | TRUE-GAP | - |
| mod-owned-report/licenses | none | no hit | TRUE-GAP | - |
| mod-settlement/mine | none | no hit | TRUE-GAP | - |
| mod-settlement/mine/income | none | no hit | TRUE-GAP | - |
| mod-upgrade | none | no hit | TRUE-GAP | - |

Notes: no `cloud/be-gNN` branch was visible on origin (`git ls-remote`), so no closest undeployed route is named.
The new adapter is gated (`allowed` defaults false), does not wire itself into any existing Core file, and never
reports "not withdrawn" after a transport/5xx failure. Wiring into the existing flow's UI is left to the owner.

Counts (34 routes): REPOINTED 4 (1 new, 3 pre-existing Adapt2) · TRUE-GAP 24 · NEEDS-OWNER 2 · FIXTURE 4 (real routes already served).
