from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


class ChapterArtworkCancelledEntryTests(unittest.TestCase):
    def test_cancelled_task_cannot_steal_new_request_or_clear_new_image(self):
        source = (ROOT / "App/ChapterStoryView.swift").read_text()
        artwork = source.split("@MainActor private struct ChapterStoryArtwork: View {", 1)[1]
        task = artwork.split(".task(id: requestKey) {", 1)[1].split("}.onDisappear", 1)[0]
        self.assertTrue(task.lstrip().startswith("guard !Task.isCancelled else { return }"))
        guard = task.index("guard !Task.isCancelled else { return }")
        for mutation in ("imageRequestID = requestID", "image = nil", "loading = true", "reader.image(url: source)"):
            self.assertLess(guard, task.index(mutation))

    def test_active_request_still_fences_delivery_and_retains_retry(self):
        source = (ROOT / "App/ChapterStoryView.swift").read_text()
        artwork = source.split("@MainActor private struct ChapterStoryArtwork: View {", 1)[1]
        self.assertEqual(artwork.count("try Task.checkCancellation()"), 2)
        self.assertEqual(artwork.count("guard imageRequestID == requestID else { return }"), 2)
        self.assertEqual(artwork.count("guard captured == requestKey else { return }"), 2)
        self.assertIn("attempt += 1", artwork)
        self.assertIn("loadedURL = captured.url; image = decoded", artwork)


if __name__ == "__main__":
    unittest.main()
