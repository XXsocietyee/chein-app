# pages/mylike/mylike

CB281 page-ready on `rc/20261108`. Native screen `App/AccountCollectionFavoritesView.swift` (我的收藏). Map status stays `exists`.

`AccountCollectionFavoritesPageModel` in `Core/AccountCollectionContracts.swift` projects the existing list contract: `POST /api/creativesquare/list` (`data.rows`, the same body `AccountCollectionService.favoritePosts` decodes) and `POST /api/topic/like_list` (`data.rows`, or a bare `data` array, the same shapes `favorites` decodes). It does not build a request, open a session, or change a route mark. Both paths stay `live-in-production` because they were already marked. `existingRouteIsLive` only reads `ChinaReviewedRouteCapability`.

Loading, empty, error, and unknown stay separate, and a decoded page is ready. An omitted count, null, a numeric string, a fraction, a boolean, or a negative is U+2014 (`—`). A literal JSON `0` stays `0`. `rows: []`, and a topic `data: []`, is empty. A missing `rows` list, null, or the token `UNKNOWN` is unknown. That is not an empty collection and not `0`. `hasMore` follows the accepted row count against `pageSize` (1...100). A page longer than `pageSize`, a nested `post` object, a bare post array, and a non-positive id are errors, matching the existing decoder. The JSON `total` field is not read, so `total: 0` does not become an empty list and `total: 900` does not invent rows.

`SquarePost` and `TopicSummary` are unchanged. `AccountCollectionService` still throws `malformedResponse` for a missing or null list, and the existing collection tests still require that. The view, string catalogs, `docs/release/ui-strings*.json`, the Xcode project, and `Core/MiniProgramPageByPage99DecisionLedgerContract.swift` were not edited. `xcodebuild` was not run.

## Missing keys

Source sentences on `pages/mylike/mylike` and on the post card this page actually shows (`show-favorite`, `show-share`) that have no entry in any `Resources/*.xcstrings` catalog. The model does not invent keys for them. It binds the existing keys `accountCollection.signInRequired`, `accountCollection.notConfigured`, `accountCollection.network`, `accountCollection.failed`, `member.favorites.postsEmpty`, `accountCollection.favorites.empty`, `member.favorites.postsEnd`, and `member.favorites.topicsEnd`.

- 收藏没能加载出来
- 看到想留着慢慢看的动态，可以点星标收藏。
- 收藏帖文加载失败
- 喜欢列表加载失败
- 分享主题
- 收藏主题
- 查看收藏的动态
- 分享一条城瘾动态
- 推荐路线：
- 分享成功
- 分享取消
- 网络错误，请重试
- 未通过审核 · 仅自己可见
- 查看路线图
- 转发帖文
- 收藏帖文

JSON names the page script or the post card reads, and this model does not. `isBookmarked` is the exception: the model reads integer `0` or `1` and leaves every other value unknown. `TopicSummary` already stores `imgUrl` / `picUrl` and `startDate`. It does not store `imgArr` or `endDate`.

- status
- link
- imgArr
- endDate
- total
- isFollowTheUser
- medalGold
- medalSilver
- medalBronze
- distanceText
- shopText
- durationText
- kudosAvatars
- kudosText
- commentNick
- commentText

## Left

`App/AccountCollectionFavoritesView.swift` still builds `SquarePost` and `TopicSummary` through `AccountCollectionPostsModel` and `AccountCollectionFavoritesModel`. It does not call `AccountCollectionFavoritesPageModel`. `SquarePostContent` still draws `max(0, post.likeCount)` and `max(0, post.commentCount)`, and it draws route progress only when `nodeTotal > 0`. A missing `likeCount`, `likeNum`, `commentCount`, `nolikeNum`, `nodeTotal`, `nodeDoneCount`, or `memberLevelId` is still stored as `0` on `SquarePost`. A missing topic `likeNum` is still stored as `0` on `TopicSummary`. `TopicTotalStops` still shows `topic.countUnknown` (`未知`) for a nil `locationCount`, not an em dash. The topic empty hint `accountCollection.favorites.emptyHint` is catalogued and the topic `ContentUnavailableView` does not pass it. The post-card actions that need `interactiveActions`, `showMore`, `interactiveMedia`, or `showFollow` stay off on this page. Map status stays `exists`. No Xcode Cloud result is claimed.
