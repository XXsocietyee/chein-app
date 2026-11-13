# cur-be-gap-play

Handover 23, with the 2026-11-13 owner correction. Each listed path has a backend that already served it or a new native handler, and a visible app surface.

- `merchantWrites` and `moneyPayments` are true only for a DEBUG build, or a TEST build with `QUESTIFY_TEST_AREA_SWITCHES=1`, when the host is not `www.chengyinhub.com`. Production stays false. The merchant confirm button and the product list stay on screen. A closed switch does not send the write and does not report success.
- Marketing cash checkout is not added. Digital goods stay on StoreKit. A points order is sent only when `moneyPayments` is open and the quote offers points. `/api/marketing/product/pay` is not called.
- City action outcomes show the server `diceFace`. A face outside 1...6 is the number. A missing face is an em dash.
- Native device enrollment reports `hardwareVerified: false`. Private-home and home-return decisions come from the server. NPC chat delete removes only the caller's rows.
- Password login is unchanged. SMS send is `/api/sms/send` and is not a password grant.
- Contract baseline stays `missingCount` 375 and `wiredPatternCount` 677.

Backend branch `feature/be-gap-play-misc`. App branch `ui/cur-be-gap-play`.
