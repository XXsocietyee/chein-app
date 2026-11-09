# Getting started as a creator

A creator publishes routes, activities, and templates, then finds them again under 我的项目. Publishing rights come from the server. A button on Me does not grant them. This page follows the mini-program publish path already described in the repo.

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

## My projects

Open 我的项目 from Me. It has three tabs: 主题, 活动, and 模板.

- 主题 and 活动 list what you published or were asked to host. A card can show 主办 or 承办, the address when there is one, and the time line. A co-host card can show 待核销 when that count was sent. A missing count is not zero.
- Cards that need you first stay in front. The order is rejected, then draft, then pending.
- The list loads one page, up to 200 rows. If that cap is hit, the screen says to filter instead of inventing another page. The Chinese line is 已达到200条加载上限，请筛选查找.
- The template tab is your own template shelf. It is not the public template browser. List, unlist, and delete appear only when that write is turned on.

A long-press on a mini-program card lists 收到的申请, 编辑, 上下架, 取消并退款, and 删除. On iOS an action in that menu stays off until the matching write is enabled. A disabled row is not a hidden gesture.

Empty tabs have their own line. The topic empty state can offer 去发布. The activity empty state offers 发布单场活动 only when this session's role is a club. That button opens the ordinary publish hub, which checks again whether you can publish.

Draft and rejected topic cards open the editor. A public preview is a different page. Do not treat the preview as the editor.

## A route, the short way

Quick publish starts with 嗨，想做一条什么样的路线？ You see the route type, a draft, and numbered stops. Each stop has a place you confirm.

An AI draft is a draft only. The note on that entry says AI only drafts. You confirm the stops yourself, up to the three the sheet offers, before they enter the editor. The primary button continues into the editor. It does not publish.

The editor keeps a local draft. Leaving a clean editor closes it. Leaving a dirty editor asks you to keep editing or discard. Discard does not delete a draft already saved. Close a preview first if one is open. The editor does not submit while a submit is already in flight.

The route quota is the number under 发布路线 on your benefits, when the server sends it. Null means no cap was stated. If benefits cannot be read, the screen says the current configuration cannot read them. Do not assume the cap is unlimited.

## An activity

The activity wizard is three questions:

1. 这场活动叫什么、在哪儿办？
2. 这场活动玩什么？
3. 这场活动怎么卖票？

Then a summary. A new activity says 发布前摘要. An edit says 修改摘要. Read the visibility line on that card.

Collaborators are merged with you first, without duplicating you. The notice says collaborators can edit the content and do not join settlement.

If the host is a merchant, the ticket price can only be 0. Collection for merchant-hosted activities is not open. If you are not that merchant and the ticket is paid, publisher identity must already be registered. The wizard stops for that check.

Confirming the summary is the publish step the screen owns. If that write is off, the button tells you. Do not look for a second submit path.

## A template

The template introduction loads up to three examples. It takes the recommended pool if that pool has rows, otherwise hot, otherwise latest. It does not mix the pools. Loading, a failed load, and a true empty list are different. A failed refresh keeps the cards you already had. Begin and Skip both continue, including when there are no cards.

You then name the template and edit it. The samples on the introduction are not copied into your draft.

Saving and publishing are separate. A successful publish with a real id shows a short result, then opens 我的模板, your own shelf. If the result has no id, it is not a success. Closing the result does not publish again.

Back on a clean form leaves. Back on a dirty form asks you to continue or discard. That question does not wipe a saved draft.

The public template page and your private template are different. Secret answers stay on the private page. Do not expect them on the public info page.

Rehearsal and preview run on what you authored. They do not award a medal, change a player's health, or write a live session. A dice example on the preview uses the sample faces the screen shows. It is not a server roll.

## Review states

A project card and the creator center use the server's state. These are separate:

| State | What you do |
| --- | --- |
| Not applied | You have not sent an application. This is not the same as a rejected one. |
| Draft | Still yours. Open the editor. |
| Pending | In review. Wait. Do not edit it into an approval. |
| Approved | The server accepted it. Follow the card for what you can still change. |
| Rejected | Read the reason. Open the editor when the card says you can resubmit. |
| Unknown | The app does not relabel this as "not applied." Refresh or come back later. |

Income on the creator center is only the figure the server included. A missing figure stays missing. A zero stays zero. This page does not turn that figure into a payout, a currency you were not shown, or a balance.

Benefits on Me, when they can be read, list what this account may do: a route-publish cap or 不限, coupons, in-store check, branch and challenge play, opening a shop as a city stop, medal design, a group, and a link to earnings. Only an explicit yes unlocks a row. If the read is off, the section says the configuration cannot read benefits.

## What this page leaves out

Password sign-in is not a creator tool. Bank-card withdrawal is not how creator income is paid out here. Virtual goods are not a publish type. A coupon you attach to a route is an in-store offer the player shows at a shop. It is not an item sold inside the app.

Media upload, taking a route off sale, and cancel-and-refund stay on the control the app has enabled. A long-press label without an enabled action does nothing.

## When a screen will not move

- Publish from the hub the button opened. That hub checks permission again. A club-only activity button does not appear on a player session.
- Do not resubmit when the result is unknown. Open 我的项目 and read the card.
- A template id, a topic id, and an activity id can share a number and still be different objects. Open the tab you started from.
- The 200-row cap is a stop, not a broken list. Use the filters.
- Guest and signed-out states do not load this shelf. Sign in, then open 我的项目 again.

## Where this comes from

My projects and the creator center: `docs/creator-content-integration.md`, `docs/parity/w2-13.md`. Quick publish and the activity wizard: `docs/worker-reports/W4-core-loop.md`, `docs/release/ui-report-ui-f06.md`. Template introduction, exit, and the publish result: `docs/template-intro-experience.md`, `docs/template-author-exit-guard.md`, `docs/template-publish-receipt.md`. Benefits: `docs/parity/w2-03.md`.
