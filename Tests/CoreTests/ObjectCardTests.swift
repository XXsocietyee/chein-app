import XCTest
@testable import QuestifyCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

private actor ObjectCardTestTransport: HTTPTransport {
    let json: String
    let status: Int
    private(set) var requests: [URLRequest] = []
    init(json: String, status: Int = 200) { self.json = json; self.status = status }
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        requests.append(request); return (Data(json.utf8), status)
    }
}
private actor ObjectCardPendingTransport: HTTPTransport {
    private var pending: CheckedContinuation<(Data, Int), Error>?
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        try await withCheckedThrowingContinuation { pending = $0 }
    }
    func waitForRequest() async { while pending == nil { await Task.yield() } }
    func finish(code: Int) {
        let data = code == 200 ? ",\"data\":\(ObjectCardSyntheticFixtures.collectionJSON)" : ""
        pending?.resume(returning: (Data("{\"code\":\(code)\(data)}".utf8), 200)); pending = nil
    }
}
final class ObjectCardTests: XCTestCase {
    private func service(_ transport: any HTTPTransport) throws -> ObjectCardService {
        try ObjectCardService(configuration: APIConfiguration(baseURL: URL(string: "https://example.com/")!), transport: transport)
    }
    func testSourceFormAndStringStatus() async throws {
        let transport = ObjectCardTestTransport(json: "{\"code\":\"200\",\"data\":\(ObjectCardSyntheticFixtures.collectionJSON)}")
        let value = try await service(transport).list(category: .books, token: "synthetic-token")
        XCTAssertEqual(value.total, 52); XCTAssertEqual(value.cards.count, 2); XCTAssertTrue(value.isTruncated)
        let requests = await transport.requests
        let request = try XCTUnwrap(requests.first)
        XCTAssertEqual(request.httpMethod, "POST"); XCTAssertEqual(request.url?.path, "/api/object-card/list")
        XCTAssertNil(request.url?.query)
        let body = try XCTUnwrap(String(data: request.httpBody ?? Data(), encoding: .utf8))
        XCTAssertTrue(body.contains("pageNum=1")); XCTAssertTrue(body.contains("pageSize=40"))
        XCTAssertTrue(body.contains("category=")); XCTAssertFalse(body.contains("userId"))
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/x-www-form-urlencoded")
    }
    func testFramesFallbackAndStatus() throws {
        let cards = try ObjectCardSyntheticFixtures.collection().cards
        XCTAssertTrue(cards[0].generating); XCTAssertEqual(cards[0].frame(at: -1), cards[0].frames[1])
        XCTAssertFalse(cards[1].generating); XCTAssertEqual(cards[1].frame(at: 99), "")
        let row = #"{"id":"x","title":"Synthetic","sourceUrl":"https://fixtures.invalid/a.png","cutoutUrl":"https://fixtures.invalid/c.png","frames":[null,7,"",{"url":"ignored"}],"cutoutBox":[0.1,0.2,0.4,0.5]}"#
        let card = try JSONDecoder().decode(ObjectCard.self, from: Data(row.utf8))
        XCTAssertEqual(card.frames, [card.sourceURL]); XCTAssertEqual(card.thumbnail, card.cutoutURL)
        XCTAssertEqual(card.cutoutBox, [0.1,0.2,0.4,0.5]); XCTAssertEqual(card.cardStyle, "foil")
    }
    func testMalformedRowsAndTotalsFailClosed() {
        for raw in [#"{"list":[],"total":-1}"#, #"{"list":[],"total":1.5}"#, #"{"list":[{"id":1}],"total":1}"#, #"{"list":[{"title":"x"}],"total":1}"#] {
            XCTAssertThrowsError(try JSONDecoder().decode(ObjectCardCollection.self, from: Data(raw.utf8)))
        }
    }
    func testInvalidBoxIsIgnored() throws {
        for box in ["[0,0,2,1]", "[-1,0,1,1]", "[0,0,0,1]", "[0,0,1]", "[0,0,\"1\",1]"] {
            let json = "{\"id\":1,\"title\":\"Synthetic\",\"cutoutBox\":\(box)}"
            XCTAssertNil(try JSONDecoder().decode(ObjectCard.self, from: Data(json.utf8)).cutoutBox)
        }
    }
    func testExactCategoriesAndBadgeRouteNormalization() {
        XCTAssertEqual(ObjectCardCategory.allCases.map(\.rawValue), ["", "电子产品", "服饰", "鞋包", "食物饮料", "书籍文具", "玩具摆件", "日用杂物", "其他"])
        let p = ObjectBadgeDetailParameters(query: ["rarity":"99", "style":"unknown", "img":"javascript:bad", "name":" "], fallbackName: "Badge")
        XCTAssertEqual(p.rarity, 4); XCTAssertEqual(p.style, "enamel"); XCTAssertEqual(p.image, ""); XCTAssertEqual(p.name, "Badge")
        XCTAssertEqual(ObjectBadgeDetailParameters(query: ["rarity":"-1", "style":"glow"], fallbackName: "Badge").rarity, 0)
    }
    func testMediaPolicyRejectsUnsafeAndUnapprovedURLs() throws {
        let policy = ObjectCardMediaPolicy(approvedOrigins: ["https://media.example.com"])
        XCTAssertNoThrow(try policy.validate("https://media.example.com/image.png?signature=synthetic"))
        for raw in ["http://media.example.com/a.png", "https://evil.example.com/a.png", "https://media.example.com:444/a.png", "https://u:p@media.example.com/a.png", "https://localhost/a.png", "https://127.0.0.1/a.png", "https://media.example.com/a.png#fragment"] {
            XCTAssertThrowsError(try policy.validate(raw))
        }
    }
    func testBadgeTracksAndChinaDates() {
        for category in ["CO_CREATE", "CO-CREATE", "COCREATE"] { XCTAssertEqual(ObjectBadgePresentation.track(category: category), 4) }
        XCTAssertEqual(ObjectBadgePresentation.track(category: "unknown"), 0)
        XCTAssertEqual(ObjectBadgePresentation.date("2026-10-01 23:20:00"), "2026-10-01")
        XCTAssertEqual(ObjectBadgePresentation.date("2026-10-01T23:20:00Z"), "2026-10-02")
        XCTAssertEqual(ObjectBadgePresentation.date("2024-02-29"), "2024-02-29")
        for raw in ["2026-02-29", "2026-13-01", "2026-10-01 25:00:00", "2026-10-01T00:00:00+25:00", "garbage"] { XCTAssertNil(ObjectBadgePresentation.date(raw)) }
    }
    @MainActor func testFailedFilterKeepsPriorSelectionAndScopeResetClears() async throws {
        let reader = ObjectCardFixtureReader(), model = ObjectCardCollectionModel()
        await model.load(category: .all, reader: reader)
        reader.failNext = true
        await model.load(category: .books, reader: reader)
        XCTAssertTrue(model.failed); XCTAssertEqual(model.category, .all); XCTAssertEqual(model.collection?.total, 52)
        reader.rotateScope(); reader.failNext = true
        await model.load(category: .food, reader: reader)
        XCTAssertNil(model.collection); XCTAssertTrue(model.failed)
    }
    @MainActor func testStaleUnauthorizedCannotExpireNewSession() async throws {
        let transport = ObjectCardPendingTransport()
        var session: ObjectCardSession? = try .init(accountID: 1, epoch: 1, token: "synthetic-a")
        var unauthorized = 0
        let reader = ObjectCardSessionReader(service: try service(transport), currentSession: { session }, onUnauthorized: { _ in unauthorized += 1 })
        let prior = reader.scope
        let task = Task { try await reader.list(category: .all) }
        await transport.waitForRequest()
        session = try .init(accountID: 1, epoch: 2, token: "synthetic-b")
        XCTAssertNotEqual(reader.scope, prior)
        await transport.finish(code: 401)
        do { _ = try await task.value; XCTFail("stale response accepted") } catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertEqual(unauthorized, 0)
    }
    @MainActor func testStaleSuccessCannotRevealPreviousOwnerCards() async throws {
        let transport = ObjectCardPendingTransport()
        var session: ObjectCardSession? = try .init(accountID: 1, epoch: 1, token: "synthetic-a")
        let reader = ObjectCardSessionReader(service: try service(transport), currentSession: { session })
        let model = ObjectCardCollectionModel()
        let task = Task { await model.load(category: .all, reader: reader) }
        await transport.waitForRequest()
        session = try .init(accountID: 2, epoch: 2, token: "synthetic-b")
        model.invalidate()
        await transport.finish(code: 200); await task.value
        XCTAssertNil(model.collection); XCTAssertNil(model.loadedScope); XCTAssertFalse(model.loading)
    }
    @MainActor func testCancelledReadCannotPublishCards() async throws {
        let transport = ObjectCardPendingTransport()
        let session: ObjectCardSession = try .init(accountID: 1, epoch: 1, token: "synthetic-a")
        let reader = ObjectCardSessionReader(service: try service(transport), currentSession: { session })
        let model = ObjectCardCollectionModel()
        let task = Task { await model.load(category: .all, reader: reader) }
        await transport.waitForRequest(); task.cancel()
        await transport.finish(code: 200); await task.value
        XCTAssertNil(model.collection); XCTAssertFalse(model.loading)
    }
    @MainActor func testUnconfiguredDoesNotRequest() async throws {
        let reader = ObjectCardSessionReader(service: nil, currentSession: { try? .init(accountID: 1, epoch: 1, token: "synthetic") })
        do { _ = try await reader.list(category: .all); XCTFail("not gated") } catch { XCTAssertEqual(error as? APIError, .notConfigured) }
    }
    func testListedTotalFactIsEmDashOrLiteralZero() throws {
        let knownZero = try JSONDecoder().decode(ObjectCardListedData.self, from: Data(#"{"list":[],"total":0}"#.utf8))
        XCTAssertEqual(knownZero.total, .known(0))
        XCTAssertEqual(knownZero.total.text, "0")
        XCTAssertEqual(ObjectCardTotalFact.unknownText, "\u{2014}")
        XCTAssertNotEqual(ObjectCardTotalFact.unknownText, "0")
        XCTAssertNotEqual(ObjectCardTotalFact.unknownText, "-")
        let withheld = [
            ObjectCardSyntheticFixtures.unknownTotalJSON,
            #"{"list":[],"total":null}"#,
            #"{"list":[]}"#,
            #"{"list":[],"total":"0"}"#,
            #"{"list":[],"total":"12"}"#,
            #"{"list":[],"total":true}"#,
            #"{"list":[],"total":{}}"#,
            #"{"list":[],"total":[]}"#,
        ]
        for json in withheld {
            let value = try JSONDecoder().decode(ObjectCardListedData.self, from: Data(json.utf8))
            XCTAssertEqual(value.total, .unknown)
            XCTAssertEqual(value.total.text, "—")
            XCTAssertNotEqual(value.total.text, "0")
        }
        for json in [#"{"list":[],"total":-1}"#, #"{"list":[],"total":1.5}"#] {
            XCTAssertThrowsError(try JSONDecoder().decode(ObjectCardListedData.self, from: Data(json.utf8)))
            XCTAssertThrowsError(try JSONDecoder().decode(ObjectCardCollection.self, from: Data(json.utf8)))
        }
        XCTAssertThrowsError(try JSONDecoder().decode(ObjectCardCollection.self, from: Data(#"{"list":[],"total":null}"#.utf8)))
    }
    func testListContractKeepsKnownZeroAndRejectsAWithheldTotal() async throws {
        let zeroTransport = ObjectCardTestTransport(json: #"{"code":200,"data":{"list":[],"total":0}}"#)
        let zero = try await service(zeroTransport).list(category: .all, token: "synthetic-token")
        XCTAssertEqual(zero.total, 0)
        XCTAssertTrue(zero.cards.isEmpty)
        let bodies = [
            ObjectCardSyntheticFixtures.unknownTotalJSON,
            #"{"list":[{"id":903,"title":"Withheld total"}],"total":"12"}"#,
            #"{"list":[],"total":true}"#,
            #"{"list":[]}"#,
            #"{"list":[],"total":{}}"#,
        ]
        for body in bodies {
            let transport = ObjectCardTestTransport(json: "{\"code\":200,\"data\":\(body)}")
            do {
                _ = try await service(transport).list(category: .all, token: "synthetic-token")
                XCTFail("withheld total published a collection")
            } catch is ObjectCardTotalUnknown {
            } catch {
                XCTFail("unexpected \(error)")
            }
            let request = try XCTUnwrap(await transport.requests.first)
            XCTAssertEqual(request.url?.path, "/api/object-card/list")
            XCTAssertEqual(request.httpMethod, "POST")
            let raw = String(data: request.httpBody ?? Data(), encoding: .utf8) ?? ""
            XCTAssertFalse(raw.contains("rename"))
        }
        for total in ["-1", "1.5"] {
            let transport = ObjectCardTestTransport(json: "{\"code\":200,\"data\":{\"list\":[],\"total\":\(total)}}")
            do {
                _ = try await service(transport).list(category: .all, token: "synthetic-token")
                XCTFail("malformed total accepted")
            } catch {
                XCTAssertEqual(error as? APIError, .malformedResponse)
            }
        }
    }
    @MainActor func testAlbumPhasesCoverLoadingEmptyErrorAndUnknown() async throws {
        let fresh = ObjectCardCollectionModel()
        XCTAssertEqual(fresh.phase, .unknown)
        XCTAssertEqual(fresh.totalText, "—")
        XCTAssertNil(fresh.collection)

        let model = ObjectCardCollectionModel()
        let hanging = ObjectCardScriptedReader(next: .success(try ObjectCardSyntheticFixtures.collection()))
        hanging.hold = true
        let task = Task { await model.load(category: .all, reader: hanging) }
        for _ in 0..<200 where !hanging.parked { await Task.yield() }
        XCTAssertTrue(hanging.parked)
        XCTAssertEqual(model.phase, .loading)
        XCTAssertEqual(model.totalText, "—")
        hanging.release()
        await task.value
        XCTAssertEqual(model.phase, .ready)
        XCTAssertEqual(model.totalText, "52")
        XCTAssertEqual(model.collection?.total, 52)

        let reader = ObjectCardFixtureReader()
        await model.load(category: .clothing, reader: reader)
        XCTAssertEqual(model.phase, .empty)
        XCTAssertEqual(model.totalText, "0")
        XCTAssertEqual(model.collection?.total, 0)
        XCTAssertEqual(model.collection?.cards.isEmpty, true as Bool?)

        reader.failNext = true
        await model.load(category: .clothing, reader: reader)
        XCTAssertEqual(model.phase, .error)
        XCTAssertEqual(model.totalText, "0")
        XCTAssertEqual(model.collection?.total, 0)

        let denied = ObjectCardCollectionModel()
        reader.failNext = true
        await denied.load(category: .all, reader: reader)
        XCTAssertEqual(denied.phase, .error)
        XCTAssertEqual(denied.totalText, "—")
        XCTAssertNil(denied.collection)

        let listed = try JSONDecoder().decode(ObjectCardListedData.self, from: Data(ObjectCardSyntheticFixtures.unknownTotalJSON.utf8))
        let unknownReader = ObjectCardScriptedReader(next: .failure(ObjectCardTotalUnknown(cards: listed.cards)))
        await model.load(category: .books, reader: unknownReader)
        XCTAssertEqual(model.phase, .unknown)
        XCTAssertFalse(model.failed)
        XCTAssertNil(model.collection)
        XCTAssertEqual(model.totalText, "—")
        XCTAssertNotEqual(model.totalText, "0")
        XCTAssertEqual(model.withheldCards.map(\.id), ["903"])
    }
    @MainActor func testSessionListWiringKeepsUnknownOffTheCountedCollection() async throws {
        let withheld = ObjectCardTestTransport(json: "{\"code\":200,\"data\":\(ObjectCardSyntheticFixtures.unknownTotalJSON)}")
        let session = try ObjectCardSession(accountID: 4, epoch: 1, token: "synthetic-token")
        let reader = ObjectCardSessionReader(service: try service(withheld), currentSession: { session })
        let model = ObjectCardCollectionModel()
        await model.load(category: .all, reader: reader)
        XCTAssertEqual(model.phase, .unknown)
        XCTAssertNil(model.collection)
        XCTAssertEqual(model.totalText, "—")
        XCTAssertEqual(model.withheldCards.map(\.id), ["903"])
        XCTAssertFalse(model.failed)
        let request = try XCTUnwrap(await withheld.requests.first)
        XCTAssertEqual(request.url?.path, "/api/object-card/list")

        let zero = ObjectCardTestTransport(json: #"{"code":200,"data":{"list":[],"total":0}}"#)
        let zeroReader = ObjectCardSessionReader(service: try service(zero), currentSession: { session })
        await model.load(category: .all, reader: zeroReader)
        XCTAssertEqual(model.phase, .empty)
        XCTAssertEqual(model.totalText, "0")
        XCTAssertEqual(model.collection?.total, 0)
        XCTAssertTrue(model.withheldCards.isEmpty)
    }
}

@MainActor private final class ObjectCardScriptedReader: ObjectCardReading {
    var scope = UUID()
    var isConfigured = true
    var isAuthenticated = true
    var next: Result<ObjectCardCollection, Error>
    var hold = false
    private(set) var parked = false
    private var waiter: CheckedContinuation<Void, Never>?
    init(next: Result<ObjectCardCollection, Error>) { self.next = next }
    func list(category: ObjectCardCategory) async throws -> ObjectCardCollection {
        _ = category
        if hold {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                waiter = continuation
                parked = true
            }
        }
        return try next.get()
    }
    func release() {
        waiter?.resume()
        waiter = nil
    }
}

@MainActor final class ProfileObjectCardsAssociationTests: XCTestCase {
    private final class AccountReader: SocialAccountReading {
        var identity = SocialAccountIdentity(accountID: 81, epoch: 1, role: "player")
        var presentationRevision: UInt64 = 1
        var isConfigured = true
        let isOfflineExample = false
        func publicProfile(memberID: Int) async throws -> SocialPublicProfile { throw APIError.notConfigured }
        func informationList() async throws -> [SocialInformation] { [] }
        func information(id: Int) async throws -> SocialInformation { throw APIError.notConfigured }
        func invitationHistory(page: Int) async throws -> SocialInviteHistory { throw APIError.notConfigured }
    }
    private final class CardsReader: ObjectCardReading {
        var scope = UUID()
        var isConfigured = true
        var isAuthenticated = true
        var reads: [ObjectCardCategory] = []
        var waits = false
        var pending: CheckedContinuation<ObjectCardCollection, Error>?
        func list(category: ObjectCardCategory) async throws -> ObjectCardCollection {
            reads.append(category)
            if waits { return try await withCheckedThrowingContinuation { pending = $0 } }
            return try ObjectCardSyntheticFixtures.collection()
        }
    }
    private let account = AccountReader(), cards = CardsReader()
    private func context(member: Int = 81, current: Bool = true) -> ProfileObjectCardsContext? {
        .capture(memberID: member, accountReader: account, objectReader: cards,
            owner: account.identity, ownerScope: cards.scope, isCurrent: current)
    }
    private func scoped(current: @escaping @MainActor () -> Bool = { true }) throws -> ProfileObjectCardsScopedReader {
        .init(context: try XCTUnwrap(context()), accountReader: account, objectReader: cards, isCurrent: current)
    }
    func testOtherProfileGuestAndRetiredParentCannotAssociate() {
        XCTAssertNil(context(member: 82)); XCTAssertNil(context(member: 0)); XCTAssertNil(context(current: false))
        account.identity = .init(accountID: nil, epoch: 2)
        XCTAssertNil(context()); XCTAssertTrue(cards.reads.isEmpty)
    }
    func testContextBindsBothReaderInstancesAndOriginalScope() throws {
        let original = try XCTUnwrap(context())
        let other = AccountReader()
        let replaced = ProfileObjectCardsContext.capture(memberID: 81, accountReader: other, objectReader: cards,
            owner: account.identity, ownerScope: cards.scope, isCurrent: true)
        XCTAssertNotEqual(original, replaced)
        cards.scope = UUID()
        XCTAssertNil(ProfileObjectCardsContext.capture(memberID: 81, accountReader: account, objectReader: cards,
            owner: account.identity, ownerScope: original.objectScope, isCurrent: true))
    }
    func testConstructionIsInertAndExactCategoryUsesExistingReader() async throws {
        let reader = try scoped()
        XCTAssertTrue(cards.reads.isEmpty)
        let value = try await reader.list(category: .books)
        XCTAssertEqual(cards.reads, [.books]); XCTAssertEqual(value.total, 52)
    }
    func testUnconfiguredAssociationPreservesDisabledStateWithoutReading() async throws {
        cards.isConfigured = false
        let reader = try scoped()
        XCTAssertTrue(reader.isAuthenticated); XCTAssertFalse(reader.isConfigured)
        do { _ = try await reader.list(category: .all); XCTFail("unconfigured read") }
        catch { XCTAssertEqual(error as? APIError, .notConfigured) }
        XCTAssertTrue(cards.reads.isEmpty)
    }
    func testQueuedReadAfterRevisionChangeIsRejected() async throws {
        let reader = try scoped(); account.presentationRevision += 1
        do { _ = try await reader.list(category: .all); XCTFail("retired read") }
        catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertFalse(reader.isAuthenticated); XCTAssertTrue(cards.reads.isEmpty)
    }
    func testSameAccountReloginAndGrantRevocationRetireAssociation() throws {
        let first = try scoped()
        account.identity = .init(accountID: 81, epoch: 2, role: "player")
        XCTAssertFalse(first.associationIsCurrent)
        let second = try scoped(); cards.isConfigured = false
        XCTAssertFalse(second.associationIsCurrent); XCTAssertFalse(second.isAuthenticated)
    }
    func testLateSuccessAndFailureCannotReachRetiredProfile() async throws {
        for failure in [false, true] {
            cards.waits = true
            let reader = try scoped()
            let task = Task { try await reader.list(category: .food) }
            for _ in 0..<100 where cards.pending == nil { await Task.yield() }
            guard let pending = cards.pending else { task.cancel(); XCTFail("request not started"); return }
            account.presentationRevision += 1
            cards.pending = nil
            if failure { pending.resume(throwing: APIError.unauthorized) }
            else { pending.resume(returning: try ObjectCardSyntheticFixtures.collection()) }
            do { _ = try await task.value; XCTFail("stale result") }
            catch { XCTAssertTrue(error is CancellationError) }
        }
    }
    func testRetainedDetailEligibilityClosesOnScopeRotationAndLogout() throws {
        let old = try scoped()
        XCTAssertTrue(old.isAuthenticated)
        cards.scope = UUID()
        XCTAssertFalse(old.isAuthenticated)
        let next = try scoped(); cards.isAuthenticated = false
        XCTAssertFalse(next.isAuthenticated)
        // ObjectCardDetailView checks this flag before rendering retained card data.
    }
    func testParentRetirementPreventsQueuedCollectionRequest() async throws {
        var current = true
        let reader = try scoped(current: { current }); current = false
        do { _ = try await reader.list(category: .all); XCTFail("retired parent") }
        catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertTrue(cards.reads.isEmpty)
    }
}
