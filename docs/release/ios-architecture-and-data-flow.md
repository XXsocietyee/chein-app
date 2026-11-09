# iOS architecture and data flow

Docs only. Marketing version stays **0.1.0** and the build stays **1** (`MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `Config/Base.xcconfig`). This note does not change that version, a host, a realm, a route, or a signing setting.

Read against `rc/20261108` at `88e981b3308558939e405606cd731b4b29fc9499`. Nothing here was compiled, and nothing here contacted a network.

Searched this branch and the origin doc branches (`origin/cloud/doc-1` through `origin/cloud/doc-5`, and `origin/docs/*`) before writing. There is no earlier architecture overview under `docs/release`. Sections that already exist are listed below and are not rewritten.

## Sections skipped

| Section | Branch | Path |
|---|---|---|
| Startup object path (`QuestifyApp` → `AppSessionContainer` → `AppCompositionRoot` → `AppSession` → `SessionRootView`) and the fixture short-circuit | `rc/20261108` | `docs/app-composition/first-slice.md` |
| CN and US operational profiles, language, and capability gating | `rc/20261108` | `docs/regional-configuration.md` |
| China production build inputs, the empty default URL, and the unsigned-archive facts | `rc/20261108` | `docs/release/ship-prep.md` |
| Shipped read-grant families and what those grants do not admit | `rc/20261108` | `docs/release/wire-1-grants.md` |
| CN SMS and account session request and response contract | `rc/20261108` | `docs/cn-native-session-contract.md` |
| US Apple wire contract. That adapter has no default URL and is not mounted on the session root | `rc/20261108` | `docs/us-apple-client.md` |
| Marketing version row and App Store metadata checklist | `rc/20261108` | `docs/release/app-store-metadata-checklist.md` |
| Player dark and merchant light theme | `rc/20261108` | `docs/release/ui-role-theme.md` |
| Player and merchant tab bars | `rc/20261108` | `docs/release/ui-token-diff.md` (§7) |
| Business-runtime composition (bank, stamp, IM, publishing, verification) | `rc/20261108` | `docs/business-runtime/composition-and-acceptance.md` |
| Private-home session composition | `rc/20261108` | `docs/private-home-session-composition.md` |
| Runtime dependency wiring | `rc/20261108` | `docs/runtime-dependencies/configuration-and-audit.md` |
| Production route inventory, envelope conventions, and the hand-read bundle and auth routes | `origin/cloud/doc-5` | `docs/release/backend-contract-for-ios.md` |
| Privacy inventory and data sent to a backend | `origin/cloud/doc-3` | `docs/release/privacy-data-inventory.md` |
| Ops architecture facts, client kill switches, and backend-error behavior | `origin/cloud/doc-4` | `docs/release/ops-runbook.md` (§1, §2.1, §2.2) |
| Backend deploy plan, including the ban on copying a route table | `rc/20261108` | `docs/release/backend-deploy-plan.md` |

`origin/docs/gap-spec-api` `docs/release-build-flags.md` and `docs/native-login-setup.md` describe the Flutter client. They are not this native process. This overview does not take a URL from them.

## 1. Two compile products

The running app is the Xcode target **Questify** (`Questify.xcodeproj`). SwiftUI screens, the composition root, and `AppSession` live under `App/`. Build settings live under `Config/`. Catalogs and `Resources/PrivacyInfo.xcprivacy` live under `Resources/`. The target's base configuration, Debug and Release, is `Config/Base.xcconfig`. Deployment target in that file is iOS 17.0. `Config/China.Production.xcconfig` is not that base configuration.

Domain types, regional configuration, and the HTTP service types live in the Swift package **QuestifyCore** (`Package.swift`, path `Core/`). The package declares iOS 17 and macOS 14. `swift test` runs `Tests/CoreTests`. App-hosted tests are `Tests/AppUnitTests` and `Tests/AppUITests` on the Xcode targets. `Vendor/GLTFKit2` is a vendored framework, not a feature module. `tools/` is Python checks. It is not on the request path.

Feature screens read an `AppSession` service. That service, when it exists, is a Core type that builds a `URLRequest` from `APIConfiguration`. Three media loaders in `App/` (`PlayKitGLBDownloader`, `PlayKitSpatialAssets.loadImage`, `ApprovedAudioDownload`) open their own ephemeral `URLSession`. They do not attach the API session token, and they are not the composition transport below.

## 2. How a screen reaches the network

`QuestifyApp` owns an `AppSessionContainer`. Outside a DEBUG fixture, that container calls `RegionalLaunchConfiguration.composition.makeSession()`. The resulting `AppSession` is what `SessionRootView` observes. The object path and the fixture short-circuit are already in the first-slice note named above.

`composition` calls `shippedComposition`. That function either returns a reviewed composition or `makeComposition(reviewed: nil, build: .current)`. The nil case is `DeploymentState.unconfigured`.

`AppSession.init` constructs network services only inside `if let scope, let regional, let configuration = regional.apiConfiguration`. `HomeFeedService` is constructed only when that configuration exists and the reviewed deployment's reads include `.homeAndSearch`. The `else` branch sets those services to nil and uses `UnconfiguredRegistrationBackend` for registration. A view whose service is nil has nothing to send.

When a service does run, the request path is:

1. The Core service appends its path to `APIConfiguration.baseURL` and builds a `URLRequest`. `APIConfiguration` accepts only `https`, with a host, and with no user, password, query, fragment, or `..` path segment. It has no production default.
2. The session's transport is `composition.transport()`, a `CompositionHTTPTransport` around the injected factory. The factory default is `URLSessionTransport()`.
3. `CompositionHTTPTransport.send` requires a reviewed deployment, a non-nil `apiConfiguration`, and a request URL with no fragment. A typed route then has to admit that exact request. Anything else throws `APIError.notConfigured`. A read grant does not admit a write. Which families the China selection passes is the wire-1 note, not a route list.
4. An admitted request goes to `URLSessionTransport`. That session is ephemeral. Cookie storage is nil, cookies are off, the URL cache is nil, and redirects are not followed. The resource timeout on that session is 30 seconds. Individual services set their own request timeout and cache policy. Those numbers are not one value, and this note does not tabulate them.

Auth field shapes, the JSON envelope, and which paths exist on the server are the documents in section 5. This note does not restate them.

## 3. When that path has no backend

An empty URL still means no backend.

`RegionalConfiguration` trims `baseURL`. An empty string sets `apiConfiguration` to nil, even if an approval dictionary is non-empty. `shippedComposition` reads the built `QuestifyAPIBaseURL`. `ReviewedMarketLaunch.admitsShippedChina` is true only when the market is China, that URL is exactly `https://www.chengyinhub.com/prod-api/`, and the bundle identifier and realm can form a `RegionalSessionStorageScope`. Any other market, an empty URL, an empty realm, or any other host returns false, and the composition stays `DeploymentState.unconfigured`.

The only reviewed China host is that URL, with realm `cn-prod`, and only when the market is China and the URL and realm are both set. `Config/China.Production.xcconfig` is the file that records those two values. The default target does not use that file. `Config/Base.xcconfig` leaves `QUESTIFY_API_BASE_URL` and `QUESTIFY_SESSION_REALM` empty and sets `QUESTIFY_MARKET = CN`. Market alone does not select a host. `Config/UnitedStates.Production.xcconfig` also leaves the URL and realm empty. `ReviewedMarketLaunch.approvedBaseURLs` has a China entry and no United States entry. This note does not add a US API URL.

`RegionalLaunchConfiguration.configuration` is a different helper. Its approved-host registry is empty, so a URL in the built Info.plist is not an approval through that helper. The session root uses `composition`, not that helper. The profile recipe is `docs/regional-configuration.md`.

Password login, bank withdrawal, and virtual goods stay off on the shipped selection. The wire-1 note is the list. The legacy address that note disallows is not a host here.

## 4. Where the session token is stored

A reviewed deployment builds one `RegionalSessionStorageScope` from the market, the approved endpoint, the bundle identifier, and the realm. `serviceName` length-prefixes those four UTF-8 strings, joins them, base64-encodes the join, and prefixes `questify.session.v2.`. The scope is a local vault name. It does not approve an endpoint, and language does not enter it.

`AppScopedStorageFactory` defaults the token store to `KeychainTokenStore(scope:)`. The item is a generic password, service `scope.service`, account `session-token`, not synchronizable, and `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`. A nil scope reads and clears as a no-op and refuses a write (`StoreError.unconfigured`). The store does not import an unscoped or cross-realm token.

`AppSession.restoreBlockedKey` is `scope.restoreBlockedKey` when a scope exists, and `session.unconfigured.preventRestore` when it does not. Cold restore and logout ordering are the CN session contract. This note does not repeat the request bytes.

## 5. Production API

Do not paste a route table into this file. `docs/release/backend-deploy-plan.md` already says route tables are not copied into the public `chengyin-ios` repo. The same limit applies here.

The existing inventory is on `origin/cloud/doc-5` at `docs/release/backend-contract-for-ios.md`. It was written against `cloud/doc-5` (`origin/wip/wave4-loc`) and a read-only backend checkout. It is not regenerated for `88e981b3308558939e405606cd731b4b29fc9499`. Use it as the path inventory and the hand-read bundle and auth notes. Appendix A is the generated path list. Its method column is marked as a heuristic in that file. This overview does not copy Appendix A, and it does not treat a string in `App/` or `Core/` as a route the shipped build calls.

On this branch, use these instead of a new table:

- `docs/release/wire-1-grants.md` — the six read families `shippedComposition` passes when the China build matches, and the writes those families do not open.
- `docs/cn-native-session-contract.md` — the mounted CN SMS, current-account, and logout contract. Normal composition still requires the reviewed deployment before that contract can run.
- `docs/us-apple-client.md` — the US Apple client. It records no default URL, and `AppSession` does not mount it.
- `docs/release/gap345/` — classifications that cite the doc-5 appendix. They are not a second route table.

A path that appears in source and is absent from the shipped read grants stays closed while the composition is unconfigured. An empty `QUESTIFY_API_BASE_URL` is that unconfigured state.
