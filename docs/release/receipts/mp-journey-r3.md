# mp-journey r3 — receipt

Branch `mp/r3-journey` from `origin/ui/combined-r7`. Owner rule (round3-1127): every page is built from its
mini-program page (all MP sections, MP order, fields, states, copy, navigation), then optimized natively.
Source: `origin/mp-source:chengyinhub-xcx`. No other r3 lane (`mp/r3-home|roam|publish|club|mine`) touched these
files; `mp/r3-mine` only gated 查看报名凭证 in `PlayerJourneyViews` (not on this lane's pages).

## Pages

| MP page | Native view | MP sections (top → bottom) | ✓ / added / fixed | Optimizations |
|---|---|---|---|---|
| `subpackageJourney/pages/landing` | `App/JourneyLandingViews.swift` `JourneyLandingView` | headline · duo (inviter ↔ you / seat no) · inviter name · title pill · 怎么玩 tiles + rules · facts · footer (primary, inline error, 先逛逛) · states loading / 链接已失效+返回 / 链接暂未读取+重试 / invalid | all ✓; **title pill added** (MP `jn-pill jl-pill`: the route name now sits in a capsule) | `.fill.tertiary` capsule, wraps to 2 lines (P12); existing `.borderedProminent` primary with ProgressView / checkmark morph (P3), Reduce Motion on the duo lights |
| `subpackageJourney/pages/promo` | `JourneyLandingViews.swift` `JourneyPromoView` | buckets + 待核算 · 成交 · 我的邀请链接 · 暂无可核实记录 · states loading / 登录后查看+登录 / 收益暂未加载+重新加载 | all ✓ | inset-grouped List, `LabeledContent`, monospaced amounts, pull to refresh |
| `subpackageJourney/pages/report` | `App/JourneyReportViews.swift` `JourneyReportView` | title (本局战报 / 主题记录) · eyebrow + result pill · **three tiles 完成节点 · 用时 · 解谜分** · 名次 / 提示扣减 / 主题背包 / 本局回忆 / 同行席位 rows · 节点 list (photo thumbs) · footer 结算 + 分享 / 刷新结果 · rank sheet · memory timeline sheet · states | **fixed**: native dropped unread tiles and moved 本局不计分 to a subtitle; now always the three MP tiles, unread values a muted "—", unscored run says 本局不计分 inside the 解谜分 tile (MP `is-muted`). `R4PlayFlowTests.testReportKeepsTheThreeMPTiles` repinned. The 反馈 row (U08-02, server-gated) stays last in the rows card. | tiles scale down on one line (`minimumScaleFactor`), `.tertiary` for muted values, VoiceOver combines each tile |
| `subpackageJourney/pages/seats` | `JourneyLandingViews.swift` `JourneySeatsView` | 1 主题头 (cover → name) + 以 X 身份游玩 · 编辑 · 2 一起玩的人 N/M + 邀请 + seat circles · 3 怎么玩 tiles · 去起点 · invited list (撤回) · invite card sheet | **reordered**: cover now above the name; 以 X 身份游玩 row moved from after 怎么玩 to directly under the head (MP section 1); route-facts card (`JourneyLobbyHowToCard`) kept in the 怎么玩 slot above the tiles | GroupBox rows, `.borderedProminent` 去起点 + system confirmation dialog, ⋯ menu for 撤回 |
| `subpackageJourney/pages/settle` | `JourneyReportViews.swift` `JourneySettleView` | step dots · 1 总览 (seal, result, topic, 本关名次, 分数 / 节点 / 辅助完成 / 开局 cells, finish offer) · 2 排行榜 · 3 评价 (stars, tags, text, count, error) · 4 分享 (帖文/故事 segmented, card) · footers | **fixed** overview footer: MP primary is 看排行榜 with 完成 as the quiet link; native had 完成 primary / 看排行榜 secondary. Other steps ✓ | count-up score (`numericText`), segmented share kind, rating result in the submit button (in place of the 谢谢 pop) |
| `subpackageTools/monthly-recap` | `App/RoamPassportToolsViews.swift` `RoamMonthlyRecapView` (+ `RoamMonthlyRecapDetailView`) | month nav · error + 重试 · 正在读取当月记录… · hero counts (hidden when all 0) · kind chips · 每周 bars · rows · 这一类本月没有记录 · 读取下一页 | all ✓ | segmented kind picker, `Text(date, format:)` month, pull to refresh |
| `subpackageTools/anniversary` | `RoamPassportToolsViews.swift` `RoamAnniversaryView` | date + 换一天 · error + 重试 · 2 card skeletons · memory cards (N 年前, title, 完成, 查看当前路线) · 这一天还没有回忆 · 读取更多 | all ✓ | system `DatePicker`, redacted placeholders |
| `subpackageTools/exploration-goals` | `App/RoamPassportPrivateToolsViews.swift` `RoamExplorationGoalsView` | error · 以原操作重试 · selected goal detail (收起 / 取消此目标) · create form (metric, target stepper, 时间段, 开始 / 结束（不含）, 创建目标 / 先不定) · 我的目标 N 个 · rows · empty · 读取更多 · FAB | all ✓ (FAB = toolbar ＋) | `Stepper`, segmented pickers, `DatePicker`, destructive confirmation dialog |
| `subpackageTools/exploration-export` | `App/RoamExplorationExportView.swift` | error · range chips + 开始 / 结束 · 准备导出 · progress % + 已读取 n / N · 这个范围内没有记录 · file card · 分享 / 保存到手机 · 读取下一块 / 开始读取 · 重新选择范围 | all ✓ | `ProgressView(value:)`, segmented range, system share |
| `pages/play/circle` | `App/PlayCircleRetiredLinkView.swift` + `PlayCircleLegacyLink` | retired shell: with topicId → redirect to `pages/play/index`; without → 探索链接不完整 + 返回首页 | ✓ | `CYEmptyState` |
| `pages/play/poi-challenge` | `App/ChallengePOIView.swift` | 一次一屏: loading skeleton · error (挑战暂时打不开 + 重试 + 返回地图) · photo screen · quiz screen · medal screen (写一张城市签 / 查看徽章墙) · gap pill (还差 xx 米 · 导航) | **fixed**: the photo card no longer stays on the quiz screen, and the photo screen of a node that still has a question shows no submit (the quiz screen sends photo + answer, as MP `/complete`) | place card + step checklist kept as the progress header (P4) |
| `pages/play/index` (section C 节点详情卡) | `App/NativeR2/CityOrientation/CityOrientationPunchSheet.swift` | cover (station → chapter → route fallback) + 第 N 站 tag + done stamp · name · meta · description · distance / hours · actions · notes | **added** station header: `PlayStationArtwork` cover with a 第 N 站 capsule and done check, meta line, description (hidden while story-locked), 距离 and 开放时段 rows; the name stays the navigation title | material capsule tag, `LabeledContent`, monospaced distance in MP units (米 / 公里 in zh) |
| `pages/play/index` (游玩工具 sheet) | `App/MPGap/PlayRoam/PlayToolsAndLeadSheetView.swift` | 领队 rows · 内容 rows · 证据卡 · 伏笔 · 本局读数 · 扫码到达 / 切换章节 · 入场码 · 背景音乐 / 旁白 / 动态效果 | **reordered**: 入场码 moved from the content rows to its MP slot just above the preference toggles | Form sections, Toggles |
| `pages/playkit/index` | — | MP placeholder page (`wx.reLaunch` home; no entry points) | nothing to build | — |

## Not done (next pass)

- `pages/play/index` is the 2,078-line city-game runtime. This pass covered section C (station sheet) and the
  游玩工具 sheet order. Still to compare section by section: 本局线索 / 队伍位置 / 旅程手记 / 自动记录足迹 /
  到点提醒 tools rows (no native key found by zh copy — may live under other names), the free-explore card pack
  (mode 2), the hero card expansion, the assemble screen, and the task page (p03).
- Settle 谢谢 pop: native shows the rating result in the submit button and moves on; MP shows a centred pop with
  去分享. Kept as the in-place pattern (xrefs-1 B.0); flag if the owner wants the pop.

## Gates

- `python3 tools/generate_project.py` — ok
- `python3 tools/check_scaffold.py` — PASS
- `python3 -B tools/check_a11y_lint.py` — PASS, 0 new
- `python3 -B tools/contract_ratchet.py --check` — see commit (new must be 0)

No new string keys: every label reuses an existing catalog key with en + zh-Hans
(`u10.template.stopNo`, `nativeR2.city.metric.distance`, `creator.family.timeWindow`, `mp.report.notScored`,
`action.done`, `mp.settle.toRank`, `playTools.entryCode`).
