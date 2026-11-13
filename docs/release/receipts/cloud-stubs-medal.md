# Cloud stubs — row 23, completion medal

Stub-ledger row 23 only. `DiscoveryTopicTemplatePreview.finishMedalName` now reads the topic-template public projection. No other stub was filled. `shareURL` is still nil and still hides the share key.

## Read

`POST api/template/topic-template/info` is unchanged. `DiscoveryService.publicTopicTemplate` still decodes `PublicTopicTemplateDetail` from that one response. `Core/TopicXcxFacts.swift` already reads `finishMedalName` on a topic payload; this row only copies that same field onto the public projection that `DiscoveryTemplateBrowserView` opens in `DiscoveryTopicTemplatePreview`. Nothing new is requested, and `App/AppSession.swift` and `App/AppCompositionRoot.swift` are untouched.

## What is shown

The projection keeps a trimmed `finishMedalName`. Missing, null, blank, and non-string values stay nil. `finishMedalImg` is not decoded. The topic title is not turned into a medal (`TopicXcxFacts`’s “· 通关” / 通关纪念 fallback is not used). Nil hides the 通关勋章 block. A real name shows that name under the existing title.

| Key | en | zh-Hans |
|---|---|---|
| `u10.template.medal` | Completion medal | 通关勋章 |
| `u10.template.medalHint` | Lights up when every stop is done | 走完全部节点时点亮 |

The name itself is server text, shown verbatim.

## Checks

`Tests/CoreTests/PublicTopicTemplateTests.swift` (`testFinishMedalNameIsOnlyThePublicDetailString`) locks the name, the blank/null absence, and that an image or another JSON shape does not become a medal. This environment has no Swift compiler, so that test was not executed here. `docs/release/contract-failing-baseline.txt` was not edited.

---

# 云端存根 — 第 23 行，通关勋章

只填存根台账第 23 行。`DiscoveryTopicTemplatePreview.finishMedalName` 改为读主题模板的公开投影。其他存根未动。`shareURL` 仍是 nil，分享键仍然隐藏。

## 读取

`POST api/template/topic-template/info` 没有改。`DiscoveryService.publicTopicTemplate` 仍从这一次响应解码 `PublicTopicTemplateDetail`。`Core/TopicXcxFacts.swift` 已经从主题载荷读取 `finishMedalName`；这一行只把同一个字段放进公开投影，供 `DiscoveryTemplateBrowserView` 打开的 `DiscoveryTopicTemplatePreview` 使用。没有新请求。`App/AppSession.swift` 与 `App/AppCompositionRoot.swift` 未改。

## 显示

投影只保留去掉首尾空白的 `finishMedalName`。缺失、null、空白、非字符串都是 nil。不解码 `finishMedalImg`。不用主题标题补一枚勋章（不用 `TopicXcxFacts` 的「· 通关」/ 通关纪念回退）。没有名字就不显示通关勋章。有名字就在原有标题下原文显示。

| 键 | en | zh-Hans |
|---|---|---|
| `u10.template.medal` | Completion medal | 通关勋章 |
| `u10.template.medalHint` | Lights up when every stop is done | 走完全部节点时点亮 |

勋章名字是服务端原文。

## 检查

`Tests/CoreTests/PublicTopicTemplateTests.swift` 的 `testFinishMedalNameIsOnlyThePublicDetailString` 锁住：有名字、空白和 null 不显示、图片或其他 JSON 形状不会变成勋章。本环境没有 Swift 编译器，这条测试没有在这里跑。`docs/release/contract-failing-baseline.txt` 没有改。
