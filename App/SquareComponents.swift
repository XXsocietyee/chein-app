import SwiftUI

extension SquareFeedMode {
    var labelKey: LocalizedStringKey {
        switch self {
        case .latest: return "square.mode.latest"
        case .following: return "square.mode.following"
        case .nearby: return "square.mode.nearby"
        case .topic: return "square.mode.topic"
        case .community: return "square.mode.community"
        case .featured: return "square.mode.featured"
        case .trending: return "square.mode.trending"
        case .forYou: return "square.mode.forYou"
        }
    }
}
struct SquareIssueView: View {
    let error: Error
    var retry: (() -> Void)? = nil
    private var key: LocalizedStringKey {
        if error as? APIError == .notConfigured { return "square.notConfigured" }
        if error as? APIError == .unauthorized { return "square.unauthorized" }
        switch error as? SquareReadFailure {
        case .signInRequired: return "square.signInRequired"
        case .cityRequired: return "square.cityRequired"
        case .topicRequired: return "square.topicRequired"
        case .communityRequired: return "square.communityRequired"
        case .unavailable: return "square.unavailable"
        default: return "square.failed"
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(key, systemImage: "exclamationmark.circle").accessibilityIdentifier("square.error")
            if let failure = error as? SquareReadFailure, case let .server(_, message) = failure, let message, !message.isEmpty {
                // Backend messages remain verbatim, including unavailable/moderation responses.
                Text(verbatim: message).cyText(.meta).textSelection(.enabled)
            }
            if let retry { Button("square.retry", action: retry).accessibilityIdentifier("square.retry") }
        }
    }
}
struct SquareImage: View {
    let source: String
    var body: some View {
        if let url = URL(string: source), url.scheme == "https", url.host != nil, url.user == nil, url.password == nil {
            AsyncImage(url: url) { phase in
                if let image = phase.image { image.resizable().scaledToFit() }
                else if phase.error != nil { Label("square.imageUnavailable", systemImage: "photo.badge.exclamationmark") }
                else { ProgressView("square.imageLoading") }
            }.frame(maxWidth: .infinity, maxHeight: 240)
                .accessibilityLabel(Text("square.postImage"))
        } else {
            // Source media can contain object keys. No storage host or signed URL is invented.
            Label("square.imageUnavailable", systemImage: "photo")
        }
    }
}
struct SquarePostContent: View {
    let post: SquarePost
    var compact = false
    var showImages = true
    var mediaScope: UUID = UUID()
    /// The detail page shows likes and comments in its action row instead.
    var showsCounts = true
    /// Mini `ph-avatar` T5 capsule (follow / visit profile). Empty keeps the avatar a plain image.
    var avatarMenuItems: [CYAnchoredMenuItem] = []
    var onAvatarPick: ((String) -> Void)? = nil
    /// MP square/detail `.gz` 关注 at the end of the post head (C-S8). Nil hides it; only the detail page passes it.
    var onFollow: (() -> Void)? = nil
    @State private var avatarMenuShown = false
    private static let disclosures: Set<String> = ["SPONSORED", "GIFTED", "MERCHANT_OWNER", "MERCHANT_EMPLOYEE"]
    /// Mini-program `post-head`: avatar, name, time; then the text, media and the post's own facts.
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                if avatarMenuItems.isEmpty || onAvatarPick == nil { SquareAuthorAvatar(source: post.avatar) }
                else {
                    Button { avatarMenuShown = true } label: { SquareAuthorAvatar(source: post.avatar) }
                        .buttonStyle(.cyPressable)
                        .frame(minWidth: CYSpacing.minTouchTarget, minHeight: CYSpacing.minTouchTarget)
                        .accessibilityLabel(Text("avatarMenu.open", tableName: "SocialParity"))
                        .accessibilityIdentifier("square.avatarMenu")
                        .cyAnchoredMenu(isPresented: $avatarMenuShown, items: avatarMenuItems) { onAvatarPick?($0) }
                }
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        if let name = post.nickname, !name.isEmpty { Text(verbatim: name).cyText(.cardTitle) }
                        else { Text("square.unknownAuthor").cyText(.cardTitle) }
                        if post.verified {
                            Image(systemName: "checkmark.seal.fill").foregroundStyle(QuestifyPalette.accent)
                                .accessibilityLabel(Text("square.verified"))
                        }
                    }
                    if !post.createTime.isEmpty { SquareXcxRelativeTime(createTime: post.createTime, now: Date()).cyText(.meta).foregroundStyle(.secondary) }
                }
                Spacer(minLength: 0)
                if let onFollow {
                    Button("fixr3.square.follow", action: onFollow)
                        .buttonStyle(.bordered).buttonBorderShape(.capsule).controlSize(.small)
                        .frame(minHeight: CYSpacing.minTouchTarget)
                        .accessibilityIdentifier("square.detail.follow")
                }
            }
            if post.memberLevel > 0 || post.authorBadge != nil || post.noticeBadge != nil {
                HStack(spacing: 8) {
                    if post.memberLevel > 0 { Text("square.levelBadge \(post.memberLevel)") }
                    if let badge = post.authorBadge { Text(verbatim: badge) }
                    if let badge = post.noticeBadge { Text(verbatim: badge).bold() }
                }
                .cyText(.meta).foregroundStyle(.secondary)
            }
            if let contents = post.contents, !contents.isEmpty { Text(verbatim: contents).lineLimit(compact ? 3 : nil).textSelection(.enabled) }
            SquareCloudStravaSection(post: post)
            if showImages && !post.images.isEmpty {
                NativeMediaGalleryEntry(sources: post.images, scope: mediaScope, titleKey: "media.destination.squareImages", compact: compact)
            }
            if showImages && !compact, let routeImage = post.routeImage {
                NativeMediaGalleryEntry(sources: [routeImage], scope: mediaScope, titleKey: "media.destination.squareImages")
            }
            if let address = post.address, !address.isEmpty { Label { Text(verbatim: address) } icon: { Image(systemName: "mappin") }.font(.subheadline) }
            if let club = post.clubName { LabeledContent("square.club", value: club) }
            if let title = post.referenceTitle { LabeledContent("square.reference", value: title) }
            if post.nodeTotal > 0 {
                LabeledContent("square.routeProgress", value: "\(post.nodeDoneCount) / \(post.nodeTotal)")
            }
            if post.completed { Label("square.completed", systemImage: "checkmark.circle") }
            if showsCounts {
                HStack(spacing: 16) {
                    Label { Text(verbatim: SquareCountDisplay.text(post.likeCount)) } icon: { Image(systemName: post.isLiked == 1 ? "heart.fill" : "heart") }
                        .accessibilityLabel(post.likeCount.map { Text("square.xcx.likesA11y \($0)") } ?? Text(verbatim: SquareCountDisplay.unknownMark))
                    Label { Text(verbatim: SquareCountDisplay.text(post.commentCount)) } icon: { Image(systemName: "bubble.right") }
                        .accessibilityLabel(post.commentCount.map { Text("square.xcx.commentsA11y \($0)") } ?? Text(verbatim: SquareCountDisplay.unknownMark))
                }
                .font(.subheadline).foregroundStyle(.secondary)
            }
            if Self.disclosures.contains(post.disclosureType) {
                Label(LocalizedStringKey("squareWorkspace.policy." + post.disclosureType), systemImage: "info.circle").cyText(.meta)
            }
            ForEach(Array(post.safetyLabels.enumerated()), id: \.offset) { _, label in
                Label { SquareSafetyLabel(value: label) } icon: { Image(systemName: "exclamationmark.triangle") }
            }
        }
    }
}

/// Round author avatar; a plain symbol when the post carries none.
struct SquareAuthorAvatar: View {
    let source: String?
    var size: CGFloat = 40
    var body: some View {
        Group {
            if let url = QuestifyCardArtwork.safeURL(source) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image { image.resizable().scaledToFill() } else { fallback }
                }
            } else { fallback }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }
    private var fallback: some View {
        // MP `/images/d_profile.png` is the avatar default on square posts and comments.
        MPAsset.AvatarDefault.dProfile.resizable().scaledToFill()
    }
}

struct SquareSafetyLabel: View {
    let value: String
    private var key: LocalizedStringKey? {
        switch value {
        case "DANGEROUS_ACTIVITY": return "square.safety.dangerous"
        case "SENSITIVE_CONTENT": return "square.safety.sensitive"
        case "FLASHING_IMAGES": return "square.safety.flashing"
        case "SPOILER": return "square.safety.spoiler"
        case "TEMPORARY_CLOSURE": return "square.safety.closure"
        case "ACCESSIBILITY_LIMIT": return "square.safety.accessibility"
        case "WEATHER_RISK": return "square.safety.weather"
        default: return nil
        }
    }
    var body: some View {
        if let key { Text(key) } else { Text(verbatim: value) }
    }
}
