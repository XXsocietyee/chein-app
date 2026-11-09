# CB282 pages/crop/index

PAGE-READY for 图片裁剪工具页. Native screen `App/TemplateImageCropView.swift`. Map status stays exists. No route was added and none was marked live. `CropPageModel.routeInstalled` and `routeMarkedLive` stay false. Nothing is sent. No upload was added.

The existing contract is local `cropInit` / `cropDone` plus `MiniCropSession`. `Core/MiniCropGeometry.swift` and `MiniCropSession` were already on rc. This lane adds `CropPageModel` in `Core/MiniCropSession.swift`. It does not change confirm, clamp, or the 0×0 unset frame.

Phases: `loading` (waiting, including an opener with no paths yet, and a session whose frame is still unset), `empty` (no opener, or a literal empty path list), `error` (source error, a failed flag, a non-positive measured size), `unknown`, `ready`. A nil count, a nil size, a numeric string, `NaN`, and the ratio or source token `UNKNOWN` display as `—` (U+2014), never `0`. A literal `0` stays `0`. One image has no progress fraction. A batch position that is missing is `—`, never `0/0`. Index `0` of two images is `1/2`.

`shape == "circle"` records `round`. `merchant == true` records `merchantLight` only. `showsMerchantChoice`, `paymentEnabled`, `payoutEnabled`, `withdrawalEnabled`, and `virtualGoodsEnabled` stay false. `uploadEnabled` stays false.

Views, string catalogs, ui-strings JSON, `Questify.xcodeproj`, and `tools/current_ci_manifest.json` were not edited.

## Missing EN+zh-Hans keys

These keys are referenced by `CropPageModel.Copy` and are not in `Resources/Localizable.xcstrings`. This lane did not add them.

- `pages.crop.loading`
- `pages.crop.empty`
- `pages.crop.error`
- `pages.crop.unknown`
- `pages.crop.busy`
- `pages.crop.retry`

These source strings have no entry in `Resources/Localizable.xcstrings`.

- `正在准备图片`
- `正在准备要裁剪的图片`
- `没有可裁剪的图片`
- `图片没能打开`
- `这张图片暂时无法读取，请重试或使用原图`
- `裁剪没有完成`
- `裁剪结果没有生成，请重试或使用原图`
- `裁剪范围无效，请调整图片后重试`
- `裁剪工具暂时不可用，请重试或使用原图`
- `图片载入失败，请重试或使用原图`
- `图片尺寸无法识别，请重试或使用原图`
- `使用未经裁剪的原图`

These sentences exist only under another page's key, so this page still has no key of its own: `请返回重新进入` (`publisherPricing.goBackAndOpenItAgain`), `返回上一页` (`cooperation.settlement.back`, `team.page.goBack`), `还原` (`profile.localCover.cropReset`), `处理中` (`merchant.business.bucket.PROCESSING`, `officialAction.working`), `重试裁剪` (`profile.localCover.cropRetry`).

Keys that already exist and were not edited: `publishParity.crop.title`, `cancel`, `confirm`, `useOriginal`, `failed`, `ratio`, `progress %lld %lld`, `template.imageCrop.title`, `localOnly`, `reset`, `confirm`, `image.crop.preview`, `horizontal`, `vertical`, `zoom`, `image.retained.failed`, `image.retained.cancel`.

## Tests

`python3 Tests/ContractChecks/test_pages_crop_index.py`. Existing `MiniCropSession` tests were not removed or rewritten. `MiniCropGeometryTests` still has five `func test` methods. Swift was not run. `xcodebuild` was not run.

## Left

`App/TemplateImageCropView.swift`, `App/MiniCropView.swift`, `App/MerchantImageCropView.swift`, and `App/CreatorCropExportView.swift` do not read `CropPageModel`. `MiniCropGeometry` still treats an unparsable ratio, including `UNKNOWN`, like `free`; only the page model keeps that token unknown. The circle mask and the merchant light theme are recorded and not drawn. `template.imageCrop.localOnly` is catalogued and not shown. `image.crop.confirm` still says upload in the catalog; this page does not use that key and does not send.
