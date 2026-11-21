# QA · C2 玩法配置 · 模板编辑 vs review/r1-theme-gameplay.md Part A (2026-11-15)

Three executors drew C2: A1 (A0–A4 问答/推理/互动, kit `C2/*` section 236:15762), A2 (A5–A13, legacy, kit `TE/*` section 236:14482), A+B (挑战 family A4.24–A4.34, G4). C1 and C3 not touched.

## Coverage — 273 frames in 20 sections
Every Part A item and state has frames: A1.1–A1.13 (A1.3 is the restored R5 frame 94:4659), A2 items 1–20 (incl. from=fabu / from=citynode, scan reply, relax, rules limit, modules removed, resources / 旧设置), A3 (4 categories + 3 disabled reasons), A4.1–A4.34 (+ A4.35 via A11.3, A4.36a–e), G1, G2, G3, G4, G5, A5 + A5.3 effect rows, A6.1/A6.2, A7, A8, A9, A10.0–A10.11 + A11.8, A11.1–A11.9, A12 preview ×5 + verdicts + save results.
- Added now: A2.10 has three toasts in the spec; two were missing → `A2.10 · 相册没有照片`, `A2.10 · D20 编辑页演不了`.
- Not drawn by anyone: **G6** (one glyph + preview tile per picker tag, 32 tags). It is new illustration work rather than a missing state; the picker currently shows generic glyphs.

## Lint
Text under 11 pt 0 · QA/seed strings 0 · raw codes (FAILED / EXPIRED / ELAPSED_TIME / SCORE / COMPLETED_UNITS / ACTIVITY / TOPIC / END_IMMEDIATELY) 0 · WeChat-only wording (微信 / 订阅消息模板) 0 · frame overlaps 0 · unlabelled frames 0 · all frames 393 wide · 0 loose nodes.

## Unification (the two kits now render the same)
| Difference | Was | Now |
|---|---|---|
| Section titles above cards | 15 Semibold (A1, A+B) vs 16 Semibold (A2) | 16 Semibold everywhere (544 runs) |
| Nav bar title | A1 frames hid the bar's title and drew a left-aligned 16 pt text | centred 18 Bold like the native bar in A2 frames (63 frames) |
| Sheet header title | `C2/Sheet Header (TE)` 16 Semibold vs `TE/Sheet Header` 20 Bold | 20 Bold (component edit; 10 + 49 instances) |
| Switch off track | #E6E6E6 vs #E4E4E4 | #E4E4E4 (component edit) |
| Switch-row labels | 14 Medium vs 14 Semibold | 14 Semibold (449 rows) |
| Dashed add rows | #8C8C8C stroke, 14 Medium vs #DBDBDB, 13 Semibold | #DBDBDB dashed 4/3, 14 Medium (289 rows + TE/Add Row component) |
| Dropdown height | — | already 41 in both kits |
| Inputs | white on grey panels (A2) vs #EFEFEF on white cards (A1) | kept: both follow A0 (input contrasts its container); owner ruling #EFEFEF/#E4E4E4 |

## Tidy and index
- Sections restacked in spec order: kits → A1 → A2 → A3 → A4 问答 / 推理 / 互动 / 挑战 → G4 → A5 → A6 → A7 → A8 → A10 → A11.3 → A11 → A12 preview → A12 save → legacy; each fits its content; 240 px gaps; no section overlaps.
- Index 139:2: new column `C2 玩法配置 · 模板编辑` after N1 with 20 section links; coverage line updated.
