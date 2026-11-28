import SwiftUI

/// Uses the already-composed topic destination, with its own read/access gates.
/// This is the reference-detail action, not the separate Mini self-play action.
@MainActor struct ClubPostReferenceView: View {
    let post: ClubCommunityPost
    let clubID: Int?
    let identity: ClubReadIdentity
    @ObservedObject var model: ClubCommunityViewModel
    let openComments: () -> Void
    @Environment(\.clubCustomerTopics) private var topics
    @State private var sourceActive = true
    private var context: ClubPostReferenceContext {
        .init(clubID: clubID, identity: identity, readScope: model.imageReadScope, viewerRevision: topics.viewerRevision)
    }
    private var route: ClubPostReferenceRoute? {
        guard (try? model.context.currentSession().identity) == identity, let posts = model.snapshot?.posts else { return nil }
        return .init(post: post, acceptedPosts: posts, context: context)
    }
    private func current(_ target: ClubPostReferenceRoute) -> Bool {
        (try? model.context.currentSession().identity) == identity &&
        target.isCurrent(acceptedPosts: model.snapshot?.posts, context: context)
    }
    var body: some View {
        Group {
            if let target = route {
                switch target.destination {
                case .comments:
                    Button {
                        guard sourceActive, current(target) else { return }; openComments()
                    } label: { referenceLabel }
                    .accessibilityHint("club.community.comments")
                    .accessibilityIdentifier("club.postReference.comments.\(post.id)")
                case let .topic(topicID):
                    if topics.destination != nil {
                        // mp-nav r3: MP talent/list index.js:241-246 onPostReference = navigateTo pages/topic/index/index,
                        // so the topic is a push (system back), not a sheet with 关闭. The destination re-checks the route.
                        NavigationLink {
                            ClubPostReferenceDestination(target: target, identity: identity, topics: topics, model: model)
                        } label: { referenceLabel }
                        .accessibilityHint("roamEvent.openTopic")
                        .accessibilityIdentifier("club.postReference.open.\(post.id)")
                    } else if let open = model.context.onTopic {
                        Button { if sourceActive && current(target) { open(topicID) } } label: { referenceLabel }
                    } else { referenceLabel }
                }
            } else { referenceLabel }
        }
        .buttonStyle(.borderless)
        .onAppear { sourceActive = true }
        .onDisappear { sourceActive = false }
    }
    private var referenceTitle: String {
        let trimmed = post.sportName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "—" : trimmed
    }
    private var referenceLabel: some View {
        HStack(spacing: 12) {
            referenceThumb
            Text(verbatim: referenceTitle)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: referenceTitle))
    }
    private var referenceThumb: some View {
        ClubCloud14Thumb(symbol: "doc.text.magnifyingglass", imageURL: ClubCloud14HTTPS.url(post.sportCover))
    }
}

/// Leading thumbnail for a linked topic: the topic cover, or an SF Symbol on a system fill. Decorative.
private struct ClubCloud14Thumb: View {
    var symbol: String
    var imageURL: URL? = nil
    var body: some View {
        Rectangle().fill(.quaternary)
            .overlay {
                Image(systemName: symbol).foregroundStyle(.secondary)
                if let imageURL {
                    PlayerFeedRemoteImage(url: imageURL, maxPixel: 168, placeholder: { Color.clear }, failure: { Color.clear })
                }
            }
            .frame(width: 40, height: 40)
            .clipShape(RoundedRectangle(cornerRadius: CYRadius.inner, style: .continuous))
            .accessibilityHidden(true)
    }
}

private enum ClubCloud14HTTPS {
    static func url(_ raw: String?) -> URL? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty,
              let url = URL(string: raw), url.scheme?.lowercased() == "https" else { return nil }
        return url
    }
}

@MainActor private struct ClubPostReferenceDestination: View {
    let target: ClubPostReferenceRoute
    let identity: ClubReadIdentity
    let topics: ClubCustomerTopicContext
    @ObservedObject var model: ClubCommunityViewModel
    @Environment(\.dismiss) private var dismiss
    private var context: ClubPostReferenceContext {
        .init(clubID: target.context.clubID, identity: identity, readScope: model.imageReadScope, viewerRevision: topics.viewerRevision)
    }
    private var current: Bool {
        (try? model.context.currentSession().identity) == identity &&
        target.isCurrent(acceptedPosts: model.snapshot?.posts, context: context)
    }
    var body: some View {
        Group {
            if current, case let .topic(id) = target.destination, let destination = topics.destination {
                destination(id).id(target.id)
            } else { Color.clear.onAppear { dismiss() } }
        }
        .cyPushedChrome()
        .onChange(of: context) { _, _ in dismiss() }
    }
}
