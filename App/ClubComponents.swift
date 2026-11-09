import SwiftUI

struct ClubName: View {
    let value: String
    var body: some View {
        if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { Text("club.untitled") }
        else { Text(verbatim: value) }
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

/// Mini-program club card (P/021, M/003): quiet cover banner, logo, heavy name,
/// type · city, counts, and one trailing pill. The whole card is the link.
struct ClubRow: View {
    let club: ClubRecord
    @Environment(\.locale) private var locale
    @Environment(\.cyPalette) private var palette
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private var subtitle: String {
        [club.style, club.city].compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }.joined(separator: " · ")
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                palette.bgSurfaceSubtle
                if let url = QuestifyCardArtwork.safeURL(club.cover) {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image { image.resizable().scaledToFill() } else { glyph }
                    }
                } else { glyph }
            }
            .frame(height: 112).frame(maxWidth: .infinity).clipped().accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 8) {
                logo.padding(.top, -34)
                Group {
                    if club.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { Text("club.untitled") }
                    else { Text(verbatim: club.name) }
                }
                .font(.title3.weight(.heavy)).foregroundStyle(palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                if !subtitle.isEmpty {
                    Text(verbatim: subtitle).font(.subheadline).foregroundStyle(palette.textSecondary)
                }
                Label { Text(verbatim: ClubMemberCountLocalization.text(club.memberCount, locale: locale)).monospacedDigit() }
                    icon: { Image(systemName: "person.2") }
                    .font(.footnote).foregroundStyle(palette.textTertiary)
                (dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout(spacing: 8))) {
                    if let host = club.leaderName?.trimmingCharacters(in: .whitespacesAndNewlines), !host.isEmpty {
                        HStack(spacing: 8) {
                            Text(verbatim: String(host.prefix(1))).font(.caption.weight(.bold))
                                .frame(width: 28, height: 28).background(palette.bgRaised, in: Circle())
                            Text(verbatim: host).font(.footnote.weight(.semibold)).lineLimit(1)
                        }
                        .foregroundStyle(palette.textPrimary)
                        .padding(8).frame(maxWidth: .infinity, alignment: .leading)
                        .background(palette.bgSurfaceSubtle, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    } else { Spacer(minLength: 0) }
                    statusPill
                }
            }
            .padding(.horizontal, 16).padding(.bottom, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(palette.cardFill)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(palette.borderSubtle, lineWidth: 0.5))
        .shadow(color: .black.opacity(0.35), radius: 10, y: 4)
        .accessibilityElement(children: .combine)
    }
    private var glyph: some View {
        CYIMCoverArt(seed: club.name + String(club.id))
    }
    @ViewBuilder private var logo: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        ZStack {
            palette.bgRaised
            if let url = QuestifyCardArtwork.safeURL(club.logo) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image { image.resizable().scaledToFill() }
                    else { Image(systemName: "person.3.fill").foregroundStyle(palette.textTertiary) }
                }
            } else { Image(systemName: "person.3.fill").foregroundStyle(palette.textTertiary) }
        }
        .frame(width: 56, height: 56).clipShape(shape)
        .overlay(shape.strokeBorder(palette.cardFill, lineWidth: 3))
        .accessibilityHidden(true)
    }
    @ViewBuilder private var statusPill: some View {
        let key: LocalizedStringKey = club.isOwner ? "club.role.creator" : club.isJoined ? "club.membership.joined"
            : club.joinPending ? "club.membership.pending" : "club.action.join"
        let primary = !(club.isOwner || club.isJoined || club.joinPending)
        Text(key).font(.subheadline.weight(.bold)).lineLimit(1)
            .padding(.horizontal, 16).frame(minHeight: 40)
            .foregroundStyle(primary ? palette.actionPrimaryFg : palette.textPrimary)
            .background(primary ? palette.actionPrimaryBg : palette.bgRaised, in: Capsule())
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
        } description: { Text(hint) }
    }
}
