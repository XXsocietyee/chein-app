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

---

# Round 2 (2026-11-24)

## Base and merges

- Continued on `restyle/r4-me-account` from `fc0344be0` (round 1, above).
- **Merged `origin/restyle/r6-system-rest`** (`aa235bbab`; coordinator decision 2) as `6f388bd80`. One conflict, in `Tests/ContractChecks/test_accessibility_hardening_wave.py` (FPA5): kept both sides' new literals, R4's `.cyText(.data2XL, monospacedDigit: true)` for the wallet and R6's `.cyText(.data2XL)` for Growth. The test passes.
- **`origin/ci/acceptance` NOT merged** (coordinator decision 3). The condition was a green run, and the Acceptance workflow (id 428944264) has 3 runs on `ci/acceptance` (#1 push `af82cad`, #2 push `6edae4a`, #3 workflow_dispatch `6edae4a`), all `conclusion: failure`. I merged it once before checking the runs and then reset it away; that merge was never pushed.
- P5 untouched: `TicketWalletDetailView.swift` and every plan §4 file. No `App/DesignSystem/*`, `App/Theme/*`, `project.pbxproj`, xcstrings or CI file was edited, and no strings were added.

## Batches (all pushed)

| commit | files | what |
|---|---:|---|
| `0c32e9c15` | 17 | **System sheet chrome.** `cyPlayerSheetGlass()` → `.themeDomain(.player)` at every R4 call site (AccountView ×3, TicketPassSheet, SettingsView, BundleDetailView, InvoiceLaunchApplyView, ProfileEditView, OrderLifecycleView ×2), so there is no custom corner or glass background (spec §3.4), with `.cySheet(detents: [.large])` on the ticket wallet / pass / order review sheets. `.cySheet()` on the wallet 更多 and withdrawal-contact sheets, the profile media flow ×2, the favourites note, the identity share and the fixture detail sheets. Inline title mode on the 5 R4 fixture hosts. |
| `cec8832d5` | 23 | **Structural native pass.** BundleWalletView and BundleReservationsView: ScrollView/VStack cards → inset-grouped `List` with `LabeledContent` facts and a system inline title. BundleRenewalIntentView, BundleTransferClaimView and BundleTransferSendView: → inset-grouped `Form`, with section headers, explanations in footers and the sticky CTA on `.bar`. `Cloud03Screen` (shared by 7 bundle commerce screens): system inline title instead of a second in-content hero title, cover at `CYRadius.hero`. 15 screens: in-content `CYHeroHeader` + `cyHeroScreen()` (an empty title) → system inline navigation title (score appeal detail, member template, pass preview, owned template config ×2, owned cover author ×2 / image, favourite removal, meeting point, follow list, ticket team, own media audio/image/model). Their subtitles become secondary rows, and the reserve window title becomes a section header. |
| `995d72436` | 18 | **States and backgrounds.** The order-filter empty, the complaint-source empty and the preference-removal empty → `ContentUnavailableView` (the identifiers, copy and 清除筛选 action are unchanged). Standalone grey explanation rows → section footers (order lifecycle caution, template config scope, ticket team read-only). `.scrollContentBackground(.hidden)` removed from 13 inset-grouped Form/List screens so the system grouped background shows (spec §3.2): Me, Settings and its search results, About, wallet earnings/analysis, ticket wallet, orders detail, order center, order lifecycle, coupons, bundle review host. Plain card feeds keep their page background. |
| `6d5772142` | 24 | **Radius names** (spec §2.3): `CYRadius.lg` / `Theme.Radius.lg` → `CYRadius.card`, `.xl` → `.hero`, `.sm` → `.inner`. The values are the same after R6. |
| `eb4ba6b79` | 1 | **Refresh** (spec §3.1): the duplicated toolbar 刷新 buttons on 我的收藏 topics and posts were removed. `.refreshable` and the error-state retry keep the same guarded refresh. |

Round 2 touched 63 App files, all R4-prefixed: AccountCollectionCouponsView, AccountCollectionFavoritesView, AccountCollectionFixtureSupport, AccountComplianceViews, AccountDeregistrationImpactSection, AccountView, BundleAppealView, BundleCommerceMount, BundleDetailView, BundleOrderStatusView, BundleOrderSummarySheet, BundlePayResultView, BundleRenewalIntentView, BundleReservationsView, BundleReserveWindowView, BundleReviewComposeView, BundleShelfView, BundleTransferClaimView, BundleTransferSendView, BundleWalletView, CouponCodeView, CouponManagementView, InvoiceLaunchApplyView, MemberHomeFixture, MemberHomeHeader, MemberScoreAppealDetailView, MemberSubscriptionAndOrderInvoiceSectionView, MemberTemplateDetailView, OrderCardComponents, OrderCenterEntryView, OrderLifecycleView, OrderPassPreviewView, OwnMediaAudioPreviewView, OwnMediaImagePreviewView, OwnMediaModelPreviewView, OwnedTemplateConfigurationView, OwnedTopicCoverAuthorView, OwnedTopicCoverImageView, ProfileAvatarDraftSection, ProfileComplaintPreparationView, ProfileEditView, ProfileFavoriteRemovalView, ProfileFixtureSupport, ProfileFollowListView, ProfileIdentityShareSection, ProfileOrderFilterSection, ProfileOrderMeetingPointView, ProfileOrdersView, ProfilePreferenceRemovalEditor, ProfileSelfOrdersFixture, SettingsAboutView, SettingsFixtureSupport, SettingsPostGovernanceView, SettingsSupportSections, SettingsView, TicketPassSheet, TicketWalletTeamView, TicketWalletView, UnifiedDecisionsU01ToU08SectionView, UnifiedReleaseAuditHubView, WalletCommerceViews, WalletEarningsOverview, WalletIncomeAnalysisView.

## Contract pins updated in the same commit (decision 1)

- `test_global_chrome_domain_contract.py` (`0c32e9c15`): AccountView, TicketPassSheet, SettingsView and BundleDetailView moved out of the "must apply `cyPlayerSheetGlass`" list. They are now asserted to keep `.themeDomain(.player)` (the sheets stay in the player role) and to have no `presentationCornerRadius`. The other 8 files in that list, and the `RoleTheme` / `CYConfirmSheet` assertions, are unchanged.
- `test_p02_editor_presentation_closeout.py` (`cec8832d5`): the OwnedTopicCoverImageView pin `.cyHeroScreen()` → `.navigationBarTitleDisplayMode(.inline)`. The exact-asset (`sourceVersion`) and close assertions are unchanged.
- No behavioural assertion was removed or weakened. The source-scan rules in `BNDRenewalModelTests` (no price/pay/order vocabulary; `renewal.intentOnly` present) and `BNDTransferModelTests` (no logging/storage APIs, no Invite/Coupon types) were checked against the rewritten views. UI-test identifiers (`profile.orderFilter.*`, `profile.complaint.empty`, `profile.preferenceRemoval.empty`, `bundle*.…`) are kept on the same text elements.
- Hash-pinned "frozen inverse" tests that list R4 files (`test_social_guide_templates.test_exact_shared_file_inverse`, `test_profile_reload_discard.test_exact_inverse_restores…`, and so on) were **already failing in `docs/release/contract-failing-baseline.txt`**: they pin pre-r6 hashes of `Localizable.xcstrings`, `project.pbxproj`, `AppSession.swift` and others. They were not re-pinned.

## Gates (local, after every batch)

- `tools/check_scaffold.py`: PASS.
- `tools/check_typography_lint.py`: PASS (raw text style 32, Theme.Font 36, raw size 53, back chevron 10, hidden back 3, large title 6; all at or below the baseline). The R4 fixture host first got `.large`, which tripped the large-title rule; it was set to `.inline`.
- `tools/contract_ratchet.py --check`: **185 failing, baseline 184, new 1, fixed 0** after each batch. The one "new" failure is the known pre-existing `test_workshop_paid_professional…bounded_paging` (it fails on `ui/combined-r6` too), so R4 adds none.
- No Swift toolchain here, so nothing was compiled. The rewrites reuse existing APIs: `cySheet`, `cyCardRow`, `CYRadius.card/hero/inner` (all from R6), `LabeledContent`, `ContentUnavailableView`, `Section {} header:/footer:`, and `.background(.bar)`.

## Acceptance

- Routes: `docs/port/accept/r4-me-account.txt` (unchanged, 20 routes).
- **Not run.** No green Acceptance run exists to merge (see above). The workflow is not on this branch and does not trigger on `restyle/**`, and this environment cannot dispatch workflows. The first compile will be the integrator's (`ui/combined-r7`), or a dispatch once `ci/acceptance` is green and merged.

## Decided against / left (with reasons)

- **`CYPillButton` call sites (≈ 100 in R4) were left as they are.** Spec §3.6 keeps `CYPillButton` as the call-site API and re-points its style centrally in R0. R6 deferred that re-point until the owner approves colours (R6 receipt §4.2). Rewriting the call sites would split the app into two button looks. The non-pill custom styles were already converted to system styles in round 1.
- **Me root regrouping (spec §4.5)** into ≤ 4 headed sections (钱包与票夹 · 我的内容 · 身份与角色 · 帮助). Only `account.section.collection` and `account.section.orders` exist, so the headers need new catalog strings, which this round does not add. The sections are also separate pinned components (82 contract tests read AccountView). The Me root is already an inset-grouped `Form` with the identity card as a card row and a system large title. → String request for R0/P6.
- **Settings pushed instead of presented as a sheet** (spec §4.11). Still a sheet: `SettingsGuideHandoff` depends on the sheet dismissing, so changing it would change navigation behaviour. Otherwise Settings matches §4.11: Form, inline title, `.navigationLink` language picker with a footer, neutral sign out, `ContentUnavailableView.search`, and now the system grouped background.
- **Toolbar refresh** on coupon detail and owner drafts was kept, because UI tests (`AccountCollectionFlowTests`, `OwnerDraft*FlowTests`) tap those buttons. Coupon-management detail and order lifecycle refresh buttons were also kept, since those pages have no `.refreshable` of their own.
- **Exempt surfaces kept** (spec §3.10): the ticket stub/pass shadow and art, the coupon code, the media previews and the legal document reader stay as ScrollViews. ApprovedReleasePreparationView keeps its cover hero card.
- **`BundleReviewComposeView`** (unmounted) got the system title only; its body stays a ScrollView.

## Component requests (carried over, still open)

1–6 from round 1 still apply, except that #6 (radius names) is now done at R4 call sites. New:
7. Catalog keys for the four Me-root section headers in spec §4.5.
8. `cyPlayerSheetGlass` has no R4 callers left and can be retired once R1–R5 are also off it.

DONE-ROUND-2
