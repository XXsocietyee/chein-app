# CB280 pages/userinfo/userinfo

PAGE-READY on rc/20261108 (`e8299803711abd007e33731bdd534c40d6536ea2`). Native screen `App/SocialPublicProfileView.swift`. Map status stays exists. No route was invented and none was marked live. `/api/user/public-info` was already `liveInProduction`.

The read contract is already wired. `SocialAccountService.profile` posts `api/user/public-info` with `member_id` and decodes `SocialPublicProfile`. `ProfilePublicInfoReader.publicProfile` uses that service for one selected member. Phone, email, address, wechat, balance, and token are not fields of the projection. A body that carries them compares equal to a body that omits them. No phone, email, or address was invented. PublicMemberVO has no city, so city stays off this page.

Loading is `SocialReadScreen` before the read settles (`social.loading`). A non-positive member id does not start a read; it is the incomplete-link empty state. A loaded profile with no introduction, no interests, or no posts uses the existing empty copy. An empty portfolio section is omitted. Error stays an error: denial, a wrong id, and a malformed body do not become an empty success, and the screen retries. UNKNOWN is a nil count or a nil follow flag. Nil counts render as an em dash (`—`, U+2014) in `SocialOptionalCount` and on the friends row. A JSON number 0 stays 0, including a published total of 0. A missing nickname uses `square.unknownAuthor`.

Missing EN+zh-Hans keys: none. Referenced keys already have translated en and zh-Hans.

`Resources/Localizable.xcstrings`: `social.profile`, `social.profileSection`, `social.loading`, `social.offline`, `social.notConfigured`, `social.signIn`, `social.failed`, `social.unknown`, `social.emptyText`, `social.changed`, `social.incompleteLink`, `profile.incompleteLink.title`, `profile.incompleteLink.backHome`, `square.unknownAuthor`, `social.followStatus`, `social.following`, `social.notFollowing`, `social.relationshipUnknown`, `social.editor.follow`, `social.editor.unfollow`, `social.editor.startChat`, `social.posts`, `social.achievements`, `social.about`, `social.published`, `social.likes`, `social.followers`, `social.followingCount`, `social.introduction`, `social.noIntroduction`, `social.interests`, `social.noInterests`, `social.portfolio`, `social.noPosts`, `social.postsSignIn`, `profile.selfEdit.open`, `action.retry`.

`Resources/MemberProfile.xcstrings`: `member.card.friends`, `member.card.levelTitle`.

`Resources/PersonalLocationShare.xcstrings`: `personalLocationShare.title.person`.

`profile.selfProjects.schedule.` is a prefix. `upcoming`, `running`, and `ended` already have en and zh-Hans. The self-only sections composed on this screen (orders, projects, posts, medals, growth, weekly points, coupons, tools, identity share, local cover) were checked the same way; their catalog keys already have both languages.

Left: the level prefix `Lv.` is a verbatim literal. `social.level` is a different string and is not drawn. Merchant 招牌主推, 品牌故事, and 营业信息 are not this player page. The shared `SocialValue.integer` parser still accepts a numeric string; a missing count, null, and a non-numeric string stay nil. That parser was not changed. The view, string catalogs, the Xcode project, and `tools/current_ci_manifest.json` were not edited.

Existing coverage stays in `SocialPublicProfileFriendsTests`, `SocialAccountTests` (`testPublicProfileUnknownRelationshipAndMissingCountsStayUnknown`, `testPublicProfileUsesPublicRouteAndNoGuestToken`, `testProfileWrongIDAndInvalidInputCannotBeShown`), and `ProfilePublicInfoRouteTests`. No new test. `swift`, `swiftc`, and `xcodebuild` are not on this machine. No Swift run and no Xcode Cloud result.
