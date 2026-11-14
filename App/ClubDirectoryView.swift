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
    @State private var stagger = CYStaggerGate()
    @State private var submittedName = ""
    /// Card or inline Join pill tapped; both open the gated detail, which still owns the membership action.
    @State private var openedClubID: Int? = nil
    @Environment(\.cyPalette) private var palette
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CYHeroHeader("club.directory")
                .padding(.horizontal, CYSpacing.pageHorizontal)
                .padding(.top, CYSpacing.sm)
            searchHeader
            ClubReadScreen(reader: reader, accessibilityPrefix: "club.directory", onSignIn: onSignIn,
                           load: { try await reader.clubDirectory(name: submittedName.isEmpty ? nil : submittedName) }) { rows in
                List {
                    if rows.isEmpty {
                        CYEmptyState(systemImage: "person.3", "club.emptyDirectory", detail: "club.emptyDirectoryHint", messageIdentifier: "club.directory.empty")
                            .listRowInsets(EdgeInsets(top: CYSpacing.lg, leading: CYSpacing.pageHorizontal, bottom: CYSpacing.lg, trailing: CYSpacing.pageHorizontal))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    } else {
                        ForEach(Array(rows.enumerated()), id: \.offset) { index, club in
                            ClubDirectoryCard(club: club, prominent: index == 0, viewerIsMerchant: actionCoordinator?.viewerIsMerchant ?? false,
                                              onOpen: { openedClubID = club.id }, identifier: "club.directory.\(club.id)")
                                .cyHeroSource(club.id, in: hero)
                                .cyStaggeredAppear(index: index, gate: stagger)
                                .listRowInsets(EdgeInsets(top: CYSpacing.sm, leading: CYSpacing.pageHorizontal, bottom: CYSpacing.sm, trailing: CYSpacing.pageHorizontal))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)

                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .id(submittedName)
        .navigationDestination(item: $openedClubID) { id in
            ClubDetailView(id: id, reader: reader, onSignIn: onSignIn, actionCoordinator: actionCoordinator, management:management, community:community, publicRoster:publicRoster)
                .cyHeroDestination(id, in: hero)
        }
        .cyDomainPageBackground()
        .cyHideTabBar()
        .onSubmit(of: .search) { submittedName = searchText.trimmingCharacters(in: .whitespacesAndNewlines) }
        .onChange(of: searchText) { _, value in if value.isEmpty { submittedName = "" } }
        .onChange(of: reader.clubIdentity) { _, _ in searchText = ""; submittedName = "" }
    }

    private var searchHeader: some View {
        HStack(spacing: CYSpacing.sm) {
            Image(systemName: "magnifyingglass").foregroundStyle(palette.textSecondary).accessibilityHidden(true)
            TextField("club.searchPrompt", text: $searchText)
                .submitLabel(.search).textInputAutocapitalization(.never).autocorrectionDisabled()
                .foregroundStyle(palette.textPrimary)
                .accessibilityIdentifier("club.directory.search")
            if !searchText.isEmpty {
                Button { searchText = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(palette.textSecondary) }
                    .accessibilityLabel(Text("club.directory.clearSearch"))
                    .frame(minWidth: CYSpacing.minTouchTarget, minHeight: CYSpacing.minTouchTarget)
            }
        }
        .padding(.horizontal, CYSpacing.md)
        .frame(minHeight: CYSpacing.minTouchTarget)
        .background(palette.bgElevated, in: Capsule(style: .continuous))
        .overlay(Capsule(style: .continuous).strokeBorder(palette.borderSubtle, lineWidth: 1))
        .padding(.horizontal, CYSpacing.pageHorizontal)
        .padding(.vertical, CYSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
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
    @State private var stagger = CYStaggerGate()
    @State private var openedClubID: Int? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CYHeroHeader("club.owned")
                .padding(.horizontal, CYSpacing.pageHorizontal)
                .padding(.top, CYSpacing.sm)
                .padding(.bottom, CYSpacing.sm)
            ClubReadScreen(reader: reader, accessibilityPrefix: "club.owned", requiresSignIn: true,
                           onSignIn: onSignIn, load: { try await reader.clubOwned() }) { rows in
                List {
                    if rows.isEmpty {
                        CYEmptyState(systemImage: "person.3", "club.emptyOwned", detail: "club.emptyOwnedHint", messageIdentifier: "club.owned.empty")
                            .listRowInsets(EdgeInsets(top: CYSpacing.lg, leading: CYSpacing.pageHorizontal, bottom: CYSpacing.lg, trailing: CYSpacing.pageHorizontal))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    } else {
                        ForEach(Array(rows.enumerated()), id: \.offset) { index, club in
                            ClubDirectoryCard(club: club, prominent: index == 0, viewerIsMerchant: false,
                                              onOpen: { openedClubID = club.id }, identifier: "club.owned.\(club.id)")
                                .cyHeroSource(club.id, in: hero)
                                .cyStaggeredAppear(index: index, gate: stagger)
                                .listRowInsets(EdgeInsets(top: CYSpacing.sm, leading: CYSpacing.pageHorizontal, bottom: CYSpacing.sm, trailing: CYSpacing.pageHorizontal))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)

                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationDestination(item: $openedClubID) { id in
            ClubDetailView(id: id, reader: reader, onSignIn: onSignIn, actionCoordinator: actionCoordinator, management:management, community:community, publicRoster:publicRoster)
                .cyHeroDestination(id, in: hero)
        }
        .cyDomainPageBackground()
        .cyHideTabBar()
    }
}

/// Photo card for a directory or owned-club row: cover, name, avatar stack and count, then one Join pill or status chip.
/// The card and the pill both open the detail; whether a join can be sent is still decided there.
private struct ClubDirectoryCard: View {
    let club: ClubRecord
    var prominent = false
    var viewerIsMerchant = false
    let onOpen: () -> Void
    let identifier: String

    var body: some View {
        CYClubPhotoCard(name: club.name, place: place, coverURL: QuestifyCardArtwork.safeURL(club.cover),
                        memberCount: club.sourceMemberCount, seed: "\(club.id)", prominent: prominent,
                        action: club.cardAction(viewerIsMerchant: viewerIsMerchant), onOpen: onOpen, onJoin: onOpen, identifier: identifier)
    }

    private var place: String? {
        let text = [club.style, club.city]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
        return text.isEmpty ? nil : text
    }
}
