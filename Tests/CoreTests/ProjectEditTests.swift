import XCTest
@testable import QuestifyCore

final class ProjectEditTests: XCTestCase {
    func testThemeDateSyncFollowsThemeAndFreezesPayloadWithStoredPreference() throws {
        var draft = ProjectEditSyntheticFixtures.draft(product: .freeExplore)
        var ticket = draft.tickets[0]
        try ticket.setThemeDateSync(true, in: draft); draft.tickets[0] = ticket
        draft.startDate = "2030-06-01"; draft.endDate = "2030-06-30"
        XCTAssertEqual(ticket.schedule(in: draft).start, "2030-06-01 00:00:00")
        XCTAssertEqual(ticket.schedule(in: draft).end, "2030-06-30 23:59:59")
        let payload = try ProjectEditContract.payload(draft, topicID: 71, scope: .full)
        let wire = try XCTUnwrap(payload["tickets"]?.array?.first?.object)
        XCTAssertEqual(wire["startTime"], .string(ticket.schedule(in: draft).start))
        XCTAssertEqual(wire["endTime"], .string(ticket.schedule(in: draft).end))
        XCTAssertEqual(wire["syncWithTheme"], .bool(true))
        draft.endDate = "2030-07-01T18:20"
        XCTAssertEqual(ticket.schedule(in: draft).end, "2030-07-01 18:20:00")
        draft.endDate = "2030-02-30"
        XCTAssertTrue(ProjectEditValidation.issues(draft).contains { $0.id.hasPrefix("ticketDates") })
        XCTAssertThrowsError(try ProjectEditContract.payload(draft, topicID: 71, scope: .full))
    }
    func testUnsyncKeepsVisibleDatesAndRepeatedOffPreservesManualEdits() throws {
        var draft = ProjectEditSyntheticFixtures.draft(product: .freeExplore)
        var ticket = draft.tickets[0]; try ticket.setThemeDateSync(true, in: draft)
        draft.startDate = "2030-06-01"; draft.endDate = "2030-06-30"
        let shown = ticket.schedule(in: draft)
        try ticket.setThemeDateSync(false, in: draft)
        XCTAssertEqual(ticket.schedule(in: draft).start, shown.start)
        XCTAssertEqual(ticket.schedule(in: draft).end, shown.end)
        ticket.startTime = "2030-06-15 09:30"; ticket.endTime = "2030-06-16 18:00"
        draft.startDate = "2031-01-01"; try ticket.setThemeDateSync(false, in: draft)
        XCTAssertEqual(ticket.startTime, "2030-06-15 09:30")
        XCTAssertEqual(ticket.endTime, "2030-06-16 18:00")
        draft.product = .city; ticket.localMetadata["syncWithTheme"] = .bool(true)
        XCTAssertEqual(ticket.schedule(in: draft).start, "2030-06-15 09:30:00")
        XCTAssertThrowsError(try ticket.setThemeDateSync(false, in: draft))
    }
    func testUnknownSyncMetadataAndOldEnvelopeArePreserved() throws {
        let draft = ProjectEditSyntheticFixtures.draft(product: .freeExplore)
        for raw in [ProjectEditJSON.string("true"), .number(1), .object(["future": .bool(true)])] {
            var ticket = draft.tickets[0]; ticket.localMetadata = ["syncWithTheme": raw, "future": .array([.number(7)])]
            let before = ticket
            XCTAssertFalse(ticket.canEditThemeDateSync); XCTAssertFalse(ticket.syncsWithThemeDates)
            XCTAssertThrowsError(try ticket.setThemeDateSync(true, in: draft))
            XCTAssertEqual(ticket, before)
            XCTAssertEqual(try JSONDecoder().decode(ProjectEditTicket.self, from: JSONEncoder().encode(ticket)), before)
            var preservedDraft = draft; preservedDraft.tickets[0] = ticket
            let wire = try ProjectEditContract.payload(preservedDraft, topicID: 71, scope: .full)["tickets"]?.array?.first?.object
            XCTAssertEqual(wire?["syncWithTheme"], raw)
        }
        var old = draft.tickets[0]; old.localMetadata = [:]
        let decoded = try JSONDecoder().decode(ProjectEditTicket.self, from: JSONEncoder().encode(old))
        XCTAssertTrue(decoded.canEditThemeDateSync); XCTAssertFalse(decoded.syncsWithThemeDates)
        XCTAssertNil(decoded.localMetadata["syncWithTheme"])
        var synced = old; synced.localMetadata["future"] = .string("retained")
        try synced.setThemeDateSync(true, in: draft)
        let restored = try JSONDecoder().decode(ProjectEditTicket.self, from: JSONEncoder().encode(synced))
        XCTAssertTrue(restored.syncsWithThemeDates); XCTAssertEqual(restored.localMetadata["future"], .string("retained"))
    }
    func testAuthoritativeTicketReadbackDoesNotInventSyncAndWhitelistOmitsIt() throws {
        var draft = try ProjectEditContract.decodeEditDetail(projectTicketIdentityFixture(), expectedTopicID: 71, owner: .merchant).draft
        XCTAssertFalse(draft.tickets[0].syncsWithThemeDates)
        XCTAssertNil(draft.tickets[0].localMetadata["syncWithTheme"])
        draft.product = .freeExplore; draft.recruitDeadline = "2030-04-20"
        var ticket = draft.tickets[0]; try ticket.setThemeDateSync(true, in: draft); draft.tickets[0] = ticket
        XCTAssertNil(try ProjectEditContract.payload(draft, topicID: 71, scope: .whitelist)["tickets"])
        // A fresh authoritative read keeps server dates; matching dates never imply sync.
        let readback = try ProjectEditContract.decodeEditDetail(projectTicketIdentityFixture(), expectedTopicID: 71, owner: .merchant)
        XCTAssertFalse(readback.draft.tickets[0].syncsWithThemeDates)
        XCTAssertEqual(readback.draft.tickets[0].startTime, readback.draft.tickets[0].localMetadata["startTime"]?.text)
        var envelope = try XCTUnwrap(JSONSerialization.jsonObject(with: projectTicketIdentityFixture()) as? [String: Any])
        var body = try XCTUnwrap(envelope["data"] as? [String: Any])
        var rows = try XCTUnwrap(body["tickets"] as? [[String: Any]])
        rows[0]["syncWithTheme"] = true; rows[0]["futureSyncOption"] = ["opaque": 7]
        body["tickets"] = rows; envelope["data"] = body
        let synced = try ProjectEditContract.decodeEditDetail(JSONSerialization.data(withJSONObject: envelope), expectedTopicID: 71, owner: .merchant).draft
        XCTAssertTrue(synced.tickets[0].syncsWithThemeDates)
        XCTAssertEqual(synced.tickets[0].localMetadata["futureSyncOption"], .object(["opaque": .number(7)]))
        let wire = try ProjectEditContract.payload(synced, topicID: 71, scope: .full)["tickets"]?.array?.first?.object
        XCTAssertEqual(wire?["syncWithTheme"], .bool(true))
    }
    func testSaleDatesNormalizeOnlyExplicitEditsWithoutDeviceTimeZoneConversion() throws {
        var ticket = ProjectEditTicket()
        ticket.saleStartTime = "2030-04-01"; ticket.saleEndTime = "2030-04-30"
        XCTAssertEqual(try ticket.saleTimePayloads(), ["saleStartTime": .string("2030-04-01 00:00:00"), "saleEndTime": .string("2030-04-30 23:59:59")])
        ticket.saleStartTime = "2030-04-01T09:30"; ticket.saleEndTime = "2030-04-30 18:05:12"
        XCTAssertEqual(try ticket.saleTimePayloads()["saleStartTime"], .string("2030-04-01 09:30:00"))
        XCTAssertEqual(try ticket.saleTimePayloads()["saleEndTime"], .string("2030-04-30 18:05:12"))
        for invalid in ["2030-02-30", "2030-04-01T09:30Z", "2030-04-01T09:30+08:00", "2030-04-01 24:01"] {
            ticket.saleStartTime = invalid; XCTAssertThrowsError(try ticket.saleTimePayloads())
        }
    }
    func testLegacySaleValuesAndUnknownSiblingsSurviveUnrelatedEditsAndCodable() throws {
        var ticket = ProjectEditTicket()
        ticket.saleStartTime = "legacy date"; ticket.saleEndTime = "2030-05-01"
        ticket.localMetadata = ["saleStartTime": .string(ticket.saleStartTime), "saleEndTime": .string(ticket.saleEndTime), "future": .object(["opaque": .bool(true)])]
        ticket.name = "Unrelated edit"
        let restored = try JSONDecoder().decode(ProjectEditTicket.self, from: JSONEncoder().encode(ticket))
        XCTAssertEqual(restored.localMetadata, ticket.localMetadata)
        XCTAssertEqual(try restored.saleTimePayloads()["saleStartTime"], .string("legacy date"))
        XCTAssertEqual(try restored.saleTimePayloads()["saleEndTime"], .string("2030-05-01"))
        ticket.saleStartTime = "2030-04-01"
        XCTAssertEqual(try ticket.saleTimePayloads()["saleStartTime"], .string("2030-04-01 00:00:00"))
        ticket.saleEndTime = ""
        XCTAssertEqual(try ticket.saleTimePayloads()["saleEndTime"], .null)
    }
    func testUnsupportedSaleWireTypeIsPreservedAndCannotBeOverwritten() throws {
        var ticket = ProjectEditTicket(); let opaque = ProjectEditJSON.object(["future": .number(1)])
        ticket.localMetadata["saleStartTime"] = opaque
        XCTAssertFalse(ticket.canEditSaleTime(end: false))
        XCTAssertEqual(try ticket.saleTimePayloads()["saleStartTime"], opaque)
        ticket.saleStartTime = "2030-04-01"
        XCTAssertThrowsError(try ticket.saleTimePayloads())
    }
    func testSaleDatesFullPayloadAndAuthoritativeReadback() throws {
        var draft = try ProjectEditContract.decodeEditDetail(projectTicketIdentityFixture(), expectedTopicID: 71, owner: .merchant).draft
        draft.tickets[0].saleStartTime = "2030-04-01"; draft.tickets[0].saleEndTime = "2030-04-30"
        let payload = try ProjectEditContract.payload(draft, topicID: 71, scope: .full)
        let ticket = try XCTUnwrap(payload["tickets"]?.array?.first?.object)
        XCTAssertEqual(ticket["saleStartTime"], .string("2030-04-01 00:00:00"))
        XCTAssertEqual(ticket["saleEndTime"], .string("2030-04-30 23:59:59"))
        XCTAssertEqual(payload["scope"], .string("MERCHANT"))
        var envelope = try XCTUnwrap(JSONSerialization.jsonObject(with: projectTicketIdentityFixture()) as? [String: Any])
        var body = try XCTUnwrap(envelope["data"] as? [String: Any])
        var tickets = try XCTUnwrap(body["tickets"] as? [[String: Any]])
        tickets[0]["saleStartTime"] = "2030-04-01 00:00:00"; tickets[0]["saleEndTime"] = "2030-04-30 23:59:59"
        body["tickets"] = tickets; envelope["data"] = body
        let readback = try ProjectEditContract.decodeEditDetail(JSONSerialization.data(withJSONObject: envelope), expectedTopicID: 71, owner: .merchant)
        XCTAssertEqual(readback.draft.tickets[0].saleStartTime, "2030-04-01 00:00:00")
        XCTAssertEqual(try readback.draft.tickets[0].saleTimePayloads(), try draft.tickets[0].saleTimePayloads())
    }
    func testSaleDateValidationAndWhitelistRemainScoped() throws {
        var draft = ProjectEditSyntheticFixtures.draft(); let original = draft
        draft.tickets[0].saleStartTime = "not a date"
        XCTAssertTrue(ProjectEditValidation.issues(draft).contains { $0.id.hasPrefix("ticketSaleDates") })
        XCTAssertThrowsError(try ProjectEditContract.payload(draft, topicID: 71, scope: .full))
        XCTAssertFalse(draft.whitelistLockedFieldsEqual(to: original))
        XCTAssertNil(try ProjectEditContract.payload(draft, topicID: 71, scope: .whitelist)["tickets"])
        XCTAssertTrue(try ProjectEditTicket().saleTimePayloads().isEmpty)
    }
    private func session(_ account: Int = 901, epoch: UInt64 = 1, scope: String = "fixture-cn") throws -> ProjectEditSession { try .init(accountID: account, epoch: epoch, storageNamespace: scope) }
    func testMissingAndFreePriceAreDifferent() {
        var d = ProjectEditSyntheticFixtures.draft(); d.tickets[0].price = ""
        XCTAssertTrue(ProjectEditValidation.issues(d).contains { $0.key == "projectEdit.validation.price" })
        d.tickets[0].price = "0"; XCTAssertTrue(ProjectEditValidation.issues(d).isEmpty)
        d.tickets[0].price = "-1"; XCTAssertFalse(ProjectEditValidation.issues(d).isEmpty)
        d.tickets[0].price = "NaN"; XCTAssertFalse(ProjectEditValidation.issues(d).isEmpty)
    }
    func testCityRequiresRealStoryBeforeAddingNode() throws {
        var c = ProjectEditChapter()
        for value in ["", " ", "暂无描述", "暂无", "无"] { c.description = value; XCTAssertThrowsError(try c.addNode(product: .city)) }
        c.description = "A real beginning"; try c.addNode(product: .city); XCTAssertEqual(c.nodes.count, 1)
        c.description = ""; try c.addNode(product: .freeExplore); XCTAssertEqual(c.nodes.count, 2)
    }
    func testCoordinateBoundsAndZeroSentinel() {
        var n = ProjectEditNode()
        for pair in [("0", "1"), ("1", "0"), ("181", "10"), ("1", "91"), ("nan", "2"), ("inf", "2")] {
            n.longitude = pair.0; n.latitude = pair.1; XCTAssertFalse(n.hasUsableCoordinates)
        }
        n.longitude = "-73.8"; n.latitude = "40.5"; XCTAssertTrue(n.hasUsableCoordinates)
    }
    func testStrictDatesDoNotUseDeviceZoneOrAppendTwice() {
        XCTAssertEqual(ProjectEditValidation.dateTime("2030-05-01", endOfDay: true), "2030-05-01 23:59:59")
        XCTAssertEqual(ProjectEditValidation.dateTime("2030-05-01T10:15"), "2030-05-01 10:15:00")
        XCTAssertEqual(ProjectEditValidation.dateTime("2030-05-01 10:15:12", endOfDay: true), "2030-05-01 10:15:12")
        XCTAssertNil(ProjectEditValidation.dateTime("2030-02-30")); XCTAssertNil(ProjectEditValidation.dateTime("2030-05-01T10:15Z"))
    }
    func testCityTicketOrderingAndMeetingPoint() {
        var d = ProjectEditSyntheticFixtures.draft(); d.tickets[0].endTime = d.tickets[0].startTime; d.tickets[0].meetingPoint = ""
        let keys = ProjectEditValidation.issues(d).map(\.key)
        XCTAssertTrue(keys.contains("projectEdit.validation.dateOrder")); XCTAssertTrue(keys.contains("projectEdit.validation.meeting"))
    }
    func testFreeExploreAlwaysRequiresRecruitDeadline() {
        var d = ProjectEditSyntheticFixtures.draft(product: .freeExplore); d.recruitDeadline = ""; d.openMerchantPool = false
        XCTAssertTrue(ProjectEditValidation.issues(d).contains { $0.key == "projectEdit.validation.deadline" })
    }
    func testFullPayloadSourceNormalizationAndOwnerScope() throws {
        var d = ProjectEditSyntheticFixtures.draft(); d.owner = .merchant; d.openMerchantPool = true; d.categoryIDs = [7, 9]
        let p = try ProjectEditContract.payload(d, topicID: nil, scope: .full)
        XCTAssertEqual(p["categoryIds"], .string("7,9")); XCTAssertEqual(p["scope"], .string("MERCHANT"))
        XCTAssertEqual(p["openClubPool"], .number(1)); XCTAssertEqual(p["publishToCreative"], .number(1))
        XCTAssertNil(p["recruitDeadline"])
        XCTAssertEqual(p["tickets"]?.array?.first?.object?["mode"], .number(1))
        XCTAssertEqual(try ProjectEditContract.payload(d, topicID: 1, scope: .full)["publishToCreative"], .number(0))
    }
    func testWhitelistHasOnlySourceFieldsAndID() throws {
        let p = try ProjectEditContract.payload(ProjectEditSyntheticFixtures.draft(), topicID: 71, scope: .whitelist)
        XCTAssertEqual(Set(p.keys), Set(ProjectEditContract.whitelist + ["id"]))
        XCTAssertNil(p["chapters"]); XCTAssertNil(p["tickets"]); XCTAssertNil(p["startDate"])
    }
    func testReplacementCarryOverRetainsContractualChapterFields() throws {
        var d = ProjectEditSyntheticFixtures.draft()
        let values: [String: ProjectEditJSON] = ["categoryId": .number(9), "maxMerchant": .number(2), "perkMinValue": .string("001.20"), "allowedValidationMethods": .string("1,4"), "maxNodeXp": .number(99), "calculatedDistance": .number(Decimal(string: "1.25")!), "imgArr": .string("a,b"), "audioUrl": .string("preserved")]
        d.chapters[0].preserved.merge(values) { _, new in new }
        let p = try ProjectEditContract.payload(d, topicID: 71, scope: .full)["chapters"]?.array?.first?.object
        for (key, value) in values { XCTAssertEqual(p?[key], value) }
    }
    func testStoryBlocksProjectNodeOrderAndSkipEmptyAudio() throws {
        var d = ProjectEditSyntheticFixtures.draft(); var second = d.chapters[0].nodes[0]; second.id = "second"; second.name = "Second"
        let first = d.chapters[0].nodes[0]; d.chapters[0].nodes.append(second)
        d.chapters[0].blocks = [.init(kind: .text, content: "Opening"), .init(kind: .node, nodeID: second.id), .init(kind: .text, content: "Later"), .init(kind: .node, nodeID: first.id), .init(kind: .audio)]
        let c = try XCTUnwrap(ProjectEditContract.payload(d, topicID: nil, scope: .full)["chapters"]?.array?.first?.object)
        XCTAssertEqual(c["description"], .string("Opening")); XCTAssertEqual(c["nodes"]?.array?.first?.object?["name"], .string("Second"))
        XCTAssertEqual(c["blocks"]?.array?.count, 4)
    }
    func testBrokenOrDuplicateReferencesFailClosedRatherThanDiscardStory() {
        var d = ProjectEditSyntheticFixtures.draft()
        d.chapters[0].blocks = [.init(kind: .text, content: "Opening"), .init(kind: .node, nodeID: "missing")]
        XCTAssertThrowsError(try ProjectEditContract.payload(d, topicID: nil, scope: .full))
        let id = d.chapters[0].nodes[0].id
        d.chapters[0].blocks = [.init(kind: .text, content: "Opening"), .init(kind: .node, nodeID: id), .init(kind: .node, nodeID: id)]
        XCTAssertThrowsError(try ProjectEditContract.payload(d, topicID: nil, scope: .full))
    }
    func testRemovingNodeAlsoRemovesItsStoryReference() {
        var c = ProjectEditSyntheticFixtures.draft().chapters[0]; let id = c.nodes[0].id
        c.blocks = [.init(kind: .text, content: "Opening"), .init(kind: .node, nodeID: id)]
        c.removeNode(id: id); XCTAssertTrue(c.nodes.isEmpty); XCTAssertEqual(c.blocks?.count, 1)
    }
    @MainActor func testLocalDraftRoundTripAndRevisionConflict() throws {
        let storage = ProjectEditMemoryStorage(); let store = ProjectEditLocalStore(storage: storage); let s = try session(); let id = try ProjectEditDraftIdentity(topicID: 71)
        var d = ProjectEditSyntheticFixtures.draft(); d.baseRevision = "one"
        try store.save(d, session: s, identity: id)
        guard case .ready(let envelope) = store.load(session: s, identity: id, baseline: d) else { return XCTFail("Expected restore") }
        XCTAssertEqual(envelope.draft, d)
        d.baseRevision = "two"
        guard case .revisionConflict = store.load(session: s, identity: id, baseline: d) else { return XCTFail("Expected revision conflict") }
    }
    @MainActor func testEnvelopeOwnerAndNamespaceAreCheckedBeyondBucketKey() throws {
        let storage = ProjectEditMemoryStorage(); let store = ProjectEditLocalStore(storage: storage); let s = try session(); let id = try ProjectEditDraftIdentity(topicID: 71)
        let d = ProjectEditSyntheticFixtures.draft(); try store.save(d, session: s, identity: id)
        let key = try XCTUnwrap(storage.data.keys.first)
        storage.data[key] = try JSONEncoder().encode(ProjectEditEnvelope(session: session(902), identity: id, draft: d))
        guard case .memberMismatch = store.load(session: s, identity: id, baseline: d) else { return XCTFail("Leaked another account") }
    }
    @MainActor func testActiveDraftPointersSeparateMarketsProductsAndOwnerScopes() throws {
        let store = ProjectEditLocalStore(storage: ProjectEditMemoryStorage()); let s = try session(); let id = try ProjectEditDraftIdentity()
        try store.save(ProjectEditSyntheticFixtures.draft(), session: s, identity: id)
        XCTAssertEqual(try store.activeIdentity(session: s, product: .city, owner: .personal), id)
        XCTAssertNil(try store.activeIdentity(session: session(scope: "fixture-us"), product: .city, owner: .personal))
        XCTAssertNil(try store.activeIdentity(session: s, product: .freeExplore, owner: .personal))
        XCTAssertNil(try store.activeIdentity(session: s, product: .city, owner: .merchant))
    }
    @MainActor func testDisabledServiceAllowsLocalReviewButNoSubmit() async throws {
        let d = ProjectEditSyntheticFixtures.draft(); let s = try session()
        let c = ProjectEditCoordinator(initial: .init(draft: d), service: ProjectEditDisabledService(), store: .init(storage: ProjectEditMemoryStorage()), currentSession: { s })
        await c.load(); c.prepare(d); let review = try XCTUnwrap(c.confirmation); await c.confirm(review)
        XCTAssertFalse(c.canSimulate); XCTAssertEqual(c.messageKey, "projectEdit.unconfigured"); XCTAssertNil(c.pending)
    }
    @MainActor func testConfirmationFreezesPayloadAndCannotBeRepeated() async throws {
        let service = ProjectEditSyntheticService(); let s = try session(); var d = ProjectEditSyntheticFixtures.draft()
        let c = ProjectEditCoordinator(initial: .init(draft: d), service: service, store: .init(storage: ProjectEditMemoryStorage()), currentSession: { s })
        await c.load(); c.prepare(d); let review = try XCTUnwrap(c.confirmation); d.name = "Later edit"
        await c.confirm(review); await c.confirm(review)
        XCTAssertEqual(service.submissions.count, 1); XCTAssertNotEqual(service.submissions[0].payload["name"], .string(d.name)); XCTAssertEqual(c.state, .simulated)
        c.prepare(d); XCTAssertNil(c.confirmation)
    }
    @MainActor func testCancelledReviewNeverSubmits() async throws {
        let service = ProjectEditSyntheticService(); let s = try session(); let d = ProjectEditSyntheticFixtures.draft()
        let c = ProjectEditCoordinator(initial: .init(draft: d), service: service, store: .init(storage: ProjectEditMemoryStorage()), currentSession: { s })
        await c.load(); c.prepare(d); let review = try XCTUnwrap(c.confirmation); c.cancelReview(); await c.confirm(review)
        XCTAssertTrue(service.submissions.isEmpty)
    }
    @MainActor func testChangedSessionInvalidatesOldConfirmation() async throws {
        let service = ProjectEditSyntheticService(); var s: ProjectEditSession? = try session(); let d = ProjectEditSyntheticFixtures.draft()
        let c = ProjectEditCoordinator(initial: .init(draft: d), service: service, store: .init(storage: ProjectEditMemoryStorage()), currentSession: { s })
        await c.load(); c.prepare(d); let review = try XCTUnwrap(c.confirmation); s = try session(epoch: 2); await c.confirm(review)
        XCTAssertTrue(service.submissions.isEmpty); XCTAssertNil(c.snapshot)
    }
    @MainActor func testSessionChangeDuringPreflightNeverSubmits() async throws {
        let service = ProjectEditSyntheticService(); var s: ProjectEditSession? = try session(); let d = ProjectEditSyntheticFixtures.draft()
        let c = ProjectEditCoordinator(initial: .init(draft: d), service: service, store: .init(storage: ProjectEditMemoryStorage()), currentSession: { s })
        await c.load(); c.prepare(d); let review = try XCTUnwrap(c.confirmation)
        service.beforePreflight = { s = nil }; await c.confirm(review); XCTAssertTrue(service.submissions.isEmpty)
    }
    @MainActor func testUnknownOutcomeSurvivesNewCoordinatorAndReauthentication() async throws {
        let service = ProjectEditSyntheticService(scenario: .unknown); let store = ProjectEditLocalStore(storage: ProjectEditMemoryStorage()); var s: ProjectEditSession? = try session(); let d = ProjectEditSyntheticFixtures.draft()
        func make() -> ProjectEditCoordinator { .init(initial: .init(draft: d), service: service, store: store, currentSession: { s }) }
        let c = make(); await c.load(); c.saveLocal(d); c.prepare(d); await c.confirm(try XCTUnwrap(c.confirmation))
        XCTAssertTrue(c.isLocked); c.leaveScreen(); s = try session(epoch: 2)
        let reopened = make(); await reopened.load(); XCTAssertTrue(reopened.isLocked)
        await reopened.checkOutcome(); XCTAssertTrue(reopened.isLocked); reopened.prepare(d); XCTAssertNil(reopened.confirmation)
        XCTAssertEqual(service.submissions.count, 1)
    }
    @MainActor func testPersistenceFailurePreventsEvenSyntheticSubmit() async throws {
        let storage = ProjectEditMemoryStorage(); let service = ProjectEditSyntheticService(); let s = try session(); let d = ProjectEditSyntheticFixtures.draft()
        let c = ProjectEditCoordinator(initial: .init(draft: d), service: service, store: .init(storage: storage), currentSession: { s })
        await c.load(); c.prepare(d); storage.failWrites = true; await c.confirm(try XCTUnwrap(c.confirmation))
        XCTAssertTrue(service.submissions.isEmpty); XCTAssertEqual(c.state, .blocked)
    }
    @MainActor func testRevisionChangeAfterReviewRequiresReload() async throws {
        let service = ProjectEditSyntheticService(); let s = try session()
        let c = ProjectEditCoordinator(initial: service.snapshot, service: service, store: .init(storage: ProjectEditMemoryStorage()), currentSession: { s })
        await c.load(); c.prepare(try XCTUnwrap(c.snapshot?.draft)); let review = try XCTUnwrap(c.confirmation)
        service.snapshot.draft.baseRevision = "newer"; await c.confirm(review)
        XCTAssertTrue(service.submissions.isEmpty); XCTAssertEqual(c.messageKey, "projectEdit.revisionConflict")
    }
    @MainActor func testWhitelistCannotSneakInStructuralChangeThroughRestoreOrPrepare() async throws {
        let snapshot = ProjectEditSyntheticFixtures.snapshot(scope: .whitelist); let service = ProjectEditSyntheticService(snapshot: snapshot); let s = try session()
        let c = ProjectEditCoordinator(initial: snapshot, service: service, store: .init(storage: ProjectEditMemoryStorage()), currentSession: { s })
        await c.load(); var d = snapshot.draft; d.tickets[0].price = "5"; c.prepare(d)
        XCTAssertNil(c.confirmation); XCTAssertEqual(c.messageKey, "projectEdit.lockedFields")
    }
    @MainActor func testQuotaZeroBlocksButNilIsUnlimited() async throws {
        let service = ProjectEditSyntheticService(); let s = try session(); let d = ProjectEditSyntheticFixtures.draft()
        let c = ProjectEditCoordinator(initial: .init(draft: d), service: service, store: .init(storage: ProjectEditMemoryStorage()), currentSession: { s })
        await c.load(); c.prepare(d); service.capability = .init(canProPublish: true, remaining: 0)
        await c.confirm(try XCTUnwrap(c.confirmation)); XCTAssertTrue(service.submissions.isEmpty)
        XCTAssertTrue(ProjectEditCapability(canProPublish: true, remaining: nil).allowsCreate)
    }
    @MainActor func testDefinitiveRejectionClearsLockButNeverClaimsSuccess() async throws {
        let service = ProjectEditSyntheticService(scenario: .rejected); let s = try session(); let d = ProjectEditSyntheticFixtures.draft()
        let c = ProjectEditCoordinator(initial: .init(draft: d), service: service, store: .init(storage: ProjectEditMemoryStorage()), currentSession: { s })
        await c.load(); c.prepare(d); await c.confirm(try XCTUnwrap(c.confirmation))
        XCTAssertFalse(c.isLocked); XCTAssertEqual(c.state, .rejected)
    }
    func testEditDetailNormalizesSourceFieldsAndNodeReferences() throws {
        let data = Data(#"{"code":200,"data":{"editScope":"FULL","topic":{"id":71,"productType":1,"name":"Route","description":"Description","categoryIds":"7,9","updateTime":"r1","merchantStatus":1},"chapters":[{"id":11,"name":"One","description":"Opening","atmospherePreset":"NIGHT","allowedValidationMethods":"1,4","maxNodeXp":12,"cmsTopicNodeList":[{"id":22,"name":"Stop","longitude":"121","latitude":"31"}],"blocks":[{"type":"text","content":"Opening"},{"type":"node","nodeId":22}]}],"tickets":[{"name":"Free","price":0,"totalInventory":15}]}}"#.utf8)
        let value = try ProjectEditContract.decodeEditDetail(data, expectedTopicID: 71, owner: .merchant)
        XCTAssertEqual(value.scope, .full); XCTAssertEqual(value.draft.owner, .merchant); XCTAssertFalse(value.draft.publishToCreative)
        XCTAssertEqual(value.draft.categoryIDs, [7, 9]); XCTAssertTrue(value.draft.openMerchantPool)
        XCTAssertEqual(value.draft.chapters[0].preserved["atmospherePreset"], .string("BLUE"))
        XCTAssertEqual(value.draft.chapters[0].blocks?[1].nodeID, value.draft.chapters[0].nodes[0].id)
        XCTAssertEqual(value.draft.tickets[0].price, "0"); XCTAssertEqual(value.draft.tickets[0].totalStock, "15")
        XCTAssertEqual(value.draft.tickets[0].teamSize, "")
    }
    func testMissingTeamSizeStaysBlankAndLiteralZeroStaysZero() throws {
        let missing = Data(#"{"code":200,"data":{"editScope":"FULL","topic":{"id":71,"productType":1,"name":"Route","description":"Description","updateTime":"r1"},"chapters":[],"tickets":[{"name":"Free","price":0,"totalInventory":15}]}}"#.utf8)
        let present = Data(#"{"code":200,"data":{"editScope":"FULL","topic":{"id":71,"productType":1,"name":"Route","description":"Description","updateTime":"r1"},"chapters":[],"tickets":[{"name":"Free","price":0,"totalInventory":15,"teamSize":0}]}}"#.utf8)
        XCTAssertEqual(try ProjectEditContract.decodeEditDetail(missing, expectedTopicID: 71, owner: .personal).draft.tickets[0].teamSize, "")
        XCTAssertEqual(try ProjectEditContract.decodeEditDetail(present, expectedTopicID: 71, owner: .personal).draft.tickets[0].teamSize, "0")
    }
    func testBlankTeamSizeStaysValidAndIsOmittedFromPayloadWhileLiteralZeroIsSent() throws {
        var draft = ProjectEditSyntheticFixtures.draft(product: .city)
        draft.tickets[0].teamSize = ""
        XCTAssertTrue(ProjectEditValidation.issues(draft).isEmpty)
        func ticket(_ draft: ProjectEditDraft) throws -> [String: ProjectEditJSON] {
            let payload = try ProjectEditContract.payload(draft, topicID: nil, scope: .full, baseline: nil, intent: .ordinary)
            return try XCTUnwrap(payload["tickets"]?.array?.first?.object)
        }
        XCTAssertNil(try ticket(draft)["teamSize"])
        draft.tickets[0].teamSize = "0"
        XCTAssertEqual(try ticket(draft)["teamSize"], .number(0))
        draft.tickets[0].teamSize = "x"
        XCTAssertFalse(ProjectEditValidation.issues(draft).isEmpty)
    }
    func testUnknownEditScopeAndWrongTopicAreRejected() {
        let data = Data(#"{"code":200,"data":{"editScope":"NEW_SCOPE","topic":{"id":71,"productType":1,"updateTime":"r1"},"chapters":[],"tickets":[]}}"#.utf8)
        XCTAssertThrowsError(try ProjectEditContract.decodeEditDetail(data, expectedTopicID: 71, owner: .personal))
        let validScope = Data(String(decoding: data, as: UTF8.self).replacingOccurrences(of: "NEW_SCOPE", with: "FULL").utf8)
        XCTAssertThrowsError(try ProjectEditContract.decodeEditDetail(validScope, expectedTopicID: 72, owner: .personal))
    }
    func testIndependentEditDetailDecodesHaveEqualStableTicketIdentities() throws {
        let data = projectTicketIdentityFixture()
        let first = try ProjectEditContract.decodeEditDetail(data, expectedTopicID: 71, owner: .personal)
        let second = try ProjectEditContract.decodeEditDetail(data, expectedTopicID: 71, owner: .personal)
        XCTAssertEqual(first, second)
        XCTAssertEqual(first.draft.tickets.map(\.id), ["topic-71-ticket-index-0", "topic-71-ticket-index-1"])
        // Identical content does not collapse two source rows into one editor binding.
        XCTAssertEqual(first.draft.tickets[0].name, first.draft.tickets[1].name)
        XCTAssertNotEqual(first.draft.tickets[0].id, first.draft.tickets[1].id)
    }
    func testDecodedTicketIdentityIsTopicScopedAndAbsentFromWirePayload() throws {
        let first = try ProjectEditContract.decodeEditDetail(projectTicketIdentityFixture(), expectedTopicID: 71, owner: .personal)
        let otherData = Data(String(decoding: projectTicketIdentityFixture(), as: UTF8.self)
            .replacingOccurrences(of: "\"id\":71", with: "\"id\":72").utf8)
        let other = try ProjectEditContract.decodeEditDetail(otherData, expectedTopicID: 72, owner: .personal)
        XCTAssertNotEqual(first.draft.tickets[0].id, other.draft.tickets[0].id)
        let payload = try ProjectEditContract.payload(first.draft, topicID: 71, scope: .full)
        for ticket in try XCTUnwrap(payload["tickets"]?.array) {
            XCTAssertNil(ticket.object?["id"])
            XCTAssertFalse(String(describing: ticket).contains("ticket-index"))
        }
    }
    @MainActor func testUnchangedFreshlyDecodedPreflightAllowsReviewedEdit() async throws {
        let service = ProjectTicketDecodingService(data: projectTicketIdentityFixture())
        let initial = try ProjectEditContract.decodeEditDetail(service.data, expectedTopicID: 71, owner: .personal)
        let s = try session()
        let coordinator = ProjectEditCoordinator(initial: initial, service: service,
            store: .init(storage: ProjectEditMemoryStorage()), currentSession: { s })
        await coordinator.load()
        var draft = try XCTUnwrap(coordinator.snapshot?.draft); draft.name = "Reviewed route rename"
        coordinator.prepare(draft)
        let review = try XCTUnwrap(coordinator.confirmation)
        await coordinator.confirm(review)
        XCTAssertEqual(service.preflightCount, 2)
        XCTAssertEqual(service.submissions.count, 1)
        XCTAssertEqual(service.submissions.first?.payload["name"], .string("Reviewed route rename"))
        XCTAssertEqual(coordinator.state, .simulated)
    }
    @MainActor func testFreshTicketChangeStillRejectsReviewedEditWithSameRevision() async throws {
        let service = ProjectTicketDecodingService(data: projectTicketIdentityFixture())
        let initial = try ProjectEditContract.decodeEditDetail(service.data, expectedTopicID: 71, owner: .personal)
        let s = try session()
        let coordinator = ProjectEditCoordinator(initial: initial, service: service,
            store: .init(storage: ProjectEditMemoryStorage()), currentSession: { s })
        await coordinator.load()
        var draft = try XCTUnwrap(coordinator.snapshot?.draft); draft.name = "Reviewed route rename"
        coordinator.prepare(draft)
        let review = try XCTUnwrap(coordinator.confirmation)
        service.data = Data(String(decoding: service.data, as: UTF8.self).replacingOccurrences(of: "\"price\":0", with: "\"price\":3").utf8)
        await coordinator.confirm(review)
        XCTAssertEqual(service.preflightCount, 2)
        XCTAssertTrue(service.submissions.isEmpty)
        XCTAssertEqual(coordinator.state, .blocked)
        XCTAssertEqual(coordinator.messageKey, "projectEdit.revisionConflict")
    }
    @MainActor func testGuestCanReviewInMemoryButCannotPersistOrSubmit() async throws {
        let storage = ProjectEditMemoryStorage(); let service = ProjectEditSyntheticService()
        let c = ProjectEditCoordinator(initial: .init(draft: .init()), service: service, store: .init(storage: storage), currentSession: { nil })
        await c.load(); let d = ProjectEditSyntheticFixtures.draft(); c.saveLocal(d); c.prepare(d)
        await c.confirm(try XCTUnwrap(c.confirmation))
        XCTAssertTrue(storage.data.isEmpty); XCTAssertTrue(service.submissions.isEmpty); XCTAssertNil(c.identity)
    }
    @MainActor func testIntentDiscoverableAcrossReopenWithoutUIAutosave() async throws {
        let service = ProjectEditSyntheticService(scenario: .unknown); let store = ProjectEditLocalStore(storage: ProjectEditMemoryStorage()); let s = try session(); let d = ProjectEditSyntheticFixtures.draft()
        let first = ProjectEditCoordinator(initial: .init(draft: d), service: service, store: store, currentSession: { s })
        await first.load(); first.prepare(d); await first.confirm(try XCTUnwrap(first.confirmation))
        let second = ProjectEditCoordinator(initial: .init(draft: d), service: service, store: store, currentSession: { s })
        await second.load(); XCTAssertTrue(second.isLocked); XCTAssertEqual(first.identity, second.identity)
    }
    @MainActor func testCompletedReceiptPreventsSameDraftReplayAfterReopen() async throws {
        let service = ProjectEditSyntheticService(); let store = ProjectEditLocalStore(storage: ProjectEditMemoryStorage()); let s = try session(); let d = ProjectEditSyntheticFixtures.draft()
        let first = ProjectEditCoordinator(initial: .init(draft: d), service: service, store: store, currentSession: { s })
        await first.load(); first.prepare(d); await first.confirm(try XCTUnwrap(first.confirmation))
        let second = ProjectEditCoordinator(initial: .init(draft: d), service: service, store: store, currentSession: { s })
        await second.load(); second.prepare(d); XCTAssertEqual(second.state, .simulated); XCTAssertNil(second.confirmation)
        XCTAssertEqual(service.submissions.count, 1)
    }

}

private func projectTicketIdentityFixture() -> Data {
    Data(#"{"code":200,"data":{"editScope":"FULL","topic":{"id":71,"productType":1,"name":"Route","description":"Description","imgUrl":"fixture://cover","categoryIds":"7","updateTime":"r1","startDate":"2030-05-01","endDate":"2030-05-30"},"chapters":[{"id":11,"name":"Opening","description":"An actual fixture story","cmsTopicNodeList":[{"id":22,"name":"Stop","longitude":"121","latitude":"31"}]}],"tickets":[{"name":"Same source title","price":0,"totalInventory":15,"startTime":"2030-05-02 10:00","endTime":"2030-05-02 12:00","meetingPoint":"Fixture meeting place"},{"name":"Same source title","price":0,"totalInventory":15,"startTime":"2030-05-02 10:00","endTime":"2030-05-02 12:00","meetingPoint":"Fixture meeting place"}]}}"#.utf8)
}

/// Decodes fresh bytes on every preflight, rather than returning one retained snapshot.
@MainActor private final class ProjectTicketDecodingService: ProjectEditServing {
    var data: Data
    var authority: ProjectEditServiceAuthority { .synthetic }
    private(set) var preflightCount = 0
    private(set) var submissions: [ProjectEditPending] = []
    init(data: Data) { self.data = data }
    func preflight(topicID: Int?, session: ProjectEditSession) async throws -> ProjectEditPreflight {
        preflightCount += 1
        let snapshot = try ProjectEditContract.decodeEditDetail(data, expectedTopicID: 71, owner: .personal)
        return .init(capability: .init(canProPublish: true, remaining: nil), snapshot: snapshot)
    }
    func submit(_ operation: ProjectEditPending, session: ProjectEditSession) async -> ProjectEditWriteOutcome {
        submissions.append(operation)
        return .simulatedReceipt(operationID: operation.operationID, topicID: 71)
    }
    func terminalReceipt(operationID: UUID, session: ProjectEditSession) async throws -> ProjectEditWriteOutcome? { nil }
}

// Recruitment carry-over is a preservation exception, never a creation/edit grant.
extension ProjectEditTests {
    private func recruitmentBaseline(fee: ProjectEditJSON? = .string("12.30")) -> ProjectEditSnapshot {
        var draft = ProjectEditSyntheticFixtures.draft(product: .freeExplore)
        draft.baseRevision = "server-r1"; draft.clubID = 31; draft.openMerchantPool = true
        draft.preserved["openClubPool"] = .number(0); draft.publishToCreative = false
        draft.chapters[0].id = "chapter-11"; draft.chapters[0].preserved["id"] = .number(11)
        let fields: [String: ProjectEditJSON] = ["recruitEnabled": .number(1), "termsMode": .string("REVSHARE"),
            "categoryId": .number(5), "category": .string("Café"), "maxMerchant": .number(2),
            "perkMinValue": .null, "allowedValidationMethods": .string("1, 3,"), "maxNodeXp": .number(10)]
        for (key, value) in fields { draft.chapters[0].preserved[key] = value }
        draft.chapters[0].preserved["maxPerHeadFee"] = fee
        return .init(topicID: 71, draft: draft)
    }
    func testRecruitmentReadbackPreservesRawTypesAndAbsentFieldsWithoutDefaults() throws {
        for fee: ProjectEditJSON? in [nil, .null, .string("12.30"), .number(Decimal(string: "12.30")!), .bool(true), .object(["future": .string("e\u{301}")])] {
            var envelope = try JSONDecoder().decode(ProjectEditJSON.self, from: projectTicketIdentityFixture()).object!
            var body = envelope["data"]!.object!, rows = body["chapters"]!.array!, chapter = rows[0].object!
            chapter["maxPerHeadFee"] = fee; chapter["termsMode"] = .string("REVSHARE")
            rows[0] = .object(chapter); body["chapters"] = .array(rows); envelope["data"] = .object(body)
            let decoded = try ProjectEditContract.decodeEditDetail(JSONEncoder().encode(ProjectEditJSON.object(envelope)), expectedTopicID: 71, owner: .personal)
            let preserved = decoded.draft.chapters[0].preserved
            XCTAssertEqual(ProjectEditPendingMaterials.exactData(preserved["maxPerHeadFee"]), ProjectEditPendingMaterials.exactData(fee))
            XCTAssertNil(preserved["recruitEnabled"]); XCTAssertNil(preserved["maxMerchant"])
            let restored = try JSONDecoder().decode(ProjectEditDraft.self, from: JSONEncoder().encode(decoded.draft))
            XCTAssertEqual(ProjectEditPendingMaterials.exactData(restored), ProjectEditPendingMaterials.exactData(decoded.draft))
        }
    }
    func testUnchangedServerRecruitmentAllowsUnrelatedEditAndExactLegacyPayload() throws {
        for fee in [ProjectEditJSON.string("0012.30"), .number(Decimal(string: "12.30")!)] {
            let baseline = recruitmentBaseline(fee: fee); var draft = baseline.draft; draft.name = "Unrelated rename"
            XCTAssertTrue(ProjectChapterRecruitmentCarryOver.allows(draft, baseline: baseline))
            XCTAssertTrue(ProjectEditValidation.issues(draft, baseline: baseline).isEmpty)
            let payload = try ProjectEditContract.payload(draft, topicID: 71, scope: .full, baseline: baseline)
            let row = try XCTUnwrap(payload["chapters"]?.array?.first?.object)
            XCTAssertEqual(ProjectEditPendingMaterials.exactData(ProjectChapterRecruitmentCarryOver.rawFields(row)),
                           ProjectEditPendingMaterials.exactData(ProjectChapterRecruitmentCarryOver.rawFields(baseline.draft.chapters[0].preserved)))
            XCTAssertEqual(try ProjectEditStoryContract.path(payload: payload, baseline: baseline), "api/topic/update")
            XCTAssertNoThrow(try ProjectEditStoryContract.validatePayload(payload, baseline: baseline))
        }
    }
    func testUnchangedServerRecruitmentAlsoWorksThroughExistingV2Validation() throws {
        var baseline = recruitmentBaseline(); baseline.draft.chapters[0].preserved["_nativeStoredStoryFlow"] = .bool(true)
        let node = baseline.draft.chapters[0].nodes[0]
        baseline.draft.chapters[0].blocks = [.init(kind: .text, content: "Story"), .init(kind: .node, nodeID: node.id)]
        var draft = baseline.draft; draft.chapters[0].nodes[0].description = "Unrelated node edit"
        let payload = try ProjectEditContract.payload(draft, topicID: 71, scope: .full, baseline: baseline)
        XCTAssertEqual(try ProjectEditStoryContract.path(payload: payload, baseline: baseline), "api/topic/v2/update")
        XCTAssertNoThrow(try ProjectEditStoryContract.validatePayload(payload, baseline: baseline))
    }
    func testNewCopiedMissingBaselineAndWrongTopicNeverReceiveException() {
        let baseline = recruitmentBaseline(), draft = baseline.draft
        XCTAssertFalse(ProjectChapterRecruitmentCarryOver.allows(draft, baseline: nil))
        XCTAssertFalse(ProjectChapterRecruitmentCarryOver.allows(draft, baseline: .init(draft: draft)))
        XCTAssertThrowsError(try ProjectEditContract.payload(draft, topicID: nil, scope: .full, baseline: baseline))
        XCTAssertThrowsError(try ProjectEditContract.payload(draft, topicID: 72, scope: .full, baseline: baseline))
        XCTAssertThrowsError(try ProjectEditContract.payload(draft, topicID: 71, scope: .full))
    }
    func testChangedOwnerClubProductRevisionOrPoolRejectBaselineException() {
        let baseline = recruitmentBaseline()
        for kind in ["owner", "club", "product", "revision", "pool"] {
            var draft = baseline.draft
            switch kind {
            case "owner": draft.owner = .merchant
            case "club": draft.clubID = 32
            case "product": draft.product = .city
            case "revision": draft.baseRevision = "server-r2"
            default: draft.openMerchantPool = false
            }
            XCTAssertFalse(ProjectChapterRecruitmentCarryOver.allows(draft, baseline: baseline))
            XCTAssertThrowsError(try ProjectEditContract.payload(draft, topicID: 71, scope: .full, baseline: baseline))
        }
        var unknown = baseline; unknown.draft.baseRevision = ""
        XCTAssertFalse(ProjectChapterRecruitmentCarryOver.allows(unknown.draft, baseline: unknown))
    }
    func testDuplicateMissingReplacedAndCanonicalAliasChapterIdentityReject() {
        let baseline = recruitmentBaseline()
        for kind in ["duplicate", "missing", "serverID", "localID", "empty"] {
            var draft = baseline.draft
            switch kind {
            case "duplicate": let first = draft.chapters[0]; draft.chapters.append(first)
            case "missing": draft.chapters = []
            case "serverID": draft.chapters[0].preserved["id"] = .number(12)
            case "localID": draft.chapters[0].id = "other"
            default: draft.chapters[0].id = ""
            }
            XCTAssertFalse(ProjectChapterRecruitmentCarryOver.allows(draft, baseline: baseline))
        }
        var original = baseline; original.draft.chapters[0].id = "é"; var changed = original.draft; changed.chapters[0].id = "e\u{301}"
        XCTAssertFalse(ProjectChapterRecruitmentCarryOver.allows(changed, baseline: original))
    }
    func testSameLookingDifferentRawTypeAndCanonicalTextAreNotUnchanged() {
        let baseline = recruitmentBaseline()
        for field in ["maxPerHeadFee", "category", "maxMerchant", "recruitEnabled", "perkMinValue"] {
            var draft = baseline.draft
            switch field {
            case "maxPerHeadFee": draft.chapters[0].preserved[field] = .number(Decimal(string: "12.30")!)
            case "category": draft.chapters[0].preserved[field] = .string("Cafe\u{301}")
            case "perkMinValue": draft.chapters[0].preserved[field] = nil
            default: draft.chapters[0].preserved[field] = .string(field == "maxMerchant" ? "2" : "1")
            }
            XCTAssertFalse(ProjectChapterRecruitmentCarryOver.allows(draft, baseline: baseline))
        }
    }
    func testMissingAndMalformedFeesRemainPreservedButCannotUseException() {
        for fee: ProjectEditJSON? in [nil, .null, .string(""), .string(" 12.30"), .string("12.300"), .string("+12"), .string("1e2"), .string("１２"), .number(0), .number(-1), .number(Decimal(string: "1.001")!), .bool(true), .array([])] {
            let baseline = recruitmentBaseline(fee: fee)
            XCTAssertFalse(ProjectChapterRecruitmentCarryOver.allows(baseline.draft, baseline: baseline))
            XCTAssertEqual(ProjectEditPendingMaterials.exactData(baseline.draft.chapters[0].preserved["maxPerHeadFee"]), ProjectEditPendingMaterials.exactData(fee))
        }
    }
    func testMalformedRecruitmentShapeAndUnsupportedMethodsFailClosed() {
        for (field, value): (String, ProjectEditJSON) in [("recruitEnabled", .number(2)), ("maxMerchant", .number(128)), ("categoryId", .number(0)), ("category", .number(5)), ("perkMinValue", .number(1)), ("maxNodeXp", .number(-1)), ("allowedValidationMethods", .string("1,,3")), ("allowedValidationMethods", .string("1,\u{301}3")), ("allowedValidationMethods", .string("\u{A0}1"))] {
            var baseline = recruitmentBaseline(); baseline.draft.chapters[0].preserved[field] = value
            XCTAssertFalse(ProjectChapterRecruitmentCarryOver.allows(baseline.draft, baseline: baseline))
        }
    }
    func testFinalLegacyAndV2PayloadGuardRejectsContextAndRawChanges() throws {
        for v2 in [false, true] {
            var baseline = recruitmentBaseline()
            if v2 { baseline.draft.chapters[0].preserved["_nativeStoredStoryFlow"] = .bool(true); let node = baseline.draft.chapters[0].nodes[0]; baseline.draft.chapters[0].blocks = [.init(kind: .text, content: "Story"), .init(kind: .node, nodeID: node.id)] }
            let original = try ProjectEditContract.payload(baseline.draft, topicID: 71, scope: .full, baseline: baseline)
            for field in ["scope", "id", "clubId", "productType", "fee", "missing", "duplicate"] {
                var payload = original
                switch field {
                case "scope": payload[field] = .string("MERCHANT")
                case "id": payload[field] = .number(72)
                case "clubId": payload[field] = .number(32)
                case "productType": payload[field] = .number(1)
                case "missing": payload["chapters"] = .array([])
                case "duplicate": let row = payload["chapters"]!.array![0]; payload["chapters"] = .array([row, row])
                default: var rows = payload["chapters"]!.array!, row = rows[0].object!; row["maxPerHeadFee"] = .number(Decimal(string: "12.30")!); rows[0] = .object(row); payload["chapters"] = .array(rows)
                }
                XCTAssertThrowsError(try ProjectEditStoryContract.validatePayload(payload, baseline: baseline))
            }
            XCTAssertThrowsError(try ProjectEditStoryContract.validatePayload(original))
        }
    }
    func testFreshSnapshotCanonicalEquivalenceDoesNotSatisfyRawCarryOverBinding() {
        let baseline = recruitmentBaseline(); var fresh = baseline
        fresh.draft.chapters[0].preserved["category"] = .string("Cafe\u{301}")
        XCTAssertEqual(fresh, baseline) // Existing Equatable alone cannot see this change.
        XCTAssertFalse(ProjectChapterRecruitmentCarryOver.matchesFresh(fresh, baseline: baseline))
        XCTAssertTrue(ProjectChapterRecruitmentCarryOver.matchesFresh(baseline, baseline: baseline))
        XCTAssertFalse(ProjectChapterRecruitmentCarryOver.matchesFresh(nil, baseline: baseline))
        fresh = baseline; fresh.draft.baseRevision = "server-r2"
        XCTAssertFalse(ProjectChapterRecruitmentCarryOver.matchesFresh(fresh, baseline: baseline))
    }
    func testOrdinaryAndWhitelistBehaviorDoesNotGainRecruitmentAuthorization() throws {
        let ordinary = ProjectEditSyntheticFixtures.snapshot()
        XCTAssertTrue(ProjectChapterRecruitmentCarryOver.matchesFresh(nil, baseline: ordinary)) // Additive guard only; existing equality is still mandatory.
        XCTAssertNoThrow(try ProjectEditContract.payload(ordinary.draft, topicID: ordinary.topicID, scope: .full))
        let original = recruitmentBaseline(), whitelist = ProjectEditSnapshot(topicID: 71, scope: .whitelist, draft: original.draft)
        let payload = try ProjectEditContract.payload(whitelist.draft, topicID: 71, scope: .whitelist, baseline: whitelist)
        XCTAssertNil(payload["chapters"]); XCTAssertNoThrow(try ProjectEditStoryContract.validatePayload(payload, baseline: whitelist))
    }
}

final class ProjectEditCastLookCarryTests: XCTestCase {
    func testCastConfigAndLookRideOnV2SaveAndLoad() throws {
        XCTAssertTrue(ProjectEditContract.topicCarryOver.contains("castConfig"))
        XCTAssertTrue(ProjectEditContract.topicCarryOver.contains("look"))
        let cast: [String: ProjectEditJSON] = ["enabled": .bool(true), "playerName": .bool(true), "cast": .array([])]
        let look = "{\"style\":\"PAPER\"}"
        var draft = ProjectEditSyntheticFixtures.draft()
        draft.preserved["publishMode"] = .string("pro")
        draft.preserved["castConfig"] = .object(cast)
        draft.preserved["look"] = .string(look)
        let created = try ProjectEditContract.payload(draft, topicID: nil, scope: .full)
        XCTAssertEqual(try ProjectEditStoryContract.path(payload: created, baseline: nil), ProjectEditStoryContract.createPath)
        let createdCast = try JSONDecoder().decode(ProjectEditJSON.self, from: Data(try XCTUnwrap(created["castConfig"]?.text).utf8))
        XCTAssertEqual(createdCast, .object(cast))
        XCTAssertEqual(created["look"], .string(look))
        let updated = try ProjectEditContract.payload(draft, topicID: 71, scope: .full)
        XCTAssertEqual(try ProjectEditStoryContract.path(payload: updated, baseline: nil), ProjectEditStoryContract.updatePath)
        XCTAssertEqual(updated["castConfig"], created["castConfig"])
        XCTAssertEqual(updated["look"], .string(look))
        let kept = "{\"enabled\":false}"
        draft.preserved["castConfig"] = .string(kept)
        XCTAssertEqual(try ProjectEditContract.payload(draft, topicID: 71, scope: .full)["castConfig"], .string(kept))
        let loaded = try detail(topic: ["castConfig": .object(cast), "look": .string(look)])
        XCTAssertEqual(loaded.preserved["castConfig"], .object(cast))
        XCTAssertEqual(loaded.preserved["look"], .string(look))
        let overlaid = try detail(topic: ["castConfig": .object(["enabled": .bool(false)]), "look": .string("topic")],
                                  overlay: ["castConfig": .string(kept), "look": .string(look)])
        XCTAssertEqual(overlaid.preserved["castConfig"], .string(kept))
        XCTAssertEqual(overlaid.preserved["look"], .string(look))
        draft.preserved["castConfig"] = .number(1)
        XCTAssertThrowsError(try ProjectEditContract.payload(draft, topicID: 71, scope: .full))
        let whitelist = try ProjectEditContract.payload(draft, topicID: 71, scope: .whitelist)
        XCTAssertNil(whitelist["castConfig"]); XCTAssertNil(whitelist["look"])
    }
    private func detail(topic: [String: ProjectEditJSON], overlay: [String: ProjectEditJSON] = [:]) throws -> ProjectEditDraft {
        var topicRow = topic
        topicRow["id"] = .number(71)
        topicRow["productType"] = .number(1)
        topicRow["name"] = .string("Route")
        topicRow["description"] = .string("Description")
        topicRow["updateTime"] = .string("r1")
        var body = overlay
        body["editScope"] = .string("FULL")
        body["topic"] = .object(topicRow)
        body["chapters"] = .array([])
        body["tickets"] = .array([.object(["name": .string("Free"), "price": .number(0)])])
        let bytes = try JSONEncoder().encode(["code": ProjectEditJSON.number(200), "data": .object(body)])
        return try ProjectEditContract.decodeEditDetail(bytes, expectedTopicID: 71, owner: .personal).draft
    }
}

final class ProjectEditRuntimeActsTests: XCTestCase {
    func testChapterHostUnlockFollowsTheActForThatChapter() throws {
        let closed = try teamDraft(hostUnlock: false)
        let resting = ProjectEditRuntimeActs.chapterHost(in: closed, chapterIndex: 0)
        XCTAssertFalse(resting.enabled)
        XCTAssertNil(resting.disabledReasonKey)
        XCTAssertEqual(resting.summaryKey, ProjectEditRuntimeActs.Copy.off)
        let opened = try ProjectEditRuntimeActs.setEnabled(true, chapterIndex: 0, in: closed)
        XCTAssertTrue(ProjectEditRuntimeActs.chapterHost(in: opened, chapterIndex: 0).enabled)
        XCTAssertEqual(ProjectEditRuntimeActs.chapterHost(in: opened, chapterIndex: 0).summaryKey, ProjectEditRuntimeActs.Copy.on)
        XCTAssertNoThrow(try NativeRuntimeStructureAuthorDraft.validateOriginalSubmission(opened))
        let saved = try ProjectEditContract.payload(opened, topicID: 71, scope: .full)
        XCTAssertEqual(saved["themeRuntimeConfig"], opened.preserved["themeRuntimeConfig"])
        let stored = try JSONDecoder().decode(ProjectEditJSON.self, from: Data(try XCTUnwrap(opened.preserved["themeRuntimeConfig"]?.text).utf8))
        let act = stored.object?["gameplayRuntime"]?.object?["acts"]?.array?.first?.object
        XCTAssertEqual(act?["hostUnlock"], .bool(true))
    }
    func testSoloPlayCanCloseStaffOpeningAndCannotOpenIt() throws {
        let opened = try teamDraft(hostUnlock: true, player: true)
        let row = ProjectEditRuntimeActs.chapterHost(in: opened, chapterIndex: 0)
        XCTAssertTrue(row.enabled)
        XCTAssertEqual(row.disabledReasonKey, ProjectEditRuntimeActs.Copy.displayPlayer)
        XCTAssertTrue(row.openingBlocked)
        XCTAssertThrowsError(try ProjectEditRuntimeActs.setEnabled(true, chapterIndex: 0, in: opened)) { error in
            XCTAssertEqual(error as? ProjectEditRuntimeActsError, .refused(ProjectEditRuntimeActs.Copy.refusePlayer))
        }
        XCTAssertEqual(opened.preserved["themeRuntimeConfig"], try teamDraft(hostUnlock: true, player: true).preserved["themeRuntimeConfig"])
        let closed = try ProjectEditRuntimeActs.setEnabled(false, chapterIndex: 0, in: opened)
        XCTAssertFalse(ProjectEditRuntimeActs.chapterHost(in: closed, chapterIndex: 0).enabled)
    }
    func testMissingModeAndUnsavedNodesRefuseWithoutWriting() throws {
        let bare = ProjectEditSyntheticFixtures.draft()
        XCTAssertEqual(ProjectEditRuntimeActs.chapterHost(in: bare, chapterIndex: 0).disabledReasonKey, ProjectEditRuntimeActs.Copy.displayUnsaved)
        XCTAssertThrowsError(try ProjectEditRuntimeActs.setEnabled(true, chapterIndex: 0, in: bare)) { error in
            XCTAssertEqual(error as? ProjectEditRuntimeActsError, .refused(ProjectEditRuntimeActs.Copy.refuseMode))
        }
        var unsaved = try teamDraft()
        unsaved.chapters[0].nodes[0].localMetadata["id"] = nil
        XCTAssertThrowsError(try ProjectEditRuntimeActs.setEnabled(false, chapterIndex: 0, in: unsaved)) { error in
            XCTAssertEqual(error as? ProjectEditRuntimeActsError, .refused(ProjectEditRuntimeActs.Copy.refuseSaveNodes))
        }
        XCTAssertEqual(unsaved.preserved["themeRuntimeConfig"], try teamDraft().preserved["themeRuntimeConfig"])
    }
    private func teamDraft(nodeID: Int = 22, hostUnlock: Bool = false, player: Bool = false) throws -> ProjectEditDraft {
        var draft = ProjectEditSyntheticFixtures.draft()
        draft.chapters[0].nodes[0].localMetadata["id"] = .number(Decimal(nodeID))
        var game: [String: ProjectEditJSON] = [
            "runtimeScope": .string(player ? "PLAYER" : "TEAM"),
            "acts": .array([.object([
                "actKey": .string("chapter_1"), "hostUnlock": .bool(hostUnlock),
                "completionRule": .object(["type": .string("ALL")]),
                "questKeys": .array([.string("node_\(nodeID)")])
            ])]),
            "quests": .array([.object([
                "questKey": .string("node_\(nodeID)"), "nodeId": .number(Decimal(nodeID)),
                "actKey": .string("chapter_1"), "locationKey": .string("node_\(nodeID)"),
                "settlementSlot": .string("node_\(nodeID)")
            ])])
        ]
        if !player { game["worldMode"] = .string("TEAM_INDEPENDENT") }
        let theme: [String: ProjectEditJSON] = ["schemaVersion": .number(1), "capacity": .number(0), "gameplayRuntime": .object(game)]
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        draft.preserved["themeRuntimeConfig"] = .string(String(decoding: try encoder.encode(theme), as: UTF8.self))
        return draft
    }
}

/// MP theme-runtime-survival.js toggleThemeReplay / toggleThemeTeamTrail.
final class ProjectEditThemeRulesTests: XCTestCase {
    func testReplayDefaultsOffAndIsRefusedForTeamRuntime() throws {
        let empty = ProjectEditSyntheticFixtures.draft(product: .city)
        XCTAssertFalse(ProjectEditThemeRules.replayEnabled(in: empty))
        let on = try ProjectEditThemeRules.setReplay(true, in: empty)
        XCTAssertTrue(ProjectEditThemeRules.replayEnabled(in: on))
        XCTAssertEqual(try theme(on)["schemaVersion"], .number(1))
        let team = try draft(with: ["schemaVersion": .number(1), "gameplayRuntime": .object(["runtimeScope": .string("TEAM")])])
        XCTAssertThrowsError(try ProjectEditThemeRules.setReplay(true, in: team)) { error in
            XCTAssertEqual(error as? ProjectEditRuntimeActsError, .refused(ProjectEditThemeRules.Copy.replayTeamRefused))
        }
        XCTAssertNoThrow(try ProjectEditThemeRules.setReplay(false, in: team))
    }

    func testTeamTrailDefaultsFollowRuntimeScope() throws {
        let empty = ProjectEditSyntheticFixtures.draft(product: .city)
        XCTAssertTrue(ProjectEditThemeRules.teamTrail(in: empty))
        XCTAssertEqual(try ProjectEditThemeRules.setTeamTrail(true, in: empty), empty)
        let player = try draft(with: ["schemaVersion": .number(1), "gameplayRuntime": .object(["runtimeScope": .string("PLAYER")])])
        XCTAssertFalse(ProjectEditThemeRules.teamTrail(in: player))
        let playerOn = try ProjectEditThemeRules.setTeamTrail(true, in: player)
        XCTAssertEqual(try theme(playerOn)["teamTrail"], .bool(true))
        let team = try draft(with: ["schemaVersion": .number(1), "teamTrail": .bool(false), "gameplayRuntime": .object(["runtimeScope": .string("TEAM")])])
        XCTAssertFalse(ProjectEditThemeRules.teamTrail(in: team))
        let teamOn = try ProjectEditThemeRules.setTeamTrail(true, in: team)
        XCTAssertNil(try theme(teamOn)["teamTrail"])
        XCTAssertTrue(ProjectEditThemeRules.teamTrail(in: teamOn))
        let teamOff = try ProjectEditThemeRules.setTeamTrail(false, in: teamOn)
        XCTAssertEqual(try theme(teamOff)["teamTrail"], .bool(false))
    }

    func testRunModeFollowsTheMiniProgramModeRules() throws {
        let empty = try draft(with: [:])
        XCTAssertNil(ProjectEditThemeRules.runMode(in: empty))
        XCTAssertEqual(ProjectEditThemeRules.modeLabelKey(nil), "mpPublish.rules.mode.none")
        let player = try ProjectEditThemeRules.setMode(.player, in: empty, inputs: nil)
        XCTAssertEqual(ProjectEditThemeRules.runMode(in: player), .player)
        let game = try theme(player)["gameplayRuntime"]?.object
        XCTAssertEqual(try theme(player)["schemaVersion"], .number(1))
        XCTAssertEqual(game?["runtimeScope"], .string("PLAYER"))
        XCTAssertNil(game?["worldMode"])
        XCTAssertEqual(game?["survival"]?.object?["zeroHpPolicy"], .string("BLOCK_HP_COST"))
        let shared = try ProjectEditThemeRules.setMode(.sharedWorld, in: player, inputs: nil)
        XCTAssertEqual(ProjectEditThemeRules.runMode(in: shared), .sharedWorld)
        XCTAssertTrue(ProjectEditThemeRules.worldShared(in: shared))
        let trading = try ProjectEditThemeRules.setAllowTrade(true, in: shared)
        XCTAssertEqual(ProjectEditThemeRules.modeReason(.team, in: trading, inputs: nil), .key("mpPublish.rules.mode.reason.shared"))
        XCTAssertThrowsError(try ProjectEditThemeRules.setMode(.team, in: trading, inputs: nil))
        let hosted = try draft(with: ["schemaVersion": .number(1), "gameplayRuntime": .object(["runtimeScope": .string("TEAM"), "worldMode": .string("TEAM_INDEPENDENT"),
            "acts": .array([.object(["actKey": .string("a"), "hostUnlock": .bool(true)])])])])
        XCTAssertEqual(ProjectEditThemeRules.runMode(in: hosted), .team)
        XCTAssertEqual(ProjectEditThemeRules.modeReason(.player, in: hosted, inputs: nil), .key("mpPublish.rules.mode.reason.hostUnlock"))
        XCTAssertNil(ProjectEditThemeRules.modeReason(.sharedWorld, in: hosted, inputs: nil))
    }

    /// MP theme-runtime-survival.js openSurvivalEditor / toggleSurvivalCardField / removeSurvivalRow / saveSurvivalEditor.
    func testResultCardSavesCustomizesAndResetsLikeTheMiniProgram() throws {
        let empty = try draft(with: ["schemaVersion": .number(1)])
        XCTAssertFalse(ProjectEditThemeRules.cardCustomized(in: empty))
        XCTAssertEqual(try ProjectEditThemeRules.saveCard([:], reset: false, in: empty), empty)
        var row = ProjectEditThemeRules.toggleCardField(.ending, in: [:])
        row = ProjectEditThemeRules.toggleCardField(.hp, in: row)
        XCTAssertEqual(ProjectEditThemeRules.cardFields(row), ["ending", "hp"])
        row = ProjectEditThemeRules.toggleCardField(.ending, in: row)
        XCTAssertEqual(ProjectEditThemeRules.cardFields(row), ["hp"])
        let bad = ProjectEditThemeRules.settingCardCover("http://example.invalid/a.jpg", in: row)
        XCTAssertThrowsError(try ProjectEditThemeRules.saveCard(bad, reset: false, in: empty)) { error in
            XCTAssertEqual(error as? ProjectEditRuntimeActsError, .refused("mpPublish.rules.card.coverInvalid"))
        }
        let saved = try ProjectEditThemeRules.saveCard(ProjectEditThemeRules.settingCardCover("https://example.invalid/a.jpg", in: row), reset: false, in: empty)
        XCTAssertTrue(ProjectEditThemeRules.cardCustomized(in: saved))
        XCTAssertEqual(ProjectEditThemeRules.cardCover(ProjectEditThemeRules.card(in: saved)), "https://example.invalid/a.jpg")
        XCTAssertEqual(try ProjectEditThemeRules.saveCard(ProjectEditThemeRules.card(in: saved), reset: false, in: saved), saved)
        let reset = try ProjectEditThemeRules.saveCard([:], reset: true, in: saved)
        XCTAssertFalse(ProjectEditThemeRules.cardCustomized(in: reset))
        XCTAssertNil(try theme(reset)["card"])
        let customName = try draft(with: ["schemaVersion": .number(1), "hpName": .string("体力")])
        XCTAssertEqual(ProjectEditThemeRules.cardCustomName(.hp, in: customName), "体力")
        XCTAssertNil(ProjectEditThemeRules.cardCustomName(.luck, in: customName))
    }

    func testTopicKeysItemsFollowTheMiniProgramItemTable() throws {
        let empty = try draft(with: [:])
        XCTAssertEqual(ProjectEditTopicKeys.items(in: empty), [])
        let added = try ProjectEditTopicKeys.addItem(named: " 铜钥匙 ", id: "i1", in: empty)
        XCTAssertEqual(ProjectEditTopicKeys.items(in: added).map(\.name), ["铜钥匙"])
        XCTAssertEqual(try theme(added)["schemaVersion"], .number(1))
        let renamed = try ProjectEditTopicKeys.renameItem("i1", to: "铁钥匙", in: added)
        XCTAssertEqual(ProjectEditTopicKeys.items(in: renamed).map(\.name), ["铁钥匙"])
        let used = try draft(with: ["items": .array([.object(["id": .string("i2"), "kind": .string("ITEM"), "name": .string("灯")]),
                                                      .object(["id": .string("c1"), "kind": .string("COIN"), "name": .string("币")])]),
                                    "grants": .array([.object(["id": .string("completion_material"), "itemId": .string("i2")])]),
                                    "chapters": .array([.object(["index": .number(1), "eggs": .array([.object(["name": .string("井"), "rewards": .array([.object(["itemId": .string("i2")])])])])])])])
        let items = ProjectEditTopicKeys.items(in: used)
        XCTAssertEqual(items.map(\.id), ["i2"])
        XCTAssertEqual(items.first?.usedIn, [.completionReward, .chapterEgg(2, "井")])
        XCTAssertEqual(try ProjectEditTopicKeys.deleteItem("i2", in: used), used)
        let removed = try ProjectEditTopicKeys.deleteItem("i1", in: renamed)
        XCTAssertEqual(ProjectEditTopicKeys.items(in: removed), [])
        XCTAssertEqual(ProjectEditTopicKeys.nameIssue(String(repeating: "长", count: 25), taken: [], kind: .clue), .tooLong)
        XCTAssertEqual(ProjectEditTopicKeys.nameIssue("灯", taken: ["灯"], kind: .item), .taken(.item))
        XCTAssertNil(ProjectEditTopicKeys.nameIssue("", taken: [], kind: .tag))
        XCTAssertEqual(ProjectEditTopicKeys.usedIn(fromRefusal: "clue.door 仍被引用，引用位置：第 1 章、结局"), ["第 1 章", "结局"])
        XCTAssertEqual(ProjectEditTopicKeys.usedIn(fromRefusal: "删除失败"), [])
    }

    func testTradeAndVoteOnlyApplyToASharedTeamWorld() throws {
        let solo = try draft(with: ["schemaVersion": .number(1), "gameplayRuntime": .object(["runtimeScope": .string("TEAM")])])
        XCTAssertFalse(ProjectEditThemeRules.worldShared(in: solo))
        XCTAssertEqual(try ProjectEditThemeRules.setAllowTrade(true, in: solo), solo)
        XCTAssertEqual(try ProjectEditThemeRules.setVotePolicy(.unanimous, in: solo), solo)
        let shared = try draft(with: ["schemaVersion": .number(1), "gameplayRuntime": .object(["runtimeScope": .string("TEAM"), "worldMode": .string("WORLD_SHARED")])])
        XCTAssertTrue(ProjectEditThemeRules.worldShared(in: shared))
        XCTAssertFalse(ProjectEditThemeRules.allowTrade(in: shared))
        XCTAssertEqual(ProjectEditThemeRules.votePolicy(in: shared), .majority)
        XCTAssertEqual(try ProjectEditThemeRules.setAllowTrade(false, in: shared), shared)
        let trading = try ProjectEditThemeRules.setAllowTrade(true, in: shared)
        XCTAssertTrue(ProjectEditThemeRules.allowTrade(in: trading))
        let closed = try ProjectEditThemeRules.setAllowTrade(false, in: trading)
        XCTAssertEqual(try theme(closed)["gameplayRuntime"]?.object?["allowTrade"], .bool(false))
        let voting = try ProjectEditThemeRules.setVotePolicy(.majorityAcceptance, in: shared)
        XCTAssertEqual(try theme(voting)["gameplayRuntime"]?.object?["votePolicy"], .string("MAJORITY_ACCEPTANCE"))
        XCTAssertEqual(ProjectEditThemeRules.votePolicy(in: voting), .majorityAcceptance)
    }

    func testHPAndLuckRowsFollowTheRuntimeValuesCard() throws {
        // MP story-initial-state.js parse: empty journeyRules = fresh topic, both off.
        let fresh = try draft(with: ["schemaVersion": .number(1)])
        XCTAssertTrue(ProjectEditRuntimeStats.available(in: fresh))
        XCTAssertFalse(ProjectEditRuntimeStats.enabled(.hp, in: fresh))
        XCTAssertEqual(ProjectEditRuntimeStats.maximum(.hp, in: fresh), 10)
        XCTAssertEqual(ProjectEditRuntimeStats.maximum(.luck, in: fresh), 3)
        // MP onRuntimeStatToggle: hp on keeps luck off, turns stateEnabled and checkEnabled on.
        let hpOn = try ProjectEditRuntimeStats.setEnabled(true, .hp, in: fresh)
        XCTAssertTrue(ProjectEditRuntimeStats.enabled(.hp, in: hpOn))
        XCTAssertFalse(ProjectEditRuntimeStats.enabled(.luck, in: hpOn))
        let rules = try journeyRules(hpOn)
        XCTAssertEqual(rules["stateEnabled"], .bool(true))
        XCTAssertEqual(rules["checkEnabled"], .bool(true))
        XCTAssertEqual(rules["schemaVersion"], .number(1))
        XCTAssertEqual(try ProjectEditRuntimeStats.setEnabled(true, .hp, in: hpOn), hpOn)
        // MP onRuntimeStatMax + serialize ranges.
        XCTAssertThrowsError(try ProjectEditRuntimeStats.setMaximum(21, .hp, in: hpOn))
        XCTAssertThrowsError(try ProjectEditRuntimeStats.setMaximum(6, .luck, in: hpOn))
        let lowered = try ProjectEditRuntimeStats.setMaximum(5, .hp, in: hpOn)
        XCTAssertEqual(ProjectEditRuntimeStats.maximum(.hp, in: lowered.draft), 5)
        XCTAssertEqual(lowered.warning, ProjectEditRuntimeStats.Copy.initialOverMaximum)
        XCTAssertNil(try ProjectEditRuntimeStats.setMaximum(12, .hp, in: hpOn).warning)
        // MP onRuntimeName: theme hpName, cut to 20.
        let named = try ProjectEditRuntimeStats.setName(String(repeating: "精", count: 25), .hp, in: hpOn)
        XCTAssertEqual(ProjectEditRuntimeStats.name(.hp, in: named).count, 20)
        let off = try ProjectEditRuntimeStats.setEnabled(false, .hp, in: hpOn)
        XCTAssertEqual(try journeyRules(off)["stateEnabled"], .bool(false))
        // Schema-2 rules keep the older resource editor.
        var schemaTwo = fresh
        schemaTwo.preserved["journeyRules"] = .string("{\"schemaVersion\":2}")
        XCTAssertFalse(ProjectEditRuntimeStats.available(in: schemaTwo))
        XCTAssertThrowsError(try ProjectEditRuntimeStats.setEnabled(true, .hp, in: schemaTwo))
    }

    func testCustomValuesFollowTheRuntimeValuesCard() throws {
        // MP openValueEditor: a new row is counter.*, 0 至 100, 开局 0, visible.
        let base = try ProjectEditRuntimeStats.setEnabled(true, .hp, in: try draft(with: ["schemaVersion": .number(1)]))
        XCTAssertTrue(ProjectEditRuntimeValues.values(in: base).isEmpty)
        var row = ProjectEditRuntimeValues.newValue(in: base, now: Date(timeIntervalSince1970: 1_000))
        XCTAssertTrue(row.key.hasPrefix("counter.value_"))
        XCTAssertEqual(row.min, 0)
        XCTAssertEqual(row.max, 100)
        // MP values.attribute: 名称 1–24, range -10000…10000 with min ≤ max.
        XCTAssertThrowsError(try ProjectEditRuntimeValues.save(row, link: false, in: base))
        row.label = "体力"
        row.min = 5
        row.max = 4
        XCTAssertThrowsError(try ProjectEditRuntimeValues.save(row, link: false, in: base))
        row.max = 50
        // MP saveValueEditor: a new row keeps the editor's 开局值 (0 here, so 开局值越界 shows).
        let saved = try ProjectEditRuntimeValues.save(row, link: true, in: base)
        let values = ProjectEditRuntimeValues.values(in: saved)
        XCTAssertEqual(values.map(\.label), ["体力"])
        XCTAssertTrue(values[0].invalidInitial)
        XCTAssertEqual(try journeyRules(saved)["stateEnabled"], .bool(true))
        // MP addValueLink: link_1, PER_POINT onto sys.hp.
        XCTAssertTrue(ProjectEditRuntimeValues.linked(row.key, in: saved))
        let link = try XCTUnwrap(try journeyRules(saved)["statLinks"]?.array?.first?.object)
        XCTAssertEqual(link["id"], .string("link_1"))
        XCTAssertEqual(link["targetKey"], .string("sys.hp"))
        XCTAssertEqual(link["trigger"], .string("PER_POINT"))
        // MP removeValue: refused while referenced (its own link counts), allowed after the link is off.
        XCTAssertThrowsError(try ProjectEditRuntimeValues.remove(row.key, in: saved)) { error in
            XCTAssertEqual(error as? ProjectEditRuntimeValues.Refusal, .referenced([.link("link_1")]))
        }
        let unlinked = try ProjectEditRuntimeValues.save(row, link: false, in: saved)
        XCTAssertFalse(ProjectEditRuntimeValues.linked(row.key, in: unlinked))
        let removed = try ProjectEditRuntimeValues.remove(row.key, in: unlinked)
        XCTAssertTrue(ProjectEditRuntimeValues.values(in: removed).isEmpty)
        XCTAssertEqual(try journeyRules(removed)["stateEnabled"], .bool(true))
        // MP addValueLink: 请先启用生命值 when HP is off.
        let hpOff = try ProjectEditRuntimeStats.setEnabled(false, .hp, in: base)
        XCTAssertThrowsError(try ProjectEditRuntimeValues.save(row, link: true, in: hpOff)) { error in
            XCTAssertEqual(error as? ProjectEditRuntimeValues.Refusal, .copy(ProjectEditRuntimeValues.Copy.needsHP))
        }
    }

    func testActionCountAndConsumeOnNoEffectFollowTheRuntimeValuesCard() throws {
        let base = try draft(with: ["schemaVersion": .number(1)])
        XCTAssertNil(ProjectEditThemeRules.actionLimit(in: base))
        XCTAssertEqual(try ProjectEditThemeRules.setActionLimit(30, in: base), base)
        let on = try ProjectEditThemeRules.setActionEnabled(true, in: base)
        XCTAssertEqual(ProjectEditThemeRules.actionLimit(in: on), 20)
        let thirty = try ProjectEditThemeRules.setActionLimit(30, in: on)
        XCTAssertEqual(ProjectEditThemeRules.actionLimit(in: thirty), 30)
        XCTAssertThrowsError(try ProjectEditThemeRules.setActionLimit(0, in: thirty))
        XCTAssertThrowsError(try ProjectEditThemeRules.setActionLimit(100_000, in: thirty))
        let named = try ProjectEditThemeRules.setActionName(String(repeating: "步", count: 25), in: thirty)
        XCTAssertEqual(ProjectEditThemeRules.actionName(in: named).count, 20)
        let off = try ProjectEditThemeRules.setActionEnabled(false, in: named)
        XCTAssertNil(try theme(off)["actionLimit"])

        XCTAssertFalse(ProjectEditThemeRules.consumeOnNoEffectAvailable(in: base))
        XCTAssertThrowsError(try ProjectEditThemeRules.setConsumeOnNoEffect(true, in: base))
        let team = try draft(with: ["schemaVersion": .number(1), "gameplayRuntime": .object(["runtimeScope": .string("TEAM")])])
        XCTAssertTrue(ProjectEditThemeRules.consumeOnNoEffectAvailable(in: team))
        XCTAssertEqual(try ProjectEditThemeRules.setConsumeOnNoEffect(false, in: team), team)
        let consuming = try ProjectEditThemeRules.setConsumeOnNoEffect(true, in: team)
        XCTAssertTrue(ProjectEditThemeRules.consumeOnNoEffect(in: consuming))
        let stopped = try ProjectEditThemeRules.setConsumeOnNoEffect(false, in: consuming)
        XCTAssertEqual(try theme(stopped)["gameplayRuntime"]?.object?["survival"]?.object?["consumeOnNoEffect"], .bool(false))
    }

    func testD20RulesFollowTheMiniProgramSheet() throws {
        var draft = ProjectEditSyntheticFixtures.draft(product: .city)
        let source: ProjectEditJSON = .object([
            "checkEnabled": .bool(true),
            "rpg": .object(["bargain": .object(["enabled": .bool(true)]), "clocks": .array([.object(["var": .string("counter.clock_a"), "label": .string("巡夜"), "kind": .string("danger"), "segments": .number(4)])])]),
            "attributes": .array([
                .object(["key": .string("counter.watch"), "label": .string("观察"), "min": .number(0), "max": .number(5), "initial": .number(2), "visible": .bool(false)]),
                .object(["key": .string("counter.clock_a"), "label": .string("巡夜"), "min": .number(0), "max": .number(4), "initial": .number(0)]),
                .object(["key": .string("sys.hp"), "label": .string("生命")]),
            ]),
        ])
        draft.preserved["journeyRules"] = .string(String(data: try JSONEncoder().encode(source), encoding: .utf8) ?? "")
        var model = ProjectEditD20Rules.model(in: draft)
        XCTAssertTrue(model.checkEnabled)
        XCTAssertEqual(model.preset, .std)
        XCTAssertTrue(model.natAuto)
        XCTAssertTrue(model.bargain)
        XCTAssertEqual(model.attributes.map(\.key), ["counter.watch"])
        XCTAssertEqual(model.clocks.first?.segments, 4)
        XCTAssertEqual(try ProjectEditD20Rules.save(model, in: draft), draft)

        model.preset = .hard
        model.attributes[0] = ProjectEditD20Rules.clamp(model.attributes[0], .max, 1)
        XCTAssertEqual(model.attributes[0].max, 1)
        XCTAssertEqual(model.attributes[0].initial, 1)
        model.attributes.append(ProjectEditD20Rules.newAttribute(label: "胆量", preset: ProjectEditD20Rules.attributePresets[1], in: model))
        let saved = try ProjectEditD20Rules.save(model, in: draft)
        let written = try rules(saved)
        XCTAssertEqual(written["tiers"]?.object?["hard"]?.object?["dc"], .number(18))
        let rows = try XCTUnwrap(written["attributes"]?.array)
        XCTAssertEqual(Array(rows.compactMap { $0.object?["key"]?.text }.prefix(2)), ["counter.watch", model.attributes[1].key])
        XCTAssertEqual(rows[0].object?["visible"], .bool(false))
        XCTAssertEqual(rows[1].object?["max"], .number(10))
        XCTAssertEqual(rows.count, 4)
        XCTAssertEqual(written["stateEnabled"], .bool(true))
        XCTAssertEqual(ProjectEditD20Rules.model(in: saved).preset, .hard)

        let off = try rules(ProjectEditD20Rules.setCheckEnabled(false, in: draft))
        XCTAssertEqual(off["checkEnabled"], .bool(false))
        XCTAssertEqual(off["rpg"]?.object?["bargain"]?.object?["enabled"], .bool(false))
        XCTAssertEqual(off["stateEnabled"], .bool(true))
        XCTAssertNotNil(off["attributes"])

        // 更多规则 (MP newClock / newAspect / apply): new clock sized by the difficulty, traits keep the preset text,
        // an emptied list drops the field.
        var more = ProjectEditD20Rules.model(in: draft)
        more.preset = .hard
        let clock = ProjectEditD20Rules.newClock(label: "警报", in: more)
        XCTAssertTrue(clock.key.hasPrefix("counter.clock_"))
        XCTAssertTrue(clock.danger)
        XCTAssertEqual(clock.segments, 4)
        more.clocks.append(clock)
        more.clocks[0].danger = false
        more.aspects.append(ProjectEditD20Rules.newAspect(label: "眼尖", desc: "更容易发现线索", in: more))
        let moreRules = try rules(ProjectEditD20Rules.save(more, in: draft))
        let clockRows = try XCTUnwrap(moreRules["rpg"]?.object?["clocks"]?.array)
        XCTAssertEqual(clockRows.count, 2)
        XCTAssertEqual(clockRows[0].object?["kind"], .string("progress"))
        XCTAssertEqual(clockRows[1].object?["segments"], .number(4))
        XCTAssertEqual(moreRules["rpg"]?.object?["aspects"]?.array?.first?.object?["desc"], .string("更容易发现线索"))
        more.clocks = []
        XCTAssertNil(try rules(ProjectEditD20Rules.save(more, in: draft))["rpg"]?.object?["clocks"])

        draft.preserved["journeyRules"] = .string("{broken")
        XCTAssertThrowsError(try ProjectEditD20Rules.setCheckEnabled(true, in: draft))
        draft.preserved["journeyRules"] = nil
        XCTAssertEqual(try rules(ProjectEditD20Rules.setCheckEnabled(true, in: draft))["checkEnabled"], .bool(true))
    }

    private func rules(_ draft: ProjectEditDraft) throws -> [String: ProjectEditJSON] {
        let text = try XCTUnwrap(draft.preserved["journeyRules"]?.text)
        return try XCTUnwrap(try JSONDecoder().decode(ProjectEditJSON.self, from: Data(text.utf8)).object)
    }

    private func draft(with theme: [String: ProjectEditJSON]) throws -> ProjectEditDraft {
        var draft = ProjectEditSyntheticFixtures.draft(product: .city)
        let data = try JSONEncoder().encode(ProjectEditJSON.object(theme))
        draft.preserved["themeRuntimeConfig"] = .string(try XCTUnwrap(String(data: data, encoding: .utf8)))
        return draft
    }

    private func journeyRules(_ draft: ProjectEditDraft) throws -> [String: ProjectEditJSON] {
        let text = try XCTUnwrap(draft.preserved["journeyRules"]?.text)
        return try XCTUnwrap(try JSONDecoder().decode(ProjectEditJSON.self, from: Data(text.utf8)).object)
    }

    private func theme(_ draft: ProjectEditDraft) throws -> [String: ProjectEditJSON] {
        let text = try XCTUnwrap(draft.preserved["themeRuntimeConfig"]?.text)
        return try XCTUnwrap(try JSONDecoder().decode(ProjectEditJSON.self, from: Data(text.utf8)).object)
    }
}
