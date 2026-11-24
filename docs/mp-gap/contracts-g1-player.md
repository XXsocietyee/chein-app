# Contract Alignment — `gap/g1-player` vs `origin/ui/combined-r7`
- **App source:** `origin/ui/combined-r7:Core/` + `Core/MPGap/`
- **MP source:** `hengyin/chengyinhub-xcx` (`player-content`, `play-roam`, `member`)

## player-content

| MP file:line | MP call | app file:line | difference | fix |
|---|---|---|---|---|
| `pages/topic/merchantinfo/host-layers.js:313` | `POST /api/topic/recruit-slot-qrcode` | *(missing)* | Endpoint not wired in Core | Wire `POST /api/topic/recruit-slot-qrcode` in Core (respecting owner/money gates) |
| `pages/topic/merchantinfo/merchantinfo.js:948` | `POST/GET /api/coop/offer/quota` | *(missing)* | Endpoint not wired in Core | Wire `POST/GET /api/coop/offer/quota` in Core (respecting owner/money gates) |
| `pages/topic/merchantinfo/merchantinfo.js:961` | `POST/GET /api/coop/offer/sale-pause` | *(missing)* | Endpoint not wired in Core | Wire `POST/GET /api/coop/offer/sale-pause` in Core (respecting owner/money gates) |
| `pages/topic/merchantinfo/merchantinfo.js:1572` | `GET /api/coop/offer/display-terms` | *(missing)* | Endpoint not wired in Core | Wire `GET /api/coop/offer/display-terms` in Core (respecting owner/money gates) |
| `pages/topic/merchantinfo/merchantinfo.js:1751` | `POST /api/merchant/chapter-application/offer/remove` | *(missing)* | Endpoint not wired in Core | Wire `POST /api/merchant/chapter-application/offer/remove` in Core (respecting owner/money gates) |
| `pages/topic/utils/wx-phone-bind.js:28` | `POST /api/getwxbindphone` | *(missing)* | Endpoint not wired in Core | Wire `POST /api/getwxbindphone` in Core (respecting owner/money gates) |
| `pages/topic/components/cy/chapter-node-form/index.js:395` | `GET /api/fe/reference-settlement/note` | *(missing)* | Endpoint not wired in Core | Wire `GET /api/fe/reference-settlement/note` in Core (respecting owner/money gates) |
| `pages/topic/index/index.js:749` | `GET /api/team/nearby` | `Core/NearbyTeamService.swift:24` | HTTP method differs (MP `GET` vs app `POST`) | Align HTTP method to `GET` |
| `subpackageB/pages/im/chat/audit-detail.js:16` | `POST/GET /api/audit/` | *(missing)* | Endpoint not wired in Core | Wire `POST/GET /api/audit/` in Core (respecting owner/money gates) |

_Unique endpoints checked in player-content: 174; mismatches/missing: 9_

## play-roam

| MP file:line | MP call | app file:line | difference | fix |
|---|---|---|---|---|
| `pages/play/index.js:9357` | `POST /api/play/my-completed` | `Core/PlayerJourneyService.swift:30` | HTTP method differs (MP `POST` vs app `GET`) | Align HTTP method to `POST` |
| `pages/play/utils/cast-play.js:393` | `POST/GET /api/play/run/profile` | *(missing)* | Endpoint not wired in Core | Wire `POST/GET /api/play/run/profile` in Core (respecting owner/money gates) |
| `pages/play/utils/cast-play.js:483` | `POST/GET /api/topic/cast/voice` | *(missing)* | Endpoint not wired in Core | Wire `POST/GET /api/topic/cast/voice` in Core (respecting owner/money gates) |
| `pages/play/utils/cast-play.js:540` | `POST/GET /api/play/run/branch` | *(missing)* | Endpoint not wired in Core | Wire `POST/GET /api/play/run/branch` in Core (respecting owner/money gates) |

_Unique endpoints checked in play-roam: 167; mismatches/missing: 4_

## member

| MP file:line | MP call | app file:line | difference | fix |
|---|---|---|---|---|
| `subpackageMember/orient-score/index.js:6` | `POST/GET /api/orient/scoring` | *(missing)* | Endpoint not wired in Core | Wire `POST/GET /api/orient/scoring` in Core (respecting owner/money gates) |

_Unique endpoints checked in member: 135; mismatches/missing: 1_

