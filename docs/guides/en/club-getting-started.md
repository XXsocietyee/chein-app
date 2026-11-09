# Getting started with a club

A club is the group that hosts routes and activities in a city. You can browse as a guest, join as a member, or apply to become the host. Creating a club is a later step, and only after the server says this account is a host.

This page follows the mini-program club path already described in the repo: the club home, join or apply, the club page, the host application, and create.

> **[LEGAL TEXT PLACEHOLDER — NOT APPROVED]**
>
> The user agreement, the privacy policy, and the account-cancellation notice are not written in this guide.
> Approved text has not been supplied. Reading this page is not acceptance.
> Do not paste this placeholder into the app as a policy.

> **[SUPPORT CONTACT PLACEHOLDER — NOT PUBLISHED]**
>
> No support address, phone number, email, WeChat ID, or filing number is published here.
> If the app shows a contact supplied by the server, use that contact.
> If it does not, this page cannot give you one.

## Find a club

The club tab lists four separate groups:

- 我创建的俱乐部 — clubs this account created. This list is not the same as clubs you joined.
- 我加入的俱乐部 — clubs you belong to.
- 附近俱乐部 — clubs returned as nearby.
- 俱乐部活动 — activities attached to clubs. A row opens that activity when the app has a destination for it. Otherwise it stays a row you can read.

查找俱乐部 searches by name. An empty search is the directory. No matches say 未找到俱乐部. Try another name or clear the search.

Created, joined, and nearby can each be empty on their own. Empty is not an error. A failed load has a retry. A 401 asks you to sign in. A 403 says this account cannot see that page. Signing in again does not fix a 403.

The member list is for the creator and for people who have joined. A visitor does not see it. If the club says it has members but the list comes back empty, the list is unavailable. That is not "this club has no members."

## Join, apply, or leave

On the club page, the button follows the club's rule and your current status. The app reads the club again before it asks you to confirm, and again before it sends.

| What you see | What happens |
| --- | --- |
| 加入俱乐部 | You ask to join. Membership is whatever the next detail read says. The first response does not mark you a member on the device. |
| 申请加入 | The club approves members. You wait. Sending again while it is pending does nothing. |
| 重新申请 | An earlier application was declined. You can send another. |
| 退出俱乐部 | You are a member and not the creator. Confirming leaves. You may lose the member list and member-only actions. Joining again may need approval. |
| Pending | The application is waiting. There is no second submit. |
| Creator | The creator does not leave the club from this button. |
| Merchant account | A merchant account does not join a club from this button. The screen uses the partnership path instead. |

If the result is unknown, do not send it again. The request may already have arrived. Use 查看当前成员状态 and read the detail. Joined, pending, and not a member stay different after that read.

A club-only activity on Home says 请先加入俱乐部再报名. Join that club first, then go back to the activity. Seats can be reserved for members.

There is no membership fee on this join button. If the server refuses the request, the refusal stands. This page does not add another way in.

## Inside the club

The club page has 帖子, 活动, and 概览. A host or an admin also sees 管理. A guest or a merchant looking at the club lands on 概览. A member lands on 帖子. You cannot force the manage tab open if the detail read says you cannot manage.

概览 shows the introduction, the host, the city, the type, and the member entry when you may see members. The weekly contribution list is for members. Someone who is not a member sees that it is locked, not a zero list.

活动 lists the club's sessions and can open the calendar. 帖子 is the club's conversation. You only see a channel after you can enter the club. Text channels can be written when you are allowed. Announcement channels are read-only. The transcript refreshes while you are looking at it. There is no separate live socket in the source flow.

Report and block, when the message menu shows them, are how you flag a person or a message. You cannot report yourself. A club admin's remove, ban, and delete actions are not member actions. A platform ban is not something a club admin lifts.

## Become the host

Start from the home hero 成为俱乐部, from Settings 成为俱乐部主理人, or from the create page when it says you are not a host yet. The create page says 请先成为俱乐部主理人 and offers 前往申请.

The application asks for:

- 实名 / 昵称
- 联系方式
- 身份说明
- 联合创始人
- 最大带队人数
- 平均参与人数
- 持导游 / 旅游资质

A certificate image stays off this form until upload is available. If you attach an image and the screen blocks submit, remove it and send the text fields, or wait until upload is enabled. Do not type a stand-in URL.

Merchant accounts and people who are already hosts see their own state on this form. Submitting does not create the club. It asks the server to recognize you as a host. Read the status it returns. Do not treat the acknowledgement as the club already existing.

The intro, the steps, and the done screen in the mini-program are one review form on iOS. The done screen's 创建我的俱乐部 appears when that handoff is available. If it is not on the screen, open the club tab and use create from there after the status says you are a host.

## Create the club

Create checks two things first: this account's role is a club host, and you are under the two-club limit from 我创建的俱乐部. If either check fails, the form does not open.

The mini-program walks four steps: type, up to three directions, the profile, then the city. iOS collects the same required facts on one form. Type, name, and city are required.

Logo and cover upload are not available on this form. The screen says media is unavailable and keeps any reference the server already had. Do not paste an image address.

After the server accepts the create, open the club. The manage tab is there when the detail read says you can manage. If that handoff is not wired yet, open the club from 我创建的俱乐部 and choose 管理 yourself.

## Run the club

管理 is for the owner and for people the server marks as able to manage. An admin who is not the owner can change display information. The card says 你是管理员 · 只能改展示信息. Operating switches such as priority sign-up, join approval, and reserved seats stay with the owner. The admin sees the current values and no switches. The line is 只有主理人能改经营配置.

From manage, when the entry is shown, you can open:

- Join requests. Approve or decline only from the request the server listed.
- The member list, with roles. Removing a member is blocked for the owner and for a member who still holds an active role assignment.
- Notices.
- A group code. Only the host and check-in staff can issue one. Everyone else sees 仅主理人和核销人员可出码，请联系俱乐部主理人开通. This page does not print a code.
- Enrollment for a club session. Rows can show 已核销 or 待核销. The fee line says the sign-up fee is held by the platform. That sentence is not a payout instruction.
- The weekly stats and the governance inbox. Cases and appeals are also linked from 概览 for someone who is not a manager.
- A new club route. The owner chooses 城市定向 or 自由探索, or cancels. Opening the editor does not publish. If an older local draft is still there, the editor asks you to restore or discard it. Restoring does not silently replace that draft with the new club.

Check-in detail for a player shows the rail 已报名, 已接洽, 已核销, 已评价 when the server sends a step. Refunded and unknown steps do not light that rail. Clearing a player and refunding them is a separate host action. It stays off until that write is enabled. Do not treat the detail page as the refund itself.

Settlement on the club manage tab is a reconciliation you can read. It is not a bank transfer. This guide does not describe bank-card withdrawal.

## When a screen will not move

- Home, directory, and detail can load for a guest. 我创建的俱乐部 and the member list ask you to sign in first.
- Join and leave confirm the club name and the consequence. If the rule changed between the prompt and the send, the app cancels that attempt. Refresh and read the button again.
- A badge on someone else's row is their role, not yours.
- Two clubs is the create limit. The form will not open a third.
- Unknown join status turns the button off. Refresh. Do not guess which action would have been sent.

## Where this comes from

Club home, directory, and members: `docs/club-module.md`. Join and leave: `docs/club-actions.md` and `docs/club-actions-localizations.json`. Detail, apply, create, and edit: `docs/parity/w2-15.md`. A club route: `docs/club-project-launch.md`. Channels and admin actions: `docs/worker-reports/w6-clubs-channels-report.md`. The home and settings entries: `docs/parity/w2-02.md`, `docs/alignment/xcx-ios-B-20261019.md`.
