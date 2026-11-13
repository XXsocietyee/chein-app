# Cloud stubs — public share links (handover 14, ledger rows 20 and 22)

Branch `ui/cloud-stubs-share`. Parent `origin/ui/next` `11e7c2c4559ee3a210fdcfacf8abee717c312ff9`.

Rows 20 and 22 only. No other stub was filled. `App/AppSession.swift` and `App/AppCompositionRoot.swift` were not edited. Journey and PWave files were not edited. `UniversalLinkParser`, `CheinDeepLink`, and `UniversalLinkConfiguration` were not edited. The contract-failing baseline was not rewritten. No referral token. No payment, payout, or virtual goods.

## What gets a public URL

`Core/PublicContentShareLink.swift` builds `https://www.chengyinhub.com` only when `CheinDeepLink` or `UniversalLinkParser` already types that path. The host is the existing China API host (`ReviewedMarketLaunch.chinaProductionBaseURL`). It is not written into `UniversalLinkConfiguration.verifiedHTTPSOrigins` (still `[]`) and not written into Associated Domains. The default parser still accepts nothing, so this build does not open inbound universal links. The outbound URL is checked by constructing `UniversalLinkParser(verifiedHTTPSOrigins: ["https://www.chengyinhub.com"])` and requiring a `.content` intent whose source path and id match. No route was added.

| Surface | Mini-program path | Public URL |
|---|---|---|
| Square post, only when `SquareL5ShareCard.isPubliclyShareable` | `/pages/square/detail/index?id=<id>` | `https://www.chengyinhub.com/pages/square/detail/index?id=<id>` |
| Discovery template | `/pages/templatedetail/templatedetail?id=` | `https://www.chengyinhub.com/pages/templatedetail/templatedetail?id=<id>` |
| Topic template | `/pages/templatedetail/topic-detail/index?id=` | none |

A post that is not publicly shareable has no public URL. `genericShareURL` stays nil, so the detail share key stays hidden. Private, followers-only, draft, missing, zero, and non-canonical ids do not get a link. The query is only `id`. A blank or `PUBLISHED` lifecycle on `SquarePost` is the mini-program's absent status (allowed). Numeric `1` stays `1`.

## Row 20 — square

`SquarePublicShareLink` conforms to `SquarePostShareLinkProviding` and is injected on the existing `CloudSquareStubModifier` (`\.squareShareLink`). It records the post in hand and returns a URL only for that id. The detail sheet is the existing `CYSquareShareSheet`: the in-app card, the system share of that URL, and copy. List and detail “copy link” copy that same URL through `LocalPasteboard`, and copy nothing when the post is not publicly shareable. `SquareShareCard` is still the repost gate. No second network client.

## Row 22 — templates

`DiscoveryTemplateDetailView` passes `PublicContentShareLink.discoveryTemplate(id:)` into the existing `TemplateXbShareButton` when the caller did not set `shareURL`. The button is the existing round share key (`ShareLink`).

The topic-template path is not parsed by `CheinDeepLink` or `UniversalLinkParser` (it is not a `NativeContentTarget` source path). The parser was not extended and no host was invented for it. `DiscoveryTopicTemplatePreview.shareURL` stays nil unless a caller sets one. The existing head card stays. The same share key shares the path text `/pages/templatedetail/topic-detail/index?id=<id>` only. That text is not an https URL and not a referral.

## Copy

No new catalog keys. The square sheet keeps `share.*` in `SocialParity.xcstrings`. The template keys stay `u10.template.share` (Share play / 分享玩法) and `u10.template.shareTopic` (Share topic template / 分享主题模板).

## Checks

`python3 tools/generate_project.py`, `python3 tools/check_scaffold.py`, and `python3 tools/check_design_lint.py` passed before push. `python3 tools/contract_ratchet.py --check` reports one id that is not in the baseline: `test_ops_safety_contracts.OpsSafetyContracts.test_audit_tool_catalog_is_complete`, from the existing `App/HomeCityLocationConsentHost.swift` user-defaults store. This branch does not edit that file. The baseline file was not edited. `Tests/CoreTests/PublicContentShareLinkTests.swift` locks the three paths, the private-post refusal, the empty allowlist, and the topic path text. This environment has no Swift compiler, so that test was not executed and the app was not compiled.

---

# 云端存根 — 公开分享链接（交接 14，台账第 20 与第 22 行）

分支 `ui/cloud-stubs-share`。父提交 `origin/ui/next` `11e7c2c4559ee3a210fdcfacf8abee717c312ff9`。

只填第 20 行和第 22 行。其他存根未动。`App/AppSession.swift` 与 `App/AppCompositionRoot.swift` 未改。旅程与 PWave 文件未改。`UniversalLinkParser`、`CheinDeepLink`、`UniversalLinkConfiguration` 未改。失败基线没有改写。不签发推荐令牌。没有支付、提现或虚拟商品。

## 哪些有公开网址

`Core/PublicContentShareLink.swift` 只在 `CheinDeepLink` 或 `UniversalLinkParser` 已经能识别该路径时，才生成 `https://www.chengyinhub.com`。主机是现有的中国 API 主机（`ReviewedMarketLaunch.chinaProductionBaseURL`）。没有写入 `UniversalLinkConfiguration.verifiedHTTPSOrigins`（仍是 `[]`），也没有写入 Associated Domains。默认解析器仍然什么都不接受，所以这个构建不会打开入站通用链接。出站网址用 `UniversalLinkParser(verifiedHTTPSOrigins: ["https://www.chengyinhub.com"])` 检查，并且必须得到路径和 id 都吻合的 `.content`。没有新增路由。

| 表面 | 小程序路径 | 公开网址 |
|---|---|---|
| 广场帖，仅当 `SquareL5ShareCard.isPubliclyShareable` | `/pages/square/detail/index?id=<id>` | `https://www.chengyinhub.com/pages/square/detail/index?id=<id>` |
| 发现玩法模板 | `/pages/templatedetail/templatedetail?id=` | `https://www.chengyinhub.com/pages/templatedetail/templatedetail?id=<id>` |
| 主题模板 | `/pages/templatedetail/topic-detail/index?id=` | 无 |

不可公开分享的帖没有公开网址。`genericShareURL` 仍是 nil，详情里的分享键保持隐藏。私密、仅关注者、草稿、缺失、0、以及非规范 id 都没有链接。查询只有 `id`。`SquarePost` 上空白或 `PUBLISHED` 的生命周期，对应小程序里缺省的状态（允许）。数字 `1` 仍是 `1`。

## 第 20 行 — 广场

`SquarePublicShareLink` 遵守 `SquarePostShareLinkProviding`，挂在现有的 `CloudSquareStubModifier`（`\.squareShareLink`）上。它只记下当前这条帖，并且只为这个 id 返回网址。详情半屏仍是现有的 `CYSquareShareSheet`：应用内卡片、系统分享这个网址、以及复制。列表和详情的「复制链接」通过 `LocalPasteboard` 复制同一个网址；帖不可公开分享时什么都不复制。转发仍由 `SquareShareCard` 把关。没有第二个网络客户端。

## 第 22 行 — 模板

调用方没有设置 `shareURL` 时，`DiscoveryTemplateDetailView` 把 `PublicContentShareLink.discoveryTemplate(id:)` 交给现有的 `TemplateXbShareButton`。按钮仍是原来的圆形分享键（`ShareLink`）。

主题模板这条路径，`CheinDeepLink` 和 `UniversalLinkParser` 都不解析（它不是 `NativeContentTarget` 的源路径）。解析器没有扩展，也没有为它另造主机。除非调用方自己传入，`DiscoveryTopicTemplatePreview.shareURL` 仍是 nil。原有的头图卡片保留。同一个分享键只分享路径文本 `/pages/templatedetail/topic-detail/index?id=<id>`。这段文本不是 https 网址，也不是推荐令牌。

## 文案

没有新的目录键。广场半屏仍用 `SocialParity.xcstrings` 里的 `share.*`。模板键仍是 `u10.template.share`（Share play / 分享玩法）和 `u10.template.shareTopic`（Share topic template / 分享主题模板）。

## 检查

推送前 `python3 tools/generate_project.py`、`python3 tools/check_scaffold.py` 和 `python3 tools/check_design_lint.py` 已通过。`python3 tools/contract_ratchet.py --check` 报了一条不在基线里的失败：`test_ops_safety_contracts.OpsSafetyContracts.test_audit_tool_catalog_is_complete`，来自现有的 `App/HomeCityLocationConsentHost.swift` 用户默认存储。本分支没有改那个文件。基线文件没有改。`Tests/CoreTests/PublicContentShareLinkTests.swift` 锁住三条路径、私密帖拒绝、空允许列表，以及主题路径文本。本环境没有 Swift 编译器，这条测试没有在这里跑，应用也没有编译。
