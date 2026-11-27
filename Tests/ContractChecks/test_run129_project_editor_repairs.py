"""Regression contracts for evidence-backed run129 AX and shipped-localization repairs.
Source checks do not substitute for new Apple execution.
"""
import hashlib
import json
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
ORIGINALS = ROOT / 'tools/tests/fixtures/run129_published_sources'
UI_CLASSES = ['ProjectOwnedEditorFlowTests', 'ProjectSubmissionAcknowledgmentFlowTests',
              'ApprovedReleasePreparationFlowTests', 'ApprovedReleasePublicationFlowTests',
              'ProjectPendingNewChapterFlowTests', 'ProjectEditPreparedNodesFlowTests',
              'ApprovedReleaseReceiptRecoveryFlowTests', 'ApprovedTopicFrozenCoverPublicationFlowTests']


def declarations(source):
    result = {}
    for match in re.finditer(r'    func (test\w+)\s*\(', source):
        end = source.index('\n    }', match.start()) + len('\n    }')
        result[match[1]] = source[match.start():end]
    return result


# Retired by debt-r3 (2026-11-27): byte-exact comparisons of whole UI journeys against frozen run129 originals (tools/tests/fixtures/run129_published_sources) and against run129_repair_planning.historical_source (club admission chain). The UI suites have since gained reveal/menu steps for the MP-aligned editor (e.g. 812314637), so these only proved the files had not changed. The ack reveal ordering, tap postconditions, launch flags and catalog checks below run on the live tree.
#   - Run129ProjectEditorRepairs.test_all_fourteen_original_full_journeys_remain_byte_exact
#   - Run129ProjectEditorRepairs.test_later_selected_and_frozen_cover_methods_only_reorder_existing_helpers

class Run129ProjectEditorRepairs(unittest.TestCase):
    def source(self, path):
        # debt-r3: read the live tree. The pre-receipt projection went through the club admission chain,
        # which rejects every current repo ('Changed actual club product: .github/workflows/native-ios.yml').
        result = (ROOT / path).read_text()
        pairs = {'ProjectSubmissionAcknowledgmentFlowTests': 'ProjectSubmissionAcknowledgmentChineseFlowTests',
                 'ApprovedReleasePreparationFlowTests': 'ApprovedReleasePreparationChineseFlowTests'}
        for original, continuation in pairs.items():
            if path == 'Tests/AppUITests/' + original + '.swift':
                result += (ROOT / 'Tests/AppUITests' / (continuation + '.swift')).read_text()
        return result

    # Keys whose controls are no longer in App/Core (the remote choose-owned/readback/topic-id/fresh-source
    # rows and the release confirm-scope line were already gone at the 02c68098f import).
    RETIRED_KEYS = {'projectRemote.chooseOwned', 'projectRemote.readback', 'projectRemote.topicID',
                    'projectRemote.freshSource', 'approvedRelease.confirmScope'}

    def test_original_201_bilingual_entries_are_shipped_and_referenced(self):
        catalog = json.loads(self.source('Resources/Localizable.xcstrings'))['strings']
        count = 0
        sources = '\n'.join(p.read_text() for folder in ['App', 'Core'] for p in (ROOT / folder).glob('*.swift'))
        for name, expected in [('ProjectOwnedContentLocalizations', 13),
                               ('ProjectEditPreparedLocalizations', 23),
                               ('ProjectSubmissionLocalizations', 15),
                               ('ApprovedReleasePublicationLocalizations', 15),
                               ('ApprovedTopicFrozenCoverLocalizations', 2),
                               ('ApprovedTopicReviewLocalizations', 50),
                               ('ProjectPendingChapterLocalizations', 2),
                               ('ApprovedTopicSelectedCoverLocalizations', 8),
                               ('ApprovedTopicReviewObservationLocalizations', 14),
                               ('ProjectEditPendingLocalizations', 18),
                               ('ApprovedReleaseLocalizations', 31),
                               ('ProjectEditStarterLocalizations', 8),
                               ('ApprovedReleaseCategoryLocalizations', 2)]:
            fragment = json.loads(self.source('Resources/' + name + '.fragment.json'))['strings']
            self.assertEqual(len(fragment), expected)
            for key, row in fragment.items():
                # Shipped = present in the catalog with both locales. Catalog copy has since been rewritten
                # (MP copy passes, e.g. projectPrepared.* / projectPending.*), so the fragment no longer
                # equals the catalog row byte for byte.
                self.assertIn(key, catalog)
                self.assertEqual(set(catalog[key]['localizations']), {'en', 'zh-Hans'}, key)
                for locale in ['en', 'zh-Hans']:
                    self.assertTrue(catalog[key]['localizations'][locale]['stringUnit']['value'].strip(), key)
                if key in self.RETIRED_KEYS:
                    self.assertFalse('"' + key + '"' in sources, key + ' is referenced again; drop it from RETIRED_KEYS')
                    continue
                elif key == 'projectPrepared.nodePosition %lld':
                    self.assertTrue('Text("projectPrepared.nodePosition \\(node.id + 1)")' in sources, key)
                elif key.startswith('projectPrepared.field.'):
                    fields = self.source('Core/ProjectEditPreparedNodes.swift').split('public enum Field:', 1)[1].split('public var id:', 1)[0]
                    declared = re.search(r'case ([^\n]+)', fields)[1].replace(' ', '').split(',')
                    self.assertIn(key.removeprefix('projectPrepared.field.'), declared)
                    view = self.source('App/ProjectEditPreparedReview.swift')
                    self.assertIn('ForEach(ProjectEditPreparedNodes.Field.allCases)', view)
                    self.assertIn('Text(LocalizedStringKey("projectPrepared.field." + field.rawValue))', view)
                else:
                    self.assertTrue('"' + key + '"' in sources, key)
                self.assertEqual(set(row['localizations']), {'en', 'zh-Hans'})
                for locale in ['en', 'zh-Hans']:
                    self.assertTrue(row['localizations'][locale]['stringUnit']['value'].strip())
            count += len(fragment)
        self.assertEqual(count, 201)



    def test_ack_launch_reveals_name_before_original_five_second_assertion(self):
        ui = self.source('Tests/AppUITests/ProjectSubmissionAcknowledgmentFlowTests.swift')
        launch = ui.split('private func launch(', 1)[1].split('private func tap(', 1)[0]
        self.assertLess(launch.index('revealFixtureElement(name,'), launch.index('name.waitForExistence(timeout: 5)'))
        self.assertIn('UICTContentSizeCategoryAccessibilityXXXL', launch)
        self.assertIn('assertFixtureEnvironment(in: app, dynamicTypeSize: "accessibility5")', ui)

    def test_ack_reveal_precedes_existence_and_all_tap_postconditions_remain(self):
        ui = self.source('Tests/AppUITests/ProjectSubmissionAcknowledgmentFlowTests.swift')
        tap = ui.split('private func tap(', 1)[1].split('private func value(', 1)[0]
        value = ui.split('private func value(', 1)[1].split('// UNMEASURED', 1)[0]
        for helper in [tap, value]:
            self.assertLess(helper.index('revealFixtureElement(target,'), helper.index('target.waitForExistence(timeout: 5)'))
            self.assertIn('maximumSwipes: 65', helper)
        for text in ['app.buttons.matching(identifier: id).count, 1',
                     'target.isEnabled && target.isHittable',
                     'app.windows.firstMatch.frame.contains(target.frame)', 'target.tap()']:
            self.assertIn(text, tap)
        self.assertIn('Array(target.label.utf8), Array(expected.utf8)', value)

    def test_fixture_flags_and_shared_scroll_helper_are_not_changed(self):
        for name in UI_CLASSES:
            before = (ORIGINALS / (name + '.swift.txt')).read_text()
            after = self.source('Tests/AppUITests/' + name + '.swift')
            def launch_flags(value):
                result = []
                for match in re.finditer(r'    private func launch\(', value):
                    end = value.index('\n    }', match.start())
                    result.append(re.findall(r'"--[^"]+"', value[match.start():end]))
                return result
            expected = launch_flags(before)
            self.assertEqual(len(expected), 1)
            for flags in launch_flags(after): self.assertEqual(flags, expected[0])
        helper = (ROOT / 'Tests/AppUITests/FailureScreenshot.swift').read_bytes()
        # debt-r3 re-pin: 705ba7fa… predates the 02c68098f import (bfaf25e8…); 812314637 only appended
        # tapEditorMenuItem (save-local moved into the editor's ⋯ menu, MP temp/index.wxml). Reveal helper unchanged.
        self.assertEqual(hashlib.sha256(helper).hexdigest(),
                         '5c7251686efbae6c8470ac0cf65a374cb19c5523443f41b5849a83936f61a272')


if __name__ == '__main__':
    unittest.main()
