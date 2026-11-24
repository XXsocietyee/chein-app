# Restyle R4: me & account (native iOS r1)

- Branch: `restyle/r4-me-account`, from `origin/ui/combined-r6` (`f1115875e`).
- Brief: `design/handoff-r2:docs/briefs/restyle-native-r1.md`.
- Spec: `design/native-ios-r1:docs/design/native-ios-r1.md` (read before the last commits; followed where more specific).
- Scope: the R4 prefixes (`Profile`, `Account`, `Settings`, `Wallet`, `Ticket`, `Member`, `Bundle`, `Own*`, `Retained`, `Unified`, `Approved`, `Reviewed`, `Invoice`, `Coupon`, `Order`): 231 files.
  - `TicketWalletDetailView.swift` (P5) was excluded.
  - No `App/DesignSystem/*`, `App/Theme/*`, port-owned file, `project.pbxproj`, `Localizable.xcstrings` or CI file was touched. No new strings were added.
- Visual and structural changes only. Every request, state, navigation target, identifier and piece of MP copy is unchanged.

## Files changed (63 App files + 2 contract checks)

AccountCollectionFavoritesView, AccountComplianceViews, AccountDeregistrationImpactSection, AccountView, ApprovedReleaseOriginalRecovery, ApprovedReleasePreparationView, ApprovedTopicReviewRequestView, ApprovedTopicSelectedCoverSection, BundleCancelView, BundleDetailView, BundleExitSwapView, BundleOrderStatusView, BundleOrderSummarySheet, BundlePayResultView, BundleRenewalIntentView, BundleReservationsView, BundleReviewComposeView, BundleShelfView, BundleTransferClaimView, BundleVoucherView, CouponCodeView, CouponManagementView, MemberHomeHeader, MemberReportProgressDetailView, MemberScoreAppealListView, MemberSubscriptionAndOrderInvoiceSectionView, OrderCardComponents, OrderCenterEntryView, OrderLifecycleView, OwnMediaAudioPreviewView, OwnMediaImagePreviewView, OwnMediaModelPreviewView, OwnedOrderComposition, OwnedTopicCoverAuthorView, OwnerDraftBrowserView, ProfileAvatarDraftSection, ProfileBadgesView, ProfileCasePictureRemovalEditor, ProfileContactQREditor, ProfileCurrentMediaPreview, ProfileEditView, ProfileFavoriteRemovalView, ProfileIdentityShareSection, ProfileLocalCoverSection, ProfileOrderMeetingPointView, ProfileOrdersView, ProfileParticipantsView, ProfilePreferenceRemovalEditor, ProfileTextFieldEditor, RetainedPublicReviewImages, SettingsAboutView, SettingsInvoiceEntry, SettingsLegalDocumentView, SettingsSupportSections, SettingsView, TicketPassPresentView, TicketPassSheet, TicketWalletView, UnifiedDecisionsU01ToU08SectionView, UnifiedReleaseAuditHubView, WalletCommerceViews, WalletEarningsOverview, WalletIncomeAnalysisView.

Tests: `Tests/ContractChecks/test_accessibility_hardening_wave.py` and `test_native_ui_accessibility_semantics.py` now check for the new `.cyText` literals instead of the old `CYTypography` ones.

## Before → after patterns

| area | before | after |
|---|---|---|
| Titles | 30 pushed pages with no title mode set; the Settings sheet root used `.large` | `.navigationBarTitleDisplayMode(.inline)` on all of them, including Settings (spec §3.1, §4.11; plan Q2) |
| Sheets | 33 sheets without detents: Login, Settings, cooperation, compliance, NPC data, previews, profile editors, participants, meeting point, review images, release/review confirmations | `Group { … }.presentationDetents([.large] or [.medium, .large]).presentationDragIndicator(.visible)`. Sheets already built on `CYConfirmSheet` or `CYSheet` were left alone. |
| Sheet chrome | `presentationCornerRadius(CYRadius.sheet)` / `presentationBackground(sheetGlass)` at the call sites in AccountView and CouponManagementView | removed, so these use the system sheet (spec §3.4) |
| Type | 29 static `.font(CYTypography.x)` / `Theme.Font.body` on text | `.cyText(.x)` (scales with Dynamic Type); numbers use `monospacedDigit: true` |
| Type floor | `.caption2` (4 text sites, 2 icons) | `.caption` |
| Truncation | ticket place `lineLimit(1)` | `lineLimit(2)` |
| Radius | cards at 16 (`CYRadius.lg`, `Theme.Radius.lg`, literal 16/14); literal 8/10/12 | `CYRadius.md` (12) for cards and `CYRadius.sm` for inner tiles; the wallet ledger hero goes from 24 to `CYRadius.xl` (20) |
| Shadows | ticket stub `black@35% r10`, ticket pass `black@40% r16` | `black@12% r6 y2` |
| Buttons | `CYPillButtonStyle`, `.questifyPrimary`, `.cyPrimary`, `CYDomainPrimaryButtonStyle`, `.cySecondary` in compliance, bundle cancel, coupon code, member header, orders, local cover, wallet earnings/income and order review | `.borderedProminent` + `.controlSize(.large)` + capsule (primary), `.bordered` + capsule (secondary), `.borderless` (tertiary) |
| Sign out | Me page: destructive red full-width button | neutral centred row, matching Settings (spec §3.6). It still asks for confirmation through the existing sheet. |
| Language | `Picker(.menu)` | `.pickerStyle(.navigationLink)` with the existing footer (spec §4.11) |

Already native on the base (no change needed): the Me root and Settings are already `Form`s with sections; there are no custom back chevrons and no hidden back in R4 files; there are no `.font(.system(size:))` calls; and destructive actions already go through `CYConfirmSheet` reviews.

## Gates (local, this branch)

- `python3 -B tools/check_scaffold.py`: PASS.
- `python3 -B tools/check_typography_lint.py`: PASS. `Theme.Font` went from 63 to 59 and 4 counts are now below the baseline; the baseline was not ratcheted (P6 owns it).
- Contract checks (each `Tests/ContractChecks/test_*.py` run standalone): 184 failing, exactly the same set as `ui/combined-r6`, so **0 new**.
- `tools/contract_ratchet.py --check`: 185 failing against a baseline of 184. The one new failure is `test_workshop_paid_professional…bounded_paging`, which also fails on combined-r6 (see the A0 receipt), so R4 adds none.
- No Swift toolchain in this container, so the Swift sources were not compiled. The edits reuse existing APIs only:
  - `Group` around sheet contents (local `let` in a ViewBuilder needs Swift 5.4 or later);
  - `.cyText(_:weight:monospacedDigit:)`;
  - `View.monospaced()`, which needs iOS 16.4 (the target is 17.0);
  - the system button styles.

## Acceptance

- Routes: `docs/port/accept/r4-me-account.txt` (20 fixture routes: Me, member card, Settings and its search, profile edit, tickets, ticket present, wallet assets/income/analysis, order info, participants, favorites, invoice apply/history, bundle detail, coupons, privacy-location, agreement, account cancellation).
- **Not run.** `.github/workflows/acceptance.yml` is only on `ci/acceptance`. It triggers on `port/**`, `ui/combined-r7` and `ci/acceptance`, so a push to `restyle/**` does not start it. `gh workflow run` is not available here (the A0 receipt also got HTTP 403). The first acceptance run will be the integrator's on `ui/combined-r7`, or a dispatch once the workflow is on this base and allows `restyle/**`.

## Component requests (for R6 / R0)

1. `CYDomainPalette.bgPage` → `Color(.systemGroupedBackground)`, and drop `.scrollContentBackground(.hidden)` from `cyScreenStyle`. R4 pages still call `cyDomainPageBackground()` and `cyDomainScreen`, so the system grouped background comes in centrally (spec §2.2, §3.2).
2. `cyPlayerSheetGlass()` → retire, or reduce to `.themeDomain(.player)` (spec §3.4). About 10 R4 call sites keep it.
3. `CYPillButton` (≈ 98 R4 call sites) → re-point to the system styles as in spec §3.6. The call sites were not rewritten.
4. `CYEmptyState` / `CYErrorState` / `CYStateView` (≈ 93 R4 sites) → `ContentUnavailableView` inside the kit (spec §3.5). R4 relies on the kit change.
5. `appNavigationTitle` defaulting to `.inline` (spec §3.1) would make the explicit modes added here redundant, but harmless.
6. `CYRadius.card` / `.hero` / `.inner` names (spec §2.3): R4 uses `md` / `xl` / `sm` until they exist.

## Left (not done in this round)

- Me root restructure (spec §4.5): a profile header row, a passport 3-up stats row and at most 4 link sections. It needs the new `cyCardRow` and a section regrouping, which is a larger structural change.
- Settings as a push from the gear instead of a sheet (spec §4.11). Settings is still a sheet: its `SettingsGuideHandoff` relies on the sheet dismissing, so moving it changes navigation behaviour.
- `CouponManagementView` full-width compact pills, `OrderLifecycleView` `CYOrderActionButtonStyle`, and the `ApprovedReleasePreparationView` ternary pill style. Each needs a label-level rewrite to get a full-width system style.
- Explanatory grey rows → section footers, and `LabeledContent` for key/value facts (spec §3.2), across the wallet, invoice and bundle pages.
- 13 monospaced `.caption` ID/receipt texts in the `Unified*` audit hubs stay monospaced (they are developer-facing hubs).
