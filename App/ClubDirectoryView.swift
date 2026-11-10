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
                            NavigationLink {
                                ClubDetailView(id: club.id, reader: reader, onSignIn: onSignIn, actionCoordinator: actionCoordinator, management:management, community:community, publicRoster:publicRoster)
                                    .cyHeroDestination(club.id, in: hero)
                            } label: {
                                ClubDirectoryCard(club: club, prominent: index == 0)
                                    .cyHeroSource(club.id, in: hero)
                            }
                            .buttonStyle(.plain)
                            .questifyHidesLinkIndicator()
                            .cyStaggeredAppear(index: index, gate: stagger)
                            .listRowInsets(EdgeInsets(top: CYSpacing.sm, leading: CYSpacing.pageHorizontal, bottom: CYSpacing.sm, trailing: CYSpacing.pageHorizontal))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .accessibilityIdentifier("club.directory.\(club.id)")
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .id(submittedName)
        .cyDomainPageBackground()
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
                            NavigationLink {
                                ClubDetailView(id: club.id, reader: reader, onSignIn: onSignIn, actionCoordinator: actionCoordinator, management:management, community:community, publicRoster:publicRoster)
                                    .cyHeroDestination(club.id, in: hero)
                            } label: {
                                ClubDirectoryCard(club: club, prominent: index == 0)
                                    .cyHeroSource(club.id, in: hero)
                            }
                            .buttonStyle(.plain)
                            .questifyHidesLinkIndicator()
                            .cyStaggeredAppear(index: index, gate: stagger)
                            .listRowInsets(EdgeInsets(top: CYSpacing.sm, leading: CYSpacing.pageHorizontal, bottom: CYSpacing.sm, trailing: CYSpacing.pageHorizontal))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .accessibilityIdentifier("club.owned.\(club.id)")
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .cyDomainPageBackground()
    }
}

/// Photo card for a directory or owned-club row. The whole card is the link; the chip is status, not a second action.
private struct ClubDirectoryCard: View {
    let club: ClubRecord
    var prominent = false
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            CYImageCard(verbatim: trimmedName, fallback: "club.untitled", meta: meta, imageURL: QuestifyCardArtwork.safeURL(club.cover), aspectRatio: prominent ? nil : 2.35, style: .hero)
            CYStatusChip(roleKey, tone: roleTone, systemImage: roleSymbol)
        }
        .accessibilityElement(children: .combine)
    }

    private var trimmedName: String { club.name.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var meta: String {
        let place = [club.style, club.city]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
        let members = memberText
        return place.isEmpty ? members : place + " · " + members
    }

    /// Missing member count is an em dash. A literal 0 stays "0 members".
    private var memberText: String {
        guard let count = club.sourceMemberCount, count >= 0 else { return "—" }
        return ClubMemberCountLocalization.text(count, locale: locale)
    }

    private var roleKey: LocalizedStringKey {
        if club.isOwner { return "club.role.creator" }
        if club.isJoined { return "club.membership.joined" }
        if club.joinPending { return "club.membership.pending" }
        return "club.action.join"
    }
    private var roleTone: CYStatusTone {
        if club.isOwner { return .info }
        if club.isJoined { return .success }
        if club.joinPending { return .warning }
        return .neutral
    }
    private var roleSymbol: String {
        if club.isOwner { return "crown" }
        if club.isJoined { return "checkmark" }
        if club.joinPending { return "clock" }
        return "plus"
    }
}
