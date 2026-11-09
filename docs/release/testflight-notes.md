# TestFlight notes

Not submitted. If the owner later uploads a signed build, the owner pastes the locale below into App Store Connect. This file does not upload it, and it is not the store listing.

Pair: marketing version `0.1.0`, build `1`, from `Config/Base.xcconfig`.
Base: `origin/rc/20261108` at `67053ccb33c0e1ad35a7508f8546ae9076fd82e5` (2026-11-08 PT).

The English block is the `en` What to Test text. The zh-Hans block is the `zh-Hans` What to Test text. Paste one locale at a time, without the heading.

## en

Questify 0.1.0 (1). This note describes that pair. It is not approval to distribute it.

On a signed install, open Settings, then About. Version reads 0.1.0. Build reads 1. The name reads Questify.

The committed bundle id is invalid.example.questify.ios. The committed API base URL and session realm are empty, so this build stays unconfigured and does not call a backend. Sign-in, payment, and withdrawal do not run.

Account cancellation reads: "Account cancellation can't be requested in the app yet. Read the cancellation notice to see how it works." That row does not delete an account.

On a fresh launch, stop at the usage-consent gate and read it. Switch between English and 简体中文. The app asks for location only while it is open. It does not ask for Always location, and it does not claim background location.

Do not use this build to pay, withdraw, or delete an account.

## zh-Hans

Questify 0.1.0（1）。这段说明只描述这个版本号，不是分发许可。

在已签名的安装里打开「设置」，再打开「关于」。版本应显示 0.1.0，构建版本应显示 1，名称应显示 Questify。

仓库里的套装标识是 invalid.example.questify.ios。接口基址和会话域名为空，因此这个构建保持未配置，不会访问后端。登录、支付和提现都不会执行。

账号注销的说明是：「暂不能在 App 内申请注销账号。可先阅读注销须知了解流程。」这一行不会删除账号。

全新启动后先停在使用同意门，把正文读完。在 English 和简体中文之间切换。应用只在打开时申请定位，不申请「始终」定位，也不声称会在后台使用定位。

不要用这个构建付款、提现或删除账号。
