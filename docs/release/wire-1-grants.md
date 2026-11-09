# WIRE-1 grant preparation

The shipped composition is `RegionalLaunchConfiguration.composition`, which calls `shippedComposition`. That function selects `reviewedComposition` only when the build market is China, the base URL is `ReviewedMarketLaunch.chinaProductionBaseURL` (`https://www.chengyinhub.com/prod-api/`), and the bundle and realm can form a storage scope. `Config/China.Production.xcconfig` supplies that URL and `QUESTIFY_SESSION_REALM = cn-prod`. The default target still uses `Config/Base.xcconfig`, whose URL and realm are empty, so that build calls `makeComposition(reviewed: nil, build: .current)`, stays `DeploymentState.unconfigured`, and calls no backend.

The US market has no reviewed host. `admitsShippedChina` returns false for it. `Config/UnitedStates.Production.xcconfig` leaves the URL and realm empty. Nothing is deployed and no production host is contacted. `47.103.124.64` stays disallowed. Password login, bank-card withdrawal, and virtual goods stay off. Payment and payout writes stay behind their own switch.

`ReviewedAppDeployment.ReadGrant` has exactly six cases (`App/AppCompositionRoot.swift`). Together they are the in-scope read groups. Push notifications and webhooks are not among them. No new `ReadGrant` case is added.

A later owner-supplied deployment that covers every in-scope group would pass this set, and only this set:

- `homeAndSearch`
- `manualMap`
- `publicMapLayers`
- `publicTopicTemplateCatalogAndDetail`
- `officialPublicEventCatalogAndDetail`
- `playNodesAndRouteState`

`reviewedDeployment` / `reviewedComposition` still default to `[.homeAndSearch, .publicMapLayers, .publicTopicTemplateCatalogAndDetail]`. The shipped China selection passes all six grants above. Callers that use the helper default still get the three-grant set.

Each value only names a root read family. Transport still requires the existing independent approval (session, market, selected source, or runtime grant). A `ReadGrant` does not create that approval.

## In-scope groups

| Feature group | `ReviewedAppDeployment.ReadGrant` | What that value admits | What it does not admit |
|---|---|---|---|
| Home and search | `homeAndSearch` | `HomeFeedService`; activity-list reads; `POST` `api/common/banner`, `api/category/list`, `api/topic/list`, `api/activity/list`, `api/club/list`, `api/merchant/list`; template metadata `api/common/dict`. Search-map service is also admitted when this value is present. | Signed-in activity/topic detail (`contentDetails`, a separate approval). Mutations. |
| Manual map | `manualMap` | `ManualMapReadRoute` for the selected area, together with `ManualMapReadApproval`. Also admits `MapPublicLayerReadRoute` and `MapPublicLayerService` / `SearchMapService`. | Public-layer reads without a selected area and a live `MapPublicLayerReadApproval`. |
| Public map layers | `publicMapLayers` | `MapPublicLayerReadRoute`, `MapPublicLayerService`, and search-map service, together with a selected area and `mapPublicLayerReadApproval`. Either this value or `manualMap` satisfies the layer check. | `ManualMapReadRoute` itself, which still requires `manualMap`. |
| Public route-template shelf and detail | `publicTopicTemplateCatalogAndDetail` | `POST api/template/topic-template/list` (JSON `{}`) and `POST api/template/topic-template/info` (one positive `id`). Guest or signed-in public viewer. | Standalone games, home/category routes, install/use, publication, and other template mutations. |
| Official public event catalog and detail | `officialPublicEventCatalogAndDetail` | `OfficialPublicEventReadRoute` on a China deployment, and only while `OfficialPublicEventReadSelection` has a live source. The shipped selection is empty. | Any non-China market. A host or login does not select the source. |
| Play nodes and route state | `playNodesAndRouteState` | `GET api/play/nodes` and `GET api/play/route-state` with one positive `activityId` or `topicId`, and only when the session's `playReadConfiguration` carries `.reads` and a `playReadApprovalID`. | Start/complete/answer, pause, hints, leader commands, ending, and other play writes. Character-card reads use the runtime approval and are not opened by this case. |

## Left out of this set

Push notifications and webhooks are not in-scope. No `ReadGrant` covers them, and this preparation does not add one.

- Push notifications stay out. There is no `ReadGrant` for APNs registration, delivery, or the push attempt ledger (`api/im/device/attempts` remains a true gap).
- Webhooks stay out. `api/im/webhook` and `api/im/webhook/context` are not a `ReadGrant` and are not re-pointed onto a live route.

Password login stays off. It is not a `ReadGrant`. In every non-DEBUG build `AppSession.canUsePassword` is `false`, and `AuthEndpoint.password` (`api/login`) is not admitted by home, map, template, official-event, or play reads.

Money-moving writes stay behind their own grants and stay off. None of the six `ReadGrant` values admit them.

- Payout and bank withdrawal stay on `BusinessRuntimeFeature.bankConsentRead`, `.bankPrepare`, and `.bankCreate` (`api/compliance/consents/latest`, `api/fund/preflight/bank-withdrawal`, `api/withdrawal/create`). `AppSession.makeBankWithdrawalContext()` is nil unless those permits exist. The shipped composition does not issue them.
- Asset withdrawal stays fail-closed on `RegionalHighRiskWriteRoute.assetWithdraw` (`/api/asset/withdraw`). Club settlement withdraw (`/api/club/settlement/withdraw`) is not adapted; the RP-03 adapter reads `api/club/settlement/summary` only.
- Virtual goods stay off `WalletCommerceVisibility` (mall defaults false) and off `WalletCommerceCommand` cart/redeem paths, and off `BusinessRuntimeFeature.topicSelfPlayPay` / `selfPlayPayment`. Registration pay stays on the existing high-risk deny list (`/api/registration/pay`, `/api/pay/create`).

Other product surfaces (IM send, club writes, merchant operations, wallet history, orders, coupons, private home) are not `ReadGrant` groups. They stay closed while the shipped deployment is `reviewed: nil`. This preparation does not turn `productionGatesEnabled` on.
