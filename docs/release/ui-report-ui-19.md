# UI-19 report — Project*.swift (dark / player) — NOT COMPILED

Reviewed 83 `App/Project*.swift` files; none overlap with cloud/ui-01..11 or ui-a..h changes. Most files were already clean (system controls, no raw colours/fixed heights).

| File | Change | Theme |
|---|---|---|
| ProjectEditCompletionRulesForm.swift | `.red` -> `CYColor.dangerText` | dark |
| ProjectEditDetailForms.swift | `.red` -> `CYColor.dangerText` | dark |
| ProjectInitialAttributesEditor.swift | `.red` -> `CYColor.dangerText` | dark |
| ProjectTopicMediaHost.swift | `.red` -> `CYColor.dangerText` (3 places) | dark |
| ProjectChapterAtmosphereFields.swift | `Color.primary.opacity` stroke -> `CYColor.borderStrong/borderSubtle` | dark |

Skipped intentionally: `UIColor.white/systemTeal` in ProjectNodeImageCrop, ProjectTopicMediaInspector, ProjectStoryImageSynthetic (image rendering / synthetic fixtures, not UI chrome); `ProjectChapterAtmosphereFields` preset colours (user-authored data colours, not theme).
New string keys: 0. New component files: 0.
