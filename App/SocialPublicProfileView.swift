import SwiftUI

@MainActor struct SocialPublicProfileView: View {
    let memberID: Int
    let reader: any SocialAccountReading
    let squareReader: any SquareReading
    var actions: SocialActionCoordinator? = nil
    var selfOrdersAccess: ProfileSelfOrdersAccess? = nil
    var selfProjectsAccess: ProfileSelfProjectsAccess? = nil
    var selfGrowthAccess: ProfileSelfGrowthAccess? = nil
    /// Attributes v2 (six attributes, archetype, titles) for the viewer's own profile; points-only CITY lease.
    var memberAttributesService: (any CityMonopolyReading)? = nil
    var weeklyPointsAccess: ProfileWeeklyPointsAccess? = nil
    var personalToolsAccess: ProfilePersonalToolsAccess? = nil
    var selfCouponAccess: ProfileSelfCouponAccess? = nil
    var selfObjectCardsAccess: ProfileObjectCardsAccess? = nil
    var selfMedalsReader: (any ProfileReading)? = nil
    var selfEditAccess: ProfileSelfEditAccess? = nil
    var selfEditDiagnostics: (@MainActor (ProfileSelfEditTicket?, ProfileSelfEditTicket, ProfileSelfEditContext?) -> String)? = nil
    var localCoverOwner: ProfileLocalCoverOwner? = nil
    var showsStartChat = true
    var isCurrent: @MainActor () -> Bool = { true }
    /// MP `userinfo?tab=` (A2-06): `projects` is the MP key for 我的; unknown keys keep the default 帖文.
    var initialTab: String? = nil
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var typeSize
    private enum Tab: String, CaseIterable { case mine, posts, achievements, about }
    @State private var authorPosts = ProfileAuthorPostsRefreshController()
    @State private var pullRefreshToken = 0
    @State private var authorPostTicket: ProfileAuthorPostTicket?
    @State private var tab = Tab.posts
    @State private var appliedInitialTab = false
    @State private var workImagePreview: SocialProfileImagePreview?
    /// A2-03 (发消息): the IM conversation opened in place; needs a host-provided destination.
    @State private var openedConversationID: Int?
    @Environment(\.socialConversationDestination) private var conversationDestination
    @State private var selfEditNavigation = ProfileSelfEditNavigation()
    @StateObject private var identityShareOwner = ProfileIdentitySharePageOwner()
    private var showsMineTab: Bool {
        if let selfOrdersAccess, selfOrdersAccess.context(memberID: memberID, social: reader, isCurrent: isCurrent()) != nil { return true }
        if let selfProjectsAccess, selfProjectsAccess.context(memberID: memberID, accountReader: reader, isCurrent: isCurrent()) != nil { return true }
        return false
    }
    private var profileTabs: [CYTabItem<Tab>] {
        var items: [CYTabItem<Tab>] = []
        if showsMineTab { items.append(.init(id: .mine, title: appLocalized("social.mine", locale: locale))) }
        items.append(.init(id: .posts, title: appLocalized("social.posts", locale: locale)))
        items.append(.init(id: .achievements, title: appLocalized("account.mine.tab.achievements", locale: locale)))
        items.append(.init(id: .about, title: appLocalized("social.about", locale: locale)))
        return items
    }
    private var selfEditContext: ProfileSelfEditContext? {
        selfEditAccess?.context(memberID: memberID, reader: reader, isCurrent: isCurrent())
    }
    private var selfEditBinding: Binding<ProfileSelfEditTicket?> {
        let captured = selfEditNavigation.ticket
        return Binding(get: { selfEditNavigation.ticket }, set: { next in
            if next == nil, let captured { selfEditNavigation.finish(captured.id, context: selfEditContext) }
        })
    }
    private func selfEditDiagnostic(for ticket: ProfileSelfEditTicket) -> (@MainActor () -> String)? {
        guard let selfEditDiagnostics else { return nil }
        return { selfEditDiagnostics(selfEditNavigation.ticket, ticket, selfEditContext) }
    }
    private var profileReadRequestKey: String {
        "profile-\(memberID)-\(selfEditNavigation.refreshID)-\(reader.presentationRevision)"
    }
    var body: some View {
        ProfileIdentitySharePageHost(owner: identityShareOwner,
            context: .init(memberID: memberID, reader: reader, isCurrent: isCurrent())) {
        List {
            if !reader.isConfigured, let weeklyPointsAccess {
                // Own weekly points are a separate read. An unavailable public profile
                // must not hide them or wait for that parent request.
                ProfileWeeklyPointsEntry(memberID: memberID, accountReader: reader,
                    access: weeklyPointsAccess, isCurrent: isCurrent)
            }
            if memberID <= 0 {
                // Mini-program userinfo missing-param state: centred empty state with a back-to-home CTA.
                ContentUnavailableView {
                    Label { Text("profile.incompleteLink.title").accessibilityIdentifier("social.incompleteLink.title") } icon: { Image(systemName: "link.badge.plus") }
                } description: {
                    Text("social.incompleteLink")
                } actions: {
                    Button { dismiss() } label: { Text("profile.incompleteLink.backHome") }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("social.incompleteLink.backHome")
                }
                .accessibilityIdentifier("social.incompleteLink")
            }
            else {
                SocialReadScreen(reader: reader, requestKey: profileReadRequestKey, failureTitle: "profile.public.loadFailed", load: {
                    // A scoped parent may retire before SwiftUI unmounts this screen.
                    // Do not start a replacement-account read for that old route.
                    guard isCurrent() else { throw CancellationError() }
                    let shareContext = ProfileIdentitySharePageContext(memberID: memberID, reader: reader, isCurrent: isCurrent())
                    let shareRead = identityShareOwner.beginSourceRead(shareContext)
                    let headerKey = SocialReadPresentationKey(reader: reader,
                        request: profileReadRequestKey, requiresSignIn: false)
                    let feedContext = authorPostsContext
                    let loaded: SocialPublicProfile
                    do { loaded = try await reader.publicProfile(memberID: memberID) }
                    catch {
                        let currentKey = SocialReadPresentationKey(reader: reader,
                            request: profileReadRequestKey, requiresSignIn: false)
                        if !Task.isCancelled, isCurrent(), headerKey == currentKey,
                           feedContext == authorPostsContext,
                           authorPosts.rejectHeader(error, context: feedContext) {
                            if authorPostTicket?.context == feedContext { authorPostTicket = nil }
                        }
                        throw error
                    }
                    guard isCurrent() else { throw CancellationError() }
                    guard !Task.isCancelled else { throw CancellationError() }
                    identityShareOwner.acceptSource(loaded, reader: reader, expected: shareContext,
                                                    readID: shareRead, isCurrent: isCurrent())
                    return loaded
                }) { profile in
                    Section {
                        // MP cy-profile `.pc-hero-bg`: default cover `/subpackageMember/images/mer1.jpg` (index.js:399) over the head. Decorative.
                        MPAsset.BannerCover.subpackageMemberImagesMer1
                            .resizable()
                            .scaledToFill()
                            .accessibilityHidden(true)
                            .frame(height: 120)
                            .frame(maxWidth: .infinity)
                            .clipped()
                            .listRowInsets(EdgeInsets())
                        // Mini-program cy-profile identity head: round avatar beside name and level.
                        // a11y-dt r3: at accessibility sizes the name goes under the avatar (Contacts card) instead of
                        // squeezing a .title2 name into the width left beside a 64 pt avatar.
                        let headLayout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: CYSpacing.sm))
                                                                      : AnyLayout(HStackLayout(spacing: CYSpacing.lg))
                        headLayout {
                            ProfilePublicAvatar(source: profile.avatar, name: profile.nickname)
                            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                                if let name = profile.nickname { Text(verbatim: name).font(.title2.bold()).accessibilityAddTraits(.isHeader).fixedSize(horizontal: false, vertical: true) }
                                else { Text("square.unknownAuthor").font(.title2.bold()).accessibilityAddTraits(.isHeader).fixedSize(horizontal: false, vertical: true) }
                                // MP cy/profile wxml:69 `wx:if="{{growthLevel > 0}}"`: no level line (never "— 城市探索者") until it is known.
                                if let level = profile.level, level > 0 {
                                    HStack(spacing: 6) {
                                        Text(verbatim: "Lv.\(level)")
                                        Text("member.card.levelTitle", tableName: "MemberProfile")
                                    }.cyText(.bodyCompact, monospacedDigit: true).foregroundStyle(.secondary).accessibilityElement(children: .combine)
                                }
                            }
                        }
                        if profile.id == memberID, reader.identity.accountID == memberID {
                            ProfileIdentityShareSection(profile: profile, reader: reader, isCurrent: isCurrent, owner: identityShareOwner)
                                .id(ProfileIdentityShareViewIdentity(profile: profile, reader: reader))
                        }
                        if actions == nil || actions?.identity.accountID == profile.id,
                           reader.identity.accountID != profile.id, let followed = profile.isFollowed {
                            // Read-only viewers keep the relationship line; for other members it lives on the 关注 button (A2-03).
                            // The MP has no relationship line on one's own page, and an unknown relation is not shown as
                            // "? —" data (18:15 sweep): the row appears only for another member with a known answer.
                            LabeledContent("social.followStatus") {
                                if followed { Label("social.following", systemImage: "checkmark").foregroundStyle(.secondary) }
                                else { Text("social.notFollowing").foregroundStyle(.secondary) }
                            }
                        }
                        if let actions, actions.identity.accountID != profile.id {
                            // Mini-program other-player head: 关注 and 发消息 side by side as two pills.
                            // a11y-dt r3: stacked full width at accessibility sizes (same order), never truncated.
                            let pillLayout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: CYSpacing.sm))
                                                                          : AnyLayout(HStackLayout(spacing: CYSpacing.sm))
                            pillLayout {
                                // A2-03: MP 关注 toggles in place (处理中… → ✓ 已关注), no editor page.
                                SocialProfileInlineFollowButton(memberID: profile.id, serverFollowed: profile.isFollowed, coordinator: actions) { title, image in
                                    profilePill(title, systemImage: image)
                                }
                                if showsStartChat {
                                    if conversationDestination != nil {
                                        // A2-03: MP 发消息 opens the chat directly. The send is `ProfileIMStartContract`.
                                        SocialProfileInlineStartChatButton(memberID: profile.id, coordinator: actions,
                                                                           onOpen: { openedConversationID = $0 }) { title, image in
                                            profilePill(title, systemImage: image)
                                        }
                                    } else {
                                        // Hosts without an IM destination keep the reviewed editor (purpose: .startChat).
                                        NavigationLink { SocialActionEditorView(purpose: .startChat, target: .member(profile.id), coordinator: actions) } label: {
                                            profilePill(Text("social.editor.startChat"), systemImage: "message")
                                        }
                                    }
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                        }
                        if reader.identity.accountID != profile.id, profile.id > 0 {
                            UGCProfileSafetyActionsSection(memberID: profile.id, displayName: profile.nickname)
                        }
                        if profile.id == memberID, let accountID = reader.identity.accountID,
                           accountID != memberID, memberID > 0, isCurrent() {
                            NavigationLink { PersonalLocationShareEntry(recipientId: Int64(memberID)) } label: {
                                Label { Text("personalLocationShare.title.person", tableName: "PersonalLocationShare") } icon: { Image(systemName: "location") }
                            }.accessibilityIdentifier("social.personalLocationShare")
                        }
                    }
                    // Mini-program cy-profile counters: 好友 / 关注 / 粉丝, em dash when the server omitted one.
                    // MP `pc-stats` hides on one's own page at 0/0/0 (1121 N5); with all three unknown the row is not
                    // shown as "— — —" data either (18:15 sweep).
                    if showsCounters(profile) {
                    Section {
                        HStack(spacing: 0) {
                            profileCounter(profile.friends, id: "friends") { Text("member.card.friends", tableName: "MemberProfile") }
                            profileCounter(profile.following, id: "following") { Text("member.card.following", tableName: "MemberProfile") }
                            profileCounter(profile.followers, id: "followers") { Text("member.card.fans", tableName: "MemberProfile") }
                        }
                    }
                    }
                    // Mini-program cy/profile tab order: 我的 (orders, projects), 帖文, 成就, 关于.
                    // A2-04 / X5 asked for MP underline tabs (2026-07-31); the owner native-iOS ruling (2026-11-24) supersedes it.
                    // Still not a menu Picker row.
                    Section {
                        // Native restyle R2 (spec §3.7): 3-4 nouns switch views, so a system segmented picker.
                        Picker(selection: $tab) {
                            ForEach(profileTabs) { item in Text(verbatim: item.title).tag(item.id) }
                        } label: { Text("social.profileSection") }
                            .cyAdaptiveSegmented()
                            .accessibilityElement(children: .contain)
                            .accessibilityLabel(Text("social.profileSection"))
                            .accessibilityIdentifier("social.profile.tabs")
                            .sensoryFeedback(.selection, trigger: tab)
                    }
                    switch tab {
                    case .mine:
                        // Mini-program 我的 tab: 我的订单, then 我的项目.
                        if let selfOrdersAccess {
                            ProfileSelfOrdersEntry(memberID: memberID, social: reader, access: selfOrdersAccess, isCurrent: isCurrent)
                        }
                        if let selfProjectsAccess {
                            ProfileSelfProjectsEntry(memberID: memberID, accountReader: reader, access: selfProjectsAccess, isCurrent: isCurrent,
                                refreshTrigger: pullRefreshToken)
                        }
                    case .posts:
                        // r8 A1-01: own profile only.
                        if let actions, actions.identity.accountID == memberID {
                            OwnProfileComposerHost(actions: actions, offline: reader.isOfflineExample)
                        }
                        UGCBlockedFilterContainer(memberID: profile.id, authorName: profile.nickname) {
                            ProfileAuthorPostsSection(memberID: memberID, accountReader: reader, squareReader: squareReader,
                                actions: actions, isCurrent: isCurrent, retainedModel: authorPosts, onOpenPost: openAuthorPost)
                        } blockedPlaceholder: {
                            UGCBlockedNoticeBanner(
                                messageKey: "ugc.safety.blockedBanner.profile",
                                memberID: profile.id,
                                authorName: profile.nickname
                            )
                        }
                        // r8 A2-08 (MP cy/profile loadMyClubPosts): own club posts follow the community posts.
                        if let actions, actions.identity.accountID == memberID { OwnProfileClubPostsSection() }
                    case .achievements:
                        // Points come first under 成就, as in the mini-program.
                        if let weeklyPointsAccess {
                            ProfileWeeklyPointsEntry(memberID: memberID, accountReader: reader,
                                access: weeklyPointsAccess, isCurrent: isCurrent)
                        }
                        if let selfObjectCardsAccess {
                            ProfileObjectCardsEntry(memberID: memberID, accountReader: reader,
                                access: selfObjectCardsAccess, isCurrent: isCurrent)
                        }
                        if let selfMedalsReader {
                            ProfileSelfMedalsSection(memberID: memberID, accountReader: reader,
                                profileReader: selfMedalsReader, isCurrent: isCurrent)
                        }
                        if let selfGrowthAccess {
                            ProfileSelfGrowthEntry(memberID: memberID, accountReader: reader,
                                access: selfGrowthAccess, isCurrent: isCurrent)
                        }
                        if let memberAttributesService, isCurrent() {
                            MemberAttributesSection(service: memberAttributesService)
                        }
                        Section("social.achievements") {
                            SocialOptionalCount(title: "social.published", count: profile.published)
                            SocialOptionalCount(title: "social.likes", count: profile.likes)
                            LabeledContent { Text(verbatim: profile.friends.map(String.init) ?? "—") } label: {
                                Text("member.card.friends", tableName: "MemberProfile")
                            }.accessibilityIdentifier("social.profile.friends")
                            SocialOptionalCount(title: "social.followers", count: profile.followers)
                            SocialOptionalCount(title: "social.followingCount", count: profile.following)
                        }
                    case .about:
                        if let personalToolsAccess {
                            ProfilePersonalToolsEntry(memberID: memberID, social: reader,
                                access: personalToolsAccess, isCurrent: isCurrent)
                        }
                        if let selfCouponAccess {
                            ProfileSelfCouponEntry(memberID: memberID, accountReader: reader,
                                access: selfCouponAccess, isCurrent: isCurrent)
                        }
                        Section("social.introduction") {
                            if let introduction = profile.introduction { Text(verbatim: introduction).textSelection(.enabled).fixedSize(horizontal: false, vertical: true) }
                            else { Text("social.noIntroduction").foregroundStyle(.secondary) }
                            if selfEditContext != nil {
                                Button("profile.selfEdit.open") { selfEditNavigation.open(selfEditContext) }
                                    .accessibilityIdentifier("profile.selfEdit.open")
                            }
                        }
                        Section("social.interests") {
                            if profile.interests.isEmpty { Text("social.noInterests").foregroundStyle(.secondary) }
                            ForEach(profile.interests) { item in Label { Text(verbatim: item.name) } icon: { Image(systemName: "tag") } }
                        }
                        // A1-05: MP 关于 › 加入时间; hidden when the server sent none.
                        if let joinDate = profile.joinDate {
                            Section {
                                LabeledContent("profile.about.joinDate") { Text(verbatim: LocaleDisplay.civil(joinDate, locale: locale)).monospacedDigit() }
                                    .accessibilityIdentifier("profile.about.joinDate")
                            }
                        }
                        if !profile.workImages.isEmpty {
                            Section("social.portfolio") {
                                // A2-07: MP 探索作品 tap previews full screen (cyp wxml:516-520).
                                ForEach(Array(profile.workImages.enumerated()), id: \.offset) { index, source in
                                    Button { workImagePreview = SocialProfileImagePreview(index: index, sources: profile.workImages) } label: {
                                        SquareImage(source: source)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(Text("social.portfolio.preview"))
                                    .accessibilityAddTraits(.isButton)
                                    .accessibilityIdentifier("social.portfolio.image.\(index)")
                                }
                            }
                        }
                        if localCoverOwner?.accountID == memberID {
                            ProfileLocalCoverSection(owner: localCoverOwner, reader: reader, isCurrent: isCurrent)
                        }
                    }
                }
            }
        }
        }
            .cyPageTitle("social.profile")
            // 11-28 05:35 sweep: posts refresh by pull-down, as in the MP (no refresh row).
            .cyRefreshable { await refreshPage() }
            .cyHideTabBar()
            .navigationDestination(item: selfEditBinding) { ticket in
                ProfileSelfEditDestination(ticket: ticket, access: selfEditAccess,
                    isCurrent: { selfEditNavigation.isCurrent(ticket, context: selfEditContext) },
                    diagnosticText: selfEditDiagnostic(for: ticket))
            }
            .navigationDestination(isPresented: authorPostBinding) {
                if let ticket = authorPostTicket, ticket.context == authorPostsContext,
                   isCurrent(), ticket.context.isConfigured, ticket.context.isSignedIn {
                    SquareDetailView(id: ticket.postID, contentGeneration: ticket.contentGeneration,
                        reader: squareReader, accountReader: reader, actions: actions).id(ticket.id)
                } else { Text("social.changed") }
            }
            .onChange(of: authorPostsContext) { _, context in
                if authorPosts.context != context { authorPosts.retire() }
                if let ticket = authorPostTicket, ticket.context != context { authorPostTicket = nil }
            }
            .accessibilityIdentifier("social.profile")
            .cyFullScreenCover(item: $workImagePreview) { preview in SocialProfileImagePreviewPager(preview: preview) }
            .navigationDestination(item: $openedConversationID) { id in
                if let conversationDestination { conversationDestination(id) }
            }
            .toolbar {
                if reader.identity.accountID != memberID, memberID > 0 {
                    ToolbarItem(placement: .topBarTrailing) {
                        UGCSafetyMenuButton(
                            presentation: UGCReportPresentationTarget(
                                target: .member(memberID: memberID),
                                authorMemberID: memberID
                            )
                        )
                        .accessibilityIdentifier("social.profile.safetyMenu")
                    }
                }
            }
            .onAppear {
                guard !appliedInitialTab else { return }
                appliedInitialTab = true
                switch initialTab {
                case "projects": if selfOrdersAccess != nil || selfProjectsAccess != nil { tab = .mine }
                case "achievements": tab = .achievements
                case "about": tab = .about
                default: break
                }
            }
            .onChange(of: selfOrdersAccess?.context(memberID: memberID, social: reader, isCurrent: isCurrent())) { _, context in
                if context == nil && tab == .mine && selfProjectsAccess?.context(memberID: memberID, accountReader: reader, isCurrent: isCurrent()) == nil { tab = .posts }
            }
    }
    /// Pull to refresh (MP pull-down): 帖文 reloads the retained author feed; 我的项目 reloads on the bumped token.
    private func refreshPage() async {
        pullRefreshToken &+= 1
        guard tab == .posts, !authorPosts.isBusy else { return }
        await authorPosts.refresh(memberID: memberID, accountReader: reader, squareReader: squareReader, isCurrent: isCurrent)
    }
    /// Label for the side-by-side bordered 关注 / 发消息 buttons.
    @ViewBuilder private func profilePill(_ title: Text, systemImage: String?) -> some View {
        Group {
            if let systemImage { Label { title } icon: { Image(systemName: systemImage) } }
            else { title }
        }
        .frame(maxWidth: .infinity)
    }
    /// Hidden while all three counters are unknown, and on one's own page while all three are a known 0 (MP 1121 N5).
    private func showsCounters(_ profile: SocialPublicProfile) -> Bool {
        let values = [profile.friends, profile.following, profile.followers]
        if values.allSatisfy({ $0 == nil }) { return false }
        let isSelf = reader.identity.accountID == profile.id
        return !(isSelf && values.allSatisfy({ $0 == 0 }))
    }

    private func profileCounter(_ value: Int?, id: String, label: () -> Text) -> some View {
        VStack(spacing: 2) {
            // A2-09: MP pc-stat-n is 18 bold (pages/userinfo/userinfo.wxss). r11 N-30: system `.headline`, not a CY text style.
            Text(verbatim: value.map(String.init) ?? "—").font(.headline).monospacedDigit()
            label().cyText(.meta).foregroundStyle(.secondary).cyWrapText(alignment: .center)
        }
        .frame(maxWidth: .infinity, minHeight: 56)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("social.profile.counter.\(id)")
    }
    private var authorPostsContext: ProfileAuthorPostsContext {
        .init(memberID: memberID, accountReader: reader, squareReader: squareReader)
    }
    private func openAuthorPost(_ post: SquarePost) {
        let context = authorPostsContext
        guard authorPostTicket == nil, authorPosts.canOpen(post, context: context, isCurrent: isCurrent()) else { return }
        authorPostTicket = .init(postID: post.id, contentGeneration: post.generation, context: context)
        authorPosts.suspend()
    }
    private var authorPostBinding: Binding<Bool> {
        let id = authorPostTicket?.id
        return Binding(get: { authorPostTicket != nil }, set: { shown in
            guard !shown, let id, authorPostTicket?.id == id else { return }
            authorPostTicket = nil
        })
    }

}


struct ProfileAuthorPostTicket: Identifiable {
    let id = UUID()
    let postID: Int
    let contentGeneration: SquareContentGeneration
    let context: ProfileAuthorPostsContext
}

/// Optional self-profile metadata entry. Captured scopes never authorize coupon codes.
@MainActor struct ProfileSelfCouponAccess {
    let reader: ProfileOwnedCouponReader
    let owner: SocialAccountIdentity
    let scope: UUID
    init(reader: ProfileOwnedCouponReader, owner: SocialAccountIdentity) {
        self.reader = reader; self.owner = owner; scope = reader.scope
    }
}

struct ProfileSelfCouponContext: Hashable {
    let memberID: Int
    let viewer: SocialAccountIdentity
    let viewerRevision: UInt64
    let accountReaderID: ObjectIdentifier
    let couponReaderID: ObjectIdentifier
    let couponScope: UUID
    @MainActor static func capture(memberID: Int, accountReader: any SocialAccountReading,
        access: ProfileSelfCouponAccess, isCurrent: Bool) -> Self? {
        guard isCurrent, memberID > 0, access.owner.accountID == memberID,
              accountReader.identity == access.owner, accountReader.isConfigured,
              ["player", "club"].contains(access.owner.role ?? ""),
              access.reader.isAuthenticated, access.reader.isConfigured,
              access.reader.scope == access.scope else { return nil }
        return .init(memberID: memberID, viewer: access.owner,
            viewerRevision: accountReader.presentationRevision,
            accountReaderID: ObjectIdentifier(accountReader),
            couponReaderID: ObjectIdentifier(access.reader), couponScope: access.scope)
    }
}

@MainActor final class ProfileSelfCouponScopedReader: AccountCollectionReading {
    // Keep the underlying scope so the existing operation lifetime remains valid.
    let scope: UUID
    private let expected: ProfileSelfCouponContext
    private let accountReader: any SocialAccountReading
    private let access: ProfileSelfCouponAccess
    private let current: @MainActor () -> Bool
    init(context: ProfileSelfCouponContext, accountReader: any SocialAccountReading,
         access: ProfileSelfCouponAccess, isCurrent: @escaping @MainActor () -> Bool) {
        expected = context; scope = context.couponScope
        self.accountReader = accountReader; self.access = access; current = isCurrent
    }
    var associationIsCurrent: Bool {
        ProfileSelfCouponContext.capture(memberID: expected.memberID, accountReader: accountReader,
            access: access, isCurrent: current()) == expected
    }
    var isAuthenticated: Bool { associationIsCurrent && access.reader.isAuthenticated }
    var isConfigured: Bool { associationIsCurrent && access.reader.isConfigured }
    var isOfflineExample: Bool { false }
    func favoriteTopics(pageNumber: Int, pageSize: Int) async throws -> TopicPage { throw APIError.notConfigured }
    func favoritePosts(pageNumber: Int, pageSize: Int) async throws -> AccountCollectionPostPage { throw APIError.notConfigured }
    func ownedCoupons(keyword: String?) async throws -> [AccountCollectionCoupon] {
        try await read { try await self.access.reader.ownedCoupons(keyword: keyword, associationIsCurrent: { self.associationIsCurrent }) }
    }
    func ownedCoupon(id: Int) async throws -> AccountCollectionCoupon {
        try await read { try await self.access.reader.ownedCoupon(id: id, associationIsCurrent: { self.associationIsCurrent }) }
    }
    func ownedCoupons(keyword: String?, lifetime: OwnedCouponReadLifetime) async throws -> [AccountCollectionCoupon] {
        try await read { try await self.access.reader.ownedCoupons(keyword: keyword, lifetime: lifetime, associationIsCurrent: { self.associationIsCurrent }) }
    }
    func ownedCoupon(id: Int, lifetime: OwnedCouponReadLifetime) async throws -> AccountCollectionCoupon {
        try await read { try await self.access.reader.ownedCoupon(id: id, lifetime: lifetime, associationIsCurrent: { self.associationIsCurrent }) }
    }
    private func read<T>(_ operation: () async throws -> T) async throws -> T {
        try Task.checkCancellation()
        guard associationIsCurrent else { throw CancellationError() }
        do {
            let value = try await operation()
            try Task.checkCancellation()
            guard associationIsCurrent else { throw CancellationError() }
            return value
        } catch {
            guard !Task.isCancelled, associationIsCurrent else { throw CancellationError() }
            throw error
        }
    }
}

@MainActor private struct ProfileSelfCouponEntry: View {
    let memberID: Int
    let accountReader: any SocialAccountReading
    let access: ProfileSelfCouponAccess
    let isCurrent: @MainActor () -> Bool
    var body: some View {
        if let context = ProfileSelfCouponContext.capture(memberID: memberID,
            accountReader: accountReader, access: access, isCurrent: isCurrent()) {
            Section {
                NavigationLink {
                    ProfileSelfCouponDestination(context: context, accountReader: accountReader,
                        access: access, isCurrent: isCurrent).id(context)
                } label: { Label("accountCollection.coupons.title", systemImage: "ticket") }
                    .accessibilityIdentifier("profile.selfCoupons")
            }.id(context)
        }
    }
}

@MainActor private struct ProfileSelfCouponDestination: View {
    @EnvironmentObject private var session: AppSession
    @State private var reader: ProfileSelfCouponScopedReader
    init(context: ProfileSelfCouponContext, accountReader: any SocialAccountReading,
         access: ProfileSelfCouponAccess, isCurrent: @escaping @MainActor () -> Bool) {
        _reader = State(initialValue: .init(context: context, accountReader: accountReader,
            access: access, isCurrent: isCurrent))
    }
    var body: some View {
        Group {
            if reader.associationIsCurrent { AccountCollectionCouponsView(reader: reader) }
            else { Text("social.changed") }
        }
        .environment(\.couponCodeFactory, nil)
        .id(session.profileOwnedCouponReader.scope)
    }
}

/// Round avatar for the public profile head; the MP default avatar when there is no https image.
@MainActor private struct ProfilePublicAvatar: View {
    let source: String?
    let name: String?
    var body: some View {
        Group {
            if let url = MemberIdentityCardSection.remoteAvatarURL(source) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image { image.resizable().scaledToFill() } else { placeholder }
                }
            } else { placeholder }
        }
        .frame(width: 64, height: 64).clipShape(Circle())
        .accessibilityHidden(true)
    }
    /// MP cy-profile: a player without an avatar shows `/images/d_profile.png` (`MPAsset.AvatarDefault.dProfile`).
    private var placeholder: some View {
        ZStack {
            Circle().fill(.tint.opacity(0.15))
            MPAsset.AvatarDefault.dProfile.resizable().scaledToFill()
        }
    }
}


/// A2-03: MP `cy-profile` 关注 (cyp wxml:97-106, js:1775-1800). One tap prepares and confirms the reviewed
/// `.toggleFollow` command in place: the label reads 处理中… while it runs, flips to 已关注 / 关注 on an
/// acknowledged receipt (success haptic), and shows the write failure inline otherwise. No editor page.
@MainActor struct SocialProfileInlineFollowButton<Label: View>: View {
    let memberID: Int
    let serverFollowed: Bool?
    let coordinator: SocialActionCoordinator
    @ViewBuilder let label: (Text, String?) -> Label
    @State private var ownerID = UUID()
    @State private var busy = false
    @State private var override: Bool?
    @State private var failed = false
    @State private var succeeded = 0
    private var followed: Bool? { override ?? serverFollowed }
    var body: some View {
        VStack(spacing: CYSpacing.xxs) {
            Button { Task { await toggle() } } label: {
                if busy { label(Text("social.follow.pending"), nil) }
                else if followed == true { label(Text("social.following"), "checkmark") }
                else { label(Text("social.editor.follow"), "plus") }
            }
            .disabled(busy || followed == nil || coordinator.identity.accountID == nil)
            .accessibilityValue(busy ? Text("social.follow.pending") : Text(verbatim: ""))
            .accessibilityHint(followed == true ? Text("social.editor.unfollow") : Text(verbatim: ""))
            .accessibilityIdentifier("social.profile.follow")
            if failed {
                Text("social.follow.failed").font(.footnote).foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("social.profile.follow.failed")
            }
        }
        .sensoryFeedback(.success, trigger: succeeded)
        .onChange(of: serverFollowed) { _, _ in override = nil }
        .onDisappear {
            coordinator.leaveScreen(target: .member(memberID), expectedIdentity: coordinator.identity, ownerID: ownerID)
        }
    }
    private func toggle() async {
        guard !busy else { return }
        let identity = coordinator.identity
        busy = true; failed = false
        defer { busy = false }
        do {
            let review = try await coordinator.prepare(.toggleFollow, target: .member(memberID), ownerID: ownerID, expectedIdentity: identity)
            guard !Task.isCancelled, coordinator.identity == identity else { coordinator.cancel(review); return }
            await coordinator.confirm(review)
            if case .acknowledged(let receipt) = coordinator.state(target: .member(memberID)) {
                override = receipt.followed ?? !(review.snapshot.profile?.isFollowed ?? false)
                succeeded += 1
            } else {
                failed = true
            }
        } catch {
            if coordinator.identity == identity { failed = true }
        }
    }
}


/// A2-03 (发消息): host-provided IM conversation screen for a `conversationId` (`MessagingHistoryView` in the app).
/// Nil (fixtures, hosts without IM) keeps the reviewed `.startChat` editor.
private struct SocialConversationDestinationKey: EnvironmentKey {
    static let defaultValue: (@MainActor (Int) -> AnyView)? = nil
}
extension EnvironmentValues {
    var socialConversationDestination: (@MainActor (Int) -> AnyView)? {
        get { self[SocialConversationDestinationKey.self] }
        set { self[SocialConversationDestinationKey.self] = newValue }
    }
}

/// A2-03: MP `cy-profile` 发消息. One tap sends `ProfileIMStartContract` (`target_member_id` form body)
/// when the signed-in root installed `profileIMStartWire`, then hands `conversationId` to `onOpen`.
/// Hosts without that wire keep the reviewed coordinator path.
@MainActor struct SocialProfileInlineStartChatButton<Label: View>: View {
    let memberID: Int
    let coordinator: SocialActionCoordinator
    let onOpen: (Int) -> Void
    @ViewBuilder let label: (Text, String?) -> Label
    @Environment(\.profileIMStartWire) private var profileIMStartWire
    @State private var ownerID = UUID()
    @State private var busy = false
    @State private var failed = false
    var body: some View {
        VStack(spacing: CYSpacing.xxs) {
            Button { Task { await start() } } label: {
                if busy { label(Text("social.follow.pending"), nil) }
                else { label(Text("social.editor.startChat"), "message") }
            }
            .disabled(busy || coordinator.identity.accountID == nil)
            .accessibilityValue(busy ? Text("social.follow.pending") : Text(verbatim: ""))
            .accessibilityIdentifier("social.profile.startChat")
            if failed {
                Text("social.startChat.failed").font(.footnote).foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("social.profile.startChat.failed")
            }
        }
        .onDisappear {
            coordinator.leaveScreen(target: .member(memberID), expectedIdentity: coordinator.identity, ownerID: ownerID)
        }
    }
    private func start() async {
        guard !busy else { return }
        let identity = coordinator.identity
        busy = true; failed = false
        defer { busy = false }
        if let wire = profileIMStartWire {
            await startWithContract(wire, identity: identity)
            return
        }
        do {
            let review = try await coordinator.prepare(.startChat, target: .member(memberID), ownerID: ownerID, expectedIdentity: identity)
            guard !Task.isCancelled, coordinator.identity == identity else { coordinator.cancel(review); return }
            await coordinator.confirm(review)
            if case .acknowledged(let receipt) = coordinator.state(target: .member(memberID)), let id = receipt.conversationID, id > 0,
               coordinator.identity == identity {
                onOpen(id)
            } else {
                failed = true
            }
        } catch {
            if coordinator.identity == identity { failed = true }
        }
    }

    /// Profile form contract: `content-type: application/x-www-form-urlencoded;`, field `target_member_id`.
    private func startWithContract(_ wire: ProfileIMStartWire, identity: SocialAccountIdentity) async {
        do {
            guard let base = wire.baseURL(), let token = wire.token() else { failed = true; return }
            let request = try ProfileIMStartContract.request(baseURL: base, targetMemberID: String(memberID), token: token)
            let (data, status) = try await wire.send(request)
            guard !Task.isCancelled, coordinator.identity == identity else { return }
            guard (200..<300).contains(status) else { failed = true; return }
            let id = try ProfileIMStartContract.conversationID(in: data)
            guard coordinator.identity == identity, id > 0 else { failed = true; return }
            onOpen(id)
        } catch {
            if coordinator.identity == identity { failed = true }
        }
    }
}

/// Signed-in root supplies the base URL, token, and the existing app transport.
/// The button builds the body with `ProfileIMStartContract` and does not use `SocialActionRequestBuilder`.
struct ProfileIMStartWire {
    var baseURL: @MainActor () -> URL?
    var token: @MainActor () -> String?
    var send: @MainActor (URLRequest) async throws -> (Data, Int)
}

private struct ProfileIMStartWireKey: EnvironmentKey {
    static let defaultValue: ProfileIMStartWire? = nil
}

extension EnvironmentValues {
    var profileIMStartWire: ProfileIMStartWire? {
        get { self[ProfileIMStartWireKey.self] }
        set { self[ProfileIMStartWireKey.self] = newValue }
    }
}

struct SocialProfileImagePreview: Identifiable {
    let index: Int
    let sources: [String]
    var id: Int { index }
}

/// A2-07: full-screen 探索作品 pager (MP wx.previewImage). Black stage, swipe between images, close in the toolbar.
@MainActor struct SocialProfileImagePreviewPager: View {
    let preview: SocialProfileImagePreview
    @Environment(\.dismiss) private var dismiss
    @State private var selection = 0
    var body: some View {
        NavigationStack {
            TabView(selection: $selection) {
                ForEach(Array(preview.sources.enumerated()), id: \.offset) { index, source in
                    SquareImage(source: source)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: preview.sources.count > 1 ? .automatic : .never))
            .background(Color.black.ignoresSafeArea())
            .navigationTitle(Text(verbatim: "\(selection + 1)/\(preview.sources.count)"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.close") { dismiss() }.accessibilityIdentifier("social.portfolio.preview.close")
                }
            }
        }
        .onAppear { selection = preview.index }
        .accessibilityIdentifier("social.portfolio.preview")
    }
}
