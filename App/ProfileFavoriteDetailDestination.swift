import SwiftUI
import Observation

/// The account NavigationStack owns the route; a covered detail is still on that stack.
@MainActor @Observable final class ProfileFavoriteNavigationOwner {
    private(set) var selection: ProfileFavoritePostSelection?
    private var mounted = false
    private var foreground = false
    private var scope: UUID?
    func appear(scope: UUID, foreground: Bool) {
        mounted = true; self.foreground = foreground; updateScope(scope)
    }
    func updateScope(_ value: UUID) {
        if scope != value { retireSelection(); scope = value }
    }
    func setForeground(_ value: Bool) {
        foreground = value
        if !value { retireSelection() }
    }
    func disappear() { mounted = false; retireSelection() }
    @discardableResult func open(_ next: ProfileFavoritePostSelection, scope: UUID) -> Bool {
        guard mounted, foreground, self.scope == scope, next.isCurrent else { return false }
        retireSelection(); selection = next; return true
    }
    @discardableResult func close(id: UUID) -> Bool {
        guard let selected = selection, selected.id == id else { return false }
        ProfileFavoriteDetailReaderLifetime.release(id)
        selected.retire(); selection = nil; return true
    }
    func binding(for selected: ProfileFavoritePostSelection) -> Binding<ProfileFavoritePostSelection?> {
        let id = selected.id
        return Binding(get: {
            guard self.selection?.id == id, selected.isCurrent else { return nil }
            return selected
        }, set: { value in
            if value == nil { _ = self.close(id: id) }
        })
    }
    private func retireSelection() {
        if let id = selection?.id { ProfileFavoriteDetailReaderLifetime.release(id) }
        selection?.retire(); selection = nil
    }
}

/// One detail reader per selection. A child cover can rebuild the destination view; the account
/// route keeps the reader that was created the first time that selection appeared.
@MainActor enum ProfileFavoriteDetailReaderLifetime {
    private static var readers: [UUID: ProfileFavoriteDetailReader] = [:]
    static func reader(for id: UUID, make: () -> ProfileFavoriteDetailReader) -> ProfileFavoriteDetailReader {
        if let existing = readers[id] { return existing }
        let created = make()
        readers[id] = created
        return created
    }
    static func release(_ id: UUID) { readers[id] = nil }
}

/// A new UUID mounts a new non-nil native item binding; no initial-nil binding is reused.
@MainActor struct ProfileFavoriteNavigationLayer<Destination: View>: View {
    let owner: ProfileFavoriteNavigationOwner
    let destination: (ProfileFavoritePostSelection) -> Destination
    var body: some View {
        Group {
            if let selected = owner.selection {
                Color.clear
                    .navigationDestination(item: owner.binding(for: selected), destination: destination)
                    .id(selected.id)
            }
        }
    }
}

/// Covers by the original author's pages do not end the account-owned route.
@MainActor struct ProfileFavoriteDetailDestination: View {
    let selection: ProfileFavoritePostSelection
    let makeReader: () -> ProfileFavoriteDetailReader
    let accountReader: (any SocialAccountReading)?
    let actions: SocialActionCoordinator?
    @State private var reader: ProfileFavoriteDetailReader?
    var body: some View {
        ZStack {
            if let reader, selection.isCurrent {
                SquareDetailView(id: selection.route.id, contentGeneration: selection.route.generation,
                    reader: reader, accountReader: accountReader, actions: actions).id(reader.scope)
                ProfileFavoriteDetailAccessibilityProjection(label: reader.confirmedProjectionAccessibilityLabel)
            } else if selection.isCurrent { ProgressView("square.loading") }
            else { AccountCollectionIssueView(issue: .login) }
        }
        .onAppear {
            guard reader == nil, selection.isCurrent else { return }
            reader = ProfileFavoriteDetailReaderLifetime.reader(for: selection.id, make: makeReader)
        }
    }
}

@MainActor private struct ProfileFavoriteDetailAccessibilityProjection: UIViewRepresentable {
    let label: String?
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        view.accessibilityLabel = label
        return view
    }
    func updateUIView(_ uiView: UIView, context: Context) {
        uiView.accessibilityLabel = label
    }
}
