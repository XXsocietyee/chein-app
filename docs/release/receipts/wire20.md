# wire20

[x] 00435acf745ba0a36c2d0a848b2527d22c556589

PR 1010. Branch `cursor/wire20`. Parent `ba70d72c4`. Base `rc/20261108`. +266/−6.

`TemplateImageCropView` reads `CropPageModel.facts`. The type is in `Core/MiniCropSession.swift`. A missing count is an em dash. A literal 0 stays 0. Reset, confirm, and use-original stay hidden when the page says they are not available. The screen passes the open draft, so that one image is a known count. The view change is +16/−6. Not merged to rc.
