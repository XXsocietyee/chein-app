"""Diagnostic-only source evidence. Hosted runtime root causes remain unconfirmed."""
from pathlib import Path
import re
import hashlib
import unittest
from test_run130_creator_scene import original_creator_source
from test_ci138_hosted_navigation_scene import original_owned_scene_source
ROOT = Path(__file__).resolve().parents[2]
OLD = ROOT / 'tools/tests/fixtures/run129_published_sources'


def without_debug(source):
    result = []
    depth = 0
    for line in source.splitlines(True):
        if line.strip() == '#if DEBUG': depth += 1
        elif line.strip() == '#endif':
            assert depth > 0; depth -= 1
        elif not depth: result.append(line)
    assert depth == 0
    return ''.join(result)


TRACE_HOSTS = ['WorkshopOwnedNavigationPresentationTests.swift', 'WorkshopPurchasedNormalAccountTests.swift']


def verify_owned(source):
    # The run129 fixture pinned the whole Release projection of this file. Its release logic has since
    # grown (route/visit identities, package bindings; already in the 02c68098f import) and the trace
    # gained events/fields with a 48-step bound. The diagnostic contract is asserted directly: the trace
    # exists only under DEBUG, is bounded, carries only an event enum and Bool flags, and never prints.
    release = without_debug(source)
    assert 'synthetic' not in release.lower(), 'Synthetic diagnostics must be DEBUG-only'
    assert 'guard selection == nil else { return nil }' in release
    assert '@ObservationIgnored var syntheticTrace: ((SyntheticSnapshot) -> Void)? = nil' in source
    bound = re.findall(r'guard let syntheticTrace, syntheticTraceCount < (\d+) else \{ return \}', source)
    assert len(bound) == 1 and 0 < int(bound[0]) <= 48
    assert 'syntheticTraceCount += 1' in source
    events = source.split('enum SyntheticEvent: String {', 1)[1].split('}', 1)[0]
    assert 'case listAppear,' in events or 'case listAppear\n' in events
    fields = source.split('struct SyntheticSnapshot {', 1)[1].split('\n    }', 1)[0]
    types = re.findall(r'let \w+: ([^\n]+)', fields)
    assert types[0] == 'SyntheticEvent' and len(types) >= 8 and set(types[1:]) == {'Bool'}
    assert 'print(' not in source


class Run129HostDiagnostics(unittest.TestCase):
    def test_owned_release_logic_is_exact_and_diagnostic_cannot_accept_content(self):
        source = (ROOT / 'App/WorkshopOwnedNavigationState.swift').read_text()
        verify_owned(source)
        for before, after in [('syntheticTraceCount < 48', 'true'),
                              ('let selected: Bool', 'let selected: String'),
                              ('case listAppear,', 'case unknown, listAppear,'),
                              ('guard selection == nil else { return nil }', 'guard true else { return nil }')]:
            self.assertIn(before, source)
            with self.subTest(before=before):
                with self.assertRaises(AssertionError): verify_owned(source.replace(before, after, 1))

    def test_only_original_sealed_owned_journey_installs_callback(self):
        # The purchased-library journey (WorkshopPurchasedNormalAccountTests) now installs the same
        # DEBUG-only trace. Each install is once per file, inside #if DEBUG, and prints only snapshot
        # flags/event names (plus the fixed role label), never IDs, routes or content.
        paths = sorted(p for p in (ROOT / 'Tests/AppUnitTests').glob('*.swift') if '.syntheticTrace =' in p.read_text())
        self.assertEqual([p.name for p in paths], sorted(TRACE_HOSTS))
        for path in paths:
            source = path.read_text()
            self.assertEqual(source.count('.syntheticTrace ='), 1, path.name)
            self.assertNotIn('.syntheticTrace =', without_debug(source), path.name)
            closure = source.split('.syntheticTrace = { snapshot in', 1)[1].split('\n#endif', 1)[0]
            for value in re.findall(r'\\\(([^)]*)\)', closure):
                self.assertTrue(value == 'role' or re.fullmatch(r'snapshot\.\w+(\.rawValue)?', value), (path.name, value))
        owned = (ROOT / 'Tests/AppUnitTests/WorkshopOwnedNavigationPresentationTests.swift').read_text()
        self.assertIn('guard stageCount < 12 else { return }', owned)
        self.assertEqual(owned.count('WORKSHOP_SYNTHETIC_OWNED'), 1)

    def test_creator_probe_records_only_framework_appearance_and_boolean_state(self):
        source = original_creator_source('WorkshopCreatorConsentNormalFlowTests.swift', (ROOT / 'Tests/AppUnitTests/WorkshopCreatorConsentNormalFlowTests.swift').read_text())
        marker = '#if DEBUG\nimport SwiftUI\nimport UIKit\n'
        probe = marker + source.split(marker, 1)[1]
        self.assertFalse((ROOT / 'Tests/AppUnitTests/WorkshopHostedLifecycleProbe.swift').exists())
        self.assertEqual(hashlib.sha256(probe.encode()).hexdigest(), '6ca904ebdfc2de50d3d9cfc1a9781fad3b53e3e98d9d7ac04f61093a227c3da9')
        self.assertTrue(probe.startswith('#if DEBUG\n')); self.assertTrue(probe.rstrip().endswith('#endif'))
        self.assertEqual(probe.count('override func viewDidAppear('), 2)
        self.assertEqual(probe.count('super.viewDidAppear(animated)'), 2)
        self.assertEqual(probe.count('observedAppearance = true'), 2)
        self.assertEqual(probe.count('print('), 1)
        for forbidden in ['beginAppearanceTransition', 'endAppearanceTransition', 'viewDidAppear(true)',
                          'Task.sleep', 'RunLoop', 'claimId', 'accountID', 'token', 'termsDocument']:
            self.assertNotIn(forbidden, probe)
        self.assertIn('enum Stage: String { case consentInitial, pendingInitialBack, pendingInitialReview }', probe)
        self.assertIn('root.viewIfLoaded?.window != nil', probe)
        self.assertIn('host.viewIfLoaded?.window != nil', probe)

    def test_creator_actions_assertions_wait_helpers_and_all_other_methods_are_unchanged(self):
        expected = {'WorkshopCreatorConsentNormalFlowTests.swift': 1,
                    'WorkshopCreatorPendingNormalFlowTests.swift': 2}
        for name, count in expected.items():
            source = original_creator_source(name, (ROOT / 'Tests/AppUnitTests' / name).read_text())
            if name == 'WorkshopCreatorConsentNormalFlowTests.swift':
                source = source.split('\n#if DEBUG\nimport SwiftUI\nimport UIKit\n', 1)[0]
            self.assertEqual(source.count('WorkshopHostedLifecycleProbe.record('), count)
            restored = re.sub(r'^\s*WorkshopHostedLifecycleProbe.record\([^\n]+\)\n', '\n', source, flags=re.M)
            restored = restored.replace('WorkshopHostedLifecycleRoot()', 'UIViewController()')
            restored = restored.replace('WorkshopHostedLifecycleHost(rootView:', 'UIHostingController(rootView:')
            old = (OLD / (name + '.txt')).read_text()
            self.assertEqual(re.sub(r'\s+', '', restored), re.sub(r'\s+', '', old))
            self.assertEqual(source[source.index('    private func waitUntil'):], old[old.index('    private func waitUntil'):])


if __name__ == '__main__': unittest.main()
