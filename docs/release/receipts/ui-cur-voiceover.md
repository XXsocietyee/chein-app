# ui/cur-voiceover

VoiceOver only, on the 14 page-template screens that already exist on `ui/h-design-v1` at `5d652cc08ac5ccc668db315fc57253b909b9e058`. That commit already contains `origin/ui/main` at `5ba7b0f2c5f10dea10905895da947c350b3e24ac`. `ui/main` was not merged again. The cur-t restyle branches were not merged. `ui/h-design-v1` was not moved.

Each control that this pass touches has a label from existing copy, a hint only when that label does not already say the action, and a trait. Reading order follows the mini-program section order from public `hengyin` `chengyinhub-xcx`. A grouped card is one VoiceOver element. Sheet and footer focus order is the visual order. Data bindings and layout are unchanged. An em dash stays on screen and is spoken as Unknown / 未知 through the existing `curA11y.unknown` string.

`App/RegionalLaunchConfiguration.swift`, `App/AppSession.swift`, and `App/AppCompositionRoot.swift` are unchanged. `ReviewedAreaSwitch` was not redeclared. `OwnerDecisionFixtureHost` was not re-added. The contract baseline was not edited. No `CYRadius.card`. No `allTagGroups`.

This VM has no `swiftc`. Nothing here is a typecheck, a compile, or a VoiceOver render.

## Screen count

13 of the 14 first-route screens are on this branch and were labeled. 1 is not on this branch and was not invented.

## Screens

1. `pages/index/index` — `HomeFeedView`, `HomeTodayCard`, `HomeSearchTabParityViews`. Unlabeled: feed cards (name, price, time, and place were separate), the today card, the continuation card, the search entry, and the map button. Labels: the card's own name plus `homeFeed.status.price`, `playx.finishRoute.priceFrom` or spoken Unknown, `homeFeed.status.time`, the date or `homeFeed.openEnded`, and `homeFeed.place`; today uses its eyebrow, title, meta, and pill; continuation uses its existing title and subtitle; search uses `searchMap.placeholder.player` with hint `homeFeed.search` and keeps `.isSearchField`; map uses the existing map title with hint `searchMap.citySearch`. Traits: button, or static text when the today card has no action. Reading order: banner, greeting, consent, recommended, nearby, upcoming, feed tabs, then the native today, pass, and continuation blocks.

2. `pages/template/index` — `DiscoveryTemplateBrowserView`. Unlabeled: the publish control, the search field, the search button, filter chips, and topic and game cards. Labels: `discovery.templateTab.publish`, the field prompt, `discovery.searchAction`, the chip title (`discovery.recommended`, `discovery.allPacks`, or the category or pack name already on the chip), `discovery.untitledTopic` or the topic name and subtitle, `discovery.untitledPlay` or the game title and description. Traits: button, plus selected on the active chip. Reading order: staff note, shelf picker, shelf, then the gameplay preset.

3. `pages/search2/index` — `GlobalSearchView`. Unlabeled: the filter tile, the map pill, and the more-ways menu (their text was inside the control without an explicit label and trait). Labels: `searchMap.filters`, `searchMap.citySearch`, `searchMap.moreWays`. Trait: button.

4. `pages/topic/index/index` — `TopicDetailView` and `TopicXcxSections`. Unlabeled: the confirm-price, sessions, and sign-up actions in the footer. Labels: `topicXcx.cta.confirmPrice`, `topicXcx.cta.sessions`, `topicXcx.cta.signUp`. The self-play button already speaks `topicXcx.cta.selfPlay` or `topicXcx.cta.selfPlayNoPrice` and now has the button trait. Trait: button. Footer order: sessions, then the primary action, matching the row.

5. `pages/activity/baoming/baoming` — `RegistrationSheetView`. Unlabeled: the total, which showed an em dash with no spoken form, and the review button when a block reason was present. Labels: the existing total text, with an em dash spoken as Unknown; `registration.form.review`. Hint: the existing block reason, only when the review is blocked. Trait: button. Order: total, then review.

6. `pages/play/index` — `PlayExperienceView`. Unlabeled: the pause and start or resume controls (the label text was inside the button without an explicit trait). Labels: `playx.run.pause`, `playx.run.start`, `playx.run.resume`. Trait: button. The clock updates as it changes.

7. `pages/member/index/index` — `MemberIdentityCardSection` in `MemberHomeHeader`, hosted by `AccountView`. Unlabeled: level, city, balance, and stat values that render an em dash, the ticket control, and decorative symbols. Labels: the existing value, with an em dash spoken as Unknown; tickets use `member.card.tickets`. Trait: button on tickets. Symbols are hidden.

8. `pages/activity/list/index` — `OfficialEventsBrowserView`. Unlabeled: filter chips (selected state only) and the event row as one control. Labels: the chip's existing tab title. The event row combines the card that is already on screen. Traits: button, plus selected on the active chip.

9. `subpackageB/pages/im/list/index` — `MessagingHomeView`. Unlabeled: the scope picker (its labels were hidden), channel and day headers, and conversation rows. Labels: `messaging.scope` on the picker; headers use the title already in the row; conversation rows keep their existing row text. Traits: header, button.

10. `pages/address/address` — `ProfileParticipantsView`. Unlabeled: the participant row as one control, the phone em dash, and the edit and delete buttons. Labels: the row's name, spoken phone, and `profile.participants.rowPurpose`; edit uses `participant.list.editShort`; delete uses `participant.form.delete`. Traits: button. An em dash phone is spoken as Unknown.

11. `pages/publish/fabu/index` — not on this branch. Fragments exist (`TopicCreatorToolsView`, `TopicTemplateUseSection`, `ProjectEditChapterRulesSection`). No fabu screen was added.

12. `pages/merchant/index/index` — `MerchantHomeView`. Unlabeled: the inactive identity block, open-application, and refresh. Labels: the merchant name and `merchant.access.inactive` (or the application title key already bound); `merchant.onboarding.openApplication`; `merchant.refreshAccess`. Traits: header and static text on the identity block, button on the two actions.

13. `pages/coop/list/index` — `CooperationBrowserView`. Unlabeled: an invite card and the application and registration headers were several elements. Labels: the text already in those rows. Traits: button on an invite; static text on the application and registration headers. Inner links stay separate controls. Covers are hidden.

14. `pages/shezhi/shezhi` — `SettingsView` and `SettingsAccountCard`. Unlabeled: the account card as one control, an empty nickname em dash, and the home-facts status row. Labels: the nickname, spoken as Unknown when it is an em dash, plus `settings.account.subtitle`; home facts use the existing copy key. Traits: button when the card navigates, otherwise static text. The status icon is hidden. Loading facts update as they change.

## Shared chrome

These controls appear on the template screens. Labels are the titles already on the control.

- `CYChromeBars` — back is `action.back` (button). The title is a header. The footer reads in visual order: secondary then primary when they sit side by side, primary then secondary when they stack.
- `CYSheetModal` — sheet title then close (`action.close`, button). Option rows use the option title, or title plus subtitle, with button and selected. Modal cancel then confirm use the titles already passed in, in visual order.
- `CYConfirmSheet` — cancel is `action.cancel`. Confirm uses the title already passed in. Empty consequences put confirm above cancel. A side-by-side row puts cancel then confirm. A stacked fallback puts confirm above cancel.
- `CYMapChrome` — glass and go buttons use the label already passed in. Trait: button.
