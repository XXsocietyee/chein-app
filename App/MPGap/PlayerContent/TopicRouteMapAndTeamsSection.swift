import MapKit
import SwiftUI

/// `PC-B-1-5`: Topic route tab map, progress bar, nearby team summary & free-explore merchant cards.
public struct TopicRouteMapAndTeamsSection: View {
    public let pins: [TopicRouteNodePin]
    public let completedCount: Int
    public let totalCount: Int
    public let isFreeExplore: Bool
    public let teams: [TopicRouteTeamSummary]
    public let merchantCards: [TopicFreeExploreMerchantCard]
    public var onSelectPin: (TopicRouteNodePin) -> Void = { _ in }
    public var onOpenAllTeams: () -> Void = {}
    public var onSelectMerchant: (TopicFreeExploreMerchantCard) -> Void = { _ in }

    public init(
        pins: [TopicRouteNodePin],
        completedCount: Int,
        totalCount: Int,
        isFreeExplore: Bool,
        teams: [TopicRouteTeamSummary] = [],
        merchantCards: [TopicFreeExploreMerchantCard] = [],
        onSelectPin: @escaping (TopicRouteNodePin) -> Void = { _ in },
        onOpenAllTeams: @escaping () -> Void = {},
        onSelectMerchant: @escaping (TopicFreeExploreMerchantCard) -> Void = { _ in }
    ) {
        self.pins = pins
        self.completedCount = completedCount
        self.totalCount = totalCount
        self.isFreeExplore = isFreeExplore
        self.teams = teams
        self.merchantCards = merchantCards
        self.onSelectPin = onSelectPin
        self.onOpenAllTeams = onOpenAllTeams
        self.onSelectMerchant = onSelectMerchant
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            if totalCount > 0 {
                VStack(alignment: .leading, spacing: CYSpacing.xs) {
                    HStack {
                        Text("topicRoute.progress.title")
                            .cyText(.label)
                            .foregroundStyle(CYColor.textSecondary)
                        Spacer()
                        Text("\(completedCount)/\(totalCount)")
                            .cyText(.numericBody, monospacedDigit: true)
                            .foregroundStyle(CYColor.textPrimary)
                    }
                    ProgressView(value: Double(completedCount), total: Double(max(1, totalCount)))
                        .tint(CYColor.brand)
                }
            }

            if !pins.isEmpty {
                Map {
                    if !isFreeExplore && pins.count >= 2 {
                        MapPolyline(coordinates: pins.map {
                            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
                        })
                        .stroke(CYColor.brand, lineWidth: 3)
                    }
                    ForEach(pins) { pin in
                        Annotation(pin.name, coordinate: CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude)) {
                            Button {
                                onSelectPin(pin)
                            } label: {
                                Text("\(pin.sequence)")
                                    .cyText(.meta, weight: .bold, monospacedDigit: true)
                                    .foregroundStyle(CYColor.actionPrimaryFg)
                                    .frame(width: 26, height: 26)
                                    .background(pin.isCompleted ? CYColor.brand : CYColor.actionPrimaryBg)
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous))
            }

            if !teams.isEmpty {
                VStack(alignment: .leading, spacing: CYSpacing.sm) {
                    HStack {
                        Text("topicRoute.teams.title")
                            .cyText(.cardTitle)
                            .foregroundStyle(CYColor.textPrimary)
                        Spacer()
                        Button("topicRoute.teams.viewAll", action: onOpenAllTeams)
                            .cyText(.label)
                    }
                    ForEach(teams) { team in
                        HStack {
                            Text(team.name)
                                .cyText(.bodyMedium)
                                .foregroundStyle(CYColor.textPrimary)
                            Spacer()
                            Text("\(team.memberCount) 人")
                                .cyText(.meta, monospacedDigit: true)
                                .foregroundStyle(CYColor.textSecondary)
                            if team.missingCount > 0 {
                                Text("还差 \(team.missingCount) 人")
                                    .cyText(.meta, monospacedDigit: true)
                                    .foregroundStyle(CYColor.brand)
                            }
                        }
                        .padding(CYSpacing.sm)
                        .background(CYColor.bgSurface)
                        .clipShape(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
                    }
                }
            }

            if isFreeExplore && !merchantCards.isEmpty {
                VStack(alignment: .leading, spacing: CYSpacing.sm) {
                    Text("topicRoute.merchants.title")
                        .cyText(.cardTitle)
                        .foregroundStyle(CYColor.textPrimary)
                    ForEach(merchantCards) { card in
                        Button {
                            onSelectMerchant(card)
                        } label: {
                            HStack(spacing: CYSpacing.sm) {
                                VStack(alignment: .leading, spacing: CYSpacing.xs) {
                                    Text(card.merchantName)
                                        .cyText(.bodyMedium)
                                        .foregroundStyle(CYColor.textPrimary)
                                    if let perk = card.perkTitle, !perk.isEmpty {
                                        Text(perk)
                                            .cyText(.meta)
                                            .foregroundStyle(CYColor.brand)
                                    }
                                    if let addr = card.address, !addr.isEmpty {
                                        Text(addr)
                                            .cyText(.meta)
                                            .foregroundStyle(CYColor.textSecondary)
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .cyText(.meta)
                                    .foregroundStyle(CYColor.textSecondary)
                            }
                            .padding(CYSpacing.sm)
                            .background(CYColor.bgSurface)
                            .clipShape(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}
