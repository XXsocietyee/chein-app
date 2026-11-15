"""Static wiring regression only, not UIKit/Swift execution."""
from pathlib import Path
import unittest
S = (Path(__file__).resolve().parents[2] / 'App/RoamMedalShareView.swift').read_text()
class MedalRenderIdentityTests(unittest.TestCase):
    def test_render_captures_full_selection_and_preview_requires_it(self):
        self.assertIn('renderedSelection = image == nil ? nil : capturedSelection', S)
        self.assertIn('if let image = machine.image, renderedSelection == selection', S)
    def test_selection_change_retires_image_and_pending_share(self):
        self.assertIn('.onChange(of: selection) { _, _ in invalidate();', S)
        invalidate = S.split('private func invalidate(', 1)[1].split('@ViewBuilder', 1)[0]
        for text in ['photoSave.invalidate()', 'systemShare = nil', 'renderedSelection = nil']:
            self.assertIn(text, invalidate)
    def test_share_sheet_is_bound_to_exported_selection(self):
        self.assertIn('guard sourceIsCurrent, renderedSelection == selection, machine.image === image', S)
        self.assertIn('renderedSelection == selection,\n                   item.isCurrent(reader: reader)', S)
    def test_photo_permission_completion_rechecks_captured_selection(self):
        block = S.split('private func saveControls(', 1)[1].split('private var saveButtonKey', 1)[0]
        self.assertIn('let captured = selection', block)
        self.assertIn('.init(record: captured.record, includeRoute: false)', block)
        self.assertIn('sourceIsCurrent && selection == captured && renderedSelection == captured', block)
if __name__ == '__main__': unittest.main()
