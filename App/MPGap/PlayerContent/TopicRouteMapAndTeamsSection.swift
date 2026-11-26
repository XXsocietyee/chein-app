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
    /// R10-PC-B-N8: a tapped system `Marker` selects its pin id; the change hands the pin to `onSelectPin`.
    @State private var selectedPinID: String?

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
                    LabeledContent {
                        Text("\(completedCount)/\(totalCount)")
                            .monospacedDigit()
                    } label: {
                        Text("topicRoute.progress.title")
                    }
                    ProgressView(value: Double(completedCount), total: Double(max(1, totalCount)))
                }
            }

            if !pins.isEmpty {
                Map(selection: $selectedPinID) {
                    if !isFreeExplore && pins.count >= 2 {
                        MapPolyline(coordinates: pins.map {
                            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
                        })
                        .stroke(Color.accentColor, lineWidth: 3)
                    }
                    ForEach(pins) { pin in
                        // R10-PC-B-N8: system Marker with the route number; green when done, accent otherwise.
                        Marker(pin.name, monogram: Text(verbatim: String(pin.sequence)),
                               coordinate: CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude))
                            .tint(pin.isCompleted ? Color.green : Color.accentColor)
                            .tag(pin.id)
                    }
                }
                .mapControls {
                    MapCompass()
                }
                .frame(height: 220)
                .onChange(of: selectedPinID) { _, id in
                    guard let id, let pin = pins.first(where: { $0.id == id }) else { return }
                    onSelectPin(pin)
                    selectedPinID = nil
                }
            }

            if !teams.isEmpty {
                VStack(alignment: .leading, spacing: CYSpacing.sm) {
                    HStack {
                        Text("topicRoute.teams.title")
                            .font(.headline)
                        Spacer()
                        Button("topicRoute.teams.viewAll", action: onOpenAllTeams)
                            .buttonStyle(.borderless)
                    }
                    ForEach(teams) { team in
                        HStack {
                            Text(team.name)
                            Spacer()
                            Text("\(team.memberCount) 人")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                            if team.missingCount > 0 {
                                Text("还差 \(team.missingCount) 人")
                                    .monospacedDigit()
                                    .foregroundStyle(.tint)
                            }
                        }
                        .font(.subheadline)
                    }
                }
            }

            if isFreeExplore && !merchantCards.isEmpty {
                VStack(alignment: .leading, spacing: CYSpacing.sm) {
                    Text("topicRoute.merchants.title")
                        .font(.headline)
                    ForEach(merchantCards) { card in
                        Button {
                            onSelectMerchant(card)
                        } label: {
                            HStack(spacing: CYSpacing.sm) {
                                VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                                    Text(card.merchantName)
                                        .foregroundStyle(.primary)
                                    if let perk = card.perkTitle, !perk.isEmpty {
                                        Text(perk)
                                            .font(.subheadline)
                                            .foregroundStyle(.tint)
                                    }
                                    if let addr = card.address, !addr.isEmpty {
                                        Text(addr)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.forward")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}
