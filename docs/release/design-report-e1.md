# Design report e1 (player discovery + commerce) — STATUS: NOT COMPILED / NOT SHOT

Branch `ui/e1` on rc/20261108 (cfbc9aa75). Contact sheet: none yet (rc did not build; waiting for compiling ui/main).

## Done (unverified)
- DEBUG fixtures `App/DesignFixtures/E1Fixtures.swift`, `E1BundleFixtures.swift` (registry prefix `e1-`): topics, topic-detail, activities, activity-detail, official, registration(+soldout), participants(+empty), discovery, bundle-shelf(+empty/error), bundle-detail(+off).
- TopicBrowserView, ActivityBrowserView, ActivityDetailView, ProfileParticipantsView: kit skeleton/empty states.
- BundleShelfView: image-card shelf + kit states; BundleDetailView: price hero, pinned primary purchase; BundleWalletView: missing count = em dash.

## TEMP commits (drop after merging compiling ui/main)
GrowthLeaderboard dup, CYConfirmSheet ids, RoamStampViews tint, ContentContractV1:520, ObjectBadgeViews:247, CYListRow verbatim init, project regen.

## Left
Official events list/detail/inbox restyle, registration/order/pay summary/cancel/refund, participant form, reviews, shop, bundle wallet/voucher/orders fixtures, zh/XL review, Pillow compares.
