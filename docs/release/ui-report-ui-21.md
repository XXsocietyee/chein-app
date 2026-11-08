# UI-21 report — NOT COMPILED

Owns: Template*.swift, Publishing*.swift, Approved*.swift (dark / player theme). Reviewed 97 files; changed 18; strings: none (`docs/release/ui-strings-ui-21.json` not needed).

| change | follows | theme | new keys |
|---|---|---|---|
| Raw `.foregroundStyle(.red)` validation/error text -> `CYColor.dangerText`; success checkmarks `.green` -> `CYColor.successText` | CYColor semantic status tokens (dark/light safe, WCAG AA) | dark | none |

## Skipped: already changed by wave 1 (cloud/ui-01..11)
ApprovedReleasePreparationView, ApprovedReleasePublicationConfirmationView, ApprovedReleaseSummaryResultView, ApprovedReleaseSummarySection, TemplateAuthoringMineView, TemplateD6RehearsalView.

## Not changed (deliberately)
- `Color.orange/.white/.gray` in TemplateHotspotPlacementView, TemplatePhotoFrameEditor, TemplateScanResponseEditor: image-editing overlays/placeholders on photo content; `.frame(height: 240)` in PublishingModesViews/TemplatePhotoFrameEditor/TemplateScanResponseEditor are image previews. Left to avoid risk without a compiler.
- `UIColor` in TemplateImageCropRenderer / TemplateMediaReviewController: pixel rendering / test-pattern, not UI chrome.
- Remaining files judged clean or too risky to edit blind.

## Files touched
- App/TemplateAuthoringDetailForms.swift
- App/TemplateAuthoringIntroExperience.swift
- App/TemplateAuthoringPublishResultPresentation.swift
- App/TemplateAuthoringRuleFields.swift
- App/TemplateAuthoringSavedResultPresentation.swift
- App/TemplateAuthoringView.swift
- App/TemplateChoiceOptionRowsEditor.swift
- App/TemplateCreatorConfigurationView.swift
- App/TemplateDailyPoemEditor.swift
- App/TemplateEffectListView.swift
- App/TemplateHotspotPlacementView.swift
- App/TemplateLegacyQuestionRehearsalView.swift
- App/TemplateMultiplayerPlanEditor.swift
- App/TemplatePhotoFrameEditor.swift
- App/TemplatePictureChoiceEditor.swift
- App/TemplatePredictionPlanEditor.swift
- App/TemplateRootAuthoringView.swift
- App/TemplateScanResponseEditor.swift
