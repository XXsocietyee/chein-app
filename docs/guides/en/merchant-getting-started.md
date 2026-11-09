# Getting started as a merchant

A merchant account is a shop that can host a stop, take orders the server assigns to that shop, and keep a store profile. Tapping 成为商家 does not grant that account. The server does, after an application it accepts and an access check that says the account is active.

This page follows the mini-program merchant path already described in the repo: the application, the status you read back, and the workbench you see only after that grant.

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

## Where to start

Two entries open the same application:

- Home hero: 成为商家.
- Settings: 成为商家, in the same row area as 俱乐部主理人. It is shown when this account is not already a merchant.

Both are applications. Neither one switches the tab bar or invents a merchant role on the device.

In the mini-program, an active merchant account uses five tabs: 工作台, 营销, 模板, 合作, and 我的. On iOS those destinations show up only when the server says the merchant account is active and the screen's permission is present. A missing tab means that grant is absent.

## Before you submit

The source calls this step registration, not a verified identity. The form asks whether publisher identity is already registered. If it is not, upload and submit stay closed.

The supplied enrollment uses a mainland Chinese identity check. This guide does not print that form, a document number, or a stand-in for another country. No US enrollment fields are collected here, because that contract was not supplied. If the app says identity is required or the lookup failed, stop on that screen. A lookup failure is not the same as "not registered."

You must be signed in. An unregistered or unconfirmed identity cannot upload the license or send the application.

## The application

The form is four steps. Required pieces are the shop name, phone, address, business hours, and the license photo. Description, preference, and a WeChat handle stay optional. The phone field does not invent a country-code rule.

1. Shop name and phone.
2. Address and business hours. Hours use the source weekday-and-time wording. You can cancel the hour picker without changing the draft.
3. License photo. Pick one image, look at the preview, then confirm the upload as a separate action. Picking the photo does not upload it. The draft keeps a license reference only after a successful upload, or from a rejected application the server sent back. There is no box where you type a URL.
4. Review. Confirming freezes this draft. Cancelling, or tapping again, does not send a second copy. Right before the send, the app reads the application state and the identity registration again. If either changed, it stops.

Location is requested only when you choose a place, to match the hosting area. The purpose line says you can still fill in the rest if you decline.

After the server acknowledges the submit, the app reads status once. That acknowledgement is not approval, not activation, and not a merchant role. If the result is unknown, do not send the form again. Use the status read. A later read that still looks unchanged does not prove the first send failed.

## What each status means

These stay distinct. Disabled always wins, and it does not reuse an old rejection reason.

| Status | What it means |
| --- | --- |
| No application | The server says there is no application. A failed request is not this state. |
| Pending review | Submitted. You wait. You do not edit it into an approval. |
| Rejected | The server sent a reason. Only this state can be filled back into a new application, and only the fields the server confirms. Coordinates and WeChat are not copied back. |
| Awaiting activation | Accepted, not operating yet. |
| Effective | The account can open the workbench. The workbench still checks access on each entry. |
| Disabled | The account is disabled. The disable reason is its own text. |

A business rejection keeps the server's words. The app does not invent a permanent conflict with a club host.

## After the account is active

The workbench shows the store and the role the server returned. It does not show operating links while the account is inactive.

What you see depends on permission:

- The owner can see pending work and recent events.
- Revenue and the seven-day amounts also need the finance read. Another role does not see those figures, and the app does not request them.
- A missing amount stays a dash. It is not zero. Money on this screen is the merchant source's CNY record, shown as the server sent it.

Orders open with the status filter and the after-sale filter the server understands. Pull to refresh. A row opens a read-only summary of the fields in that list. There is no extra detail call hiding behind it.

Merchant-hosted projects are a separate list from personal projects. The first page is what the server returns. If the server says there are more rows than the page holds, the screen says the list is partial. It does not invent a next page.

Store tools that the workbench can open, when the permission exists, include the store profile, storefront, gallery, brand story, hosting settings, the store character, voice and portrait resources, the city-location catalog, and the shop's own interaction templates. Saving those pages stays off until that write is turned on. A preview is not a published storefront. The gallery holds up to nine images. A new interaction template starts with no completion method selected. You choose one. The private template is not the public template page.

Hosting settings can record capacity and whether a charge is free or paid, as the values 0 and 1. An unknown charge stays unknown. Missing does not mean free.

## Hosting a stop or an activity

Signing up to host a stop is not the same as winning it. The line on that form is: signing up is not winning the stop; it counts once the organizer confirms you. You choose a place, a date range, the space and on-site conditions, and at least one venue photo, up to nine. Photos are 5:3 landscape when you can shoot them that way.

You cannot change that registration after the topic has started, after it was approved, or after the status changed under you. Go back to the detail and read the latest result.

An activity whose host is the merchant cannot charge a ticket price yet. The check says collection is not open, so the price can only be 0. Do not enter a paid price on that form.

A non-merchant publisher who sells a paid ticket must already have publisher identity registered. The activity wizard asks for that before review.

## Orders, refunds, and what this page leaves out

Order status and after-sale status are the codes the server sends. An unknown code stays a number. It is not given a new name here.

After-sale detail can show the refund number, the activity, the amount when it is known, and the policy snapshot on the order. A merchant opinion is not itself a refund. Platform steps appear only after the server has recorded them. The app does not invent an arrival time.

Customer-service handoff for a refund uses the support placeholder above. This page does not name a person or a chat id.

This guide does not cover bank-card withdrawal. It does not cover virtual goods. Payout records, when the app can read them, are history. They are not a new transfer form.

## When a screen will not move

- Choosing the merchant entry never grants `access`. Open the workbench only after a status read says the account is effective, and expect that screen to check access again.
- Pending, rejected, awaiting activation, effective, and disabled are not interchangeable. Do not keep a disabled account's old rejection text.
- If submit stays busy or says the outcome is unknown, do not confirm again. Read status.
- An employee with finance access does not see the owner's pending-work list. An owner without the finance read does not see revenue.
- Uploads, redemption, and storefront publication stay on the screen that is actually enabled. A grey control means that write is off.

## Where this comes from

Application and status: `docs/merchant-onboarding.md`. Workbench, orders, and hosted projects: `docs/merchant-module.md`. Store tools: `docs/merchant-operations-module.md`. Home entry and settings row: `docs/parity/w2-02.md`, `docs/alignment/xcx-ios-B-20261019.md`. Merchant-hosted ticket price: `docs/worker-reports/W4-core-loop.md`. Stop registration copy: `docs/parity/w2-07-localizations.json`.
