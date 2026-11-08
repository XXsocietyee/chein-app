# UI-F05 report: merchant console fidelity (LIGHT theme)

**NOT COMPILED.** Presentation only. Mini-program source (`chengyin/chengyinhub-xcx/pages/merchant/**`) was accessible and read.
Screenshots: the repo has **no screenshots of merchant pages**. Closest: `docs/xcx-wechat-review-board-shots/shell-workbench.png` (actually the club-invite tab with an error state, not the workbench) and `shell-merchant-profile.png` (invalid-link state of the public merchant home). Neither shows a merchant console page, so layout was taken from WXML/WXSS only. `artifacts/merchant-ai-npc/*.png` covers `decor/ai-npc` only (not edited, gated).
New string keys: **0** (no `ui-strings-ui-f05.json` needed). New component files: **0**.

## Scope rule
Files already changed by `cloud/ui-07/08/11/12/13/14` (e.g. `MerchantHomeView`, `MerchantBusinessViews`, `MerchantCustomerListParityViews`, `MerchantGameNodeView`, `MerchantCoopCenterView`, `MerchantPerkTemplatesView`, `MerchantReviewSummaryHeader`, `MerchantOnboardingView`, `MerchantPredictionInboxView`, `MerchantStoreCharacterView`, `MerchantCityNode*View`) were NOT edited here, to avoid merge conflicts. Their mini pages (index/index, apply, reviews, customer list, game-node, coop-center, predict, citynode, citynode/create, decor/perks, decor/ai-npc, team list host, ledger/aftercare hosts) are owned by those agents.

## Page -> screenshot -> matched / deliberately changed
| mini page (pages/merchant/…) | screenshot | iOS file(s) edited | matched | deliberately changed |
|---|---|---|---|---|
| ledger/index (`.fin-row`, `.fin-summary`) | none | `MerchantLedgerParityViews.swift` (RowLabel, SummaryStrip) | leading status dot, title / "who · time" / state chip, right-aligned tabular amount, 3-cell summary (本月核销 / 待结算 / 已入账) with warning/success tones, 44pt min row | CY tokens; native List supplies the card/grouping |
| ledger/order-detail, ledger/batch-detail (`.fin-hero`) | none | `MerchantLedgerParityViews.swift` (RedemptionHero, BatchHero, BatchStatementCard) | one hero number (data2XL, tabular), muted label above, state line | missing amount stays the existing "pending" label (not 0) |
| ledger/batch-detail (progress) | none | `MerchantSettlementProgressView.swift` | tokens for step/secondary text, card titles | token-only |
| marketing/index | none | `MerchantMarketingHomeSections.swift` | section order hero → tools → 我的内容 → 优惠券 → 合作机会; hero left-aligned (label, big number, sub); 我的内容 as 3-up number tiles; coupon deck as tinted card; empty-state CTA primary | **hero value is an em dash when analytics / SIGNUP stage is missing** (mini shows 0 per its 2026-09-19 note; task rule overrides). Core `heroValue` still returns "0": the view substitutes. Mini coupon "ghost stack" and cooperation image banner not reproduced (no asset in app; kept native row) |
| marketing/index, ai-insight | none | `MerchantMarketingView.swift` | token-only (secondary text, danger red) | token-only |
| aftercare/index | none | `MerchantAftercareParityViews.swift` | day header + total, row: title, time · status · takeover, activity line, right amount ("amount pending" muted) | tokens; kept Dynamic-Type stacked layout |
| customer/detail | none | `MerchantCustomerDetailSections.swift` | name first, 累计实付 as one large number (dataXL; unknown/denied stay text, never 0), then 概览, 参与记录, 标签与备注, 跟进与触达 order | mini's 3 metric tiles and date-chip participation rows NOT rebuilt: fields come from generic `MerchantBusinessField`; left as native Form rows |
| team/index | none | `MerchantOperatorRosterSections.swift` | section order 当前身份 → 成员 → 邀请 → 历史 | token-only |
| decor/index, decor/coop-setting, decor/gallery | none | `MerchantOperationsViews.swift` | already native Form sections matching mini card groups | token-only (secondary text, headline) |
| marketing → aftercare/detail | none | `MerchantAftercareProgressView.swift` | hero amount (unknown amount text, never 0) | token-only |

## Mini pages not touched (and why)
index/index, apply, reviews, customer (list), game-node, coop-center, predict, citynode(+create), decor/perks, decor/ai-npc, relation, profile (public home: `PublicMerchantHomeView`, owned by UI-24), components/cy/* (WeChat-only widgets): owned by other agents' branches, gated, or no iOS equivalent.

## Not done
- No `#Preview` added: these views take Core presentation structs (`MerchantLedgerParity.*`, `MerchantMarketingHome`) whose initialisers I can't verify without compiling.
- Light scheme is forced by the role root (UI-01), no per-view scheme added.

Files touched (9): MerchantLedgerParityViews, MerchantMarketingHomeSections, MerchantMarketingView, MerchantAftercareParityViews, MerchantAftercareProgressView, MerchantCustomerDetailSections, MerchantOperatorRosterSections, MerchantOperationsViews, MerchantSettlementProgressView.
