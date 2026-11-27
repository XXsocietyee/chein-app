"""Topic-media host, chapter-removal and club-lead mounts in the project editor (source checks only).

History: this module used to reverse App/ProjectEditView.swift hunk by hunk back to its run130
bytes (club lead -> chapter removal -> topic host -> version row). That byte chain broke when the
editor was rebuilt (the remote version/mode rows are gone from the editor since the 02c68098f
import; 03033d614 codemodded .sheet -> .cySheet; later MP-order work moved sections). The
behavior the chain protected is asserted on the current sources instead:
  * the existing topic-media feature contract (test_project_topic_media_app.contracts) still holds;
  * the topic-media host is mounted exactly once, directly after basicFields;
  * chapter removal keeps its confirmation/disable/retire guards (data safety), and its sources
    are re-pinned so any edit to them needs review again;
  * the club-lead fields stay mounted exactly once on the same model.
"""
from pathlib import Path
import hashlib
import importlib.util
import unittest

ROOT = Path(__file__).resolve().parents[2]
AFTER_HUNK = (
    '                basicFields\n'
    '                ProjectTopicMediaHost(editor: model)\n'
)
FEATURE_PATHS = (
    'App/ProjectTopicMediaPresentation.swift',
    'App/ProjectTopicMediaInspector.swift',
    'Core/ProjectTopicImageUpload.swift',
    'App/ProjectTopicMediaHost.swift',
    'App/AppCompositionRoot.swift',
)

# Re-pinned to current bytes. App/ProjectChapterRemovalPresentation.swift: 03033d614 changed only
# `content.sheet(item:` -> `content.cySheet(item:`. Core/ProjectEditCoordinator.swift: unchanged
# since the 02c68098f import. Core/ProjectChapterRemoval.swift keeps its original pin.
CHAPTER_SOURCE_SHAS = {
    'App/ProjectChapterRemovalPresentation.swift': '6bd373dace2a192c3e4437adde3901f3e75bc1787bd9a134a57eb1d465ca0a8f',
    'Core/ProjectChapterRemoval.swift': 'c99b2902a9d481655059ec80a3e9eb390fc06298d8a6ccb70dcecda881100120',
    'Core/ProjectEditCoordinator.swift': '6b62fcd2771835199aafa4fd7e209c0f95e66f398d8b936989fcbb087517c467',
}
CHAPTER_TOKENS = ['!coordinator.hasUnconfirmedChapterRemoval',
                  '.onDelete { chapterRemoval.open(offsets: $0, captured: removalCapture) }',
                  '.deleteDisabled(removalCapture == nil)',
                  'chapterRemoval.retire(); starter.retire(); pending.retire(); model.leave()']
CLUB_MOUNT_FORMS = {'ProjectClubLeadFields(model: model)',
                    'ProjectClubLeadFields(model: model).id("project-issue-anchor-clubLead")'}


def verify_chapter_sources(sources):
    assert set(sources) == set(CHAPTER_SOURCE_SHAS)
    for path, sha in CHAPTER_SOURCE_SHAS.items():
        assert hashlib.sha256(sources[path].encode('utf-8')).hexdigest() == sha, path


def verify_editor(source):
    assert source.count('ProjectTopicMediaHost(') == 1, 'Topic media host must be mounted exactly once'
    assert source.count(AFTER_HUNK) == 1, 'Topic media host must follow basicFields on the same editor model'
    for token in CHAPTER_TOKENS:
        assert source.count(token) == 1, token
    mounts = [line for line in source.splitlines() if line.strip() in CLUB_MOUNT_FORMS]
    assert len(mounts) == 1, 'Club lead fields must be mounted exactly once'
    assert source.count('ProjectClubLeadFields(') == 1


def verify_current_feature_sources(sources):
    """Run the existing feature contract on current sources.

    Only its helper function is invoked; no TestCase is imported into this module,
    avoiding duplicate unittest discovery/counting.
    """
    path = ROOT / 'Tests/ContractChecks/test_project_topic_media_app.py'
    spec = importlib.util.spec_from_file_location('_run130_current_topic_contract', path)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    assert module.contracts(*sources)


class Run130TopicMediaSourceAdapterTests(unittest.TestCase):
    def current_source(self):
        return (ROOT / 'App/ProjectEditView.swift').read_bytes().decode('utf-8')

    def feature_sources(self):
        return tuple((ROOT / path).read_bytes().decode('utf-8') for path in FEATURE_PATHS)

    def test_exact_current_feature_contract_precedes_reversal(self):
        verify_current_feature_sources(self.feature_sources())
        verify_editor(self.current_source())

    def test_new_host_hunk_change_removal_duplication_or_relocation_is_rejected(self):
        source = self.current_source()
        line = '                ProjectTopicMediaHost(editor: model)\n'
        candidates = [
            source.replace(line, '', 1),
            source.replace(line, line + line, 1),
            source.replace(line, line.replace('model)', 'otherModel)'), 1),
            source.replace(line, '', 1) + line,
            source.replace(AFTER_HUNK, AFTER_HUNK.replace('basicFields', 'basicFields.disabled(true)'), 1),
        ]
        for candidate in candidates:
            self.assertNotEqual(candidate, source)
            with self.subTest(candidate_sha=hashlib.sha256(candidate.encode()).hexdigest()):
                with self.assertRaises(AssertionError):
                    verify_editor(candidate)

    def test_chapter_feature_mutation_cannot_hide_behind_historical_reversal(self):
        sources = {path: (ROOT / path).read_bytes().decode('utf-8')
                   for path in CHAPTER_SOURCE_SHAS}
        verify_chapter_sources(sources)
        for path in sources:
            changed = dict(sources); changed[path] += '\n'
            with self.subTest(path=path), self.assertRaises(AssertionError):
                verify_chapter_sources(changed)
        source = self.current_source()
        verify_editor(source)
        for token in CHAPTER_TOKENS:
            with self.subTest(token=token), self.assertRaises(AssertionError):
                verify_editor(source.replace(token, 'REMOVED', 1))

    def test_club_lead_feature_cannot_hide_behind_historical_reversal(self):
        source = self.current_source()
        verify_editor(source)
        mounts = [line for line in source.splitlines(keepends=True) if line.strip() in CLUB_MOUNT_FORMS]
        self.assertEqual(len(mounts), 1)
        mount = mounts[0]
        for altered in [source.replace(mount, '', 1),
                        source.replace(mount, mount + mount, 1),
                        source.replace(mount, mount.replace('model: model', 'model: other'), 1)]:
            self.assertNotEqual(altered, source)
            with self.subTest(digest=hashlib.sha256(altered.encode()).hexdigest()), self.assertRaises(AssertionError):
                verify_editor(altered)

    def test_current_feature_mutation_cannot_hide_behind_historical_reversal(self):
        current = self.feature_sources()
        for index, token in [(0, 'editor.topicMediaContext == original.context'),
                             (1, 'O_NOFOLLOW'), (2, 'currentApproval() == approval'),
                             (3, 'RetainedImagePresenterHost'), (4, 'issued.fields.contains(field)')]:
            changed = list(current); self.assertIn(token, changed[index]); changed[index] = changed[index].replace(token, 'REMOVED')
            with self.subTest(token=token), self.assertRaises(AssertionError):
                verify_current_feature_sources(tuple(changed))


if __name__ == '__main__':
    unittest.main()
