from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


class ChapterRichTextAccessibilityTests(unittest.TestCase):
    def setUp(self):
        self.code = (ROOT / "App/ChapterStoryView.swift").read_text()

    def section(self, start, end):
        return self.code.split("case ." + start, 1)[1].split("case ." + end, 1)[0]

    def test_all_rich_authored_text_remains_selectable_and_wrapping(self):
        for start, end in [("voice(", "reveal("), ("reveal(", "dream("), ("dream(", "thought("), ("thought(", "game(")]:
            with self.subTest(kind=start):
                body = self.section(start, end)
                self.assertIn(".textSelection(.enabled)", body)
                self.assertIn(".fixedSize(horizontal: false, vertical: true)", body)
                self.assertNotIn(".lineLimit(", body)

    def test_voice_and_thought_keep_authored_name_with_text(self):
        voice = self.section("voice(", "reveal(")
        thought = self.section("thought(", "game(")
        self.assertIn("Text(verbatim: speaker)", voice)
        self.assertIn("Text(verbatim: text)", voice)
        self.assertIn("Text(verbatim: name)", thought)
        self.assertIn("Text(verbatim: description)", thought)
        for body in (voice, thought):
            self.assertIn(".accessibilityElement(children: .combine)", body)

    def test_reveal_remains_disclosure_and_dream_image_remains_interactive(self):
        reveal = self.section("reveal(", "dream(")
        dream = self.section("dream(", "thought(")
        self.assertIn("DisclosureGroup {", reveal)
        self.assertIn("Array(lines.enumerated())", reveal)
        self.assertNotIn(".accessibilityElement(children: .combine)", reveal)
        self.assertIn("ChapterStoryArtwork(url: item.url, alt: item.line, reader: imageReader)", dream)
        self.assertNotIn(".accessibilityElement(children: .combine)", dream)
        self.assertIn(".accessibilityAddTraits(.isHeader)", dream)


if __name__ == "__main__":
    unittest.main()
