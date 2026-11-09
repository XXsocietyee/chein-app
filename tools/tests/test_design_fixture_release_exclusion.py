"""Source gate only. These tests do not compile Release and do not run xcodebuild."""
import importlib.util
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location(
    'check_design_fixture_release_exclusion',
    ROOT / 'tools/check_design_fixture_release_exclusion.py',
)
CHECK = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CHECK)


class DesignFixtureReleaseExclusionTests(unittest.TestCase):
    def test_repository_keeps_fixture_symbols_out_of_the_release_projection(self):
        self.assertEqual(CHECK.check(ROOT), [])

    def test_identifier_outside_debug_fails(self):
        source = 'enum DesignFixtureRegistry {}\n'
        hits = CHECK.symbol_hits(source, ['DesignFixtureRegistry'])
        self.assertEqual(hits, ['1: DesignFixtureRegistry in Release projection: enum DesignFixtureRegistry {}'])

    def test_debug_guard_and_release_else_are_distinct(self):
        guarded = '#if DEBUG\nenum DesignFixtureRegistry {}\n#endif\n'
        self.assertEqual(CHECK.symbol_hits(guarded, ['DesignFixtureRegistry']), [])
        self.assertEqual(CHECK.release_visible_code(guarded)[0], '')
        leaked = '#if DEBUG\nenum Hidden {}\n#else\nenum DesignFixtureRegistry {}\n#endif\n'
        self.assertTrue(any('DesignFixtureRegistry' in hit for hit in CHECK.symbol_hits(leaked, ['DesignFixtureRegistry'])))
        self.assertFalse(any('Hidden' in hit for hit in CHECK.symbol_hits(leaked, ['DesignFixtureRegistry', 'Hidden'])))

    def test_comments_do_not_count_and_string_literals_do(self):
        comment = '// DesignFixtureRegistry stays in this comment\nstruct Session {}\n'
        self.assertEqual(CHECK.symbol_hits(comment, ['DesignFixtureRegistry']), [])
        literal = 'let label = "DesignFixtureRegistry"\n'
        self.assertTrue(CHECK.symbol_hits(literal, ['DesignFixtureRegistry']))

    def test_missing_release_exclusion_is_reported(self):
        tokens = CHECK.exclusion_tokens('$(inherited) D2Fixtures.swift')
        self.assertNotIn('DesignFixtureRegistry.swift', tokens)
        self.assertIn('D2Fixtures.swift', tokens)

    def test_audit_lists_every_declared_fixture_symbol(self):
        audit = (ROOT / 'App/DesignFixtures/DesignFixtureReleaseExclusionAudit.swift').read_text()
        self.assertTrue(audit.startswith('#if DEBUG\n'))
        self.assertTrue(audit.rstrip().endswith('#endif'))
        symbols = CHECK.audit_symbols(audit)
        declared = []
        for path in sorted((ROOT / 'App/DesignFixtures').glob('*.swift')):
            declared.extend(CHECK.declared_types(path.read_text()))
            visible, errors = CHECK.release_visible_code(path.read_text())
            self.assertEqual(errors, [], path.name)
            self.assertEqual(visible, '', path.name)
        self.assertEqual(sorted(symbols), sorted(set(declared)))
        self.assertIn('DesignFixtureRegistry', symbols)
        self.assertIn('DesignFixtureReleaseExclusionAudit', symbols)


if __name__ == '__main__':
    unittest.main()
