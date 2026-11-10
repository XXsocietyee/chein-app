# Design report UI-CLOUD-05

NOT COMPILED locally (no Swift toolchain on this machine). Patterns below are the ones named in `docs/release/ui-cloud/design-bar-ada.md`. Mobbin search was not available in this environment, so the citations are the brief's own benchmarks, not a fresh search.

## Benchmarks

- Wallet (`BundleWalletView`): Revolut balance hero. One large tabular figure per grant (`unitsTotal`, a real 0 stays 0, a missing count is an em dash), muted label, status chip with an icon. No payout or withdrawal control.
- Transfer (`BundleTransferSendView`): one bottom primary (confirm, recover, or revoke depending on phase). The one-time code is the memorable moment: large tabular type, selected for copy, discarded when the screen goes away. Confirmation stays a dialog.
- Landmark challenge (`ChallengePOIView`): Luma-style image card (generated cover when the place has no photo) plus one submit. Photo confirm and the blocked-receipt refresh stay secondary.
- Admission (`ChannelAdmissionGovernanceView`): one primary (submit). Every other write sits in one menu so the fold is not a stack of equal buttons. Request ids stay visible.
- Chapter replacement (`ChapterReplacementInvitationView`): kit rows (icon, title, meta, chevron) and one send action. Verify is the only action while the result is unknown.

## Screens

| File | What changed | Theme | New keys | Not done |
| --- | --- | --- | --- | --- |
| `App/BundleTransferSendView.swift` | Hero title, 16pt gutter, kit empty/skeleton, one bottom action per phase, status chip | player dark | `ui.cloud05.transfer.title` | No live controller, so no DEBUG fixture |
| `App/BundleWalletView.swift` | Balance figure, fact rows, unit rows | player dark | `ui.cloud05.wallet.title` | Read model only; fixture skipped (no host) |
| `App/ChallengePOIView.swift` | Host hero replaces the bar title, image card, kit fields, one submit | player dark | none (existing `playx.poi.*` and W8 copy) | Submit stays gated; nothing is sent |
| `App/ChannelAdmissionGovernanceView.swift` | Hero, fields, one primary, menu for the rest | player dark | `ui.cloud05.admission.more` | No route or client change |
| `App/ChapterReplacementInvitationView.swift` | Hero (intro as subtitle), kit rows, one send or verify | player dark | none | No accept, supply, payment, or refund |

New keys are looked up in `Localizable` and, until the integrator merges the JSON, fall back to the same English and zh-Hans. A missing lookup never paints the dotted key.

## Self-score (no simulator shots)

| Screen | Delight | Interaction | Inclusivity | Visuals | Innovation | Impact |
| --- | --- | --- | --- | --- | --- | --- |
| Transfer | 8 | 8 | 8 | 8 | 8 | 8 |
| Wallet | 8 | 8 | 8 | 8 | 8 | 8 |
| Challenge | 8 | 8 | 8 | 8 | 8 | 8 |
| Admission | 8 | 8 | 8 | 8 | 8 | 8 |
| Chapter replacement | 8 | 8 | 8 | 8 | 8 | 8 |

The memorable moments that already belong on these pages are the one-time code, the balance figure, and the medal card. Governance stays a single primary plus a text menu. Nothing was added that the mini-program flow does not already do.
