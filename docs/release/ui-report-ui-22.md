# UI-22 report — NOT COMPILED

Owns: Profile*, Account*, Settings*, Member*, Private*, Own*, Owned* (125 files in `App/`). Theme: dark (player), role root forces scheme.

Files reviewed: 125 (grep sweep for raw colours, fixed fonts/frames, hard-coded schemes). Files changed: 12. Presentation only; no identifiers, text keys or logic touched.

| Change | Files | Pattern |
|---|---|---|
| Raw `.red/.green/.orange/.blue`, `Color.secondary/primary/accentColor`, `Color.secondary.opacity(x)` replaced by `CYColor.dangerText/successText/warningText/accent/textSecondary/textPrimary/bgSurfaceSubtle` | see list below | design tokens (adapts to scheme, contrast per design-system.md) |

New string keys: 0 (`docs/release/ui-strings-ui-22.json` is empty).
New component files: 0.

Skipped — already changed by wave 1 (ui-01..11): ProfileContactQREditor.swift, ProfileCurrentAvatarView.swift, SettingsAboutView.swift.
Skipped — not changed (intentional): zero-size `Color.clear.frame(0,0)` presenter anchors, fixed 56/88pt avatar frames (decorative, Dynamic Type n/a), UIKit `UIColor` in preview/synthetic/3D scene code, `Color(.systemBackground)` privacy cover, fixture files.
Not done: broader restructuring to List/Form, empty/error states and numeric typography — left alone per "if unsure, do not change" since it cannot be compiled/verified here.

Files touched:
- App/AccountComplianceViews.swift
- App/AccountDeletionAndGDPRPIPLSectionView.swift
- App/MemberSubscriptionAndOrderInvoiceSectionView.swift
- App/MemberTemplateDetailView.swift
- App/ProfileComplaintPreparationView.swift
- App/ProfileLocalCoverSection.swift
- App/ProfileOrderFilterSection.swift
- App/ProfileOrderSourceDetailSections.swift
- App/ProfileOrdersView.swift
- App/ProfileParticipantsView.swift
- App/ProfileTextFieldEditor.swift
- App/SettingsPrivacyLocationView.swift
- docs/release/ui-report-ui-22.md
- docs/release/ui-strings-ui-22.json
