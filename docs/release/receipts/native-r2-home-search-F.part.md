## Group F: bundle commerce screens (native r2)

| File | What changed |
|---|---|
| App/BundleOrderStatusView.swift | Shared lane chrome: `Cloud03Screen` is now `List` (inset grouped) + inline navigation title (generated cover art and page background removed; `Cloud03Cover` deleted, no other users). New `Cloud03Note` = system `Label` with a tinted SF Symbol (replaces `CYNoteBanner`). Order status: `ProgressView` in the receipt row, `LabeledContent` + `Label` rows, `ContentUnavailableView` for no order, plain `Button` for recheck. |
| App/BundleAppealView.swift | Form-style sections: `Picker`, vertical `TextField`, `Label` evidence row, explanation as the section footer; status rows use `Cloud03Note`/`ProgressView`/`ContentUnavailableView`; submit is `.borderedProminent` `.large`, recovery buttons are separate rows. |
| App/BundleCancelView.swift | `Toggle` section, system `Button`s (destructive confirm), `Cloud03Note`, `ProgressView` loading rows, `ContentUnavailableView` for not open. |
| App/BundleRefundApplyView.swift | `LabeledContent` rows, `Cloud03Note`, one `.borderedProminent` submit. |
| App/BundleRefundProgressView.swift | `LabeledContent` rows; not-refunded note is the section footer. |
| App/BundleRefundQuoteView.swift | Amount row with text styles, route `Section` with header `Label`, `LabeledContent` rows, quote-only notice and policy version in the footer. |
| App/BundleRedeemResultView.swift | `ProgressView`, `ContentUnavailableView` (unavailable / failed + retry), result as a `Label` with a tinted symbol (custom result mark removed). |
| App/BundleDetailView.swift | `List` with sections (price `LabeledContent`, included, merchants, compliance `DisclosureGroup`), bundle name as the inline navigation title (hero art, gradient, parallax, stagger, card chrome removed). Custom buy bar replaced by a bottom bar on `.bar`: borderless total button (opens the summary sheet) + one `.borderedProminent` Buy button with `ProgressView` while paying. `BundleIncludedRow` is a `Label` row. Keeps `.themeDomain(.player)` and system sheet detents. |
| App/BundleOrderSummarySheet.swift | `NavigationStack` + `List` with inline title; `LabeledContent` price rows, compliance line in the footer, `.borderedProminent` Pay button, included section. |
| App/BundlePayResultView.swift | `List` led by a `ContentUnavailableView` result (SF Symbol, title, message; `.contentTransition(.symbolEffect(.replace))`), `LabeledContent` detail rows, `ProgressView` while processing, `.borderedProminent` primary + borderless secondary. Gradient, confetti, entrance motion removed; haptics kept. |
| App/BundleRenewalIntentView.swift | Cover art removed; `ContentUnavailableView` notices; inline `Picker` for the intent; `TextField` note; plain Form buttons; `.refreshable { await model.load() }`. Source scan words (pay/order/…) avoided, so no `.bordered*` button styles here. |
| App/BundleReservationsView.swift | Cover art removed; `ContentUnavailableView` empty / legacy; reservation rows are `Label`s with a tinted status symbol. |
| App/BundleReserveWindowView.swift | `DatePicker` + plain `Button` row; `ContentUnavailableView` when there is no window; custom insets removed. |
| App/BundleReviewComposeView.swift | `ScrollView` + cards → `Form`: menu `Picker`, `TextEditor`, counter in the footer, `ProgressView`, `ContentUnavailableView`, `LabeledContent` summary, tinted status `Label`. |
| App/BundleReviewListView.swift | `ProgressView`, `ContentUnavailableView` (unavailable / failed + retry / empty), inset-grouped list, `.refreshable`. |
| App/BundleShelfView.swift | `ScrollView` of cards → inset-grouped `List` of `Button` rows (thumbnail via `AsyncImage` of the server cover, else SF Symbol), `ContentUnavailableView` states, `.refreshable`. |
| App/BundleTransferClaimView.swift | Cover art removed; `ContentUnavailableView`, `TextField` with `.oneTimeCode` / `.submitLabel`, plain `Button`, `ProgressView`, `Cloud03Note`. |
| App/BundleTransferSendView.swift | `ContentUnavailableView` states, `ProgressView` rows, tinted `Label` state, sticky bottom actions are `.borderedProminent` / destructive `.bordered` with `.controlSize(.large)`. |
| App/BundleVoucherView.swift | `ProgressView`, `ContentUnavailableView` (+ retry), status as secondary `Text`, inset-grouped, `.refreshable { await model.reload() }`. Privacy shield / `privacySensitive` kept. |
| App/BundleWalletView.swift | `ContentUnavailableView` legacy / no-detail, expired as an orange-symbol `Label`, text styles. `.appSwitcherPrivacyShield()` kept. |
| App/BundleCommerceMount.swift | Forced-dark `CYNight.ink0` backgrounds and `.scrollContentBackground(.hidden)` removed; lists inset grouped; `BundleCommerceStatus` = `ProgressView` / `ContentUnavailableView` (+ prominent retry). |
| App/BundleExitSwapView.swift | Palette colours → `Label` with `.secondary` / `.red`; inset grouped; `.themeDomain(.player)`. |
| App/BundleMerchantStallView.swift | Text styles; `ContentUnavailableView` for unavailable. |

Unchanged (no UI): BundleAppealTransport, BundleCancelCanceler, BundleCancelTransport, BundleCommerceReadTransport, BundleComposition, BundleReadTransport, BundleRefundTransport, BundleTransferTransport.

### Not converted / notes
- `App/BundleShelfView.swift`: `.clipShape(.rect(cornerRadius: 8))` on the server cover photo thumbnail only (image clip, as Apple does for artwork).
- Bundle detail buy bar: the MP's pinned price + buy bar has no single Apple control; closest is a `.safeAreaInset` bottom bar on the system `.bar` material with a borderless total button and one `.borderedProminent` button (App Store / Apple Store pattern).
- `BundleExitSwapView` still presents the shared `MemberBundleSwapConfirmSheet` (not in this group).
- `cyAnimation` (state cross-fade, Reduce Motion aware) and haptics were kept; decorative motion (stagger, parallax, confetti, entrance, row transitions) removed.
- No new strings.
