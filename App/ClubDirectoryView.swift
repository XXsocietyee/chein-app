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
                        // P25: the viewer's own clubs are navigation (chevron rows), every other club is a decision
                        // (one trailing bordered Join); the two never share a row style. Server order is kept inside each.
                        let merchant = actionCoordinator?.viewerIsMerchant ?? false
                        let yours = rows.filter { ClubDirectoryCard.isYours($0, viewerIsMerchant: merchant) }
                        let discover = rows.filter { !ClubDirectoryCard.isYours($0, viewerIsMerchant: merchant) }
                        if !yours.isEmpty {
                            Section {
                                ForEach(yours, id: \.id) { club in
                                    ClubDirectoryCard(club: club, style: .yours, viewerIsMerchant: merchant,
                                                      onOpen: { openedClubID = club.id }, identifier: "club.directory.\(club.id)")
                                        .cyHeroSource(club.id, in: hero)
                                }
                            } header: {
                                Text("club.home.yours").accessibilityAddTraits(.isHeader)
                            }
                        }
                        if !discover.isEmpty, yours.isEmpty {
                            // No header when it is the only section: an empty header still reserves a band.
                            Section { discoverRows(discover, merchant: merchant) }
                        } else if !discover.isEmpty {
                            Section {
                                discoverRows(discover, merchant: merchant)
                            } header: {
                                Text("club.home.discover").accessibilityAddTraits(.isHeader)
                            }
                        }
                    }
                }
                // Sweep 13:15 (P2): the list starts right under the title, no empty band above the first row.
                .contentMargins(.top, CYSpacing.sm, for: .scrollContent)
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

    @ViewBuilder private func discoverRows(_ discover: [ClubRecord], merchant: Bool) -> some View {
        ForEach(discover, id: \.id) { club in
            ClubDirectoryCard(club: club, style: .discover, viewerIsMerchant: merchant,
                              onOpen: { openedClubID = club.id }, identifier: "club.directory.\(club.id)")
                .cyHeroSource(club.id, in: hero)
        }
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
                        ForEach(rows, id: \.id) { club in
                            ClubDirectoryCard(club: club, style: .yours, viewerIsMerchant: false,
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

/// Native club row for the directory and owned lists (P25). `.yours`: thumbnail, name, member count, chevron; the row
/// opens the club. `.discover`: thumbnail, name, one secondary line (member count · description, else style · city) and one
/// trailing bordered Join / Apply, which opens the detail; whether a join can be sent is decided there.
private struct ClubDirectoryCard: View {
    enum Style { case yours, discover }
    static func isYours(_ club: ClubRecord, viewerIsMerchant: Bool) -> Bool {
        switch club.cardAction(viewerIsMerchant: viewerIsMerchant) {
        case .owner, .joined: return true
        default: return false
        }
    }
    let club: ClubRecord
    var style: Style = .discover
    var viewerIsMerchant = false
    let onOpen: () -> Void
    let identifier: String
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let action = club.cardAction(viewerIsMerchant: viewerIsMerchant)
        // AX sizes: the fixed-width Join / Apply button would squeeze the name to a sliver, so it moves under the row.
        let stacked = typeSize.isAccessibilitySize
        let layout = stacked
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: CYSpacing.sm))
            : AnyLayout(HStackLayout(spacing: CYSpacing.md))
        layout {
            Button(action: onOpen) {
                HStack(spacing: CYSpacing.md) {
                    // Sweep 0446d1c4f en-d4-directory: a List row squeezes a Label icon into its fixed icon column, which
                    // clipped the 48 pt thumbnail and centred the wrapped meta line. Plain HStack, text leading.
                    ClubRowThumbnail(url: QuestifyCardArtwork.safeURL(club.cover) ?? QuestifyCardArtwork.safeURL(club.logo))
                    VStack(alignment: .leading, spacing: 2) {
                        ClubName(value: club.name).font(.headline)
                        if let secondary {
                            Text(verbatim: secondary)
                                .font(.subheadline).foregroundStyle(.secondary)
                                .lineLimit(style == .discover ? 2 : 1).monospacedDigit()
                        }
                    }
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    if style == .yours {
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                            .accessibilityHidden(true)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.primary)
            .accessibilityIdentifier(identifier)
            if style == .discover {
                if !stacked {
                    Spacer(minLength: 0)
                }
                switch action {
                case .join:
                    Button(action: onOpen) {
                        Label("club.action.join", systemImage: "plus")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .fixedSize()
                    .accessibilityIdentifier(identifier + ".join")
                case .apply:
                    Button("club.action.apply", action: onOpen)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .fixedSize()
                        .accessibilityIdentifier(identifier + ".join")
                case .pending:
                    Label("club.membership.pending", systemImage: "clock")
                        .font(.subheadline).foregroundStyle(CYColor.warningText)
                case .joined, .owner, .none:
                    EmptyView()
                }
            }
        }
    }

    private var memberCount: String? {
        club.sourceMemberCount.map { ClubMemberCountLocalization.text($0, locale: locale) }
    }

    private var secondary: String? {
        let detail: String?
        if style == .discover {
            let description = club.description?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            detail = description.isEmpty ? place : description
        } else {
            detail = nil
        }
        let text = [memberCount, detail].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
        return text.isEmpty ? nil : text
    }

    private var place: String? {
        let text = [club.style, club.city]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
        return text.isEmpty ? nil : text
    }
}
