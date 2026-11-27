"""Run130 route-fixture bottom inset; runtime acceptance remains unproven.

The fixture's bytes have not changed since the 02c68098f import, but the run130 pins (fixture
AFTER/BEFORE and the shared FailureScreenshot helper hash) were taken before that import, and the
helper has since grown (812314637 added tapEditorMenuItem) and computes its bound from `screen`
instead of `app.frame`. The fixture and UI journey stay hash-pinned; the helper's bounded
viewport is asserted by its exact line instead of a whole-file hash.
"""
from pathlib import Path
import hashlib,unittest
ROOT=Path(__file__).resolve().parents[2]
REL='App/PlayRouteMapFixture.swift'
BEFORE='f5bfa40f5c95c2a26b5047c49aa5a708a45684a3f077ac8334480e24c9046729'
AFTER='6e25f5e5babf485ec67991503979d68df4ce9bddc8cc5c82e0694e75a29d86ae'
INSERT='                .padding(.bottom, 8)\n'
UI='Tests/AppUITests/PlayRouteMapFlowTests.swift'
UI_SHA='bfdd211e9113d87788f6555d4a4736c6e77e04175d84807981df0fb34d6ed4ca'
VIEWPORT='        var bottom = screen.maxY - 40\n'
def verify(source,ui,helper):
    assert hashlib.sha256(source.encode()).hexdigest()==AFTER
    assert source.count(INSERT)==1
    assert hashlib.sha256(source.replace(INSERT,'',1).encode()).hexdigest()==BEFORE
    assert hashlib.sha256(ui.encode()).hexdigest()==UI_SHA
    assert helper.count(VIEWPORT)==1
class Run130SourceBoundary(unittest.TestCase):
    def sources(self):return (ROOT/REL).read_text(),(ROOT/UI).read_text(),(ROOT/'Tests/AppUITests/FailureScreenshot.swift').read_text()
    def test_only_the_approved_layout_or_label_line_is_added(self):verify(*self.sources())
    def test_removed_or_changed_line_is_rejected(self):
        source,ui,helper=self.sources()
        for value in ['',INSERT+'\n',INSERT.replace('8','80')]:
            with self.subTest(value=value),self.assertRaises(AssertionError):verify(source.replace(INSERT,value,1),ui,helper)
    def test_original_method_wait_and_exact_assertions_cannot_change(self):
        source,ui,helper=self.sources()
        for a,b in [('XCTAssertTrue','XCTAssertFalse'),('timeout: 5','timeout: 20'),('func test','func skipped')]:
            self.assertIn(a,ui)
            with self.assertRaises(AssertionError):verify(source,ui.replace(a,b,1),helper)
    def test_shared_viewport_and_existing_bounded_scroll_are_exact(self):
        source,ui,helper=self.sources();self.assertIn(VIEWPORT,helper)
        verify(source,ui,helper)
        with self.assertRaises(AssertionError):verify(source,ui,helper.replace('screen.maxY - 40','screen.maxY',1))
if __name__=='__main__':unittest.main()
