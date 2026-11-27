import SwiftUI

struct ClubName: View {
    let value: String
    var body: some View {
        if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { Text("club.untitled") }
        else { Text(verbatim: value) }
    }
}

/// Shared club list thumbnail (club home rows and the club directory): logo or cover over the system fill,
/// a person.3 glyph while the image loads or when there is none. One size and radius for every club list.
struct ClubRowThumbnail: View {
    let url: URL?

    var body: some View {
        ZStack {
            Image(systemName: "person.3.fill").foregroundStyle(.secondary)
            if let url {
                PlayerFeedRemoteImage(url: url, maxPixel: 168, placeholder: { Color.clear }, failure: { Color.clear })
            }
        }
        .frame(width: 48, height: 48)
        .background(.fill.tertiary)
        .clipShape(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
        .accessibilityHidden(true)
    }
}

/// Member-count grammar follows the selected UI locale, without changing source counts.
/// Both supported languages share the exactly-one selection; their words remain in the catalog.
enum ClubMemberCountLocalization {
    static func resource(_ count: Int, locale: Locale) -> LocalizedStringResource {
        if count == 1 {
            return LocalizedStringResource("club.memberCount.singular \(count)", locale: locale)
        }
        return LocalizedStringResource("club.memberCount \(count)", locale: locale)
    }

    static func text(_ count: Int, locale: Locale) -> String {
        String(localized: resource(count, locale: locale))
    }
}

/// Club list row (native): logo thumbnail, name, type · city, member count, and the viewer's status as secondary text.
/// The whole row is the link when the caller wraps it in a `NavigationLink`.
struct ClubRow: View {
    let club: ClubRecord
    @Environment(\.locale) private var locale
    @ScaledMetric(relativeTo: .body) private var logoSide: CGFloat = 44
    private var subtitle: String {
        [club.style, club.city].compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }.joined(separator: " · ")
    }
    var body: some View {
        LabeledContent {
            statusPill
        } label: {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    ClubName(value: club.name)
                        .font(.headline)
                    if !subtitle.isEmpty {
                        Text(verbatim: subtitle).font(.subheadline).foregroundStyle(.secondary)
                    }
                    Text(verbatim: ClubMemberCountLocalization.text(club.memberCount, locale: locale)).monospacedDigit()
                        .font(.footnote).foregroundStyle(.secondary)
                    if let host = club.leaderName?.trimmingCharacters(in: .whitespacesAndNewlines), !host.isEmpty {
                        Label { Text(verbatim: host).lineLimit(1) } icon: { Image(systemName: "person.crop.circle") }
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
            } icon: {
                logo
            }
        }
        .accessibilityElement(children: .combine)
    }
    /// The club's logo, else its cover, else a symbol: a small rounded thumbnail like Apple's own list rows.
    @ViewBuilder private var logo: some View {
        Group {
            if let url = QuestifyCardArtwork.safeURL(club.logo) ?? QuestifyCardArtwork.safeURL(club.cover) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image { image.resizable().scaledToFill() }
                    else { Image(systemName: "person.3.fill").foregroundStyle(.secondary) }
                }
            } else {
                Image(systemName: "person.3.fill").foregroundStyle(.secondary)
            }
        }
        .frame(width: logoSide, height: logoSide)
        .background(.fill.tertiary)
        .clipShape(RoundedRectangle(cornerRadius: CYRadius.inner, style: .continuous))
        .accessibilityHidden(true)
    }
    @ViewBuilder private var statusPill: some View {
        let key: LocalizedStringKey = club.isOwner ? "club.role.creator" : club.isJoined ? "club.membership.joined"
            : club.joinPending ? "club.membership.pending" : "club.action.join"
        let primary = !(club.isOwner || club.isJoined || club.joinPending)
        // i18n r1: "Waiting for the host to approve" is far longer than 等待主理人审核; wrap to two lines.
        Text(key).font(.subheadline).lineLimit(2).multilineTextAlignment(.trailing)
            .fixedSize(horizontal: false, vertical: true)
            .foregroundStyle(primary ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
    }
}

struct ClubOptionalRow: View {
    let title: LocalizedStringKey
    let value: String?
    var body: some View {
        if let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            LabeledContent(title) { Text(verbatim: value).textSelection(.enabled) }
        }
    }
}

struct ClubEmptyState: View {
    let title: LocalizedStringKey
    let hint: LocalizedStringKey
    let identifier: String
    var body: some View {
        ContentUnavailableView {
            Label { Text(title).accessibilityIdentifier(identifier) } icon: { Image(systemName: "person.3") }
        } description: {
            Text(hint)
        }
    }
}


// MARK: - Social kit (moved from DEBUG fixtures; presentation only)
// Social surface kit (e3): player-dark cards, avatars, follow states, rich chat cards, month grid, post cards.
// Presentation only: every view takes plain values / closures; no reads, writes or authority live here.
// Motion is spring-based and gated on Reduce Motion; haptics use sensoryFeedback.

struct E3Avatar: View {
    let seed: String
    var systemImage = "person.fill"
    var size: CGFloat = 44
    var body: some View {
        CYIMCoverArt(seed: seed, systemImage: systemImage, symbolSize: size * 0.42)
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
                // "+N" chip: never a truncated number. The chip widens into a capsule for 3+ digits and scales its text.
                Text(verbatim: "+\(extra)").cyText(.meta, weight: .semibold).monospacedDigit()
                    .lineLimit(1).minimumScaleFactor(0.6).fixedSize(horizontal: true, vertical: false)
                    .foregroundStyle(CYColor.textPrimary)
                    .padding(.horizontal, extra >= 100 ? 6 : 0)
                    .frame(minWidth: size, minHeight: size)
                    .background(CYColor.bgRaised, in: Capsule())
                    .overlay(Capsule().strokeBorder(CYColor.bgPage, lineWidth: 2))
                    .zIndex(0)
            }
        }
    }
}

enum E3FollowState { case follow, following, requested, mutual }

/// Follow button (native-a r3): the system capsule button, `.borderedProminent` for the action (关注 / Follow) and
/// `.bordered` once following / requested / mutual. The system draws fill, press, disabled and Dynamic Type.
struct E3FollowButton: View {
    let state: E3FollowState
    let title: String
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        Group {
            if state == .follow {
                button.buttonStyle(.borderedProminent)
            } else {
                button.buttonStyle(.bordered)
            }
        }
        .buttonBorderShape(.capsule)
        .sensoryFeedback(.success, trigger: state)
        .animation(reduceMotion ? nil : .snappy(duration: 0.25), value: state)
    }

    private var button: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if state == .following || state == .mutual { Image(systemName: state == .mutual ? "arrow.left.arrow.right" : "checkmark") }
                if state == .requested { Image(systemName: "clock") }
                Text(verbatim: title).lineLimit(1).minimumScaleFactor(0.8)
            }
        }
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
            Text(verbatim: name).cyText(.bodyMedium).foregroundStyle(CYColor.textPrimary).fixedSize(horizontal: false, vertical: true)
            Text(verbatim: meta).cyText(.meta).foregroundStyle(CYColor.textTertiary).fixedSize(horizontal: false, vertical: true)
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
                .frame(width: 44, height: 44).background(tint.opacity(0.16), in: RoundedRectangle(cornerRadius: CYRadius.card, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(verbatim: title).cyText(.bodyMedium).foregroundStyle(CYColor.textPrimary)
                Text(verbatim: detail).cyText(.meta).foregroundStyle(CYColor.textSecondary)
                Text(verbatim: time).cyText(.caption).foregroundStyle(CYColor.textTertiary)
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
                Rectangle().fill(.fill.tertiary)
                Image(systemName: "mappin.circle.fill").cyText(.dataXL).foregroundStyle(.white, Color.red)
                    .symbolRenderingMode(.palette)
            }
            .frame(height: 96).clipped().accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: place).cyText(.bodyMedium).lineLimit(2)
                Text(verbatim: address).cyText(.meta).opacity(0.72).lineLimit(2)
            }.padding(CYSpacing.md)
        }
        .foregroundStyle(isOwn ? CYChat.onSent : CYColor.textPrimary)
        .frame(width: 240, alignment: .leading).background(isOwn ? CYChat.sent : CYColor.bgRaised, in: RoundedRectangle(cornerRadius: CYRadius.hero, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: CYRadius.hero, style: .continuous))
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
            Text(verbatim: duration).cyText(.meta).monospacedDigit()
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
                .frame(width: 44, height: 44).background(isOwn ? Color.white : CYColor.textPrimary, in: RoundedRectangle(cornerRadius: CYRadius.card, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: name).cyText(.bodyMedium).fixedSize(horizontal: false, vertical: true)
                Text(verbatim: size).cyText(.meta).opacity(0.72)
            }
            if !typeSize.isAccessibilitySize { Spacer(minLength: 0) }
            Image(systemName: "arrow.down.circle").font(.title3).opacity(0.8)
        }
        .foregroundStyle(isOwn ? CYChat.onSent : CYColor.textPrimary)
        .padding(CYSpacing.md).frame(maxWidth: typeSize.isAccessibilitySize ? 340 : 260, alignment: .leading)
        .background(isOwn ? CYChat.sent : CYColor.bgRaised, in: RoundedRectangle(cornerRadius: CYRadius.hero, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// Video card: generated poster with play button and duration pill.
struct E3VideoCard: View {
    let seed: String
    let duration: String
    var body: some View {
        ZStack {
            CYIMCoverArt(seed: seed, systemImage: "film.fill", symbolSize: 44)
            // native-a r3: media controls on a dark system material (as Photos / TV), not a hand-tinted black disc.
            Image(systemName: "play.fill").accessibilityLabel(Text(verbatim: "Play")).font(.title3).foregroundStyle(.white)
                .frame(width: 52, height: 52).background(.ultraThinMaterial, in: Circle())
                .environment(\.colorScheme, .dark)
        }
        .frame(width: 240, height: 150)
        .overlay(alignment: .bottomTrailing) {
            Text(verbatim: duration).cyText(.meta, weight: .semibold).monospacedDigit().foregroundStyle(.white)
                .padding(.horizontal, 8).padding(.vertical, 3).background(.ultraThinMaterial, in: Capsule())
                .environment(\.colorScheme, .dark).padding(CYSpacing.sm)
        }
        .clipShape(RoundedRectangle(cornerRadius: CYRadius.hero, style: .continuous))
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
                ForEach(weekdays, id: \.self) { Text(verbatim: $0).cyText(.label).foregroundStyle(CYColor.textTertiary).frame(maxWidth: .infinity) }
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
        // a11y-dt r3: seven fixed day circles cannot grow to AX sizes without clipping the numbers (as in Calendar's
        // month grid); the grid stops at xxxLarge and each day still speaks its full label to VoiceOver.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
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
                    Text(verbatim: author).cyText(.bodyMedium).foregroundStyle(CYColor.textPrimary)
                    Text(verbatim: club + " · " + time).cyText(.caption).foregroundStyle(CYColor.textTertiary).lineLimit(1)
                }
                Spacer(minLength: 0)
            }.padding(CYSpacing.md)
            CYIMCoverArt(seed: coverSeed, systemImage: coverSymbol, symbolSize: 54)
                .aspectRatio(4.0 / 3.0, contentMode: .fit).frame(maxWidth: .infinity).clipped()
            Text(verbatim: text).cyText(.body).foregroundStyle(CYColor.textPrimary).lineLimit(4)
                .padding(.horizontal, CYSpacing.md).padding(.top, CYSpacing.md)
            HStack(spacing: CYSpacing.xl) {
                Button { liked.toggle() } label: {
                    Label { Text(verbatim: count(likes)).monospacedDigit() } icon: { Image(systemName: liked ? "heart.fill" : "heart").symbolEffect(.bounce, value: liked) }
                        .foregroundStyle(liked ? Color.red : CYColor.textSecondary)
                }.buttonStyle(.borderless).sensoryFeedback(.impact(weight: .light), trigger: liked)
                Label { Text(verbatim: count(comments)).monospacedDigit() } icon: { Image(systemName: "bubble.left") }.foregroundStyle(CYColor.textSecondary)
                Spacer(minLength: 0)
            }
            .cyText(.meta).padding(CYSpacing.md).frame(minHeight: 44)
        }
        .background(CYColor.bgElevated, in: RoundedRectangle(cornerRadius: CYRadius.card, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: CYRadius.card, style: .continuous))
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
            Text(verbatim: title).cyText(.sectionTitle).foregroundStyle(CYColor.textPrimary).accessibilityAddTraits(.isHeader)
            Spacer()
            if let trailing { Text(verbatim: trailing).cyText(.meta).foregroundStyle(CYColor.textTertiary) }
        }
    }
}

/// Elevated card surface (`CYColor.bgElevated` on `CYColor.bgPage`), continuous radius 12 (native card style).
extension View {
    func e3Card(padding: CGFloat = CYSpacing.lg) -> some View {
        self.padding(padding).frame(maxWidth: .infinity, alignment: .leading)
            .background(CYColor.bgElevated, in: RoundedRectangle(cornerRadius: CYRadius.card, style: .continuous))
    }
}
