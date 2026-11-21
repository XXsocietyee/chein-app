# G6 · gameplay icon + preview components (2026-11-15)

Source: the C3 executor's four G6 boards on C3 (`249:36388` 问答, `249:36556` 推理, `249:37576` 互动, `249:37739` 挑战; 37 tags). Refined into one component system; not redrawn from scratch.

## Components (C2 section `255:14133` "G6 玩法图标与预览", board in MP-Light)
- `G6/Gameplay Icon` `255:15248`: Type (37) × State Default / Selected / Disabled = 111 variants. 44 × 44, radius 12, resizes to 36 with the glyph centred.
  - Default: ink glyph on surface-2. Selected: white glyph on black (cta). Disabled: ink-3 glyph, 55 %.
- `G6/Gameplay Preview` `255:15249`: Type (37) × State = 111 variants. 120 × 90 mini play screen. Selected = 2 px ink inner stroke; Disabled = 45 %.

## Review against the icon rules (handbook d.6: coolicons, 24 grid, stroke 2, round, outline, colour from text)
| Found on the C3 boards | Fixed |
|---|---|
| Tiles tinted per family (pink fill, red / blue / green / brown glyphs) | Monochrome: every glyph and fill bound to MP tokens (ink, ink-3, surface-2, cta, cta-ink) |
| Glyph box 23 px, stroke 1.8, 3 vectors without round caps | 24 px box, stroke 2, round caps and joins |
| 刮刮卡 glyph empty | redrawn: card + scratch zigzag |
| 弹球 = same glyph as 拍物成卡 | redrawn: phone + ball + bounce path |
| 揭晓式猜图 = same grid as 九宫格 | redrawn: frame with revealed pixel blocks |
| 抛硬币 showed an arrow-in-circle | redrawn: coin (two rings + face line) |
| 倒计时 ≈ 精准停表 (both clocks) | 倒计时 redrawn as an hourglass |
| 翻卡 ≈ 猜图 (two overlapping squares) | redrawn: card with ? |
| Preview text at 8–10 pt (预测, 排序, 输入挑战) | raised to 11 pt; numeral dots and input pill resized to fit |

## Placed
- C2: 147 `gameplay tile/*` frames replaced by instances (A3 选择玩法 ×104 at 44; A1 / A2 / A4 chosen-玩法 rows ×43 at 36): 6 Selected, 16 Disabled (row dimming moved from the row to its texts so the tile is not faded twice), the rest Default. All 6 A3 picker footers now show the picked type's `G6/Gameplay Preview`.
- C3: the four G6 boards now show instances (37 icons + 37 previews), with a note pointing at the component set.

## F2.11 creator monetization (C3)
Already present: 定价模式 仅流量激励 / 付费购买 (TEST), 售价, 流量激励 = 积分, TEST 净销售分成. Added in all four F2.11 frames: note「付费购买只在测试环境、资金开关打开时可选，真实收款不对正式用户开放。流量激励一律按有效游玩结算为积分。」; removed the raw code `(POINTS)`.

C2 re-lint: 274 frames, 0 text < 11 pt, 0 overlaps, 0 unlabelled, 0 raw / QA strings. Index 139:2 C2 column now has 21 links (G6 added).
