# CB85 — pre-merge parity audit

Base: `origin/rc/20261108` `8cac4681a592621c663c231991bda4f2c660fa21` (2026-11-09 03:01 AM PT).
Branch: `cursor/cb85`. This pass is the pre-merge audit only.

The post-merge audit is waiting. The UI merge queue is not in this RC. `docs/release/ui-tier3-batches.md` names `origin/cursor/theme` `cfd65e7fddcece2dc3b7e40b2cc708934188a562`, `origin/cursor/ui-list` `0765d3053ea2d29d5afa52d72ed8c0fff547f0d6`, `origin/cursor/ui-detail` `3c8016846bdbde0533e861e563bc9d18bfd2239e`, `origin/cursor/ui-form` `2b957c7348d0c3b528d2d6a2f2635957c51759af`, `origin/cursor/ui-settings` `c4109d858e6e99340fdfca20a7c9af13e3fdbee3`, `origin/cursor/ui-chat` `e3a173ac96b2319d8956ab30d780922f8563c35c`, and `origin/cursor/ui-empty` `6284f2ce7aa6403f7e665acb6048e16d01096c12`. None of those objects is in this RC. Those branches were not read. No `docs/parity/page-map.csv` row was marked changed because an unmerged cursor branch exists. No view was edited. `docs/parity/page-map.csv` was not edited.

Version stays **0.1.0 (1)**. `Config/Base.xcconfig` has `MARKETING_VERSION = 0.1.0` and `CURRENT_PROJECT_VERSION = 1`. This commit does not change those lines.

This RC already contains the `origin/ui/d2`, `origin/ui/d3`, and `origin/ui/d4` merges (`3c312f5d9fe7ccbe8e22235c7a9fea336f20d6ec`, `c1261a40451eab0a8b1cc2eb4f431c90897f83de`, `8be6ba6c44b60052afb6d35734f9f176a0288a5a`). Those commits are not the UI merge queue.

## What was read

`docs/parity/page-map.csv` on this RC: 163 data rows, one header, six columns on every row, no duplicate `mini_path`. Each `target_native_screen` path exists. Each `merged-into:` target names a row in this file. The 17 `CB14:` notes already in that file were compared with the status column. `docs/parity/gap-wave-audit.md`, `docs/release/ui-tiers.md`, and `docs/release/cb70-gap-register.md` were read as files already in this RC.

Nothing was compiled or run. Pass counts that notes attribute to `/private/tmp/*.log` are not files in this RC, so they are not new evidence.

## Census (unchanged by this pass)

| status | rows |
|---|---:|
| exists | 97 |
| gated | 14 |
| partial | 37 |
| merged-into | 14 |
| dropped | 1 |
| total | 163 |

## Status corrections

None. This pass does not change a status.

The only status-column change between `89dcba807e7e5439182ff8852d6600d1fa9fdd49` and this RC is already merged. `pages/play/poi-challenge/index` is `partial`. At `67053ccb33c0e1ad35a7508f8546ae9076fd82e5` it was `exists`. CB14 (`70bde9230af9d13874717d85ac93a8ea63ab8716`, pull request #606) set it to `partial`. Source on this RC matches that status:

- `App/ChallengePOIWriterFactory.swift` sets `makeWriter` to `GatedChallengePOIWriter()`.
- `Core/ChallengePOISubmission.swift` `GatedChallengePOIWriter.complete` returns `.unavailable`.
- `Tests/CoreTests/ChallengePOISubmissionTests.swift` `testSuccessUsesMiniRequestShapeAndShowsDoneOnlyAfterServerAnswer` uses `FakeWriter`, not that factory.

`docs/release/ui-tiers.md` still prints `exists` for that row. The file says it copied the map at `67053ccb33c0e1ad35a7508f8546ae9076fd82e5`, where the status was `exists`. It is a labeled snapshot. It was not edited here.

The other 16 `CB14:` notes do not ask for a different status. Those rows are already `partial` or `gated`. `pages/roam/index` stays `exists`; its CB14 sentence says presence sharing stays off.

`docs/release/cb70-gap-register.md` says the CB14 sentences are not in this RC's page map. They are: `docs/parity/page-map.csv` on `8cac4681a592621c663c231991bda4f2c660fa21` has 17 notes that contain `CB14:`. That sentence in CB70 is stale. It is not a page-map status, and this pass does not edit that file.
