# Integration batch 4 (2026-11-13)

Integrator branch `integ/next`, pushed to `ui/next` and `ui/main` (fast-forward only).

## First item: batch-3 KNOWN-FAILs (cleared, pushed as `34f866715`)

- (a) `POST api/club/detail`: `ClubPublicRosterRoute` claimed it before the E2E F4 player read and needs a roster approval the
  shipped China composition never issues. The roster branch is skipped when China production gates and player writes are on
  and `ReviewedPlayerReadRoute` accepts the request.
- (b) `api/im/send`: test fixture only. The tests built the request with cookie handling on; `NativeChannelTextRoute` requires
  it off, as the production `NativeChannelTextService` sends it. Product path unaffected.
- Behind (b): `GET api/orient/scoring/receipt` (orient-appeal) was refused by the composition query gate. It is now admitted
  there; the reviewed lease still checks shape and grant.

## Merged

| Branch | Head |
| --- | --- |
| `ui/cloud-ch-fixes` | `689134de7` |
| `ui/cloud-h7-claude` | `74fe013d7` |
| `ui/cloud-g-editor` | `aafba56c9` |
| `ui/cloud-h2-claude` | `56a8e9b0d` |

## Integrator changes

- Conflict unions: player-write lease (template adoption, admission, team pool, creator editor), China capability
  (CITY, channels social, creator editor, topic state keys), composition query gate. Line ratchets stay at 8171 / 4184.
- Journey leaderboard: h7's decoders plus ch-fixes' in-team (队内) tab and `scope=team` read; the settle preset stays quest-only.
- `POST api/play/feedback/submit` granted (lease `playPaths` and the China player-journey grant).
- CITY bounded reads accept OPEN and FROZEN (`servesBoundedReads`); the NPC route egg stays unreachable (asserted).
- **Project editor for China players.** Decision: owner approval 2026-11-12, all non-money player writes. The shipped business
  configuration grants `projectRead`, `projectWrite`, `projectPublicationRead`. Routes the production host does not serve
  (`edit-requests/*`, `publish-status`) are granted only against a non-production host such as TEST 8120, so production hides
  them; the editor's publication-status section hides instead of saying "unavailable". Merchant-scoped edits
  (`scope: "MERCHANT"`) are refused for non-merchant roles. Pricing, paid listing, sales, revenue, platform-pass and merchant
  routes are not in these features.
- Publication reads (`publish-check`, `publish-status`) carry a query and were refused by the composition query gate; now admitted
  through `ProjectExactReadRoute`.
- IM video duration shown only when the server sends it (now optional).
- Catalogued the G3 creator-tools publish request id.
- Test counts: `CB93RouteAdaptationTests` follows h2's route marks (997 / 375); the CITY lifecycle test follows OPEN reads.
