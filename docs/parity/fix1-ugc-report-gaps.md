# UGC surfaces without a native report entry (FP-H3, App Store 1.2)

Status after FIX1: **not fixed**. Checked by `Tests/ContractChecks/test_ugc_surfaces_report_entries.py`.

| Surface | File | What exists | What is missing |
|---|---|---|---|
| Topic detail | `App/TopicDetailView.swift` | `ContentReportReasonRules.topicWritePath` (`api/topic/report`, MATCH in AN-1), reasons from `api/v1/community/capabilities` | No UI entry, no reviewed transport grant for the write |
| Topic reviews and sections | `App/TopicXcxSections.swift` | none | Entry plus grant |
| Activity reviews | `App/ActivityReviewsSection.swift` | none | Entry, route confirmation with the backend |
| Club post discussion comments | `App/ClubPostDiscussion.swift` | club governance report (`api/club/governance/cases/report`) is used elsewhere in the club UI | Entry on comment rows |
| Member avatars | `App/MemberIdentityAvatarView.swift` | none | Entry, route confirmation with the backend |

Why not added in FIX1: each entry needs a write transport approved by the reviewed deployment, composed in
`App/AppSession.swift` (G1-owned, hook only). A UI row that only copied text would pretend to report, so none was added.

Already covered: Square posts and comments, club channel messages, club posts and comments, merchant reviews, IM conversations.

Also still owner-only (FP-O7): the moderation SLA, who staffs it, the published support contact, and the user-agreement
clause. `Settings > Support and safety` carries draft clause copy (`SettingsSupportSafetyCopy.clause`) and links to the
server-provided support contact; it states no SLA.
