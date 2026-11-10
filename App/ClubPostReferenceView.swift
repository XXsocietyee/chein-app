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
                    } label: { referenceLabel(true) }
                    .accessibilityHint("club.community.comments")
                    .accessibilityIdentifier("club.postReference.comments.\(post.id)")
                case let .topic(topicID):
                    if topics.destination != nil {
                        Button {
                            guard sourceActive, selected == nil, topics.destination != nil, current(target) else { return }
                            selected = target
                        } label: { referenceLabel(true) }
                        .accessibilityHint("roamEvent.openTopic")
                        .accessibilityIdentifier("club.postReference.open.\(post.id)")
                    } else if let open = model.context.onTopic {
                        Button { if sourceActive && current(target) { open(topicID) } } label: { referenceLabel(true) }
                    } else { referenceLabel(false) }
                }
            } else { referenceLabel(false) }
        }
        .buttonStyle(.borderless)
        .sheet(item: $selected) { target in
            ClubPostReferenceDestination(target: target, identity: identity, topics: topics, model: model)
                .presentationDetents([.large]).presentationCompactAdaptation(.sheet)
        }
        .onChange(of: context) { _, _ in selected = nil }
        .onChange(of: post) { _, _ in selected = nil }
        .onChange(of: topics.destination == nil) { _, _ in selected = nil }
        .onAppear { sourceActive = true }
        .onDisappear { sourceActive = false }
    }
    private func referenceLabel(_ actionable: Bool) -> some View {
        CYListRow(verbatim: post.sportName, trailing: actionable ? .chevron : .none, card: true) {
            CYRowIcon(systemImage: "doc.text.magnifyingglass")
        }
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
