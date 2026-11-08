# UI-13 report — Merchant[E-N]*.swift (light theme) — NOT COMPILED

Owned: 55 files matching `App/Merchant[E-N]*.swift`. Reviewed all by scanning for raw colours, fixed fonts/heights, per-view colour scheme, literal spacing.

| file | change | pattern | theme | new keys |
|---|---|---|---|---|
| App/MerchantGameNodeView.swift | toast and status-chip literal paddings -> `CYSpacing` tokens | tokens | light | none |

Skipped (changed by wave 1): `App/MerchantHomeView.swift`, `App/MerchantNPCFieldEntry.swift`.
Left as-is (intentional): `MerchantNPCPresetPicker.swift` Color(.sRGB…) builds pixel-art avatar colours from data, not UI chrome; `MerchantImageCropView.swift` UIColor.white is the crop bitmap fill, not UI; `MerchantNPCTranscriptScroll.swift` 1pt scroll anchor; `MerchantNPCPresetPicker` 144pt artwork frame is fixed-aspect art.
All other files had no raw colours, no per-view `.preferredColorScheme`, no fixed text heights; left untouched.

Could not do: no compile or screenshots available; no further changes judged safe.
Files touched: 1 edited + report + strings (empty). New component files: 0. New string keys: 0.
