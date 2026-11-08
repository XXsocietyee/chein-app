# UI-24 report — NOT COMPILED

Owns: Home*, Discovery*, Search*, Square*, Social*, Topic*, Activity*, Official*, Public* (App/*.swift). Theme: dark (player).

## Changed (10 files, presentation only: raw system colours -> CYColor tokens)
| File | Change | Theme |
|---|---|---|
| ActivityPublishingWizardView.swift | `.red` -> `CYColor.dangerText` | dark |
| DiscoveryTemplateDetailParitySections.swift | `.orange` -> `CYColor.warningText` | dark |
| OfficialEventDetailView.swift | paused-task `.red` -> `CYColor.dangerText` (2) | dark |
| OfficialPrivateViews.swift | `.orange` -> `CYColor.warningText` | dark |
| SocialActionViews.swift | `.red` -> `CYColor.dangerText` | dark |
| SocialGraphAndProfilePrivacySectionView.swift | `Color.green/orange.opacity(0.15)` -> `CYColor.successSoft/warningSoft` | dark |
| SquarePostVideoViews.swift | `.red` -> `CYColor.dangerText` | dark |
| SquareReportView.swift | counter `Color.red/secondary` -> `CYColor.dangerText/textSecondary` | dark |
| SquareXcxPostCard.swift | `.orange` -> `CYColor.warningText` | dark |
| TopicXcxSections.swift | `.orange` -> `CYColor.warningText` | dark |

New string keys: 0 (`docs/release/ui-strings-ui-24.json` = empty list).

## Skipped
- Owned by wave 1 (ui-01..11): ActivityPeopleSection, HomeFeedView, HomeSearchTabParityViews.
- Left on purpose: OfficialEventComponents `.preferredColorScheme(domain.colorScheme)` (domain-driven, routing/theme logic, not a presentation-only edit); SearchMapCanvas colours (map overlay tokens/UIColor for MapKit, not CYColor-mappable); fixed `.frame(height:)` on media/player/wheel picker (media aspect, intentional).
- Fixture/Reading/Model/Storage/SessionAccess/Injection files: non-UI, not reviewed for styling.
- Not done (risk without compiler): empty/error-state and typography sweeps across ~80 files; remaining files judged clean by grep for raw colours/fonts.
