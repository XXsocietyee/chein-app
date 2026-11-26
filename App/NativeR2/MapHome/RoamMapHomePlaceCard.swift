import SwiftUI
import MapKit
#if canImport(QuestifyCore)
import QuestifyCore
#endif

/// The Maps place card, pushed in the sheet when a marker or a 附近 row is tapped: header, action button
/// row, photo, then `LabeledContent` details. It reads nothing itself: it shows the facts the pin's read
/// already returned. The state-driven primary button opens the same page the old roam root opened
/// (`RoamItemDetailView` / activity / topic / team), so every POI rule (`RoamPOIActionModel`) stays there.
@MainActor struct RoamMapHomePlaceCard: View {
    let pin: RoamMapHomePin
    @Bindable var model: RoamMapHomeModel
    let dependencies: RoamMapHomeDependencies
    @State private var externalMaps: PlatformExternalMaps?
    @State private var confirmingDirections = false

    private struct CardAction {
        let titleKey: LocalizedStringKey
        let systemImage: String
        var disabled = false
        let identifier: String
        let run: () -> Void
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text(verbatim: pin.title)
                        .font(.title2.bold())
                        .accessibilityAddTraits(.isHeader)
                    HStack(spacing: 4) {
                        Text(pin.kindKey)
                        if let meters = pin.distanceMeters {
                            Text(verbatim: "·")
                            Text(Measurement(value: meters, unit: UnitLength.meters), format: .measurement(width: .abbreviated, usage: .road))
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
            }
            Section {
                actionRow
            } footer: {
                directionsFooter
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            if let url = pin.imageURL {
                Section {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFill()
                        } else if phase.error != nil {
                            Image(systemName: "photo").font(.largeTitle).foregroundStyle(.secondary)
                        } else {
                            ProgressView()
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .aspectRatio(16.0 / 9.0, contentMode: .fit)
                    .clipped()
                    .listRowInsets(EdgeInsets())
                    .accessibilityLabel(Text("nativeR2.mapHome.card.photo"))
                }
            }
            kindSections
            Section("nativeR2.mapHome.card.section.details") {
                if let address = pin.address {
                    LabeledContent("nativeR2.mapHome.card.address") { Text(verbatim: address).multilineTextAlignment(.trailing) }
                }
                LabeledContent("nativeR2.mapHome.card.type") { Text(pin.kindKey) }
                if let meters = pin.distanceMeters {
                    LabeledContent("nativeR2.mapHome.card.distance") {
                        Text(Measurement(value: meters, unit: UnitLength.meters), format: .measurement(width: .abbreviated, usage: .road))
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    model.path.removeAll()
                } label: {
                    Label("action.close", systemImage: "xmark.circle.fill").symbolRenderingMode(.hierarchical)
                }
                .accessibilityIdentifier("roam.mapHome.card.close")
            }
        }
        .confirmationDialog("nativeR2.mapHome.card.navigate.confirm", isPresented: $confirmingDirections, titleVisibility: .visible) {
            Button("nativeR2.mapHome.card.navigate.open") {
                let destination = mapDestination
                Task { await externalMaps?.openReviewedDestination(destination) }
            }
            Button("nativeR2.mapHome.card.copyAddress") { externalMaps?.copySelectedAddress() }
        }
        .accessibilityIdentifier("roam.detail")
    }

    // MARK: Action row (Maps: one prominent action, then bordered ones)

    private var primaryAction: CardAction? {
        switch pin.payload {
        case .place(let place):
            let detail = { model.push(.placeDetail(pin.id)) }
            guard dependencies.placeDetailDestination != nil else { return nil }
            if place.readStatus.pendingRedemption == .yes {
                return CardAction(titleKey: "nativeR2.mapHome.card.redeem", systemImage: "qrcode", identifier: "roam.mapHome.card.redeem", run: detail)
            }
            if place.readStatus.discovered == .yes {
                return CardAction(titleKey: "nativeR2.mapHome.card.done", systemImage: "checkmark.circle.fill", disabled: true,
                                  identifier: "roam.mapHome.card.done", run: {})
            }
            if place.type == 1 {
                return CardAction(titleKey: "nativeR2.mapHome.card.challenge", systemImage: "flag.checkered", identifier: "roam.mapHome.card.challenge", run: detail)
            }
            return CardAction(titleKey: "roam.w208.entry.viewDetail", systemImage: "info.circle", identifier: "roam.mapHome.card.detail", run: detail)
        case .routeStop(let node):
            if let topic = node.topicId, topic > 0, dependencies.eventDestination != nil {
                return CardAction(titleKey: "nativeR2.mapHome.card.viewTopic", systemImage: "map", identifier: "roam.mapHome.card.topic") {
                    model.push(.event(.topic(topic)))
                }
            }
            guard dependencies.placeDetailDestination != nil else { return nil }
            return CardAction(titleKey: "roam.w208.entry.viewDetail", systemImage: "info.circle", identifier: "roam.mapHome.card.detail") {
                model.push(.placeDetail(pin.id))
            }
        case .activity(let card):
            guard let target = card.destination, dependencies.eventDestination != nil else { return nil }
            return CardAction(titleKey: LocalizedStringKey(card.primaryKey ?? "roam.w208.entry.viewDetail"),
                              systemImage: card.primaryKey == "roam.w208.entry.register" ? "ticket" : "info.circle",
                              identifier: "roam.mapHome.card.event") {
                model.push(.event(target))
            }
        case .team(let team):
            guard dependencies.nearbyTeamDestination != nil else { return nil }
            return CardAction(titleKey: "nativeR2.mapHome.card.openTeam", systemImage: "person.2", identifier: "roam.mapHome.card.team") {
                model.teamSheet = RoamMapHomeTeamSheet(teamID: team.teamID)
            }
        case .officialStop:
            return nil
        }
    }

    /// 查看详情 next to a state button (Maps' "More"), only when the primary is not already the detail.
    private var showsDetailButton: Bool {
        guard case .place(let place) = pin.payload, dependencies.placeDetailDestination != nil else { return false }
        return place.readStatus.pendingRedemption == .yes || place.readStatus.discovered == .yes || place.type == 1
    }

    private var canNavigate: Bool {
        dependencies.makeExternalMaps != nil && mapDestination.hasCoordinates
    }

    private var mapDestination: PlatformMapDestination {
        PlatformMapDestination(name: pin.title, address: pin.address, latitude: pin.latitude, longitude: pin.longitude)
    }

    private var actionRow: some View {
        HStack(spacing: 8) {
            if let primary = primaryAction {
                Button(action: primary.run) { actionLabel(primary.titleKey, systemImage: primary.systemImage) }
                    .buttonStyle(.borderedProminent)
                    .disabled(primary.disabled)
                    .accessibilityIdentifier(primary.identifier)
            }
            if canNavigate {
                Button {
                    if externalMaps == nil { externalMaps = dependencies.makeExternalMaps?() }
                    externalMaps?.select(mapDestination)
                    confirmingDirections = true
                } label: {
                    actionLabel("nativeR2.mapHome.card.navigate", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("roam.mapHome.card.navigate")
            }
            if showsDetailButton {
                Button { model.push(.placeDetail(pin.id)) } label: {
                    actionLabel("roam.w208.entry.viewDetail", systemImage: "info.circle")
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("roam.mapHome.card.detail")
            }
        }
        .controlSize(.large)
    }

    private func actionLabel(_ key: LocalizedStringKey, systemImage: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: systemImage).accessibilityHidden(true)
            Text(key).font(.caption).lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder private var directionsFooter: some View {
        switch externalMaps?.state {
        case .launchFailed?: Label("nativeR2.mapHome.card.navigate.failed", systemImage: "exclamationmark.triangle")
        case .noCoordinates?: Label("nativeR2.mapHome.card.navigate.failed", systemImage: "exclamationmark.triangle")
        case .copied?: Label("nativeR2.mapHome.card.copied", systemImage: "doc.on.doc")
        case .copyFailed?: Label("nativeR2.mapHome.card.copyFailed", systemImage: "exclamationmark.triangle")
        default: EmptyView()
        }
    }

    // MARK: Kind sections

    @ViewBuilder private var kindSections: some View {
        switch pin.payload {
        case .place(let place):
            let about = (place.merchantDescriptionText ?? place.description)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !about.isEmpty || !place.tags.isEmpty {
                Section("nativeR2.mapHome.card.section.about") {
                    if !about.isEmpty { Text(verbatim: about) }
                    if !place.tags.isEmpty {
                        Text(verbatim: place.tags.joined(separator: " · ")).foregroundStyle(.secondary)
                    }
                }
            }
        case .routeStop:
            EmptyView()
        case .activity(let card):
            Section("nativeR2.mapHome.card.section.time") {
                if let start = card.activity.startDate, !start.isEmpty {
                    LabeledContent("nativeR2.mapHome.card.start") { Text(verbatim: start) }
                }
                if let end = card.activity.endDate, !end.isEmpty {
                    LabeledContent("nativeR2.mapHome.card.end") { Text(verbatim: end) }
                }
                if card.participantCount > 0 {
                    LabeledContent("nativeR2.mapHome.card.participants") { Text(card.participantCount, format: .number) }
                }
            }
            if !card.teams.isEmpty {
                Section("nativeR2.mapHome.card.section.teams") {
                    ForEach(card.teams) { team in
                        Button {
                            model.teamSheet = RoamMapHomeTeamSheet(teamID: team.teamID)
                        } label: {
                            LabeledContent {
                                Text(verbatim: String(team.joinedCount) + "/" + String(team.maxMembers))
                            } label: {
                                Label { Text(verbatim: team.title) } icon: { Image(systemName: "person.2") }
                            }
                        }
                        .disabled(dependencies.nearbyTeamDestination == nil)
                    }
                }
            }
        case .team(let team):
            Section("nativeR2.mapHome.card.section.team") {
                if !team.activityName.isEmpty {
                    LabeledContent("nativeR2.mapHome.card.teamActivity") { Text(verbatim: team.activityName) }
                }
                if !team.leaderName.isEmpty {
                    LabeledContent("nativeR2.mapHome.card.leader") { Text(verbatim: team.leaderName) }
                }
                if let joined = team.reportedJoinedCount, let maximum = team.reportedMaxMembers {
                    LabeledContent("nativeR2.mapHome.card.members") { Text(verbatim: String(joined) + "/" + String(maximum)) }
                }
            }
        case .officialStop(let node):
            if node.stayMinutes > 0 {
                Section {
                    LabeledContent("nativeR2.mapHome.card.stay") {
                        Text(Measurement(value: Double(node.stayMinutes), unit: UnitDuration.minutes), format: .measurement(width: .abbreviated))
                    }
                }
            }
        }
    }
}
