import SwiftUI

@MainActor
struct ClubDirectoryView<Reader: ClubReading & ObservableObject>: View {
    @ObservedObject var reader: Reader
    var onSignIn: (() -> Void)? = nil
    var actionCoordinator: ClubActionCoordinator? = nil
    var management:ClubManagementContext? = nil
    var community: ClubCommunityContext? = nil
    var publicRoster: ClubPublicRosterReader? = nil
    @State private var searchText = ""
    @Namespace private var hero
    @State private var submittedName = ""
    /// Card or inline Join pill tapped; both open the gated detail, which still owns the membership action.
    @State private var openedClubID: Int? = nil
    var body: some View {
        // X1 (parity r2): pushed page → inline bar title, no hero in the content.
        VStack(alignment: .leading, spacing: 0) {
            ClubReadScreen(reader: reader, accessibilityPrefix: "club.directory", onSignIn: onSignIn,
                           load: { try await reader.clubDirectory(name: submittedName.isEmpty ? nil : submittedName) }) { rows in
                List {
                    if rows.isEmpty {
                        ContentUnavailableView {
                            Label { Text("club.emptyDirectory").accessibilityIdentifier("club.directory.empty") } icon: { Image(systemName: "person.3") }
                        } description: {
                            Text("club.emptyDirectoryHint")
                        }
                    } else {
                        ForEach(Array(rows.enumerated()), id: \.offset) { index, club in
                            ClubDirectoryCard(club: club, prominent: index == 0, viewerIsMerchant: actionCoordinator?.viewerIsMerchant ?? false,
                                              onOpen: { openedClubID = club.id }, identifier: "club.directory.\(club.id)")
                                .cyHeroSource(club.id, in: hero)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .id(submittedName)
        .navigationDestination(item: $openedClubID) { id in
            ClubDetailView(id: id, reader: reader, onSignIn: onSignIn, actionCoordinator: actionCoordinator, management:management, community:community, publicRoster:publicRoster)
                .cyHeroDestination(id, in: hero)
        }
        .cyHideTabBar()
        .searchable(text: $searchText, prompt: Text("club.searchPrompt"))
        .onSubmit(of: .search) { submittedName = searchText.trimmingCharacters(in: .whitespacesAndNewlines) }
        .onChange(of: searchText) { _, value in if value.isEmpty { submittedName = "" } }
        .onChange(of: reader.clubIdentity) { _, _ in searchText = ""; submittedName = "" }
        .cyDomainScreen(.player)
        .cyPageTitle("club.directory")
    }
}

/// /my owns only the owned section; joined clubs remain separately sourced from /home.
@MainActor
struct ClubOwnedView<Reader: ClubReading & ObservableObject>: View {
    @ObservedObject var reader: Reader
    var onSignIn: (() -> Void)? = nil
    var actionCoordinator: ClubActionCoordinator? = nil
    var management:ClubManagementContext? = nil
    var community: ClubCommunityContext? = nil
    var publicRoster: ClubPublicRosterReader? = nil
    @Namespace private var hero
    @State private var openedClubID: Int? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ClubReadScreen(reader: reader, accessibilityPrefix: "club.owned", requiresSignIn: true,
                           onSignIn: onSignIn, load: { try await reader.clubOwned() }) { rows in
                List {
                    if rows.isEmpty {
                        ContentUnavailableView {
                            Label { Text("club.emptyOwned").accessibilityIdentifier("club.owned.empty") } icon: { Image(systemName: "person.3") }
                        } description: {
                            Text("club.emptyOwnedHint")
                        }
                    } else {
                        ForEach(Array(rows.enumerated()), id: \.offset) { index, club in
                            ClubDirectoryCard(club: club, prominent: index == 0, viewerIsMerchant: false,
                                              onOpen: { openedClubID = club.id }, identifier: "club.owned.\(club.id)")
                                .cyHeroSource(club.id, in: hero)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationDestination(item: $openedClubID) { id in
            ClubDetailView(id: id, reader: reader, onSignIn: onSignIn, actionCoordinator: actionCoordinator, management:management, community:community, publicRoster:publicRoster)
                .cyHeroDestination(id, in: hero)
        }
        .cyHideTabBar()
        .cyDomainScreen(.player)
        .cyPageTitle("club.owned")
    }
}

/// Native club row for the directory and owned lists: cover thumbnail, name, place and member count, and the
/// membership state. The row and its Join / Apply button both open the detail; whether a join can be sent is decided there.
private struct ClubDirectoryCard: View {
    let club: ClubRecord
    var prominent = false
    var viewerIsMerchant = false
    let onOpen: () -> Void
    let identifier: String
    @Environment(\.locale) private var locale

    var body: some View {
        let action = club.cardAction(viewerIsMerchant: viewerIsMerchant)
        HStack(spacing: CYSpacing.md) {
            Button(action: onOpen) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        ClubName(value: club.name).font(.headline).multilineTextAlignment(.leading)
                        if let place { Text(verbatim: place).font(.subheadline).foregroundStyle(.secondary) }
                        if let count = club.sourceMemberCount {
                            Text(verbatim: ClubMemberCountLocalization.text(count, locale: locale))
                                .font(.subheadline).foregroundStyle(.secondary).monospacedDigit()
                        }
                    }
                } icon: {
                    ClubRowThumbnail(url: QuestifyCardArtwork.safeURL(club.cover) ?? QuestifyCardArtwork.safeURL(club.logo))
                }
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.primary)
            .accessibilityIdentifier(identifier)
            Spacer(minLength: 0)
            switch action {
            case .join, .apply:
                Button(action: onOpen) {
                    action == .join ? Text("club.action.join") : Text("club.action.apply")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .accessibilityIdentifier(identifier + ".join")
            case .pending:
                Label("club.membership.pending", systemImage: "clock")
                    .font(.subheadline).foregroundStyle(.orange)
            case .joined:
                Label("club.membership.joined", systemImage: "checkmark")
                    .font(.subheadline).foregroundStyle(.secondary)
            case .owner, .none:
                EmptyView()
            }
        }
    }

    private var place: String? {
        let text = [club.style, club.city]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
        return text.isEmpty ? nil : text
    }
}
