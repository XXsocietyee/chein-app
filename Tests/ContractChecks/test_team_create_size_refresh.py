"""Source-wiring checks only; not SwiftUI or server execution."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


class TeamCreateSizeRefreshTests(unittest.TestCase):
    def test_new_eligibility_preserves_valid_choice_and_only_uses_existing_sizes(self):
        source = (ROOT / "App/TeamCreateView.swift").read_text()
        handler = source.split(
            ".onChange(of: model.coordinator.creation?.sizes ?? [], initial: true)", 1,
        )[1].split(".cySheet(item:", 1)[0]
        self.assertIn("guard !sizes.contains(size), let first = sizes.first else { return }", handler)
        self.assertIn("size = first", handler)
        for forbidden in ["prepare(", "confirm(", "submit(", "pending =", "size = 2", "inviteOnly ="]:
            self.assertNotIn(forbidden, handler)

    def test_review_remains_locked_for_unmatched_draft_capacity(self):
        source = (ROOT / "App/TeamCreateView.swift").read_text()
        self.assertIn('.disabled(model.actionLocked || !context.sizes.contains(size))', source)
        self.assertIn('.accessibilityIdentifier("team.create.review")', source)
        self.assertIn("ForEach(context.sizes, id: \\.self)", source)
        self.assertIn("await model.coordinator.loadCreation(ownerID: activityID)", source)


if __name__ == "__main__":
    unittest.main()
