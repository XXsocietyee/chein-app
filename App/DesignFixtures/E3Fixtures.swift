#if DEBUG
import SwiftUI

/// E3 social fixtures. Each case mounts an existing offline DEBUG host (synthetic data) under the player theme.
/// Variants are selected with the host's own launch arguments, e.g.
/// `--design-fixture e3-social --uitesting-social-destination invites`.
enum E3Fixtures {
    @MainActor static func make(_ name: String) -> AnyView? {
        switch name {
        case "e3-inbox": return wrap(MessagingFixtureHostView(scenario: .success))
        case "e3-inbox-empty": return wrap(MessagingFixtureHostView(scenario: .empty))
        case "e3-inbox-error": return wrap(MessagingFixtureHostView(scenario: .error))
        case "e3-chat": return wrap(MessageActionFixtureHost())
        case "e3-poll-detail": return wrap(GroupPollDirectFixtureRoot())
        case "e3-poll": return wrap(GroupPollFixtureRoot(scenario: "success"))
        case "e3-social": return wrap(SocialAccountFixtureHostView())
        case "e3-coop": return wrap(CooperationFixtureHostView())
        case "e3-club-community": return wrap(ClubCommunityFixtureRoot())
        case "e3-club-detail": return wrap(D4ClubFixture(.detail(owner: false)))
        case "e3-club-detail-spec": return wrap(E3ClubDetailFixture())
        case "e3-club-events": return wrap(D4ClubFixture(.tab(.events)))
        case "e3-club-overview": return wrap(D4ClubFixture(.tab(.overview)))
        case "e3-club-story": return wrap(ClubStoryFixtureHost())
        case "e3-club-apply": return wrap(E3ClubApplyFixture())
        case "e3-club-calendar": return wrap(E3ClubCalendarFixture())
        case "e3-club-feed": return wrap(E3ClubFeedFixture())
        case "e3-chat-rich": return wrap(E3RichChatFixture())
        case "e3-invite": return wrap(E3InviteFixture())
        case "e3-notices": return wrap(E3NoticesFixture())
        case "e3-people": return wrap(E3PeopleFixture())
        case "e3-real-friends": return wrap(E3RealFriendsHost())
        case "e3-real-follow": return wrap(E3RealFollowHost())
        case "e3-real-imcards": return wrap(E3RealIMCardsHost())
        default: return E3ShareFixtures.make(name)
        }
    }
    @MainActor private static func wrap<V: View>(_ v: V) -> AnyView { AnyView(v.roleTheme(.player)) }
}




// DEBUG-only design fixtures for the social family. All people, clubs and posts are synthetic and generated
// (CYCoverArt gradients stand in for photos); nothing here reaches a Release build or a production path.

private struct E3Page<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content
    @Environment(\.locale) private var locale
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CYSpacing.xl) {
                    content()
                    Text(verbatim: locale.pick("调试示例 · 合成数据", "DEBUG fixture · synthetic data")).cyText(.caption).foregroundStyle(CYColor.textTertiary)
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, CYSpacing.lg).padding(.vertical, CYSpacing.md)
            }
            .background(CYColor.bgPage.ignoresSafeArea())
            .navigationTitle(title).navigationBarTitleDisplayMode(.large)
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: Club detail

struct E3ClubDetailFixture: View {
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var tab = 0
    @State private var joined = false
    var body: some View {
        let t = { (zh: String, en: String) in locale.pick(zh, en) }
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CYSpacing.lg) {
                    ZStack(alignment: .bottomLeading) {
                        CYIMCoverArt(seed: "E3 Night Walkers", systemImage: "moon.stars.fill", symbolSize: 72)
                            .frame(height: 300).frame(maxWidth: .infinity).clipped()
                        LinearGradient(stops: [.init(color: .clear, location: 0.35), .init(color: .black, location: 1)], startPoint: .top, endPoint: .bottom)
                        VStack(alignment: .leading, spacing: CYSpacing.sm) {
                            CYStatusChip(verbatim: t("公开加入", "Open to join"), tone: .success, systemImage: "checkmark.circle")
                            Text(verbatim: t("夜行者俱乐部", "Night Walkers")).cyText(.pageTitle).foregroundStyle(.white).lineLimit(3)
                            Text(verbatim: t("每周三晚，漫步老城区的灯与影。", "Wednesday evenings, strolling the lights and shadows of the old town.")).cyText(.body).foregroundStyle(.white.opacity(0.85))
                        }.padding(CYSpacing.lg)
                    }
                    .frame(maxWidth: .infinity)
                    VStack(alignment: .leading, spacing: CYSpacing.lg) {
                        HStack(spacing: CYSpacing.md) {
                            E3AvatarStack(seeds: ["a1", "b2", "c3", "d4", "e5"], extra: 123)
                            Text(verbatim: t("128 位成员 · 本周 3 场活动", "128 members · 3 events this week")).cyText(.meta).foregroundStyle(CYColor.textSecondary).lineLimit(2)
                        }
                        Picker("", selection: $tab) {
                            Text(verbatim: t("动态", "Posts")).tag(0); Text(verbatim: t("活动", "Events")).tag(1); Text(verbatim: t("关于", "About")).tag(2)
                        }.pickerStyle(.segmented)
                        if tab == 0 {
                            E3PostCard(author: t("林夏", "Lin Xia"), club: t("夜行者", "Night Walkers"), time: t("2 小时前", "2h ago"), text: t("今晚的老城巷子太美了，霓虹和雨刚刚好。", "The old-town alleys tonight were perfect, neon and rain."), coverSeed: "alley", likes: 42, comments: 8)
                        } else if tab == 1 {
                            CYImageCard(verbatim: t("周三夜行：老城灯影", "Wednesday walk: old-town lights"), fallback: "", meta: t("周三 19:30 · 钟楼广场", "Wed 7:30 PM · Clock Tower Square"), aspectRatio: 16.0 / 10.0, style: .hero)
                        } else {
                            Text(verbatim: t("一群喜欢夜晚散步、拍照、收集街头故事的人。新人随时欢迎，无需经验。", "People who love evening walks, photography and collecting street stories. Newcomers welcome, no experience needed.")).cyText(.body).foregroundStyle(CYColor.textSecondary).e3Card()
                        }
                    }.padding(.horizontal, CYSpacing.lg)
                    Text(verbatim: t("调试示例 · 合成数据", "DEBUG fixture · synthetic data")).cyText(.caption).foregroundStyle(CYColor.textTertiary).frame(maxWidth: .infinity)
                }
            }
            .ignoresSafeArea(edges: .top)
            .background(CYColor.bgPage.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                Button { withAnimation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.65)) { joined.toggle() } } label: {
                    Label(joined ? t("已加入", "Joined") : t("加入俱乐部", "Join club"), systemImage: joined ? "checkmark.circle.fill" : "plus")
                        .cyText(.cardTitle).symbolEffect(.bounce, value: joined)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .foregroundStyle(joined ? CYColor.textPrimary : CYColor.textInverse)
                        .background(joined ? CYColor.bgRaised : CYColor.textPrimary, in: Capsule())
                }
                .buttonStyle(E3PressStyle()).sensoryFeedback(.success, trigger: joined)
                .padding(.horizontal, CYSpacing.lg).padding(.vertical, CYSpacing.sm).background(.ultraThinMaterial)
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: Club apply / create

struct E3ClubApplyFixture: View {
    @Environment(\.locale) private var locale
    @State private var name = ""
    @State private var about = ""
    @State private var category = 0
    @State private var agree = true
    var body: some View {
        let t = { (zh: String, en: String) in locale.pick(zh, en) }
        let cats = [t("夜行", "Night"), t("摄影", "Photo"), t("美食", "Food"), t("运动", "Sport"), t("桌游", "Games")]
        E3Page(title: t("创建俱乐部", "Create a club")) {
            ZStack(alignment: .bottomTrailing) {
                CYIMCoverArt(seed: name.isEmpty ? "new club" : name, systemImage: "sparkles", symbolSize: 56)
                    .frame(height: 180).frame(maxWidth: .infinity).clipShape(RoundedRectangle(cornerRadius: CYRadius.hero, style: .continuous))
                Label(t("更换封面", "Change cover"), systemImage: "photo").cyText(.bodyMedium).foregroundStyle(.white)
                    .padding(.horizontal, 12).frame(minHeight: 36).background(.black.opacity(0.5), in: Capsule()).padding(CYSpacing.md)
            }
            VStack(alignment: .leading, spacing: CYSpacing.md) {
                E3SectionTitle(title: t("基本信息", "Basics"))
                TextField(t("俱乐部名称", "Club name"), text: $name).padding(CYSpacing.md).frame(minHeight: 52)
                    .background(CYColor.bgElevated, in: RoundedRectangle(cornerRadius: CYRadius.card, style: .continuous))
                TextField(t("一句话介绍", "One-line pitch"), text: $about, axis: .vertical).lineLimit(2...4).padding(CYSpacing.md).frame(minHeight: 52)
                    .background(CYColor.bgElevated, in: RoundedRectangle(cornerRadius: CYRadius.card, style: .continuous))
            }
            VStack(alignment: .leading, spacing: CYSpacing.md) {
                E3SectionTitle(title: t("类型", "Category"))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: CYSpacing.sm) {
                        ForEach(Array(cats.enumerated()), id: \.offset) { i, c in
                            Button { category = i } label: {
                                Text(verbatim: c).cyText(.bodyMedium).padding(.horizontal, 16).frame(minHeight: 44)
                                    .foregroundStyle(category == i ? CYColor.textInverse : CYColor.textPrimary)
                                    .background(category == i ? CYColor.textPrimary : CYColor.bgElevated, in: Capsule())
                            }.buttonStyle(E3PressStyle()).accessibilityAddTraits(category == i ? .isSelected : [])
                        }
                    }
                }.sensoryFeedback(.selection, trigger: category)
            }
            Toggle(isOn: $agree) { Text(verbatim: t("我已阅读并同意社区规则", "I have read and agree to the community rules")).cyText(.meta).foregroundStyle(CYColor.textSecondary) }
                .e3Card(padding: CYSpacing.md)
            CYPillButton(verbatim: t("提交申请", "Submit application")) {}
        }
    }
}

// MARK: Club calendar

struct E3ClubCalendarFixture: View {
    @Environment(\.locale) private var locale
    @State private var selected = 12
    var body: some View {
        let t = { (zh: String, en: String) in locale.pick(zh, en) }
        let wd = locale.pick("日 一 二 三 四 五 六", "S M T W T F S").split(separator: " ").map(String.init)
        E3Page(title: t("十一月", "November")) {
            E3MonthGrid(weekdays: wd, daysInMonth: 30, firstWeekdayOffset: 0, eventDays: [4, 12, 18, 25], today: 9, selected: $selected).e3Card(padding: CYSpacing.md)
            E3SectionTitle(title: t("11 月 \(selected) 日", "Nov \(selected)"), trailing: t("2 场活动", "2 events"))
            ForEach([(t("周三夜行：老城灯影", "Wednesday walk: old-town lights"), "19:30", t("钟楼广场", "Clock Tower Square"), "night"),
                     (t("街头摄影交流", "Street photo meetup"), "21:00", t("河畔咖啡", "Riverside Café"), "photo")], id: \.0) { e in
                HStack(spacing: CYSpacing.md) {
                    CYIMCoverArt(seed: e.3, systemImage: "figure.walk", symbolSize: 22).frame(width: 64, height: 64).clipShape(RoundedRectangle(cornerRadius: CYRadius.card, style: .continuous))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(verbatim: e.0).cyText(.bodyMedium).foregroundStyle(CYColor.textPrimary).lineLimit(2)
                        Text(verbatim: e.1 + " · " + e.2).cyText(.meta).foregroundStyle(CYColor.textTertiary).lineLimit(2)
                        E3AvatarStack(seeds: ["x", "y", "z"], extra: 9, size: 22)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").accessibilityHidden(true).font(.footnote.weight(.semibold)).foregroundStyle(CYColor.textTertiary)
                }.e3Card(padding: CYSpacing.md)
            }
        }
    }
}

// MARK: Club stories / posts

struct E3ClubFeedFixture: View {
    @Environment(\.locale) private var locale
    var body: some View {
        let t = { (zh: String, en: String) in locale.pick(zh, en) }
        E3Page(title: t("俱乐部动态", "Club feed")) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: CYSpacing.md) {
                    ForEach([t("夜行者", "Night Walkers"), t("光影", "Lumen"), t("味蕾", "Tastebuds"), t("骑行", "Riders")], id: \.self) { n in
                        VStack(spacing: 6) {
                            E3Avatar(seed: n, systemImage: "sparkles", size: 60).padding(3)
                                .overlay(Circle().strokeBorder(AngularGradient(colors: [.orange, .pink, CYColor.avatarRing, .orange], center: .center), lineWidth: 2.5))
                            Text(verbatim: n).cyText(.meta).foregroundStyle(CYColor.textSecondary).lineLimit(1).frame(width: 72)
                        }
                    }
                }
            }
            E3PostCard(author: t("林夏", "Lin Xia"), club: t("夜行者", "Night Walkers"), time: t("2 小时前", "2h ago"), text: t("今晚的老城巷子太美了，霓虹和雨刚刚好。", "The old-town alleys tonight were perfect, neon and rain."), coverSeed: "alley", likes: 42, comments: 8)
            E3PostCard(author: t("陈默", "Chen Mo"), club: t("光影", "Lumen"), time: t("昨天", "Yesterday"), text: t("日落前十分钟的河岸。", "The riverbank ten minutes before sunset."), coverSeed: "river", coverSymbol: "sun.haze.fill", likes: nil, comments: 3)
        }
    }
}

// MARK: Chat with rich cards

struct E3RichChatFixture: View {
    @Environment(\.locale) private var locale
    @State private var draft = ""
    var body: some View {
        let t = { (zh: String, en: String) in locale.pick(zh, en) }
        NavigationStack {
            ScrollView {
                VStack(spacing: 4) {
                    Text(verbatim: t("今天 19:24", "Today 7:24 PM")).cyText(.meta).foregroundStyle(CYColor.textTertiary).padding(.vertical, CYSpacing.sm)
                    row(false, "u1", .first, t("到了吗？", "Are you there yet?"))
                    row(false, "u1", .last, t("我在钟楼下面，给你发位置", "I'm under the clock tower, sending the pin"), time: "19:24")
                    HStack(alignment: .bottom, spacing: 8) { Color.clear.frame(width: 28, height: 1); E3LocationCard(place: t("钟楼广场", "Clock Tower Square"), address: t("老城区 中山路 1 号", "1 Zhongshan Rd, Old Town")); Spacer(minLength: 0) }.padding(.top, 6)
                    row(true, "me", .first, t("马上，3 分钟", "Almost, 3 minutes"))
                    row(true, "me", .last, t("先听这个", "Listen to this first"), time: "19:26")
                    HStack { Spacer(); E3VoiceCard(duration: "0:18", isOwn: true) }.padding(.top, 6)
                    HStack(alignment: .bottom, spacing: 8) { E3Avatar(seed: "u1", size: 28); E3FileCard(name: t("夜行路线.pdf", "night-route.pdf"), size: "1.2 MB"); Spacer(minLength: 0) }.padding(.top, 10)
                    HStack(alignment: .bottom, spacing: 8) { E3Avatar(seed: "u1", size: 28); E3VideoCard(seed: "vid", duration: "0:42"); Spacer(minLength: 0) }.padding(.top, 6)
                    Text(verbatim: t("调试示例 · 合成数据", "DEBUG fixture · synthetic data")).cyText(.caption).foregroundStyle(CYColor.textTertiary).padding(.top, CYSpacing.lg)
                }.padding(.horizontal, CYSpacing.lg)
            }
            .defaultScrollAnchor(.bottom)
            .background(CYColor.bgPage.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) { composer(t) }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) { E3Avatar(seed: "u1", size: 28); VStack(alignment: .leading, spacing: 0) { Text(verbatim: t("林夏", "Lin Xia")).cyText(.cardTitle); Text(verbatim: t("在线", "Online")).cyText(.caption).foregroundStyle(.green) } }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    private func row(_ own: Bool, _ seed: String, _ pos: ChatGroupPosition, _ text: String, time: String? = nil) -> some View {
        HStack(alignment: .bottom, spacing: 8) {
            if !own { if pos.showsTail { E3Avatar(seed: seed, size: 28) } else { Color.clear.frame(width: 28, height: 1) } }
            ChatMessageBubble(isOwn: own, timestamp: time, position: pos) { EmptyView() } content: { Text(verbatim: text) }
        }
    }
    private func composer(_ t: @escaping (String, String) -> String) -> some View {
        HStack(alignment: .bottom, spacing: 8) {
            Image(systemName: "plus").accessibilityLabel(Text(verbatim: t("添加", "Add"))).font(.title3.weight(.medium)).frame(width: 44, height: 44).foregroundStyle(CYColor.textSecondary)
            HStack(spacing: 4) {
                TextField(t("发消息…", "Message"), text: $draft).padding(.leading, 16).frame(minHeight: 44)
                let live = !draft.isEmpty
                Image(systemName: "arrow.up").accessibilityLabel(Text(verbatim: t("发送", "Send"))).font(.subheadline.weight(.bold)).foregroundStyle(live ? Color.white : Color.secondary)
                    .frame(width: 32, height: 32).background(live ? CYChat.sent : Color.secondary.opacity(0.25), in: Circle()).padding(.trailing, 6)
            }
            .background(CYColor.bgRaised, in: RoundedRectangle(cornerRadius: CYRadius.hero, style: .continuous))
        }
        .padding(.horizontal, CYSpacing.lg).padding(.vertical, CYSpacing.sm).background(CYColor.bgPage)
    }
}

// MARK: Cooperation invite detail

struct E3InviteFixture: View {
    @Environment(\.locale) private var locale
    @State private var accepted = false
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        let t = { (zh: String, en: String) in locale.pick(zh, en) }
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CYSpacing.lg) {
                    ZStack(alignment: .bottomLeading) {
                        CYIMCoverArt(seed: "coop invite", systemImage: "handshake.fill", symbolSize: 52).frame(height: 170)
                        LinearGradient(colors: [.clear, .black.opacity(0.8)], startPoint: .top, endPoint: .bottom)
                        VStack(alignment: .leading, spacing: 6) {
                            CYStatusChip(verbatim: accepted ? t("已接受", "Accepted") : t("待回复", "Awaiting reply"), tone: accepted ? .success : .warning, systemImage: accepted ? "checkmark.circle" : "clock")
                            Text(verbatim: t("河畔咖啡 × 夜行者", "Riverside Café × Night Walkers")).cyText(.display).foregroundStyle(.white)
                        }.padding(CYSpacing.lg)
                    }.clipShape(RoundedRectangle(cornerRadius: CYRadius.hero, style: .continuous))
                    VStack(alignment: .leading, spacing: CYSpacing.md) {
                        E3SectionTitle(title: t("合作条款", "Terms"))
                        term("percent", t("分成", "Revenue share"), t("商家 70% · 俱乐部 30%", "Venue 70% · Club 30%"))
                        Divider().overlay(CYColor.borderSubtle)
                        term("calendar", t("有效期至", "Valid until"), "2026-12-31")
                        Divider().overlay(CYColor.borderSubtle)
                        term("lock.shield", t("押金", "Deposit"), "—")
                    }.e3Card()
                    VStack(alignment: .leading, spacing: 6) {
                        Text(verbatim: t("对方留言", "Their message")).cyText(.caption).foregroundStyle(CYColor.textTertiary)
                        Text(verbatim: t("希望每周三晚上在我们店做一场夜行集合。", "We'd love to host a Wednesday night walk meet-up at our café.")).cyText(.body).foregroundStyle(CYColor.textPrimary)
                    }.e3Card()
                    Text(verbatim: t("调试示例 · 合成数据", "DEBUG fixture · synthetic data")).cyText(.caption).foregroundStyle(CYColor.textTertiary).frame(maxWidth: .infinity)
                }.padding(.horizontal, CYSpacing.lg).padding(.vertical, CYSpacing.md)
            }
            .background(CYColor.bgPage.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 4) {
                    CYPillButton(verbatim: accepted ? t("查看合作", "View collaboration") : t("接受邀请", "Accept invite")) { accepted = true }
                        .sensoryFeedback(.success, trigger: accepted)
                    if !accepted { Button(t("婉拒", "Decline")) {}.font(.subheadline).foregroundStyle(CYColor.textSecondary).frame(minHeight: 44) }
                }.padding(.horizontal, CYSpacing.lg).padding(.top, CYSpacing.sm).background(.ultraThinMaterial)
            }
            .navigationTitle(t("合作邀请", "Invitation")).navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(.dark)
    }
    private func term(_ icon: String, _ k: String, _ v: String) -> some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4)) : AnyLayout(HStackLayout(alignment: .top, spacing: CYSpacing.md))
        return layout {
            Image(systemName: icon).foregroundStyle(CYColor.textSecondary).frame(width: 24).accessibilityHidden(true)
            Text(verbatim: k).cyText(.meta).foregroundStyle(CYColor.textTertiary)
            if !typeSize.isAccessibilitySize { Spacer(minLength: CYSpacing.sm) }
            Text(verbatim: v).cyText(.bodyMedium).foregroundStyle(CYColor.textPrimary).multilineTextAlignment(typeSize.isAccessibilitySize ? .leading : .trailing)
        }
    }
}

// MARK: Notices

struct E3NoticesFixture: View {
    @Environment(\.locale) private var locale
    @State private var filter = 0
    var body: some View {
        let t = { (zh: String, en: String) in locale.pick(zh, en) }
        E3Page(title: t("通知", "Notices")) {
            ScrollView(.horizontal, showsIndicators: false) { HStack(spacing: CYSpacing.sm) {
                ForEach(Array([t("全部", "All"), t("俱乐部", "Clubs"), t("合作", "Collab"), t("系统", "System")].enumerated()), id: \.offset) { i, n in
                    Button { filter = i } label: {
                        Text(verbatim: n).cyText(.bodyMedium).padding(.horizontal, 14).frame(minHeight: 44).fixedSize()
                            .foregroundStyle(filter == i ? CYColor.textInverse : CYColor.textPrimary)
                            .background(filter == i ? CYColor.textPrimary : CYColor.bgElevated, in: Capsule())
                    }.buttonStyle(E3PressStyle())
                }
            } }.sensoryFeedback(.selection, trigger: filter)
            E3SectionTitle(title: t("今天", "Today"))
            VStack(spacing: 0) {
                E3NoticeRow(systemImage: "person.3.fill", tint: .orange, title: t("夜行者批准了你的加入申请", "Night Walkers approved your request"), detail: t("欢迎！本周三 19:30 钟楼广场集合。", "Welcome! Meet Wednesday 7:30 PM at Clock Tower Square."), time: t("刚刚", "Just now"), unread: true)
                Divider().overlay(CYColor.borderSubtle).padding(.leading, 56)
                E3NoticeRow(systemImage: "handshake.fill", tint: .teal, title: t("河畔咖啡发来合作邀请", "Riverside Café sent an invitation"), detail: t("点开查看条款并回复。", "Open to review the terms and reply."), time: t("12 分钟前", "12 min ago"), unread: true)
            }.e3Card(padding: CYSpacing.md)
            E3SectionTitle(title: t("更早", "Earlier"))
            VStack(spacing: 0) {
                E3NoticeRow(systemImage: "bell.badge.fill", tint: .indigo, title: t("活动提醒：街头摄影交流", "Reminder: Street photo meetup"), detail: t("明天 21:00，河畔咖啡。", "Tomorrow 9:00 PM, Riverside Café."), time: t("昨天", "Yesterday"))
                Divider().overlay(CYColor.borderSubtle).padding(.leading, 56)
                E3NoticeRow(systemImage: "shield.checkered", tint: .gray, title: t("举报已处理", "Your report was reviewed"), detail: t("我们已处理你提交的举报，谢谢。", "We've handled the report you sent. Thank you."), time: t("3 天前", "3 days ago"))
            }.e3Card(padding: CYSpacing.md)
        }
    }
}

// MARK: Friends / followers

struct E3PeopleFixture: View {
    @Environment(\.locale) private var locale
    @State private var states: [E3FollowState] = [.follow, .following, .requested, .mutual, .follow]
    var body: some View {
        let t = { (zh: String, en: String) in locale.pick(zh, en) }
        let people = [(t("林夏", "Lin Xia"), t("3 位共同好友", "3 mutual friends")), (t("陈默", "Chen Mo"), t("同在夜行者", "Also in Night Walkers")),
                      (t("周小满", "Zhou Xiaoman"), t("2 位共同好友", "2 mutual friends")), (t("Ava Reyes", "Ava Reyes"), t("互相关注", "Follows you back")), (t("许知远", "Xu Zhiyuan"), t("附近的玩家", "Player nearby"))]
        E3Page(title: t("关注", "Followers")) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").accessibilityHidden(true).foregroundStyle(CYColor.textTertiary)
                Text(verbatim: t("搜索昵称", "Search by name")).foregroundStyle(CYColor.textPlaceholder)
                Spacer()
            }.cyText(.body).padding(.horizontal, CYSpacing.md).frame(minHeight: 44).background(CYColor.bgElevated, in: Capsule())
            VStack(spacing: 0) {
                ForEach(Array(people.enumerated()), id: \.offset) { i, p in
                    E3PersonRow(name: p.0, meta: p.1, seed: p.0, state: states[i], actionTitle: title(states[i], t)) {
                        states[i] = states[i] == .follow ? .following : .follow
                    }
                    if i < people.count - 1 { Divider().overlay(CYColor.borderSubtle).padding(.leading, 60) }
                }
            }
        }
    }
    private func title(_ s: E3FollowState, _ t: (String, String) -> String) -> String {
        switch s { case .follow: return t("关注", "Follow"); case .following: return t("已关注", "Following"); case .requested: return t("已申请", "Requested"); case .mutual: return t("互相关注", "Friends") }
    }
}


// MARK: - Fifth pass: hosts that reach the REAL production views with stub data (DEBUG only)

@MainActor private final class E3FriendService: NativeFriendDirectoryServing {
    let viewerID: Int64 = 2
    var isCurrent: Bool { true }
    private let names = ["Mina Chen", "Jun Park", "林小满", "Aiko Tanaka", "周末骑行队长", "Sam Rivera", "Noor Haddad", "陈一鸣"]
    private func item(_ i: Int) -> [String: Any] {
        ["peer_id": 100 + i, "nickname": names[i], "state": 1, "version": 3, "msg": "", "expires_at_ms": 0, "starred": i < 2 ? 1 : 0]
    }
    func page(filter: NativeFriendDirectoryFilter, cursor: String?) async throws -> NativeFriendDirectoryPage {
        let json: [String: Any] = [
            "viewer_id": 2, "section": filter.section.rawValue, "group_id": NSNull(), "starred_only": filter.starredOnly,
            "revision": String(repeating: "a", count: 64),
            "groups": ["viewer_id": 2, "list": [["id": NSNull(), "name": "default", "position": 0, "version": 0, "is_default": 1]]],
            "counts": ["all": names.count, "recent": 4, "together": 3], "total": names.count,
            "items": (0..<names.count).map(item), "has_more": false, "next_cursor": NSNull()]
        return try JSONDecoder().decode(NativeFriendDirectoryPage.self, from: JSONSerialization.data(withJSONObject: json))
    }
    func detail(peerID: Int64) async throws -> NativeFriendDirectoryDetail { throw NativeFriendDirectoryFailure.unavailablePeer }
}

@MainActor struct E3RealFriendsHost: View {
    @State private var flow = NativeFriendDirectoryFlow(service: E3FriendService())
    var body: some View {
        NavigationStack { NativeFriendDirectoryView(flow: flow, conversation: { _ in AnyView(EmptyView()) }) }
    }
}

@MainActor private final class E3FollowReader: ProfileFollowListReading {
    private let base = SocialAccountFixtureReader(.content)
    let scope = UUID()
    var isCurrent: Bool { true }
    var identity: SocialAccountIdentity { base.identity }
    var isConfigured: Bool { true }
    var isOfflineExample: Bool { true }
    func publicProfile(memberID: Int) async throws -> SocialPublicProfile { try await base.publicProfile(memberID: memberID) }
    func informationList() async throws -> [SocialInformation] { [] }
    func information(id: Int) async throws -> SocialInformation { try await base.information(id: id) }
    func invitationHistory(page: Int) async throws -> SocialInviteHistory { try await base.invitationHistory(page: page) }
    func makePublicProfileReader(memberID: Int, isCurrent: @escaping () -> Bool) -> ProfilePublicInfoReader? { nil }
    func page(kind: ProfileFollowListKind, cursor: Int) async throws -> ProfileFollowListPage {
        let names = ["Mina Chen", "Jun Park", "林小满", "Aiko Tanaka", "周末骑行队长", "Sam Rivera"]
        let rows: [[String: Any]] = names.enumerated().map { i, n in
            ["id": 201 + i, "nickname": n, "avatar": NSNull(), "isFollow": kind == .following ? true : i % 2 == 0] }
        let json: [String: Any] = ["owner_id": 81, "kind": kind.rawValue, "rows": rows, "has_more": false, "next_cursor": NSNull()]
        return try JSONDecoder().decode(ProfileFollowListPage.self, from: JSONSerialization.data(withJSONObject: json))
    }
}

@MainActor struct E3RealFollowHost: View {
    @State private var flow = ProfileFollowListFlow(reader: E3FollowReader())
    var body: some View {
        NavigationStack { ProfileFollowListView(flow: flow, squareReader: SquareFixtureReader()) }
    }
}

/// Real IM card label views inside the real ChatMessageBubble (voice / file / video / location).
@MainActor struct E3RealIMCardsHost: View {
    private func decode<T: Decodable>(_ json: String) -> T { try! JSONDecoder().decode(T.self, from: Data(json.utf8)) }
    var body: some View {
        let voice: IMVoiceReference = decode(#"{"uploadRequestID":"00000000-0000-4000-8000-000000000001","assetID":7,"durationMS":23000,"waveform":"AQIDBAUGBwgJCgsMDQ4PEA==","size":4000}"#)
        let file: IMFileReference = decode(#"{"uploadRequestID":"00000000-0000-4000-8000-000000000002","attachmentID":"9","name":"Saturday-route.pdf","size":2411724,"mime":"application/pdf","ext":"pdf","sha256":"\#(String(repeating: "a", count: 64))"}"#)
        let video: IMVideoReference = decode(#"{"uploadRequestID":"00000000-0000-4000-8000-000000000003","attachmentID":"11","sha256":"\#(String(repeating: "b", count: 64))","coverSHA256":"\#(String(repeating: "c", count: 64))","size":5000000,"coverSize":90000,"durationMS":12000,"width":1080,"height":1920}"#)
        let place = try! IMStaticLocation(name: "East Gate, Riverside Park", address: "1 Riverside Road", latitude: 31.23, longitude: 121.47, datum: "WGS84")
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Space.s2) {
                    row(false, .first) { IMStaticLocationCardView(place: place) }
                    row(false, .middle) { IMVoiceCardLabel(reference: voice) }
                    row(false, .last) { IMFileCardLabel(reference: file) }
                    row(true, .first) { IMVideoCardLabel(reference: video) }
                    row(true, .last) { Text(verbatim: "See you at the gate") }
                }.padding(.horizontal, Theme.Space.s4)
            }.navigationTitle(Text(verbatim: "Weekend walks")).navigationBarTitleDisplayMode(.inline)
        }
    }
    private func row<C: View>(_ own: Bool, _ pos: ChatGroupPosition, @ViewBuilder _ c: @escaping () -> C) -> some View {
        HStack(alignment: .bottom, spacing: Theme.Space.s2) {
            if own { Spacer(minLength: 40) }
            ChatMessageBubble(isOwn: own, timestamp: pos.showsTail ? "19:2\(pos == .first ? 1 : 4)" : nil, position: pos) { EmptyView() } content: { c() }
            if !own { Spacer(minLength: 40) }
        }
    }
}
#endif
