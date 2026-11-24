from pathlib import Path
import hashlib
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]

class CoopFixtureLifecycleDiagnosticChecks(unittest.TestCase):
    def test_probe_is_bounded_and_requires_all_synthetic_flags(self):
        source = (ROOT / 'App/CoopRelationDiscoveryFixture.swift').read_text()
        recorder = source.split('func record(_ value: String)', 1)[1].split('\n    }', 1)[0]
        for flag in ['--cooperation-flow-fixture', '--relation-discovery-fixture', '--relation-scenario']:
            self.assertIn('args.contains("' + flag + '")', recorder)
        self.assertIn('value.prefix(160)', recorder)
        self.assertIn('events.suffix(32)', recorder)
        self.assertIn('.accessibilityValue(ledger.diagnostic)', source)
        self.assertIn('identity.replace.received', source)
        self.assertIn('identity.replace.completed', source)

    def test_release_view_tokens_match_the_explicit_presentation_owner_increment(self):
        source = (ROOT / 'App/CoopRelationDiscoveryView.swift').read_text()
        # Reverse only the reviewed actor-initialization repair before checking the
        # original owner/lifetime Release tokens. No other production change is allowed.
        replacements = [
            ('@State private var model: CoopRelationDiscoveryModel',
             '@State private var model = CoopRelationDiscoveryModel()'),
            ('model: CoopRelationDiscoveryModel? = nil, presentation:',
             'model: CoopRelationDiscoveryModel = .init(), presentation:'),
            ('_model = State(initialValue: model ?? .init())',
             '_model = State(initialValue: model)'),
        ]
        for current, original in replacements:
            self.assertEqual(source.count(current), 1)
            source = source.replace(current, original)
        stripped = re.sub(r'(?ms)^\s*#if DEBUG\s*\n.*?^\s*#endif\s*$', '', source)
        normalized = re.sub(r'\s+', '', stripped)
        # The earlier diagnostic-only c2d2/f128 source had hash
        # 6e8d14b020e33d30cebba4215a4d30463131554dc450f80400198987f2712602.
        # This explicit production identity-owner increment changes Release code;
        # it must not be described as another Release-equivalent diagnostic patch.
        # Re-pinned after the e3/UI-CLOUD-16 player-surface restyles and WP-04 square author delete mount;
        # the identity-owner/lifetime token content above is unchanged. Re-pinned again for the RM-01 relation post feed,
        # and after the Audit 2026-11-14 compile fix removing the player clubCommunityContext feed from CoopRelationContextLabel.
        # Re-pinned for fix-parity merchant-coop (combined-r5): relation P1 merchant theme + no stray author-delete row,
        # relation P0b club post feed through CoopRelationPostFeedFactory. Owner/lifetime tokens above unchanged.
        # Re-pinned for fix-parity2 merchant-coop: relation P1 inline 重新加载 button and 登录后查看发现 copy key only.
        # Re-pinned for restyle R3 (native iOS): CYTypography → .cyText, inline title mode, system sheet detents only.
        # Re-pinned for fix/r3-merchant-coop-b MC7-28-5: 重新加载 button under the partial notice only.
        self.assertEqual('2f5c3d2260e4cd4fdc4c79bc13ae8aa2427aa5332a863462179e6f7be0c62106', hashlib.sha256(normalized.encode()).hexdigest())

    def test_failure_projection_is_small_and_does_not_change_read_count_label(self):
        source = (ROOT / 'Tests/AppUITests/CoopRelationDiscoveryFlowTests.swift').read_text()
        self.assertIn('(testRun?.totalFailureCount ?? 0) > 0', source)
        self.assertIn('value.prefix(6_144)', source)
        self.assertIn('XCTAssertEqual(app.staticTexts["cooprelation.fixture.profileReads"].label, "1:0")', source)
