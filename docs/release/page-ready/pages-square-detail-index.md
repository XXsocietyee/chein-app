# pages/square/detail/index

CB267 page-ready on `rc/20261108`. Native screen `App/SquareDetailView.swift` (动态详情与评论互动). Map status stays `exists`.

`SquareDetailPageModel` in `Core/SquareXcxPresentation.swift` projects the existing detail contract: `POST /api/creativesquare/info`, `GET /api/v1/community/posts/{}`, `POST /api/comment/list` (`rows`), and `GET /api/v1/community/posts/{}/comments` (`items`). It does not build a request, open a session, or change a route mark. Those four paths stay `live-in-production` because they were already marked. `blockRouteIsLive` stays false. `SquareAuthorSafety.blockAvailability` stays `.notAvailableYet`. No block path was added.

Loading, empty, error, and unknown stay separate, and a decoded post or comment page is ready. An omitted count, null, a numeric string, a fraction, or a boolean is U+2014 (`—`). A literal JSON `0` stays `0`. A missing comment list is unknown, not “还没有评论”. `rows: []` or `items: []` is empty. `hasMore` is true only for JSON `true`. Absent `viewerCanComment` stays allowed, matching `SquarePost`. `isBookmarked` is unknown unless it is the integer `0` or `1`.

The view, string catalogs, `docs/release/ui-strings*.json`, the Xcode project, and `Core/MiniProgramPageByPage99DecisionLedgerContract.swift` were not edited. `xcodebuild` was not run.

## Missing keys

Source sentences on `pages/square/detail/index` that have no entry in any `Resources/*.xcstrings` catalog. The model does not invent keys for them. It binds the existing keys `square.failed`, `square.unavailable`, `square.unauthorized`, `square.notConfigured`, `square.signInRequired`, `square.xcx.closedTitle`, `square.xcx.noCommentsTitle`, and `square.xcx.noCommentsDetail`.

- 动态加载失败
- 这条帖文暂不可用
- 没有找到这条帖文
- 社区暂未开放
- 评论加载失败
- 更多评论加载失败
- 服务暂时无法提供这条动态
- 网络异常，请检查连接后重试
- 正在加载更多评论…
- 回复评论
- 转发帖文
- 收藏帖文
- 打开用户主页
- 更多操作
- 查看大图
- 评论已发送，计数请刷新查看
- 选择举报原因

JSON names the completion card reads, and `isFollowTheUser` / `sportSubtitle`, are not on the existing `SquarePost` decoder. The model does not read them and does not substitute `0`. The card’s own note says the backend does not define the medal, distance, shop, duration, kudos, and comment-preview fields.

- medalGold (decoded since r8, 45f2b0991; nil when the server omits it)
- medalSilver (decoded since r8)
- medalBronze (decoded since r8)
- distanceText
- shopText
- durationText
- kudosAvatars
- kudosText
- commentNick
- commentText
- sportSubtitle
- isFollowTheUser

## Left

`App/SquareDetailView.swift` still decodes `SquarePost` and `SquareComment`. Those types still store a missing `likeCount`, `likeNum`, `commentCount`, `nolikeNum`, `nodeTotal`, `nodeDoneCount`, or comment `likeCount` as `0`. The view does not call `SquareDetailPageModel`. Empty comments in the view show `square.xcx.noCommentsTitle` and do not show `square.xcx.noCommentsDetail`. No Xcode Cloud result is claimed.
