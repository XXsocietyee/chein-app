# wire34

[x] 56e0a9e5554cd448549312f69d142426f32dd847

PR 1024. Branch `cursor/wire34`. Parent `a9b89c901`. Base `rc/20261108`. +62/−0.

The gallery destination in `App/MerchantOperationsViews.swift` reads `MerchantGalleryPage.facts`. A missing count is an em dash. A literal 0 stays 0. Add stays hidden until the gallery is loaded and an upload host exists. Other destinations are not rewritten. Not merged to rc.
