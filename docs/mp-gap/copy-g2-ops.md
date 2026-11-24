# Copy Alignment — G2 ops (`club`, `merchant-coop`, `account-publish`)

- **MP Source:** `liboyang42-cpu/hengyin` (`chengyinhub-xcx`)
- **App Base:** `origin/ui/combined-r7` (`Resources/Localizable.xcstrings` + area `.xcstrings`)
- **Sweep Totals:**
  - `club`: 632 unique Chinese UI strings extracted → 378 not exact-matched in `Localizable.xcstrings` (297 not in any `.xcstrings`; 11 near-mismatches)
  - `merchant-coop`: 855 unique Chinese UI strings extracted → 573 not exact-matched in `Localizable.xcstrings` (443 not in any `.xcstrings`; 5 near-mismatches)
  - `account-publish`: 1384 unique Chinese UI strings extracted → 1057 not exact-matched in `Localizable.xcstrings` (1001 not in any `.xcstrings`; 3 near-mismatches)

---

## 1. Mismatches in `MPGap` files (fixed in this branch)

| MP file:line | MP text | app key | app text | fix |
|---|---|---|---|---|
| `pages/merchant/marketing/ai-insight/index.wxml:252-272` | `经营优化` / `去合作中心` | `gap.merchant.aiInsight.grow` | `经营优化` | Align grow-tip card titles/subtitles with `pages/merchant/utils/grow-tips.js` |
| `pages/club/detail/index.js:1968` | `暂时读不到你的游玩记录` | `ClubPostRefCopy.loadFailed` | `暂时读不到你的游玩记录` | Verified exact match; add `"网络异常，获取失败你的游玩记录"` fallback |
| `pages/club/detail/index.wxml:580` | `申请带队` / `查看申请` / `提交中…` | `gap.club.coopPool.*` | `申请带队` / `查看申请` / `提交中…` | Verified exact match |
| `pages/merchant/apply/index.wxml:25-30` | `把你的店放进玩家的路线里` / `门店已在城瘾上线？认领已有门店` | `MerchantRemainingGapCopy.*` | `把你的店放进玩家的路线里` / `门店已在城瘾上线？认领已有门店` | Verified exact match |
| `pages/team/join/index.wxml:24-31` | `加入码` / `粘贴队长给的加入码` | `gap.team.joinCode` | `加入码` | Verified exact match |

---

## 2. Mismatches in existing `Localizable.xcstrings` on `origin/ui/combined-r7` (for coordinator)

### Club
| MP file:line | MP text | app key | app text | fix |
|---|---|---|---|---|
| `pages/club/apply/index.wxml:146` | `持导游 / 旅游资质` | `club.gov.field.hasGuideCert` | `持导游/旅游资质` | Add spaces around `/` in `Localizable.xcstrings` |
| `pages/club/components/cy/scene-club-edit/index.wxml:64` | `俱乐部风格，选填` | `context.ai.style` | `俱乐部风格（选填）` | Use `，选填` to match MP |
| `pages/club/create/index.wxml:115` | `一句话介绍，选填` | `club.ops.createDescription` | `一句话介绍（选填）` | Use `，选填` to match MP |
| `pages/club/create/index.wxml:128` | `核心关键词，选填` | `club.ops.keywords` | `核心关键词（选填）` | Use `，选填` to match MP |
| `pages/club/detail/index.js:821` | `你还没有俱乐部` | `cooperation.pool.clubHint` | `你还没有俱乐部。` | Drop trailing period to match MP toast |
| `pages/club/detail/index.js:2764` | `这个项目还没有可举报的具体活动` | `club.activityReport.empty` | `这个项目还没有可举报的具体活动。` | Drop trailing period to match MP toast |
| `pages/club/detail/index.wxml:147` | `写评论…` | `club.community.commentContent` | `写评论` | Add trailing ellipsis `…` |
| `pages/club/detail/index.wxml:939` | `生成中…` | `merchant.engagement.status.RUNNING` | `生成中` | Add trailing ellipsis `…` |

### Merchant-Coop
| MP file:line | MP text | app key | app text | fix |
|---|---|---|---|---|
| `pages/coop/invite/index.wxml:56` | `引流合作，不产生现金结算` | `cooperation.invite.terms.traffic` | `引流合作（不产生现金结算）` | Use `，不产生现金结算` |
| `pages/merchant/aftercare/index.wxml:72` | `正在加载更多…` | `templateOwnShelf.read.loadingMore` | `正在加载更多` | Add trailing `…` |
| `pages/merchant/apply/index.wxml:129` | `11位手机号` | `auth.channels.phone` | `11 位手机号` | Remove space between `11` and `位` |
| `pages/merchant/marketing/ai-insight/index.wxml:47` | `近30天` | `roam.export.range.30` | `近 30 天` | Remove spaces around `30` (`近30天`) |
| `pages/merchant/marketing/index.wxml:26` | `正在更新营销数据` | `merchant.marketing.refreshing` | `正在更新营销数据…` | Drop trailing `…` on marketing refresh |

### Account-Publish
| MP file:line | MP text | app key | app text | fix |
|---|---|---|---|---|
| `pages/gerenziliao/gerenziliao.wxml:153` | `请输入昵称` | `profile.edit.nameRequired` | `请输入昵称。` | Drop trailing period |
| `pages/publish/fabu/theme-route-names.js:92` | `没有保存成功，请再试一次` | `parityB.alt.saveFailed` | `没有保存成功，请再试一次。` | Drop trailing period |
| `pages/publish/temp/index.wxml:1373` | `揭示第几个字(不填为第 1 个)` | `templateHint.letter.placeholder` | `揭示第几个字（不填为第 1 个）` | Match half-width parens if strict, or keep full-width |

---

## 3. Missing strings in `Localizable.xcstrings` (for coordinator / `gap-g2-ops.json` merge)

All new gap strings for translated features are staged in `docs/port/strings/gap-g2-ops.json` (32+ keys covering `可对接的活动`, `准备总览`, `自由探索结算（参考）`, `店铺参谋`, `客源主题`, `经营优化`, `核销据点`, `选择补位操作`, `有什么新鲜好玩的分享吗？`, `发起合作`, `可直接开局的模板`, `入队申请`, `加入码`, `去买这一场的票`, etc.).
Additional MP-only strings from non-translated / owner-gated / remaining screens are summarized in `docs/mp-gap/{club,merchant-coop,account-publish}.md` (total 297 club, 443 merchant-coop, 1001 account-publish strings not yet in `Resources/*.xcstrings`, largely from unmounted/gated sheets and inline template hints).
