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
    @ScaledMetric(relativeTo: .headline) private var avatarSide: CGFloat = 48
    @Environment(\.locale) private var locale
    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.lg) {
            HStack(alignment: .top, spacing: CYSpacing.md) {
                avatar
                VStack(alignment: .leading, spacing: CYSpacing.xs) {
                    Group {
                        if let nickname = post.nickname { Text(verbatim: nickname) }
                        else { Text("square.unknownAuthor") }
                    }
                    .font(.headline)
                    // Keep the post anchor on a leaf, so time and source-club
                    // controls retain their independently addressable IDs.
                    .accessibilityIdentifier("club.feed.post.\(post.id)")
                    if let time = post.createTime {
                        Text(verbatim: LocaleDisplay.civil(time, locale: locale))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("club.feed.time.\(post.id)")
                    }
                }
            }
            if let content = post.content {
                Text(verbatim: content)
                    .textSelection(.enabled)
            }
            if !post.images.isEmpty {
                NativeMediaGalleryEntry(sources: post.images, scope: mediaScope, reader: imageReader)
                    .accessibilityIdentifier("club.feed.images.\(post.id)")
            }
            if let openClub {
                Button(action: openClub) { sourceClub }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.primary)
                    .accessibilityIdentifier("club.feed.source.\(post.id)")
            } else if post.clubName != nil { sourceClub }
        }
        .padding(.vertical, CYSpacing.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
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
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Group {
                if let name = post.clubName { Text(verbatim: name) }
                else { Text("club.detail") }
            }
            .font(.subheadline)
            Spacer(minLength: CYSpacing.sm)
            if openClub != nil {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
        .frame(minHeight: CYSpacing.minTouchTarget, alignment: .leading)
        .contentShape(Rectangle())
    }
}
