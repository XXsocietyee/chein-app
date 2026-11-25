"""Native-only source checks; these do not execute Swift or SwiftUI."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


class TopicCreatorAttributionChecks(unittest.TestCase):
    def test_public_display_has_no_collaborator_as_creator_projection(self):
        contract = (ROOT / 'Core/TopicContracts.swift').read_text()
        detail = contract.split('public struct TopicDetail:', 1)[1].split('public enum TopicAvailability:', 1)[0]
        for unsupported in ['initiatorName', 'initiatorAvatar', 'TopicCollaboratorRecord', 'collaborators.first']:
            self.assertNotIn(unsupported, contract)
        # Publisher display is MP pages/topic/utils/topic-motion.js:33-39: contentPublisherName
        # else clubName, and umsMember.avatar only when contentPublisherType is MEMBER.
        # That is not a collaborator-as-creator projection.
        self.assertNotIn('collaboratorsList', detail)
        self.assertNotIn('collaborators.first', detail)
        self.assertIn('c.text("contentPublisherName") ?? c.text("clubName")', detail)
        self.assertIn('contentPublisherType == "MEMBER"', detail)
        self.assertIn('TopicKey("umsMember")', detail)
        self.assertIn('publisherAuthoritySource = try? PublisherTopicAuthoritySource(from: decoder)', detail)
        self.assertIn('isOwner = c.flag("isOwner")', detail)

    def test_person_label_is_omitted_while_club_and_existing_routes_remain(self):
        view = (ROOT / 'App/TopicDetailView.swift').read_text()
        self.assertNotIn('topic.initiator', view)
        self.assertNotIn('initiatorName', view)
        # The club line moved into the hero (TopicXcxHero) when the detail page was redesigned.
        hero = (ROOT / 'App/TopicXcxSections.swift').read_text()
        self.assertIn('if let club = topic.clubName { Label { Text("topicXcx.clubHost \\(club)") }', hero)
        self.assertNotIn('initiatorName', hero)
        self.assertIn('if let publisherDestination { publisherDestination(value) }', view)
        self.assertIn('if let activities = value.activities', view)

    def test_separate_collaborator_review_projection_and_owner_gate_remain(self):
        evidence = (ROOT / 'Core/PublisherAuthoritySource.swift').read_text()
        self.assertIn('static let collaborator: Self = fields(["memberId", "memberRealName", "memberAvatar", "nickname", "avatar"])', evidence)
        self.assertIn('"collaboratorsList": .array(collaborator)', evidence)
        self.assertIn('let owner = PublisherSourceProjection.flag(body["isOwner"])', evidence)
        self.assertIn('viewerIsOwner = owner', evidence)

    def test_authored_regressions_cover_distinct_person_and_authority_data(self):
        tests = (ROOT / 'Tests/CoreTests/TopicTests.swift').read_text()
        for token in ['testTopicDisplayDoesNotPromoteCollaboratorsOrPublisherToInitiator',
                      'testOmittingInitiatorPreservesSeparateCollaboratorReviewEvidenceAndOwnerProof',
                      '"Public publisher"', '"Content entity"', '"First collaborator"',
                      'XCTAssertEqual(actual, expected', 'XCTAssertFalse(evidence.viewerIsOwner',
                      'XCTAssertNil(try decode(TopicDetail.self, missingOwner).publisherAuthoritySource)']:
            self.assertIn(token, tests)


if __name__ == '__main__':
    unittest.main()
