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
    @State private var selected: ClubPostReferenceRoute?
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
                        Button {
                            guard sourceActive, selected == nil, topics.destination != nil, current(target) else { return }
                            selected = target
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
        .sheet(item: $selected) { target in
            ClubPostReferenceDestination(target: target, identity: identity, topics: topics, model: model)
                .presentationDetents([.large]).presentationCompactAdaptation(.sheet)
                .cyDomainPageBackground()
        }
        .onChange(of: context) { _, _ in selected = nil }
        .onChange(of: post) { _, _ in selected = nil }
        .onChange(of: topics.destination == nil) { _, _ in selected = nil }
        .onAppear { sourceActive = true }
        .onDisappear { sourceActive = false }
    }
    private var referenceTitle: String {
        let trimmed = post.sportName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "—" : trimmed
    }
    private var referenceLabel: some View {
        CYListRow(verbatim: referenceTitle, trailing: .chevron) {
            referenceThumb
        }
        .frame(maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget, alignment: .leading)
        .accessibilityLabel(Text(verbatim: referenceTitle))
    }
    private var referenceThumb: some View {
        let seed = referenceTitle == "—" ? "club-post-\(post.id)" : referenceTitle
        return ClubCloud14Thumb(seed: seed, symbol: "doc.text.magnifyingglass", imageURL: ClubCloud14HTTPS.url(post.sportCover))
    }
}

/// Leading art for a linked topic. Decorative: the row title is the accessible name.
private struct ClubCloud14Thumb: View {
    let seed: String
    var symbol: String? = nil
    var imageURL: URL? = nil
    var body: some View {
        Color.clear
            .overlay {
                CYCoverArt(seed: seed, symbol: symbol, showsDebugLabel: false)
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
        NavigationStack {
            if current, case let .topic(id) = target.destination, let destination = topics.destination {
                destination(id).id(target.id)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("action.close") { dismiss() }.accessibilityIdentifier("club.postReference.close")
                        }
                    }
            } else { Color.clear.onAppear { dismiss() } }
        }
        .onChange(of: context) { _, _ in dismiss() }
    }
}
