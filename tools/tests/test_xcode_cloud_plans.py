"""Xcode Cloud shard and unsigned-build contracts. Does not run Xcode or swift test."""
import importlib.util
import json
import pathlib
import re
import shutil
import subprocess
import tempfile
import unittest
import xml.etree.ElementTree as ET

ROOT = pathlib.Path(__file__).resolve().parents[2]
CLASS_PATTERN = re.compile(
    r'(?m)^(?:@\w+(?:\([^)\n]*\))?\s+)*(?:(?:public|internal|fileprivate|private|final|open|nonisolated)\s+)*class\s+([A-Za-z_][A-Za-z0-9_]*)\b[^{;\n]*\bXCTestCase\b'
)
SHARDS = ('Shard01', 'Shard02', 'Shard03', 'Shard04')


def classes():
    found = []
    for path in sorted(ROOT.glob('Tests/AppUnitTests/**/*.swift')):
        found.extend(CLASS_PATTERN.findall(path.read_text()))
    return found


class XcodeCloudPlanTests(unittest.TestCase):
    def test_generator_pattern_matches_this_contract(self):
        source = (ROOT / 'tools/generate_project.py').read_text()
        self.assertIn(CLASS_PATTERN.pattern, source)
        self.assertIn('APP_UNIT_SHARDS=4', source)

    def test_committed_project_matches_generator_and_shards_cover_every_class_once(self):
        names = classes()
        self.assertEqual(len(names), len(set(names)))
        self.assertGreater(len(names), 4)
        with tempfile.TemporaryDirectory(prefix='questify-xcode-cloud-') as directory:
            scratch = pathlib.Path(directory)
            for folder in ('App', 'Core', 'Tests', 'Resources'):
                (scratch / folder).symlink_to(ROOT / folder, target_is_directory=True)
            (scratch / 'tools').mkdir()
            shutil.copyfile(ROOT / 'tools/generate_project.py', scratch / 'tools/generate_project.py')
            subprocess.run(['python3', '-B', str(scratch / 'tools/generate_project.py')], check=True, cwd=scratch)
            for relative in (
                'Questify.xcodeproj/project.pbxproj',
                'Questify.xcodeproj/xcshareddata/xcschemes/Questify.xcscheme',
                'Questify.xcodeproj/xcshareddata/xcschemes/QuestifyAppUnitTests.xcscheme',
            ):
                self.assertEqual((ROOT / relative).read_bytes(), (scratch / relative).read_bytes(), relative)
            for label in SHARDS:
                relative = f'Questify.xcodeproj/xcshareddata/xctestplans/QuestifyAppUnitTests-{label}.xctestplan'
                scheme = f'Questify.xcodeproj/xcshareddata/xcschemes/QuestifyAppUnitTests-{label}.xcscheme'
                self.assertEqual((ROOT / relative).read_bytes(), (scratch / relative).read_bytes(), relative)
                self.assertEqual((ROOT / scheme).read_bytes(), (scratch / scheme).read_bytes(), scheme)
        included = {}
        for label in SHARDS:
            plan = json.loads((ROOT / f'Questify.xcodeproj/xcshareddata/xctestplans/QuestifyAppUnitTests-{label}.xctestplan').read_text())
            target, = plan['testTargets']
            self.assertFalse(target['parallelizable'])
            self.assertEqual(target['target']['name'], 'QuestifyAppUnitTests')
            skipped = set(target['skippedTests'])
            kept = set(names) - skipped
            self.assertTrue(kept)
            self.assertFalse(kept & skipped)
            for name in kept:
                self.assertNotIn(name, included)
                included[name] = label
            scheme = ET.parse(ROOT / f'Questify.xcodeproj/xcshareddata/xcschemes/QuestifyAppUnitTests-{label}.xcscheme')
            self.assertFalse(scheme.findall('.//SkippedTests'))
            self.assertFalse(scheme.findall('.//Testables'))
            reference = scheme.find('TestAction/TestPlans/TestPlanReference')
            self.assertEqual(reference.get('default'), 'YES')
            self.assertEqual(reference.get('reference'), f'container:Questify.xcodeproj/xcshareddata/xctestplans/QuestifyAppUnitTests-{label}.xctestplan')
            built = {node.get('BlueprintName') for node in scheme.findall('BuildAction/BuildActionEntries/BuildActionEntry/BuildableReference')}
            self.assertEqual(built, {'Questify', 'QuestifyAppUnitTests'})
        self.assertEqual(set(included), set(names))
        full = ET.parse(ROOT / 'Questify.xcodeproj/xcshareddata/xcschemes/QuestifyAppUnitTests.xcscheme')
        self.assertFalse(full.findall('.//SkippedTests'))
        self.assertFalse(full.findall('.//SelectedTests'))
        self.assertFalse(full.findall('.//TestPlans'))
        shared = ET.parse(ROOT / 'Questify.xcodeproj/xcshareddata/xcschemes/Questify.xcscheme')
        self.assertEqual(shared.getroot().tag, 'Scheme')

    def test_prepare_disables_signing_without_touching_the_deployment_target_or_this_checkout(self):
        spec = importlib.util.spec_from_file_location('xcode_cloud_prepare', ROOT / 'tools/xcode_cloud_prepare.py')
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        disable_signing = module.disable_signing
        before = {
            relative: (ROOT / relative).read_bytes()
            for relative in (
                'Questify.xcodeproj/project.pbxproj',
                'Vendor/GLTFKit2/GLTFKit2.xcodeproj/project.pbxproj',
                'Config/Base.xcconfig',
                'Config/AppUnitTests.xcconfig',
            )
        }
        with tempfile.TemporaryDirectory() as directory:
            checkout = pathlib.Path(directory)
            for relative, raw in before.items():
                path = checkout / relative
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(raw)
            disable_signing(checkout)
            once = {path.relative_to(checkout).as_posix(): path.read_bytes() for path in checkout.rglob('*') if path.is_file()}
            disable_signing(checkout)
            twice = {path.relative_to(checkout).as_posix(): path.read_bytes() for path in checkout.rglob('*') if path.is_file()}
            self.assertEqual(once, twice)
            gltf = (checkout / 'Vendor/GLTFKit2/GLTFKit2.xcodeproj/project.pbxproj').read_text()
            self.assertEqual(gltf.count('IPHONEOS_DEPLOYMENT_TARGET = 17.0;'), 2)
            self.assertNotIn('IPHONEOS_DEPLOYMENT_TARGET = 12.1;', gltf)
            self.assertIn('CODE_SIGNING_ALLOWED = NO;', gltf)
            app = (checkout / 'Questify.xcodeproj/project.pbxproj').read_text()
            self.assertGreaterEqual(app.count('"CODE_SIGNING_ALLOWED" = "NO";'), 8)
            for relative in ('Config/Base.xcconfig', 'Config/AppUnitTests.xcconfig'):
                text = (checkout / relative).read_text()
                self.assertEqual(text.count('\nCODE_SIGNING_ALLOWED = NO\n'), 1)
                self.assertTrue(text.endswith('CODE_SIGNING_REQUIRED = NO\n'))
        for relative, raw in before.items():
            self.assertEqual((ROOT / relative).read_bytes(), raw)

    def test_ci_scripts_do_not_generate_sign_or_store_secrets(self):
        post_clone = (ROOT / 'ci_scripts/ci_post_clone.sh').read_text()
        post_build = (ROOT / 'ci_scripts/ci_post_xcodebuild.sh').read_text()
        self.assertNotRegex(post_clone, r'(?m)^(?!#).*generate_project\.py')
        self.assertIn('xcode_cloud_prepare.py --checkout', post_clone)
        self.assertIn('CI_XCODEBUILD_ACTION', post_build)
        self.assertIn('swift test', post_build)
        self.assertIn('Questify', post_build)
        for text in (post_clone, post_build, (ROOT / 'tools/xcode_cloud_prepare.py').read_text()):
            self.assertNotIn('BEGIN PRIVATE', text)
            self.assertNotIn('.p12', text)
            self.assertNotIn('.p8', text)
        self.assertFalse(list(ROOT.glob('.github/workflows/*xcode*')))
        self.assertNotIn('xcode-27', (ROOT / '.github/workflows/native-ios.yml').read_text())


if __name__ == '__main__':
    unittest.main()
