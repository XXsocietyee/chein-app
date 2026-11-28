"""mp-mine-b: Settings → AI 对话记录 clear toast names the server-confirmed count, as MP ai-chat-records onConfirmClear."""
import unittest
from pathlib import Path
W=Path(__file__).resolve().parents[2]
R=(W/'App/NPCChatDataReadSettingsEntry.swift').read_text()
class AIChatClearCountTests(unittest.TestCase):
 def test_count_passed(self):self.assertIn('case .deleted(let count):',R)
 def test_mp_copy(self):
  self.assertIn('"已清除 \\(count) 条对话"',R)
  self.assertIn('"没有需要清除的对话"',R)
 def test_old_countless_copy_gone(self):self.assertNotIn('"已清除对话记录"',R)
 def test_row_shows_a_chevron_and_stays_a_sheet_button(self):
  self.assertIn('Image(systemName: "chevron.right")', R)
  self.assertIn('accessibilityIdentifier("npcData.open")', R)
  self.assertNotIn('NavigationLink', R)
if __name__=='__main__':unittest.main()
