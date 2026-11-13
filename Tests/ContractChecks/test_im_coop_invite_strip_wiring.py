"""Row 29 keeps one coop-invite strip factory call. Row 30 is a local invite-alert switch."""
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class IMCoopInviteStripWiringTests(unittest.TestCase):
    def read(self, name):
        return (ROOT / name).read_text()

    def test_message_list_calls_factory_once_and_wires_the_local_reminder(self):
        source = self.read('App/SessionMessagingEntry.swift')
        self.assertEqual(source.count('IMCoopInviteStripFactory.make('), 1)
        self.assertIn(
            'IMCoopInviteStripFactory.make(reader: session.cooperationReader)',
            source,
        )
        self.assertEqual(source.count('.environment(\\.imInviteReminder, inviteReminder)'), 1)
        self.assertIn('@StateObject private var inviteReminder = IMInviteReminderController()', source)
        for name in ('App/AppSession.swift', 'App/AppCompositionRoot.swift', 'Core/ChinaReviewedRouteCapability.swift'):
            text = self.read(name)
            self.assertNotIn('imInviteReminder', text)
            self.assertNotIn('IMInviteReminder', text)
        self.assertNotIn('inviteList', self.read('App/AppSession.swift'))
        self.assertNotIn('imCoopInviteStrip', self.read('App/AppSession.swift'))
        self.assertNotIn('imCoopInviteStrip', self.read('App/AppCompositionRoot.swift'))

    def test_strip_load_uses_coop_list_only_on_the_session_reader(self):
        reader = self.read('Core/CooperationReading.swift')
        start = reader.index('public func inviteList()')
        body = reader[start:reader.index('public func detail(', start)]
        self.assertIn('invitations(token: $1)', body)
        self.assertNotIn('inbox(direction:', body)
        self.assertNotIn('pool(', body)
        self.assertNotIn('candidates(', body)
        view = self.read('App/IMCoopInviteStripView.swift')
        self.assertIn('reader.inviteList()', view)
        self.assertIn('IMInviteReminderToggle()', view)

    def test_reminder_is_local_permission_not_a_server_or_push_topic(self):
        source = self.read('App/IMInviteReminderController.swift')
        self.assertIn('CYPermissionSystemPrompt.precede(.notification)', source)
        self.assertIn('guard Self.hasWindowScene else { return .unavailable }', source)
        self.assertIn('requestAuthorization(options: [.alert, .sound, .badge])', source)
        self.assertIn('case .unknown: return .unknown', source)
        self.assertNotIn('registerForRemoteNotifications', source)
        self.assertNotIn('coopInvited', source)
        self.assertNotIn('api/', source)
        self.assertNotIn('UNNotificationRequest', source)
        self.assertNotIn('http', source.lower())
        app = '\n'.join(path.read_text() for path in (ROOT / 'App').rglob('*.swift')
                        if 'Fixture' not in path.name and 'DesignFixtures' not in path.parts)
        self.assertEqual(app.count('.environment(\\.imInviteReminder'), 1)
        self.assertNotIn('registerForRemoteNotifications', self.read('App/SessionMessagingEntry.swift'))

    def test_unknown_mark_is_an_em_dash_in_english_and_simplified_chinese(self):
        catalog = json.loads((ROOT / 'Resources/Localizable.xcstrings').read_text())
        mark = catalog['strings']['mpd.im.inviteReminder.unknown']['localizations']
        label = catalog['strings']['mpd.im.inviteReminder.unknownLabel']['localizations']
        self.assertEqual(mark['en']['stringUnit']['value'], '\u2014')
        self.assertEqual(mark['zh-Hans']['stringUnit']['value'], '\u2014')
        self.assertEqual(label['en']['stringUnit']['value'], 'Invite alert status unknown')
        self.assertEqual(label['zh-Hans']['stringUnit']['value'], '邀约提醒状态未知')
        presentation = self.read('App/IMDriftEntries.swift')
        self.assertIn('static let unknownMark = "\\u{2014}"', presentation)
        toggle = presentation[presentation.index('struct IMInviteReminderToggle'):]
        self.assertIn('mpd.im.inviteReminder.unknown', toggle)
        self.assertIn('mpd.im.inviteReminder.unknownLabel', toggle)
        self.assertNotIn('mpd.im.inviteReminder.on', toggle[toggle.index('case .unknown'):toggle.index('case .on')])
