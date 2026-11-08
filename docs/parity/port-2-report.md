# port-2 report (branch cloud/port-2, base origin/wip/gm-next)

Nothing here was compiled or run (no Swift toolchain in the cloud container). All symbols were checked by grep.
No routes, endpoints, leases, approvals, gates, Resources/ or xcstrings were touched. Forbidden files untouched.
New string keys are listed in docs/parity/port-2-new-strings.md (until added, the UI shows raw keys).

## Per page
1. **couponInfo** (CouponManagementView): added validity span badge (days/hours/minutes, source `cdr__badge`) in the range editor.
   Files: Core/CouponValiditySpanPort.swift, App/CouponValiditySpan+Port.swift, hunk in App/CouponValidityRangeEditor.swift, Port2CouponValiditySpanTests.
   Still missing: template create/edit save endpoint (gated by design), "time set" toast, inline retry action on submit error.
2. **merchant/relation** (CoopRelationDiscoveryView): merchant cards now render business hours, free/paid + capacity tags, suitable activity types (Core already parsed them but the view dropped them).
   Files: App/CoopRelationCardDetails+Port.swift, one-line hunk in card(), Port2CoopRelationVenueTests.
   Still missing: card description, open/closed status, distance, verified-location badge, city role (not parsed in Core), club-card audience layout.
3. **merchant/reviews** (MerchantBusinessViews): list-end marker ("已经到底了") and the four metric sub-captions.
   Files: Core/MerchantReviewListEndPort.swift, hunks in MerchantBusinessViews.swift and MerchantReviewSummaryHeader.swift, Port2MerchantReviewListEndTests.
   Still missing: pending count inside the "pending" filter label, public-mode compose form is elsewhere (PublicMerchantReview*), reply/report flows already exist and were not re-verified.
4. **decor/perks** (MerchantPerkTemplatesView.swift; mapped file MerchantOperationsViews.swift only hosts the home): form hint for first invalid field in source order, validity date picker limited to tomorrow-or-later in China time, discard confirmation (cancel/interactive dismiss) when form is dirty.
   Files: Core/MerchantPerkTemplateFormPort.swift, hunks in App/MerchantPerkTemplatesView.swift, Port2MerchantPerkTemplateFormTests.
   Still missing: form stays open with inline save error/readback-pending state (native closes the sheet on submit), "invalid/expired" copy wording.
5. **topic/merchantinfo** (MerchantContentViews): detail-tab text blocks in the recruit view: subtitle, 主题介绍 description, 活动内容 list (chapters/stations/plays/audio/medal/coupon), mirroring `buildContentIncludes`.
   Files: Core/MerchantTopicIntroPort.swift, App/MerchantTopicIntroSection+Port.swift, one hunk in MerchantContentRecruitView, Port2MerchantTopicIntroTests.
   Still missing: stat bar (buildTopicStatBar), cover/gallery, node-template list, guide-tab chapter meta (time/place/play) and guide blocks, my-chapter-applications offer/circle-supply status lines, check-in QR voucher.
6. **merchant/citynode**: NO CHANGE. Audit-failing CityNodeRedemptionTests (5) assert older loose behavior (e.g. byte-exact server message on 200 without poiId/memberId target); current Core (CityNodeRedemptionOutcome) deliberately requires a matching target and maps otherwise to UNKNOWN. Needs a decision on whether to update tests; not a missing mini-program behavior. List/quota/claim/poster/toggle flows already present.
7. **merchant/decor/index**: NO CHANGE. Home sections, tags (12 max), story limit (300), business-status, gallery limit (9) already modeled in Core/MerchantOperationsDraft.swift and MerchantDecorTagEditor. Not verified: brand-field limits (preference 100), name-required toast parity, save receipt/readback strings.
8. **merchant/customer/detail**: NO CHANGE. Identity line, paid card states, overview metrics, participation, tags/notes (500/16 limits enforced in MerchantBusinessMutation), history, correction/hide actions are already implemented.

## Could NOT verify
Compilation of any change; SwiftUI result-builder placement of the new `else if` after the reviews Load-more button; `Text` key interpolation with `%lld` keys (keys must be added as `%lld` variants); the new tests (run Port2*Tests).
