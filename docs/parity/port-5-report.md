# port-5 report (branch cloud/port-5 from origin/wip/port-build; nothing compiled or run)

## Source availability (same finding as port-3 / port-4, re-verified)
In the second checkout (`chengyin/chengyinhub-xcx`, master 5e23cd52) `subpackageTools/` does not exist, and
`subpackageMember/` has no `character`, `orient-score` or `invoice-apply` directory (none are in app.json either;
`git log --all` shows no history for them). A grep for those page names finds no source. Only
`subpackageMember/couponInfo` exists. Without a source there is nothing to diff, and inventing fields would break the
"no mock data / parity" rule, so those pages were left untouched.

## Per page
- **couponInfo -> CouponManagementView.swift** (commit `PORT-5: couponInfo ...`)
  - Audited against couponInfo.wxml/.js + utils/coupon-form.js. Already native: name, validity range (sheet), quantity, type picker
    (gift / 9折 / 8折 / experience), description, validation blockers, discard-edit confirm, review-before-publish, double-submit guard.
  - Added: validity span badge (N days H hours M minutes) in the editor's dates section (mini-program shows the span beside the picked range).
    Uses existing `CouponValiditySpan.make` / `CouponValiditySpanBadge` and existing string keys; no new strings.
  - Still missing: "时间设置完成" success toast after range confirm; submit-failure inline error with a retry action and a
    network-vs-data kind (native shows issue/server message through CouponManagementNotice); `scope=MERCHANT` publish param
    (template create/edit/publish endpoint stays gated). Native intentionally stricter than the mini-program on quantity
    (rejects non-integers instead of `parseInt || 0`).
  - Unverified: compile; layout of the badge inside the Form section. No new test (no new pure logic; the span logic is covered by Port2CouponValiditySpanTests).
- **capsule, monthly-recap, anniversary, exploration-export** (RoamPassportPrivateToolsViews / RoamPassportToolsViews / RoamExplorationExportView):
  no mini-program source. Not changed. Added: nothing. Still missing: unknown (no reference); known from notes: capsule photo attachment (needs a RetainedImage scope/destination).
- **character** (CharacterCardReadbackView), **orient-score** (OrientScoreView), **invoice-apply** (InvoiceLaunchApplyView): no mini-program source. Not changed.
  Known from page-map notes: character attribute level labels not wired; orient-score not wired into navigation, writes not offered;
  invoice-apply has a failing `InvoiceLaunchCoordinatorTests.testUnknownApplyRecoversOriginalRequestAfterRestartWithoutWrite` (Core safety bug, out of scope for a screen port).

## Recommendation
To do real screen work on the seven source-less pages, point the second checkout at the branch/commit that still contains those
pages (or supply the design docs/PRDs for them). Until then further port waves on them will be no-ops.

## Not verified
Everything is uncompiled. No Resources, xcstrings, routes, leases, endpoints, gates or the three protected App files were touched. New strings: none (docs/parity/port-5-new-strings.md says so).
