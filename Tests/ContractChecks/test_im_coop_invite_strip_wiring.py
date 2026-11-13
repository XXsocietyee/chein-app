"""Row 29: the message list installs the coop invite strip. Row 30 stays unwired."""
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class IMCoopInviteStripWiringTests(unittest.TestCase):
    def read(self, name):
        return (ROOT / name).read_text()

    def test_message_list_calls_factory_with_the_existing_reader(self):
        source = self.read('App/SessionMessagingEntry.swift')
        self.assertIn(
            'IMCoopInviteStripFactory.make(reader: session.cooperationReader)',
            source,
        )
        self.assertNotIn('imInviteReminder', source)
        self.assertNotIn('IMInviteReminderBinding', source)
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

    def test_reminder_binding_has_no_production_assignment(self):
        app = '\n'.join(path.read_text() for path in (ROOT / 'App').rglob('*.swift')
                        if 'Fixture' not in path.name and 'DesignFixtures' not in path.parts)
        self.assertNotIn('.environment(\\.imInviteReminder', app)
        self.assertNotIn('IMInviteReminderBinding', app.replace(self.read('App/IMDriftEntries.swift'), ''))
