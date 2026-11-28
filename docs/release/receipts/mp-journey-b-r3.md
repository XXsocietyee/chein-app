# mp-journey-b r3 — receipt (B lane, bottom-up)

Branch `mp/r3-journey-b` from `origin/mp/r3-journey`. Works the open rows of `docs/release/receipts/mp-journey-r3.md`
("Not done (next pass)") from the bottom up; the A receipt is never edited here. Source: `origin/mp-source:chengyinhub-xcx`.

## Rows finished

| A-receipt row | MP page | Native view | MP sections (✓ / added / fixed) | Level · optimizations |
|---|---|---|---|---|
| "联系主办 / 联系商家: MP puts it in 游玩工具 after the lead rows and only dials (number hidden) …" (11-28) | `pages/play/index.wxml:318` (`drow wx:if="{{playContact}}"`, after 整团结算) + `utils/play-hud-overlays.js` `loadPlayContact` / `callPlayContact` | `App/MPGap/PlayRoam/PlayToolsAndLeadSheetView.swift` `contactSection`; read in `App/PlayRuntimeGapViews.swift` `PlayContactReader`, applied in `App/PlayExperienceView.swift` | **moved**: the row left the page list and is now the 游玩工具 row right after the lead rows (label 联系主办 / 联系商家, phone glyph, no number on screen); tap asks 拨打「name」的电话？ (name, else 商家 / 主办) with 拨打 / 取消, then dials. The side effect was split out first: `PlayContactReader` (a page modifier) keeps the one read per current station and the finished-run `run-session/clear` tombstone, same conditions as before (current media snapshot) | C (tools sheet) · system `Form` row with `Label` + SF Symbol, native `.alert` confirm, `openURL(tel:)`; en + zh-Hans `playTools.contact.*` (6 keys) |

## Skipped (not actionable in this lane)

- "Pages not ported (story-flow theme, out of scope)" — story-flow stays paused.

## Gates

- 11-28 (联系主办 row): `generate_project` ok · `check_scaffold` PASS · `check_a11y_lint` PASS 0 new · `contract_ratchet --check` 52 failing, baseline 52, **new 0** · `check_design_consistency` PASS · `check_missing_string_keys` missing 0.

New strings (en + zh-Hans, also in `docs/port/strings/mp-journey-r3.json`): `playTools.contact.host|merchant|call|hostName|merchantName`, `playTools.contact.prompt %@`.
