- identityConsent: true must be sent with realName/idCardNumber on merchant submit (consent checkbox in UI). Build in the post-design code round.
## Next pass for worker B (start only AFTER worker A, City, finishes: one builder at a time)
- Everything "left" or "partial" in docs/release/receipts/ui-h-code-app.md.
- Coordinator review of B's screenshots (2026-11-18):
  - Topic detail (06): an empty hero shows 图片暂不可用 text on black. Use a designed cover placeholder (category gradient plus an SF Symbol) at the hero height. 路线总站点 0: hide the row when the route has no stations. The 详情/故事/路线 segmented bar is drawn as a dark box inside a rounded box: one container only, pinned. The hairline dividers have inconsistent insets.
  - Merchant identity (01c): the status bar is still WHITE on the light page; fix the status bar scheme for pushed light pages. 上一步 sits alone inside a white card: make it the secondary button beside 下一步 in the one bottom bar.
## City Monopoly follow-ups (coordinator review of code-final-shots/city, 2026-11-19)
- Deed with no photo shows a map glyph in a dashed box: replace it with the xrefs no-photo cover (district colour 24%, place name, camera glyph inviting the first claim photo).
- Roam root pins overlap near 越秀 (a flag over a flag over a plus): cluster or offset the pins (MapKit clustering).
- 附近 · 3 shows no rows under the hold button at the medium detent: show the first row peeking.
- District names show as 街区 1: the backend lacks district names (endpoint gap), so track it with the backend.
- Backend gaps from the receipt: task verifier (N35), defender/rent push, deed serial, district names, and a 500 on the claim quote for board points without place_id.
- City app: wire districtName/districts[] and deedSerial from the backend (fix/city-gaps-r3 is live on TEST) into the hooks C1 left; show the 'DEFENDED' inbox card. Backend note: a district's first-claim race may deadlock (it rolls back; add a retry).
