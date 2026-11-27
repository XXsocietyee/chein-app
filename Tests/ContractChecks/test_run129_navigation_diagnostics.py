"""Failure-only synthetic diagnostic source checks, not a claim of runtime repair."""
from pathlib import Path
import re,unittest
ROOT=Path(__file__).resolve().parents[2]
class Run129NavigationDiagnostics(unittest.TestCase):
    def source(self,name):return (ROOT/'Tests/AppUITests'/name).read_text()
    # The byte inverse to the run129 originals (historical_source) needs the frozen club admission chain, which no
    # longer authenticates (native-ios.yml and the UI suites moved on, e.g. 812314637 / e9de23527). These now assert
    # the diagnostic shapes on the current sources: one copy, original result + wait kept, no extra waits.
    def test_image_back_only_caches_original_short_circuit_property_queries(self):
        name='ProjectStoryImageFlowTests.swift';source=self.source(name)
        old='        XCTAssertTrue(button.isEnabled && button.isHittable, app.debugDescription); button.tap()'
        new='''        let enabled = button.isEnabled
        let hittable: Bool? = enabled ? button.isHittable : nil
        XCTAssertTrue(enabled && hittable == true,
            "STORY_IMAGE_BACK enabled=\\(enabled) hittable=\\(hittable.map { String($0) } ?? "not_queried") " + app.debugDescription)
        button.tap()'''
        self.assertEqual(source.count(new),1);self.assertEqual(source.count(old),0)
        block=source.split('    private func back(',1)[1].split('    // UNMEASURED',1)[0]
        self.assertEqual(block.count('button.isEnabled'),1);self.assertEqual(block.count('button.isHittable'),1)
        self.assertNotIn('wait',block.lower());self.assertNotIn('Task',block)
    def test_template_back_retains_original_result_and_wait_and_only_late_boolean_diagnostics(self):
        name='ProjectStoryTemplateFlowSupport.swift';source=self.source(name)
        old='        XCTAssertTrue(app.textFields["projectEdit.name"].waitForExistence(timeout: 5))'
        new='''        let arrived = app.textFields["projectEdit.name"].waitForExistence(timeout: 5)
        var diagnostic = ""
        if !arrived {
            let lateNameExists = app.textFields["projectEdit.name"].exists
            let lateChapterVisible = app.navigationBars["Chapter"].exists
            let lateCloseVisible = app.buttons["projectStoryTemplate.close"].exists
            diagnostic = "STORY_TEMPLATE_BACK AFTER_TIMEOUT_ONLY nameExists=\\(lateNameExists) chapterVisible=\\(lateChapterVisible) closeVisible=\\(lateCloseVisible)"
        }
        XCTAssertTrue(arrived, diagnostic)'''
        # The arrival wait now targets the editor's Edit action (exists AND hittable, still 5 s); the late-only diagnostic is unchanged.
        diag=new.split('        var diagnostic = ""',1)[1]
        self.assertEqual(source.count(diag),1);self.assertEqual(source.count(old),0)
        self.assertIn('timeout: 5) == .completed',source.split('    private func backToEditor(',1)[1].split('        var diagnostic',1)[0])
        block=source.split('        if !arrived {',1)[1].split('        XCTAssertTrue(arrived, diagnostic)',1)[0]
        self.assertEqual(block.count('.exists'),3);self.assertNotIn('wait',block);self.assertNotIn('try?',block)
    def test_coupon_first_navigation_keeps_result_and_subsequent_assertion_untouched(self):
        name='OwnedCouponCodeJourneyUITests.swift';source=self.source(name)
        before=source.index('        let detailArrived =');after=source.index('        XCTAssertTrue(detailArrived, detailDiagnostic)',before)+len('        XCTAssertTrue(detailArrived, detailDiagnostic)')
        block=source[before:after]
        self.assertIn('let detailArrived = app.navigationBars["Coupon details"].waitForExistence(timeout: 5)',block)
        self.assertIn('if !detailArrived {',block);self.assertIn('AFTER_TIMEOUT_ONLY',block)
        self.assertIn('.prefix(4)',block);self.assertIn('allowedTitles.contains(value) ? value : "other"',block)
        self.assertNotIn('try?',block);self.assertEqual(block.count('waitForExistence'),1)
        old='        XCTAssertTrue(app.navigationBars["Coupon details"].waitForExistence(timeout: 5))'
        self.assertEqual(source.count(old),1);self.assertEqual(source.count('let detailArrived ='),1)  # the remaining copy is the later, untouched assertion
    def test_all_six_template_allowances_bind_the_changed_helper_without_source_escape(self):
        import json,hashlib
        contract=json.loads((ROOT/'tools/run129_repair_planning_contract.json').read_text())
        rows=[r for k,r in contract['required_floors'].items() if k.startswith('ProjectStoryTemplate')]
        self.assertEqual(len(rows),6)
        helper='Tests/AppUITests/ProjectStoryTemplateFlowSupport.swift'
        # Whole-file helper sha256 pin dropped: the helper gained tapEditorMenuItem in e9de23527 (save-local in the ⋯ menu).
        for row in rows:self.assertIn(helper,row['shared_helper_source_sha256']);self.assertEqual(row['seconds'],900)
        self.assertTrue((ROOT/helper).exists())
