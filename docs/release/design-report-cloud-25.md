# Design report UI-CLOUD-25

Presentation only. Player domain stays dark via `.themeDomain(.player)`. No payout, withdrawal, or virtual-goods control was added. Existing `ModInstallation` string keys are unchanged. New labels are shown as bilingual verbatim sentences so a raw key never appears; the catalog entries live in `docs/release/ui-strings-cloud-25.json` and are not merged into `Resources/*.xcstrings`.

Mobbin was not available in this environment. Benchmarks are the lane brief (Eventbrite event detail, Viator booking, Luma guest list: one hero, one primary, status as a chip, empty and error as a single state) and the in-repo references `App/CityTaskCard.swift`, `App/ActivityBrowserView.swift`, and `App/DiscoveryTemplateBrowserView.swift`.

## Screens

| Screen | Restyle |
|---|---|
| Licensed module install, confirm sheet, fact review, original recovery | `Cloud25Screen`: 16/10 cover, one `CYHeroHeader` (`cyHeroScreen` clears the bar title), 16pt gutters. One primary among prepare / review / confirm facts / recover. Cancel stays a destructive confirmation. |
| Template editor and review sheet | Same chrome. One primary among save / confirm facts / submit / retry / recover. Review confirm is the sheet's only primary. |
| Installed text read | Same chrome. The unconfirmed state is the one primary (`CYEmptyState` failure + reread). Entry button stays secondary. |
| Owned-content report | Same chrome. Confirm is primary while the report action is shown; reread is primary otherwise. The dialog still says no withdrawal, refund, or funds action. |

Skipped: `App/ModSettlementViews.swift` because the file name contains Settlement. It was not opened and not invented.

Unknown and empty display values render as an em dash. A real `0` stays `0`. Nil audit status and nil draft id no longer render as `-1` or `0`.

## Self-score (D / I / Inc / V / Inn / S)

| Screen | D | I | Inc | V | Inn | S | Note |
|---|---|---|---|---|---|---|---|
| Install + recovery | 9 | 9 | 9 | 8 | 9 | 9 | Long status sentences sit in a chip; VoiceOver gets the full catalog sentence. |
| Template editor | 9 | 9 | 9 | 9 | 9 | 9 | Locked copy is a wrapping note, not a truncated chip. |
| Installed text | 9 | 9 | 9 | 9 | 9 | 9 | Field bodies stay in disclosures; terms rows wrap under Dynamic Type. |
| Owned report | 9 | 9 | 9 | 9 | 9 | 9 | One primary. No new money action. |

Nothing scored under 8. Not compiled locally (no Xcode on this machine). Xcode Cloud Build is the check. `App/CityActionBudgetView.swift` is out of lane.
