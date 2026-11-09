from pathlib import Path
import json
import unittest

ROOT = Path(__file__).resolve().parents[2]

class JoinedInvitationDetailNavigationTests(unittest.TestCase):
    def test_current_members_only_enter_fresh_exact_id_route(self):
        text = (ROOT / 'App/TeamHomeView.swift').read_text()
        joined = text.split('if detail.joined == true {', 1)[1].split('else { actionButton', 1)[0]
        self.assertIn('TeamDetailView(lookup: .id(detail.team.id), coordinator: makeCoordinator(), makeCoordinator: makeCoordinator, requiresMembership: true)', joined)
        self.assertIn('team.invitation.openDetail', joined)
        self.assertIn('.disabled(model.actionLocked)', joined)
        self.assertIn('loadDetail(lookup, requireMembership: requiresMembership)', text)

    def test_membership_refresh_fails_closed_and_keeps_existing_identity_checks(self):
        text = (ROOT / 'Core/TeamCoordinator.swift').read_text()
        body = text.split('public func loadDetail(', 1)[1].split('public func loadCreation(', 1)[0]
        self.assertIn('if requireMembership {\n            detail = nil\n            guard case .id = lookup', body)
        self.assertIn('guard active(session, stamp)', body)
        self.assertIn('result.team.id != id', body)
        self.assertIn('if requireMembership, result.joined != true { detail = nil; throw TeamFailure.invalidContract }', body)
        self.assertIn('try restorePending(targetKey: "team-\\(result.team.id)", session: session)', body)
        self.assertNotIn('submit(', body)

    def test_normal_and_fixture_factories_are_wired(self):
        for file in ['SessionTeamViews.swift', 'NativeNavigationCompletionViews.swift', 'TeamFixtureSupport.swift']:
            lines = (ROOT / 'App' / file).read_text().splitlines()
            calls = [line for line in lines if 'TeamDetailView(lookup:' in line]
            self.assertTrue(calls)
            for line in calls:
                self.assertIn('makeCoordinator:', line)

    def test_join_page_strings_and_unknown_count_contract(self):
        spec = json.loads((ROOT / 'docs/release/ui-strings-pages-team-join-index.json').read_text())
        self.assertEqual(spec['page'], 'pages/team/join/index')
        self.assertEqual(spec['unknownCountText'], '\u2014')
        self.assertNotEqual(spec['unknownCountText'], '0')
        catalog = json.loads((ROOT / 'Resources/Localizable.xcstrings').read_text())['strings']
        self.assertGreaterEqual(len(spec['strings']), 1)
        seen = set()
        for item in spec['strings']:
            key = item['key']
            self.assertNotIn(key, seen)
            seen.add(key)
            self.assertTrue(item['en'].strip() and item['zh-Hans'].strip(), key)
            unit = catalog[key]['localizations']
            self.assertEqual(item['en'], unit['en']['stringUnit']['value'], key)
            self.assertEqual(item['zh-Hans'], unit['zh-Hans']['stringUnit']['value'], key)
        sources = '\n'.join((ROOT / 'App').joinpath(name).read_text() for name in [
            'TeamHomeView.swift', 'TeamPageParityViews.swift', 'TeamComponents.swift'])
        sources += '\n' + (ROOT / 'Core/TeamContracts.swift').read_text()
        self.assertGreaterEqual(len(spec['accessibilityIdentifiers']), 1)
        for identifier in spec['accessibilityIdentifiers']:
            self.assertNotIn('club.', identifier)
            self.assertIn('"' + identifier + '"', sources, identifier)
        blob = json.dumps(spec)
        for forbidden in ['showsMerchantChoice', 'paymentEnabled', 'payoutEnabled', 'withdrawalEnabled', 'virtualGoodsEnabled', 'http://', 'https://']:
            self.assertNotIn(forbidden, blob)
        presentation = (ROOT / 'Core/TeamPagePresentation.swift').read_text()
        self.assertIn('public static let unknownCountText = "\u2014"', presentation)
        self.assertIn('joined >= 0, maximum > 0 else { return unknownCountText }', presentation)
        self.assertNotIn('joined ?? 0', presentation)
        self.assertNotIn('maximum ?? 0', presentation)
        fixture = (ROOT / 'Core/TeamSyntheticFixtures.swift').read_text()
        self.assertTrue(fixture.startswith('#if DEBUG'))
        self.assertIn('enum TeamJoinIndexFixtureData', fixture)
        self.assertIn('unknownCountJSON', fixture)

    def test_authored_behavior_tests_cover_back_revocation_and_locks(self):
        core = (ROOT / 'Tests/CoreTests/TeamCoordinatorTests.swift').read_text()
        ui = (ROOT / 'Tests/AppUITests/TeamFlowTests.swift').read_text()
        for name in ['testJoinedInvitationContinuationRequiresFreshMembership', 'testJoinedContinuationRejectsInvitationLookupAndUnknownMembership', 'testJoinedContinuationClearsRosterWhenRefreshFails', 'testJoinedContinuationDiscardsReadAfterSessionChanges', 'testJoinedContinuationPreservesUnknownJournalLock']:
            self.assertIn(name, core)
        self.assertIn('testAlreadyJoinedInvitationOpensDetailBackAndReopens', ui)
        self.assertIn('testNonmemberInvitationHasNoOwnedDetailShortcut', ui)
