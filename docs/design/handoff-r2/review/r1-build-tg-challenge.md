# Part A · 挑战 family + G4 (executor A+B), page C2 `235:178`

Built from the A1 executor's kit (section `236:15762`: C2/Input, C2/Dropdown, C2/Switch, C2/Drag Handle) and by cloning its own card blocks from the 问答 card `238:16389` (title row, card, sub-header, field, switch row, list item with drag handle, dashed add row, two-column grid, inline error, dropdown panel), so the cards match the A4 问答 / 推理 / 互动 sections exactly. Light topic-editor mode (MP-Light).

## Section `241:20608` "A4 玩法设置卡 · 挑战 family（A4.24–A4.34）" — 27 frames
| Spec | Frames |
|---|---|
| A4.24 D20 `check` | a 默认 · b 已配置 (full) · c 加上属性展开（六维属性清单）· d 主题没有属性（技能文本）· e 属性读取失败 · f 幸运加分下拉 · g 魔鬼交易开 (full) · h 情境加值拖动排序 (Q8) |
| A4.25 D20 加值 | a 已填 · b 掷骰方式下拉 · c 校验错误 (DC, 成功结果) |
| A4.26 计步 | a 已填 (Apple 健康 wording, Q7) · b 校验错误 |
| A4.27 变色就点 | a · b 校验错误 |
| A4.28 弹球 | a 不限时 · b 限时开 |
| A4.29 安静挑战 | 1 |
| A4.30 罗盘指向 | a 未取值 · b 已取值 + toast · c 设备没报方向 + 校验错误 |
| A4.31 喊一嗓子 | 1 |
| A4.32 倒计时 | a · b 校验错误 |
| A4.33 精准停表 | 1 |
| A4.34 输入挑战 | a 旧模板（卡内限时）· b 新模板（限时移到工具）|

## Section `243:25477` "G4 传感器挑战" — 7 frames
未选类型 · 类型下拉 · 保持静止已填 · 步数挑战未填完 · 音频片段已填 · 字段错误 · 已保存的设置不支持（只读）. Copy from spec G4 (App `TemplateSensorDraftConfigurationView`).

## Decisions
- 难度 is a dropdown: the owner reference ③a–③d (`5390:13149…13232`) draws it so; the spec text says segmented. Owner wins.
- 状态不好时松一点 is drawn inside the D20 card, as in the owner reference.
- Error copy is the validator's (`advanced-game-config.js`), e.g. `计步目标须为 100 至 100000 步`, `罗盘目标方位须为 0 至 359 度`, `D20 成功结果须为 1 至 200 字`.
- Q7: steps say `以 Apple 健康同步的步数为准`. Q8: list rows have drag handles; A4.24h shows a lifted row with haptic notes.
- Attributes are the theme's 六维 (探索 / 体魄 / 洞察 / 魅力 / 运气 / 城识 from N1). Condition names, costs and result texts are samples (annotated).

## Not drawn here (already on C2)
- A4.35 扫码参与 + A11.3 扫完回复 / AR: A2 executor, section `238:12378`.
- A4.36 legacy cards, A6.2, A9: A2 executor, section `239:23105`.
- A11.5 添加加值 / 添加代价: A2 executor, section A11.
