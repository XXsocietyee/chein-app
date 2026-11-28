"""K50-R5 cold start. Measures the deferred-vs-critical split from the class weights.

No device and no xcodebuild. The weights live in Core/ColdStartFirstFrameSplit.swift.
This check parses them, runs the same virtual clock as ColdStartFirstFrameSplit.measure,
and checks the call sites match that split. Home resume, bootstrap, and the session
graph the home reader uses stay off the deferral gate.
"""
import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
SPLIT = ROOT / 'Core' / 'ColdStartFirstFrameSplit.swift'
LANE = re.compile(
    r'ColdStartLaneWeight\(lane: \.(\w+), phase: \.(\w+), iphone12Milliseconds: (\d+)\)'
)

EXPECTED = {
    'notificationDelegate': ('critical', 15),
    'controlCenterRoute': ('critical', 5),
    'homeSessionGraph': ('critical', 640),
    'homeFeedRequiredReads': ('critical', 180),
    'orphanedLiveActivities': ('deferred', 280),
    'planActivityObservation': ('deferred', 240),
    'externalGameCatalog': ('deferred', 300),
    'personalLocationMonitor': ('deferred', 90),
    'nonHomeTabBodies': ('deferred', 700),
}
REQUIRED = {'homeSessionGraph', 'homeFeedRequiredReads'}
BUDGET = 1500


def parse_lanes(text):
    found = LANE.findall(text)
    return [(name, phase, int(ms)) for name, phase, ms in found]


def measure(lanes):
    """Same clock as ColdStartFirstFrameSplit.measure: critical, then the frame, then deferred."""
    now = 0
    critical = 0
    for _, phase, ms in lanes:
        if phase == 'critical':
            now += ms
            critical += ms
    frame = now
    deferred = 0
    starts = {}
    for name, phase, ms in lanes:
        if phase == 'deferred':
            starts[name] = now
            now += ms
            deferred += ms
    return critical, deferred, frame, starts


class K50R05ColdStartTests(unittest.TestCase):
    def setUp(self):
        self.split = SPLIT.read_text()
        self.lanes = parse_lanes(self.split)
        self.app = (ROOT / 'App' / 'QuestifyApp.swift').read_text()
        self.gate = (ROOT / 'App' / 'ColdStartAfterFirstFrame.swift').read_text()

    def test_virtual_clock_keeps_the_iphone12_budget(self):
        self.assertEqual([(name, phase, ms) for name, phase, ms in self.lanes], [
            (name, EXPECTED[name][0], EXPECTED[name][1]) for name in EXPECTED
        ])
        self.assertIn('public static let budgetMilliseconds = 1500', self.split)
        critical, deferred, frame, starts = measure(self.lanes)
        self.assertEqual(critical, 840)
        self.assertEqual(deferred, 1610)
        self.assertEqual(frame, critical)
        self.assertLessEqual(critical, BUDGET)
        self.assertGreater(critical + deferred, BUDGET)
        self.assertTrue(starts)
        self.assertTrue(all(start >= frame for start in starts.values()))
        for name in REQUIRED:
            self.assertEqual(EXPECTED[name][0], 'critical')
        folded = [(name, 'critical' if name == 'nonHomeTabBodies' else phase, ms) for name, phase, ms in self.lanes]
        folded_critical, _, _, _ = measure(folded)
        self.assertGreater(folded_critical, BUDGET)

    def test_deferred_symbols_are_off_app_init(self):
        init = self.app.split('init() {', 1)[1].split('#if DEBUG', 1)[0]
        self.assertIn('MPNotificationTapRouter.shared.attach()', init)
        self.assertIn('QuestWidgetBoardPublisher.installControlRoute()', init)
        self.assertNotIn('endOrphanedActivities', self.app)
        self.assertNotIn('QuestPlanActivityCenter.shared.start', self.app)
        self.assertIn('.modifier(ColdStartDeferredLaunch())', self.app)
        open_body = self.gate.split('static func open()', 1)[1]
        self.assertIn('QuestLiveActivityCenter.shared.endOrphanedActivities()', open_body)
        self.assertIn('QuestPlanActivityCenter.shared.start()', open_body)
        self.assertLess(open_body.index('pending.forEach'), open_body.index('endOrphanedActivities'))
        self.assertIn('DispatchQueue.main.async { ColdStartAfterFirstFrame.open() }', self.gate)

    def test_catalog_location_and_other_tabs_wait(self):
        catalog = (ROOT / 'App' / 'ExternalGameSession.swift').read_text()
        body = catalog.split('func body(content: Content)', 1)[1].split('static func refresh', 1)[0]
        self.assertLess(body.index('waitUntilOpen()'), body.index('Self.refresh(session)'))
        self.assertIn('pastFirstFrame ? session.personalLocationShareHost : nil', self.app)
        self.assertIn('guard pastFirstFrame else { return }', self.app)
        for tab in ('.roam', '.publish', '.club', '.mine'):
            self.assertIn('deferredTab(%s)' % tab, self.app)
        self.assertNotIn('deferredTab(.home)', self.app)
        self.assertIn('selectedTab == tab || nonHomeTabsReady', self.app)
        self.assertIn('DispatchQueue.main.async { nonHomeTabsReady = true }', self.app)

    def test_first_screen_required_reads_stay_off_the_gate(self):
        home = (ROOT / 'App' / 'HomeFeedView.swift').read_text()
        session_home = (ROOT / 'App' / 'SessionHomeFeedView.swift').read_text()
        session = (ROOT / 'App' / 'AppSession.swift').read_text()
        self.assertIn(
            '.task(id: binding) { await model.resume(reader: reader, query: query, available: unavailableMessageKey == nil, expectedBinding: binding) }',
            home,
        )
        self.assertNotIn('ColdStartAfterFirstFrame', home)
        self.assertIn('.task(id:session.homeFeedReader.scope) { await cityConsent.refresh(session) }', session_home)
        self.assertIn('.task(id:session.ticketWalletReader.scope) { await reloadTodayTicket() }', session_home)
        self.assertIn('.task(id:session.sessionRevision) { await cityConsent.refresh(session) }', session_home)
        self.assertNotIn('ColdStartAfterFirstFrame', session_home)
        self.assertIn('.task { await session.bootstrap() }', self.app)
        self.assertNotIn('waitUntilOpen()', (ROOT / 'App' / 'HomeFeedView.swift').read_text())
        self.assertNotIn('waitUntilOpen()', session_home)
        self.assertIn(
            'homeFeedService=composition.reviewed?.reads.contains(.homeAndSearch) == true ? HomeFeedService(configuration:configuration,transport:transport) : nil',
            session,
        )
        self.assertNotIn('homeFeedService', self.gate)
        self.assertLessEqual(len(session.splitlines()), 7977)

    def test_launch_constraints_unchanged(self):
        for path in (
            'Core/ColdStartFirstFrameSplit.swift',
            'App/ColdStartAfterFirstFrame.swift',
            'App/QuestifyApp.swift',
            'App/ExternalGameSession.swift',
        ):
            self.assertNotIn('String(localized:', (ROOT / path).read_text())
        leases = (ROOT / 'App' / 'ReviewedPlayerWriteLeases.swift').read_text()
        self.assertIn(
            'publisherReads: true, devices: Self.playDevices, sensors: Self.playSensors,\n'
            '            artworkHosts: Self.playArtworkHosts(apiBase: context.baseURL), shopNPCWrites: true',
            leases,
        )
        launch = (ROOT / 'Core' / 'PlayerLaunch.swift').read_text()
        self.assertIn('#else\n    public static let merchantCenterEnabled = false\n    #endif', launch)
        money = (ROOT / 'Core' / 'ChinaReviewedRouteCapability.swift').read_text()
        self.assertIn('public enum ReleaseMoneyWriteSwitch {', money)
        self.assertIn('public static var paymentEnabled: Bool { testDerivation?(.payment) ?? false }', money)
