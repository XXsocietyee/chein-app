from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


class ChapterArtworkRetryZoomTests(unittest.TestCase):
    def setUp(self):
        self.full = (ROOT / "App/ChapterStoryView.swift").read_text()
        self.code = self.full.split("@MainActor private struct ChapterStoryArtwork: View {", 1)[1]

    def test_retry_reuses_original_reader_and_url(self):
        self.assertIn("attempt += 1", self.code)
        self.assertIn(".task(id: requestKey)", self.code)
        self.assertIn("URL(string: captured.url)", self.code)
        self.assertEqual(self.code.count("reader.image(url: source)"), 1)
        self.assertNotIn("URLSession", self.code)

    def test_request_and_presentation_require_current_permission(self):
        self.assertIn("enabled: reader?.enabled == true, active: scenePhase == .active", self.code)
        self.assertIn("if !requestKey.enabled || !requestKey.active", self.code)
        self.assertIn("guard captured.enabled, captured.active, let reader", self.code)
        self.assertEqual(self.code.count("guard captured == requestKey else { return }"), 2)
        self.assertIn("captured == requestKey && !Task.isCancelled", self.code)

    def test_zoom_uses_sanitized_current_image_without_new_read(self):
        cover = self.full.split(".cyFullScreenCover(item: $zoomedImage)", 1)[1].split(".background(", 1)[0]
        self.assertIn("if visible, scenePhase == .active, imageReader?.enabled == true", cover)
        self.assertIn("ChapterStoryImageViewer(image: item.image, alt: item.alt)", cover)
        self.assertNotIn("reader.image", cover)
        self.assertIn("else if let image, loadedURL == url", self.code)
        self.assertIn("RetainedImageSanitizer.sanitize(bytes)", self.code)

    def test_changed_context_closes_zoom_without_clearing_a_new_completion(self):
        story = self.full.split("@MainActor private struct ChapterStoryGameHost:", 1)[0]
        self.assertIn("zoomedImage = nil", story)
        self.assertIn("loadedURL = captured.url; image = decoded", self.code)


if __name__ == "__main__":
    unittest.main()
