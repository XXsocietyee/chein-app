# CB261 PAGE-READY · pages/coop/invite/index

- Feature: 发起协作邀请与批量邀约
- Native: `App/CooperationContextualViews.swift`
- Map status: exists

The invite form, batch drafts (`CoopFlowBatchInvite`), and the live reads `api/topic/list`, `api/merchant/clubs`, and `api/club/merchants` were already on `rc/20261108`. This change adds the page model those reads did not have.

- Model: `CoopInviteIndexReadiness` in `Core/CooperationContextual.swift`. Phases are loading, empty, error, and unknown. Unknown counts display as — and a literal 0 stays 0. An unknown directory is not reported as 0. Invite send, share, and a locked preset target stay hidden. `showsMerchantChoice`, `paymentEnabled`, `payoutEnabled`, `withdrawalEnabled`, and `virtualGoodsEnabled` stay false. `/api/coop/invite` is not marked live.
- Tests: `Tests/CoreTests/CoopInviteIndexReadinessTests.swift` and `Tests/ContractChecks/test_coop_invite_index_page_ready.py`. Existing `CoopBatchInviteTests` are unchanged.
- Views, ui-strings JSON, the catalog, the project, and the ledger were not edited.

## Missing keys

These keys are not on this page's read contract. The model does not invent them, and the capability stays hidden.

- `toId` — preset target deep link. It stays on the received-application reply, not this page.
- `originApplyId` — locked reply from a received application. Same as `toId`.
- `merchantName` — not a substitute for `name`. A row without `name` does not become a target.
- `share` — no share payload. No share surface is added.
- `coopInvited` — WeChat subscribe alert. No native subscribe surface is added.
- `originalRequest` — unknown-result query of the original invite. Not on this read.
- `countdown` — expiry countdown. Not on this form.

Left: `App/CooperationContextualViews.swift` still owns `CoopInvitationReadModel` and does not call `CoopInviteIndexReadiness`. A missing club `memberCount` there still uses `cooperation.invite.membersUnknown`. `CoopFlowTargetCandidate` still parses a non-canonical numeric string such as `00` as 0; the page model renders that same string as —. No Xcode build was run.
