import SwiftUI
import MapKit
#if canImport(QuestifyCore)
import QuestifyCore
#endif

/// The map home's bottom panel content: search, 漫游 actions, the 附近 list and the cards pushed over it.
@MainActor struct RoamMapHomeSheet: View {
    @Bindable var model: RoamMapHomeModel
    let dependencies: RoamMapHomeDependencies

    var body: some View {
        NavigationStack(path: $model.path) {
            RoamMapHomeSheetRoot(model: model, dependencies: dependencies)
                .navigationDestination(for: RoamMapHomeRoute.self) { route in
                    destination(route)
                }
        }
        .cyFullScreenCover(isPresented: $model.showsLive) {
            NavigationStack {
                if let live = dependencies.liveDestination {
                    live()
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button { model.showsLive = false } label: { Label("action.close", systemImage: "xmark") }
                                    .accessibilityIdentifier("roam.mapHome.live.close")
                            }
                        }
                }
            }
        }
        .cyFullScreenCover(isPresented: $model.showsCityBoard) {
            if let board = dependencies.cityBoardDestination {
                board()
                    .overlay(alignment: .topTrailing) {
                        Button { model.showsCityBoard = false } label: {
                            Label("action.close", systemImage: "xmark").labelStyle(.iconOnly)
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.circle)
                        .padding()
                        .accessibilityIdentifier("roam.mapHome.cityBoard.close")
                    }
            }
        }
        .cySheet(isPresented: $model.showsPassport) {
            dependencies.passportDestination?()
                .presentationDragIndicator(.visible)
        }
        // The team pages are push destinations elsewhere, so each sheet gives them a stack.
        .cySheet(isPresented: $model.showsMyTeams) {
            NavigationStack { dependencies.myTeamsDestination?() }
                .presentationDragIndicator(.visible)
        }
        .cySheet(isPresented: $model.showsNearbyTeams) {
            NavigationStack { dependencies.nearbyTeamsDestination?() }
                .presentationDragIndicator(.visible)
        }
        .cySheet(item: $model.teamSheet) { team in
            NavigationStack { dependencies.nearbyTeamDestination?(team.teamID) }
                .presentationDragIndicator(.visible)
        }
    }

    private func pin(_ id: String) -> RoamMapHomePin? {
        let center = (dependencies.entryReader?.searchArea ?? dependencies.roamReader.searchArea)?.coordinate
        return model.allPins(reader: dependencies.entryReader, center: center).first { $0.id == id }
    }

    @ViewBuilder private func destination(_ route: RoamMapHomeRoute) -> some View {
        switch route {
        case .pin(let id):
            if let pin = pin(id) {
                RoamMapHomePlaceCard(pin: pin, model: model, dependencies: dependencies)
            } else {
                ContentUnavailableView("nativeR2.mapHome.card.gone", systemImage: "mappin.slash")
            }
        case .placeDetail(let id):
            if let item = pin(id)?.roamItem, let make = dependencies.placeDetailDestination {
                make(item)
            } else {
                ContentUnavailableView("nativeR2.mapHome.card.gone", systemImage: "mappin.slash")
            }
        case .event(let target):
            if let make = dependencies.eventDestination {
                make(target)
            } else {
                ContentUnavailableView("nativeR2.mapHome.card.gone", systemImage: "calendar.badge.exclamationmark")
            }
        case .officialRoutes:
            if let reader = dependencies.officialRouteReader {
                RoamMapHomeRoutesList(reader: reader, model: model)
            }
        case .officialRoute(let id):
            if let reader = dependencies.officialRouteReader {
                RoamMapHomeRouteCard(reader: reader, routeID: id, model: model)
            }
        case .search(let keyword):
            if let make = dependencies.searchDestination {
                make(keyword)
            }
        }
    }
}

/// The sheet's root list (Maps home sheet). Peek shows the search field only.
@MainActor private struct RoamMapHomeSheetRoot: View {
    @Bindable var model: RoamMapHomeModel
    let dependencies: RoamMapHomeDependencies
    @State private var location: RoamLocationSettingsSnapshot?

    private var area: RoamSearchArea? { dependencies.entryReader?.searchArea ?? dependencies.roamReader.searchArea }
    private var entryState: RoamEntryPeekState? { dependencies.entryReader.map { model.entry.visibleState(reader: $0) } }
    private var pins: [RoamMapHomePin] {
        model.listPins(from: model.allPins(reader: dependencies.entryReader, center: area?.coordinate))
    }
    private var isSearching: Bool { !model.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var locationDenied: Bool {
        guard let location else { return false }
        return !location.servicesEnabled || location.authorization == .denied || location.authorization == .restricted
    }
    private var isLoading: Bool {
        entryState == .loading || model.placesPhase == .loading || (model.category == .routes && model.stopsPhase == .loading)
    }
    private var readFailed: Bool {
        entryState == .failed || model.placesPhase == .failed || (model.category == .routes && model.stopsPhase == .failed)
    }

    var body: some View {
        List {
            if isSearching {
                searchSections
            } else {
                if area == nil { areaSection }
                roamSection
                nearbySection
                moreSection
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(Text("tabBar.roam"))
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $model.query, isPresented: $model.searchActive,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: Text("nativeR2.mapHome.search.prompt"))
        .onChange(of: model.searchActive) { _, active in if active { model.detent = .large } }
        .onSubmit(of: .search) { model.detent = .medium }
        .refreshable { model.reloadGeneration += 1 }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { mapMenu }
        }
        .task { location = try? await dependencies.locationSettings?.readStatus() }
        .accessibilityIdentifier("roam.mapHome.sheet")
    }

    // MARK: Sections

    @ViewBuilder private var areaSection: some View {
        Section {
            ContentUnavailableView {
                Label("nativeR2.mapHome.area.required", systemImage: "mappin.and.ellipse")
            } description: {
                Text("nativeR2.mapHome.area.required.detail")
            } actions: {
                if let onChooseArea = dependencies.onChooseArea {
                    Button("roam.area.title", action: onChooseArea)
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("roam.mapHome.area")
                }
            }
        }
    }

    @ViewBuilder private var roamSection: some View {
        Section {
            if dependencies.liveDestination != nil {
                LabeledContent {
                    Button("nativeR2.mapHome.start.action") { model.showsLive = true }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("roam.go")
                } label: {
                    Label("nativeR2.mapHome.start", systemImage: "figure.walk")
                }
            }
            Button {
                model.category = .teams
                model.detent = .medium
            } label: {
                LabeledContent {
                    if !model.teams.isEmpty { Text(model.teams.count, format: .number) }
                } label: {
                    Label("nativeR2.mapHome.findTeams", systemImage: "person.2")
                }
            }
            .accessibilityIdentifier("roam.home.intro.teams")
            if dependencies.nearbyTeamsDestination != nil {
                Button { model.showsNearbyTeams = true } label: {
                    Label("nativeR2.mapHome.teamsMap", systemImage: "map")
                }
                .accessibilityIdentifier("roam.home.intro.map")
            }
            if dependencies.myTeamsDestination != nil {
                Button { model.showsMyTeams = true } label: {
                    Label("nativeR2.mapHome.myTeams", systemImage: "person.crop.circle.badge.checkmark")
                }
                .accessibilityIdentifier("roam.mapHome.myTeams")
            }
        } header: {
            Text("nativeR2.mapHome.section.roam")
        }
    }

    @ViewBuilder private var nearbySection: some View {
        Section {
            if !pins.isEmpty {
                ForEach(pins) { pin in RoamMapHomePinRow(pin: pin) }
            } else if isLoading {
                ForEach(0..<4, id: \.self) { _ in
                    Label("nativeR2.mapHome.loading", systemImage: "mappin")
                        .redacted(reason: .placeholder)
                }
            } else if locationDenied && area == nil {
                ContentUnavailableView {
                    Label("nativeR2.mapHome.location.denied", systemImage: "location.slash")
                } actions: {
                    if let settings = dependencies.locationSettings {
                        Button("nativeR2.mapHome.location.openSettings") { Task { _ = await settings.openAppSettings() } }
                            .buttonStyle(.bordered)
                    }
                }
            } else if entryState == .login, model.places.isEmpty {
                ContentUnavailableView {
                    Label("nativeR2.mapHome.signIn.title", systemImage: "person.crop.circle")
                } actions: {
                    if let onOpenAccount = dependencies.onOpenAccount {
                        Button("nativeR2.mapHome.signIn", action: onOpenAccount).buttonStyle(.bordered)
                    }
                }
            } else if entryState == .denied, model.places.isEmpty {
                ContentUnavailableView("nativeR2.mapHome.denied", systemImage: "lock")
            } else if readFailed {
                ContentUnavailableView {
                    Label("nativeR2.mapHome.nearby.failed", systemImage: "exclamationmark.triangle")
                } actions: {
                    Button("action.retry") { model.reloadGeneration += 1 }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("roam.home.peek.refresh")
                }
            } else if area != nil {
                ContentUnavailableView("nativeR2.mapHome.nearby.empty", systemImage: "mappin.slash",
                                       description: Text("nativeR2.mapHome.nearby.empty.detail"))
            }
        } header: {
            Picker("nativeR2.mapHome.section.nearby", selection: $model.category) {
                ForEach(RoamMapHomeCategory.allCases) { category in
                    Text(category.titleKey).tag(category)
                }
            }
            .pickerStyle(.segmented)
            .textCase(nil)
            .accessibilityIdentifier("city.roam.nearby")
        } footer: {
            if dependencies.roamReader.isOfflineExample {
                Label("nativeR2.mapHome.offline", systemImage: "wifi.slash")
            } else if !pins.isEmpty, readFailed {
                Label("nativeR2.mapHome.partialFailure", systemImage: "exclamationmark.triangle")
            }
        }
    }

    @ViewBuilder private var moreSection: some View {
        Section {
            if dependencies.passportDestination != nil {
                Button { model.showsPassport = true } label: {
                    Label("nativeR2.mapHome.passport", systemImage: "book.closed")
                }
                .accessibilityIdentifier("city.roam.passport")
            }
            if dependencies.officialRouteReader != nil {
                NavigationLink(value: RoamMapHomeRoute.officialRoutes) {
                    Label("nativeR2.mapHome.officialRoutes", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                }
                .accessibilityIdentifier("roam.mapHome.officialRoutes")
            }
            if dependencies.cityBoardDestination != nil {
                Button { model.showsCityBoard = true } label: {
                    Label("nativeR2.mapHome.cityBoard", systemImage: "square.grid.3x3")
                }
                .accessibilityIdentifier("city.roam.board")
            }
        }
    }

    @ViewBuilder private var searchSections: some View {
        Section {
            if pins.isEmpty {
                ContentUnavailableView.search(text: model.query)
            } else {
                ForEach(pins) { pin in RoamMapHomePinRow(pin: pin) }
            }
        }
        if dependencies.searchDestination != nil {
            Section {
                NavigationLink(value: RoamMapHomeRoute.search(model.query.trimmingCharacters(in: .whitespacesAndNewlines))) {
                    LabeledContent {
                        Text(verbatim: model.query)
                    } label: {
                        Label("nativeR2.mapHome.searchMap", systemImage: "magnifyingglass")
                    }
                }
                .accessibilityIdentifier("roam.search")
            }
        }
    }

    // MARK: Toolbar menus

    /// Maps' "Choose Map": map style, range, the City board mode and the search area.
    private var mapMenu: some View {
        Menu {
            Picker("nativeR2.mapHome.mapModes", selection: $model.satellite) {
                Label("nativeR2.mapHome.mapStyle.explore", systemImage: "map").tag(false)
                Label("nativeR2.mapHome.mapStyle.satellite", systemImage: "globe.asia.australia").tag(true)
            }
            .accessibilityIdentifier("roam.layer")
            Picker("nativeR2.mapHome.range", selection: $model.radius) {
                ForEach(RoamMapHomeModel.radiusOptions, id: \.self) { meters in
                    Text(Measurement(value: Double(meters) / 1000, unit: UnitLength.kilometers),
                         format: .measurement(width: .abbreviated)).tag(meters)
                }
            }
            .accessibilityIdentifier("roam.radius")
            if dependencies.cityBoardDestination != nil {
                Button { model.showsCityBoard = true } label: {
                    Label("nativeR2.mapHome.cityBoard", systemImage: "square.grid.3x3")
                }
            }
            if let onChooseArea = dependencies.onChooseArea {
                Button(action: onChooseArea) { Label("roam.area.title", systemImage: "mappin.and.ellipse") }
            }
        } label: {
            Label("nativeR2.mapHome.mapModes", systemImage: "square.stack.3d.up")
        }
        .accessibilityIdentifier("roam.mapHome.mapModes")
    }
}

/// One 附近 row: kind symbol, title, kind · distance (Maps' search result row).
@MainActor struct RoamMapHomePinRow: View {
    let pin: RoamMapHomePin
    var body: some View {
        NavigationLink(value: RoamMapHomeRoute.pin(pin.id)) {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: pin.title).lineLimit(1)
                    HStack(spacing: 4) {
                        Text(pin.kindKey)
                        if let meters = pin.distanceMeters {
                            Text(verbatim: "·")
                            Text(Measurement(value: meters, unit: UnitLength.meters), format: .measurement(width: .abbreviated, usage: .road))
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }
            } icon: {
                Image(systemName: pin.systemImage).foregroundStyle(pin.tint)
            }
        }
        .accessibilityIdentifier("city.nearby." + pin.id)
    }
}
