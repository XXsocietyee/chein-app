"""WP-11 source contracts. Each test names the completeness row it closes."""
import pathlib
import plistlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]


def swift_sources(*dirs):
    for d in dirs:
        yield from sorted((ROOT / d).rglob('*.swift'))


class WP11SessionLocationContracts(unittest.TestCase):
    def read(self, relative):
        return (ROOT / relative).read_text()

    def test_own_d07a_plist_declares_only_session_location_background_and_when_in_use(self):
        info = plistlib.loads((ROOT / 'Config/Info.plist').read_bytes())
        self.assertEqual(info['UIBackgroundModes'], ['audio', 'location'])  # P-083 story audio
        base = self.read('Config/Base.xcconfig')
        self.assertIn('INFOPLIST_KEY_NSLocationWhenInUseUsageDescription', base)
        for source in swift_sources('App', 'Core'):
            text = source.read_text()
            self.assertNotIn('requestAlwaysAuthorization', text, str(source))
            if 'allowsBackgroundLocationUpdates = true' in text:
                # Only the session tracker turns it on, and only behind the declared-mode guard.
                self.assertEqual(source.name, 'SessionBackgroundLocationTracker.swift')
                self.assertIn('if background, Self.declaresBackgroundLocationMode', text)

    def test_own_d07a_zh_and_en_purpose_strings_describe_session_background_and_no_sharing(self):
        catalog = self.read('Resources/InfoPlist.xcstrings')
        self.assertIn('keeps recording in the background', catalog)
        self.assertIn('never shared with other players', catalog)
        self.assertIn('锁屏后仍会记录轨迹', catalog)
        self.assertIn('不会把你的位置分享给其他玩家', catalog)

    def test_own_d07bc_play_and_roam_hold_the_tracker(self):
        play = self.read('App/PlayExperienceView.swift')
        self.assertIn('.modifier(PlaySessionLocationHold(', play)
        tracker = self.read('App/SessionBackgroundLocationTracker.swift')
        self.assertIn('ledger.acquire(next, foregroundOnly: true', tracker)
        self.assertIn('acquire(Self.key, foregroundOnly: false', tracker)
        session = self.read('App/AppSession.swift')
        self.assertIn('location = SessionTrackedRoamLocationProvider(owner:', session)

    def test_own_d07e_privacy_pages_show_holds_with_stop(self):
        for page in ('App/PrivacyProtectionView.swift', 'App/SettingsPrivacyLocationView.swift'):
            self.assertIn('SessionLocationHoldsSection()', self.read(page))
        self.assertIn('ledger.revoke(purpose)', self.read('App/SessionLocationHoldsSection.swift'))
        self.assertIn('SessionBackgroundLocationTracker.shared.ledger.revoke(.roam)', self.read('App/AppSessionRoamConsent.swift'))

    def test_own_d07f_personal_location_share_approvals_stay_nil(self):
        """Closes the native side of OWN-OPT-052: no production code installs a sharing approval."""
        session = self.read('App/AppSession.swift')
        for name in ('personalLocationShareReadApproval', 'personalLocationShareWriteApproval', 'personalLocationShareCaptureApproval'):
            self.assertRegex(session, r'private var ' + name + r': \w+\? = nil')
        callers = [str(p) for p in swift_sources('App', 'Core')
                   if 'installReviewedPersonalLocationShareApprovals(' in p.read_text()
                   and 'func installReviewedPersonalLocationShareApprovals' not in p.read_text()]
        self.assertEqual(callers, [])
        host = self.read('App/PersonalLocationShareHost.swift')
        for name in ('readApproval', 'writeApproval', 'captureApproval'):
            self.assertRegex(host, name + r': @escaping \(\) -> \w+\? = \{ nil \}')

    def test_own_10_3c_schema_has_no_runtime_loader_or_validated_claim(self):
        project = self.read('Questify.xcodeproj/project.pbxproj')
        self.assertNotIn('content-schema', project)
        literal = re.compile(r'"[^"\n]*content-schema[^"\n]*"')
        for source in swift_sources('App', 'Core'):
            code = '\n'.join(line for line in source.read_text().splitlines() if not line.strip().startswith('//'))
            self.assertIsNone(literal.search(code), str(source))
        for path in list((ROOT / 'Resources').glob('*.xcstrings')) + list(swift_sources('App', 'Core')):
            text = path.read_text().lower()
            for claim in ('validated by schema', 'runtime validated', '运行时已校验'):
                self.assertNotIn(claim, text, str(path))

    def test_own_d01c_app_and_core_have_no_client_point_deduct_rate(self):
        for source in swift_sources('App', 'Core'):
            self.assertNotIn('pointDeductRate', source.read_text(), str(source))

    def test_own_opt042b_countdown_does_not_tick_from_the_device_clock(self):
        screen = self.read('App/PlayKitScreen.swift')
        self.assertIn('Text(verbatim: "—")', screen)
        self.assertNotIn('TimelineView(.periodic(from: .now, by: 1))', screen)
        advanced = self.read('App/PlayAdvancedView.swift')
        self.assertIn('LabeledContent("playx.advanced.remaining") { Text(verbatim: "—") }', advanced)
        self.assertNotIn('timeIntervalSince1970 * 1000', advanced)
        window = self.read('Core/NativeTimeWindowContract.swift')
        self.assertIn('nextOpenAt.timeIntervalSince1970 - serverNow.timeIntervalSince1970', window)
        reminder = self.read('App/NativeMotionReminderViews.swift')
        self.assertIn('countdown(window.countdownSeconds)', reminder)
        self.assertNotIn('nextOpenAt.timeIntervalSince(context.date)', reminder)
        challenge = self.read('App/PlayKitTimedChallengeView.swift')
        self.assertIn('if kind == .countdown { return "—" }', challenge)
        self.assertNotIn('if kind == .countdown, elapsed >=', challenge)

    def test_own_opt072_reference_is_recorded_and_shown(self):
        self.assertIn('RequestReferenceLedger.shared.record(http)', self.read('Core/AuthService.swift'))
        self.assertIn('RequestReferenceRow(pathFragment: "/api/play/")', self.read('App/PlayExperienceView.swift'))


if __name__ == '__main__':
    unittest.main()
