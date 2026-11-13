"""E2E-20261113 (1): every signed-in activity detail offers the free sign-up CTA.

Source guard only: it does not compile Swift or prove UI behaviour. Free sign-up is an
owner-approved non-money player write; the view still gates the action on the session's
registration capability. The topic detail's activity link used to omit it.
"""
import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
# The creator's own activities (profile projects, publishing modes, owned content) are not a sign-up surface.
OWNER_VIEWS = {'ProfileSelfProjectsSection.swift', 'SessionPublishingModesView.swift', 'ProjectOwnedContentViews.swift'}


class ActivitySignupCTA(unittest.TestCase):
    def test_session_activity_details_enable_registration(self):
        offenders = []
        for path in (ROOT / 'App').rglob('*.swift'):
            if 'DesignFixtures' in path.parts or path.name in OWNER_VIEWS:
                continue
            text = path.read_text(encoding='utf-8')
            for match in re.finditer(r'ActivityDetailView\(\s*id:\s*[^,]+,\s*reader:\s*session\b[^\n]*', text):
                if 'registrationEnabled: true' not in match.group(0).replace('registrationEnabled:true', 'registrationEnabled: true'):
                    offenders.append(f'{path.relative_to(ROOT)}: {match.group(0)[:120]}')
        self.assertEqual(offenders, [])

    def test_topic_detail_activity_link_enables_registration(self):
        source = (ROOT / 'App/PlatformConsumerSessionOwner.swift').read_text(encoding='utf-8')
        self.assertIn('activityDestination: { AnyView(ActivityDetailView(id: $0, reader: session, '
                      'playReaderForActivity: { session.playReader(for: .activity($0)) }, registrationEnabled: true)) }', source)


if __name__ == '__main__':
    unittest.main()
