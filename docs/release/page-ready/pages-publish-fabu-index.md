# CB231 PAGE-READY · pages/publish/fabu/index

- Feature: 专业主题编辑器
- Native: `App/ProjectEditView.swift`
- Map status: gated
- Base: `rc/20261108`

`ProjectEditCoordinator` and `ProjectEditHTTPService` already read the existing publish-home and edit-detail contracts. This lane does not add a route or mark one live.
`PublishFabuPageModel` in `Core/ProjectEditService.swift` projects loading, empty, error, and unknown. `ProjectEditCoordinator.fabuPageModel` reads that projection. Unknown and empty text is an em dash (`—`). A literal integer 0 stays `0`. A numeric string stays unknown.
A missing `canProPublish` capability stays hidden. `opensPlayerFirstEntry` stays false, so the player-first entry does not open this page.
DEBUG fixtures already exist: `Core/ProjectEditSyntheticFixtures.swift` and `Core/ProjectEditRemoteFixtures.swift`.
Strings and accessibility identifiers: `docs/release/ui-strings-pages-publish-fabu-index.json`.
No view file is edited. No Xcode Cloud result is claimed.
