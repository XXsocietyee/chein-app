import XCTest
@testable import QuestifyCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Chapter 24 fixtures for P2, P3, P6, P8, and P9. Responses stay in this test target.
final class PWaveSecondWaveTests: XCTestCase {
    private let emDash = "—"

    func testLaterOrderAndUnknownNumbersUseAnEmDash() {
        XCTAssertEqual(PWaveFeature.laterDisplayOrder, [.affiliateCenter, .themeCollection, .cityPass, .runMemory, .memberBoard])
        XCTAssertEqual(PWaveFeature.displayOrder, [.battleReport, .inviteLanding, .playMode, .ticketSeats])
        XCTAssertEqual(PWaveNumberFact.parse(.string("UNKNOWN")).displayText, emDash)
        XCTAssertEqual(PWaveNumberFact.parse(.null).displayText, emDash)
        XCTAssertEqual(PWaveNumberFact.parse(.string("0")).displayText, emDash)
        XCTAssertEqual(PWaveNumberFact.parse(.integer(0)).displayText, "0")
        XCTAssertNotEqual(PWaveNumberFact.parse(.string("UNKNOWN")).displayText, "0")
    }

    func testAffiliateStaysHiddenWithoutACapabilityAndDoesNotBecomeAnEmptyZero() {
        let absent = PWaveAffiliateCenter.decode(data: envelope(#"""
        {"credentials":[],"campaigns":[],"allocations":[],"held":{"amountFen":0},"payout":{"available":false}}
        """#, capability: nil), status: 200, supported: ["affiliate.summary"])
        XCTAssertTrue(absent.hidden)
        XCTAssertNil(absent.phase)
        XCTAssertNotEqual(absent.phase, .empty)

        let nullList = PWaveAffiliateCenter.decode(data: envelope(#"""
        {"credentials":[],"campaigns":[],"allocations":[],"held":{"amountFen":null},"payout":{"available":false}}
        """#, capability: "null"), status: 200, supported: ["affiliate.summary"])
        XCTAssertTrue(nullList.hidden)
        XCTAssertNil(nullList.phase)

        let emptyList = PWaveAffiliateCenter.decode(data: envelope(#"""
        {"credentials":[],"campaigns":[],"allocations":[],"held":{"amountFen":null},"payout":{"available":false}}
        """#, capability: "empty"), status: 200, supported: ["affiliate.summary"])
        XCTAssertTrue(emptyList.hidden)
        XCTAssertEqual(emptyList.serverCapabilitiesDeclared, Optional(true))
        XCTAssertNil(emptyList.phase)
    }

    func testAffiliateNullHeldAndFalsePayoutAreNotAWithdrawableBalance() throws {
        let presented = PWaveAffiliateCenter.decode(data: envelope(#"""
        {"requiredCapabilities":["affiliate.summary"],"credentials":[{"token":"secret-token","phone":"15500001111"}],
         "campaigns":[],"allocations":[{"amountFen":100},{"amountFen":50,"status":"paid"}],
         "held":{"amountFen":null},"payout":{"available":false}}
        """#, capability: nil), status: 200, supported: ["affiliate.summary"])
        guard case .ready(let fact)? = presented.phase else { return XCTFail("expected ready") }
        XCTAssertFalse(presented.hidden)
        XCTAssertEqual(fact.credentialCount, 1)
        XCTAssertEqual(fact.allocationCount, 2)
        XCTAssertTrue(fact.heldAmountNull)
        XCTAssertEqual(fact.heldAmountText, emDash)
        XCTAssertNotEqual(fact.heldAmountText, "0")
        XCTAssertFalse(fact.withdrawShown)
        XCTAssertFalse(fact.showsArrived)
        XCTAssertFalse(fact.usesMerchantWithdraw)
        XCTAssertFalse(fact.issuesLinkOnRead)
        XCTAssertFalse(fact.storesPlaintextToken)
        XCTAssertFalse(fact.sumsCurrencies)
        XCTAssertFalse(fact.mergedAwayPartialReversals)
        XCTAssertFalse(fact.campaignRefundSummaryCoversEveryPartialRefund)
        XCTAssertFalse(strings(in: fact).contains("secret-token"))
        XCTAssertFalse(strings(in: fact).contains("15500001111"))
        XCTAssertFalse(strings(in: fact).contains("150"))
        let quoted = try readyAffiliate(#"""
        {"credentials":[{}],"campaigns":[],"allocations":[],"held":{"amountFen":"0"},"payout":{"available":"true"}}
        """#)
        XCTAssertEqual(quoted.heldAmountText, emDash)
        XCTAssertNil(quoted.payoutAvailable)
        XCTAssertFalse(quoted.withdrawShown)
    }

    func testMultipleCurrenciesStayUnsummedAndALiteralAmountCanWithdraw() throws {
        let mixed = try readyAffiliate(#"""
        {"credentials":[{}],"campaigns":[],"allocations":[{"amountFen":200}],
         "held":{"amountFen":100,"currency":"CNY"},"amountUnavailableReason":"MULTIPLE_CURRENCIES","payout":{"available":true}}
        """#)
        XCTAssertTrue(mixed.multipleCurrencies)
        XCTAssertNil(mixed.currency)
        XCTAssertEqual(mixed.heldAmountText, "多币种暂不合计")
        XCTAssertNil(mixed.heldAmountFen.literal)
        XCTAssertFalse(mixed.withdrawShown)
        XCTAssertFalse(mixed.sumsCurrencies)
        XCTAssertFalse(strings(in: mixed).contains("100"))
        XCTAssertFalse(strings(in: mixed).contains("300"))
        let payable = try readyAffiliate(#"""
        {"credentials":[{}],"campaigns":[],"allocations":[],"held":{"amountFen":80,"currency":"CNY"},"payout":{"available":true}}
        """#)
        XCTAssertEqual(payable.heldAmountText, "80")
        XCTAssertTrue(payable.withdrawShown)
        XCTAssertEqual(payable.currency, "CNY")
        let none = PWaveAffiliateCenter.decode(data: envelope(#"""
        {"credentials":[],"campaigns":[],"allocations":[],"held":{"amountFen":null},"payout":{"available":false}}
        """#), status: 200, supported: ["affiliate.summary"])
        XCTAssertEqual(none.phase, .some(.empty))
        XCTAssertEqual(PWaveAffiliateSummaryFact.emptyRecordsCopy, "暂无可核实记录")
    }

    func testThemeCollectionHidesWithoutCapabilityAndDoesNotPadOrInventProof() throws {
        let hidden = PWaveThemeCollection.decode(data: envelope("[]", capability: nil), status: 200, supported: ["public.catalog"])
        XCTAssertTrue(hidden.hidden)
        XCTAssertNil(hidden.phase)
        XCTAssertNotEqual(hidden.phase, .empty)
        let card = try readyCatalog(#"""
        {"id":"9","name":"江岸","cityCode":"SHA","chapterNames":["序"],"priceState":"UNKNOWN","priceFrom":0,
         "groupEligible":null,"schoolEligible":null,"answer":"secret-ending","saleState":"LISTED",
         "requestedLocale":"en","actualLocale":"zh-CN","rating":5,"finishCount":0}
        """#)
        XCTAssertEqual(card.cards.count, 1)
        XCTAssertEqual(card.cards[0].sampleCountText, "1")
        XCTAssertFalse(card.cards[0].samplesPadded)
        XCTAssertEqual(card.cards[0].priceText, emDash)
        XCTAssertNotEqual(card.cards[0].priceText, "0")
        XCTAssertNil(card.cards[0].groupEligible)
        XCTAssertNil(card.cards[0].schoolEligible)
        XCTAssertFalse(card.cards[0].presentsAsDoesNotHost)
        XCTAssertFalse(card.cards[0].fieldVerified)
        XCTAssertFalse(card.cards[0].arrivalReminderSucceeded)
        XCTAssertTrue(card.cards[0].socialProofHidden)
        XCTAssertEqual(card.cards[0].primaryTargetID, "9")
        XCTAssertFalse(card.cards[0].opensEmptySignup)
        XCTAssertEqual(card.cards[0].localeFellBack, Optional(true))
        XCTAssertFalse(card.leaksPaidBody)
        XCTAssertFalse(card.insertsDelistedSamples)
        XCTAssertFalse(strings(in: card).contains("secret-ending"))
        XCTAssertFalse(strings(in: card).contains("5"))
        let city = try readyCatalog(#"[{"cityCode":"SHA"}]"#)
        XCTAssertNil(city.cities[0].cityName)
        XCTAssertEqual(city.cities[0].cityCode, "SHA")
        XCTAssertTrue(city.cards.isEmpty)
        let realEmpty = PWaveThemeCollection.decode(data: envelope("[]", capability: "public.catalog"), status: 200, supported: ["public.catalog"])
        XCTAssertEqual(realEmpty.phase, .some(.empty))
        XCTAssertFalse(realEmpty.hidden)
    }

    func testCityPassKeepsUnknownPriceAsAnEmDashAndDoesNotSell() throws {
        let hidden = PWaveCityPass.decode(data: envelope("[]", capability: nil), status: 200,
                                          supported: ["marketing.product"], frozenSnapshot: false)
        XCTAssertTrue(hidden.hidden)
        XCTAssertNil(hidden.phase)
        let unknown = try readyProduct(#"""
        {"purchase_kind":2,"explore_capacity":0,"price":0,"priceState":"UNKNOWN","seat_count":null,"validDays":"30"}
        """#, frozen: false)
        XCTAssertEqual(unknown.products[0].catalogPriceText, emDash)
        XCTAssertNotEqual(unknown.products[0].catalogPriceText, "0")
        XCTAssertEqual(unknown.products[0].seatCountText, emDash)
        XCTAssertEqual(unknown.products[0].validDaysText, emDash)
        XCTAssertFalse(unknown.products[0].saleDecidedFromTier)
        XCTAssertEqual(unknown.products[0].dealPriceText, emDash)
        XCTAssertFalse(unknown.products[0].purchaseShown)
        XCTAssertFalse(unknown.products[0].trialOffered)
        XCTAssertFalse(unknown.products[0].autoRenewOffered)
        XCTAssertFalse(unknown.products[0].describesFixedTermAsAutoRenew)
        XCTAssertFalse(unknown.products[0].paymentEqualsActivation)
        XCTAssertFalse(unknown.products[0].pricedLocally)
        XCTAssertFalse(unknown.products[0].hardcodesUsedNonRefundable)
        XCTAssertFalse(unknown.products[0].adoptsLaterCatalog)
        XCTAssertFalse(unknown.purchaseShown)
        let listed = try readyProduct(#"""
        {"purchase_kind":2,"price":0,"priceState":"ON_SALE","seat_count":2,"coveredTopics":["9"],"validDays":30}
        """#, frozen: true)
        XCTAssertEqual(listed.products[0].catalogPriceText, "0")
        XCTAssertEqual(listed.products[0].seatCountText, "2")
        XCTAssertEqual(listed.products[0].coveredTopicCountText, "1")
        XCTAssertTrue(listed.products[0].frozenSnapshot)
        XCTAssertFalse(listed.products[0].purchaseShown)
        XCTAssertEqual(listed.dealPriceText, emDash)
        let noCoverage = try readyProduct(#"{"price":12,"priceState":"ON_SALE"}"#, frozen: false)
        XCTAssertEqual(noCoverage.products[0].coveredTopicCountText, emDash)
        XCTAssertNotEqual(noCoverage.products[0].coveredTopicCountText, "0")
    }

    func testMemoryHidesOtherPhotosAndDoesNotTurnUnknownIntoZero() throws {
        let hidden = PWaveRunMemory.decode(data: envelope(#"""
        {"moments":[],"participantCount":0}
        """#, capability: nil), status: 200, supported: ["play.memory"])
        XCTAssertTrue(hidden.hidden)
        XCTAssertNil(hidden.phase)
        let fact = try readyMemory(#"""
        {"moments":[{"url":"https://secret.example/a.jpg","phone":"15500003333"}],"participantCount":"UNKNOWN",
         "photoShareCapability":"NO_PRIVATE_PHOTO_SHARE_CONSENT_FACT","identityPolicy":"PRIVATE"}
        """#)
        XCTAssertEqual(fact.momentCount, 1)
        XCTAssertEqual(fact.momentCountText, "1")
        XCTAssertEqual(fact.participantText, emDash)
        XCTAssertFalse(fact.noCompanions)
        XCTAssertTrue(fact.consentFactAbsent)
        XCTAssertFalse(fact.otherPrivatePhotosVisible)
        XCTAssertFalse(fact.createsFriendRelation)
        XCTAssertFalse(fact.mixesAccountAlbum)
        XCTAssertFalse(fact.publicSharePerformed)
        XCTAssertFalse(strings(in: fact).contains("https://secret.example/a.jpg"))
        XCTAssertFalse(strings(in: fact).contains("15500003333"))
        let alone = try readyMemory(#"{"participantCount":0}"#)
        XCTAssertEqual(alone.participantText, "0")
        XCTAssertTrue(alone.noCompanions)
        XCTAssertEqual(alone.momentCountText, emDash)
        XCTAssertNotEqual(alone.momentCountText, "0")
        XCTAssertTrue(alone.showsNoPhotoAssociation)
        XCTAssertTrue(alone.consentFactAbsent)
        XCTAssertFalse(alone.otherPrivatePhotosVisible)
        XCTAssertEqual(PWaveRunMemoryFact.noPhotoAssociationCopy, "暂无照片")
    }

    func testHistoryKeepsSessionIdsAndDoesNotFillCurrentContent() throws {
        let presented = PWaveRunMemory.decodeHistory(data: envelope(#"""
        [{"sessionId":"run-9"},{"sessionId":"UNKNOWN"}]
        """#, capability: "play.memory"), status: 200, supported: ["play.memory"])
        guard case .unknown? = presented.phase else { return XCTFail("a bad session id is unknown, not a substituted run") }
        XCTAssertFalse(presented.hidden)
        let history = PWaveRunMemory.decodeHistory(data: envelope(#"[{"sessionId":"run-9"}]"#, capability: "play.memory"), status: 200, supported: ["play.memory"])
        guard case .ready(let fact)? = history.phase else { return XCTFail("expected history") }
        XCTAssertEqual(fact.sessionIDs, ["run-9"])
        XCTAssertFalse(fact.fillsCurrentContent)
        XCTAssertFalse(fact.opensAnotherRunOnMismatch)
    }

    func testQuestRankStaysHiddenUntilTheCompletedNodeBasisAndUnknownIsAnEmDash() throws {
        let wrong = PWaveBoards.decodeQuest(data: envelope(#"""
        {"scope":"quest","period":"all","scoreBasis":"NET","rank":0}
        """#, capability: "rank.board"), status: 200, supported: ["rank.board"])
        XCTAssertTrue(wrong.hidden)
        XCTAssertNil(wrong.phase)
        let missing = PWaveBoards.decodeQuest(data: envelope(#"""
        {"scope":"quest","period":"all","scoreBasis":"COMPLETED_NODES","rank":1}
        """#, capability: nil), status: 200, supported: ["rank.board"])
        XCTAssertTrue(missing.hidden)
        XCTAssertNil(missing.phase)
        let board = try readyQuest(#"""
        {"scope":"quest","period":"all","scoreBasis":"COMPLETED_NODES","periodStart":"2026-11-02","periodEnd":"2026-11-09",
         "coverage":{"unattributedRuns":null,"attributionBasis":"FROZEN"},"rank":"UNKNOWN","me":true}
        """#)
        XCTAssertTrue(board.matchesQuestBasis)
        XCTAssertEqual(board.label, "完成节点数")
        XCTAssertEqual(board.rows.count, 1)
        XCTAssertEqual(board.rows[0].rankText, emDash)
        XCTAssertTrue(board.rows[0].unranked)
        XCTAssertFalse(board.rows[0].assignedFromIndex)
        XCTAssertEqual(board.rows[0].mine, Optional(true))
        XCTAssertEqual(board.unattributedRunsText, emDash)
        XCTAssertFalse(board.netScoreBoard)
        XCTAssertFalse(board.friendBoardShown)
        XCTAssertFalse(board.filledGeographyFromDevice)
        let rows = PWaveBoards.decodeQuest(data: rootEnvelope(#"""
        [{"rank":2,"mine":false},{"rank":null,"mine":true}]
        """#, extra: #""scope":"quest","period":"all","scoreBasis":"COMPLETED_NODES""#), status: 200, supported: ["rank.board"])
        guard case .ready(let list)? = rows.phase else { return XCTFail("expected rows") }
        XCTAssertEqual(list.rows.map(\.rankText), ["2", emDash])
        XCTAssertFalse(list.rows[0].assignedFromIndex)
        let empty = PWaveBoards.decodeQuest(data: rootEnvelope("[]", extra: #""scope":"quest","period":"all","scoreBasis":"COMPLETED_NODES""#),
                                            status: 200, supported: ["rank.board"])
        XCTAssertEqual(empty.phase, .some(.empty))
        XCTAssertFalse(empty.hidden)
    }

    func testTeamBoardIsNotMemberRankAndStaysHiddenWhenTheSwitchIsOff() throws {
        let off = PWaveBoards.decodeTeams(data: rootEnvelope(#"""
        [{"teamId":"3","rank":1,"teamDoneCount":4,"title":"甲"}]
        """#, extra: #""orient.team.board.enabled":false"#), status: 200, supported: ["rank.board"])
        XCTAssertTrue(off.hidden)
        XCTAssertNil(off.phase)
        let presented = PWaveBoards.decodeTeams(data: rootEnvelope(#"""
        [{"teamId":"3","rank":null,"teamDoneCount":4,"title":"甲","activeCount":"UNKNOWN","totalTasks":9,"mine":true}]
        """#, extra: #""orient.team.board.enabled":true"#), status: 200, supported: ["rank.board"])
        guard case .ready(let board)? = presented.phase else { return XCTFail("expected teams") }
        XCTAssertTrue(board.boardEnabled)
        XCTAssertFalse(board.memberRankShown)
        XCTAssertEqual(board.rows[0].rankText, emDash)
        XCTAssertEqual(board.rows[0].teamDoneCountText, "4")
        XCTAssertEqual(board.rows[0].activeCount.displayText, emDash)
        XCTAssertFalse(board.rows[0].isMemberRank)
        XCTAssertFalse(board.rows[0].teamDoneCountIsPerMember)
    }

    func testMemberRankStaysHiddenUntilTheServerSendsIt() {
        let unimplemented = PWaveBoards.decodeMembers(data: envelope(#"""
        {"memberRankBasis":"COMPLETED_TASK_COUNT","orient.team.board.enabled":true,"members":[{"doneTaskIds":[1,2,3]}]}
        """#, capability: "rank.board"), status: 200, supported: ["rank.board"])
        XCTAssertTrue(unimplemented.hidden)
        XCTAssertNil(unimplemented.phase)
        let switchedOff = PWaveBoards.decodeMembers(data: envelope(#"""
        {"memberRankBasis":"COMPLETED_TASK_COUNT","orient.team.board.enabled":false,
         "members":[{"doneTaskCount":2,"rank":1,"ranked":true,"mine":true}]}
        """#, capability: "rank.board"), status: 200, supported: ["rank.board"])
        XCTAssertTrue(switchedOff.hidden)
        XCTAssertNil(switchedOff.phase)
        let presented = PWaveBoards.decodeMembers(data: envelope(#"""
        {"memberRankBasis":"COMPLETED_TASK_COUNT","orient.team.board.enabled":true,
         "members":[{"doneTaskIds":[1],"doneTaskCount":null,"rank":"UNKNOWN","ranked":true,"mine":false}]}
        """#, capability: "rank.board"), status: 200, supported: ["rank.board"])
        guard case .ready(let fact)? = presented.phase else { return XCTFail("expected members") }
        XCTAssertTrue(fact.available)
        XCTAssertFalse(fact.friendBoardShown)
        XCTAssertEqual(fact.rows[0].rankText, emDash)
        XCTAssertEqual(fact.rows[0].doneTaskCountText, emDash)
        XCTAssertNotEqual(fact.rows[0].rankText, "1")
        XCTAssertFalse(fact.rows[0].promotedToFirst)
        XCTAssertTrue(fact.rows[0].ranked)
    }

    func testReaderHidesTheLaterWaveUntilTheGrantAndSendsNothing() async throws {
        let wire = Wire()
        let reader = try makeReader(wire, granted: [])
        let scope = try PWaveSessionScope(accountID: 7, epoch: 1, namespace: "cn")
        let affiliate = try await reader.affiliateSummary(token: "session-token", scope: scope, currentScope: { scope })
        let catalog = try await reader.themeCatalog(.list, fields: ["city_code": "SHA"], token: nil, scope: scope, currentScope: { scope })
        let products = try await reader.products(city: "SHA", token: "session-token", scope: scope, currentScope: { scope })
        let memory = try await reader.runMemory(topicID: "9", token: "session-token", scope: scope, currentScope: { scope })
        let quest = try await reader.questBoard(scopeID: "9", token: "session-token", scope: scope, currentScope: { scope })
        let teams = try await reader.teamRanking(ownerType: 1, ownerID: "4", token: "session-token", scope: scope, currentScope: { scope })
        let members = try await reader.teamDetail(teamID: "4", token: "session-token", scope: scope, currentScope: { scope })
        XCTAssertTrue(affiliate.hidden && catalog.hidden && products.hidden && memory.hidden)
        XCTAssertTrue(quest.hidden && teams.hidden && members.hidden)
        XCTAssertNil(affiliate.phase)
        XCTAssertNil(catalog.phase)
        XCTAssertNil(products.phase)
        XCTAssertNil(memory.phase)
        XCTAssertNil(quest.phase)
        XCTAssertNil(teams.phase)
        XCTAssertNil(members.phase)
        XCTAssertTrue(wire.requests.isEmpty)
    }

    func testReaderUsesTheNamedReadsAndRefusesWrites() async throws {
        let wire = Wire(body: envelope(#"""
        {"credentials":[{}],"campaigns":[],"allocations":[],"held":{"amountFen":null},"payout":{"available":false}}
        """#))
        let reader = try makeReader(wire, granted: [.affiliateCenter, .themeCollection, .cityPass, .runMemory, .memberBoard],
                                   supported: ["affiliate.summary", "public.catalog", "marketing.product", "play.memory", "rank.board"])
        let scope = try PWaveSessionScope(accountID: 7, epoch: 1, namespace: "cn")
        let affiliate = try await reader.affiliateSummary(token: "session-token", scope: scope, currentScope: { scope })
        guard case .ready(let summary)? = affiliate.phase else { return XCTFail("expected a ready affiliate summary") }
        XCTAssertEqual(summary.credentialCount, 1)
        XCTAssertEqual(summary.campaignCount, 0)
        XCTAssertEqual(summary.allocationCount, 0)
        XCTAssertNil(summary.heldAmountFen.literal)
        XCTAssertTrue(summary.heldAmountNull)
        XCTAssertEqual(summary.payoutAvailable, false)
        XCTAssertFalse(summary.withdrawShown)
        XCTAssertEqual(wire.requests[0].httpMethod, "GET")
        XCTAssertEqual(wire.requests[0].url?.path, "/api/marketing/affiliate/summary")
        XCTAssertTrue(wire.requests[0].url?.query?.contains("limit=20") == true)
        XCTAssertEqual(wire.requests[0].value(forHTTPHeaderField: "Authorization"), "session-token")

        wire.body = envelope(#"{"id":"9","name":"江岸","chapterNames":["序"]}"#, capability: "public.catalog")
        let catalog = try await reader.themeCatalog(.info, fields: ["id": "9", "locale": "zh-CN"], token: nil,
                                                    scope: scope, currentScope: { scope })
        guard case .ready(let theme)? = catalog.phase else { return XCTFail("expected catalog") }
        XCTAssertEqual(theme.cards[0].sampleCountText, "1")
        let catalogRequest = try XCTUnwrap(wire.requests[1])
        XCTAssertEqual(catalogRequest.httpMethod, "POST")
        XCTAssertEqual(catalogRequest.url?.path, "/api/public-catalog/info")
        XCTAssertEqual(catalogRequest.value(forHTTPHeaderField: "Content-Type"), "application/x-www-form-urlencoded; charset=utf-8")
        XCTAssertNil(catalogRequest.value(forHTTPHeaderField: "Authorization"))
        let catalogBody = String(decoding: try XCTUnwrap(catalogRequest.httpBody), as: UTF8.self)
        XCTAssertEqual(catalogBody, "id=9&locale=zh-CN")
        XCTAssertFalse(catalogBody.contains("{"))

        wire.body = envelope(#"{"purchase_kind":2,"price":15,"priceState":"ON_SALE"}"#, capability: "marketing.product")
        let products = try await reader.products(city: "SHA", kind: "pass", token: "session-token", scope: scope, currentScope: { scope })
        guard case .ready(let pass)? = products.phase else { return XCTFail("expected product") }
        XCTAssertFalse(pass.purchaseShown)
        XCTAssertEqual(pass.dealPriceText, emDash)
        XCTAssertEqual(wire.requests[2].url?.path, "/api/marketing/product/list")
        XCTAssertTrue(wire.requests[2].url?.query?.contains("limit=20") == true)
        XCTAssertTrue(wire.requests[2].url?.query?.contains("city=SHA") == true)
        XCTAssertTrue(wire.requests[2].url?.query?.contains("kind=pass") == true)

        wire.body = envelope(#"[{"purchase_kind":2,"price":15,"priceState":"ON_SALE","contentRevision":{"id":"rev"}}]"#,
                             capability: "marketing.product")
        let orders = try await reader.productOrders(token: "session-token", scope: scope, currentScope: { scope })
        guard case .ready(let frozen)? = orders.phase else { return XCTFail("expected orders") }
        XCTAssertTrue(frozen.products[0].frozenSnapshot)
        XCTAssertTrue(frozen.products[0].contentRevisionPresent)
        XCTAssertFalse(frozen.products[0].adoptsLaterCatalog)
        XCTAssertEqual(wire.requests[3].url?.path, "/api/marketing/product/orders")

        wire.body = envelope(#"""
        {"moments":[],"participantCount":1,"photoShareCapability":"PRIVATE"}
        """#, capability: "play.memory")
        let memory = try await reader.runMemory(topicID: "9", runID: "run-9", token: "session-token", scope: scope, currentScope: { scope })
        guard case .ready(let run)? = memory.phase else { return XCTFail("expected memory") }
        XCTAssertFalse(run.otherPrivatePhotosVisible)
        XCTAssertEqual(wire.requests[4].url?.path, "/api/play/player-journey/memory")
        XCTAssertTrue(wire.requests[4].url?.query?.contains("topicId=9") == true)
        XCTAssertTrue(wire.requests[4].url?.query?.contains("runId=run-9") == true)

        wire.body = rootEnvelope(#"""
        [{"rank":1,"mine":true}]
        """#, capability: "rank.board", extra: #""scope":"quest","period":"all","scoreBasis":"COMPLETED_NODES""#)
        let quest = try await reader.questBoard(scopeID: "9", token: "session-token", scope: scope, currentScope: { scope })
        guard case .ready(let rank)? = quest.phase else { return XCTFail("expected quest") }
        XCTAssertEqual(rank.rows[0].rankText, "1")
        XCTAssertFalse(rank.rows[0].assignedFromIndex)
        XCTAssertEqual(wire.requests[5].url?.path, "/api/rank/list")
        XCTAssertTrue(wire.requests[5].url?.query?.contains("scope=quest") == true)
        XCTAssertTrue(wire.requests[5].url?.query?.contains("period=all") == true)
        XCTAssertTrue(wire.requests[5].url?.query?.contains("scopeId=9") == true)
        XCTAssertFalse(wire.requests[5].url?.query?.contains("scope=world") == true)

        wire.onSend = {}
        XCTAssertThrowsError(try reader.issueAffiliateLink(targetType: 1, targetID: "9", requestID: "req-1", token: "session-token")) {
            XCTAssertEqual($0 as? PWaveRefusal, .writesNotAvailable)
        }
        XCTAssertThrowsError(try reader.remindWhenAvailable(id: "9", token: "session-token"))
        XCTAssertThrowsError(try reader.quoteProduct(requestID: "req-1", token: "session-token"))
        XCTAssertThrowsError(try reader.orderProduct(requestID: "req-1", token: "session-token"))
        XCTAssertThrowsError(try reader.payProduct(orderNo: "o-1", requestID: "req-1", token: "session-token"))
        XCTAssertThrowsError(try reader.activateProduct(orderNo: "o-1", topicID: "9", token: "session-token"))
        XCTAssertThrowsError(try reader.claimProductGift(credential: "gift", requestID: "req-1", token: "session-token"))
        XCTAssertThrowsError(try reader.publishMemory(runID: "run-9", requestID: "req-1", token: "session-token"))
        XCTAssertEqual(wire.requests.count, 6)
    }

    func testAStaleAccountDropsTheLaterReadAndAFailedReadIsNotZero() async throws {
        let wire = Wire(body: envelope(#"""
        {"credentials":[{}],"campaigns":[],"allocations":[],"held":{"amountFen":40},"payout":{"available":true}}
        """#))
        var current = try PWaveSessionScope(accountID: 7, epoch: 1, namespace: "cn")
        let reader = try makeReader(wire, granted: [.affiliateCenter], supported: ["affiliate.summary"])
        wire.onSend = { current = try! PWaveSessionScope(accountID: 8, epoch: 2, namespace: "cn") }
        let stale = try await reader.affiliateSummary(token: "session-token",
                                                      scope: try PWaveSessionScope(accountID: 7, epoch: 1, namespace: "cn"),
                                                      currentScope: { current })
        XCTAssertNil(stale.phase)
        XCTAssertTrue(stale.hidden)
        wire.onSend = {}
        wire.status = 500
        wire.body = Data("nope".utf8)
        let failed = try await reader.affiliateSummary(token: "session-token",
                                                       scope: try PWaveSessionScope(accountID: 8, epoch: 2, namespace: "cn"),
                                                       currentScope: { current })
        guard case .error? = failed.phase else { return XCTFail("expected error") }
        XCTAssertNotEqual(failed.phase, .empty)
        XCTAssertFalse(failed.hidden)
    }

    func testCatalogCardKeepsNamedFieldsAndDropsANonStringSample() throws {
        let card = try readyCatalog(#"""
        {"id":"9","name":"江岸","chapterNames":["序",1],"canonicalPath":"/t/9","subtitle":"夜","summary":"短",
         "imgUrl":"/a.png","productType":"CITY","priceUnit":"起","priceFrom":12,"priceState":"ON_SALE",
         "groupEligible":false,"schoolEligible":true,"translationState":"MACHINE","revision":{"state":"DRAFT"},
         "requestedLocale":"zh-CN"}
        """#)
        let row = card.cards[0]
        XCTAssertNil(row.chapterNames)
        XCTAssertEqual(row.sampleCountText, emDash)
        XCTAssertNotEqual(row.sampleCountText, "0")
        XCTAssertFalse(row.samplesPadded)
        XCTAssertEqual(row.canonicalPath, "/t/9")
        XCTAssertEqual(row.subtitle, "夜")
        XCTAssertEqual(row.summary, "短")
        XCTAssertEqual(row.imageURL, "/a.png")
        XCTAssertEqual(row.productType, "CITY")
        XCTAssertEqual(row.priceUnit, "起")
        XCTAssertEqual(row.priceText, "12")
        XCTAssertEqual(row.translationState, "MACHINE")
        XCTAssertEqual(row.revisionState, "DRAFT")
        XCTAssertTrue(row.groupEligibilityDeclared)
        XCTAssertEqual(row.groupEligible, Optional(false))
        XCTAssertFalse(row.presentsAsDoesNotHost)
        XCTAssertTrue(row.schoolEligibilityDeclared)
        XCTAssertNil(row.localeFellBack)
        let two = try readyCatalog(#"{"id":"1","chapterNames":["序","二"]}"#)
        XCTAssertEqual(two.cards[0].sampleCountText, "2")
        XCTAssertFalse(two.cards[0].samplesPadded)
        XCTAssertNotEqual(two.cards[0].sampleCountText, "3")
        let scalar = PWaveThemeCollection.decode(data: envelope("\"nope\"", capability: "public.catalog"), status: 200, supported: ["public.catalog"])
        XCTAssertEqual(scalar.phase, .some(.unknown))
        XCTAssertNotEqual(scalar.phase, .empty)
    }

    func testCatalogPathsAndThemeHistoryUseNamedReads() async throws {
        let wire = Wire()
        let reader = try makeReader(wire, granted: [.themeCollection, .runMemory, .memberBoard],
                                   supported: ["public.catalog", "play.memory", "rank.board"])
        let scope = try PWaveSessionScope(accountID: 7, epoch: 1, namespace: "cn")
        wire.body = envelope(#"[{"cityCode":"SHA","cityName":"上海"}]"#, capability: "public.catalog")
        let cities = try await reader.themeCatalog(.cityList, fields: [:], token: "session-token", scope: scope, currentScope: { scope })
        guard case .ready(let cityFact)? = cities.phase else { return XCTFail("expected cities") }
        XCTAssertEqual(cityFact.cities[0].cityName, "上海")
        XCTAssertEqual(wire.requests[0].httpMethod, "POST")
        XCTAssertEqual(wire.requests[0].url?.path, "/api/public-catalog/city/list")
        XCTAssertEqual(wire.requests[0].value(forHTTPHeaderField: "Authorization"), "session-token")
        XCTAssertEqual(String(decoding: wire.requests[0].httpBody ?? Data(), as: UTF8.self), "")

        wire.body = envelope("[]", capability: "public.catalog")
        let paths: [(PWaveCatalogPath, String)] = [(.map, "/api/public-catalog/map"), (.filters, "/api/public-catalog/filters"), (.list, "/api/public-catalog/list")]
        for (path, expected) in paths {
            _ = try await reader.themeCatalog(path, fields: ["city_code": "SHA"], token: nil, scope: scope, currentScope: { scope })
            XCTAssertEqual(wire.requests.last?.url?.path, expected)
        }

        wire.body = envelope(#"{"id":"9","name":"江岸"}"#, capability: "public.catalog")
        let ids = try await reader.themeCatalog(.ids, fields: ["ids": "9", "keyword": "a b"], token: nil, scope: scope, currentScope: { scope })
        guard case .ready(let listed)? = ids.phase else { return XCTFail("expected ids") }
        XCTAssertEqual(listed.cards[0].primaryTargetID, "9")
        XCTAssertEqual(wire.requests.last?.url?.path, "/api/public-catalog/ids")
        XCTAssertEqual(String(decoding: wire.requests.last?.httpBody ?? Data(), as: UTF8.self), "ids=9&keyword=a%20b")
        let sentBeforeReject = wire.requests.count
        do {
            _ = try await reader.themeCatalog(.ids, fields: ["city_code": "SHA"], token: nil, scope: scope, currentScope: { scope })
            XCTFail("ids needs ids")
        } catch PWaveRefusal.invalidRequest {}
        XCTAssertEqual(wire.requests.count, sentBeforeReject)

        wire.body = envelope(#"[{"sessionId":"run-9"}]"#, capability: "play.memory")
        let history = try await reader.themeHistory(topicID: "9", beforeSessionID: "run-8", limit: 5, token: "session-token", scope: scope, currentScope: { scope })
        guard case .ready(let sessions)? = history.phase else { return XCTFail("expected history") }
        XCTAssertEqual(sessions.sessionIDs, ["run-9"])
        XCTAssertFalse(sessions.fillsCurrentContent)
        let historyURL = try XCTUnwrap(wire.requests.last?.url)
        XCTAssertEqual(historyURL.path, "/api/play/theme/history")
        XCTAssertTrue(historyURL.query?.contains("topicId=9") == true)
        XCTAssertTrue(historyURL.query?.contains("beforeSessionId=run-8") == true)
        XCTAssertTrue(historyURL.query?.contains("limit=5") == true)
        let sent = wire.requests.count
        do {
            _ = try await reader.themeHistory(topicID: "9", limit: 0, token: "session-token", scope: scope, currentScope: { scope })
            XCTFail("limit")
        } catch PWaveRefusal.invalidRequest {}
        do {
            _ = try await reader.themeHistory(topicID: "", token: "session-token", scope: scope, currentScope: { scope })
            XCTFail("topic")
        } catch PWaveRefusal.invalidRequest {}
        do {
            _ = try await reader.questBoard(scopeID: "9", limit: 0, token: "session-token", scope: scope, currentScope: { scope })
            XCTFail("quest limit")
        } catch PWaveRefusal.invalidRequest {}
        do {
            _ = try await reader.teamRanking(ownerType: 3, ownerID: "4", token: "session-token", scope: scope, currentScope: { scope })
            XCTFail("owner")
        } catch PWaveRefusal.invalidRequest {}
        XCTAssertEqual(wire.requests.count, sent)
    }

    func testCityPassKeepsTheTermAndABadProductIdSendsNothing() async throws {
        let term = try readyProduct(#"""
        {"purchase_kind":1,"explore_capacity":0,"validityKind":2,"validDays":30,"fixedValidFrom":"2026-11-01","fixedValidTo":"2027-11-01","seat_count":1,"coveredTopics":["9",8],"price":12,"priceState":"ON_SALE","refundPolicy":"UNUSED_ONLY"}
        """#, frozen: false)
        let product = term.products[0]
        XCTAssertEqual(product.exploreCapacity.literal, 0)
        XCTAssertEqual(product.validityKind.literal, 2)
        XCTAssertEqual(product.validDays.literal, 30)
        XCTAssertEqual(product.fixedValidFrom, "2026-11-01")
        XCTAssertEqual(product.fixedValidTo, "2027-11-01")
        XCTAssertEqual(product.refundPolicy, "UNUSED_ONLY")
        XCTAssertEqual(product.coveredTopicCountText, "2")
        XCTAssertEqual(product.catalogPriceText, "12")
        XCTAssertFalse(product.frozenSnapshot)
        XCTAssertFalse(product.purchaseShown)
        let objectTopics = try readyProduct(#"{"price":1,"priceState":"ON_SALE","coveredTopics":{"id":"9"}}"#, frozen: false)
        XCTAssertEqual(objectTopics.products[0].coveredTopicCountText, emDash)
        XCTAssertNotEqual(objectTopics.products[0].coveredTopicCountText, "0")
        let scalar = PWaveCityPass.decode(data: envelope("\"nope\"", capability: "marketing.product"), status: 200,
                                          supported: ["marketing.product"], frozenSnapshot: false)
        XCTAssertEqual(scalar.phase, .some(.unknown))

        let wire = Wire()
        let reader = try makeReader(wire, granted: [.cityPass], supported: ["marketing.product"])
        let scope = try PWaveSessionScope(accountID: 7, epoch: 1, namespace: "cn")
        do {
            _ = try await reader.product(id: "../9", token: "session-token", scope: scope, currentScope: { scope })
            XCTFail("path")
        } catch PWaveRefusal.invalidRequest {}
        do {
            _ = try await reader.product(id: "9/1", token: "session-token", scope: scope, currentScope: { scope })
            XCTFail("slash")
        } catch PWaveRefusal.invalidRequest {}
        do {
            _ = try await reader.products(city: "", token: "session-token", scope: scope, currentScope: { scope })
            XCTFail("city")
        } catch PWaveRefusal.invalidRequest {}
        XCTAssertTrue(wire.requests.isEmpty)
        wire.body = envelope(#"{"price":15,"priceState":"ON_SALE","contentRevision":{"id":"rev"}}"#, capability: "marketing.product")
        let one = try await reader.product(id: "9", token: "session-token", scope: scope, currentScope: { scope })
        guard case .ready(let pass)? = one.phase else { return XCTFail("expected product") }
        XCTAssertFalse(pass.products[0].frozenSnapshot)
        XCTAssertTrue(pass.products[0].contentRevisionPresent)
        XCTAssertEqual(wire.requests[0].url?.path, "/api/marketing/product/9")
        XCTAssertEqual(wire.requests[0].httpMethod, "GET")
        XCTAssertNil(wire.requests[0].httpBody)
    }

    func testAffiliateCountTextAndUnknownCurrencyDoNotInventATotal() throws {
        let fact = try readyAffiliate(#"""
        {"credentials":[{},{}],"allocations":[{}],"held":{"amountFen":1,"currency":"UNKNOWN"},"currency":"CNY","payout":{"available":true}}
        """#)
        XCTAssertEqual(fact.credentialCountText, "2")
        XCTAssertEqual(fact.campaignCountText, emDash)
        XCTAssertNotEqual(fact.campaignCountText, "0")
        XCTAssertNil(fact.campaignCount)
        XCTAssertEqual(fact.allocationCountText, "1")
        XCTAssertEqual(fact.currency, "CNY")
        XCTAssertEqual(fact.heldAmountText, "1")
        XCTAssertTrue(fact.withdrawShown)
        let unknown = try readyAffiliate(#"""
        {"credentials":[],"campaigns":[{}],"allocations":[],"held":{"amountFen":1,"currency":"UNKNOWN"},"currency":"UNKNOWN","payout":{"available":true}}
        """#)
        XCTAssertNil(unknown.currency)
        XCTAssertEqual(unknown.heldAmountText, "1")
        XCTAssertTrue(unknown.withdrawShown)
        XCTAssertFalse(unknown.multipleCurrencies)
        XCTAssertEqual(unknown.credentialCountText, "0")
    }

    func testMemoryZeroAndPrivateShareStayClosed() throws {
        let none = try readyMemory(#"{"moments":[],"participantCount":1,"photoShareCapability":"PRIVATE"}"#)
        XCTAssertEqual(none.momentCount, 0)
        XCTAssertEqual(none.momentCountText, "0")
        XCTAssertTrue(none.showsNoPhotoAssociation)
        XCTAssertFalse(none.consentFactAbsent)
        XCTAssertFalse(none.otherPrivatePhotosVisible)
        XCTAssertEqual(none.photoShareCapability, "PRIVATE")
        let walked = Data(#"{"code":200,"msg":"NO_PRIVATE_PHOTO_SHARE_CONSENT_FACT","requiredCapabilities":["play.memory"],"data":{"participantCount":1,"photoShareCapability":"PRIVATE"}}"#.utf8)
        let presented = PWaveRunMemory.decode(data: walked, status: 200, supported: ["play.memory"])
        guard case .ready(let fact)? = presented.phase else { return XCTFail("expected memory") }
        XCTAssertTrue(fact.consentFactAbsent)
        XCTAssertFalse(fact.otherPrivatePhotosVisible)
    }

    func testHistoryEmptyIsEmptyAndAnIntegerSessionIdIsKept() {
        let empty = PWaveRunMemory.decodeHistory(data: envelope("[]", capability: "play.memory"), status: 200, supported: ["play.memory"])
        XCTAssertEqual(empty.phase, .some(.empty))
        XCTAssertFalse(empty.hidden)
        let presented = PWaveRunMemory.decodeHistory(data: envelope(#"[{"sessionId":7}]"#, capability: "play.memory"), status: 200, supported: ["play.memory"])
        guard case .ready(let fact)? = presented.phase else { return XCTFail("expected history") }
        XCTAssertEqual(fact.sessionIDs, ["7"])
        XCTAssertFalse(fact.fillsCurrentContent)
        let object = PWaveRunMemory.decodeHistory(data: envelope(#"{"sessionId":"run-9"}"#, capability: "play.memory"), status: 200, supported: ["play.memory"])
        guard case .unknown? = object.phase else { return XCTFail("a single object is not a history list") }
    }

    func testCatalogRejectsAnUnknownFieldBeforeSending() async throws {
        let wire = Wire()
        let reader = try makeReader(wire, granted: [.themeCollection])
        let scope = try PWaveSessionScope(accountID: 7, epoch: 1, namespace: "cn")
        do {
            _ = try await reader.themeCatalog(.list, fields: ["rating": "5"], token: nil, scope: scope, currentScope: { scope })
            XCTFail("unknown field")
        } catch PWaveRefusal.invalidRequest {}
        do {
            _ = try await reader.themeCatalog(.info, fields: ["locale": "zh-CN"], token: nil, scope: scope, currentScope: { scope })
            XCTFail("info needs id")
        } catch PWaveRefusal.invalidRequest {}
        XCTAssertTrue(wire.requests.isEmpty)
    }

    private func readyAffiliate(_ data: String) throws -> PWaveAffiliateSummaryFact {
        let presented = PWaveAffiliateCenter.decode(data: envelope(data), status: 200, supported: ["affiliate.summary"])
        guard case .ready(let fact)? = presented.phase else { throw TestFailure() }
        return fact
    }

    private func readyCatalog(_ data: String) throws -> PWaveThemeCollectionFact {
        let presented = PWaveThemeCollection.decode(data: envelope(data, capability: "public.catalog"), status: 200, supported: ["public.catalog"])
        guard case .ready(let fact)? = presented.phase else { throw TestFailure() }
        return fact
    }

    private func readyProduct(_ data: String, frozen: Bool) throws -> PWaveCityPassFact {
        let presented = PWaveCityPass.decode(data: envelope(data, capability: "marketing.product"), status: 200,
                                            supported: ["marketing.product"], frozenSnapshot: frozen)
        guard case .ready(let fact)? = presented.phase else { throw TestFailure() }
        return fact
    }

    private func readyMemory(_ data: String) throws -> PWaveRunMemoryFact {
        let presented = PWaveRunMemory.decode(data: envelope(data, capability: "play.memory"), status: 200, supported: ["play.memory"])
        guard case .ready(let fact)? = presented.phase else { throw TestFailure() }
        return fact
    }

    private func readyQuest(_ data: String) throws -> PWaveQuestBoardFact {
        let presented = PWaveBoards.decodeQuest(data: envelope(data, capability: "rank.board"), status: 200, supported: ["rank.board"])
        guard case .ready(let fact)? = presented.phase else { throw TestFailure() }
        return fact
    }

    private func envelope(_ data: String, capability: String? = "affiliate.summary") -> Data {
        switch capability {
        case nil:
            return Data(#"{"code":200,"msg":"ok","data":\#(data)}"#.utf8)
        case "null":
            return Data(#"{"code":200,"msg":"ok","requiredCapabilities":null,"data":\#(data)}"#.utf8)
        case "empty":
            return Data(#"{"code":200,"msg":"ok","requiredCapabilities":[],"data":\#(data)}"#.utf8)
        case let name?:
            return Data(#"{"code":200,"msg":"ok","requiredCapabilities":["\#(name)"],"data":\#(data)}"#.utf8)
        }
    }

    private func rootEnvelope(_ data: String, capability: String = "rank.board", extra: String) -> Data {
        Data(#"{"code":200,"msg":"ok","requiredCapabilities":["\#(capability)"],\#(extra),"data":\#(data)}"#.utf8)
    }

    private func makeReader(_ wire: Wire, granted: Set<PWaveFeature>, supported: Set<String> = [],
                            url: String = "https://example.test") throws -> PWaveReader {
        try PWaveReader(configuration: APIConfiguration(baseURL: URL(string: url)!), transport: wire,
                        endpointClass: .nonProduction,
                        capabilities: PWaveCapability(granted: granted, supportedServerCapabilities: supported))
    }

    private func strings(in value: Any, depth: Int = 0) -> [String] {
        if depth > 8 { return [] }
        if let text = value as? String { return [text] }
        return Mirror(reflecting: value).children.flatMap { strings(in: $0.value, depth: depth + 1) }
    }

    private struct TestFailure: Error {}

    private final class Wire: HTTPTransport, @unchecked Sendable {
        var requests: [URLRequest] = []
        var body: Data
        var status: Int
        var onSend: () -> Void = {}
        init(body: Data = Data(), status: Int = 200) {
            self.body = body
            self.status = status
        }
        func send(_ request: URLRequest) async throws -> (Data, Int) {
            requests.append(request)
            onSend()
            return (body, status)
        }
    }
}
