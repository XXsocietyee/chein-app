# mp-states-b r3 receipt (B lane of mp-states)

B lane per brief `round3-1127.md` § "B lanes": works `docs/release/receipts/mp-states-r3.md` open rows bottom-up and records
progress only here. The A receipt never gets edited by this lane.

## Run 11-28 (first B run)

A receipt open rows at start (`origin/mp/r3-states` 0eb446a17): only **"Not done · P1-9 remote push"**, still blocked on
the backend (no device-token route / APNs sender on `us/r3-functional`; `cb13-route-matrix.md` lists only
`/api/native/device/*` enrollment and `/api/im/device/attempts`, neither a push-token upload). Not taken. With no other open
row, this lane re-scanned the area for player screens with no A-receipt row (brief: "pick the next page in your area that has
no row in your receipt yet").

| A-receipt row / screen | MP state | Before | After (level) |
|---|---|---|---|
| (new, no A row) 俱乐部 · 编辑资料 · 资料概况 facts section (`ClubEditFactsSection`, `App/ClubTabParityViews.swift`, inside 俱乐部详情 管理 · 编辑资料) — code read, no sweep fixture | `pages/club/components/cy/scene-club-edit/index.wxml:3` cy-skeleton 正在读取俱乐部资料; `:6` cy-error load-failure 编辑资料没能打开 · 重新加载 (members / 保留名额 come from the same club read in the MP) | bare `ProgressView()` with no words; a failed read = a bare 加载失败 line with no way to retry except leaving the page | labelled `ProgressView { 正在读取俱乐部资料 }` (Loading club details…); failure = warning `Label` 编辑资料没能打开 (Couldn’t open the club details) + `.bordered` 重新加载 (Reload) that re-runs the facts read — the same keys as the page-level state (A row "俱乐部 · 编辑资料 load states"). Identifiers `club.ops.facts.loading` / `.error` kept, new `club.ops.facts.reload`. Level C |
| (new, no A row) 发布 · 发布人登记 status (`PublishingIdentityStatusView`, `App/PublishingManagementViews.swift`, pushed from 发布 · 发布方式) — code read, no sweep fixture | MP has no standalone page: the status read (`/api/publisher/identity/status`) runs inside `pages/publish/fabu`; the MP global pattern for a failed read is cy-error load-failure + 重试 | bare `ProgressView()` with no words; a failed read = the bare sentence 列表没加载出来 (“Couldn’t load the list”) — wrong object, no retry | labelled `ProgressView { 正在读取登记状态… }` (Checking your registration…); failure = one `ContentUnavailableView` 登记状态没能读取 (Couldn’t check your registration) · 检查网络后再试一次 · `.bordered` 重试 that re-runs the read (`reloadToken` in the `.task` id). New keys `publishModes.identityLoading` / `.identityReadFailed` (en + zh-Hans). The five states pinned by `test_identity_unknown_is_not_authoritative_false` are unchanged. Level C |

## Not done

| Row | Why |
|---|---|
| P1-9 remote push (A "Not done") | blocked on the backend device-token route + APNs sender; unchanged |

## Gates

Before each push, on the branch head: `python3 tools/generate_project.py` (no project diff), `python3 tools/check_scaffold.py`
PASS, `python3 -B tools/check_a11y_lint.py` (0 new), `python3 -B tools/contract_ratchet.py --check` (52 failing = baseline 52,
new 0), `python3 tools/check_design_consistency.py` PASS. No Swift compiler here: the edit mirrors the existing
`ProgressView { Text(…) }` / `Label { } icon: { }` / `.buttonStyle(.bordered)` patterns.
