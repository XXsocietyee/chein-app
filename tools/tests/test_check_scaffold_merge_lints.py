"""Merge-break lints in check_scaffold. No Swift, Xcode, or network."""
import ast
import pathlib
import re
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[2]
MODULE = ast.parse((ROOT / 'tools/check_scaffold.py').read_text())
PUBLIC = {'unguarded_questify_core_imports', 'duplicate_top_level_types'}
NODES = [
    node for node in MODULE.body
    if (isinstance(node, ast.FunctionDef) and (node.name in PUBLIC or node.name.startswith('_merge_')))
    or (isinstance(node, ast.Assign) and any(
        isinstance(target, ast.Name) and target.id.startswith('_MERGE_') for target in node.targets))
]
SCOPE = {'re': re}
exec(compile(ast.Module(body=NODES, type_ignores=[]), 'check_scaffold merge lints', 'exec'), SCOPE)
unguarded = SCOPE['unguarded_questify_core_imports']
duplicates = SCOPE['duplicate_top_level_types']


class UnguardedQuestifyCoreImportTests(unittest.TestCase):
    def test_bare_import_is_unguarded(self):
        self.assertEqual(unguarded('import SwiftUI\nimport QuestifyCore\n'), [2])

    def test_can_import_guard_passes(self):
        source = '#if canImport(QuestifyCore)\nimport QuestifyCore\n#endif\n'
        self.assertEqual(unguarded(source), [])

    def test_guard_covers_the_whole_branch(self):
        source = '#if canImport(QuestifyCore)\nimport SwiftUI\nimport QuestifyCore\n#endif\n'
        self.assertEqual(unguarded(source), [])

    def test_else_of_can_import_is_unguarded(self):
        source = '#if canImport(QuestifyCore)\n#else\nimport QuestifyCore\n#endif\n'
        self.assertEqual(unguarded(source), [3])

    def test_negated_can_import_is_unguarded(self):
        source = '#if !canImport(QuestifyCore)\nimport QuestifyCore\n#endif\n'
        self.assertEqual(unguarded(source), [2])

    def test_else_of_negated_can_import_is_guarded(self):
        source = '#if !canImport(QuestifyCore)\n#else\nimport QuestifyCore\n#endif\n'
        self.assertEqual(unguarded(source), [])

    def test_and_with_other_condition_still_guards(self):
        source = '#if canImport(QuestifyCore) && os(iOS)\nimport QuestifyCore\n#endif\n'
        self.assertEqual(unguarded(source), [])

    def test_compiler_condition_still_guards(self):
        source = '#if compiler(>=5.9) && canImport(QuestifyCore)\nimport QuestifyCore\n#endif\n'
        self.assertEqual(unguarded(source), [])

    def test_or_with_other_condition_does_not_guard(self):
        source = '#if canImport(QuestifyCore) || canImport(Other)\nimport QuestifyCore\n#endif\n'
        self.assertEqual(unguarded(source), [2])

    def test_double_negation_guards(self):
        source = '#if !(!canImport(QuestifyCore))\nimport QuestifyCore\n#endif\n'
        self.assertEqual(unguarded(source), [])

    def test_parenthesized_can_import_guards(self):
        source = '#if (canImport(QuestifyCore))\nimport QuestifyCore\n#endif\n'
        self.assertEqual(unguarded(source), [])

    def test_comment_string_and_block_comment_are_not_imports(self):
        source = '\n'.join([
            '// import QuestifyCore',
            'let note = "import QuestifyCore"',
            '/*',
            'import QuestifyCore',
            '*/',
            'let block = """',
            'import QuestifyCore',
            '"""',
            'let raw = #"',
            'import QuestifyCore',
            '"#',
        ])
        self.assertEqual(unguarded(source), [])

    def test_directive_inside_a_comment_does_not_guard(self):
        source = '/* #if canImport(QuestifyCore) */\nimport QuestifyCore\n'
        self.assertEqual(unguarded(source), [2])

    def test_testable_and_kind_import_are_checked(self):
        self.assertEqual(unguarded('@testable import QuestifyCore\n'), [1])
        self.assertEqual(unguarded('import struct QuestifyCore.Route\n'), [1])

    def test_second_bare_import_after_a_guard_fails(self):
        source = '#if canImport(QuestifyCore)\nimport QuestifyCore\n#endif\nimport QuestifyCore\n'
        self.assertEqual(unguarded(source), [4])

    def test_nested_guard_still_counts(self):
        source = '#if os(iOS)\n#if canImport(QuestifyCore)\nimport QuestifyCore\n#endif\n#endif\n'
        self.assertEqual(unguarded(source), [])


class DuplicateTopLevelTypeTests(unittest.TestCase):
    def test_duplicate_across_app_and_core_fails(self):
        files = [
            ('App/A.swift', 'struct PlayRouteNotice {}\n'),
            ('Core/B.swift', '@MainActor\npublic final class PlayRouteNotice {}\n'),
        ]
        self.assertEqual(
            duplicates(files),
            ['PlayRouteNotice: App/A.swift:1 (struct), Core/B.swift:2 (class)'])

    def test_unique_names_pass(self):
        files = [
            ('App/A.swift', 'struct Alpha {}\n'),
            ('Core/B.swift', 'enum Beta {}\nprotocol Gamma {}\nactor Delta {}\n'),
        ]
        self.assertEqual(duplicates(files), [])

    def test_file_private_copies_in_different_files_pass(self):
        files = [
            ('App/A.swift', 'private struct Row {}\n'),
            ('Core/B.swift', 'fileprivate struct Row {}\n'),
        ]
        self.assertEqual(duplicates(files), [])

    def test_file_private_and_module_visible_clash(self):
        files = [
            ('App/A.swift', 'struct Row {}\n'),
            ('Core/B.swift', 'private struct Row {}\n'),
        ]
        self.assertEqual(duplicates(files), ['Row: App/A.swift:1 (struct), Core/B.swift:1 (struct)'])

    def test_same_file_private_redeclaration_fails(self):
        files = [('App/A.swift', 'private struct Row {}\nprivate struct Row {}\n')]
        self.assertEqual(duplicates(files), ['Row: App/A.swift:1 (struct), App/A.swift:2 (struct)'])

    def test_if_else_branches_are_not_a_clash(self):
        source = '#if DEBUG\nstruct Foo {}\n#else\nstruct Foo {}\n#endif\n'
        self.assertEqual(duplicates([('App/A.swift', source)]), [])

    def test_debug_copy_beside_unconditional_fails(self):
        source = '#if DEBUG\nstruct Foo {}\n#endif\nstruct Foo {}\n'
        self.assertEqual(duplicates([('App/A.swift', source)]), ['Foo: App/A.swift:2 (struct), App/A.swift:4 (struct)'])

    def test_same_config_branch_in_two_files_clashes(self):
        source = '#if DEBUG\nstruct Foo {}\n#endif\n'
        self.assertEqual(
            duplicates([('App/A.swift', source), ('Core/B.swift', source)]),
            ['Foo: App/A.swift:2 (struct), Core/B.swift:2 (struct)'])

    def test_nested_extension_comment_and_literals_are_not_declarations(self):
        files = [
            ('App/A.swift', '\n'.join([
                'struct Outer { struct Inner {} }',
                'extension Outer {}',
                '// struct Ghost {}',
                'let text = "{ struct Ghost {}"',
                'let raw = #"struct Ghost {}"#',
                'let multi = """',
                'struct Ghost {}',
                '"""',
                'typealias Outer.Nested = Int',
            ])),
            ('Core/B.swift', 'struct Inner {}\nstruct Ghost {}\nstruct Nested {}\n'),
        ]
        self.assertEqual(duplicates(files), [])

    def test_string_brace_does_not_hide_a_later_type(self):
        files = [
            ('App/A.swift', 'let s = "{ struct Hidden {}"\nstruct Shown {}\n'),
            ('Core/B.swift', 'struct Hidden {}\nstruct Shown {}\n'),
        ]
        self.assertEqual(duplicates(files), ['Shown: App/A.swift:2 (struct), Core/B.swift:2 (struct)'])

    def test_typealias_duplicate_fails(self):
        files = [
            ('App/A.swift', 'typealias RouteID = Int\n'),
            ('Core/B.swift', 'typealias RouteID = String\n'),
        ]
        self.assertEqual(
            duplicates(files),
            ['RouteID: App/A.swift:1 (typealias), Core/B.swift:1 (typealias)'])

    def test_repository_has_no_unguarded_imports_or_duplicate_types(self):
        sources = []
        for folder in ('App', 'Core'):
            for path in sorted((ROOT / folder).rglob('*.swift')):
                sources.append((path.relative_to(ROOT).as_posix(), path.read_text(encoding='utf-8')))
        bare = [
            f'{rel}:{line}' for rel, text in sources if rel.startswith('App/') for line in unguarded(text)]
        self.assertEqual(bare, [])
        self.assertEqual(duplicates(sources), [])


if __name__ == '__main__':
    unittest.main()
