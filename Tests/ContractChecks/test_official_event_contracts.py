#!/usr/bin/env python3
"""Local source assertions, not Swift compilation, runtime or live-backend evidence."""
import json
import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]

def read(path):
    return (ROOT / path).read_text()

class OfficialSourceChecks(unittest.TestCase):
    def test_only_seven_source_backed_read_routes(self):
        service = read("Core/OfficialEventService.swift")
        routes = set(re.findall(r'"(api/official/[^"\n]+)"', service))
        expected = {"api/official/events", r"api/official/events/\(id)", "api/official/my-events", "api/official/v2/party-inbox", "api/official/can-publish", "api/official/my-published", r"api/official/broadcast/\(id)/stats"}
        self.assertEqual(routes, expected)
        self.assertEqual(re.findall(r'httpMethod\s*=\s*"([A-Z]+)"', service), ["GET", "GET"])
        self.assertNotIn("request.httpBody =", service)
    def test_read_module_has_no_write_or_real_configuration(self):
        services = "\n".join(p.read_text() for p in (ROOT / "Core").glob("OfficialEvent*.swift"))
        for forbidden in ["api/official/publish", "/signup\"", "/complete\"", "/arrivals\"", "/click\"", "/accept\"", "/decline\"", "URLSession.shared", "Keychain", "UserDefaults"]:
            self.assertNotIn(forbidden, services)
        self.assertNotIn("APIConfiguration(baseURL", read("Core/OfficialEventService.swift"))
    def test_official_and_ordinary_activities_stay_separate(self):
        browser = read("App/OfficialEventsBrowserView.swift")
        self.assertNotIn("ActivityBrowserView(", browser)
        self.assertNotIn("api/activity/", read("Core/OfficialEventService.swift"))
        models = read("Core/OfficialEventContracts.swift")
        self.assertIn("value.status == 2 || value.status == 3", models)
        self.assertIn("value.status == 1", models)
        self.assertIn("case .ended: return value.hasEndedListStatus", models)
        self.assertIn("[5, 6, 9].contains($0)", models)
        self.assertIn("[0, 1, 2, 3, 4, 5, 6, 9].contains($0)", models)
        self.assertIn("|| !value.hasKnownListStatus", models)
        self.assertNotIn("(value.status ?? -1) >= 5", models)
    def test_mine_keyword_uses_same_local_query_and_no_private_search_suppression(self):
        # Source pages/activity/list hides cy-search on tab 3 ("我的"); the hidden keyword
        # must not filter the private list, while the shared query keeps mine search for roam.
        browser = read("App/OfficialEventsBrowserView.swift")
        # R10-PC-C-N10: system `.searchable`, applied only while the tab is searchable (MP pages/activity/list/index.wxml).
        self.assertIn('.searchable(text: $keyword, placement: .navigationBarDrawer(displayMode: .always), prompt: Text("official.search"))', browser)
        self.assertIn('OfficialEventsSearchModifier(enabled: bucket.isSearchable, keyword: $keyword)', browser)
        self.assertNotIn('if !privateList {', browser)
        self.assertIn('private var query: OfficialEventBrowseQuery { .sourceList(bucket: bucket, keyword: keyword) }', browser)
        self.assertIn('let visible = page.visible', browser)
        self.assertIn('OfficialActivityListCoordinator.project(query: query', browser)
        # R7-PC-C3-3: MP EMPTY_COPY has one title line per tab; only the search keeps its second line.
        self.assertIn('detail: query.isSearching ? LocalizedStringKey(query.emptyDetailKey) : nil)', browser)
        self.assertIn('LocalizedStringKey(query.emptyTitleKey)', browser)
        model = read("Core/OfficialEventContracts.swift")
        self.assertIn('let visible = query.visible(rows)', model)
        self.assertIn('.init(bucket: bucket, keyword: bucket.isSearchable ? keyword : "")', model)
        self.assertIn('var isSearchable: Bool { self != .mine }', model)
        self.assertIn('.onChange(of: reader.scope) { _, _ in keyword = "" }', browser)
        self.assertIn('isPrivate: privateList, requestID: privateList ? "mine" : "public"', browser)
        self.assertIn('if privateList { return try await reader.myEvents() }; return try await reader.events(city: nil)', browser)
    def test_session_guards_and_private_guest_short_circuit(self):
        reader = read("Core/OfficialEventReading.swift")
        self.assertIn("guestEpoch: UInt64", reader)
        self.assertIn("fileprivate let token: String?", reader)
        self.assertIn("currentContext() == context, scope == captured", reader)
        self.assertIn("guard !Task.isCancelled", reader)
        self.assertIn("guard isAuthenticated else { throw APIError.unauthorized }", reader)
        self.assertIn("context.isAuthenticated { onUnauthorized(context) }", reader)
        self.assertIn("current != snapshot", reader.replace("context != snapshot", "current != snapshot"))
    def test_view_scope_and_generation_isolation(self):
        screen = read("App/OfficialEventComponents.swift")
        self.assertIn("loadedKey != key || loading", screen)
        self.assertIn("generation == operation, key == captured", screen)
        self.assertIn(".task(id: key)", screen)
        self.assertIn(".onDisappear { generation &+= 1", screen)
        detail = read("App/OfficialEventDetailView.swift")
        self.assertIn("reader.isAuthenticated ? event.participationKey : event.statusKey", detail)
        self.assertIn("if reader.isAuthenticated", detail)
    def test_permission_business_code_and_status_field_semantics(self):
        service = read("Core/OfficialEventService.swift")
        self.assertIn('envelope?.code == 401', service)
        self.assertIn('无官方发布权限', service)
        self.assertIn('通知不存在', service)
        self.assertIn('guard code == 200 else', service)
        model = read("Core/OfficialEventContracts.swift")
        self.assertIn('status = c.text("status")', model)
        self.assertNotIn('c.text("state")', model)
    def test_every_static_user_facing_key_has_two_languages(self):
        # Active keys live in the app catalog; the historical module snapshot is
        # still checked byte-for-value below for every pre-existing entry.
        catalog = json.loads(read("Resources/Localizable.xcstrings"))["strings"]
        # Accessibility identifiers (OfficialMineAccessibility / OfficialOrganizer snapshot ids), not catalog keys.
        identifiers = {"official.published.loading", "official.published.empty", "official.published.empty.events",
                       "official.published.empty.broadcasts", "official.published.error", "official.published.unknown",
                       "official.organizer.empty", "official.organizer.unknown", "official.organizer.counts"}
        ignored = identifiers | {"official.issue", "official.browser", "official.filter", "official.event.", "official.detail.content", "official.participationState", "official.mission.", "official.invite.", "official.inbox.content", "official.broadcast.", "official.published.content", "official.stats.content", "official.fixture.guest", "official.fixture.account", "official.bucket.", "official.organizer.content", "official.organizer.denied", "official.organizer.error", "official.organizer.loading", "official.organizer.formError", "official.organizer.recovery", "official.organizer.result", "official.organizer.header", "official.organizer.resume.reason", "official.detail.cta.roam"}
        literals = set()
        for directory in ["App", "Core"]:
            for path in (ROOT / directory).glob("Official*.swift"):
                literals.update(re.findall(r'"(official\.[A-Za-z0-9_.]+)"', path.read_text()))
        self.assertFalse((literals - ignored) - set(catalog), (literals - ignored) - set(catalog))
        for key in literals - ignored:
            entry = catalog[key]
            for language in ["en", "zh-Hans"]:
                self.assertTrue(entry["localizations"][language]["stringUnit"]["value"], key)
    def test_common_card_and_no_unbounded_animations(self):
        text = read("App/OfficialEventComponents.swift") + read("App/OfficialEventsBrowserView.swift")
        self.assertIn("QuestifyImageEntityCard", text)
        self.assertIn("QuestifyCardButtonStyle", text)
        for forbidden in ["Timer.publish", "repeatForever", ".animation(", "withAnimation("]:
            self.assertNotIn(forbidden, "\n".join(p.read_text() for p in (ROOT / "App").glob("Official*.swift")))
        self.assertIn("ForEach(visible)", text)
        self.assertIn(".frame(minHeight: 44)", text)
    def test_fixtures_are_valid_synthetic_json_without_remote_media(self):
        source = read("Core/OfficialEventSyntheticFixtures.swift")
        fixtures = re.findall(r'#"""\n(.*?)\n\s*"""#', source, re.S)
        self.assertEqual(len(fixtures), 5)
        for fixture in fixtures:
            json.loads(fixture)
            self.assertNotIn("https://", fixture)
            self.assertNotIn("token", fixture.lower())
        self.assertEqual(json.loads(json.loads(fixtures[0])["rewardJson"])["settleXp"], 25)
    def test_integrated_session_preserves_regional_and_cn_protected_gates(self):
        session = read("App/AppSession.swift")
        start = session.index('if let scope, let regional, let configuration=regional.apiConfiguration')
        end = session.index('} else {', start)
        self.assertIn('officialEventService=OfficialEventService(configuration:configuration,transport:transport)', session[start:end])
        self.assertIn('officialEventService=nil', session[end:])
        self.assertIn('self.currentOfficialContext == captured', session)
        self.assertIn('OfficialReadContext(guestEpoch:gate.currentStamp,viewerRevision:compositionViewerRevision,', session)
        self.assertIn('private let accountSessionService: CNAccountSessionService?', session)
        self.assertIn('growthCenterService=GrowthCenterService', session)
    def test_integrated_entry_scope_fixture_and_catalog(self):
        home = read("App/SessionHomeFeedView.swift")
        self.assertEqual(home.count('accessibilityIdentifier("homeFeed.openOfficialEvents")'), 1)
        self.assertIn('.id(session.officialEventReader.scope)', home)
        self.assertIn('.onChange(of:session.officialEventReader.scope)', home)
        self.assertIn('case .officialEvents: OfficialFixtureHostView()', read("App/ModuleFixtureSupport.swift"))
        expected = json.loads(read("docs/official-event-localizations.json"))["strings"]
        actual = json.loads(read("Resources/Localizable.xcstrings"))["strings"]
        for key, value in expected.items(): self.assertEqual(actual[key], value)
        issue = read("App/OfficialEventComponents.swift")
        self.assertNotIn('}.padding().accessibilityIdentifier("official.issue")', issue)
    def test_authored_tests_cover_lifecycle_and_ui_states(self):
        core = read("Tests/CoreTests/OfficialEventTests.swift")
        ui = read("Tests/AppUITests/OfficialEventFlowTests.swift")
        self.assertGreaterEqual(len(re.findall(r'func test\w+', core)), 20)
        self.assertEqual(len(re.findall(r'func test\w+', ui)), 13)
        for text in ["testAccountEpochTokenAndGuestTransitionsDropSuccessAnd401", "testGuestEpochChangeInvalidatesPublicReadEvenAfterRoundTrip", "testCancelledReadNeverExpiresCurrentSession"]:
            self.assertIn(text, core)
        self.assertIn("testSignOutImmediatelyHidesPrivateInvitationsAndCanReenter", ui)
        self.assertIn("testPublisherDenialIsNotRetryableFailure", ui)
        self.assertNotRegex(core, r'XCTAssert\w+\(try await')

    def test_activity_list_page_states_and_string_spec(self):
        model = read("Core/OfficialEventContracts.swift")
        self.assertIn("case loading, empty, error, unknown, ready", model)
        self.assertIn('public static let unknownMark = "—"', model)
        self.assertIn("summaryCount: visible.count", model)
        self.assertIn("canPublish == true", model)
        for flag in ("showsMerchantChoice", "paymentEnabled", "payoutEnabled", "withdrawalEnabled", "virtualGoodsEnabled"):
            self.assertNotIn(flag + " = true", model)
            self.assertNotIn(flag + "=true", model)
        service = read("Core/OfficialEventService.swift")
        routes = set(re.findall(r'"(api/official/[^"\n]+)"', service))
        self.assertEqual(len(routes), 7)
        self.assertIn("#if DEBUG", read("Core/OfficialEventSyntheticFixtures.swift"))
        spec_path = "docs/release/ui-strings-pages-activity-list-index.json"
        spec = json.loads(read(spec_path))
        self.assertEqual(spec["page"], "pages/activity/list/index")
        catalog = json.loads(read("Resources/Localizable.xcstrings"))["strings"]
        keys = []
        for item in spec["strings"]:
            key = item["key"]
            keys.append(key)
            self.assertTrue(item["en"])
            self.assertTrue(item["zh-Hans"])
            self.assertNotIn("http://", item["en"])
            self.assertNotIn("http://", item["zh-Hans"])
            self.assertNotIn("https://", item["en"])
            self.assertNotIn("https://", item["zh-Hans"])
            entry = catalog[key]["localizations"]
            self.assertEqual(entry["en"]["stringUnit"]["value"], item["en"])
            self.assertEqual(entry["zh-Hans"]["stringUnit"]["value"], item["zh-Hans"])
        self.assertEqual(len(keys), len(set(keys)))
        ids = [item["id"] for item in spec["accessibilityIdentifiers"]]
        browser = read("App/OfficialEventsBrowserView.swift")
        components = read("App/OfficialEventComponents.swift")
        # R10-PC-C-N10: official.search is now the system search bar (`.searchable`), which takes no identifier;
        # the UI test finds it as `app.searchFields.firstMatch`.
        self.assertIn("official.search", ids)
        self.assertIn('prompt: Text("official.search")', browser)
        for identifier in ("official.filter", "official.publishedLink", "official.inboxLink", "officialList.summary"):
            self.assertIn(identifier, ids)
            self.assertIn('accessibilityIdentifier("%s")' % identifier, browser)
        for identifier in ("official.issue", "official.signIn", "official.retry"):
            self.assertIn(identifier, ids)
            self.assertIn('accessibilityIdentifier("%s")' % identifier, components)
        self.assertIn("official.event.", ids)
        self.assertIn('accessibilityIdentifier("official.event.\\(event.id)")', browser)
        core = read("Tests/CoreTests/OfficialEventTests.swift")
        self.assertIn("testActivityListPageStatesKeepUnknownCountsAsEmDash", core)

if __name__ == "__main__":
    unittest.main(verbosity=2)
