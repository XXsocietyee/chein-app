"""E2E-20261113 R12 and R13 source guards.

R12: every Home continuation message key exists in Localizable.xcstrings in English and Simplified Chinese,
and the session's journey reader is built with reads enabled for the reviewed China player grant.
R13: the club post review sheet shows "posting unavailable" only when the write grant is absent.
Source guards only: they do not compile Swift or prove UI behaviour.
"""
import json
import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]


class E2E20261113R12R13(unittest.TestCase):
    def test_home_continuation_keys_are_translated(self):
        source = (ROOT / 'Core/HomeSearchTabParity.swift').read_text(encoding='utf-8')
        keys = sorted(set(re.findall(r'"(homeContinuation\.[A-Za-z]+)"', source)))
        self.assertGreaterEqual(len(keys), 3)
        strings = json.loads((ROOT / 'Resources/Localizable.xcstrings').read_text(encoding='utf-8'))['strings']
        for key in keys:
            self.assertIn(key, strings)
            for language in ('en', 'zh-Hans'):
                value = strings[key]['localizations'][language]['stringUnit']['value']
                self.assertTrue(value.strip(), f'{key} {language}')

    def test_journey_reader_reads_with_the_china_player_grant(self):
        session = (ROOT / 'App/AppSession.swift').read_text(encoding='utf-8')
        self.assertIn('PlayerJourneyService(configuration: $0, transport: runtimeHTTPTransport, readsEnabled: '
                      'composition.reviewed?.playerWritesEnabled == true && composition.reviewed?.regional.market == .china)', session)

    def test_post_review_unavailable_note_follows_the_write_grant(self):
        views = (ROOT / 'App/ClubCommunityViews.swift').read_text(encoding='utf-8')
        # native-r2 club (351198266): Confirm is a system Button in a Form section; the note is the preceding footer.
        anchor = views.index('.accessibilityIdentifier("club.community.confirm")')
        review = views[anchor - 1200:anchor]
        self.assertIn('Text("club.community.confirm")', review)
        self.assertLess(review.index('if model.context.coordinator?.permitsInjectedWrites != true {'),
                        review.index('Text("club.community.confirm")'))
        self.assertIn('if model.context.coordinator?.permitsInjectedWrites != true {', review)
        self.assertIn('Text("club.community.offline")', review.split('if model.context.coordinator?.permitsInjectedWrites != true {')[-1])


if __name__ == '__main__':
    unittest.main()
