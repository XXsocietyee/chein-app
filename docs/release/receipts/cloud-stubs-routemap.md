# Cloud stubs — route map (ledger row 21)

Branch `ui/cloud-stubs-routemap`. Parent `origin/ui/next` `bdd0a90b3b3c1abb52c767d2fe877effed428755`.

Row 21 only. The other layout stubs stay nil.

`SquareRouteMapProvider` conforms to `SquareRouteMapProviding` and is injected on the existing `CloudB3RootModifier` environment (`\.squareRouteMap`). `App/AppSession.swift` and `App/AppCompositionRoot.swift` are unchanged.

## Read

One signed-in `POST api/topic/info-to-user`, form field `id`, through `TopicService.detailDocument`. `detail()` is that same read and still returns only `TopicDetail`. No second request, no new path, no write. `TopicSessionReader.topicDetailDocument` keeps the existing signed-in gate (`topicDetail` now returns `topicDetailDocument(...).detail`). A guest still gets `unauthorized` and the live map stays hidden. The post `MAP_SNAPSHOT`, when the card already has one, still shows.

## Chapters to nodes, verified roads only

`SquareRouteMapVerified.project` reads `chaptersList` from that response body. Stops are the topic detail's chapter nodes that have a finite coordinate inside the latitude/longitude limits, in `sortId` order. A blank name is an em dash (`U+2014`), not a made-up title.

A road segment is used only when `routeGeometryAvailable` is JSON `true`, `routeGeometryError` is not `true`, and `routeGeometryErrorCode` is absent or falsy (`false`, `0`, `""`). `routeGeometry` may be an array or a JSON string. Every point must be a valid coordinate, and there must be at least two. One bad point drops that chapter. Chapters are separate segments and are not joined.

If any chapter that has a stop lacks that verified road, the provider returns an empty preview and `CYSquareRouteMapCard` does not draw. It does not fall back to a straight line through the stops. `SquareRouteMap.build` still describes the mini-program's labelled straight preview; this provider does not display that preview.

## Checks

`python3 tools/check_design_lint.py` passed. `python3 tools/check_scaffold.py` passed (catalogs, release config, privacy, design lint, AppSession ratchet, page route table, project equivalence). The contract failing baseline was not edited. This environment has no Swift compiler, so the new tests were not executed.
