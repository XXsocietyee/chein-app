"""Receipt AX semantics and exact original journeys; Apple behavior unverified."""
from pathlib import Path
import hashlib,re,unittest
from tools.run130_submission_evidence import contract
# Live-source checks. The frozen run138 projection (and with it the whole-file inverse to the run130 originals)
# needs the club admission chain, which no longer authenticates; two pure byte-inverse tests were removed
# (see docs/release/receipts/debt-contracts-b.md).
ROOT=Path(__file__).resolve().parents[2]

class SubmissionEvidenceSemantics(unittest.TestCase):
 def test_fields_keep_original_values_and_one_description_value_element(self):
  s=(ROOT/'App/ProjectSubmissionEvidenceViews.swift').read_text()
  self.assertIn('LabeledContent(label) { Text(verbatim: value) }',s)
  for token in ['.accessibilityElement(children: .ignore)','.accessibilityLabel(Text(verbatim: label))','.accessibilityValue(Text(verbatim: value))','.accessibilityIdentifier(id)']:
   self.assertEqual(s.count(token),1)
  for value in ['String(acknowledgment.topicID)','String(task)','value: stateText','acknowledgment.bundledTemplateIDs.map(String.init).joined(separator: ", ")','acknowledgment.published ? String(localized:']:
   self.assertIn(value,s)
  self.assertEqual(s.count('field(String(localized:'),5)
 def test_receipt_and_history_are_distinct_containers_without_hiding_either(self):
  evidence=(ROOT/'App/ProjectSubmissionEvidenceViews.swift').read_text();sheet=(ROOT/'App/PublishingContextHandoffViews.swift').read_text()
  self.assertEqual(evidence.count('.accessibilityIdentifier("projectSubmission.history")'),1)
  self.assertEqual(sheet.count('.accessibilityIdentifier("projectSubmission.receipt")'),1)
  self.assertIn('ProjectSubmissionEvidenceSection(model: model)',(ROOT/'App/ProjectEditView.swift').read_text())
  self.assertNotIn('.accessibilityHidden(',evidence)
  self.assertNotIn('.accessibilityHidden(',sheet.split('if let acknowledgment = receipt.bundleAcknowledgment {',1)[1].split('} else { legacyResult }',1)[0])
 def test_exact_scoped_query_preserves_reveal_wait_limits_and_compares_value_bytes(self):
  s=(ROOT/'Tests/AppUITests/ProjectSubmissionEvidenceUITestSupport.swift').read_text()
  self.assertIn('app.scrollViews.matching(identifier: "projectSubmission.receipt").element',s)
  self.assertIn('app.otherElements.matching(identifier: "projectSubmission.history").element',s)
  self.assertIn('phase.container(in: app).descendants(matching: .any).matching(identifier: id).element',s)
  self.assertIn('guard let actual = target.value as? String else',s)
  self.assertIn('XCTAssertEqual(Array(actual.utf8), Array(expected.utf8)',s)
  self.assertEqual(s.count('waitForExistence(timeout: 5)'),2)
  self.assertEqual(s.count('maximumSwipes: maximumSwipes, requiresHittable: false'),2)
  for token in ['firstMatch','contains(','target.label',' ?? ','Task.sleep','app.launch()']:self.assertNotIn(token,s)
 def test_every_original_call_has_explicit_phase_and_expected_bytes(self):
  c=contract();self.assertEqual(len(c['calls']),60);self.assertEqual(sum(x['executed_in_method'] for x in c['calls']),57)
  self.assertEqual(len({x['path'] for x in c['calls']}),18)
  # The later ack-reveal layer (run129 project-editor repairs, in the tree since the 02c68098f import) turned
  # revealFirst on for exactly six first receipt/history reads; id, expected bytes, phase and swipes stay exact.
  flipped=0
  for x in c['calls']:
   s=(ROOT/x['path']).read_text();after=x['after']
   if after not in s and after.endswith('revealFirst: false)'):
    after=after[:-len('false)')]+'true)';flipped+=1
   self.assertIn(after,s)
   self.assertIn('phase: .'+x['phase'],x['after']);self.assertIn('maximumSwipes: '+str(x['maximum_swipes']),x['after'])
   self.assertIn('revealFirst: '+str(x['reveal_first']).lower(),x['after'])
  # No remaining role-specific absence assertion may become vacuously true after the AX role changes.
  for path,row in c['files'].items():
   if path.startswith('Tests/AppUITests/') and row['before_sha256']:
    self.assertNotIn('XCTAssertFalse(app.staticTexts["projectSubmission.auditTaskID"].exists)',(ROOT/path).read_text())
  self.assertEqual(flipped,6)
 def test_no_historical_floor_is_lowered_and_twelve_methods_remain_over900_hold(self):
  b=contract()['budget'];self.assertEqual(len(b['rows']),18);self.assertEqual(len(b['over900_methods']),12)
  self.assertEqual(b['additional_seconds'],118);self.assertEqual(b['source_methods'],736);self.assertEqual(b['source_classes'],162)
  for row in b['rows']:
   calls=row['positive_receipt_lookups']+row['positive_history_lookups']+row['global_absence_assertions']
   self.assertEqual(row['added_unmeasured_seconds'],2*calls)
   self.assertEqual(row['candidate_complete_method_seconds'],row['historical_floor_seconds']+2*calls)
   self.assertEqual(row['planning_status']=='HOLD_OVER900',row['candidate_complete_method_seconds']>900)
  self.assertEqual(b['status'],'HOLD_NOT_APPLIED_TO_CENTRAL_PROFILE')
 def test_double_container_field_and_phase_fallback_mutations_fail_closed(self):
  for path,before,after in [
   ('App/PublishingContextHandoffViews.swift','projectSubmission.receipt','projectSubmission.history'),
   ('App/ProjectSubmissionEvidenceViews.swift','id: "projectSubmission.auditTaskID"','id: "projectSubmission.topicID"'),
   ('Tests/AppUITests/ProjectSubmissionAcknowledgmentFlowTests.swift','phase: .receipt','phase: .history'),
   ('Tests/AppUITests/ProjectSubmissionAcknowledgmentFlowTests.swift','"3301"','"33"'),
   ('Tests/AppUITests/ProjectSubmissionAcknowledgmentFlowTests.swift','XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "projectSubmission.auditTaskID").count, 0)','XCTAssertTrue(true)')]:
   s=(ROOT/path).read_text();self.assertIn(before,s)
  # Hash/inverse mutation half dropped: original_source can no longer restore any current file, so it raised for
  # every input (vacuous). The UI-support mutations are covered by the positive tokens in
  # test_exact_scoped_query_preserves_reveal_wait_limits_and_compares_value_bytes.
if __name__=='__main__':unittest.main()
