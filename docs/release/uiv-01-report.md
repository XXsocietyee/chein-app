# UIV-01 report — onboarding group (NOT COMPILED)

Standard: docs/release/ui-standard.md; method: ui-agent-method.md. Base origin/ui/own-1.

## Screens
| iOS file | Mini-program page | Reference |
|---|---|---|
| App/UsageConsentGateView.swift | components/cy/privacy-gate, pages/privacy | evidence 012-privacy.png (013-agreement.png not opened) |
| App/PrivacyProtectionView.swift | pages/privacy/index | 012-privacy.png |
| App/WelcomeView.swift | pages/index entry / role choice | none found |
| App/LoginView.swift (+AuthChannelView, WeChatAppAuthSection untouched) | login pages | chengyinhub-xcx login pages NOT reviewed |
| App/LanguageSwitcher.swift | n/a | — (already compliant: 44pt, label, value) |
Role registration is `WelcomeView.roleButton` -> LoginView(intent:).

## Diffs fixed
- Consent gate: text wall replaced by a short summary (new key authEntry.gate.summary) plus a DisclosureGroup (authEntry.gate.details) holding the original full body (id authEntry.gate.body kept); document links grouped in one elevated card with chevrons; ONE primary button (.cyPrimary, neutral brand); Decline is a quiet text button; error uses dangerText + icon (was .red); page uses CYColor.bgPage; CY typography/spacing tokens; all accessibilityIdentifiers kept.
- Welcome: tint (violet risk) icon -> CYColor.textPrimary; hard-coded systemBackground -> CYColor.textOnAccent; chevron contrast on primary card; page background token.
- Login: error `.red` -> CYColor.dangerText with icon (status not by colour alone).
- PrivacyProtectionView: page background token, hidden default form background.

## Diffs left (UIV-TODO)
- Login still a plain Form with TextField/SecureField sign-in as primary-looking row; phone/Apple layout lives in AuthChannelView/AuthChannelAppleButton/WeChatAppAuthSection (not reviewed in detail). Mini-program login pages not compared.
- Welcome: role cards still use QuestifyCardButtonStyle / questifyCardSurface (not CYCard); title copy unchanged.
- Privacy: withdraw/revoke is a destructive Form button without confirmation sheet (CYConfirmSheet) — logic-adjacent, left.
- 013-agreement.png and SettingsLegalDocumentView not touched.
- Dynamic Type/VoiceOver screenshots not possible.

## Compile risks
- New keys are not in Resources/AuthEntry.xcstrings (rule: integrator merges ui-strings-uiv-01.json); until merged the two new strings show their key.
- Uses CYTypography.body/bodyCompact, CYColor.{textPrimary,textSecondary,textTertiary,textOnAccent,bgPage,bgElevated,borderSubtle,dangerText,accent}, CYRadius.md, CYSpacing.{sm,md,lg,xxl,minTouchTarget}, .cyPrimary — all grepped to exist. `.tint(CYColor.accent)` on Toggle/DisclosureGroup assumes Color.
- `documentRow(_ title: LocalizedStringKey…)` used via Text(title, tableName:) — valid init.
