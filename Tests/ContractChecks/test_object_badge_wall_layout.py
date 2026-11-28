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
        # fix/r10-roam-b N-B3D (play-roam.md §5; MP subpackageP3/badge-3d): route preview -> 2D List, no turntable.
        # fix/r11-roam N-r11-5 (play-roam.md §4; MP subpackageP3/pages/badge-3d): detail -> inset-grouped List with the image
        # row and LabeledContent facts; no CYFlipCard / CYFoilMedal / cyCelebrations; .sensoryFeedback(.success) kept.
        # i18n/r1-strings: the badge share text's English half says "on Chengyin" instead of "on 城瘾" (copy only).
        # us/r1-one-app (owner 2026-11-27, English brand Chein): "on Chengyin" -> "on Chein" (copy only).
        # design/r3-consistency: detail artwork clip radius 16 -> CYRadius.card (one radius scale; look only).
        # design/r3-consistency run 10: share button hand-drawn capsule -> .borderedProminent capsule on .bar (look only).
        # design/r3-consistency run 36: badge name .title2 semibold -> .title2.bold() (one hero-name weight; look only).
        self.assertEqual(hashlib.sha256(value).hexdigest(), 'c2de7c1d662e504fae051337cd362a309944feb772079bb9c5db0ac856ea94c6')
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
        # BWALL-3: 已点亮 before 未解锁. Family sections are no longer the wall.
        groups = ['Section("profile.badges.unlocked")', 'Section("profile.badges.notUnlocked")']
        self.assertEqual([self.wall.index(g) for g in groups], sorted(self.wall.index(g) for g in groups))
        for token in ['if wall.isPartial', 'Text("profile.badges.partial")', 'wall.medalFailureMessage',
                      'if wall.isEmpty {', 'CYEmptyState(systemImage: "medal", "badgeWall.empty"', 'if let medals = wall.medals',
                      'let city = medals.filter { !$0.isAchievement }', 'let achievements = medals.filter(\\.isAchievement)',
                      'ObjectBadgeWallOrdering.litFirst(wall.identities)', 'profile.badge.identity',
                      'profile.badge.medal', 'profile.badge.achievement', 'if badge.unlocked']:
            self.assertIn(token, self.wall)
        self.assertNotIn('Section("profile.badges.identities")', self.wall)
        self.assertNotIn('POST', self.wall)
    def test_static_grid_is_readable_and_uses_existing_badge_facts(self):
        for token in ['dynamicTypeSize.isAccessibilitySize ? 1 : 2', 'LazyVGrid(columns: badgeWallColumns',
                      'description.fixedSize(horizontal: false, vertical: true)',
                      '.accessibilityElement(children: .combine)', 'Text(verbatim: badge.name)',
                      'badge.isLocked ? "profile.badges.locked" : "profile.badges.unlocked"',
                      'ObjectBadgeTileArtwork(url: badge.image',
                      ]:
            self.assertIn(token, self.wall)
        # BWALL-3b (r10, MP subpackageP3/badge-wall/index/index.wxml:46-63): one grid, no layout parameter.
        self.assertIn('albumID: slot.identifier, wall: wall).buttonStyle(.plain)', self.wall)
        self.assertIn('.grayscale(badge.isLocked ? 1 : 0)', self.wall)
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
    def test_layout_switch_and_its_state_are_retired(self):
        # BWALL-3b (r10, MP badge-wall wxml:46-63, 97): the list/wall Picker, its selection state and its unit test are gone.
        for symbol in ['ObjectBadgeWallLayout', 'ObjectBadgeWallLayoutControl', 'ObjectBadgeWallLayoutSelection',
                       'CYFoilMedal(unlocked: !badge.isLocked, size: 76', 'cyNewPulse']:
            self.assertNotIn(symbol, self.wall)
        self.assertFalse((ROOT / 'Tests/AppUnitTests/ObjectBadgeWallLayoutTests.swift').exists())

if __name__ == '__main__': unittest.main(verbosity=2)
