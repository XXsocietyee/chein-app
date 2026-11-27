# Support playbook

Chein **0.1.0 (1)**. English. The zh-Hans text is [`support-playbook.zh-Hans.md`](support-playbook.zh-Hans.md). Community rules are in [`community-guidelines.md`](community-guidelines.md) and [`community-guidelines.zh-Hans.md`](community-guidelines.zh-Hans.md).

This is an internal script for people answering support. It is not store listing copy, not a privacy policy, and not a filing. It does not change the version. Marketing version stays `0.1.0` and build stays `1` (`Config/Base.xcconfig`). Nothing here is deployed.

Written against `origin/rc/20261108` at `88e981b3308558939e405606cd731b4b29fc9499` (2026-11-09 PT).

The on-screen name is Chein in English and 城瘾 in Chinese (owner decision 2026-11-27: the English brand is Chein). Use the name the person used. Do not rename the app.

## Placeholders

These four blocks stay empty. Do not fill them in a reply, a macro, a store listing, or a later edit of this file unless the owner supplies the text.

| Block | Token | What is missing |
|---|---|---|
| Support contact | `[SUPPORT_CONTACT_PLACEHOLDER]` | No phone, no email, no WeChat ID, no web form, no support URL |
| Legal text | `[LEGAL_TEXT_PLACEHOLDER]` | No approved privacy policy, user agreement, or cancellation notice for this playbook |
| UGC policy | `[UGC_POLICY_PLACEHOLDER]` | No owner policy, no objectionable-content clause, no moderation SLA, no named reviewer |
| China ICP filing | `[ICP_FILING_PLACEHOLDER]` | No 备案号 |

Do not invent a phone number, an email address, or a China ICP number. Do not copy a number out of Settings → About, a screenshot, or source and treat it as this playbook's contact. A China-market About row can show a source-app contact string. That string is not authorization to publish a support address here.

The API base URL in `Config/China.Production.xcconfig` is a build input. It is not a support address, a privacy-policy URL, or a marketing URL. Do not send people there for help.

## Version and what this build is

| Item | Say this |
|---|---|
| Version | 0.1.0 (1) |
| Bundle id in the tree | The committed id is a placeholder (`invalid.example.questify.ios`). Do not quote a production bundle id. |
| Languages | English and zh-Hans. Answer in the language the person used. |
| Market | China is the only market with a reviewed host record. The US market stays off. Do not open a US account path. |
| Composition | The default target stays unconfigured (`makeComposition(reviewed: nil, build: .current)`). Do not tell someone this build is live on a production host. |
| Store | This branch is not submitted. Do not say the app is on the App Store. |

If the version they see is not 0.1.0 (1), write down what they see. Do not invent a second script.

## Do not offer these

Password login, bank-card withdrawal, and virtual goods stay off. Do not offer them, walk someone through them, or promise a later turn-on from a ticket.

### Password login

Username and password sign-in is off. Release builds do not offer it.

Do not ask for a password, accept one, tell someone to create one, or point them at a password form. There is nothing to reset. A password field that exists only in a debug build is not a supported sign-in.

If they cannot sign in, say: "Password sign-in is not available in this version." Phone codes, Sign in with Apple, and WeChat are not a password workaround. Do not promise those channels will finish on an unconfigured build. When the app says the feature is not available right now, repeat that. The English string is "This feature isn't available right now." The zh-Hans string is "此功能暂不可用." Do not invent a bypass.

Domestic China phone codes are the only sign-in capability the native client implements, and only when that build is actually configured and the form is on screen. If the form is not on screen, do not tell them to hunt for a hidden field.

### Bank-card withdrawal

Do not collect a bank card number, bank name, account holder name, or any payout secret. Do not start, approve, or promise a transfer. Do not give an arrival date.

The withdraw screen can ask someone to contact support. That label is not permission to move money. The screen's own explanation says support can help check records, and that the screen does not confirm a transfer or an arrival date. Repeat that. Reading history, when the screen can load it, is not a payout.

Bank-card withdrawal stays off in 0.1.0 (1). `AppSession.makeBankWithdrawalContext()` is nil unless bank permits exist, and the shipped composition does not issue them. Do not ask engineering to turn it on for one person.

### Virtual goods

Do not sell, gift, redeem, or promise virtual goods, a mall checkout, in-app currency, or a digital unlock. Do not ask for payment for a virtual item, in the app or outside it. Wallet mall and virtual-goods commands stay off. Registration payment stays off in this version.

If they ask to buy a virtual item, say: "Virtual goods are not offered in version 0.1.0 (1)."

## Support contact

Status: **PLACEHOLDER**. Leave this block as written.

```
[SUPPORT_CONTACT_PLACEHOLDER]
```

When someone asks how to reach support:

1. Confirm the version is 0.1.0 (1).
2. Tell them this playbook has no published phone, email, or ICP number.
3. In the app, the path is Settings → Support and safety → Show support contact. zh-Hans: 设置 → 客服与安全 → 查看客服联系方式. That sheet is the same contact sheet the withdraw screen uses.
4. If the sheet says the contact is unavailable, stop. English: "Customer support contact isn't available right now." zh-Hans: "客服联系方式暂不可用." Do not type a replacement WeChat ID, phone, or email.
5. Do not ask them to send a password, a token, a full bank number, or a verification code.

## Account cancellation

On this unconfigured build, Settings shows Account cancellation / 账号注销 and the request cannot be made in the app yet. English: "Account cancellation can't be requested in the app yet. Read the cancellation notice to see how it works." zh-Hans: "暂不能在 App 内申请注销账号。可先阅读注销须知了解流程."

Opening the notice does not delete the account. Do not say the account was deleted. Do not submit a deregistration from this playbook. The notice body is legal text and stays in `[LEGAL_TEXT_PLACEHOLDER]`. Do not paste it into a reply.

## Legal text

Status: **PLACEHOLDER**. Leave this block as written.

```
[LEGAL_TEXT_PLACEHOLDER]
```

Do not quote, translate, or summarize a privacy policy, user agreement, or cancellation notice as the approved text for 0.1.0 (1). The app can show source Chinese agreement and cancellation documents. Showing them is not approval, and this playbook does not reproduce them. The China app privacy policy and the US legal documents are not in this playbook. Interface labels in English are not translations of those documents.

If they ask for a privacy-policy URL, say it is not published here. If they ask for the ICP filing number, answer with `[ICP_FILING_PLACEHOLDER]` and do not guess digits.

## Reports and community

Follow [`community-guidelines.md`](community-guidelines.md). The UGC policy there is `[UGC_POLICY_PLACEHOLDER]`.

Do not state a review-time promise, including 24 hours. Some club-channel screens contain their own rules sentence. That sentence is not the policy of this playbook. Do not quote it as policy and do not extend it to other screens. The Content rules sentence under Settings → Support and safety is in-app draft copy. It is not copied here and it is not the UGC policy.

Where the screen already has a report action, tell them to use that action:

- Square posts and comments: Report in the overflow menu. Block from a post says it is not available and that nothing was blocked. Do not say the post was blocked.
- Club channel messages, channels, and members: use the report action that screen already shows.
- Club posts and comments: use the report action that screen already shows.
- Merchant reviews: use the report action that screen already shows.
- Messages: use report or block only when that conversation already shows it. A notice that only offers hide does not gain a report action from this playbook.

These screens have no report entry. Do not tell someone to tap a button that is not there:

- Topic detail
- Topic reviews and sections
- Activity reviews
- Club post discussion comments
- Member avatars

For those, write down what they describe. Do not promise removal. Review staffing is part of `[UGC_POLICY_PLACEHOLDER]`.

## Replies you can send

Keep them short. Do not add an address.

- "This is Chein 0.1.0 (1)."
- "Password sign-in is not available in this version."
- "Bank-card withdrawal is not available in this version. This screen does not confirm a transfer or an arrival date."
- "Virtual goods are not offered in this version."
- "A support phone, email, and ICP filing number are not published for this version."
- "Account cancellation can't be requested in the app yet."
- "The formal UGC policy is not published in the support documents yet."

## Out of scope

Do not deploy, sign, upload, or change 0.1.0 (1). Do not turn on password login, bank-card withdrawal, or virtual goods to close a ticket. Do not collect card numbers, identity documents, or one-time codes in the thread.
