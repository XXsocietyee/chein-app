# UI-14 report (Merchant[O-Z]*.swift, light theme) — NOT COMPILED

Files reviewed: 65 (App/Merchant[O-Z]*.swift). Files changed: 11. New component files: 0. New string keys: 0 (no ui-strings file needed).

| file | change | pattern | theme |
|---|---|---|---|
| App/MerchantOfferWithdrawalOriginalView.swift | raw `.orange`/`.red` foreground replaced by `CYColor.warningText`/`CYColor.dangerText` | design-system status tokens (AA contrast, light/dark) | light |
| App/MerchantOfferWithdrawalView.swift | raw `.orange`/`.red` foreground replaced by `CYColor.warningText`/`CYColor.dangerText` | design-system status tokens (AA contrast, light/dark) | light |
| App/MerchantOnboardingView.swift | raw `.orange`/`.red` foreground replaced by `CYColor.warningText`/`CYColor.dangerText` | design-system status tokens (AA contrast, light/dark) | light |
| App/MerchantOrdersView.swift | raw `.orange`/`.red` foreground replaced by `CYColor.warningText`/`CYColor.dangerText` | design-system status tokens (AA contrast, light/dark) | light |
| App/MerchantPerkValidityCalendar.swift | raw `.orange`/`.red` foreground replaced by `CYColor.warningText`/`CYColor.dangerText` | design-system status tokens (AA contrast, light/dark) | light |
| App/MerchantPredictionInboxView.swift | raw `.orange`/`.red` foreground replaced by `CYColor.warningText`/`CYColor.dangerText` | design-system status tokens (AA contrast, light/dark) | light |
| App/MerchantPredictionWorkbenchAlert.swift | raw `.orange`/`.red` foreground replaced by `CYColor.warningText`/`CYColor.dangerText` | design-system status tokens (AA contrast, light/dark) | light |
| App/MerchantStationServiceTimeFields.swift | raw `.orange`/`.red` foreground replaced by `CYColor.warningText`/`CYColor.dangerText` | design-system status tokens (AA contrast, light/dark) | light |
| App/MerchantStoreCharacterView.swift | raw `.orange`/`.red` foreground replaced by `CYColor.warningText`/`CYColor.dangerText` | design-system status tokens (AA contrast, light/dark) | light |
| App/MerchantStoreIndustryPicker.swift | raw `.orange`/`.red` foreground replaced by `CYColor.warningText`/`CYColor.dangerText` | design-system status tokens (AA contrast, light/dark) | light |
| App/MerchantWorkbenchReminders.swift | raw `.orange`/`.red` foreground replaced by `CYColor.warningText`/`CYColor.dangerText` | design-system status tokens (AA contrast, light/dark) | light |

## Skipped
- Already changed by wave 1 (cloud/ui-01..11, a..h): App/MerchantPerkTemplatesView.swift, App/MerchantReviewSummaryHeader.swift (the latter still has `Color.orange` stars).
- App/MerchantOfferWithdrawalOriginalView.swift keeps `.preferredColorScheme(domain.colorScheme)` and `Theme.Generated` colours: separate domain-theme mechanism tied to view/composition logic; left untouched (not presentation-only to swap).
- App/MerchantOnboardingModel.swift `UIColor.white` is image-flattening logic, not UI colour; left.
- Remaining files judged clean or logic/fixture/copy/model files; no structural rewrites attempted since nothing can be compiled.
