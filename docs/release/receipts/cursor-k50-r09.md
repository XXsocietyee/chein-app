# cursor-k50-r09

Branch `cursor/1128-k50-r09` from `origin/ui/combined-r7` (`b954de71cd6669256c49785864504f8e05ba05d9`), then merged `origin/ui/combined-r7` at `5375df502` before push. No force-push, no `main`, no deploy, no secrets, no SQL, no `xcodebuild`. This machine has no `swiftc`.

ATS is unchanged: `Config/Info.plist` has no `NSAppTransportSecurity`, and no xcconfig sets `NSAllowsArbitraryLoads` or `NSExceptionDomains`. `DeepLinkSafetyAudit.verifiedHTTPSHosts` stays empty. `PlayerLaunch.merchantCenterEnabled` stays `false` in Release. Money writes, auth bypasses, and `App/AppSession.swift` were not edited (7976 lines, ceiling 7977). `ReviewedPlayerWriteLeases` still passes devices, then sensors, then artworkHosts. No `String(localized:)` was added. Search-history Keychain (`AfterFirstUnlock`) was left as pinned.

## Fixes

1. **Badge image URL.** `ObjectBadgeDetailParameters` keeps `img` only when `ObjectCardMediaPolicy.origin` accepts it (https, no user or password, no fragment, no localhost, `.local`, or IP). `http` and `javascript:` become an empty image. The loader still uses that policy.

2. **Pass and campaign ids.** `MPParityRoute.safeIdentifier` rejects `.`, `..`, and any value containing `..`. A route can no longer open for `id=..`.

3. **Journey landing query.** `JourneyLandingLink` accepts `t` only inside the custom-scheme token bounds, and rejects `.`, `..`, a `..` substring, `\`, and `%2e` / `%2f` / `%5c` / `%00`. Present `aid` and `tid` must be positive canonical decimals. `t=tok` and `t=invite-token` still parse. A decoded `%2F` (`a/b`) still parses, matching `CheinDeepLinkTests`.

4. **Custom-scheme token.** `CheinDeepLink.plainToken` rejects `.`, `..`, and `\`. `chein://referral/a%2Fb` still decodes to `a/b`.

5. **Session, photo, and avatar query.** `subpackageRoam/session` `sessionId` must be a canonical positive id. `shareToken` rejects a path or a URL; `shareToken=tok` still opens `RoamSharedFootprintView` (the view already fail-closes a non-32-hex token before any request). A `photo` or `avatar` value that contains `:` and fails the https origin check is dropped from the query. The page still opens.

6. **Seat-claim path segment.** `JourneyLoopSource.pathToken` rejects `.`, `..`, `/`, `\`, and `%` before `POST /api/play/seat-invitations/claim-phone/{token}`. That route is not a money write. Gift and seat JSON bodies still use `acceptableToken` and were not changed.

7. **Signing-key pin.** `ExternalGameReviewModel.pinKeychain` adopts a stored key only when it is `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` and not synchronizable. A weaker item is deleted and not used. The key is not logged.

8. **Other device-only Keychain reads.** Image-upload, square-workspace, roam-history, native-enrollment, template-authoring, and project-edit reads use `KeychainItemProtection.isDeviceOnlyUnlocked`. A non-compliant item is deleted and the read fails. Session-token storage already had this check and was not changed. The template-authoring release projection fixture was updated to the same read; the DEBUG diagnostic block is still stripped before that comparison.

9. **Square share pasteboard.** Copy uses `public.utf8-plain-text` with `.localOnly` and a 120-second expiry. The card image is kept only when the same https origin check passes.

10. **Place-note copy.** The existing local-only pasteboard write now expires after 120 seconds. The URLs are the public catalog sources.

11. **Channel attachment URL.** `isApprovedAttachmentURL` is the https origin check. `http://127.0.0.1` and `http://localhost` are not approved. `https://cdn.example.com/club/route-map.jpg` still passes the origin check.

12. **DEBUG E2E log.** `E2ETestHostTransport` logs method, path, status, and latency. It does not log the response body or the absolute URL. The error line still passes the error text through `LogFieldRedaction`.

## Gates

`tools/generate_project.py` OK (new `Core/KeychainItemProtection.swift` is in the app target). `tools/check_scaffold.py` PASS (a11y lint, typography, design consistency, log redaction, page routes). `tools/check_appsession_ratchet.py` PASS (`App/AppSession.swift` 7976 ≤ 7977). `tools/check_log_redaction.py` PASS (0 findings). `Tests/ContractChecks/test_appsec_review.py` 8 tests OK, including `test_8_k50_r9_player_reachable_leaks_and_deep_link_inputs`. `tools/contract_ratchet.py --check` 46 failing, baseline 46, new 0, fixed 0. No `xcodebuild`. No Swift compiler on this machine.
