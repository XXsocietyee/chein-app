# CB271 page-ready — pages/templatedetail/templatedetail

Base `rc/20261108` `86fa48b0c5833bbadd97c09f246ad05f7af1b8b0`. Branch `cursor/cb271`.

Screen: 玩法模板详情与节点交互预览. Native file `App/DiscoveryTemplateDetailView.swift`. Page-map status stays `exists`. This pass does not mark a route live and does not edit the page map.

Core and tests only. Views, `docs/release/ui-strings-*.json`, `Resources/Localizable.xcstrings`, the Xcode project, and the CI ledger were not edited.

`xcodebuild` was not run. This machine has no Swift toolchain, so the XCTest files below were not executed. Tree-sitter syntax preflight could not start: `tools/requirements-swift-syntax.txt` is not installed.

## Contract

`DiscoveryService.playTemplateRead` already posts `api/template/info` once and decodes `DiscoveryPlayTemplate` plus `DiscoveryPlayTemplateExtras`. That wiring was already on rc. It was not replaced, and the route was not registered again.

## States

`DiscoveryPlayTemplateDetailPhase.classify` names the four outcomes of that same read:

| Phase | When |
|---|---|
| `loading` | The caller is still in flight. A stale read is ignored. |
| `empty` | The call finished with no template and no failure. A decoded template is not empty. |
| `error` | A known refusal (not found, deleted, under review, offline) or any other `Error`, including `APIError.malformedResponse`. |
| `unknown` | `DiscoveryTemplateUnavailable.unknown`: the server refused, and the message is not one of the known template reasons. |
| `ready` | A template decoded. A missing count inside it stays an em dash. A literal `0` stays `"0"`. |

The view still uses `DiscoveryLoader` and was not switched to this phase.

Empty-success bodies on this contract: **0**. A 200 with `data: null` is a malformed response, which is `error`, not an empty template.

## Counts

Unknown counts render as `—` (U+2014). A literal `0` stays `0`.

`DiscoveryPlayTemplateDetailPresentation` now does that for adoption count (`useCountText`), review count (`commentCountText`), chapter count, and node count. The parity section already prints `stat.value`, so a missing chapter or node count shows the dash without a view edit. Rating and duration are not counts. A missing duration stays off the row. `duration == 0` still becomes a nil `durationMinutes`, which existing `DiscoveryContractTests` lock in place.

`DiscoveryPlayTemplatePresentation.useCountText` follows the same rule. `useCount` itself is still `Int?`: nil when missing, `0` when the JSON number is 0.

## Missing keys

User-visible catalog keys already referenced by `DiscoveryTemplateDetailView`, `DiscoveryTemplateDetailParitySections`, `DiscoveryPlayTemplatePresentationView`, `DiscoveryComponents` (the loader and error copy this screen uses), and `MemberTemplateDetailView` were checked against `Resources/Localizable.xcstrings`. Every one of those keys is present. Missing count: **0**.

Phrases named for this page that have no catalog entry. The key cell is an em dash because no identifier exists. The mini-program file `chengyinhub-xcx/pages/templatedetail/templatedetail.js` is not in this checkout (the recorded raw URL returns 404), so the count of original message-key identifiers is **—**.

| Phrase | Catalog key |
|---|---|
| 分享玩法 (`onShareAppMessage`) | — |
| 详情 (detail / capability tab) | — |
| 能力 (detail / capability tab) | — |
| 来源 (capability row) | — |

`memberTemplate.failed` already covers 这份玩法没能打开，请重试 on the owner detail. It is not a missing key.

These response fields stay undecoded on purpose. They are not display keys to add: `questionAnswer`, and the other secret or authority fields the public presentation test already rejects (`hint1`, `correctAnswer`, `merchantGuide`, `storyJson`, `isOwner`, `isPurchased`, `isUnlocked`, `memberTemplateId`). `nodeCount` and `gameCount` fold into the node count. They are not separate missing keys.

## Tests

Existing assertions were left in place.

- `DiscoveryPlayTemplateExtrasTests.testMissingCountsAreEmDashAndLiteralZeroStaysZero` — missing chapter, node, use, and review counts are `—`; JSON `0` stays `0`; a blank chapter string stays `—`.
- `DiscoveryPlayTemplateExtrasTests.testReadPhaseKeepsLoadingEmptyErrorAndUnknownApart` — loading, empty, known refusal, malformed response, unrecognized refusal, and a ready template whose counts are missing.
- `DiscoveryPlayTemplatePresentationTests.testMissingNullAndBlankContentRemainUnknownWithoutFabricatedZero` — the old nil-versus-`0` checks remain. Added: `useCountText` is `—` when missing and `"0"` for a literal 0.
- `DiscoveryPlayTemplateExtrasTests.testStatsChipsGalleryAndRuleSteps` — still expects use count `"0"` and topic counts `"3"`, `"6"`, `"90"`.

`python3 -B Tests/ContractChecks/test_w2_11_play_template.py` on this diff: the extras, single-read, and recovery checks pass. `test_localizations_are_bilingual` fails on unchanged rc as well. The catalog English for `discovery.templateTab.staffReadOnly` is “Only the owner or manager can publish and copy.” The JSON file still has the older sentence. That pair was not edited.

## Left

- `App/DiscoveryPlayTemplatePresentationView` still shows the use count only when `useCount` is non-nil, so a missing use count is omitted there. The dash is on `useCountText`.
- `DiscoveryTemplateDetailParitySections` still drops `.uses` and `.duration`, and still shows the review-source sentence unless `commentCount > 0`. A literal review count of 0 and a missing review count look the same on screen. `commentCountText` has the distinct strings.
- `TopicTotalStops` still shows `topic.countUnknown` (`Unknown` / `未知`) for a missing public stop count. That is the topic preview inside the same view file. It does not show `0`.
- Share, and the 详情 / 能力 split, stay unwired. Their keys are in the table above.
- The new phase is not called from the view.
- XCTest was not run.
