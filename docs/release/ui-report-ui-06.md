# UI-06 report — Profile / settings / auth / welcome / about (player, DARK)

**NOT COMPILED** (written without a Swift toolchain; Cursor to build and screenshot.)

| Screen file | What changed | Follows | Theme | New string keys |
|---|---|---|---|---|
| App/WelcomeView.swift | Title uses `CYTypography.display`, role cards/icon use `CYColor` text/accent tokens, `CYSpacing.xxl` padding, `CYColor.bgPage` backdrop | mini-program entry/role-choice order unchanged | dark (player root forces scheme; UI-01) | none |
| App/LoginView.swift | Form hidden default background + `CYColor.bgPage`; error text `CYColor.dangerText` (was system red) | existing login flow, unchanged | dark | none |
| App/SettingsAboutView.swift | App name `CYTypography.pageTitle` (was fixed largeTitle.bold, clipped at XXL) + header trait; tagline tokens; `CYColor.bgPage` backdrop | settings → about | dark | none |

## Not done
- Role-scheme forcing is UI-01's job; not applied here.
- SettingsView, account deletion, LanguageSwitcher, legal view, onboarding not restyled (time-boxed); LanguageSwitcher already has 44pt target and a11y label.
- No previews added: existing Welcome previews include dark; About/Login have none and need fixtures for their dependencies.

Files touched: 3 source + this report. New components: 0. New string keys: 0.
