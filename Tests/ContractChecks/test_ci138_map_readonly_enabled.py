"""CI138 UI68 candidate: preserve native disabled state on the complete AX row.

These exact source checks do not establish native AX behavior. Run the original
UI68 journey on Apple; never substitute a weaker enabled-state assertion.
"""
from pathlib import Path
import re
import unittest
import tempfile

ROOT = Path(__file__).resolve().parents[2]
# The BEFORE/AFTER/UI hash pins and the run138 feature-batch projection were
# dropped: QuestifyDensityMap.swift moved on (8f196dac0, MapKit markers) and the
# UI flow file moved on (f73e88a3e), so the frozen bytes could no longer be read.
# The checks below pin the same disabled/AX row semantics on the live source.
DISABLED = '                        .disabled(onSelect == nil)\n'
ROLE = '                        .accessibilityAddTraits(.isButton)\n'
HEAD = '                    }.buttonStyle(.plain)\n                        .accessibilityElement(children: .ignore)\n'
TAIL = '                        .accessibilityIdentifier("mapList.pin.\\(pin.id)")\n'
LIST_ROW = '                ForEach(currentPins) { pin in\n'
OLD_ORDER = '                    }.buttonStyle(.plain)\n' + DISABLED + '                        .accessibilityElement(children: .ignore)\n'


def original_source(source):
    """The pre-UI68 order (disabled before the AX element), for negative controls."""
    return source.replace(TAIL + DISABLED, TAIL, 1).replace(HEAD, OLD_ORDER, 1)


def verify(source, tests):
    if '\r' in source or '\r' in tests:
        raise ValueError('CRLF or CR bytes are not admitted')
    if source.count(DISABLED) != 1 or source.count(OLD_ORDER) != 0:
        raise ValueError('Unreviewed alternative-list source')
    if source.count(TAIL + DISABLED) != 1 or source.count(HEAD) != 1:
        raise ValueError('Disabled must wrap the entire custom accessibility row')
    if source.count(LIST_ROW) != 1 or source.index(LIST_ROW) > source.index(HEAD):
        raise ValueError('Alternative-list row moved')
    block = source[source.index(LIST_ROW):source.index(TAIL + DISABLED)]
    row = source[source.index(HEAD):source.index(TAIL + DISABLED)]
    for required in (
        '.accessibilityLabel(Text(verbatim: pin.title))',
        '.accessibilityValue(pin.id == selectedID ? Text("mapList.selected") : Text(""))',
        '.accessibilityHint(onSelect == nil ? Text("mapList.readOnly") : pinHint(pin.id))',
        ROLE,
        '.accessibilityAddTraits(pin.id == selectedID ? .isSelected : [])',
    ):
        if row.count(required) != 1:
            raise ValueError('Existing selection, lifecycle or accessibility semantics changed')
    for required in (
        'guard isExpanded, renderedInput == currentInput, let request,',
        'let id = gate.consume(request) else { return }',
        'onSelect?(id)',
    ):
        if block.count(required) != 1:
            raise ValueError('Existing selection, lifecycle or accessibility semantics changed')
    if block.count('Text(verbatim: pin.title)') != 2 or block.count('renderedInput == currentInput') != 2:
        raise ValueError('Visible title or stale-input gate changed')
    if 'let request = renderedInput == currentInput\n' not in block:
        raise ValueError('Request is no longer bound to the rendered input')
    for required in ('selectionEnabled: onSelect != nil',):
        if required not in source:
            raise ValueError('Existing selection, lifecycle or accessibility semantics changed')
    if tests.count('    func test') != 3:
        raise ValueError('Original UI68 journeys must remain')
    for required in (
        'app.buttons[id]',
        'XCTAssertFalse(app.buttons["mapList.pin.list-first"].isEnabled)',
        'XCTAssertFalse(app.buttons["mapList.pin.list-second"].isEnabled)',
        'maximumSwipes: 20',
        'timeout: 5',
    ):
        if required not in tests:
            raise ValueError('Original UI68 journeys, assertions and waits must remain exact')
    waits = [float(x) for x in re.findall(r'timeout: ([0-9.]+)', tests)]
    swipes = [int(x) for x in re.findall(r'maximumSwipes: ([0-9]+)', tests)]
    if max(waits) > 5 or max(swipes) > 20:
        raise ValueError('Wait caps cannot be relaxed')


def read_sources(root):
    root = Path(root)
    return ((root / 'App/QuestifyDensityMap.swift').read_bytes().decode('utf-8'),
            (root / 'Tests/AppUITests/SearchMapAlternativeListFlowTests.swift').read_bytes().decode('utf-8'))


class MapReadOnlyEnabledContracts(unittest.TestCase):
    def sources(self):
        return read_sources(ROOT)

    def test_on_disk_crlf_is_not_normalized_before_admission(self):
        paths = ('App/QuestifyDensityMap.swift', 'Tests/AppUITests/SearchMapAlternativeListFlowTests.swift')
        originals = [(ROOT / path).read_bytes() for path in paths]
        for changed_index in range(2):
            with self.subTest(path=paths[changed_index]), tempfile.TemporaryDirectory(prefix='map-byte-admission-') as directory:
                target = Path(directory)
                for index, path in enumerate(paths):
                    file = target / path
                    file.parent.mkdir(parents=True, exist_ok=True)
                    raw = originals[index]
                    file.write_bytes(raw.replace(b'\n', b'\r\n') if index == changed_index else raw)
                with self.assertRaises(ValueError):
                    verify(*read_sources(target))

    def test_only_disabled_modifier_order_changes(self):
        source, tests = self.sources()
        verify(source, tests)
        with self.assertRaises(ValueError):
            verify(original_source(source), tests)

    def test_original_complete_readonly_and_return_journey_is_unchanged(self):
        source, tests = self.sources()
        verify(source, tests)
        self.assertEqual(tests.count('    func test'), 3)
        self.assertIn('XCTAssertFalse(app.buttons["mapList.pin.list-first"].isEnabled)', tests)
        self.assertIn('XCTAssertFalse(app.buttons["mapList.pin.list-second"].isEnabled)', tests)
        self.assertIn('maximumSwipes: 20', tests)

    def test_mutations_to_disabled_role_selection_label_or_gates_fail_closed(self):
        source, tests = self.sources()
        for before, after in (
            (DISABLED, ''), (DISABLED, DISABLED + DISABLED),
            ('.disabled(onSelect == nil)', '.disabled(false)'),
            (ROLE, ''), (ROLE, ROLE.replace('.isButton', '.isStaticText')),
            ('.isSelected : []', '[] : []'),
            ('Text(verbatim: pin.title)', 'Text("Short title")'),
            ('onSelect?(id)', 'onSelect!(id)'),
            ('let id = gate.consume(request)', 'let id = Optional(request.id)'),
            ('renderedInput == currentInput', 'true'),
        ):
            start = source.index(LIST_ROW)
            self.assertIn(before, source[start:])
            with self.subTest(before=before), self.assertRaises(ValueError):
                verify(source[:start] + source[start:].replace(before, after, 1), tests)
        for changed in [source.replace('\n', '\r\n'), original_source(source)]:
            with self.assertRaises(ValueError):
                verify(changed, tests)

    def test_test_locator_assertions_and_wait_caps_cannot_be_relaxed(self):
        source, tests = self.sources()
        for before, after in [('app.buttons[id]', 'app.otherElements[id]'),
                              ('timeout: 5', 'timeout: 20'),
                              ('XCTAssertFalse(app.buttons["mapList.pin.list-first"].isEnabled)', 'XCTAssertTrue(true)')]:
            self.assertIn(before, tests)
            with self.subTest(before=before), self.assertRaises(ValueError):
                verify(source, tests.replace(before, after, 1))


if __name__ == '__main__':
    unittest.main()
