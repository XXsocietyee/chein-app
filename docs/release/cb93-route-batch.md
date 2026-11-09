# CB93 route batch

Base `origin/rc/20261108`. The China host gate is unchanged: `https://www.chengyinhub.com/prod-api/` with realm `cn-prod`, and only when the market is China and the bundle plus realm form a storage scope. An empty API URL or an empty realm still returns `makeComposition(reviewed: nil)`. No US API URL was added. Password login, bank-card withdrawal, and virtual goods stay off. Nothing was deployed. `docs/release/cb13-route-matrix.md` and the call-site mark table were not republished. `tools/current_ci_manifest.json` and `ios-ci.yml` were not edited. No test was deleted. This VM has no Swift toolchain, so the new tests were not run.

The missing literals stay marked missing. The client calls the production path only when `ChinaReviewedRouteCapability.admitsChinaProductionCall` is already true for that path.

## Adapted

| Missing iOS literal | Production path the client calls | Where |
| --- | --- | --- |
| `/api/topic/detail` | `POST /api/topic/info-to-user` | China transport, form body `id` only |
| `/api/club/settlements` | `POST /api/club/settlement/summary` | China transport, JSON `{"clubId"}` only. The withdraw route is not used |
| `/api/club/update` | `POST /api/club/update-mine` | China transport, club profile JSON with `id` and no extra keys |
| `/api/join-request/submit` | `POST /api/club/join` | Club kind only (`guild` kind 1), no invite id |
| `/api/space/leave` | `POST /api/club/quit` | Club kind only. `未加入` is not reported as a successful leave |

Other hosts keep the missing literals. A body that is not the production contract is refused with `APIError.notConfigured` and is not sent.

## Left missing

The other missing call sites stay hidden. That includes password login (`/api/login`), bank withdrawal (`/api/withdrawal/create`, `/api/fund/preflight/**`, `/api/asset/withdraw`, `/api/club/settlement/withdraw`, `/api/wallet/withdraw`), and virtual goods (`/api/cart/**`, `/api/product/info`, `/api/product/list`, `/api/registration/pay`, `/api/registration/pay/app`, `/api/pay/create`).

Also left missing, because the production route does not carry the same contract:

- `/api/join-request/approve`, `/api/join-request/reject`, and `/api/join-request/cancel`. Review needs a club id and a member id, not an application id, and cancel has no production route.
- `/api/space/leave` for a non-club guild kind.
- `/api/user/sms/send`. The live SMS route already exists for phone login. The deny-list literal was not turned into a second sender.
- `/api/ugc/block`. Production blocks direct chat only. It was not claimed as a content block.
- `/api/growth/leaderboard/anonymous`. The live board is identity-bearing, and the anonymous decoder rejects that payload.
- City-game, workshop, friend, channel, reward-pledge, and the rest of the 385. No production controller matches them.
