# r2 · verify-r1 batches 4 and 5 · run order

File `0YyoybGnU1KG0657wdGCPX`. Plan: `review/verify-r1.md` §2.2, §4 Batch 4, §4 Batch 5, §5.
Executor: Opus 5.5 · task `task_97634259dad9` · 2026-11-16. Budget: 150 Figma calls today (count in `LOG.md`).

## Owner answers (coordinator msg_2cfff16fd299, 2026-11-16)
All §5 answers are **owner-confirmed**; annotations read `Owner confirmed 2026-11-16 (verify-r1 Q#)`.
- **Q2 CHANGED: keep** the merchant identity step (真实姓名 + 身份证号, 18 chars, last may be X), inline error under the field,
  privacy line 「仅用于商家资质审核，加密保存」, ID shown masked `110***********1234` on review and after, secure entry with no autofill.
- Q3 neutral switch tint · Q6 hide the external-game price · Q8 账户余额 ¥560.00 · Q9 首页 header = 消息 + 搜索 · Q10 three sheet headers, written into the handbook.

## How the scripts are built
- `src/_prelude.js` (helpers: pages, bound paints, text, annotations, archive, prototype relink), `src/_meta.js`, `_scrim.js`, `_motion.js`, `_census.js` are shared.
- `python3 build.py` → `out/NN-name.js` (apply) and `out/NN-name.dry.js` (report only). Each script switches page once, returns `R` (touched / created / removed / archived / info / warn).
- Ids created by `01-lib` go into `ids.json` (`KB_ID`, `DP_ID`, `MENU_ID`, `MET_ID`), then rebuild.
- Every script is idempotent by name where it creates frames (re-running replaces its own output).

## Run order (≈ 45 calls + screenshots + fixes)
| # | Call | Page | Items | Calls |
|---|---|---|---|---|
| 0 | `get_metadata` (no node) poll, then `create_session` | — | — | 1 + polls |
| 0b | `search_design_system`: “Date Picker”, “Keyboard” | — | 4.6 (Apple iOS kit available?) | 1 |
| 1 | `01-lib.js` | Library 6:3 | 4.2 Theme Card meta · 4.3 Club/Row Menu bar · 4.4 Merchant/Nav Bar More + Merchant/Menu · 4.6 stand-ins · 4.7 Editor/Switch → ink (Q3) · Merchant/Metric Module (5.6) · Q10 handbook board | 1 |
| 1s | screenshot: new Library section + handbook board | | | 1–2 |
| 2 | `02-result-merge.dry.js` → `02-result-merge.js` | Library | 4.8 Editor/Result merge (C1, C2, C3 instances) | 2 |
| 3 | `03-P-create.dry.js` → `03-P-create.js` | P | 4.1 create flow, relink flow 5, 俱乐部已创建 · 去看看 | 2 |
| 4 | `04-P-misc.js` | P | 4.2 (instances), 4.6 keyboard 204:21385, 4.9 lobby 204:15032, 4.9 scrim 210:9137, Q8, Q9, 5.8 | 1 |
| 4s | screenshots: P create1, create5, 210:8239, 204:15032 | | | 3–4 |
| 5 | `06-R1-PL10.dry.js` → `06-R1-PL10.js` | R1 | 5.5 old-kit twins → Player/* | 2 |
| 6 | `07-R1-PL33.dry.js` → `07-R1-PL33.js` | R1 | 5.6 PL-33 017 states | 2 |
| 7 | `05-R1.js` | R1 | 4.2 twins, 4.9 scrim 169:6954/169:7170, Q8, Q9, 5.8 | 1 |
| 7s | screenshots: 169:6954, one 228:* state, one PL-10 twin | | | 2–3 |
| 8 | `08-R3.js` | R3 | 4.3 223:3698, 5.4 chips + comment menu, 5.8 | 1 |
| 9 | `09-R2.js` | R2 | 5.3 附近 rasters, 5.8 | 1 |
| 9s | screenshots: 223:3698, comment-menu frame, 204:34773 | | | 2–3 |
| 10 | `10-R4-onboard.js` | R4 | Q2 identity step (+ error frame, masking), 4.5 statuses, 4.9 营销 | 1 |
| 11 | `11-R4-menus.js` | R4 | 4.4 nav ⋯ + open menus, MR-27 voice | 1 |
| 12 | `12-R4-MR24.dry.js` → `12-R4-MR24.js` | R4 | 5.6 MR-24 AI 参谋 | 2 |
| 13 | `13-R4-boards.js` | R4 | 5.2 spec boards, 4.10 archive | 1 |
| 13s | screenshots: 182:7628 + error frame, 182:7693, 183:1731, 182:8065, one ⋯ frame, 182:8263 | | | 4–5 |
| 14 | `14-R5-archive.js` | R5 | 4.10 twins → Archive | 1 |
| 15 | `15-R6.js` | R6 | 4.10 A10/A11 → Archive, 5.8 | 1 |
| 16 | `16-N1.js` | N1 | 5.8 | 1 |
| 17 | `17-C1.js` | C1 | 4.6 246:6728/6908, 4.9 links + 删除节点, 5.7 census | 1 |
| 18 | `18-C3.js` | C3 | 4.6 239:625/771, 5.1 result sheets, Q6, 5.7 census | 1 |
| 19 | `19-C2.dry.js` → `19-C2.js` | C2 | 4.10/F-12 under-sheet bases, Q6, 5.7 census | 2 |
| 19s | screenshots: 246:6728, 239:625, 238:19113, 249:16773, one C2 sheet | | | 3–4 |
| 20 | Archive page screenshot + final tidy check (stray page-root nodes on touched pages) | | | 2 |

Rule: a script that errors is rolled back by Figma; fix and re-run that script only. A script whose report shows a wrong match gets one targeted follow-up call.

## As run
See LOG.md: 50 Figma calls. Calls were made from trimmed copies of these scripts (helpers inlined per call); fixes found on screenshots were applied in follow-up calls listed in LOG.md. `out/20a-C2-bases.js` is cfg-D-cf44.js with the job list for 4.10 / F-12.
