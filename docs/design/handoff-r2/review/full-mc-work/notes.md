# Working notes — full-merchant-creator review (Fable). Not the deliverable.

Figma session 10e9ba5f-c681-40b6-b651-b72aedd15698. Outlines: $TMPDIR/rev/r4-outline.txt, r5-outline.txt (may be wiped).
Scope counted: R4 90:26 = 339 frames / 30 sections; R5 90:2 = 126 frames / 29 sections; D/E/F elsewhere: R1 (116:1173 T03, 113:1347 T01, 116:1169 T02, 95:1001 T15), R2 (105:1588, 105:1620, 124:1856, 91:1411), R3 233:3449 (N01/N02), R6 (230:2853 A01, 230:2942 A02, 230:3003 A03, 231:6832 A04, 231:7006 A05, 231:7474 A06, 231:7608 A07).

## Programmatic audit, R4 (all 30 sections) — facts
- Prototype reactions: 0 on every frame of R4 (339/339). No flow is wired.
- Type scale drift. Twins (优化) use 11/12/14/16/18/29 plus leftovers 13, 15, 19, 21, 23, 25, 27, 44. New C frames use 11/12/14/16/18/22/29/32/42. Data hero = 44 in twins (097/098/099/111) vs 42 in new frames and twins 105/106. K/State text = 15 (off scale) in every generic state. 114 发帖 (225:8697) is a clone of restored frame: 13×41, 15×33, 17×2.
   - twin 113 (182:8263): 13×4, 21×3, 25, 27×2. twin 122 (183:2102): 13×9, 21×9. twin 125 (183:2355): 13, 22×3, 27. twin 112 (183:1906): 23, 29×5. twin 110 (182:7862): 13×6, 15×2.
- Button sizes mixed inside one flow: apply twins 100–102 use Button Size=Pill; new apply frames (首屏, 校验, 已上传 …) use Size=Default. 116 twin Pill vs 116 可提交 Default. 121 twin Pill vs 121 添加 Default.
- Controls under 44 pt: Button Size=Small = 34 high (58×34, 84×34, 97×34, 110×34, 162×34) in ~25 frames; Chip = 34 high (56/68/80/91 × 34) everywhere chips are used.
- Contrast below 4.5:1: placeholder/disabled #6F6F6F on #EEEEEE/#EFEFEF = 4.3–4.4 (all inputs, all disabled buttons); on #E4E4E4 = 4.0 (step-4 inputs twin 182:7628); rating stars #F59F00 on white = 2.1 (112 frames); destructive text #D0323B on #EEEEEE = 4.3 (删除回复 183:1906, 移除 233:11700, required * 182:7590); link #2563EB on #EEE = 4.5 borderline; 111 twin "领取 5 · 核销…" #6B6B6B on black = 3.9 (182:8065).
- Nav inconsistency: 111 营销 twin (182:8065) uses Nav Bar Type=Back + Merchant Tab Bar; the new 111 states (223:10741 …) use Type=Root + Tab Bar. 114 relation states use Root + Tab Bar, 114 发帖 uses Back.
- Sheets/alerts are drawn as absolute "scrim + sheet · X" layers over a cloned page (not components, except K/Alert?). Two primaries visible in sheet frames (page CTA + sheet CTA): 221:2905, 221:2996, 221:3051, 227:17985, 233:10091.
- 117 修改图片 (227:18200) has no Nav Bar instance.
- 118 引导 2/3/4 sheets are named "sheet · result".

## Programmatic audit, R5 (all 29 sections) — facts
- Prototype reactions: 0 on every frame of R5 (126/126).
- Restored frames and twins on R5 are layoutMode NONE (absolute); new D frames are VERTICAL auto-layout. On R4 everything is VERTICAL.
- Two executors, two kits: R4 new frames (C) use K/State + K/Inline Error from R3 kit 217:4511, Button Size=Default, no Home Indicator, loading frames WITHOUT a K/Skeleton instance (hand-drawn). R5 new frames (D) use K/State (219:5570, has Kind=Location/Loading), K/Skeleton/list|card|amount, a "Home Indicator" layer, Button Size=Pill. K/State on R4 has Kind=Info for missing link; R5 uses Kind=Info too. Check visually whether the two K/State look the same.
- Publish twins (48/49/49a/50/56 → 171:5929, 188:5698, 171:6166, 171:6496, 171:6575; 51 → 189:3397; 52 → 171:6655; 53–55 → 186:5655/5718/5768; 57 → 188:5893): sizes 12/13/14/15/16/31 — off the handbook scale (13, 15, 31). 48 twin has Button Primary ×3 + Secondary ×4 on one screen. Need to check vs TE screens.
- 131 申报本次供给 (224:2553), 131 评价 (224:2647), 132 编辑邀约语/已发送/发送失败 (224:6175/6245/6292) are clones of the RESTORED frame (sizes 13/15/19/30), not of the twin → old type scale under the sheet.
- 132 states 加载中/无权限/加载失败 carry a "0.00" placeholder input (224:6522 etc.) — a money field prefilled 0.00 visible even in error states; two K/State in one frame (224:6596, 224:6672).
- 133 有商家 (225:2730): font 11.2 ×2 (non-integer). 150 twin: 23.5. 
- Controls <44: Button Small 34 high in 130 twin + new frames; 
- Contrast: 153 twin BIZ tag #F8F8F8 on #4C86FF = 3.2; 211 twin "暂时无法注销" #E5484D on #3A3A3C = 2.9 (18 pt); 130 保证金 "支付处理中…" (ellipsis in progress text, against d.7).
- No twin for: 143 地图搜索, 149 设置, 151 合作与推荐, 154 我的收藏, 155 图片裁剪, 210 用户服务协议 (should be labelled 无需优化 — verify).
- Dark-mode frames on R5: 57, 138, 143, 147–155, 209–211 (mode 81:0). Light: publish 48–56, coop 130–137.

## Visual notes by section (R4)
### M01 商家工作台 91:625 (twins 182:7328/182:7428, 180:7074, 180:7140; new 218:1623…218:3099)
- Twin vs new states disagree on the same page: hero ¥1280.00 is Regular 44 in twins, Bold 42 in new frames (218:1805, 218:2895); section headers 16 Regular ("项目", "我的消息") in twins vs 18 Bold in new; "全部 14 →" (arrow) vs "全部 ›" (chevron); avatar = store photo in twins, memoji default avatar in new frames; 营业中 tag has a dot in twins and none in new.
- ~70 pt dead band between status bar and greeting on every workbench frame (nav bar Root instance with no title). First 130 pt carries nothing.
- Tab bar: opaque white block, 5 icon-only tabs, no labels; megaphone / document / chat-bubble icons are not self-explanatory for 营销 / 模板 / 合作. Selected = filled glyph only.
- Partial-failure language differs: twin 099 (180:7140) uses a blue info banner "收入没更新成功 · 重新加载此部分"; new frames use red K/Inline Error "项目和待办加载失败 · 重试" (218:2997) and a red banner above the greeting (218:3099). Twin 099 avatar is an empty white circle.
- Name: page/tab is 工作台, new frames say 经营台 (218:1623 title, 218:2837 "登录后查看经营台").
- 消息展开 218:1688: each row has a 12 px × to dismiss (target ≪ 44); 4th row icon circle is empty; "清空" is a centred text+trash with no confirm.
- 更多 sheet 218:1993: 3-col grid of 6 tiles is left-aligned, leaves ~30 px on the right (tiles 107 wide, not filling). Sheet header: grabber + centred title + round ✕ (handbook T1 says title left, no grabber).
- 选择章节/节点 sheets 218:2159/218:2299: OK. Disabled row explains why (good). Check icon only on selected.
- Result sheets 218:2439/2577/2707: good structure (icon, title, one line, primary, secondary). Icon circles 64. No motion/haptic spec. Secondary "完成" is a grey filled button same height as primary.
- No scanner surface: 扫码 → camera → result has no frame (viewfinder, torch, manual code entry, camera permission denied).
- 登录 gate 218:2837: K/State action button is a small pill (~39 high).
- 核销员 218:1904: two actions centred, "当前岗位：核销员" as plain 11 pt text. OK.

### M02 商家入驻 92:854 (twins 182:7504/7546/7590/7628/7693; new 221:2200…221:3348)
- One flow, two looks. Twins: pill CTA pinned near the bottom (y≈815), field label 12 bold + spaced red *, "→" disclosure arrow, field 48 high. New states: 12-radius CTA placed inline right under the last card, label 14 medium + tight *, "›" chevron, field 46 high, red-outline error fields.
- Step titles differ for the same step: step 2 "告诉大家怎样找到你" (twin 182:7546) vs "店在哪、几点开" (221:2681); step 3 "补齐审核需要的资料" (182:7590) vs "上传经营资料" (221:2747).
- Step 4 twin (182:7628/182:7693) has NO submit button (audit: no Button instance) — the flow cannot be finished in the design. It also introduces new required fields (真实姓名, 身份证号) on a page titled "确认这份入驻信息"; consent control is a circle (reads as radio), text 11 pt; "行业类型 —" shown although the field is required at step 1.
- Twin step 3 upload tiles: + on the right for 营业执照, + on the left for 品牌形象图 (inconsistent); new 已上传 (221:2747) uses a 3-col grid — and repeats the same photo three times; helper "已上传 1 张 · 点 × 可移除" explains an affordance in text; × badge ≈ 20 px.
- 已通过 221:2477: primary CTA is "返回" (no "进入工作台"). 审核中 221:2339: primary black "返回" for a passive state. 未通过 221:2407 good (reason box + 重新申请) but does not jump to the failing step.
- Pending colour: 审核中 tag amber, 待复核 icon amber (M01), but 认领申请已提交 (221:2996) uses a BLUE clock.
- Chips: 行业类型 sheet (221:3108) selected chip = dark grey pill, unselected = bare text (no container); 经营时间 sheet (221:3188) selected day = pure black circle, unselected = grey circle. CTA "确定" (handbook: never 确定). Helper "点开始或结束时间，用滚轮选择".
- 俱乐部移交 221:2545: 继续 disabled, reason not stated next to it; "前往移交" 34 high.
- 认领 search sheet 221:2830: 搜索 button 58×34; "认领" is a bare text action in the row; disabled row "已有商家管理" OK.
- 首屏 221:2200: good (城 mark, 3 icon rows, one primary, one link).

### M03 账本 94:687 · M04 105 94:753 · M05 106 94:819 · M06 售后 94:877 · M08 预测 94:940
- Twin 104 (180:7203) rows show seed text "E2E 玩家小城 19:33" (QA string). New frames show "玩家小城".
- Ledger has three views with three titles (核销与退款 / 结算 / 项目动态) plus "核销记录" (无财务权限 221:3623) and nav title "账本" (无权限 221:3896, 链接已失效 221:3930). No switcher between views is drawn; entry per view unclear.
- 筛选 221:3542 stacks three filter states in one 852 frame (spec board, not a screen).
- Filter controls: 104 = 4-segment pill bar (black selected, tinted track in twin, white track in new frames); 107 = separate chips. 107 twin (182:7816) selected chip pure black, 40 high, title y≈168; 107 new frames (223:8043…) selected chip dark grey, 34 high, title y≈159 → page jumps between states.
- Timeline dot semantics conflict: apply flow (221:2339) done = green filled, current = black filled, pending = grey; ledger detail twins (180:7276, 182:7757) done = black filled, current = green ring, pending = grey ring.
- Sibling detail pages use different nav: 105 twin large left title "核销详情"; 106 twin centred nav title "对公结算", no large title. Generic states of 105 use centred title "核销详情" (title style changes between loading and loaded).
- 结算 221:3406: switch "结算到账提醒" is iOS green; "去我的资产" grey button; amber tag "¥39.00 调整待处理" sits beside hero. Good density.
- 空 · 结算 221:3819 shows ¥0.00 with "本月还没有入账" (true zero, OK).
- 正在更新 221:3966 shows BOTH "正在确认最新记录…" (with ellipsis) and "最新记录暂未取回，显示的是上次的数据" — refreshing and refresh-failed in one frame.
- 105 状态未更新 223:7797: stale strip is placed above the large title and pushes it down.
- 108 列表 223:9334: answer options 会 / 不会 are two identical grey buttons; iOS alert 223:9389 uses system blue text buttons (app tint should be neutral); irreversible "公布并结算" is not emphasised.
- 107 rows: "19:28 ·待回应" status as amber text only in twin; new frames use tags (平台审核中 blue, 已退款 grey). "已经到底了" footer.
- K/State (R4): 28 px line icon, title ~15 semibold, sub 12–14, action = small black pill (~36 high). Block starts ≈ 200 from top. Empty uses an inbox glyph, while restored empties 108/133/136 use the lime illustration (R4/Empty Illustration 94:600, MP/Empty Art 97:150).

### M07 售后详情 94:3300 · M09 公开主页 94:3622 · M10 营销 95:1750
- 109 twin (183:1731/183:1819): three equal white chips 同意 / 不同意 / 补充凭证 at the top, no primary; tapping opens a sheet that asks the same three-way choice again as a segmented control (223:8522) → choice made twice. Unlabelled icon-only round button right of the amount.
- Status colour: "平台审核中" is an AMBER tag in twin 109, a BLUE tag in 109 已处理 (223:9095) and 107 处理中 (223:8043).
- Hero amount 32 bold in twin 109 vs 42 bold in 109 已处理.
- Third timeline style in twin 109 (green dot / blue dot + blue bar / grey dot); 109 已处理 uses green + grey dots newest-first.
- Refund sheet 223:8522–8943: good two-step (1/2 → 2/2 confirm, summary, inline error, 确认同意退款 / 返回修改). Step counter "1 / 2" at the left of a centred title.
- 110 twin (182:7862/7964) and all 110 new frames: the cover-fade layer ends at y≈495 and cuts through the first line of body text (a visible seam through "上海黄浦区老城合作探索驿站…" and the first post). Nav title "主页" and grey tagline sit on a blurred photo (contrast not guaranteed). Stats 0 好友 / 0 关注 / 0 粉丝. Address "南京东路188号" here vs "南京东路 299 号" in apply status frames; twins of apply use another shop ("外滩九号书店驿站").
- 110 结果未知 223:10422: primary = "再试一次" although the copy says the request may have arrived (kit rule K8: verify first, never push retry).
- 111 营销: every tab-root frame shows the FIRST tab icon selected (工作台) — 营销 (223:11119, 182:8065), also 114 relation frames and N08. R4/Merchant Tab Bar has no selected-state variants.
- 111 无权限 223:10798 uses a red error banner for a permission state. 111 empty cards: centred title + left-aligned button (223:11032, 223:11119).
- Quick actions: circles on 工作台, rounded squares on 营销.
- 111 twin coupon card: grey "领取 5 · 核销 5" on black = 3.9:1.

### M11 口碑 95:1876 · M12 AI参谋 96:2257 · M14 节点 103:1801 · M15 报名节点 103:1863 (twins)
- 112: twin (183:1906) and new states are two different pages. Twin: "5.0 ★ 1 条已核销评价" line + 2×2 KPI tiles with four tinted icon squares + chips with counts (全部 1 / 待回复 0 / 低分 0 / 有图 1 / 平台…). New (225:7535 …): header card "5.0 ★ 1 条评价" + chips 全部/待回复/已回复/有图, no KPI tiles, different avatar, no "公开展示中" tag.
- 112 举报 225:7661 shows a spec note as UI copy: "提交后显示：举报已提交审核". 112 回复待确认 225:7735: buttons "读取原回复请求 / 复制原请求号" (engineering wording). Reply/发送/取消 buttons 34 high. Twin text actions 修改回复 / 删除回复 / 举报 are bare 12–14 pt text.
- 113 twin (182:8263/8356): greeting "晚上好，南京东路猫咖…" truncated; lavender bars = brand violet used for a chart; dot matrix + bars have no axis/legend/value; "0 位玩家到店" with 核销 2 (data contradiction); 推荐主题 card cover is a blank grey gradient; 核销率/复购率 "—" with reason (good).
- 115 twin (182:8448/8485): info card "ⓘ 在架节点 1/3" nearly empty; primary is a full-width black bar with left label + arrow ("投放节点 →") — a third primary style; "下线" is bare bold text.
- 116 twin (182:8521): centred nav title + 4-dot stepper with BLUE current dot; "待确认" in green text; black "确认这个店址" + disabled pill "提交投放申请" at bottom.

### 113/114/115/116 new states
- 114 俱乐部 225:8609: nav title "发现"; tab bar still shows tab 1 selected; partial-data notice drawn as RED error ("部分俱乐部资料暂不可用 · 其余俱乐部正常显示"); "邀请合作" 34 high.
- 114 发帖 225:8697: compose sheet header = 取消 / 发帖 / 发布 (text buttons), unlike every other sheet (centred title + ✕); 发布 looks enabled at 0/500; underlying page is the restored frame (old type sizes).
- 115 申请中 225:9682: centred nav title "城市节点", twin 115 has large-left "成为节点" → name and nav family differ. "撤回" blue link next to tag.
- 115 配额 225:10210: spec board "节点配额的四种状态" (4 states stacked), not a screen.
- 115 popover 225:10153: custom white popover overlapping the title; fine as native popover tip, needs anchor arrow.
- 116: twin (182:8521) = centred title + 4-dot stepper; new frames (225:10463 …) = large-left title + numbered cards 1/2. Two layouts for one page.
- 116 确认店址 225:10521: map is a 4-block grey/green/blue mock; UI contains spec notes: "没有店址时显示：请在地图上选择店门口 + 在地图上标店址"; 116 已提交 225:10578: "失败时显示：投放申请未提交".
- QR sheet 225:9842 good (QR 220, name, one line, 保存到相册).

### M16 品牌中心 103:1958 (no twin; 16 new) + twins 118/119/121/123
- 123 twin (183:2281): seed strings "E2E 玩家小城" ×2 and "smoke note" visible. Row arrows "→".
- 121 twin (183:2067): centred nav title + pill CTA pinned in a bottom bar; new 121 states use inline 12-radius CTA. 119 twin: large-left title + inline CTA "编辑".
- 118 twin (170:3821): onboarding sheet is an inset floating card (side margins, pill CTA, "跳过") — unlike all other sheets (edge-to-edge, 12-radius CTA). Headline ends with a Latin full stop ".".
- Blue text links (#2563EB) used as actions across new frames: 编辑 (227:17435), 添加自定义标签, 去发布一个活动, 联系运营开通 (227:17510), 上传二维码 (227:17603), 撤回 (225:9682), 移除, 换一家, 认领已有门店 link (221:2200). Handbook d.3: blue is status-only.
- 117 标签 227:17985: sheet on sheet (特色标签 + 自定义标签) — two T1 sheets stacked.
- 117 门店信息 read (227:17603) vs 编辑 (227:17672): a read mode then an edit mode for a plain settings list (extra tap; iOS habit = rows directly editable).
- 117 品牌故事 sheet 227:17892: error text "暂未完成" says nothing; CTA "重试保存".
- 117 升级权益 · 支付状态 227:18300: spec board (6 states stacked), not a screen. Same class as 104 筛选 and 115 配额.
- 117 修改图片 227:18200: full-screen black cropper, OK (native PhotosPicker + crop).
- Selected chips in 117 品牌介绍 = dark grey; day circles in 经营时间 = black.

### M17 AI 店铺角色 103:2005
- Onboarding step 1 (twin 170:3821) = inset floating card + pill CTA; steps 2–4 (227:18742/18806/18870) = edge-to-edge sheet + 12-radius CTA + back chevron. Same 24H illustration on all four steps. Headlines end with Latin "." .
- Spec notes in UI: 227:18696 "处理中显示：正在处理形象，请稍候"; 227:19212 "麦克风被拒绝时显示：去设置开启麦克风".
- 选现成的 227:18934: 5 of 6 characters are the same default memoji.
- Voice: hold-to-talk black circle (good, tactile) but no level meter/timer; 生成中 227:19366 has a manual "刷新状态" button; 结果未知 227:19560 "查询原请求 / 确认后另起独立请求" (engineering wording); 可用 227:19432 "清除声音" red text link.
- Base page read mode + "编辑" → edit mode + "完成编辑" (same two-mode pattern as 门店信息).

### M18–M21 (119 承接设置, 120 相册, 121 权益, 122 合作中心)
- 121 校验 230:8916: red banner "常备权益保存状态待确认 · 原请求可能已经保存，请先刷新列表再决定是否重试" while the primary "保存权益" stays enabled right below (banner says don't retry, button retries).
- 122 twin (183:2102/2192): nav title LEFT next to the back chevron ("‹ 合作中心") — a fourth nav style; 广场 tab = nine near-identical dark navy gradient cards (no covers, same date range on all) inside a light page; 官方活动 tab (230:9269) = white cards with photo covers, centred nav title. Two card languages + two nav styles on one page. "正在刷新官方活动…" has an ellipsis.
- 120 相册 230:8602: × badge 20 px on photos.
- Discard alert "还没有保存" consistent (继续编辑 / 放弃修改 red) across 117/118/119/120/121 — good.

### M24 本站准备与运行 115:748 + twins 125/126/128/129
- Status tag colours: "准备完成" BLUE in twin 124 (170:3884), GREEN in 多站 (233:9834). 待接受 blue, 运行中 green, 已暂停 amber, 已结束 grey.
- 运行中 233:9703: primary "出示打卡码" + three grey buttons (暂停接待 / 输入核验编号 / 扫码核验); "2 待核验" is a plain number, not actionable — the urgent task is not the primary. No live indicator for a running station.
- Danger fill red used for both irreversible (确认拒绝 233:9948) and reversible (确认暂停 233:9998) actions.
- 服务时段 233:10169: hand-drawn wheel picker (handbook: never draw system pickers).
- 本站打卡码 233:10254: dynamic QR "一次有效，扫后自动更新" with no refresh indicator.
- 结果待确认 233:9891: both actions secondary (correct per kit) — compare 110 结果未知 / 121 校验 / 118 结果未知 where retry is primary or wording is technical.
- 核验游戏提交 233:10091: manual number entry first; segmented 通过 / 驳回.
- Guidance block "这一站怎么接待" (你要做的 / 玩家会做什么 / 不能说的) is strong content; keep.
- 125 twin (183:2355): "备注：smoke note" seed string; small black pill "编辑" inside a card. 126 twin: status as green text "·已核销".

### M22 客户 115:658, M23 125, M25 126, M26 127, M27 128, M28 129, N08 233:12462
- 123 筛选客户 230:9592: sheet header = 取消 / title / 重置(blue) — third sheet-header variant; chips unselected = bare text; CTA "查看 2 位客户" (good).
- 123 导出 230:9905: spec board "导出横幅的五种状态" stacked in one frame.
- 126 已撤销 233:10782: 2-segment bar; twin 126 (183:2416) uses chips with counts.
- 128 触达明细 233:11311: UI contains spec note "没有逐人结果时显示：这次触达没有逐人结果"; five stat tiles with very small labels.
- 129 加入经营团队 233:11529: spec note "接受后显示：已加入经营团队，去工作台开始核销".
- 127 待签约/待验证 233:11034/11078: "签约链接需要在微信中打开" + CTA "复制签约链接" — WeChat-only hand-off, no next step in the app.
- N08 我的 233:12356: 我的资产 row clips/overlaps "¥1280.00" into "¥220.20"; tab label "推文" (elsewhere 帖文); stats "—" + "关系数据尚未开放给商家账号，暂显示 —". N08 frames show the correct selected tab; 111/114 frames do not.
- N08 模板 233:12260: segmented 主题/游戏 + search squeezed on one row; floating "+ 发布" pill above the tab bar.
- R4 visual pass complete: 30/30 sections viewed (twins + new at 1x; generic states at 0.56x for 10 sections, the rest audited by component only).
