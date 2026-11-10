# Design report UI-CLOUD-02

NOT COMPILED (no iOS SDK on this agent). Mobbin search was not available in this environment, so the benchmarks below are the brief's cited screens that match these forms. No extra Mobbin URLs were invented.

## Benchmarks
- Luma event detail (https://mobbin.com/screens/054f5624-ea8a-4bf5-a3eb-ecf64a11805c): one pinned primary action, poster/cover above the facts. Used for the release and review confirms, and for the bank review bar.
- Revolut money form (ui-agent brief): calm dark cards, one primary, tabular amount, progressive disclosure into a confirmation sheet. Used for the dormant bank withdrawal screen. The withdrawal switch stays off.
- Apple inset grouped form: section headers, one hero title, destructive reject kept off the primary style.

## What changed
Presentation only. Player dark via `themeDomain(.player)`. One visible title via `cyHeroScreen` + `CYHeroHeader`. 16pt gutters (`CYSpacing.pageHorizontal` on the bank scroll; inset grouped margin on the forms). One `CYPillButtonStyle` primary per state. Reject stays `CYDestructiveButtonStyle`. Unknown blank strings render as an em dash. A real 0 stays 0 (`String(id)` / version `0` / pending copy when status is 0). Reduce Motion and haptics go through `CYCoverArt`, `CYStateArt`, `CYPillButtonStyle`, and `cyHaptic`.

| Screen | File | Pattern | Theme | New keys |
|---|---|---|---|---|
| Approved snapshot | `App/ApprovedReleasePreparationView.swift` | Luma cover + one primary (review, else check, else reload) | player dark | none |
| Publish confirm | `App/ApprovedReleasePublicationConfirmationView.swift` | one primary, cancel in the bar | player dark | none |
| Saved publication | `App/ApprovedReleaseSummaryResultView.swift` | read-only history, no second close | player dark | none |
| Topic review | `App/ApprovedTopicReviewRequestView.swift` | same primary rule; capture-current replaces check as the only primary when it is shown | player dark | none |
| Bank withdrawal | `App/BankWithdrawalView.swift` | Revolut form, lock cover, review pinned, sheet confirms | player dark | none |

## Self-score (D / I / Inc / V / Inn / S)
| Screen | D | I | Inc | V | Inn | S |
|---|---|---|---|---|---|---|
| Approved snapshot | 8 | 9 | 8 | 8 | 8 | 9 |
| Publish confirm | 8 | 9 | 8 | 8 | 8 | 9 |
| Saved publication | 8 | 8 | 8 | 8 | 8 | 9 |
| Topic review | 8 | 9 | 8 | 8 | 8 | 9 |
| Bank withdrawal | 8 | 9 | 8 | 8 | 8 | 9 |

Under 8: none. Delight is the cover plus the primary haptic, not a new mechanic. Innovation stays inside the existing dormant/confirm flows.

## Skipped
- No view file was missing. None of the five names contain Merchant, Coupon, Ledger, or Settlement.
- `App/ApprovedMerchantReviewSourceSection.swift` was not in the lane and its name contains Merchant, so it was not edited. The review screen still embeds it for source selection.
- No `CloudFixtures_02.swift`. Every screen needs a live controller (`ApprovedReleaseAuthorPresentation`, review flow, or `WalletCommerceReader`).
- No new string keys. `docs/release/ui-strings-cloud-02.json` was not added.
- Core, routes, capability gates, Vendor, and `project.pbxproj` were not edited. Withdrawal, payout, and virtual goods stay off (`adapter?.isAvailable` is still the switch).
