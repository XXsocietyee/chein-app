# Mini-program delta 1113

Source: public `liboyang42-cpu/hengyin`, read over HTTPS. Range is `chengyinhub-xcx` from `1ca6d3215beee96afdcdfd300dd9176f2d0ac5b3` to `master` `73f4f7be45aa5b49381baa2c1aff57e1b2245fad`. Native tip is this branch, taken from `origin/ui/main`. No other branch was merged.

Master commits in that range, newest first:

| SHA | Subject |
|---|---|
| `73f4f7be45aa5b49381baa2c1aff57e1b2245fad` | fix: 平台自玩路线走查第四轮 (#829) |
| `8390d99e3f7a54899c493ecb3d70e9aa8f57dbca` | fix: 平台自玩城市路线走查第三轮十一项 (#828) |
| `4bc6a1117b1486b71dabd6f72e4aa991b33a63b2` | fix: 确认订单章数不含结局、同意行移入固定底栏 (#827) |
| `ababc795e191cb9c79fda732543809fdb1cfcfda` | fix: 开局 300 米闸、拍照 fallback、逐字猜词继续、问答 maxTries 0 (#825) |
| `fc1dae24ee9ecdc5c613758bf5e4c3fb9427cfa0` | fix: 主题详情章数不含结局、解锁卡、进度条标签、票夹定位 (#826) |
| `fbd42b4de7cb1ccdab7874ba2290027a1f6b964c` | fix: 游玩页验收走查八项界面缺陷 (#824) |
| `7502b7fe0246cdbbb1cab5d935c933cce1c8b660` | feat: 平台自玩票小程序虚拟支付 XPAY，默认关闭 (#821) |
| `e86eb01303621be476235c855f62ef3b051d80b2` | fix: 主题详情走查第二轮 (#823) |

Requested branches:

| Branch | Result |
|---|---|
| `fix/play-runtime-1113c` | exists, `36a1563eb`. Player changes are the squash already on master. |
| `fix/topic-detail-1113d` | exists, `2cc575d86`. Same. |
| `fix/play-ui-1113c` | exists, `1c81ef32c`. Same. |
| `fix/checkout-1113e` | exists, `b377556ac`. Same. |
| `fix/selfplay-xpay-20261113` | exists, `9f7599e5e`. Same. |
| `fix/pass-mini-20261113` | exists, `ec0d84908`. No `chengyinhub-xcx` tree difference against master. |
| `fix/fe-organizer-settlement-info-20261113` | exists, `acf21b9a0`. Merchant copy files match master. Remaining commits are tests and docs. |
| `fix/pass-backend-20261113` | exists, `ac0688a4e`. Remaining commits are backend tests and docs, not a player screen. |
| `fix/topic-detail-walk2` | missing. Dated sibling `fix/topic-detail-walk2-20261113` (`9cc64ebaa`) was read. Its player diff is already on master. |
| `fix/chapter-guide` | missing. Dated sibling `fix/topic-detail-chapter-guide-20261113` (`f3dad7e50`) was read. That player change is commit `#822`, which is the base `1ca6d3215`, already on this tip. |
| `fix/chapters-map-20261113` | missing. Dated sibling `fix/topic-detail-chapters-map-20261113` (`f782e9260`) was read. Its player diff is already on master. |

| Mini-program change | Native file | Result |
|---|---|---|
| Cover subtitle cuts at 20 characters and adds an ellipsis | `App/TopicDetailView.swift`, `Core/TopicXcxFacts.swift` | DONE on the no-cover hero line. The covered hero on this tip has no subtitle line, so that cut is not added there. The details-section subtitle stays the full string. |
| Buyer chapter count leaves chapters named 结局 out of the chapter number, and shows endings beside it | `Core/TopicXcxFacts.swift`, `App/TopicXcxSections.swift` | DONE. Count uses delivered chapter names. `totalChapterCount` still includes endings. |
| Unlock copy drops 与到店权益 when no shop card would show | `App/TopicDetailView.swift`, `Core/TopicXcxFacts.swift` | DONE. Perks follow lineup merchants. Existing `topicXcx.paywall.detail` is unchanged when shops are present. |
| 去票夹 and the self-play tickets link scroll to this topic's ticket (`ownerType` 1, `cmsTopic.id`, else `ownerId`) | `App/TicketWalletView.swift`, `Core/TicketWalletContracts.swift`, `App/PlatformConsumerSessionOwner.swift`, `App/SessionTopicSelfPlayView.swift`, `App/TopicXcxSections.swift` | DONE for those two existing call sites. Other wallet entries stay unfocused. Ticket id 0 does not match. |
| Pass expiry at 00:00:00 is the previous civil day; that day reads 今天过期. A decoded 0 stays 0 | `Core/MoneyParityRules.swift` | DONE. |
| Play photo upload timeout 15s to 60s | `Core/PlayPhotoEvidence.swift` | DONE for the play photo upload only. |
| Late upload success is reused, and the total upload deadline is 90s | — | Not ported. The native upload uses `URLSession`, which cancels the request. There is no late-upload map on this tip. |
| Checkout consent moves into the fixed bottom bar, and the payment review puts consent above continue | `App/TopicSelfPlaySheet.swift` | DONE. The document link stays in the form. |
| Confirm-order chapter count excludes endings | — | The native confirm-order sheet does not show a chapter count. The includes row on topic detail is the count that was ported. No new checkout line was added. |
| Template preview skips a generated 第N章 when the name already has 第X章, 结局, 终章, 序章, or 尾声. The guide is the description with puzzle text removed, at most 60 characters, two lines. Opening description is four lines | `App/DiscoveryTemplateDetailView.swift`, `Core/TopicXcxFacts.swift` | DONE. The template chapter stat still counts ending chapters, matching the preview list. |
| Chapter page story stays the full description | `App/TopicDetailView.swift` | Not changed. The 60-character guide is only the template preview. |
| Native topic chapter rows do not prefix 第N章 | — | The double-prefix bug is not on `TopicDetailView`. Prefixes were not added. |
| XPAY / `wx.requestVirtualPayment`, default off | — | Not ported. It is WeChat virtual payment. No StoreKit product id is invented. Money stays behind the existing `ReviewedAreaSwitch`. Orders stay on the existing payment path. Production host `www.chengyinhub.com` stays closed. |
| Paper look, light-hex ink, ending-button contrast, back-button ink, typed-answer ink | — | No paper-look skin on this tip. |
| Chapter-flip canvas seal timing | — | No native canvas chapter flip. |
| Walk minutes on the play sheet cap at 60 | — | No play-sheet walk-minute fact on this tip. The topic itinerary estimate is a different rule and stays uncapped. |
| Start dialog 还没到起点 / 重新定位, and the client 300m gate | — | Native arrive refusal stays the server text in `App/PlayRecoveryViews.swift`. No location-retry dialog was added. |
| Hangman inline 继续 deduped against the story button; QA 继续 deduped when the label is 继续 | — | Native hangman is a full-screen kit. Continue closes that kit. There is no second story-flow button on this tip. |
| QA `maxTries` 0 means unlimited | — | No `maxTries` string change in this xcx range. Native attempt limits do not finish a round; finished stays server-owned. The question form already hides dots when the cap is not positive. |
| Photo `fallback=pass` | — | No such string change in this xcx range. |
| Verdict tidy text, keep-numerals, keep-measure | — | No native verdict paragraph inserts those spaces. Word-joiner characters were not added to accessible strings. |
| Archive rows, photo caption ellipsis, achievement split, station label stripping | — | No native 走过 / 首达 / life-arc surface on this tip. |
| Kit-start popup drops 模板 chips and 绑定地点 | — | No native kit-start popup with those labels. |
| Empty chapter review is skipped | — | No native post-finish story review that opens an empty chapter page. |
| Route progress labels hide when there are more than 7 stations | — | Topic route on this tip is a list, not that progress mark. |
| Topic route map bounds and padding, and refit when the tab changes | — | No topic route map on this tip. |
| Story-fan front/back labels | — | No native story fan. |
| Docked story card padding and locked chevron rotation | — | Chapters are a list above the action bar. The paywall already sits above that inset. |
| No-cover placeholder must not cover the back button | — | The native no-cover hero is a card with a symbol, not an illustration over the navigation bar. |
| Play opening intro line ellipsis | — | No native intro line with that source string. |
| Order detail and history XPAY sign, pay, and verify | — | Same as the XPAY row. Not ported. |
| Publish look tokens | — | Authoring duplicate of the play look tokens. Not a player skin on this tip. |
| Organizer settlement player copy on the dated settlement branch | — | The player files match master. Nothing new to port. |
| Pass mini-program and pass backend branches | — | No player `chengyinhub-xcx` delta against master in this window. |
