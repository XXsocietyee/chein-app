import SwiftUI

/// `FIN-17-4` (Order detail team, seats, club & merchant consent),
/// `FIN-17-8` (亲子票 & 票夹已过期),
/// `PLY-23-3` / `23-4` / `23-6` (Participation detail bundle entry, merchant-apply edit, cover),
/// `PLY-21-13` (Stacked horizontal pass pager).

public struct OrderDetailTeamSeatsClubSections: View {
    public let model: OrderDetailExtraActionsModel
    public let partyText: String?
    public let isTicketExpired: Bool

    public var onOpenTeam: () -> Void = {}
    public var onOpenSeats: () -> Void = {}
    public var onFollowOrJoinClub: () -> Void = {}

    public init(
        model: OrderDetailExtraActionsModel,
        partyText: String? = nil,
        isTicketExpired: Bool = false,
        onOpenTeam: @escaping () -> Void = {},
        onOpenSeats: @escaping () -> Void = {},
        onFollowOrJoinClub: @escaping () -> Void = {}
    ) {
        self.model = model
        self.partyText = partyText
        self.isTicketExpired = isTicketExpired
        self.onOpenTeam = onOpenTeam
        self.onOpenSeats = onOpenSeats
        self.onFollowOrJoinClub = onFollowOrJoinClub
    }

    public var body: some View {
        Group {
            if partyText != nil || isTicketExpired {
                Section("orderDetail.credentials.extra") {
                    if let partyText, !partyText.isEmpty {
                        LabeledContent("orderDetail.partyTicket", value: partyText)
                            .cyText(.bodyCompact)
                    }
                    if isTicketExpired {
                        Text("orderDetail.ticketExpired")
                            .cyText(.meta)
                            .foregroundStyle(CYColor.textSecondary)
                    }
                }
            }

            if model.hasTeamSection || model.hasSeatsEntry {
                Section("orderDetail.teamAndSeats") {
                    if model.hasTeamSection {
                        if let teamName = model.teamName, !teamName.isEmpty {
                            Button(teamName, action: onOpenTeam)
                        } else {
                            Button("orderDetail.inviteTeammates", action: onOpenTeam)
                        }
                    }
                    if model.hasSeatsEntry {
                        Button("orderDetail.seatsEntry", action: onOpenSeats)
                    }
                }
            }

            if let clubName = model.clubName, model.clubID != nil {
                Section("orderDetail.club.section") {
                    Button {
                        onFollowOrJoinClub()
                    } label: {
                        LabeledContent {
                            Text(model.isClubMember ? "orderDetail.club.joined" : "orderDetail.club.followOrJoin")
                        } label: {
                            Text(clubName)
                        }
                    }
                }
            }

            if let consent = model.merchantConsentText, !consent.isEmpty {
                Section("orderDetail.merchantConsent.section") {
                    Text(consent)
                        .cyText(.meta)
                        .foregroundStyle(CYColor.textSecondary)
                }
            }
        }
    }
}

public struct ParticipationDetailGapSections: View {
    public let coverURL: String?
    public let templateBannerURL: String?
    public let isFreeExplore: Bool
    public let canEditMerchantApply: Bool
    public var onOpenFreeExploreBundle: () -> Void = {}
    public var onEditMerchantApply: () -> Void = {}

    public init(
        coverURL: String? = nil,
        templateBannerURL: String? = nil,
        isFreeExplore: Bool = false,
        canEditMerchantApply: Bool = false,
        onOpenFreeExploreBundle: @escaping () -> Void = {},
        onEditMerchantApply: @escaping () -> Void = {}
    ) {
        self.coverURL = coverURL
        self.templateBannerURL = templateBannerURL
        self.isFreeExplore = isFreeExplore
        self.canEditMerchantApply = canEditMerchantApply
        self.onOpenFreeExploreBundle = onOpenFreeExploreBundle
        self.onEditMerchantApply = onEditMerchantApply
    }

    public var body: some View {
        Group {
            if let coverURL, !coverURL.isEmpty {
                Section {
                    CYCachedAsyncImage(coverURL, role: .cover)
                        .frame(maxWidth: .infinity, minHeight: 160)
                        .clipShape(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
                }
            }

            if isFreeExplore {
                Section {
                    Button(action: onOpenFreeExploreBundle) {
                        Text("participation.freeExploreBundle").cyText(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .frame(minHeight: CYSpacing.minTouchTarget)
                    }
                    .accessibilityIdentifier("playerJourney.freeExploreBundle")
                }
            }

            if canEditMerchantApply {
                Section {
                    Button("participation.editMerchantApply", action: onEditMerchantApply)
                }
            }

            if let templateBannerURL, !templateBannerURL.isEmpty {
                Section("participation.templateBanner") {
                    CYCachedAsyncImage(templateBannerURL, role: .cover)
                        .frame(maxWidth: .infinity, minHeight: 120)
                        .clipShape(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
                }
            }
        }
    }
}

public struct StackedPassHorizontalPager<Item: Identifiable, CardContent: View>: View {
    public let passes: [Item]
    @Binding public var selectedID: Item.ID?
    @ViewBuilder public let content: (Item) -> CardContent

    public init(
        passes: [Item],
        selectedID: Binding<Item.ID?>,
        @ViewBuilder content: @escaping (Item) -> CardContent
    ) {
        self.passes = passes
        self._selectedID = selectedID
        self.content = content
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: CYSpacing.md) {
                ForEach(passes) { pass in
                    content(pass)
                        .containerRelativeFrame(.horizontal, count: 1, spacing: CYSpacing.md)
                        .id(pass.id)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $selectedID)
        .sensoryFeedback(.selection, trigger: selectedID)
    }
}
