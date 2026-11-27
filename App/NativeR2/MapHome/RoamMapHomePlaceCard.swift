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
    /// MP roam-place-card rating cell: `/api/city/nodes/{id}` averageRating / ratingCount; a failed read shows 「—」.
    @State private var rating: String?
    @State private var ratingFailed = false

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
                        // MP rpc__row: rating first, then distance.
                        if rating != nil || ratingFailed {
                            Label {
                                Text(verbatim: rating ?? "—").monospacedDigit()
                            } icon: {
                                Image(systemName: "star.fill").foregroundStyle(.yellow)
                            }
                            .labelStyle(.titleAndIcon)
                            .accessibilityLabel(Text("nativeR2.mapHome.card.rating \(rating ?? "—")"))
                            .accessibilityIdentifier("roam.mapHome.card.rating")
                            Text(verbatim: "·")
                        }
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
            // MP roam-place-card: the photo hero comes first, then the facts and the 导航 / 分享 row.
            if case .activity(let card) = pin.payload {
                // MP entry-sheet activity summary: the cover, or the shared route illustration when it has none.
                Section {
                    RoamEntryCover(source: card.activity.coverURL)
                        .frame(height: 160)
                        .listRowInsets(EdgeInsets())
                }
            } else if let url = pin.imageURL {
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
            Section {
                actionRow
            } footer: {
                directionsFooter
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
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
        .task(id: pin.id) { await loadRating() }
    }

    /// MP `_loadRating`: only server POIs (shareKind poi) are read; the card stays usable whatever happens.
    private func loadRating() async {
        rating = nil
        ratingFailed = false
        guard case .place(let place) = pin.payload, place.type == 1, place.id > 0 else { return }
        do {
            let detail = try await dependencies.roamReader.roamNodeDetail(id: place.id)
            guard !Task.isCancelled else { return }
            rating = detail.ratingText
        } catch {
            guard !Task.isCancelled else { return }
            ratingFailed = true
        }
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
            // MP entry sheet: no primary while registered and open; 发起组队 follows the teams instead.
            guard let target = card.destination, let key = card.primaryKey, dependencies.eventDestination != nil else { return nil }
            return CardAction(titleKey: LocalizedStringKey(key),
                              systemImage: key == "roam.w208.entry.register" ? "ticket" : "info.circle",
                              identifier: "roam.mapHome.card.event") {
                model.push(.event(target))
            }
        case .team(let team):
            guard dependencies.nearbyTeamDestination != nil else { return nil }
            return CardAction(titleKey: "nativeR2.mapHome.card.openTeam", systemImage: "person.2", identifier: "roam.mapHome.card.team") {
                model.push(.team(team.teamID))
            }
        case .officialStop, .searchNode:
            return nil
        case .searchActivity(let activity):
            guard dependencies.eventDestination != nil else { return nil }
            return CardAction(titleKey: "roam.w208.entry.viewDetail", systemImage: "info.circle", identifier: "roam.mapHome.card.event") {
                model.push(.event(.activity(activity.id)))
            }
        }
    }

    /// 查看详情 next to a state button (Maps' "More"), only when the primary is not already the detail.
    private var showsDetailButton: Bool {
        guard case .place(let place) = pin.payload, dependencies.placeDetailDestination != nil else { return false }
        return place.readStatus.pendingRedemption == .yes || place.readStatus.discovered == .yes || place.type == 1
    }

    private var shareURL: URL? {
        guard case .place(let place) = pin.payload, place.type == 1, place.id > 0 else { return nil }
        return PublicContentShareLink.poi(id: place.id)
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
            if let url = shareURL {
                // MP roam-place-card 分享 (open-type share, `shareKind` poi): only server POIs carry a public link.
                ShareLink(item: url) { actionLabel("mp.common.share", systemImage: "square.and.arrow.up") }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("roam.mapHome.card.share")
            }
        }
        .controlSize(.large)
    }

    private func actionLabel(_ key: LocalizedStringKey, systemImage: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: systemImage).accessibilityHidden(true)
            Text(key).font(.caption).lineLimit(2).multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
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
            let tags = RoamPlaceNote.visibleTags(place.tags)
            let note = RoamPlaceNote.lookup(tags: place.tags)
            if !about.isEmpty || !tags.isEmpty || note != nil {
                // MP entry place sheet order (pages/roam/index.wxml:53-63): body → 推荐理由 quote → tags → 资料来源.
                Section("nativeR2.mapHome.card.section.about") {
                    if !about.isEmpty { Text(verbatim: about) }
                    if let note { RoamPlaceNoteRows(note: note) }
                    if !tags.isEmpty {
                        Text(verbatim: tags.joined(separator: " · ")).foregroundStyle(.secondary)
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
            }
            // MP entry-sheet order after the primary: N 人参加 → 一起参加 · N 队正在招募 → 发起组队 → 现场动态.
            if card.participantCount > 0 {
                Section {
                    Label { Text("roam.w208.entry.participants \(card.participantCount)") } icon: { Image(systemName: "person.3") }
                        .accessibilityIdentifier("roam.mapHome.card.participants")
                }
            }
            if !card.teams.isEmpty {
                Section {
                    ForEach(card.teams) { team in activityTeamRow(team, card: card) }
                } header: {
                    Text("roam.w208.entry.teams \(card.teams.count)")
                }
            }
            if card.registered && !card.ended, let target = card.destination, dependencies.eventDestination != nil {
                Section {
                    Button { model.push(.event(target)) } label: {
                        Label("roam.w208.entry.createTeam", systemImage: "person.badge.plus")
                    }
                    .accessibilityIdentifier("roam.mapHome.card.createTeam")
                }
            }
            activityMoments(card)
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
        case .searchNode(let node):
            let about = node.description?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let tags = node.tags?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !about.isEmpty || !tags.isEmpty || node.templateTitle != nil {
                Section("nativeR2.mapHome.card.section.about") {
                    if !about.isEmpty { Text(verbatim: about) }
                    if let template = node.templateTitle, !template.isEmpty {
                        LabeledContent("nativeR2.mapHome.card.template") { Text(verbatim: template) }
                    }
                    if !tags.isEmpty { Text(verbatim: tags).foregroundStyle(.secondary) }
                }
            }
        case .searchActivity(let activity):
            Section("nativeR2.mapHome.card.section.time") {
                if let start = activity.startDate, !start.isEmpty {
                    LabeledContent("nativeR2.mapHome.card.start") { Text(verbatim: start) }
                }
                if let end = activity.endDate, !end.isEmpty {
                    LabeledContent("nativeR2.mapHome.card.end") { Text(verbatim: end) }
                }
            }
        }
    }

    /// MP entry-team row: title, members · 队长审核, then 申请加入 (registered) or 报名后申请. A team the viewer
    /// may apply to opens the team page; otherwise the row goes to the activity (MP 去报名).
    @ViewBuilder private func activityTeamRow(_ team: RoamEntryActivityCard.Team, card: RoamEntryActivityCard) -> some View {
        let label = VStack(alignment: .leading, spacing: 4) {
            if team.title.isEmpty { Text("roam.w208.entry.teamUntitled").font(.headline) } else { Text(verbatim: team.title).font(.headline) }
            Text("roam.w208.entry.teamMembers \(team.joinedCount) \(team.maxMembers)").font(.subheadline).foregroundStyle(.secondary)
            Text(LocalizedStringKey(card.registered ? "roam.w208.entry.apply" : "roam.w208.entry.applyAfterRegister"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(card.registered ? Color.accentColor : Color.secondary)
        }
        if team.canApply, dependencies.nearbyTeamDestination != nil {
            Button { model.push(.team(team.teamID)) } label: { label }
                .buttonStyle(.plain)
                .accessibilityIdentifier("roam.mapHome.card.team.\(team.teamID.rawValue)")
        } else if let target = card.destination, dependencies.eventDestination != nil {
            Button { model.push(.event(target)) } label: { label }
                .buttonStyle(.plain)
                .accessibilityIdentifier("roam.mapHome.card.team.\(team.teamID.rawValue)")
        } else {
            label.accessibilityElement(children: .combine)
                .accessibilityIdentifier("roam.mapHome.card.team.\(team.teamID.rawValue)")
        }
    }

    /// MP 现场动态: up to three post photos with the count in the header, else 还没有现场动态.
    @ViewBuilder private func activityMoments(_ card: RoamEntryActivityCard) -> some View {
        let urls = Array(card.liveMomentFeedState.momentURLs.prefix(3)).compactMap { URL(string: $0) }
        Section {
            if urls.isEmpty {
                Text("roam.w208.entry.noMoments")
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("roam.mapHome.card.moments.empty")
            } else {
                HStack(spacing: 8) {
                    ForEach(urls, id: \.self) { url in
                        AsyncImage(url: url) { phase in
                            if let image = phase.image {
                                image.resizable().scaledToFill()
                            } else {
                                Rectangle().fill(.quaternary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .aspectRatio(1, contentMode: .fit)
                        .clipShape(.rect(cornerRadius: CYRadius.inner))
                        .accessibilityHidden(true)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("roam.w208.entry.moments \(urls.count)"))
            }
        } header: {
            if urls.isEmpty { Text("roam.w208.entry.momentsTitle") } else { Text("roam.w208.entry.moments \(urls.count)") }
        }
    }
}
