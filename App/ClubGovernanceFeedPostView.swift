import SwiftUI

struct ClubGovernanceFeedContext {
    var viewerRevision: UInt64 = 0
    var readerIdentity: ObjectIdentifier? = nil
    var destination: ((Int) -> AnyView)? = nil
    var imageReader: (any RetainedPublicImageReading)? = nil
}
private struct ClubGovernanceFeedKey: EnvironmentKey {
    static let defaultValue = ClubGovernanceFeedContext()
}
extension EnvironmentValues {
    var clubGovernanceFeed: ClubGovernanceFeedContext {
        get { self[ClubGovernanceFeedKey.self] }
        set { self[ClubGovernanceFeedKey.self] = newValue }
    }
}

@MainActor struct ClubGovernanceFeedPostView: View {
    let post: ClubFeedPost
    let mediaScope: UUID
    let imageReader: any RetainedPublicImageReading
    var openClub: (() -> Void)? = nil
    @Environment(\.cyPalette) private var palette
    @ScaledMetric(relativeTo: .headline) private var avatarSide: CGFloat = 48
    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.lg) {
            HStack(alignment: .top, spacing: CYSpacing.md) {
                avatar
                VStack(alignment: .leading, spacing: CYSpacing.xs) {
                    Group {
                        if let nickname = post.nickname { Text(verbatim: nickname) }
                        else { Text("square.unknownAuthor") }
                    }
                    .cyText(.cardTitle)
                    .foregroundStyle(palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    // Keep the post anchor on a leaf, so time and source-club
                    // controls retain their independently addressable IDs.
                    .accessibilityIdentifier("club.feed.post.\(post.id)")
                    if let time = post.createTime {
                        Text(verbatim: time)
                            .cyText(.meta)
                            .foregroundStyle(palette.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("club.feed.time.\(post.id)")
                    }
                }
            }
            if let content = post.content {
                Text(verbatim: content)
                    .cyText(.body)
                    .foregroundStyle(palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
            if !post.images.isEmpty {
                NativeMediaGalleryEntry(sources: post.images, scope: mediaScope, reader: imageReader)
                    .accessibilityIdentifier("club.feed.images.\(post.id)")
            }
            if let openClub {
                Button(action: openClub) { sourceClub }
                    .buttonStyle(CYPressScaleStyle())
                    .accessibilityIdentifier("club.feed.source.\(post.id)")
            } else if post.clubName != nil { sourceClub }
        }
        .padding(CYSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.bgElevated, in: RoundedRectangle(cornerRadius: CYRadius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: CYRadius.card, style: .continuous).strokeBorder(palette.borderSubtle, lineWidth: 1))
        .fixedSize(horizontal: false, vertical: true)
        .listRowInsets(EdgeInsets(top: CYSpacing.sm, leading: CYSpacing.pageHorizontal, bottom: CYSpacing.sm, trailing: CYSpacing.pageHorizontal))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .id(mediaScope)
    }
    @ViewBuilder private var avatar: some View {
        if let avatar = post.avatar {
            NativeMediaImage(raw: avatar, reader: imageReader, zoomable: false)
                .frame(width: avatarSide, height: avatarSide)
                .clipShape(Circle())
                .accessibilityHidden(true)
        } else {
            CYCoverArt(seed: post.nickname ?? "club-feed-\(post.id)", symbol: "person.fill", showsDebugLabel: false)
                .frame(width: avatarSide, height: avatarSide)
                .clipShape(Circle())
                .accessibilityHidden(true)
        }
    }
    private var sourceClub: some View {
        HStack(spacing: CYSpacing.sm) {
            Image(systemName: "person.3")
                .foregroundStyle(palette.textSecondary)
                .accessibilityHidden(true)
            Group {
                if let name = post.clubName { Text(verbatim: name) }
                else { Text("club.detail") }
            }
            .cyText(.bodyCompact)
            .foregroundStyle(palette.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: CYSpacing.sm)
            if openClub != nil {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(palette.textTertiary)
                    .accessibilityHidden(true)
            }
        }
        .frame(minHeight: CYSpacing.minTouchTarget, alignment: .leading)
        .contentShape(Rectangle())
    }
}
