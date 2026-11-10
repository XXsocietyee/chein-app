# wired-sl6 (e5: system / search / launch rows of view-requests-91)

Base: ui/main d7913357f merged into liboyang42-cpu/DES-e5. The request file carries no family column, so the rows were chosen by topic: system, legal, privacy, search/discovery, launch and capture pages. Settings rows (`shezhi/*`, about, marketing consent) were left to SL4 (ME/settings).

Rule applied: a row is wired only where the view already displays the field the model projects. Adding a new label, list or row would be a layout change and was not done.

| page | view | model.property | displayed field today | result |
| --- | --- | --- | --- | --- |
| `pages/crop/index` | `TemplateImageCropView` | `CropPageModel.facts` | none (sliders and a retained-failure note only; no count, size or progress text) | not wired, no field to swap |
| `pages/deregister/index` | `AccountComplianceViews` | `DeregisterIndexPageModel.page` | application id (a real id, not a projection) | not wired, no count or money text |
| `pages/privacy/index` | `PrivacyProtectionView` | `PrivacyProtectionPageModel.reload` | none; usage-record count is not rendered and the route stays hidden | not wired |
| `pages/template/index` | `DiscoveryTemplateBrowserView` | `TemplateIndexPageModel.beginLoad` | none; no row count or home total text | not wired |
| `subpackageMember/free-explore/index` | `FreeExploreBundleLaunchView` | `FreeExploreBundlePageReady.screen` | available-chapter count in the header chip (already an em-dash-free chip, hidden at 0) | not wired; money facts (price, paid, refund) have no label in this view |
| `subpackageP3/pages/stamp-camera/index/index` | `RoamStampCameraView` | `StampCameraPageReady.project` | caption counter `n/30` (local text length, unrelated to the album count) | not wired |
| `pages/agreement/index` | `SettingsLegalDocumentView` | `SettingsLegalAgreementPage.facts` | none | not wired |

Result: 0 of 7 rows wired. Every one of these views is a label-only screen today; the models project counts and money that the views never show. Wiring them needs a view request to add the field (layout change), which this task excludes.

Other lanes (not touched): SL3 social, IM, club, coop rows; SL4 ME, settings, wallet, orders rows; merchant rows; Roam and Tools rows.
