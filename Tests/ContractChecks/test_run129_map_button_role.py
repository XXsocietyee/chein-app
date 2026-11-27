"""Run129 UI65 AX-role contract on the alternative map list; no locator fallback or business-authority change.

The original check reconstructed the run129 bytes of App/QuestifyDensityMap.swift through
tools/map_readonly_inverse.py. 8f196dac0 (L3 P-038, MapKit Markers in the density map) and
f73e88a3e (design P1 L2 search) rewrote both files, so the byte inverse no longer applies. The
behavior it protected is asserted directly on the current list-pin control and its UI journeys.
"""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[2]
INSERT='                        .accessibilityAddTraits(.isButton)\n'
REQUIRED=['.accessibilityAddTraits(pin.id == selectedID ? .isSelected : [])',
          '.disabled(onSelect == nil)',
          '.accessibilityLabel(Text(verbatim: pin.title))',
          '.accessibilityIdentifier("mapList.pin.\\(pin.id)")']
def pin_control(view):
    start=view.index('.accessibilityLabel(Text(verbatim: pin.title))')
    start=view.rindex('}.buttonStyle(.plain)',0,start)
    end=view.index('.disabled(onSelect == nil)',start)+len('.disabled(onSelect == nil)')
    return view[start:end]
def verify(view,tests):
    assert view.count(INSERT)==1, 'Exactly one explicit button role on the list pin'
    control=pin_control(view)
    assert INSERT in control+'\n', 'The button role belongs to the list pin control'
    for marker in REQUIRED:
        assert marker in control, marker
    assert 'let button = app.buttons[id]' in tests
    assert 'app.otherElements[' not in tests, 'No other-element locator fallback'
    assert 'XCTAssertFalse(first.isSelected)' in tests
    assert 'XCTAssertTrue(button.waitForExistence(timeout: 5), app.debugDescription)' in tests
class Run129MapButtonRole(unittest.TestCase):
    def sources(self):
        view=(ROOT/'App/QuestifyDensityMap.swift').read_text()
        tests=(ROOT/'Tests/AppUITests/SearchMapAlternativeListFlowTests.swift').read_text()
        return view,tests
    def test_only_explicit_button_role_added_to_the_original_control(self):verify(*self.sources())
    def test_button_selected_disabled_and_label_cannot_be_dropped_or_replaced(self):
        view,tests=self.sources()
        for old,new in [(INSERT,''),('.accessibilityAddTraits(.isButton)','.accessibilityAddTraits(.isStaticText)'),('.disabled(onSelect == nil)','.disabled(false)'),('                        .accessibilityAddTraits(pin.id == selectedID ? .isSelected : [])\n                        .accessibilityIdentifier','                        .accessibilityAddTraits([])\n                        .accessibilityIdentifier'),('.accessibilityLabel(Text(verbatim: pin.title))','.accessibilityLabel(Text("Short title"))')]:
            self.assertIn(old,view)
            with self.subTest(old=old),self.assertRaises((AssertionError,ValueError)):verify(view.replace(old,new,1),tests)
    def test_other_element_locator_or_weaker_readiness_is_rejected(self):
        view,tests=self.sources()
        for old,new in [('app.buttons[id]','app.otherElements[id]'),('XCTAssertTrue(button.waitForExistence(timeout: 5), app.debugDescription)','XCTAssertTrue(button.waitForExistence(timeout: 8), app.debugDescription)'),('XCTAssertFalse(first.isSelected)','XCTAssertTrue(true)')]:
            self.assertIn(old,tests)
            with self.subTest(old=old),self.assertRaises(AssertionError):verify(view,tests.replace(old,new,1))
    def test_all_three_complete_cases_and_maximum_type_remain(self):
        _,tests=self.sources();self.assertEqual(tests.count('    func test'),3)
        self.assertIn('for chinese in [false, true]',tests)
        self.assertIn('dynamicTypeSize: "accessibility5"',tests)
        self.assertIn('maximumSwipes: 20',tests)
        self.assertIn('XCTAssertFalse',tests)
if __name__=='__main__':unittest.main()
