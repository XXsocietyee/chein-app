# Design report UI-CLOUD-03

NOT COMPILED locally. Player dark. Presentation only.

Mobbin search was not available in this environment. Patterns below are taken from the coordinator brief (Eventbrite / Viator / Luma: one full-width primary, status shown as icon plus text, image-led header) and from `CityTaskCard`, `ActivityBrowserView`, and `DiscoveryTemplateBrowserView` (kit card, one pill, skeleton / empty / error, `CYImageCard` cover language). These bundle screens have no photo, so the header is `CYCoverArt` (DEBUG-labelled generated art) plus one `CYHeroHeader` (`cyHeroScreen`).

| Screen | Follows | Theme | New strings | Notes |
|---|---|---|---|---|
| `BundleAppealView` | Appeal form. Same reason picker, note cap, evidence count, review disclaimer, and the same submit / read-back actions. | dark | `cloud03.appeal.title`, `cloud03.appeal.submitting` | One enabled primary. Submit stays on screen and disables while locked. |
| `BundleCancelView` | Cancel quote flow. Waiver toggle, quote, confirm, back, refresh, unavailable. | dark | `cloud03.cancel.checking`, `cloud03.cancel.cancelling` | Confirm stays destructive. No client-side time math. |
| `BundleOrderStatusView` | Receipt banner plus order number, registration number, legacy line, activation key. | dark | `cloud03.order.title`, `cloud03.order.empty` | No paid claim. Recheck only for still-unconfirmed and read-unavailable. |
| `BundleRedeemResultView` | Success / review / rejected / none / processing, plus unavailable and retry. | dark | none | Server reason only. Success haptic is gated on Reduce Motion. |
| `BundleRefundQuoteView` | Quote only. Route, amount, ratio, values, after-sales pointer, policy. | dark | none | No action control. Server figures pass through. `0` and `0.00` stay. |

Skipped: none of the named files were missing, and none contain Merchant, Coupon, Ledger, or Settlement.

## Self-score (1–10)

| Lens | Score | Why |
|---|---|---|
| Delight | 8 | Generated cover plus one gated haptic on appeal submit, cancel confirmed, and redeem success. No extra motion on the quote. |
| Interaction | 9 | One primary per state. Quote screen has no control. Native picker, field, toggle, destructive confirm. |
| Inclusivity | 9 | Text styles, no fixed text heights, 44pt targets, labels on custom controls, icon plus text for status. |
| Visuals | 8 | 16pt gutters, dark surfaces, kit rows and chips. Cover is generated art because these screens have no photo. |
| Innovation | 8 | Honest quote and unknown dash. Not a map or stamp surface, so nothing extra was invented. |
| Social impact | 9 | Unknown is an em dash. A real 0 stays 0. Appeal copy still says review, not refunded or consumed. Quote cannot apply a refund. |

Nothing under 8.
