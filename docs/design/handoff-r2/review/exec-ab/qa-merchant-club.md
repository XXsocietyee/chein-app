# QA · merchant and club output vs review/r1-merchant-club.md (2026-11-15)

Scope: all frames added for the spec by executors A/B (club), C (merchant console, R4) and D/E/F (cooperation, 新稿-only, app-only) on R1–R6. Pages C1–C3 not touched. Restored frames not edited.

## Coverage (spec item counts vs frames drawn)
- 81 screens; every PARTIAL/MISSING screen has at least as many frames as missing items. N03–N07 are covered inside B-C02 (管理员), B-C12, B-C20, B-M24 and T01/T02, as the D/E/F manifest notes. Nothing missing.
- New frames checked: R1 51 · R2 20 · R3 207 · R4 261 · R5 50 · R6 16 = **605**.

## Findings and fixes
| Check | Found | Fixed |
|---|---|---|
| Overlapping frames (per section) | 0 | — |
| Frames without a label above | 0 | — |
| Frames not 393 wide | 0 | — |
| Text under 11 pt | 12 frames / 14 runs (R1 到店页 11 frames「暂无排队数据」10 pt; R4 N08 我的 1) | 14 → 11 pt |
| QA seed / raw strings (E2E 玩家…, smoke note, smoke-rt-post, 13900000004/09, order no. …E2E0002, request id RQ-…) | 28 runs (R4 23, R3 5) | 28 replaced (玩家小城, 沪上寻踪搭子, masked phones, plain order no., time instead of request id) |
| Latin placeholder text / second currency | 0 (only City Walk, Logo, Excel) | — |
| **State kits** | 3 systems: A/B kit (R3 217:4466), D/E/F duplicate kit (R5 219:5570/5645/5668, same look, other prop names), C inline blocks (87 `state · *`, 18 `inline error`; gates used a pink disc icon) | Unified on the A/B kit: added Kind=Location, Kind=Loading and Type=form; swapped 61 D/E/F instances (47 State, 13 Skeleton, 1 Alert) and deleted the D/E/F kit; replaced 86 C state blocks and 18 inline errors with kit instances. 1 C empty state kept on purpose (it carries the lime illustration). |

After fixes, re-lint on R1/R3/R4: 0 small text, 0 seed strings, 0 overlaps.

## Tidy
- R3 (22 sections) and R4 (30 sections): sections resized to fit content, restacked at x=0 with 240 px gaps, first-row gaps all 120 px, 0 loose nodes.
- Index 139:2: columns rebuilt in page order — links added: R3 +2 (K 状态组件, 会费 · 新稿), R4 +1 (商家 Tab 根页), R6 +7 (app-only club/merchant views); links to local-component sections removed (R4, R5, R6: 1 each); section/frame counts and stat tiles refreshed; a coverage line for the state-completion pass added. 222 links, 0 dead, nothing loose on the page.

## Left for the owner / reviewer
- Spec §7 open questions (merchant tab bar, 会费 route, merchantinfo tab names, club calendar) are still open.
- Kit instances on R4 are the dark-first kit shown in MP-Light; visually checked on 7 frames, all fine.
