# UI-F03 fidelity report — NOT COMPILED

Mini-program source: accessible (repo `chengyin`, `chengyinhub-xcx/`).

## Page assignment
`pages/play/` directories (alphabetical, 8): assets, audio, circle, components, images, merchant, style, utils.
Second half (last 4): **images, merchant, style, utils**. Only `merchant` is a page; `images`, `style`, `utils` are
asset/stylesheet/helper folders with no WXML (no screen to match). `circle` (retired redirect shell, page-map: dropped)
and `components` belong to UI-F02.

## Page -> screenshot -> matched / deliberately changed

### pages/play/merchant/index -> `App/PlayStoreDayMerchantView.swift` (page-map: gated, PlayStoreDay)
Screenshot: `chengyinhub-xcx/docs/audit-e2e-202609/shots/play-merchant-index.png` (shows only the not-found state;
no screenshot of the loaded page exists — loaded layout taken from .wxml/.wxss).

Matched:
- Section order: hero -> head (status tag, name, 营业/现场 meta) -> 现场记录 3-step proof -> 现场参考 3 stats -> feedback
  -> 当前门店授权 -> 商家信息 address card -> docked CTA bar (address ghost + one primary).
- Hero full-bleed with large bottom corner radius, vignette gradient, pin placeholder (was inset 180pt rounded box).
- Eyebrow tag as letter-spaced micro capsule; name as page title; meta as tracked key + primary value, baseline aligned.
- Proof steps as bordered surface cards (numbered/check badge, title + caption); done = primary ink, pending = tertiary.
- Stats as three equal surface cards, tabular numerals (`CYTypography.dataXL`) + micro caption.
- Consent as card with scope text and underlined revoke link (44pt target); revoke keeps its confirmation dialog.
- Address as card (pin, address, open text, navigate control).
- Status line above CTA: colour only on the dot (warning token for UNKNOWN), text secondary.
- Game/task sheets: eyebrow header, question, option rows with selected state, single pill primary action,
  "later" as quiet tertiary text; dark elevated sheet background, drag indicator, detents unchanged.
- Page background `CYColor.bgPage`; all colours/fonts/spacing from CY tokens (no raw colours/fonts left in the file).

Deliberately changed:
- Native nav bar/back replaces the WeChat floating back button over the hero; sheets are system sheets with detents.
- Bottom CTA bar uses `.bar` material instead of the page-colour gradient.
- Primary CTA uses `.cyPrimary` (accent) instead of the mini-program's white pill.
- Stats keep the em dash for unknown values (mini-program renders 0) — UNKNOWN rule.
- Options sheet keeps `Form` (Apple-native) rather than custom bordered option cards; selection shown by checkmark + ink.
- Not-found state keeps `ContentUnavailableView` + refresh; mini-program's "回上一页重新进一次" hint/返回 button not added
  (would need new strings; native back exists).

## Not done
- `#Preview`: `PlayStoreDayCoordinator` needs service dependencies; no safe synthetic fixture without compiling. Cursor to add.
- Not compiled/run; verify `UnevenRoundedRectangle` (iOS 17, same floor as `@Bindable`) and `presentationBackground`.

New string keys: 0 (no `ui-strings-ui-f03.json`). New components: 0.
Files touched: `App/PlayStoreDayMerchantView.swift`, `docs/release/ui-report-ui-f03.md`.
