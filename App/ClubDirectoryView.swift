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
    var body: some View {
        ClubReadScreen(reader: reader, accessibilityPrefix: "club.directory", onSignIn: onSignIn,
                       load: { try await reader.clubDirectory(name: submittedName.isEmpty ? nil : submittedName) }) { rows in
            if rows.isEmpty {
                CYEmptyState(systemImage: "person.3", "club.emptyDirectory", detail: "club.emptyDirectoryHint", messageIdentifier: "club.directory.empty")
            } else {
                List {
                    ForEach(Array(rows.enumerated()), id: \.offset) { index, club in
                        ZStack {
                            ClubRow(club: club).cyHeroSource(club.id, in: hero)
                            NavigationLink {
                                ClubDetailView(id: club.id, reader: reader, onSignIn: onSignIn, actionCoordinator: actionCoordinator, management:management, community:community, publicRoster:publicRoster)
                                    .cyHeroDestination(club.id, in: hero)
                            } label: { EmptyView() }.opacity(0)
                        }
                        .cyStaggeredAppear(index: index, gate: stagger)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .listRowBackground(Color.clear).listRowSeparator(.hidden)
                        .accessibilityIdentifier("club.directory.\(club.id)")
                    }
                }
                .cyGroupedSurface()
                .listStyle(.plain).scrollContentBackground(.hidden).listRowSpacing(4)
            }
        }
        .id(submittedName)
        .cyDomainPageBackground()
        .appNavigationTitle("club.directory")
        // Pinned header (not the floating system search overlay) so the last card never slides under it.
        .safeAreaInset(edge: .top, spacing: 0) { searchHeader }
        .onSubmit(of: .search) { submittedName = searchText.trimmingCharacters(in: .whitespacesAndNewlines) }
        .onChange(of: searchText) { _, value in if value.isEmpty { submittedName = "" } }
        .onChange(of: reader.clubIdentity) { _, _ in searchText = ""; submittedName = "" }
    }
}

extension ClubDirectoryView {
    private var searchHeader: some View {
        HStack(spacing: CYSpacing.sm) {
            Image(systemName: "magnifyingglass").foregroundStyle(CYColor.textSecondary).accessibilityHidden(true)
            TextField("club.searchPrompt", text: $searchText)
                .submitLabel(.search).textInputAutocapitalization(.never).autocorrectionDisabled()
                .foregroundStyle(CYColor.textPrimary)
                .accessibilityIdentifier("club.directory.search")
            if !searchText.isEmpty {
                Button { searchText = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(CYColor.textSecondary) }
                    .accessibilityLabel(Text("club.directory.clearSearch")).frame(minWidth: 44, minHeight: 44)
            }
        }
        .padding(.horizontal, CYSpacing.md).frame(minHeight: 44)
        .background(CYColor.bgSurfaceSubtle, in: Capsule())
        .overlay(Capsule().stroke(CYColor.borderSubtle))
        .padding(.horizontal, CYSpacing.lg).padding(.vertical, CYSpacing.sm)
        .background(.bar)
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
    var body: some View {
        ClubReadScreen(reader: reader, accessibilityPrefix: "club.owned", requiresSignIn: true,
                       onSignIn: onSignIn, load: { try await reader.clubOwned() }) { rows in
            if rows.isEmpty {
                CYEmptyState(systemImage: "person.badge.shield.checkmark", "club.emptyOwned", detail: "club.emptyOwnedHint", messageIdentifier: "club.owned.empty")
            } else {
                List {
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, club in
                        NavigationLink {
                            ClubDetailView(id: club.id, reader: reader, onSignIn: onSignIn, actionCoordinator: actionCoordinator, management:management, community:community, publicRoster:publicRoster)
                        } label: { ClubRow(club: club) }
                        .buttonStyle(QuestifyCardButtonStyle()).questifyCardListRow()
                        .accessibilityIdentifier("club.owned.\(club.id)")
                    }
                }
                .cyGroupedSurface()
                .listStyle(.plain).scrollContentBackground(.hidden).listRowSpacing(4)
            }
        }.cyDomainPageBackground().appNavigationTitle("club.owned")
    }
}
