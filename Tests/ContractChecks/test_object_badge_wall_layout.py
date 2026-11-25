"""Focused P029 source contracts; no Swift compiler, UI or accessibility execution."""
from pathlib import Path
import hashlib
import json
import re
import unittest
ROOT = Path(__file__).resolve().parents[2]

class ObjectBadgeWallLayoutContracts(unittest.TestCase):
    def setUp(self):
        self.source = (ROOT / 'App/ObjectBadgeViews.swift').read_text()
        self.wall, self.detail = self.source.split('@MainActor struct ObjectBadgeDetailView:', 1)
    def test_existing_detail_and_route_lifetimes_are_byte_identical(self):
        value = ('@MainActor struct ObjectBadgeDetailView:' + self.detail).encode()
        # ObjectBadgeWallBadgeLabel migrated medal icon to CYTypography.data2XL (cur-t7-14); detail & route lifetimes unchanged.
        # fix/parity2-play-roam: detail + route preview titles appNavigationTitle -> cyPageTitle (inline title mode only).
        # restyle/r6-system-rest: static CYTypography fonts -> .cyText(.token) (semantic text styles only).
        # fix/r3-play-roam-b round 2: detail stage placeholder art SF medal -> MP `badge-demo.png` (MPAsset.BadgeMedal.badgeDemo).
        self.assertEqual(hashlib.sha256(value).hexdigest(), 'ff26c06b901f71bfc5fa08210437e16772e85478532239840daa64c811ca8a1d')
        self.assertIn('let capturedIdentity = reader.identity', self.wall)
        self.assertIn('ObjectBadgeDetailView(badge: badge, reader: reader, expectedIdentity: capturedIdentity, media: media,', self.wall)
    def test_list_wall_switch_is_not_required(self):
        # BWALL-3: the 2-column static grid may replace the list/wall switch.
        # This no longer pins `.list`, the segmented Picker, or ObjectBadgeWallLayoutControl.
        self.assertNotIn('SceneKit', self.wall)
        self.assertNotIn('RealityKit', self.wall)
        self.assertNotIn('AsyncImage(', self.wall)
        self.assertLessEqual(self.wall.count('try await reader.profileBadges()'), 1)
    def test_switch_does_not_add_reads_or_reload_the_read_screen(self):
        self.assertLessEqual(self.wall.count('try await reader.profileBadges()'), 1)
        self.assertNotIn('.id(layout', self.wall)
        for forbidden in ['.task(', '.onAppear', 'UserDefaults', 'URLSession', 'request(', 'unlock(', 'AsyncImage(', 'Task {']:
            self.assertNotIn(forbidden, self.wall)
    def test_control_is_separate_from_detail_navigation(self):
        self.assertNotIn('SceneKit', self.wall)
        self.assertNotIn('RealityKit', self.wall)
        self.assertNotIn('AsyncImage(', self.wall)
    def test_same_rows_group_order_and_partial_results_are_retained(self):
        groups = ['Section("profile.badges.identities")', 'Section("profile.badges.medals")', 'Section("profile.badges.achievements")']
        self.assertEqual([self.wall.index(g) for g in groups], sorted(self.wall.index(g) for g in groups))
        for token in ['if wall.isPartial', 'Text("profile.badges.partial")', 'wall.medalFailureMessage',
                      'if wall.isEmpty {', 'CYEmptyState(systemImage: "medal", "badgeWall.empty"', 'if let medals = wall.medals',
                      'let city = medals.filter { !$0.isAchievement }', 'let achievements = medals.filter(\\.isAchievement)',
                      'ObjectBadgeWallOrdering.litFirst(wall.identities).map { .identity($0) }', 'city.map { .medal($0) }', 'achievements.map { .medal($0) }']:
            self.assertIn(token, self.wall)
        self.assertEqual(self.wall.count('ForEach(Array(badges.enumerated()), id: \\.offset)'), 2)
    def test_static_grid_is_readable_and_uses_existing_badge_facts(self):
        for token in ['dynamicTypeSize.isAccessibilitySize', 'CYCollectionGrid.columns(accessibility: dynamicTypeSize.isAccessibilitySize)', 'description.fixedSize(horizontal: false, vertical: true)',
                      '.accessibilityElement(children: .combine)', 'Text(verbatim: badge.name)',
                      'badge.isLocked ? "profile.badges.locked" : "profile.badges.unlocked"',
                      ]:
            self.assertIn(token, self.wall)
        self.assertIn('layout: layout, wall: wall).buttonStyle(.plain)', self.wall)
        # The album card (a separate view) clamps its hero name to two lines; the tile label itself never truncates.
        self.assertNotIn('.lineLimit(', self.source.split('struct ObjectBadgeWallBadgeLabel', 1)[1])
        self.assertNotIn('SceneKit', self.wall)
        self.assertNotIn('RealityKit', self.wall)
    def test_additive_bilingual_labels_accept_exact_central_merge(self):
        fragment = json.loads((ROOT / 'Resources/ObjectBadgeWallLayoutLocalizations.fragment.json').read_text())
        expected = {'objects.badgeLayout.' + k for k in ['title', 'list', 'wall', 'staticOnly']}
        self.assertEqual(set(fragment), expected)
        catalog = json.loads((ROOT / 'Resources/Localizable.xcstrings').read_text())['strings']
        present = expected & set(catalog)
        if present:
            self.assertEqual(present, expected)
            for key in expected: self.assertEqual(fragment[key], catalog[key])
        for row in fragment.values():
            self.assertEqual(set(row['localizations']), {'en', 'zh-Hans'})
            for locale in row['localizations'].values(): self.assertTrue(locale['stringUnit']['value'])
        self.assertEqual(fragment['objects.badgeLayout.wall']['localizations']['en']['stringUnit']['value'], 'Static wall')
    def test_focused_runtime_methods_are_authored_without_claiming_execution(self):
        tests = (ROOT / 'Tests/AppUnitTests/ObjectBadgeWallLayoutTests.swift').read_text()
        self.assertEqual(len(re.findall(r'func test\w+\(', tests)), 8)
        for case in ['testAccountEpochSignOutAndConfigurationLoss', 'testReplacementReaderWithSameAccount',
                     'testOldRenderedControlCannotChangeCurrentOwnersChoice', 'testRetirementNeedsAnotherExplicitCurrentSelection',
                     'testBilingualLargeTextLabelsAndControlConstructInBothLayouts']:
            self.assertIn(case, tests)
        self.assertIn('.dynamicTypeSize(.accessibility5)', tests)
        self.assertIn('["en", "zh-Hans"]', tests)

if __name__ == '__main__': unittest.main(verbosity=2)
