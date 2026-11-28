"""mp-mine-b: 邀请好友 page shows the MP scene-share-invite copy and 分享链接 (wxml:23-28) under the personal code."""
import json, unittest
from pathlib import Path
W=Path(__file__).resolve().parents[2]
R=(W/'App/PlayerGapViews.swift').read_text()
S=json.loads((W/'Resources/Localizable.xcstrings').read_text())['strings']
class ShareInviteCopyTests(unittest.TestCase):
 def test_copy_after_code(self):self.assertIn('codeState\n                inviteCopy',R)
 def test_share_only_when_ready(self):self.assertIn('if let qr {\n            ShareLink(item: qr',R)
 def test_mp_zh_copy(self):
  zh=lambda k:S[k]['localizations']['zh-Hans']['stringUnit']['value']
  self.assertEqual(zh('playerGap.invite.title'),'邀请好友一起探索城市')
  self.assertEqual(zh('playerGap.invite.description'),'分享城瘾给你的好友，一起发现城市里的新玩法。')
  self.assertEqual(zh('playerGap.invite.share'),'分享链接')
if __name__=='__main__':unittest.main()
