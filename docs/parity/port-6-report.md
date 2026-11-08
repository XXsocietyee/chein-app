# port-6 report (nothing compiled or run — no Swift toolchain here)

Branch `cloud/port-6` from `origin/wip/port-build`. Every symbol was checked by grep; a local worker must compile and test.
New files are NOT in `Questify.xcodeproj/project.pbxproj` (SwiftPM picks them up): add
`App/DiscoveryTemplateBrowserView+Port.swift`, `App/RoamHistoryViews+Port.swift`, `App/PlayExperienceView+Port.swift`,
`Core/TemplateBrowserPort.swift`, `Core/MyProjectSyncPort.swift`, `Core/PlayResyncPort.swift` and `Tests/CoreTests/Port6*Tests.swift`.
New strings (xcstrings untouched): `docs/parity/port-6-new-strings.md`. No routes, leases, endpoints, gates, Resources, AppSession/CompositionRoot/QuestifyApp touched; no test changed.
Note: the requested "Tests/AppUnitTests" pure-logic tests went to Tests/CoreTests (QuestifyCore `@testable`) because all new logic is Core-level.

## pages/template/index -> DiscoveryTemplateBrowserView.swift
- Added: topic rows show the cover (`imgUrl`, https-only) with the "封面暂不可用" placeholder on missing/failed load; "正在同步最新内容…" line when refreshing over loaded rows (first load keeps the spinner); "其他模板 · 不筛掉，继续显示" header hint; "刷新试试" action in the empty state; "正在搜索「x」" prefix on the applied search. Tests: `Port6TemplateBrowserTests`.
- Still missing: banner (single hero) card, bell/inbox header, play-template (games) cover thumbnails and `_iconUrl` art, `TopicTemplateUseSection` host embedding / use-template write (gated).
- Unverified: row HStack layout, `Section { } header:` rewrite, `Text` key interpolation.

## pages/play/index -> PlayExperienceView.swift
- Added: "重新同步本局状态" button (existing `PlayExperienceCoordinator.load()`, which already reconciles pending completions) for read-side issues (stale session, malformed, unknown result, persistence). Test: `Port6PlayResyncTests`.
- Still missing: the 1766-line wxml has ~150 strings with no native equivalent (e.g. 旅程手记, 城市故事 sheet, 同行者榜 empty/loading, 保存为我的主题标签, 扫码到达/动态核销 copy, mini-map sheet, 身份卡). Not attempted: they are tied to separate native hosts (PlayPlayerAndCircleViews, backpack/RPG writes gated, external-game download transport absent) and cannot be diffed safely without a compiler.
- Unverified: load() replaces the snapshot with a spinner during resync (same as the existing refresh button).

## subpackageA/pages/myproject -> CreatorContentViews.swift
- Added: "正在同步最新项目…" line while a same-filter/same-scope reload runs, keeping the previous rows (read-only, no taps) instead of a spinner; stale rows are dropped on filter/scope change or failure. Test: `Port6MyProjectSyncTests`.
- Still missing: long-press ops sheet and writes (gated, so the 长按 hint stays unused), published-address line, `MyProjectMutationStatusView` host embedding.
- Unverified: `@Published` tuple optional in the private generic model.

## subpackageMember/free-explore/index -> FreeExploreBundleLaunchView.swift
- Not changed. There is no `index.wxml/js` for this page in the mini-program checkout (confirmed again; only play/index.js mentions the free-explore play mode, which is a different feature). No source to diff; no refund arithmetic added.

## subpackageRoam/history/index -> RoamHistoryViews.swift
- Added: per-card combined accessibility label matching the mini-program `aria-label` ("{date} {title}, {km} 公里"), reusing existing keys. `Text` concatenation in `App/RoamHistoryViews+Port.swift`.
- Still missing: RunCard cover thumbnail (history photos are local mini-program paths, unusable natively).
- Unverified: label composition and that NavigationLink label override reads well in VoiceOver.

## subpackageP3 stamp-camera -> RoamStampCameraView.swift
- Added: "返回" (existing `action.back`) on a camera error that offers no Settings route, matching `sc-err` 返回上一页.
- Still missing: nothing behavioral found (permission denied+Settings, pinch framing, crop, upload, journal reconcile already present).
- Unverified: `@Environment(\.dismiss)` inside the pushed Form.

## subpackageP3 stamp-album -> RoamStampViews.swift
- Added: "正在读取下一页" for continuation loads (first load still "加载中").
- Still missing: rotated collage layout (see StampAlbumParityViews, not re-audited) and strict page validation (would break existing metadata-only decode tests).
- Unverified: ternary of string literals inferred as `LocalizedStringKey` in `ProgressView`.
