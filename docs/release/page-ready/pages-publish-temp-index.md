# pages/publish/temp/index

Page: 节点玩法模板编辑器. Screen: `App/TemplateAuthoringView.swift`. Map status stays `gated`.

`TemplateAuthoringCoordinator` already sends the live draft, publish, and own-list contracts through `TemplateAuthoringContract` and `TemplateAuthoringHTTPTransport`. `/api/template/info` stays live only on `DiscoveryService.playTemplate`. This branch does not add that path to the authoring wire builder and does not mark a route live.

`TemplateAuthoringPageReadiness` is the read-only model phase: loading, empty, error, unknown, and ready. A missing session or a disabled read stays hidden. An unknown duration or use count is `—` (U+2014). A literal `0` stays `0`. Empty strings, bools, and non-canonical digits are not turned into 0.

Evidence: `Core/TemplateAuthoringDomain.swift`, `Core/TemplateAuthoringCoordinator.swift` (`editorReadiness`, `libraryInfoReadiness`), `Tests/CoreTests/TemplateAuthoringPageReadinessTests.swift`, DEBUG `TemplateAuthoringPageFixtureData`, `docs/release/ui-strings-pages-publish-temp-index.json`.

No view file, `Localizable.xcstrings`, project, test plan, or CI manifest was edited. The player-first entry was not opened. Payment, payout, withdrawal, virtual-goods, and merchant-choice flags were not enabled. Xcode was not run.

The editor still inlines two sentences instead of the catalog: “查询原请求结果” and “保存/提审回执不等于审核通过、上架或媒体检查完成。” The view was left unchanged, so those lines do not yet use the catalog Chinese.
