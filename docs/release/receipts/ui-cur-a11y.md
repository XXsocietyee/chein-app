# ui/cur-a11y

Handover 42. Accessibility only, for screens added on `ui/main` since `04b244ff992b9b908b477ace5b5437c50d565759`. Parent is the `ui/main` tip this branch was cut from. `App/RegionalLaunchConfiguration.swift`, `App/AppSession.swift`, and `App/AppCompositionRoot.swift` are unchanged. `ReviewedAreaSwitch` was not redeclared. The contract baseline was not raised. The completeness matrix was not imported.

VoiceOver gets a label, a hint, and a trait (button, header, selected, or static text). Rows that sit side by side stack at Dynamic Type XXL and above, and text uses `lineLimit(nil)` with vertical `fixedSize` so it wraps instead of clipping. Controls use a 44pt minimum hit target. Text uses existing `CYColor` tokens (`textPrimary`, `textSecondary`, `dangerText`). No new color system. An em dash on screen is spoken as Unknown / 未知 (`curA11y.unknown` in `Resources/CurA11y.xcstrings`, English and zh-Hans).

`tools/check_a11y.py` is wired from `tools/check_scaffold.py` the same way as `tools/check_design_lint.py`, and from the `a11y-lint` job in `.github/workflows/ios-ci.yml` the same way as `design-lint`. The lint checks only the screens in this pass. It does not fail the build for the rest of the tree.

This VM has no `swiftc`. Nothing here is a typecheck, a compile, or a VoiceOver / Dynamic Type render.

## Changed (18)

- `BeGapImDesk` — read and write buttons, four fields, and the server text. Unknown server text is spoken as Unknown.
- `BeGapMerchantHubView` — switch rows, gate rows, address and status (visual em dash, spoken Unknown), and the payment note.
- `ClubGapBoardView` — each path title, result, Send, and the merchant invite. Unknown results are spoken as Unknown.
- `ExternalGameCatalogSection` — catalog heading, notice, install, and My submissions. Meta that used `textTertiary` now uses `textSecondary`.
- `ExternalGameSubmissionsScreen` — review status, cancel, resubmit, and reject reason. A dash in the status or reason is spoken as Unknown.
- `ExternalGameAgeGateSheet` — cancel and confirm, 44pt, with hints.
- `ExternalGameReportSheet` — reason, details, block toggle, cancel, and send.
- `IMRecipientPreviewRow` — section heading and each preview line. A dash value is spoken as Unknown. The line stacks at XXL.
- `IMRecipientPreviewFixtureScreen` — the DEBUG `im-preview` host keeps the row and adds a heading hint.
- `PlayGapMiscSurfaces` — the five record links.
- `PlayGapDevicePage` — device key, status, challenge, and result.
- `PlayGapHomePage` — label, latitude, longitude, load, save, and result.
- `PlayGapReturnPage` — policy button and result.
- `PlayGapProductPage` — load, each product, the empty dash, and the result. Cash checkout is unchanged.
- `PlayGapSmsPage` — phone, send, and result.
- `PlayTeamBackpackView` — loading, empty, failed, retry, item commands, and the receipt. Missing quantities and unknown receipt fields are spoken as Unknown. Use, discard, and receive stack at XXL.
- `PlayTeamBackpackFixtureHost` — the failed fallback, when the preview model cannot be built.
- `SessionTeamCreateFixtureHost` — the closed-lease fallback. The hosted `TeamCreateView` is older than this range and was not restyled.

## Left in the range (2)

These were added in the same range and are not screens. They have no VoiceOver surface of their own, so they were not edited.

- `ExternalGameCatalogLaunch` — launch modifier. It refreshes the catalog and draws nothing.
- `CYFloatingTabBarClearance` — padding modifier for the floating tab bar. It draws nothing.

The lint also leaves every other App view alone (3015 view types on this tree). That includes pre-existing hosts that only link to a new screen (`PlayExperienceView`, `SettingsView`, `ClubDetailView`) and the older half of `PlayTeamBackpackView.swift` above `PlayTeamBackpackView`.

## Checks

`python3 tools/generate_project.py` registered `App/CurA11y.swift` and `Resources/CurA11y.xcstrings`. `python3 tools/check_scaffold.py` passed, including catalog coverage, the design lint, and `python3 tools/check_a11y.py`. `python3 tools/check_design_lint.py` passed on its own as well. `swiftc` was not run.
