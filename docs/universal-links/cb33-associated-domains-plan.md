# CB33 — Universal links and Associated Domains

The owner has not supplied the universal-link host. This change keeps that host configurable and empty. It does not put a domain in the app entitlement, the site-association file, or the production allowlist.

## What stays empty

| Slot | Current value | File |
| --- | --- | --- |
| Production entry allowlist | `NativeEntryLinkPolicy(verifiedHTTPSOrigins: [])` | `App/AppSession.swift` |
| Parser default | `UniversalLinkConfiguration.verifiedHTTPSOrigins = []` | `Core/UniversalLinkParser.swift` |
| Associated Domains values | `UniversalLinkConfiguration.associatedDomainEntitlements = []` | `Core/UniversalLinkParser.swift` |
| Entitlement file | `com.apple.developer.applesignin = [Default]` only | `Config/Questify.entitlements` |
| API base URL | empty | `Config/Base.xcconfig` (`QUESTIFY_API_BASE_URL`) |
| Session realm | empty | `Config/Base.xcconfig` (`QUESTIFY_SESSION_REALM`) |

`Config/Questify.entitlements` does not contain `com.apple.developer.associated-domains`. `Config/Info.plist` does not contain `CFBundleURLTypes`. No associated-domain value is compiled into the app. The bundle id in `Config/Base.xcconfig` is still the placeholder `invalid.example.questify.ios`. Version stays `MARKETING_VERSION = 0.1.0` and `CURRENT_PROJECT_VERSION = 1`.

`UniversalLinkParser` is the reviewed gate for a later owner host. `AppSession.receiveNativeURL` still calls the existing empty `NativeEntryLinkPolicy`. With an empty allowlist that call already accepts nothing, so leaving the call site in place does not open links. `Core/NativeEntryRouting.swift` is unchanged.

## What the owner supplies later

One ASCII host, or the punycode form of an internationalized host. No scheme, path, port, user, or wildcard. The same host must be the one that will answer `https://<owner-supplied-host>/.well-known/apple-app-site-association`.

Also required before any entitlement edit:

- The Apple Team ID that will own the App ID.
- The real bundle id that replaces `invalid.example.questify.ios`. The placeholder must not be written into the site-association file as if it were the shipping id.
- Whether a WeChat universal-link host is this same host. That registration is a separate owner value. This plan does not add a WeChat app id, URL scheme, or query scheme.

## Later edit, not done here

1. Set `UniversalLinkConfiguration.verifiedHTTPSOrigins` to `["https://<owner-supplied-host>"]` and no other origin.
2. Set `UniversalLinkConfiguration.associatedDomainEntitlements` to `["applinks:<owner-supplied-host>"]`. Do not use a wildcard host unless the owner asks for one.
3. Add `com.apple.developer.associated-domains` to `Config/Questify.entitlements` using that one value. Turn the capability on for the App ID and refresh the provisioning profile in the developer portal.
4. Host the site-association file at `https://<owner-supplied-host>/.well-known/apple-app-site-association` with `Content-Type: application/json`, no redirect, and `appIDs` of `<team-id>.<real-bundle-id>`. Paths must be no wider than the routes below.
5. Point `AppSession.nativeEntryLinkPolicy` at `UniversalLinkParser()` so the new gate is the one `receiveNativeURL` uses. Do that in the same change that sets the host. Do not add a second allowlist.
6. Do not add `CFBundleURLTypes` for this host. A universal link is not a custom URL scheme.

Until those steps happen, `associatedDomainEntitlements` stays `[]` and the entitlement file stays Sign in with Apple only.

## Routes the parser may type

`UniversalLinkParser` does not add destinations. After the host gate, `NativeEntryLinkPolicy` is the only classifier. The routes it already types are:

- `/door` with `scene`, `inviter`, or `id`
- `/merchant/team` with one `invite` query item
- `/merchant/public-home/<id>` and `/merchant/public-home/member/<id>` with no query
- `/team/join`, `/pages/team/join/index`, `/badge`, and the existing content source paths (`/pages/activity/detail/index`, `/pages/club/detail/index`, `/pages/topic/index/index`, `/pages/templatedetail/templatedetail`, `/pages/square/detail/index`, `/subpackageRoam/poi-detail/index`, `/subpackageRoam/session/index`)

A future site-association `paths` list should name only those paths. Unknown paths still fail closed.

## Parser rules

- Default and empty configuration accept nothing.
- Scheme must be `https`. User, password, port, fragment, and a URL longer than 8192 bytes are rejected.
- A configured origin is kept only when it is `https://<dns-host>` or `https://<dns-host>/`. Userinfo, port, query, fragment, and any other path are dropped. Host case is folded.
- The host must be a DNS name of at least two labels, each 1–63 LDH characters, total length at most 253. It must be in the normalized allowlist.
- These hosts are rejected even if a caller lists them: numeric addresses, a single label, `localhost`, names ending in `.local`, `.localhost`, or `.invalid`, names containing `:`, and the legacy literal IPv4 already denied by `DeepLinkAndUniversalLinkSafetyAudit`.
- The path must be a single slash-separated sequence of ASCII letters, digits, hyphens, and underscores. `.`, `..`, `//`, `\`, and `%` are rejected.
- Parsing does not perform network I/O.

Fixture hosts such as `example.test` appear only in tests. They are not an associated domain.

## Explicitly unchanged

- Password login, bank-card withdrawal, and virtual goods stay off.
- No US API URL, payment route, legal copy, support contact, user-content policy, or China filing number is added.
- No CB26–CB31 view migration is included.
- `tools/current_ci_manifest.json` is not refreshed.

## Not run

This environment has no `swift` and no `xcodebuild`. Not run, and not claimed as passed:

- `swift` typecheck
- `swift test`
- XCTest, including `UniversalLinkParserTests`
- `xcodebuild`
- simulator or device launch
- Associated Domains or site-association fetch
- provisioning-profile or App ID capability check
