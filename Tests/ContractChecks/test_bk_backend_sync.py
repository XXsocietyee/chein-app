"""BK backend-sync card: source-structure checks only. No Swift compiler, simulator or live service is run."""
import pathlib, re, unittest
ROOT = pathlib.Path(__file__).resolve().parents[2]
DOC = 'docs/handoff/ios-BK-20261019.md'
ITEMS = ['E06-17', 'E01-19', 'E02-23', 'E02-12', 'E02-24', 'E02-25', 'E04-07', 'E01-13']
class BackendSyncSourceTests(unittest.TestCase):
 def swift(self):
  return {p: p.read_text() for d in ('Core', 'App') for p in (ROOT/d).rglob('*.swift')}
 def test_endpoints_recorded_without_ios_consumer_stay_unused(self):
  # E06-17 share snapshot: a future consumer must adopt the handoff first.
  for p, value in self.swift().items():
   if p.name == 'RoamSubpagePresentation.swift':
    self.assertIn('guard (200..<300).contains(status) else { return .error }', value)
    continue
   if p.name == 'ChinaReviewedRouteCapability.swift':
    # Route-capability catalog (not a consumer): the snapshot read must stay recorded as a live, reviewed read.
    self.assertIn('"/api/roam/share/snapshot": .liveInProduction', value)
    continue
   if p.name == 'RoamShareSnapshotPublisher.swift':
    # fix-parity RSESS-2 adopts E06-17: the publish is built only by AppSession.makeRoamShareSnapshotPublisher,
    # which requires the reviewed roam live-write approval for this exact path.
    self.assertIn('public static let path = "api/roam/share/snapshot"', value)
    self.assertIn('RoamShareSnapshotPublisher.path', (ROOT/'App/RoamShareLinkRow.swift').read_text())
    self.assertIn('approval.allows(', (ROOT/'App/RoamShareLinkRow.swift').read_text())
    continue
   if p.name == 'AppCompositionRoot.swift':
    # Reviewed composition gate for the anonymous read: production gates and the China market only.
    self.assertIn('reviewed?.productionGatesEnabled == true && reviewed?.regional.market == .china', value)
    continue
   self.assertNotIn('roam/share/snapshot', value, p)
 def test_topic_like_write_is_only_the_explicit_type0_unlike(self):
  # E01-19 consumers: explicit type only; the legacy blank-type toggle keeps failing on DELETE0.
  users = sorted(str(p.relative_to(ROOT)) for p, v in self.swift().items() if re.search(r'"api/topic/like"', v))
  # App/ReviewedProductionRoutes.swift hosts the reviewed-route body validator that pins the same explicit type "0"
  # (moved out of AppCompositionRoot for the glue-file ratchet). The lease file names the path in the approved like set.
  # The type "0" body stays in TopicUnlike.
  # PlayerContentMPContract only records the MP body. pages/topic/index/index.js:628-629 posts
  # api/topic/like {id, type: next ? 1 : 0}. It is not called from App screens. moneyEnabled follows the host switch.
  self.assertEqual(users, ['App/ReviewedPlayerWriteLeases.swift', 'App/ReviewedProductionRoutes.swift', 'Core/PlayerContentMPContract.swift', 'Core/TopicLikeDirection.swift', 'Core/TopicUnlike.swift'])
  contract = (ROOT/'Core/PlayerContentMPContract.swift').read_text()
  self.assertIn('public static var moneyEnabled: Bool { ReleaseMoneyWriteSwitch.paymentEnabled }', contract)
  self.assertNotIn('URLSession', contract)
  self.assertIn('public static func like(baseURL: URL, id: Int, type: Int) throws -> URLRequest {\n        try form(baseURL, likePath, [("id", String(id)), ("type", String(type))])', contract)
  for p, value in self.swift().items():
   if p.parts[0] != 'App': continue
   self.assertNotIn('PlayerContentMPContract.like(', value, p)
  root = (ROOT/'App/ReviewedProductionRoutes.swift').read_text()
  self.assertIn('case baseURL.appendingPathComponent("api/topic/like").absoluteString:\n            requiredKeys = ["id", "type"]; positiveKey = "id"; requiredTypeField = "0"', root)
  value = (ROOT/'Core/TopicUnlike.swift').read_text()
  self.assertIn('fields: ["id": String(topicID), "type": "0"]', value)
  self.assertIn('if envelope.code == 200 {\n            unresolved.remove(topicID); phase = .removed(topicID: topicID)', value)
  direction = (ROOT/'Core/TopicLikeDirection.swift').read_text()
  self.assertIn('fields: ["id": String(topicID), "type": direction.typeField]', direction)
  self.assertIn("return envelope.code == 200 ? .acknowledged : .rejected(envelope.msg)", direction)
 def test_topic_like_direction_factory_wired_only_through_mp_favorite_host(self):
  # Was test_topic_like_direction_factory_stays_unwired. MP-first rule (owner 2026-11-25, R7-PC-B1-1): the MP topic
  # page sends api/topic/like {id, type 1|0} for 收藏 (pages/topic/index/index.js:619-637), so the pin is lifted;
  # the factory is wired in exactly one host, behind the reviewed TopicUnlike lease.
  for p, value in self.swift().items():
   if p.name in ('TopicLikeDirection.swift', 'TopicFavoriteHost.swift'): continue
   self.assertNotIn('TopicLikeOperationFactory', value, p)
  host = (ROOT/'App/TopicFavoriteHost.swift').read_text()
  self.assertIn('composition.topicUnlikeApproval(context) != nil', host)
  # 104580afa: the host builds the MP body through TopicLikeHostController.miniProgramLikeRequest (id then type)
  # instead of the factory; the lease gate and the single wiring point are unchanged.
  self.assertIn('TopicLikeHostController.miniProgramLikeRequest(\n                    baseURL: api.baseURL, topicID: topicID, direction: direction, token: token)', host)
  for p, value in self.swift().items():
   if p.parts[0] != 'App' or p.name == 'TopicFavoriteHost.swift': continue
   self.assertNotIn('miniProgramLikeRequest', value, p)
 def test_legacy_square_bookmark_never_routes_through_community_id(self):
  contracts = (ROOT/'Core/SocialActionContracts.swift').read_text()
  self.assertIn('case .communityComment, .communityCommentLike, .postAction: return .communityV1', contracts)
  self.assertIn('guard snapshot.post?.generation == requiredGeneration', contracts)
  detail = (ROOT/'App/SquareDetailView.swift').read_text()
  # MP pages/square/detail/index.js:528-544 posts /api/creativesquare/bookmark {id, bookmark, request_id}.
  # index.js:78-82 `_captureCommunityContext` is an account-epoch closure, not a community id, and the body has none.
  # The star stays inside the communityV1 branch (legacy square never takes the community postAction route).
  # The saved-state symbol effect adds lines between the button and its hint; the gate and the post id stay.
  self.assertEqual(detail.count('purpose: .bookmark'), 1)
  # fix-1128b-social gap #1 (audit 1128-plan M-01b, M-13b): the v1 star toggles at once through `bookmarkTapped`
  # (server-confirmed community writer); the reviewed bookmark editor stays the fallback when the writer is off.
  self.assertRegex(detail, r'if post\.generation == \.communityV1 \{\n\s*Button \{ bookmarkTapped\(post, actions: actions\) \}[^\n]*\n(?:[^\n]*\n){1,12}[^\n]*social\.editor\.bookmark')
  self.assertIn('fallback: .init(purpose: .bookmark, target: .post(post.id)', detail)
  self.assertIn('guard contentGeneration == .communityV1, actions.availability(for: command, target: target) == .approved else {', detail)
 def test_legacy_unbookmark_keeps_readback_only_resolution(self):
  value = (ROOT/'Core/ProfileFavoriteRemoval.swift').read_text()
  self.assertIn('"bookmark": "0"', value); self.assertNotIn('"bookmark": "1"', value)
  self.assertIn('phase = dispatched ? .unknown : .failed', value)
  self.assertIn('A pending write can be observed, never automatically submitted a second time.', value)
 def test_handoff_table_lists_every_item(self):
  doc = (ROOT/DOC).read_text()
  for item in ITEMS: self.assertRegex(doc, r'\n\| ' + re.escape(item) + r' \|', item)
  self.assertIn('TEST_DEPLOYED=NO', doc)
  self.assertTrue((ROOT/'Tests/CoreTests/BackendSyncContractTests.swift').exists())
if __name__ == '__main__': unittest.main()
