from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


class ChapterThoughtTaskLifetimeTests(unittest.TestCase):
    def setUp(self):
        self.view = (ROOT / "App/ChapterStoryView.swift").read_text()

    def test_only_lifecycle_task_enters_thought_sync(self):
        self.assertEqual(self.view.count("await model.claimVisibleThoughts(chapterID: chapterID)"), 1)
        self.assertIn(".task(id: thoughtReadTaskKey)", self.view)
        self.assertIn("guard !Task.isCancelled, scenePhase == .active, visible else { return }", self.view)
        self.assertIn(".onChange(of: model.snapshot) { _, _ in thoughtReadRevision = UUID() }", self.view)
        self.assertNotIn("Task { await model.claimVisibleThoughts", self.view)

    def test_task_restarts_for_current_identity_node_chapter_and_read(self):
        key = self.view.split("private struct ThoughtReadTaskKey:", 1)[1].split("var body:", 1)[0]
        for field in ("identity", "chapterID", "nodeID", "revision", "active"):
            self.assertIn("let " + field + ":", key)
        self.assertIn("identity: model.identity", key)
        self.assertIn("revision: thoughtReadRevision, active: scenePhase == .active", key)

    def test_unknown_and_pending_are_still_owned_by_existing_writer(self):
        core = (ROOT / "Core/PlayExperienceCoordinator.swift").read_text()
        claim = core.split("public func claimVisibleThoughts(chapterID: Int)", 1)[1].split("public func acceptAdvanced", 1)[0]
        self.assertIn("pendingThoughtKeys = Set(claims)", claim)
        self.assertIn("unresolved = unresolved || !pendingThoughtKeys.isEmpty", claim)
        self.assertIn("thoughtSyncPhase = pendingThoughtKeys.isEmpty ? .synced : .needsReadback", claim)
        self.assertIn("await load()", claim)
        self.assertNotIn("pendingThoughtKeys", self.view)


if __name__ == "__main__":
    unittest.main()
