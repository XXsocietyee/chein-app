# Cloud stubs — playkit writes #2 #3 #4

Parent: `origin/ui/next` `bdd0a90b3b3c1abb52c767d2fe877effed428755`.
Ledger (not edited): `origin/ui/stub-ledger` `0ad3cefa` `docs/release/stub-ledger.md`, rows #2, #3, and #4 only.
`UGGameplay.contractExecution` stays `"NOT_RUN"`. `docs/release/contract-failing-baseline.txt` was not edited. `App/AppSession.swift` and `App/AppCompositionRoot.swift` were not edited. No new App or Core Swift file, so `tools/generate_project.py` was not required. Money, price, and payment fields are not sent.

## English

#2 Hangman. `PlayKitActionCatalog` now has `"hangman": ["SUBMIT_HANGMAN"]`. `PlayKitInputContract.validate` accepts `{slots: {"i": one character}}` for every editable cell and refuses a solved board, a missing cell, more than one code point, whitespace, and any extra field such as `amount`. `PlayAdvancedView` posts that payload through `PlayAdvancedCoordinator.submit` when `ugHangmanWrite` is nil. `UGGameplayReader.submitHangman` POSTs `/api/play/advanced/action` on the injected non-production transport. A transport error or a non-2xx response (other than 401) returns `.unknown` with the same request id. HTTP 401 or a business code other than 200 returns `.failed` and does not mint a replacement id. A missing hangman grant does not send. Help, skip, and `submitAccusation` still throw `writesNotAvailable`. The reader still refuses a production host.

#3 Accusation. `UGGameplay.accusationPublishable` is true. `PlayKitScreen` calls the existing `prepare("SUBMIT_QA", ["optionId": …])` path when `ugAccusationWrite` is nil. `PlayAdvancedView` passes that same optional through, so both call sites publish UG-03 as `SUBMIT_QA`. There is no `SUBMIT_ACCUSATION` and no `accusation` catalog key. The qa catalog stays `["SUBMIT_QA"]`.

#4 Album. The catalog has `"album": ["SUBMIT_ALBUM"]`. For an R5 album that is not done, the completion button opens the existing photo capture. A reviewed https URL posts `SUBMIT_ALBUM` with `{imageUrls: [url]}`. An upload error, a missing camera, or a non-https URL stays a failure and does not create a request id. An unknown action result keeps `pending.key` on screen, with reconcile; a second submit does not POST. This is not a payment.

Checks on this branch, before push: `python3 tools/check_scaffold.py` PASS, `python3 tools/check_design_lint.py` PASS. Swift is not installed on this machine, so the new Core tests were not executed here.

## 简体中文

#2 逐字猜词。动作目录增加 `"hangman": ["SUBMIT_HANGMAN"]`。输入校验只接受每个可填格子一个字符的 `{slots}`，已解开、缺格、多字符、空白和 `amount` 等额外字段都会拒绝。`ugHangmanWrite` 为空时，页面经高级会话协调器提交。`UGGameplayReader.submitHangman` 在注入的非生产传输上 POST `/api/play/advanced/action`。传输失败或非 2xx（401 除外）返回 `.unknown`，请求号不变。401 或业务码不是 200 时返回 `.failed`，不另造请求号。没有逐字猜词授权则不发送。帮助、跳过和 `submitAccusation` 仍抛出 `writesNotAvailable`。生产域名仍然拒绝。

#3 指认。`UGGameplay.accusationPublishable` 为 true。`ugAccusationWrite` 为空时，`PlayKitScreen` 走原有的 `prepare("SUBMIT_QA", ["optionId": …])`。`PlayAdvancedView` 把同一个可选闭包传下去，所以两处都用 `SUBMIT_QA` 发布 UG-03。没有第二个动作名，也没有 `accusation` 目录项。qa 目录仍是 `["SUBMIT_QA"]`。

#4 相册。目录增加 `"album": ["SUBMIT_ALBUM"]`。尚未完成的 R5 相册打开已有的拍照上传。审核通过的 https 地址才 POST `SUBMIT_ALBUM`，载荷是 `{imageUrls: [url]}`。上传失败、没有相机或不是 https，都停在失败态，不生成请求号。结果未知时画面保留已保存的请求号，并可核对；再次提交不会发新的 POST。这不是支付。

推送前检查：`python3 tools/check_scaffold.py` 通过，`python3 tools/check_design_lint.py` 通过。本机没有 Swift，新增的 Core 测试未在此执行。
