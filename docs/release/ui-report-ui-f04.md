# UI-F04 fidelity report — mini-program `pages/club` (NOT COMPILED)

Mini-program source (`chengyin` repo, `chengyinhub-xcx/pages/club/**`) was accessible; all 32 wxml were inventoried, 5 read in full (detail, customers, settlement, join-requests, +detail sections via grep). Theme: PLAYER DARK (mini-program roots are `theme-dark`). No wave-1 branch touched these files. Presentation only; no accessibilityIdentifier or text key changed.

| mini page | screenshot | iOS file | matched | deliberately changed / not done |
|---|---|---|---|---|
| club/detail | `docs/audits/assets/ui-fix-20260829/club-after.png`, `docs/evidence/player-e2e-20260927/103-club-detail-settled.png` | App/ClubDetailView.swift | Full-bleed cover; square logo overlapping cover edge; name beside logo; icon+text meta rows (type / member count / join policy); overview 3 fact tiles (主理人 / 等级 / 所在城市, em dash for unknown, level 0 → em dash); tab order posts/events/overview/manage unchanged; CY tokens | Native segmented Picker kept (instead of underline tabs); join CTA stays in `ClubActionPanel` (not moved to header row — logic file); share/settings nav icons not added (routing) |
| club/customers | `chengyinhub-xcx/docs/screenshots/customer-figma-0830/03-club-led-customers.png` | App/ClubOpsCustomerViews.swift | Round initial avatar, name + 备注 tag, meta, sub text, chevron via NavigationLink; status tones via CY tokens | Filter chips + search live in the screen host (not edited); no right-side status column (native row) |
| club/customer-detail | none found | App/ClubOpsCustomerViews.swift | Three numeric metric tiles (到店/待核销/已退款, `dataXL` tabular), tag chips on `bgRaised` | — |
| club/settlement | none found (`docs/xcx-wechat-review-board-shots/stub-settlement.png` is a stub) | App/ClubOpsSettlementViews.swift | 已入账分润 card: caption + one large tabular amount; unverified shows 「金额待核验」 never 0; footnote token | Topic rows / funds stages / withdraw button not restyled (other files) |
| club/join-requests | `docs/audits/assets/merchant-club-20260823/07-club-join-requests.png` (not opened; merchant-light era) | App/ClubOpsJoinRequestSections.swift | Intro line, quoted message, reject-reason validation colours → CY tokens | Request card layout (avatar+approve/reject) lives in ClubManagementView — not edited |
| club/roles, governance, event-ops, notify, enroll, topic-detail, topic-story, checkin-detail, create, edit, apply, group-code | `stub-roles.png`, `danger-confirm-club-dissolve-2026-08-27.png` (not opened) | ClubOpsGovernanceSections, ClubOpsEventView, ClubOpsNotifySections, ClubEnrollmentView, ClubGovernanceViews, ClubOperationsViews | Token pass only: raw `.red/.green/.orange/.secondary` → `CYColor.dangerText/successText/warningText/textTertiary` | Layout fidelity NOT done (not read page by page; time) |
| club/components/*, badges, workbench | — | — | not reviewed | Discord-style channels: mini `club/detail` has no channel UI, so `ClubChannelMessagingView.swift` left untouched (raw `.orange/.red` remain at lines ~851–1154) |

## Files touched (11)
ClubDetailView, ClubOpsCustomerViews, ClubOpsSettlementViews, ClubOpsJoinRequestSections, ClubOpsGovernanceSections, ClubOpsEventView, ClubOpsNotifySections, ClubEnrollmentView, ClubGovernanceViews, ClubOperationsViews (+ report, strings JSON).

New string keys: 1 (`club.detail.levelFact`) in `docs/release/ui-strings-ui-f04.json`. New components: none (private views inside edited files). No previews added (not compiled; existing previews untouched).
