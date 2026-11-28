"""mp-publish: 编辑角色 用自己的声音录 (MP `publish/fabu/cast-sheet.wxml:107-110`, `theme-cast.js` `toggleCastRecord`).

One mono take ≤ 60 s (REC_MAX_MS) → under 0.5 s is 录音太短 → the editor's approved `api/common/uploadOSS`
(story-audio upload) → `cast[].voice = {mode: 'record', url}`; a preset or 不配音 clears the recording;
完成 waits for a running upload; the 角色 row shows 自己录的.
"""
import json
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
PUB = ROOT / "App/MPGap/AccountPublish"


class CastVoiceRecordTests(unittest.TestCase):
    def test_recorder_follows_mp_limits(self):
        text = (PUB / "ProjectEditCastVoiceRecorder.swift").read_text(encoding="utf-8")
        self.assertIn("static let maxSeconds: TimeInterval = 60", text)
        self.assertIn("static let minSeconds: TimeInterval = 0.5", text)
        self.assertIn("AVNumberOfChannelsKey: 1", text)
        self.assertIn("ProjectStoryAudioCapture.read(", text)
        self.assertIn("source.upload(audio, attemptID: UUID(), session: session).reference", text)
        self.assertIn("source.permitsPicker(session: session)", text)

    def test_wire_shape_is_mp_record_voice(self):
        text = (PUB / "AccountPublishR8Mounts.swift").read_text(encoding="utf-8")
        self.assertIn('row["voice"] = .object(["mode": .string("record"), "url": .string(recording)])', text)
        self.assertIn('voiceRecordingURL: recordedVoice(voice)', text)

    def test_done_waits_for_voice_upload(self):
        text = (PUB / "ProjectEditCastMemberEditor.swift").read_text(encoding="utf-8")
        save = text[text.index("private func save()"):]
        self.assertIn("if uploadingAvatar || uploadingVoice {", save)
        self.assertLess(save.index("issue = .avatarUploading"), save.index("issue = .nameMissing"))

    def test_editor_is_wired_from_the_fabu_page(self):
        view = (ROOT / "App/ProjectEditView.swift").read_text(encoding="utf-8")
        self.assertIn("voiceUpload: ProjectEditCastVoiceUpload.make(model)", view)

    def test_copy_is_bilingual(self):
        strings = json.loads((ROOT / "Resources/Localizable.xcstrings").read_text(encoding="utf-8"))["strings"]
        for key in ("record", "recording", "stopLabel", "recorded", "own", "uploading", "notStarted", "tooShort", "failed"):
            loc = strings["castMember.voice." + key]["localizations"]
            self.assertTrue(loc["en"]["stringUnit"]["value"])
            self.assertTrue(loc["zh-Hans"]["stringUnit"]["value"])


if __name__ == "__main__":
    unittest.main()
