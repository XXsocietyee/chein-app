# Player-content MP contracts

Mini-program source: public `liboyang42-cpu/hengyin` `chengyinhub-xcx` at `25eb6a0c1fbae79f124f109e19f7b7f97fd06aaf`.

The coverage table on `origin/cursor/mp-contract-coverage` (`569fca241951`) counts `request(` only. Topic, template, activity browse, catalog, and search send `sendRequest(`. Those calls are the missing rows for this slice. Core wire shapes live in `PlayerContentMPContract`. Pinning tests are `PlayerContentMPContractTests`.

`POST` with no header is `application/x-www-form-urlencoded;` (trailing semicolon, as `utils/transport/request-client.js` sets it). `POST` with a JSON header is `application/json` in page key order. `GET` puts `data` on the query.

Money rows build no request. `PlayerContentMPContract.moneyEnabled` and `pricingGrantEnabled` are false. `PublisherLifecycleGrants.dormant.pricing` stays nil.

## Pinned

| MP file:line | method | path | fields | Core symbol | test |
|---|---|---|---|---|---|
| `pages/topic/index/index.js:517` | `GET` | `api/marketing/product/list` | topicId, limit | `PlayerContentMPContract.productList` | `testProductListPinsTopicIdAndLimit` |
| `pages/topic/index/index.js:584` | `POST` | `api/topic/like_list` | pageNum, pageSize | `PlayerContentMPContract.likeList` | `testLikeListPinsPageNumAndPageSize` |
| `pages/topic/index/index.js:607` | `GET` | `api/marketing/product/list` | limit | `PlayerContentMPContract.productList` | `testProductListPinsLimitOnly` |
| `pages/topic/index/index.js:628` | `POST` | `api/topic/like` | id, type | `PlayerContentMPContract.like` | `testTopicLikePinsIdAndTypeAndGrantStaysOff` |
| `pages/topic/index/index.js:666` | `GET` | `api/free-explore/bundle/catalog` | topicId | `PlayerContentMPContract.exploreCatalog` | `testExploreCatalogPinsTopicId` |
| `pages/topic/index/index.js:680` | `GET` | `api/play/setup` | topicId | `PlayerContentMPContract.playSetup` | `testPlaySetupPinsTopicId` |
| `pages/topic/index/index.js:727` | `POST` | `api/orient/safety/check` | topicId | `PlayerContentMPContract.safetyCheck` | `testSafetyCheckPinsTopicId` |
| `pages/topic/index/index.js:823` | `POST` | `api/registration/quote` | ownerType, ownerId | `PlayerContentMPContract.registrationQuote` | `testRegistrationQuoteStaysUnsent` |
| `pages/topic/index/index.js:834` | `GET` | `api/marketing/product/list` | limit | `PlayerContentMPContract.productList` | `testProductListPinsLimitOnly` |
| `pages/topic/index/index.js:1147` | `POST` | `api/comment/add` | owner_type, owner_id, rating, contents, reply_id, img_arr | `PlayerContentMPContract.commentAdd` | `testCommentAddPinsOwnerRatingContentsReplyAndImages` |
| `pages/topic/index/index.js:1251` | `POST` | `api/topic/beta/graduate` | topicId | `PlayerContentMPContract.betaGraduate` | `testBetaGraduatePinsTopicId` |
| `pages/topic/index/index.js:1315` | `POST` | `api/topic/transfer-to-club` | topicId, clubId | `PlayerContentMPContract.transferToClub` | `testTransferToClubPinsTopicIdAndClubId` |
| `pages/topic/index/index.js:1367` | `POST` | `api/registration/create` | ownerType, ownerId, realName, phone, isUsePoint, requestId, quoteSign, sourceClubId, sourceChannelCode | `PlayerContentMPContract.registrationCreate` | `testRegistrationCreateStaysUnsent` |
| `pages/topic/index/index.js:1625` | `POST` | `api/user/address/list` | (none) | `PlayerContentMPContract.addressList` | `testAddressListPinsEmptyPost` |
| `pages/topic/index/index.js:1694` | `POST` | `api/user/address/action` | fullName, mobilePhone, isDefault, requestId | `PlayerContentMPContract.addressAction` | `testAddressActionPinsNamePhoneDefaultAndRequestId` |
| `pages/topic/components/cy/chapter-node-form/index.js:392` | `GET` | `api/fe/reference-settlement/note` | chapterId | `PlayerContentMPContract.referenceSettlementNote` | `testReferenceSettlementNotePinsChapterId` |
| `pages/topic/merchantinfo/host-layers.js:312` | `POST` | `api/topic/recruit-slot-qrcode` | id, chapterId, scope | `PlayerContentMPContract.recruitSlotQrcode` | `testRecruitSlotQrcodePinsIdChapterAndScope` |
| `pages/topic/merchantinfo/merchantinfo.js:1543` | `GET` | `api/coop/offer/display-terms` | offerId | `PlayerContentMPContract.displayTermsRead` | `testDisplayTermsReadPinsOfferId` |
| `pages/topic/merchantinfo/merchantinfo.js:1577` | `POST` | `api/coop/offer/display-terms` | offerId, included, extraSpendText, reserveRequired, dailyCapacity, validStart, soldOutRuleText, storefrontImg | `PlayerContentMPContract.displayTermsWrite` | `testDisplayTermsWritePinsOfferFields` |
| `pages/topic/merchantinfo/merchantinfo.js:1725` | `POST` | `api/merchant/chapter-application/offer/remove` | offerId, reason, scope | `PlayerContentMPContract.offerRemove` | `testOfferRemovePinsOfferReasonAndScope` |
| `pages/topic/pricing/index.js:125` | `POST` | `api/topic/pricing/preview` | topicId, subType, scope, leadCost, teamSize | `PlayerContentMPContract.pricingPreview` | `testPricingPreviewPinsTopicSubtypeScopeAndGuidedCost` |
| `pages/topic/pricing/index.js:331` | `GET` | `api/topic/pricing/sale-status` | topicId, scope | `PlayerContentMPContract.saleStatus` | `testSaleStatusPinsTopicIdAndScope` |
| `pages/topic/pricing/index.js:351` | `GET` | `api/topic/pricing/settlement-pending` | scope, topicId | `PlayerContentMPContract.settlementPending` | `testSettlementPendingPinsScopeAndTopicId` |
| `pages/topic/pricing/index.js:440` | `POST` | `api/topic/pricing/confirm` | topicId, scope, guidedPrice, ticketPrices, leadCost, teamSize, selfPrice | `PlayerContentMPContract.pricingConfirm` | `testPricingConfirmStaysOff` |
| `pages/topic/pricing/partner/index.js:150` | `POST` | `api/topic/pricing/preview` | topicId, subType, scope, leadCost, teamSize | `PlayerContentMPContract.pricingPreview` | `testPricingPreviewPinsTopicSubtypeScopeAndGuidedCost` |
| `pages/topic/pricing/partner/index.js:205` | `POST` | `api/club/detail` | id | `PlayerContentMPContract.clubDetail` | `testClubDetailPinsId` |
| `pages/topic/pricing/partner/index.js:205` | `POST` | `api/merchant/public-detail` | id | `PlayerContentMPContract.merchantPublicDetail` | `testMerchantPublicDetailPinsId` |
| `pages/templatedetail/shelf/index.js:183` | `POST` | `api/template/topic-template/list` | (none) | `PlayerContentMPContract.topicTemplateList` | `testTopicTemplateListPinsEmptyPost` |
| `pages/templatedetail/shelf/index.js:225` | `POST` | `api/template/list` | pageNum, pageSize, pack_type | `PlayerContentMPContract.templateList` | `testTemplateListPinsPagePackType` |
| `pages/templatedetail/topic-preview/index.js:106` | `POST` | `api/template/topic-template/info` | id | `PlayerContentMPContract.topicTemplateInfo` | `testTopicTemplateInfoPinsId` |
| `pages/templatedetail/topic-detail/index.js:147` | `POST` | `api/template/topic-template/info` | id | `PlayerContentMPContract.topicTemplateInfo` | `testTopicTemplateInfoPinsId` |
| `pages/templatedetail/templatedetail.js:331` | `POST` | `api/template/info` | id, scope | `PlayerContentMPContract.templateInfo` | `testTemplateInfoPinsIdAndScope` |
| `pages/templatedetail/templatedetail.js:331` | `POST` | `api/template/myinfo` | id, scope | `PlayerContentMPContract.templateMyInfo` | `testTemplateMyInfoPinsIdAndScope` |
| `pages/templatedetail/utils/topic-use-flow.js:43` | `POST` | `api/template/topic-template/use` | id, scope, bindingIntent, sourceContentRevisionId, requestId | `PlayerContentMPContract.topicTemplateUse` | `testTopicTemplateUsePinsIdScopeIntentRevisionAndRequestId` |
| `pages/activity/list/index.js:162` | `GET` | `api/official/can-publish` | (none) | `PlayerContentMPContract.officialCanPublish` | `testOfficialCanPublishPinsGet` |
| `pages/activity/list/index.js:195` | `GET` | `api/official/events` | (none) | `PlayerContentMPContract.officialEvents` | `testOfficialEventsPinsGet` |
| `pages/activity/list/index.js:241` | `GET` | `api/official/my-events` | (none) | `PlayerContentMPContract.officialMyEvents` | `testOfficialMyEventsPinsGet` |
| `pages/search2/index.js:441` | `POST` | `api/category/list` | type, parentid | `PlayerContentMPContract.categoryList` | `testCategoryListPinsTypeAndParentId` |
| `pages/search2/result/index.js:198` | `POST` | `api/topic/list` | keyword, pageNum, pageSize, category_id | `PlayerContentMPContract.searchTopicList` | `testSearchTopicListPinsKeywordPageAndCategory` |
| `pages/search2/result/index.js:198` | `POST` | `api/activity/list` | is_my, keyword, pageNum, pageSize, category_id | `PlayerContentMPContract.searchActivityList` | `testSearchActivityListPinsMineKeywordPageAndCategory` |
| `pages/search2/result/index.js:198` | `POST` | `api/club/list` | name, categoryId | `PlayerContentMPContract.searchClubList` | `testSearchClubListPinsNameAndCategoryId` |
| `pages/search2/result/index.js:198` | `POST` | `api/merchant/list` | name, categoryId | `PlayerContentMPContract.searchMerchantList` | `testSearchMerchantListPinsNameAndCategoryId` |
| `pages/search2/result/index.js:198` | `POST` | `api/template/topic-template/list` | (none) | `PlayerContentMPContract.topicTemplateList` | `testTopicTemplateListPinsEmptyPost` |
| `pages/search2/result/index.js:198` | `POST` | `api/template/list` | keyword, category_id | `PlayerContentMPContract.searchGameTemplates` | `testSearchGameTemplatesPinsKeywordAndCategory` |
| `pages/searchmap/index.js:576` | `GET` | `api/city/nodes` | lat, lng, radius, keyword, categoryId, tag, cityRole | `PlayerContentMPContract.cityNodes` | `testCityNodesPinsLatLngRadiusKeywordCategoryTagAndRole` |

Search lanes at `pages/search2/result/index.js:198` forward `utils/discover-search.js` `buildRequests` (`219`–`224`). Topic list does not send `is_my`. Activity list sends `is_my` first. Club and merchant bodies are JSON. `category_id` / `categoryId` are sent when a category is selected; the pinning tests include them.

`pages/topic/index/index.js:1367` may also send `quoteSign`, `sourceClubId`, and `sourceChannelCode` (`utils/ticket-source.js` `attributionPayload`). The create contract lists those fields and does not send.

`pages/topic/pricing/partner/index.js:205` chooses `api/club/detail` or `api/merchant/public-detail`. Both are `POST` JSON `{id}`.

## Catalog page

`pages/topic/catalog/index.js` has no API call. It redirects `?id=` to the topic page, otherwise home. The catalog read is `GET api/free-explore/bundle/catalog`.

## Not API rows

These `request(` rows are in the coverage remainder and are not HTTP calls. No path was invented.

| MP file:line | what it is |
|---|---|
| `pages/topic/index/index.js:1557` | `subscribe.request` |
| `pages/topic/utils/voice-enrollment-journal.js:18` | predicate named `request` |
| `pages/topic/utils/voice-enrollment-journal.js:20` | predicate named `request` |
| `pages/topic/utils/voice-enrollment-journal.js:76` | predicate named `request` |
| `pages/topic/utils/voice-enrollment-journal.js:100` | predicate named `request` |
| `pages/topic/index/index.js:13` | `recordsRequest(url, method, data, header)`; the URL is a parameter |

## Not this slice

Play-run, roam, journey, advanced start, and refund-apply stay with M6. The 16 pins on `cursor/mp-contract-coverage` were not copied. Activity registration (`pages/activity/baoming`) is not activity browse. Merchant-workbench `sendRequest` rows that already have a Core symbol were not re-pinned, except the five calls whose path had no Core literal (`reference-settlement/note`, `recruit-slot-qrcode`, `display-terms` read and write, `offer/remove`).
