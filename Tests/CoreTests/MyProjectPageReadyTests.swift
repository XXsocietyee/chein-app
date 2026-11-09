import XCTest
@testable import QuestifyCore

/// Page readout for subpackageA/pages/myproject. Counts that the server omits stay an em dash.
@MainActor final class MyProjectPageReadyTests: XCTestCase {
    private func project(_ json: String) throws -> CreatorContentProject {
        try JSONDecoder().decode(CreatorContentProject.self, from: Data(json.utf8))
    }

    private func page(_ json: String) throws -> CreatorContentProjectPage {
        struct Envelope: Decodable { let data: CreatorContentProjectPage }
        return try JSONDecoder().decode(Envelope.self, from: Data(json.utf8)).data
    }

    func testMissingAndNullCountsAreUnknownEmDashNotZero() throws {
        let missing = try project(#"{"id":21,"bizType":"topic","title":"Synthetic topic"}"#)
        XCTAssertEqual(missing.signupCountFact, .unknown)
        XCTAssertEqual(missing.viewCountFact, .unknown)
        XCTAssertEqual(missing.signupCountFact.displayText, "\u{2014}")
        XCTAssertEqual(missing.viewCountFact.displayText, "\u{2014}")
        XCTAssertNotEqual(missing.signupCountFact.displayText, "0")
        XCTAssertNotEqual(missing.signupCountFact.displayText, "-")
        let facts = MyProjectPageRowFacts(missing)
        XCTAssertEqual(facts.signupText, MyProjectCountFact.unknownText)
        XCTAssertEqual(facts.viewText, MyProjectCountFact.unknownText)
        XCTAssertEqual(facts.id, "topic:21")

        let nulled = try project(#"{"id":22,"bizType":"topic","signupCount":null,"viewCount":null}"#)
        XCTAssertEqual(nulled.signupCountFact, .unknown)
        XCTAssertEqual(nulled.viewCountFact, .unknown)
        XCTAssertEqual(nulled.signupCount, 0)
        XCTAssertEqual(nulled.viewCount, 0)
        XCTAssertNotEqual(MyProjectPageRowFacts(nulled).signupText, "0")
    }

    func testLiteralZeroStaysZeroAndNegativeStaysLiteral() throws {
        let zero = try project(#"{"id":11,"bizType":"topic","signupCount":0,"viewCount":0}"#)
        XCTAssertEqual(zero.signupCountFact, .value(0))
        XCTAssertEqual(zero.viewCountFact, .value(0))
        XCTAssertEqual(zero.signupCountFact.displayText, "0")
        XCTAssertEqual(MyProjectPageRowFacts(zero).viewText, "0")

        let negative = try project(#"{"id":11,"bizType":"topic","signupCount":-3,"viewCount":4}"#)
        XCTAssertEqual(negative.signupCountFact, .value(-3))
        XCTAssertEqual(negative.signupCountFact.displayText, "-3")
        XCTAssertEqual(negative.viewCountFact.displayText, "4")
        XCTAssertEqual(negative.signupCount, -3)
    }

    func testWrongCountTypeStillFailsTheRow() {
        for json in [
            #"{"id":1,"bizType":"topic","signupCount":"2"}"#,
            #"{"id":1,"bizType":"topic","signupCount":"0"}"#,
            #"{"id":1,"bizType":"topic","viewCount":true}"#,
            #"{"id":1,"bizType":"topic","signupCount":1.5}"#,
        ] {
            XCTAssertThrowsError(try project(json))
        }
    }

    func testFixtureReadyEmptyAndUnknownCounts() async throws {
        let reader = CreatorContentFixtureReader()
        let coordinator = MyProjectPageCoordinator(reader: reader)

        reader.projectsJSON = MyProjectFixtureData.ready
        await coordinator.reload(query: .init(), tab: .topic)
        XCTAssertEqual(coordinator.phase, .ready)
        XCTAssertEqual(coordinator.titleKey, "creatorContent.projects")
        XCTAssertEqual(coordinator.accessibilityIdentifier, MyProjectPageAccessibility.ready.rawValue)
        XCTAssertEqual(coordinator.rows.map(\.id), ["topic:11"])
        XCTAssertEqual(coordinator.rows.map(\.signupText), ["2"])
        XCTAssertEqual(coordinator.rows.map(\.viewText), ["0"])

        await coordinator.reload(query: .init(), tab: .activity)
        XCTAssertEqual(coordinator.phase, .ready)
        XCTAssertEqual(coordinator.rows.map(\.signupText), ["0"])
        XCTAssertEqual(coordinator.rows.map(\.viewText), ["4"])

        reader.projectsJSON = MyProjectFixtureData.empty
        await coordinator.reload(query: .init(), tab: .topic)
        XCTAssertEqual(coordinator.phase, .empty)
        XCTAssertTrue(coordinator.rows.isEmpty)
        XCTAssertEqual(coordinator.emptyTitleKey, "myProject.empty.topic")
        XCTAssertEqual(coordinator.emptyDetailKey, "myProject.empty.topicDetail")
        XCTAssertEqual(coordinator.titleKey, "myProject.empty.topic")
        XCTAssertEqual(coordinator.accessibilityIdentifier, MyProjectPageAccessibility.empty.rawValue)

        reader.projectsJSON = MyProjectFixtureData.unknownCounts
        await coordinator.reload(query: .init(), tab: .topic)
        XCTAssertEqual(coordinator.phase, .ready)
        XCTAssertEqual(coordinator.rows.map(\.signupText), [MyProjectFixtureData.unknownMark])
        XCTAssertEqual(coordinator.rows.map(\.viewText), ["\u{2014}"])
        XCTAssertNotEqual(coordinator.rows.first?.signupText, "0")

        reader.projectsJSON = MyProjectFixtureData.nullCounts
        await coordinator.reload(query: .init(), tab: .activity)
        XCTAssertEqual(coordinator.phase, .empty)
        XCTAssertEqual(coordinator.emptyTitleKey, "myProject.empty.activity")
        XCTAssertNil(coordinator.emptyDetailKey)
        await coordinator.reload(query: .init(), tab: .activity, canPublishActivity: true)
        XCTAssertEqual(coordinator.emptyDetailKey, "myProject.empty.activityPublish")
        XCTAssertEqual(coordinator.titleKey, "myProject.empty.activity")
    }

    func testTemplateTabStaysUnknownAndDoesNotReadProjects() async {
        let reader = CreatorContentFixtureReader()
        let coordinator = MyProjectPageCoordinator(reader: reader)
        await coordinator.reload(query: .init(type: "template"), tab: .template)
        XCTAssertEqual(coordinator.phase, .unknown)
        XCTAssertNil(coordinator.titleKey)
        XCTAssertEqual(coordinator.unknownText, "\u{2014}")
        XCTAssertNotEqual(coordinator.unknownText, "0")
        XCTAssertTrue(coordinator.rows.isEmpty)
        XCTAssertEqual(reader.readCount, 0)
        XCTAssertEqual(coordinator.accessibilityIdentifier, MyProjectPageAccessibility.unknown.rawValue)
        XCTAssertNil(coordinator.issue)
    }

    func testSignedOutAndUnconfiguredDoNotRead() async {
        let signedOut = CreatorContentFixtureReader()
        signedOut.signOut()
        let signedOutPage = MyProjectPageCoordinator(reader: signedOut)
        await signedOutPage.reload(query: .init(), tab: .topic)
        XCTAssertEqual(signedOutPage.phase, .error)
        XCTAssertEqual(signedOutPage.issue, .login)
        XCTAssertEqual(signedOutPage.titleKey, "creatorContent.signInRequired")
        XCTAssertEqual(signedOut.readCount, 0)
        XCTAssertEqual(signedOutPage.accessibilityIdentifier, MyProjectPageAccessibility.error.rawValue)

        let probe = PhaseProbe(configured: false, authenticated: true)
        let unconfigured = MyProjectPageCoordinator(reader: probe)
        await unconfigured.reload(query: .init(), tab: .topic)
        XCTAssertEqual(unconfigured.phase, .error)
        XCTAssertEqual(unconfigured.issue, .notConfigured)
        XCTAssertEqual(unconfigured.titleKey, "creatorContent.notConfigured")
        XCTAssertEqual(probe.reads, 0)
    }

    func testFailureClearsRowsAndCancellationStaysLoading() async throws {
        let reader = CreatorContentFixtureReader()
        reader.projectsJSON = MyProjectFixtureData.ready
        let coordinator = MyProjectPageCoordinator(reader: reader)
        await coordinator.reload(query: .init(), tab: .topic)
        XCTAssertEqual(coordinator.phase, .ready)
        reader.failure = .unauthorized
        await coordinator.reload(query: .init(), tab: .topic)
        XCTAssertEqual(coordinator.phase, .error)
        XCTAssertEqual(coordinator.issue, .login)
        XCTAssertTrue(coordinator.rows.isEmpty)

        let probe = PhaseProbe()
        probe.result = .failure(URLError(.notConnectedToInternet))
        let failing = MyProjectPageCoordinator(reader: probe)
        await failing.reload(query: .init(), tab: .topic)
        XCTAssertEqual(failing.phase, .error)
        XCTAssertEqual(failing.issue, .network)
        XCTAssertEqual(failing.titleKey, "creatorContent.network")
        XCTAssertTrue(failing.rows.isEmpty)

        probe.reads = 0
        probe.result = .failure(CancellationError())
        let cancelled = MyProjectPageCoordinator(reader: probe)
        await cancelled.reload(query: .init(), tab: .topic)
        XCTAssertEqual(probe.reads, 1)
        XCTAssertEqual(cancelled.phase, .loading)
        XCTAssertNil(cancelled.issue)
        XCTAssertEqual(cancelled.titleKey, "creatorContent.loading")
        XCTAssertEqual(cancelled.accessibilityIdentifier, MyProjectPageAccessibility.loading.rawValue)
        XCTAssertTrue(cancelled.rows.isEmpty)
    }

    func testLoadingIsVisibleAndInvalidQueryDoesNotRead() async throws {
        let probe = PhaseProbe()
        probe.result = .success(try page(MyProjectFixtureData.empty))
        let coordinator = MyProjectPageCoordinator(reader: probe)
        probe.coordinator = coordinator
        await coordinator.reload(query: .init(), tab: .topic)
        XCTAssertEqual(probe.phaseDuringRead, .loading)
        XCTAssertEqual(coordinator.phase, .empty)
        XCTAssertEqual(probe.reads, 1)

        probe.reads = 0
        await coordinator.reload(query: .init(type: "guessed"), tab: .topic)
        XCTAssertEqual(probe.reads, 0)
        XCTAssertEqual(coordinator.phase, .error)
        XCTAssertEqual(coordinator.issue, .failure)
        XCTAssertEqual(coordinator.titleKey, "creatorContent.failed")
    }

    func testPageAccessibilityIdentifiers() {
        XCTAssertEqual(MyProjectPageAccessibility.loading.rawValue, "myProject.page.loading")
        XCTAssertEqual(MyProjectPageAccessibility.empty.rawValue, "myProject.page.empty")
        XCTAssertEqual(MyProjectPageAccessibility.error.rawValue, "myProject.page.error")
        XCTAssertEqual(MyProjectPageAccessibility.unknown.rawValue, "myProject.page.unknown")
        XCTAssertEqual(MyProjectPageAccessibility.ready.rawValue, "myProject.page.ready")
        XCTAssertEqual(MyProjectPageAccessibility.signup, "myProject.page.signup")
        XCTAssertEqual(MyProjectPageAccessibility.views, "myProject.page.views")
    }
}

@MainActor private final class PhaseProbe: CreatorContentReading {
    let scope = UUID()
    var isConfigured: Bool
    var isAuthenticated: Bool
    var isOfflineExample: Bool { false }
    var reads = 0
    var phaseDuringRead: MyProjectPagePhase?
    weak var coordinator: MyProjectPageCoordinator?
    var result: Result<CreatorContentProjectPage, Error> = .success(.init(rows: [], total: 0))

    init(configured: Bool = true, authenticated: Bool = true) {
        isConfigured = configured
        isAuthenticated = authenticated
    }

    func projects(query: CreatorContentQuery) async throws -> CreatorContentProjectPage {
        reads += 1
        phaseDuringRead = coordinator?.phase
        return try result.get()
    }

    func center() async throws -> CreatorContentCenter { throw APIError.notConfigured }
}
