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
        case "e3-club-detail": return wrap(E3ClubDetailFixture())
        case "e3-club-apply": return wrap(E3ClubApplyFixture())
        case "e3-club-calendar": return wrap(E3ClubCalendarFixture())
        case "e3-club-feed": return wrap(E3ClubFeedFixture())
        case "e3-chat-rich": return wrap(E3RichChatFixture())
        case "e3-invite": return wrap(E3InviteFixture())
        case "e3-notices": return wrap(E3NoticesFixture())
        case "e3-people": return wrap(E3PeopleFixture())
        default: return nil
        }
    }
    @MainActor private static func wrap<V: View>(_ v: V) -> AnyView { AnyView(v.roleTheme(.player)) }
}


// Social surface kit (e3): player-dark cards, avatars, follow states, rich chat cards, month grid, post cards.
// Presentation only: every view takes plain values / closures; no reads, writes or authority live here.
// Motion is spring-based and gated on Reduce Motion; haptics use sensoryFeedback.

/// Press feedback: a small spring scale, disabled under Reduce Motion.
struct E3PressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct E3Avatar: View {
    let seed: String
    var systemImage = "person.fill"
    var size: CGFloat = 44
    var body: some View {
        CYCoverArt(seed: seed, systemImage: systemImage, symbolSize: size * 0.42)
            .frame(width: size, height: size).clipShape(Circle())
            .overlay(Circle().strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
    }
}

/// Overlapped member avatars with an optional "+N" count (nil = unknown, shows nothing rather than 0).
struct E3AvatarStack: View {
    let seeds: [String]
    var extra: Int? = nil
    var size: CGFloat = 32
    var body: some View {
        HStack(spacing: -size * 0.32) {
            ForEach(Array(seeds.enumerated()), id: \.offset) { i, seed in
                E3Avatar(seed: seed, size: size)
                    .overlay(Circle().strokeBorder(CYColor.bgPage, lineWidth: 2))
                    .zIndex(Double(seeds.count - i))
            }
            if let extra, extra > 0 {
                Text(verbatim: "+\(extra)").font(.caption.weight(.semibold)).monospacedDigit()
                    .foregroundStyle(CYColor.textPrimary)
                    .frame(width: size, height: size)
                    .background(CYColor.bgRaised, in: Circle())
                    .overlay(Circle().strokeBorder(CYColor.bgPage, lineWidth: 2))
            }
        }
    }
}

enum E3FollowState { case follow, following, requested, mutual }

/// Pill follow button: filled for the action, outlined when already following. 44pt hit area.
struct E3FollowButton: View {
    let state: E3FollowState
    let title: String
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if state == .following || state == .mutual { Image(systemName: state == .mutual ? "arrow.left.arrow.right" : "checkmark").font(.caption.weight(.bold)) }
                if state == .requested { Image(systemName: "clock").font(.caption.weight(.bold)) }
                Text(verbatim: title).font(.subheadline.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.8)
            }
            .foregroundStyle(state == .follow ? CYColor.textInverse : CYColor.textPrimary)
            .padding(.horizontal, CYSpacing.lg).frame(minHeight: 36)
            .background(state == .follow ? AnyShapeStyle(CYColor.textPrimary) : AnyShapeStyle(Color.clear), in: Capsule())
            .overlay(Capsule().strokeBorder(state == .follow ? Color.clear : CYColor.borderStrong, lineWidth: 1))
            .frame(minHeight: 44).contentShape(Rectangle())
        }
        .buttonStyle(E3PressStyle())
        .sensoryFeedback(.success, trigger: state)
        .animation(reduceMotion ? nil : .snappy(duration: 0.25), value: state)
    }
}

/// Avatar row for friends / followers: avatar, name + meta, trailing follow button.
struct E3PersonRow: View {
    let name: String
    let meta: String
    let seed: String
    let state: E3FollowState
    let actionTitle: String
    let action: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        let text = VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: name).font(CYTypography.bodyMedium).foregroundStyle(CYColor.textPrimary).fixedSize(horizontal: false, vertical: true)
            Text(verbatim: meta).font(CYTypography.meta).foregroundStyle(CYColor.textTertiary).fixedSize(horizontal: false, vertical: true)
        }
        // At accessibility sizes the follow button drops under the name so nothing truncates.
        Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: CYSpacing.sm) {
                    HStack(spacing: CYSpacing.md) { E3Avatar(seed: seed, size: 48); text }
                    E3FollowButton(state: state, title: actionTitle, action: action)
                }
            } else {
                HStack(spacing: CYSpacing.md) {
                    E3Avatar(seed: seed, size: 48)
                    text
                    Spacer(minLength: CYSpacing.sm)
                    E3FollowButton(state: state, title: actionTitle, action: action)
                }
            }
        }
        .padding(.vertical, CYSpacing.sm)
        .accessibilityElement(children: .contain)
    }
}

/// Notification row: tinted symbol tile, title, body, relative time, unread dot.
struct E3NoticeRow: View {
    let systemImage: String
    let tint: Color
    let title: String
    let detail: String
    let time: String
    var unread = false
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: CYSpacing.sm)) : AnyLayout(HStackLayout(alignment: .top, spacing: CYSpacing.md))
        layout {
            Image(systemName: systemImage).font(.body.weight(.semibold)).foregroundStyle(tint)
                .frame(width: 44, height: 44).background(tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(verbatim: title).font(CYTypography.bodyMedium).foregroundStyle(CYColor.textPrimary)
                Text(verbatim: detail).font(CYTypography.meta).foregroundStyle(CYColor.textSecondary)
                Text(verbatim: time).font(CYTypography.caption).foregroundStyle(CYColor.textTertiary)
            }
            Spacer(minLength: 0)
            if unread, !typeSize.isAccessibilitySize {
                Circle().fill(CYChat.sent).frame(width: 9, height: 9).padding(.top, 6).accessibilityHidden(true)
            }
        }
        .padding(.vertical, CYSpacing.sm)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Rich chat cards (bubble-width, received style or sent style)

/// Location card: generated map tile, place name, address.
struct E3LocationCard: View {
    let place: String
    let address: String
    var isOwn = false
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                LinearGradient(colors: [Color(red: 0.13, green: 0.30, blue: 0.27), Color(red: 0.07, green: 0.14, blue: 0.20)], startPoint: .topLeading, endPoint: .bottomTrailing)
                Path { p in
                    p.move(to: CGPoint(x: 0, y: 70)); p.addCurve(to: CGPoint(x: 260, y: 30), control1: CGPoint(x: 80, y: 20), control2: CGPoint(x: 160, y: 90))
                    p.move(to: CGPoint(x: 40, y: 0)); p.addLine(to: CGPoint(x: 120, y: 120))
                    p.move(to: CGPoint(x: 200, y: 0)); p.addLine(to: CGPoint(x: 170, y: 120))
                }.stroke(Color.white.opacity(0.14), lineWidth: 6)
                Image(systemName: "mappin.circle.fill").font(.system(size: 34)).foregroundStyle(.white, Color.red)
                    .symbolRenderingMode(.palette)
            }
            .frame(height: 96).clipped().accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: place).font(CYTypography.bodyMedium).lineLimit(2)
                Text(verbatim: address).font(CYTypography.meta).opacity(0.72).lineLimit(2)
            }.padding(CYSpacing.md)
        }
        .foregroundStyle(isOwn ? CYChat.onSent : CYColor.textPrimary)
        .frame(width: 240, alignment: .leading).background(isOwn ? CYChat.sent : CYColor.bgRaised, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// Voice message: play circle, static waveform, duration.
struct E3VoiceCard: View {
    let duration: String
    var isOwn = false
    var played = false
    private let heights: [CGFloat] = [8, 14, 22, 12, 26, 18, 10, 24, 16, 28, 12, 20, 9, 15, 22, 11]
    var body: some View {
        HStack(spacing: CYSpacing.md) {
            Image(systemName: "play.fill").font(.subheadline).foregroundStyle(isOwn ? CYChat.sent : CYColor.textInverse)
                .frame(width: 36, height: 36).background(isOwn ? Color.white : CYColor.textPrimary, in: Circle())
            HStack(spacing: 3) {
                ForEach(Array(heights.enumerated()), id: \.offset) { i, h in
                    Capsule().frame(width: 3, height: h).opacity(i < (played ? 16 : 6) ? 1 : 0.4)
                }
            }.frame(height: 30).accessibilityHidden(true)
            Text(verbatim: duration).font(CYTypography.meta).monospacedDigit()
        }
        .foregroundStyle(isOwn ? CYChat.onSent : CYColor.textPrimary)
        .padding(.horizontal, CYSpacing.md).padding(.vertical, CYSpacing.sm + 2)
        .background(isOwn ? CYChat.sent : CYColor.bgRaised, in: Capsule())
        .accessibilityElement(children: .combine)
    }
}

/// File card: type tile, name, size.
struct E3FileCard: View {
    let name: String
    let size: String
    var kind = "doc.fill"
    var isOwn = false
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: CYSpacing.sm)) : AnyLayout(HStackLayout(spacing: CYSpacing.md))
        layout {
            Image(systemName: kind).font(.title3).foregroundStyle(isOwn ? CYChat.sent : CYColor.textInverse)
                .frame(width: 44, height: 44).background(isOwn ? Color.white : CYColor.textPrimary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: name).font(CYTypography.bodyMedium).fixedSize(horizontal: false, vertical: true)
                Text(verbatim: size).font(CYTypography.meta).opacity(0.72)
            }
            if !typeSize.isAccessibilitySize { Spacer(minLength: 0) }
            Image(systemName: "arrow.down.circle").font(.title3).opacity(0.8)
        }
        .foregroundStyle(isOwn ? CYChat.onSent : CYColor.textPrimary)
        .padding(CYSpacing.md).frame(maxWidth: 260)
        .background(isOwn ? CYChat.sent : CYColor.bgRaised, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// Video card: generated poster with play button and duration pill.
struct E3VideoCard: View {
    let seed: String
    let duration: String
    var body: some View {
        ZStack {
            CYCoverArt(seed: seed, systemImage: "film.fill", symbolSize: 44)
            LinearGradient(colors: [.clear, .black.opacity(0.45)], startPoint: .top, endPoint: .bottom)
            Image(systemName: "play.fill").font(.title3).foregroundStyle(.white)
                .frame(width: 52, height: 52).background(.black.opacity(0.45), in: Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.5), lineWidth: 1))
        }
        .frame(width: 240, height: 150)
        .overlay(alignment: .bottomTrailing) {
            Text(verbatim: duration).font(.caption.weight(.semibold)).monospacedDigit().foregroundStyle(.white)
                .padding(.horizontal, 8).padding(.vertical, 3).background(.black.opacity(0.55), in: Capsule()).padding(CYSpacing.sm)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Month grid (club calendar)

struct E3MonthGrid: View {
    let weekdays: [String]
    let daysInMonth: Int
    let firstWeekdayOffset: Int
    let eventDays: Set<Int>
    let today: Int
    @Binding var selected: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var cells: [Int?] { Array(repeating: nil, count: firstWeekdayOffset) + (1...daysInMonth).map { Optional($0) } }
    var body: some View {
        let cols = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
        VStack(spacing: CYSpacing.sm) {
            LazyVGrid(columns: cols, spacing: 0) {
                ForEach(weekdays, id: \.self) { Text(verbatim: $0).font(.caption.weight(.medium)).foregroundStyle(CYColor.textTertiary).frame(maxWidth: .infinity) }
            }
            LazyVGrid(columns: cols, spacing: 4) {
                ForEach(Array(cells.enumerated()), id: \.offset) { _, day in
                    if let day {
                        Button { withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.75)) { selected = day } } label: {
                            VStack(spacing: 3) {
                                Text(verbatim: "\(day)").font(.body.weight(selected == day || today == day ? .semibold : .regular)).monospacedDigit()
                                    .foregroundStyle(selected == day ? CYColor.textInverse : (today == day ? CYChat.sent : CYColor.textPrimary))
                                    .frame(width: 38, height: 38)
                                    .background(selected == day ? AnyShapeStyle(CYColor.textPrimary) : AnyShapeStyle(Color.clear), in: Circle())
                                Circle().fill(eventDays.contains(day) ? CYChat.sent : Color.clear).frame(width: 5, height: 5)
                            }
                            .frame(maxWidth: .infinity, minHeight: 48).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(verbatim: "\(day)" + (eventDays.contains(day) ? " •" : "")))
                        .accessibilityAddTraits(selected == day ? .isSelected : [])
                    } else { Color.clear.frame(height: 48) }
                }
            }
        }
        .sensoryFeedback(.selection, trigger: selected)
    }
}

// MARK: - Post card (photo-led)

struct E3PostCard: View {
    let author: String
    let club: String
    let time: String
    let text: String
    let coverSeed: String
    var coverSymbol = "photo.fill"
    let likes: Int?
    let comments: Int?
    @State private var liked = false
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: CYSpacing.sm) {
                E3Avatar(seed: author, size: 36)
                VStack(alignment: .leading, spacing: 0) {
                    Text(verbatim: author).font(CYTypography.bodyMedium).foregroundStyle(CYColor.textPrimary)
                    Text(verbatim: club + " · " + time).font(CYTypography.caption).foregroundStyle(CYColor.textTertiary).lineLimit(1)
                }
                Spacer(minLength: 0)
            }.padding(CYSpacing.md)
            CYCoverArt(seed: coverSeed, systemImage: coverSymbol, symbolSize: 54)
                .aspectRatio(4.0 / 3.0, contentMode: .fit).frame(maxWidth: .infinity).clipped()
            Text(verbatim: text).font(.body).foregroundStyle(CYColor.textPrimary).lineLimit(4)
                .padding(.horizontal, CYSpacing.md).padding(.top, CYSpacing.md)
            HStack(spacing: CYSpacing.xl) {
                Button { liked.toggle() } label: {
                    Label { Text(verbatim: count(likes)).monospacedDigit() } icon: { Image(systemName: liked ? "heart.fill" : "heart").symbolEffect(.bounce, value: liked) }
                        .foregroundStyle(liked ? Color.red : CYColor.textSecondary)
                }.buttonStyle(E3PressStyle()).sensoryFeedback(.impact(weight: .light), trigger: liked)
                Label { Text(verbatim: count(comments)).monospacedDigit() } icon: { Image(systemName: "bubble.left") }.foregroundStyle(CYColor.textSecondary)
                Spacer(minLength: 0)
            }
            .font(CYTypography.meta).padding(CYSpacing.md).frame(minHeight: 44)
        }
        .background(CYColor.bgElevated, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
    /// Unknown counts show an em dash, never 0.
    private func count(_ v: Int?) -> String { v.map(String.init) ?? "—" }
}

/// Section title used across social pages.
struct E3SectionTitle: View {
    let title: String
    var trailing: String? = nil
    var body: some View {
        HStack {
            Text(verbatim: title).font(.title3.weight(.semibold)).foregroundStyle(CYColor.textPrimary).accessibilityAddTraits(.isHeader)
            Spacer()
            if let trailing { Text(verbatim: trailing).font(CYTypography.meta).foregroundStyle(CYColor.textTertiary) }
        }
    }
}

/// Elevated card surface (#1C1C1E on #000), continuous 22 radius.
extension View {
    func e3Card(padding: CGFloat = CYSpacing.lg) -> some View {
        self.padding(padding).frame(maxWidth: .infinity, alignment: .leading)
            .background(CYColor.bgElevated, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
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
                    Text(verbatim: locale.pick("调试示例 · 合成数据", "DEBUG fixture · synthetic data")).font(.caption2).foregroundStyle(CYColor.textTertiary)
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
                        CYCoverArt(seed: "E3 Night Walkers", systemImage: "moon.stars.fill", symbolSize: 72)
                            .frame(height: 300).frame(maxWidth: .infinity).clipped()
                        LinearGradient(stops: [.init(color: .clear, location: 0.35), .init(color: .black, location: 1)], startPoint: .top, endPoint: .bottom)
                        VStack(alignment: .leading, spacing: CYSpacing.sm) {
                            CYStatusChip(verbatim: t("公开加入", "Open to join"), tone: .success, systemImage: "checkmark.circle")
                            Text(verbatim: t("夜行者俱乐部", "Night Walkers")).font(.largeTitle.weight(.bold)).foregroundStyle(.white).lineLimit(3)
                            Text(verbatim: t("每周三晚，漫步老城区的灯与影。", "Wednesday evenings, strolling the lights and shadows of the old town.")).font(CYTypography.body).foregroundStyle(.white.opacity(0.85))
                        }.padding(CYSpacing.lg)
                    }
                    .frame(maxWidth: .infinity)
                    VStack(alignment: .leading, spacing: CYSpacing.lg) {
                        HStack(spacing: CYSpacing.md) {
                            E3AvatarStack(seeds: ["a1", "b2", "c3", "d4", "e5"], extra: 123)
                            Text(verbatim: t("128 位成员 · 本周 3 场活动", "128 members · 3 events this week")).font(CYTypography.meta).foregroundStyle(CYColor.textSecondary).lineLimit(2)
                        }
                        Picker("", selection: $tab) {
                            Text(verbatim: t("动态", "Posts")).tag(0); Text(verbatim: t("活动", "Events")).tag(1); Text(verbatim: t("关于", "About")).tag(2)
                        }.pickerStyle(.segmented)
                        if tab == 0 {
                            E3PostCard(author: t("林夏", "Lin Xia"), club: t("夜行者", "Night Walkers"), time: t("2 小时前", "2h ago"), text: t("今晚的老城巷子太美了，霓虹和雨刚刚好。", "The old-town alleys tonight were perfect, neon and rain."), coverSeed: "alley", likes: 42, comments: 8)
                        } else if tab == 1 {
                            CYImageCard(verbatim: t("周三夜行：老城灯影", "Wednesday walk: old-town lights"), fallback: "", meta: t("周三 19:30 · 钟楼广场", "Wed 7:30 PM · Clock Tower Square"), aspectRatio: 16.0 / 10.0, style: .hero)
                        } else {
                            Text(verbatim: t("一群喜欢夜晚散步、拍照、收集街头故事的人。新人随时欢迎，无需经验。", "People who love evening walks, photography and collecting street stories. Newcomers welcome, no experience needed.")).font(CYTypography.body).foregroundStyle(CYColor.textSecondary).e3Card()
                        }
                    }.padding(.horizontal, CYSpacing.lg)
                    Text(verbatim: t("调试示例 · 合成数据", "DEBUG fixture · synthetic data")).font(.caption2).foregroundStyle(CYColor.textTertiary).frame(maxWidth: .infinity)
                }
            }
            .ignoresSafeArea(edges: .top)
            .background(CYColor.bgPage.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                Button { withAnimation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.65)) { joined.toggle() } } label: {
                    Label(joined ? t("已加入", "Joined") : t("加入俱乐部", "Join club"), systemImage: joined ? "checkmark.circle.fill" : "plus")
                        .font(.headline).symbolEffect(.bounce, value: joined)
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
                CYCoverArt(seed: name.isEmpty ? "new club" : name, systemImage: "sparkles", symbolSize: 56)
                    .frame(height: 180).frame(maxWidth: .infinity).clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                Label(t("更换封面", "Change cover"), systemImage: "photo").font(.footnote.weight(.semibold)).foregroundStyle(.white)
                    .padding(.horizontal, 12).frame(minHeight: 36).background(.black.opacity(0.5), in: Capsule()).padding(CYSpacing.md)
            }
            VStack(alignment: .leading, spacing: CYSpacing.md) {
                E3SectionTitle(title: t("基本信息", "Basics"))
                TextField(t("俱乐部名称", "Club name"), text: $name).padding(CYSpacing.md).frame(minHeight: 52)
                    .background(CYColor.bgElevated, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                TextField(t("一句话介绍", "One-line pitch"), text: $about, axis: .vertical).lineLimit(2...4).padding(CYSpacing.md).frame(minHeight: 52)
                    .background(CYColor.bgElevated, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            VStack(alignment: .leading, spacing: CYSpacing.md) {
                E3SectionTitle(title: t("类型", "Category"))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: CYSpacing.sm) {
                        ForEach(Array(cats.enumerated()), id: \.offset) { i, c in
                            Button { category = i } label: {
                                Text(verbatim: c).font(.subheadline.weight(.medium)).padding(.horizontal, 16).frame(minHeight: 44)
                                    .foregroundStyle(category == i ? CYColor.textInverse : CYColor.textPrimary)
                                    .background(category == i ? CYColor.textPrimary : CYColor.bgElevated, in: Capsule())
                            }.buttonStyle(E3PressStyle()).accessibilityAddTraits(category == i ? .isSelected : [])
                        }
                    }
                }.sensoryFeedback(.selection, trigger: category)
            }
            Toggle(isOn: $agree) { Text(verbatim: t("我已阅读并同意社区规则", "I have read and agree to the community rules")).font(CYTypography.meta).foregroundStyle(CYColor.textSecondary) }
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
                    CYCoverArt(seed: e.3, systemImage: "figure.walk", symbolSize: 22).frame(width: 64, height: 64).clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(verbatim: e.0).font(CYTypography.bodyMedium).foregroundStyle(CYColor.textPrimary).lineLimit(2)
                        Text(verbatim: e.1 + " · " + e.2).font(CYTypography.meta).foregroundStyle(CYColor.textTertiary).lineLimit(2)
                        E3AvatarStack(seeds: ["x", "y", "z"], extra: 9, size: 22)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(CYColor.textTertiary)
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
                                .overlay(Circle().strokeBorder(AngularGradient(colors: [.orange, .pink, .purple, .orange], center: .center), lineWidth: 2.5))
                            Text(verbatim: n).font(.caption).foregroundStyle(CYColor.textSecondary).lineLimit(1).frame(width: 72)
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
                    Text(verbatim: t("今天 19:24", "Today 7:24 PM")).font(.caption).foregroundStyle(CYColor.textTertiary).padding(.vertical, CYSpacing.sm)
                    row(false, "u1", .first, t("到了吗？", "Are you there yet?"))
                    row(false, "u1", .last, t("我在钟楼下面，给你发位置", "I'm under the clock tower, sending the pin"), time: "19:24")
                    HStack(alignment: .bottom, spacing: 8) { Color.clear.frame(width: 28, height: 1); E3LocationCard(place: t("钟楼广场", "Clock Tower Square"), address: t("老城区 中山路 1 号", "1 Zhongshan Rd, Old Town")); Spacer(minLength: 0) }.padding(.top, 6)
                    row(true, "me", .first, t("马上，3 分钟", "Almost, 3 minutes"))
                    row(true, "me", .last, t("先听这个", "Listen to this first"), time: "19:26")
                    HStack { Spacer(); E3VoiceCard(duration: "0:18", isOwn: true) }.padding(.top, 6)
                    HStack(alignment: .bottom, spacing: 8) { E3Avatar(seed: "u1", size: 28); E3FileCard(name: t("夜行路线.pdf", "night-route.pdf"), size: "1.2 MB"); Spacer(minLength: 0) }.padding(.top, 10)
                    HStack(alignment: .bottom, spacing: 8) { E3Avatar(seed: "u1", size: 28); E3VideoCard(seed: "vid", duration: "0:42"); Spacer(minLength: 0) }.padding(.top, 6)
                    Text(verbatim: t("调试示例 · 合成数据", "DEBUG fixture · synthetic data")).font(.caption2).foregroundStyle(CYColor.textTertiary).padding(.top, CYSpacing.lg)
                }.padding(.horizontal, CYSpacing.lg)
            }
            .defaultScrollAnchor(.bottom)
            .background(CYColor.bgPage.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) { composer(t) }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) { E3Avatar(seed: "u1", size: 28); VStack(alignment: .leading, spacing: 0) { Text(verbatim: t("林夏", "Lin Xia")).font(.headline); Text(verbatim: t("在线", "Online")).font(.caption2).foregroundStyle(.green) } }
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
            Image(systemName: "plus").font(.title3.weight(.medium)).frame(width: 44, height: 44).foregroundStyle(CYColor.textSecondary)
            HStack(spacing: 4) {
                TextField(t("发消息…", "Message"), text: $draft).padding(.leading, 16).frame(minHeight: 44)
                let live = !draft.isEmpty
                Image(systemName: "arrow.up").font(.subheadline.weight(.bold)).foregroundStyle(live ? Color.white : Color.secondary)
                    .frame(width: 32, height: 32).background(live ? CYChat.sent : Color.secondary.opacity(0.25), in: Circle()).padding(.trailing, 6)
            }
            .background(CYColor.bgRaised, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
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
                        CYCoverArt(seed: "coop invite", systemImage: "handshake.fill", symbolSize: 52).frame(height: 170)
                        LinearGradient(colors: [.clear, .black.opacity(0.8)], startPoint: .top, endPoint: .bottom)
                        VStack(alignment: .leading, spacing: 6) {
                            CYStatusChip(verbatim: accepted ? t("已接受", "Accepted") : t("待回复", "Awaiting reply"), tone: accepted ? .success : .warning, systemImage: accepted ? "checkmark.circle" : "clock")
                            Text(verbatim: t("河畔咖啡 × 夜行者", "Riverside Café × Night Walkers")).font(.title.weight(.bold)).foregroundStyle(.white)
                        }.padding(CYSpacing.lg)
                    }.clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    VStack(alignment: .leading, spacing: CYSpacing.md) {
                        E3SectionTitle(title: t("合作条款", "Terms"))
                        term("percent", t("分成", "Revenue share"), t("商家 70% · 俱乐部 30%", "Venue 70% · Club 30%"))
                        Divider().overlay(CYColor.borderSubtle)
                        term("calendar", t("有效期至", "Valid until"), "2026-12-31")
                        Divider().overlay(CYColor.borderSubtle)
                        term("lock.shield", t("押金", "Deposit"), "—")
                    }.e3Card()
                    VStack(alignment: .leading, spacing: 6) {
                        Text(verbatim: t("对方留言", "Their message")).font(CYTypography.caption).foregroundStyle(CYColor.textTertiary)
                        Text(verbatim: t("希望每周三晚上在我们店做一场夜行集合。", "We'd love to host a Wednesday night walk meet-up at our café.")).font(CYTypography.body).foregroundStyle(CYColor.textPrimary)
                    }.e3Card()
                    Text(verbatim: t("调试示例 · 合成数据", "DEBUG fixture · synthetic data")).font(.caption2).foregroundStyle(CYColor.textTertiary).frame(maxWidth: .infinity)
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
            Text(verbatim: k).font(CYTypography.meta).foregroundStyle(CYColor.textTertiary)
            if !typeSize.isAccessibilitySize { Spacer(minLength: CYSpacing.sm) }
            Text(verbatim: v).font(CYTypography.bodyMedium).foregroundStyle(CYColor.textPrimary).multilineTextAlignment(typeSize.isAccessibilitySize ? .leading : .trailing)
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
                        Text(verbatim: n).font(.subheadline.weight(.medium)).padding(.horizontal, 14).frame(minHeight: 44).fixedSize()
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
                Image(systemName: "magnifyingglass").foregroundStyle(CYColor.textTertiary)
                Text(verbatim: t("搜索昵称", "Search by name")).foregroundStyle(CYColor.textPlaceholder)
                Spacer()
            }.font(.body).padding(.horizontal, CYSpacing.md).frame(minHeight: 44).background(CYColor.bgElevated, in: Capsule())
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
#endif
