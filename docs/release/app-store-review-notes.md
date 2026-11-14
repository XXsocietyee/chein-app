# App Review notes

Not submitted. Not signed. Version in the tree is `0.1.0` (`1`) in `Config/Base.xcconfig`. `QUESTIFY_API_BASE_URL` and `QUESTIFY_SESSION_REALM` are empty. `PRODUCT_BUNDLE_IDENTIFIER` is `invalid.example.questify.ios`. This note does not invent a demo password.

`externalGames` stays off on the production host `www.chengyinhub.com`.

## English

### Demo account

Steps: —

No demo account exists in this repository. Missing: a review username, a phone number, an SMS code, and a password. `Config/Local.xcconfig` is absent. Do not paste a password into App Store Connect from this file.

What is present without an account:

1. Launch the app and read the usage-consent gate (`authEntry.gate`, agree or decline).
2. On the welcome screen, tap Browse (`welcome.browse`). That enters the tab shell without an account. Decline on the consent gate does the same.
3. This build has an empty API base URL, so those tabs do not load `https://www.chengyinhub.com`. This note does not claim they show live city content.
4. Password sign-in is not compiled into a non-DEBUG build. `AppSession.passwordLoginCompiledIn` and `canUsePassword` are false outside `#if DEBUG`.

A signed-in player, merchant, or club-admin walkthrough is missing until an owner creates the account outside this repository.

### External games (Guideline 4.7)

The in-app index is `ExternalGameCatalogSection` inside `ExternalGameLibrarySection` (`App/ExternalGameImportView.swift`). The backpack shows it on the game tab only when `externalGamesEnabled` is true. `PlayExperienceView` sets that flag from `ExternalGameSessionRead.externalGamesOpen`, which calls `ReviewedAreaSwitch.externalGames(host:testOrDebug:)`.

That call is false when the host is `www.chengyinhub.com`, and it is false on a Release build because `compiledTestOrDebug` is false. `externalGames(apiHost:)` is also false for `www.chengyinhub.com`. The production host does not show the index.

When the switch is on, against a host other than production and only in TEST or DEBUG, the index lists each approved game with name, version, content rating, author or —, summary or —, monetization `NONE`, sha256, permissions or —, and allowed domains or —. Copy on that screen says HTML and JavaScript only, no native code, bridge `1.0` limited to `getMetadata`, `loadProgress`, `saveProgress`, and `haptic`.

Catalog read: `GET /api/external-game/catalog`. Download stays under `/api/external-game/catalog/.../package`. Report: `POST /api/external-game/reports`. Package ratings accepted by `ExternalGameContentRating` are `4+`, `9+`, `12+`, and `17+`. A body that carries a price, `iap`, or `StoreKit` is refused. Monetization on submit is `NONE`.

A reviewer of the production host will not open this index. The catalog of games on that host is —.

### Money switches

For API host `www.chengyinhub.com`, this note does not turn any switch on. `App/ReviewedAreaSwitch.swift` is unchanged.

| Switch | Production host |
|---|---|
| `moneyPayments` | Off |
| `payout` | Off |
| `merchantWrites` | Off |
| `passwordLogin` | Off |
| `externalGames` | Off |

Virtual goods stay off. `releaseMoneyDerivation` returns false for `.virtualGoods`. Digital goods, if a later approval sells one, go through StoreKit. See `docs/release/storekit-sandbox.md`. This note does not add a card charge. `Config/QuestifySandbox.storekit` is a local sandbox file with an empty product list. Product ids are —.

Location on this branch is when-in-use. `ui/wp-11` `1e48434` also keeps a roam you started updating in the background until you pause, finish, sign out, or stop it from Privacy, still without an Always prompt. That tracker is not in this commit. Precise Location in `Resources/PrivacyInfo.xcprivacy` is the collected type. No separate background API was added.

## 简体中文

### 演示账号

步骤：—

此仓库中没有演示账号。缺少：审核用用户名、手机号、短信验证码和密码。`Config/Local.xcconfig` 不存在。不要根据本文件往 App Store Connect 粘贴密码。

没有账号时可以做的事：

1. 启动 App，阅读使用同意门（`authEntry.gate`，同意或拒绝）。
2. 在欢迎页点「先逛逛」（`welcome.browse`）。这会在没有账号时进入标签栏。在同意门上拒绝，结果相同。
3. 此构建的 API 基址为空，这些标签不会加载 `https://www.chengyinhub.com`。本说明不声称它们会显示线上的城市内容。
4. 非 DEBUG 构建不编译密码登录。`#if DEBUG` 之外，`AppSession.passwordLoginCompiledIn` 和 `canUsePassword` 为 false。

在仓库外由负责人创建账号之前，没有已登录的玩家、商家或俱乐部管理员走查。

### 外部游戏（准则 4.7）

应用内索引是 `ExternalGameLibrarySection`（`App/ExternalGameImportView.swift`）中的 `ExternalGameCatalogSection`。只有 `externalGamesEnabled` 为 true 时，背包的游戏标签才会显示它。`PlayExperienceView` 用 `ExternalGameSessionRead.externalGamesOpen` 设置该标志，后者调用 `ReviewedAreaSwitch.externalGames(host:testOrDebug:)`。

主机为 `www.chengyinhub.com` 时该调用为 false；Release 构建中 `compiledTestOrDebug` 为 false，该调用也为 false。`externalGames(apiHost:)` 对 `www.chengyinhub.com` 同样为 false。生产主机不显示该索引。

开关打开时（主机不是生产主机，且仅为 TEST 或 DEBUG），索引用名称、版本、内容分级、作者或 —、简介或 —、变现 `NONE`、sha256、权限或 —、允许的域名或 — 列出每个已通过的游戏。该屏文案写明仅 HTML 与 JavaScript，不下载原生代码，桥接 `1.0` 只开放 `getMetadata`、`loadProgress`、`saveProgress` 和 `haptic`。

目录读取：`GET /api/external-game/catalog`。下载保持在 `/api/external-game/catalog/.../package` 之下。举报：`POST /api/external-game/reports`。`ExternalGameContentRating` 接受的包分级为 `4+`、`9+`、`12+` 和 `17+`。正文若带价格、`iap` 或 `StoreKit` 会被拒绝。提交时的变现为 `NONE`。

审核生产主机的人打不开这个索引。该主机上的游戏目录为 —。

### 资金开关

对于 API 主机 `www.chengyinhub.com`，本说明不打开任何开关。`App/ReviewedAreaSwitch.swift` 未改。

| 开关 | 生产主机 |
|---|---|
| `moneyPayments` | 关 |
| `payout` | 关 |
| `merchantWrites` | 关 |
| `passwordLogin` | 关 |
| `externalGames` | 关 |

虚拟商品保持关闭。`releaseMoneyDerivation` 对 `.virtualGoods` 返回 false。数字商品若在以后的批准中出售，走 StoreKit。见 `docs/release/storekit-sandbox.md`。本说明不增加银行卡扣款。`Config/QuestifySandbox.storekit` 是本地沙盒文件，产品列表为空。产品 ID 为 —。

本分支的定位是使用期间。`ui/wp-11` `1e48434` 还会在你开始的漫游结束前于后台继续更新，直到暂停、结束、退出登录或在隐私页停止，仍然没有「始终」提示。那个追踪器不在这次提交里。`Resources/PrivacyInfo.xcprivacy` 中的精确位置是收集类型。没有单独新增后台 API。
