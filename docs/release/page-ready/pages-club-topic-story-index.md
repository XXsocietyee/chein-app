# CB254 pages/club/topic-story/index
Base rc/20261108 at 86fa48b0c5833bbadd97c09f246ad05f7af1b8b0. Branch cursor/cb254. The mapped page is already complete, so this note is the only change.
Map status exists. The native surface is App/ClubGovernanceViews.swift (ClubGovernanceStoryView) and App/ClubNodeAnswerContent.swift, backed by Core/ClubStoryPresentation.swift.
The live topicOverview read is api/topic/info-to-user. Node answers use the live ClubGovernanceRead.nodeAnswer read api/club/topic-node-answer. No route was invented and none was marked live.
Answer reveal stays capability-gated on club:content:manage. ClubStoryAnswerRoute is nil without that permission, and the public story projection drops answer, hints, and feedback.
Loading, signed-out, failure, empty chapters, empty stops, empty plays, and source-unavailable are already represented. A missing duration or walk estimate stays nil. validationMethod 0 stays 0. Non-positive authored minutes stay unknown, as ClubStoryPresentationTests already locks.
No user-facing English or zh-Hans key is missing from Resources/Localizable.xcstrings. The unmatched club.story.* and club.gov.* strings in these files are accessibility identifiers, not catalog keys.
showsMerchantChoice stays false. The money switches were not set. Views, string catalogs, the Xcode project, and tools/current_ci_manifest.json were not edited.
Left outside this mapped page: StoryClubTopicRules.buildChapters still stores a missing distance or duration as 0 for the separate join-the-story card. That card is not ClubGovernanceStoryView, and its tests were not changed.
No Swift test was run. swift, swiftc, and xcodebuild were not used. No Xcode Cloud result is claimed.
