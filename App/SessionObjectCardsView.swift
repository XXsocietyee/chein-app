import SwiftUI

/// Observes epoch rotation so navigation detail and selection state are replaced.
@MainActor struct SessionObjectCardsView: View {
    @EnvironmentObject private var session: AppSession
    var body: some View {
        ObjectCardsView(reader: session.objectCardReader, media: session.makeObjectCardImageLoader())
            .id(session.objectCardReader.scope)
    }
}

@MainActor struct ProfileObjectCardsAccess {
    let reader: any ObjectCardReading
    let owner: SocialAccountIdentity
    let scope: UUID
    init(reader: any ObjectCardReading, owner: SocialAccountIdentity) {
        self.reader = reader; self.owner = owner; scope = reader.scope
    }
}

@MainActor struct ProfileObjectCardsEntry: View {
    let memberID: Int
    let accountReader: any SocialAccountReading
    let access: ProfileObjectCardsAccess
    let isCurrent: @MainActor () -> Bool
    var body: some View {
        if let context = ProfileObjectCardsContext.capture(memberID: memberID, accountReader: accountReader,
            objectReader: access.reader, owner: access.owner, ownerScope: access.scope, isCurrent: isCurrent()) {
            Section {
                NavigationLink {
                    ProfileObjectCardsDestination(context: context, accountReader: accountReader,
                        objectReader: access.reader, isCurrent: isCurrent)
                        .id(context)
                } label: { Label("objects.title", systemImage: "rectangle.stack") }  // N-OCARDS (r10): system NavigationLink Label row
                    .accessibilityIdentifier("profile.objectCards")
            }.id(context)
        }
    }
}

@MainActor private struct ProfileObjectCardsDestination: View {
    @EnvironmentObject private var session: AppSession
    @State private var reader: ProfileObjectCardsScopedReader
    init(context: ProfileObjectCardsContext, accountReader: any SocialAccountReading,
         objectReader: any ObjectCardReading, isCurrent: @escaping @MainActor () -> Bool) {
        _reader = State(initialValue: .init(context: context, accountReader: accountReader,
            objectReader: objectReader, isCurrent: isCurrent))
    }
    var body: some View {
        Group {
            if reader.associationIsCurrent {
                ObjectCardsView(reader: reader, media: session.makeObjectCardImageLoader()).id(reader.scope)
            }
            else { CYEmptyState(systemImage: "arrow.triangle.2.circlepath", "social.changed") }
        }
        // Observe the live host even while the profile is covered by this route.
        // Replacing the underlying epoch removes retained collection/detail state.
        .id(session.objectCardReader.scope)
    }
}
