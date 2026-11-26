"""Source wiring checks only; Apple navigation/runtime tests remain unrun."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[2]
class ClubHomeTopicNavigationChecks(unittest.TestCase):
    def read(self, name): return (ROOT/'App'/name).read_text()
    def test_event_uses_topic_id_and_native_navigation_link(self):
        # r11 A8-03: MP talent/list/index.wxml:57-95 (chengyinhub-xcx) — the 俱乐部 tab root is the create row plus one
        # club list; the 俱乐部活动 section left ClubHomeView (events stay on club detail).
        s=self.read('ClubHomeView.swift')
        self.assertNotIn('NavigationLink { topicDestination(event.id) } label: { eventRow(event, page: page) }',s)
        self.assertNotIn('Text("club.events")',s)
    def test_both_normal_hosts_inject_existing_guarded_destination(self):
        for file in ['QuestifyApp.swift','AccountView.swift']:
            s=self.read(file)
            self.assertIn('topicDestination: { AnyView(SessionTopicDetailView(id: $0, session: session)) }',s)
            self.assertIn('.id(session.sessionRevision)',s)
    def test_destination_keeps_auth_and_content_revision_guards(self):
        s=self.read('PlatformConsumerSessionOwner.swift')
        self.assertIn('guestSignIn: session.account == nil',s)
        self.assertIn('promptGuestSignIn()',s)
        self.assertIn('reader: topicReaderOverride ?? session.topicReader',s)
        self.assertIn('.id(session.contentDetailRevision)',s)
    def test_fixture_is_offline_and_scope_reset_survives(self):
        s=self.read('ClubFixtureSupport.swift')
        self.assertTrue(s.startswith('#if DEBUG'))
        self.assertIn('topicDestination: { id in',s)
        self.assertIn('.id(reader.clubIdentity)',s)
        self.assertNotIn('AppSession(',s)
    def test_authored_ui_tests_cover_back_reopen_signout_account_change(self):
        # r11 A8-03: the home-topic flows went with the 俱乐部活动 section (MP talent/list/index.wxml:57-95).
        s=(ROOT/'Tests/AppUITests/ClubCommunityUITests.swift').read_text()
        self.assertIn('r11 A8-03',s)
        self.assertNotIn('app.buttons["club.event.91"]',s)
        self.assertNotIn('XCTSkip',s)
