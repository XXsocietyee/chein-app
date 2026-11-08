# WP-06 new strings (not added; Resources/xcstrings are off limits for builders)

| Key | Purpose | Suggested zh-Hans |
|---|---|---|
| `friend.reviewUnavailable` | Friend request review refused fail-closed (server code 403), e.g. Apple-only/phone-only account without a WeChat openid | 暂时无法处理该好友申请，请稍后再试或换用微信登录的账号 |

Until this key exists in the string catalog, `NativeFriendFlow.issue` shows the raw key for 403 rejects (previously `friend.rejected`).
