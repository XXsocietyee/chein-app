# ui-cur-copy

Handover 50. Parent `9209d33cb2d7ceed6f95a1b9d90b556e531a63b0` (`origin/ui/main`). Branch `ui/cur-copy`.

Mini-program source: public `liboyang42-cpu/hengyin` `8390d99e3f7a54899c493ecb3d70e9aa8f57dbca`, tree `chengyinhub-xcx`. Chinese below was read there. English is the natural line for that Chinese. Unknown values that the mini-program draws as an em dash use `—` in both `en` and `zh-Hans`.

This is not a whole-app pass. Merchant rows (`pages/merchant/`) were out of scope. Only the player pages below were compared. Money stays closed on `www.chengyinhub.com`. `RegionalLaunchConfiguration`, `AppSession`, and `AppCompositionRoot` were not edited. `ReviewedAreaSwitch` was not redeclared. `docs/release/contract-failing-baseline.txt` was not raised.

`swiftc` is not on this machine. No typecheck was run.

## Compared

| Page | Result |
|---|---|
| `pages/index/index` | Tab and failure copy fixed. Countdown Chinese already matched `还剩N天` / `还剩N小时` / `已开始`; English shortened forms were rewritten. Location prompt already matched. |
| `pages/search2/index` | Player placeholder fixed (`主题`, merchants still omitted on the player field). Sort chip `最近` already matched. The filter still offers `最热` (`searchMap.popular` in `SearchMapFilterSheet`); the mini-program removed that sort and did not rename it, so the catalog value was left. |
| `pages/activity/list/index` | Search placeholder fixed. Tab chips, empty titles, and summaries already matched `进行中` / `即将` / `已结束` / `我的` and the empty lines in `EMPTY_COPY`. |
| `subpackageMember/signup/index` | Missing ticket name is now `—` (`wTitle \|\| '—'`). Filters `全部` / `即将开始` / `已通关` already matched. A non-boolean completion already shows `—`; its VoiceOver label stays a sentence. |
| `pages/shezhi/shezhi` | Marketing row and sign-out detail fixed. `设置`, `成为俱乐部主理人`, `成为商家`, `城瘾玩法`, `我的收藏`, `用户服务协议`, `关于` already matched. Confirm button stays `退出登录` (`account.logout` `confirmText`). The close-account row stays `注销账号`, which is the deregister page title; the settings cell in the mini-program says `账号注销` and shares this key. |
| `pages/shezhi/marketing/index` | Page title fixed to `营销消息与优惠券`. |
| `pages/privacy/index` | Row actions `查看` / `关闭` / `撤回` fixed. Row titles `首页城市自动定位` is not a separate catalog key on this screen. `漫游定位`, `附近的人位置分享`, `我的待审媒体`, and `隐私与定位` already matched. |

## Strings changed

| Key | Table | en | zh-Hans |
|---|---|---|---|
| `homeFeed.title` | Localizable | Home | 首页 |
| `homeFeed.topics` | Localizable | Topics | 主题 |
| `mpfresh.home.countdown.days %lld` | MpFresh | %lld days left | 还剩%lld天 |
| `mpfresh.home.countdown.hours %lld` | MpFresh | %lld hours left | 还剩%lld小时 |
| `mpfresh.home.sectionFailed.nearby` | MpFresh | Couldn't load nearby activities | 附近活动加载失败 |
| `mpfresh.home.streamFailed.topics.first` | MpFresh | Topics didn't load | 主题列表加载失败 |
| `mpfresh.home.streamFailed.topics.more` | MpFresh | More topics didn't load | 更多主题加载失败 |
| `searchMap.placeholder.player` | Localizable | Search topics, activities and clubs | 搜索主题、活动和俱乐部 |
| `official.search` | Localizable | Search activity names or cities | 搜索活动名称或城市 |
| `ticketWallet.untitled` | Localizable | — | — |
| `compliance.marketing` | Localizable and AccountCompliance | Marketing and coupons | 营销消息与优惠券 |
| `compliance.roam` | Localizable and AccountCompliance | Roam location | 漫游定位 |
| `settings.signOut.message` | Localizable | You’ll need to sign in again on this device. Your tickets, orders and coupons stay on your account. | 本机登录态清除，下次进入需要重新登录。已购通行证、订单和券都保留在账号里，不会丢。 |
| `member.privacy.media.open` | MemberProfile | View | 查看 |
| `member.privacy.presence.off` | MemberProfile | Turn off | 关闭 |
| `member.privacy.roam.withdraw` | MemberProfile | Withdraw | 撤回 |

`tools/build_compliance_catalog.py` keeps the same roam and marketing pair so a later run does not put the old Chinese back. `docs/search-map-localizations.json` matches the player placeholder, because `Tests/ContractChecks/test_search_map_contracts.py` compares that file to the catalog.

## Pages left

Non-merchant `docs/parity/page-map.csv` rows with status `exists` or `partial` whose native file is on this commit, and not in the table above. 106 pages. Gated, merged, and dropped rows were not opened. Merchant rows were not opened.

- pages/template/index
- pages/talent/list/index
- pages/member/index/index
- pages/roam/index
- pages/agreement/index
- pages/deregister/index
- pages/team/detail/index
- pages/team/join/index
- pages/play/index
- pages/play/poi-challenge/index
- pages/activity/detail/index
- pages/activity/baoming/baoming
- pages/activity/official-detail/index
- pages/activity/official-inbox/index
- pages/activity/official-mine/index
- pages/activity/official-organizer/index
- subpackageA/pages/myproject/index
- subpackageA/pages/infomation/infomation
- subpackageA/pages/infomationdetail/infomationdetail
- subpackageA/pages/assetcenter/income-detail/income-detail
- subpackageA/pages/assetcenter/earnings/index
- subpackageA/pages/assetcenter/analysis/index
- subpackageP3/pages/growthcenter/index/index
- subpackageP3/pages/growthcenter/leaderboard/index
- subpackageP3/pages/stamp-camera/index/index
- subpackageP3/pages/stamp-album/index/index
- subpackageP3/pages/badge-wall/index/index
- subpackageP3/pages/badge-3d/index
- subpackageP3/pages/object-cards/index/index
- subpackageB/pages/im/list/index
- subpackageB/pages/im/chat/index
- pages/publish/simple/index
- pages/publish/activity/index
- pages/publish/template-intro/index
- pages/club/apply/index
- pages/club/badges/index
- pages/club/create/index
- pages/club/customer-detail/index
- pages/club/customers/index
- pages/club/detail/index
- pages/club/edit/index
- pages/club/enroll/index
- pages/club/checkin-detail/index
- pages/club/event-ops/index
- pages/club/governance/index
- pages/club/group-code/index
- pages/club/notify/index
- pages/club/settlement/index
- pages/club/topic-detail/index
- pages/club/topic-story/index
- pages/topic/index/index
- pages/topic/merchantinfo/merchantinfo
- pages/topic/merchantapply/index
- pages/topic/pricing/index
- pages/topic/pricing/partner/index
- pages/coop/list/index
- pages/coop/invite-detail/index
- pages/coop/invite/index
- pages/coop/nearby/index
- pages/coop/finance/index
- pages/coop/settlement-detail/index
- pages/square/detail/index
- pages/templatedetail/templatedetail
- pages/address/address
- pages/addressinfo/addressinfo
- pages/shezhi/about/index
- pages/userinfo/userinfo
- pages/mylike/mylike
- pages/crop/index
- subpackageMember/free-explore/index
- subpackageMember/character/index
- subpackageMember/orient-score/index
- subpackageMember/invoice/index
- subpackageMember/invoice-detail/index
- subpackageMember/invoice-apply/index
- subpackageMember/invoice-titles/index
- subpackageMember/invoice-title-edit/index
- subpackageMember/coupon-wallet/index
- subpackageMember/coupon-qr/index
- subpackageMember/coupon/coupon
- subpackageMember/couponInfo/couponInfo
- subpackageMember/mycanyu/mycanyu
- subpackageMember/mycanyuinfo/mycanyuinfo
- subpackageMember/myinvite/myinvite
- subpackageMember/order/order
- subpackageMember/orderinfo/orderinfo
- subpackageMember/points-history/index
- subpackageMember/report-mine/index
- subpackageMember/report-detail/index
- subpackageMember/appeal-mine/index
- subpackageMember/tixian/tixian
- subpackageMember/tixianjilu/tixianjilu
- subpackageRoam/citynode-code/index
- subpackageRoam/history/index
- subpackageRoam/poi-detail/index
- subpackageRoam/session/index
- subpackageRoam/nearby/index
- subpackageRoam/citystamp/index
- subpackageRoam/my-teams/index
- subpackageRoam/official-routes/index
- subpackageRoam/official-route/index
- subpackageTools/capsule/index
- subpackageTools/monthly-recap/index
- subpackageTools/exploration-goals/index
- subpackageTools/anniversary/index
- subpackageTools/exploration-export/index
