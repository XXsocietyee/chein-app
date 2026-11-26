from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


class ChapterAudioCurrentSelectionTests(unittest.TestCase):
    def setUp(self):
        self.code = (ROOT / "App/ChapterStoryView.swift").read_text().split("@MainActor private struct ChapterStoryGameHost:", 1)[0]

    def test_all_audio_choices_recheck_current_projection(self):
        self.assertEqual(self.code.count("{ selectAudio(url) }"), 3)
        self.assertNotIn("{ audioURL = url }", self.code)
        self.assertIn("guard audioMounted, scenePhase == .active, currentAudioURLs.contains(url) else { return }", self.code)

    def test_player_mount_also_rechecks_current_projection(self):
        # Classic host and the native-r2 story-flow mini player (4a6129aff) both recheck the current projection at mount.
        self.assertIn("if !NativeR2Flags.storyFlow, let audioURL, audioMounted, scenePhase == .active, currentAudioURLs.contains(audioURL)", self.code)
        self.assertIn("if NativeR2Flags.storyFlow, visible, audioMounted, scenePhase == .active, makeAudio != nil, !orderedAudioURLs.isEmpty", self.code)
        self.assertIn("selected: audioURL.flatMap { currentAudioURLs.contains($0) ? $0 : nil }", self.code)
        self.assertIn("guard visible else { return [] }", self.code)
        self.assertIn("currentRead: visible", self.code)

    def test_exit_closes_selection_before_clearing(self):
        self.assertIn("audioMounted = true", self.code)
        self.assertIn(".onDisappear { audioMounted = false; audioURL = nil;", self.code)

    def test_existing_cleanup_and_shared_player_remain(self):
        self.assertIn("PlatformAudioHost(rawURL: audioURL, scope: mediaScope, makeModel: makeAudio)", self.code)
        self.assertIn(".onChange(of: currentAudioURLs)", self.code)
        self.assertIn(".onChange(of: mediaScope)", self.code)
        self.assertIn("if phase != .active { audioURL = nil", self.code)

    def test_rendered_buttons_capture_identity_before_click(self):
        self.assertEqual(self.code.count("let selectAudio = scopedAudioSelection()"), 2)
        helper = self.code.split("private func scopedAudioSelection()", 1)[1].split("private func selectAudio(", 1)[0]
        self.assertLess(helper.index("let expectedIdentity = model.identity"), helper.index("return { url in"))
        self.assertIn("guard let expectedIdentity, expectedIdentity == model.identity else { return }", helper)
        self.assertLess(helper.index("guard let expectedIdentity"), helper.index("selectAudio(url)"))

    def test_identity_is_live_session_and_epoch_not_only_url(self):
        coordinator = (ROOT / "Core/PlayExperienceCoordinator.swift").read_text()
        identity = coordinator.split("public var identity: String?", 1)[1].split("\n    }", 1)[0]
        self.assertIn("currentSession()", identity)
        self.assertIn("epoch", identity)

    def test_old_rendered_action_cannot_cross_presentation_lifetime(self):
        self.assertIn("@State private var audioPresentationID = UUID()", self.code)
        helper = self.code.split("private func scopedAudioSelection()", 1)[1].split("private func selectAudio(", 1)[0]
        self.assertLess(helper.index("let expectedPresentationID = audioPresentationID"), helper.index("return { url in"))
        self.assertLess(helper.index("guard expectedPresentationID == audioPresentationID else { return }"), helper.index("selectAudio(url)"))

    def test_scope_changes_and_exit_invalidate_previous_audio_action(self):
        for key in ("mediaScope", "chapterID", "nodeID", "model.identity"):
            self.assertIn(".onChange(of: " + key + ") { _, _ in audioPresentationID = UUID();", self.code)
        self.assertIn(".onDisappear { audioMounted = false; audioURL = nil; audioPresentationID = UUID(); advancedVariables = [:]; dirtyNodes = []; zoomedImage = nil }", self.code)
        self.assertIn(".onChange(of: scenePhase) { _, phase in audioPresentationID = UUID();", self.code)

    def test_unconfigured_audio_has_no_enabled_play_action(self):
        self.assertEqual(self.code.count(".disabled(makeAudio == nil)"), 2)
        self.assertIn("if makeAudio == nil, !currentAudioURLs.isEmpty {", self.code)
        self.assertIn('Label("platform.audio.gated", systemImage: "speaker.slash")', self.code)
        select = self.code.split("private func selectAudio(_ url: String)", 1)[1]
        self.assertLess(select.index("guard makeAudio != nil else { return }"), select.index("audioURL = url"))

    def test_source_content_and_original_disabled_host_are_preserved(self):
        self.assertIn("case .text(let text): Text(verbatim: text)", self.code)
        host = (ROOT / "App/PlatformConsumerViews.swift").read_text()
        self.assertIn("var makeModel: (@MainActor () -> PlatformAudioPlayback)? = nil", host)
        self.assertIn("model = makeModel?()", host)


if __name__ == "__main__":
    unittest.main()
