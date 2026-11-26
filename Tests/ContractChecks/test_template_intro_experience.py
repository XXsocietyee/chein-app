#!/usr/bin/env python3
"""Focused source checks only; Swift behavior and Apple compilation are separate."""
from pathlib import Path
import json,re,sys,unittest
R=Path(sys.argv.pop(1)).resolve() if len(sys.argv)>1 and (Path(sys.argv[1])/'Core').is_dir() else Path(__file__).resolve().parents[2]
C=(R/'Core/TemplateAuthoringIntroExamples.swift').read_text();A=(R/'App/TemplateAuthoringIntroExperience.swift').read_text();H=(R/'App/TemplateAuthoringView.swift').read_text();D=(R/'docs/template-intro-experience.md').read_text();L=json.loads((R/'Resources/CreatorIntroExamples.xcstrings').read_text())['strings'];G=json.loads((R/'docs/registration/template-intro-experience.json').read_text());CT=(R/'Tests/CoreTests/TemplateAuthoringIntroExamplesTests.swift').read_text();AT=(R/'Tests/AppUnitTests/TemplateIntroExperienceTests.swift').read_text()
class IntroSourceContracts(unittest.TestCase):
 def test_priority_and_prefix_are_source_ordered(self):
  self.assertLess(C.index('!home.recommended.isEmpty'),C.index('!home.hot.isEmpty'));self.assertLess(C.index('!home.hot.isEmpty'),C.index('source = home.latest'))
  self.assertIn('maximum = 3',C);self.assertIn('source.prefix(Self.maximum)',C);self.assertNotIn('.filter',C)
 def test_normal_intro_has_one_entry_and_keeps_name_and_editor(self):
  self.assertEqual(H.count('TemplateAuthoringIntroExperience('),1);self.assertIn('onContinue: { step = .name }',H)
  # native r2: CYPillButton became a plain system Button with the same save action
  for x in ['private var name: some View','step = .edit','Button { model.save() } label: { Text("templateAuthor.saveLocal") }']:self.assertIn(x,H)
  self.assertIn('Text("publishParity.intro.lead")',A);self.assertIn('Text("publishParity.intro.tail")',A)
 def test_uses_only_existing_home_read_and_artwork(self):
  self.assertEqual(A.count('reader.discoveryTemplateHome()'),1);self.assertIn('DiscoveryArtwork(source:item.imgUrl,height:150)',A)
  self.assertNotRegex(A+C,r'URLSession|https?://|requestAuthorization|grant|Authorization|transport\.send')
 def test_never_mutates_draft_or_persistence(self):
  self.assertNotRegex(A,r'model\.draft\s*=|model\.(changed|save|prepare|confirm|discard|restore)\(|store\.(save|discard)|beginNewDraft')
  self.assertIn('self.retire(); advance()',A)
 def test_single_flight_and_owned_task_cancellation(self):
  for x in ['requestID == nil','let id = UUID(); requestID = id','self.requestID == id','request?.cancel()','!Task.isCancelled']:self.assertIn(x,A)
 def test_success_replaces_and_refresh_failure_keeps_prior_real_rows(self):
  self.assertIn('self.examples = result; self.phase = result.rows.isEmpty ? .empty : .ready',A)
  self.assertIn('self.examples?.rows.isEmpty == false ? .ready',A)
 def test_scope_covers_exact_owner_reader_and_draft(self):
  for x in ['Data($0.namespace.utf8)','Data($0.authorizationRevision.utf8)','ObjectIdentifier($0)','Data($0.discoveryPresentationIdentity.utf8)','model.metadataGeneration','model.mediaReviewGeneration','model.revision','encoder.encode(model.draft)','originalScope == scope()']:self.assertIn(x,A)
 def test_publication_ABA_and_scene_retire_old_actions(self):
  for x in ['model.objectWillChange.sink','controller.retire(); readerRevision &+= 1','.onDisappear { controller.retire() }','phase != .active { controller.retire() }','permit.generation == generation']:self.assertIn(x,A)
 def test_begin_and_skip_share_real_exit_without_data_gate(self):
  # Mini-program parity: one primary "begin" action and no second exit (the skip button was retired).
  self.assertEqual(A.count('Button(action:advance)'),1);self.assertEqual(A.count('.disabled(!controller.canContinue || scenePhase != .active)'),1)
  line=next(x for x in A.splitlines() if 'var canContinue:' in x);self.assertNotIn('configured',line);self.assertNotIn('phase',line);self.assertNotIn('examples',line)
 def test_retry_and_empty_unavailable_loading_states_are_visible(self):
  for x in ['case .failed:','case .empty,.ready:','case .unavailable:','case .idle,.loading:','controller.load(permit)']:self.assertIn(x,A)
 def test_no_id_collision_when_source_duplicates_are_displayed(self):
  self.assertIn('ForEach(Array(examples.rows.enumerated()),id:\\.offset)',A);self.assertIn('Text(verbatim:item.title)',A)
 def test_catalog_keys_use_explicit_named_table(self):
  # fix-parity C-I3: no examples now draws nothing, so 'creatorIntro.empty' is no longer rendered (three keys).
  # The restyled intro renders only four of the nine catalogued keys (examples header, loading/unavailable text,
  # scope note and skip were retired); every rendered key must stay catalogued and use the named table.
  keys=set(re.findall(r'"(creatorIntro\.(?:examples|unnamed|loading|failed|retry|empty|unavailable|scope|skip))"',A));self.assertEqual(keys,{'creatorIntro.unnamed','creatorIntro.failed','creatorIntro.retry'});self.assertTrue(keys<=set(L));self.assertEqual(len(L),9)
  self.assertEqual(A.count('tableName:"CreatorIntroExamples"'),3);self.assertTrue(all(set(v['localizations'])=={'en','zh-Hans'} for v in L.values()))
 def test_tests_and_registration_are_complete_and_native_unrun(self):
  self.assertEqual(CT.count('func test'),9);self.assertEqual(AT.count('func test'),16);self.assertEqual(len(G['production_sources']),2);self.assertTrue(G['actual_PBX_registration']);self.assertTrue(G['CoreTests_directory_discovery']);self.assertIn('NOT_RUN',D)
 def test_projection_limits_and_old_stack_are_explicit(self):
  for x in ['not Mini row.name/sysCategoryList','does not claim the Mini','separate three-page back-stack parity','No private Mini module']:self.assertIn(x,D)
if __name__=='__main__':unittest.main(verbosity=2)
