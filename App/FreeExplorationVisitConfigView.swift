import SwiftUI

/// FE-STORY 7.10 author control: per place 「到访方式」 GPS (default) / scan / online only, and
/// a 300 / 400 / 500 m radius for GPS. Saving needs the author-write grant (default off);
/// nothing changes locally until the server's list confirms it, and an unknown save is
/// re-read, never re-sent. Mounted in `ProjectEditView` for saved free-explore topics through
/// `FreeExplorationVisitConfigEntrySection` (C-F6); both routes stay behind their default-off gates.
@MainActor struct FreeExplorationVisitConfigView: View {
    @State private var model: FreeExplorationVisitConfigModel
    init(model: FreeExplorationVisitConfigModel) { _model = State(initialValue: model) }
    var body: some View {
        List {
            Section {
                Text("feVisitConfig.hint").font(.subheadline)
                if !model.canWrite, model.phase == .ready {
                    Label("feVisitConfig.disabled", systemImage: "lock").font(.footnote).foregroundStyle(.secondary)
                        .accessibilityIdentifier("feVisitConfig.disabled")
                }
            }
            switch model.phase {
            case .idle, .loading: ProgressView("feVisitConfig.loading")
            case .failed(let error):
                Label(LocalizedStringKey(error.localizationKey), systemImage: "exclamationmark.triangle")
                Button("feVisitConfig.reload", systemImage: "arrow.clockwise") { Task { await model.load() } }
            case .ready:
                if model.rows.isEmpty { Text("feVisitConfig.empty") }
                ForEach(model.rows) { row in
                    FreeExplorationVisitConfigRowView(row: row, model: model)
                        .id("\(row.id)-\(row.visitCheck.rawValue)-\(row.visitRadius ?? 0)")
                }
            }
        }.navigationTitle("feVisitConfig.title").accessibilityIdentifier("feVisitConfig.list")
            .task { if model.phase == .idle { await model.load() } }
            .refreshable { await model.load() }
    }
}

@MainActor private struct FreeExplorationVisitConfigRowView: View {
    let row: FreeExplorationVisitConfigRow
    let model: FreeExplorationVisitConfigModel
    @State private var check: PlayVisitCheck
    @State private var radius: Int
    init(row: FreeExplorationVisitConfigRow, model: FreeExplorationVisitConfigModel) {
        self.row = row; self.model = model
        _check = State(initialValue: row.visitCheck)
        _radius = State(initialValue: row.effectiveRadius ?? PlayArrivalPolicy.visitDefaultRadiusMeters)
    }
    private var changed: Bool { check != row.visitCheck || (check == .gps && radius != row.effectiveRadius) }
    var body: some View {
        Section {
            Picker("feVisitConfig.method", selection: $check) {
                Label("feVisitConfig.method.gps", systemImage: "location").tag(PlayVisitCheck.gps)
                Label("feVisitConfig.method.scan", systemImage: "qrcode.viewfinder").tag(PlayVisitCheck.scan)
                Label("feVisitConfig.method.online", systemImage: "globe").tag(PlayVisitCheck.online)
            }.accessibilityIdentifier("feVisitConfig.method.\(row.id)")
            if check == .gps {
                Picker("feVisitConfig.radius", selection: $radius) {
                    ForEach(FreeExplorationVisitConfigChange.radiusChoices, id: \.self) { value in
                        Text("feVisitConfig.radius.value \(value)").tag(value)
                    }
                }.accessibilityIdentifier("feVisitConfig.radius.\(row.id)")
                if !row.hasCoordinates {
                    Label("feVisitConfig.error.coordinates", systemImage: "mappin.slash").font(.footnote)
                }
            }
            Button {
                Task { await model.save(nodeID: row.id, visitCheck: check, visitRadius: check == .gps ? radius : nil) }
            } label: {
                Label("feVisitConfig.save", systemImage: "checkmark").frame(maxWidth: .infinity, minHeight: 44)
            }.disabled(!model.canWrite || !changed || (check == .gps && !row.hasCoordinates))
                .accessibilityIdentifier("feVisitConfig.save.\(row.id)")
            status
        } header: {
            FreeExplorationStoreName(name: row.name)
        }
    }
    @ViewBuilder private var status: some View {
        switch model.saves[row.id] {
        case nil: EmptyView()
        case .saving?: ProgressView("feVisitConfig.saving")
        case .saved?: Label("feVisitConfig.saved", systemImage: "checkmark.circle.fill")
        case .failed(let error)?: Label(LocalizedStringKey(error.localizationKey), systemImage: "exclamationmark.triangle")
        case .unknown?:
            Label("feVisitConfig.unknown", systemImage: "questionmark.circle")
            Button("feVisitConfig.reload", systemImage: "arrow.clockwise") { Task { await model.reread() } }
        }
    }
}


/// C-F6 (MP pages/publish/fabu/theme-fe-visit): mounts the per-place 「到访方式」 editor in the topic editor
/// for a saved free-explore topic. The factory is installed once at the app root; fixtures and previews get
/// nil and show nothing. Reads and writes stay behind `PlayRuntimePortRouteGate` (both default off).
private struct FreeExplorationVisitConfigFactoryKey: EnvironmentKey {
    static let defaultValue: ((_ topicID: Int, _ authorWrites: Bool) -> FreeExplorationVisitConfigModel?)? = nil
}

extension EnvironmentValues {
    var freeExplorationVisitConfig: ((_ topicID: Int, _ authorWrites: Bool) -> FreeExplorationVisitConfigModel?)? {
        get { self[FreeExplorationVisitConfigFactoryKey.self] }
        set { self[FreeExplorationVisitConfigFactoryKey.self] = newValue }
    }
}

extension AppSession {
    /// Nil while the read gate is off, signed out, or unconfigured. Writes need both the write gate and the
    /// editor's own author-write grant (`authorWrites`, derived from the approved project write authority).
    func freeExplorationVisitConfigModel(topicID: Int, authorWrites: Bool) -> FreeExplorationVisitConfigModel? {
        guard PlayRuntimePortRouteGate.freeExploreVisitConfigRead, topicID > 0, isConfigured, isSignedIn,
              let configuration = regionalConfiguration?.apiConfiguration else { return nil }
        let service = FreeExplorationVisitConfigService(
            configuration: configuration, transport: compositionTransport,
            authorWrites: PlayRuntimePortRouteGate.freeExploreVisitConfigWrite && authorWrites,
            readsEnabled: PlayRuntimePortRouteGate.freeExploreVisitConfigRead,
            token: { [weak self] in self?.token })
        return FreeExplorationVisitConfigModel(topicID: topicID, service: service)
    }
}

/// One disclosure row 到访方式 › in the topic editor. Absent when no factory or the gate gives no model.
@MainActor struct FreeExplorationVisitConfigEntrySection: View {
    let topicID: Int
    let authorWrites: Bool
    @Environment(\.freeExplorationVisitConfig) private var factory

    var body: some View {
        if let factory, let model = factory(topicID, authorWrites) {
            Section {
                NavigationLink {
                    FreeExplorationVisitConfigView(model: model)
                } label: {
                    Label("feVisitConfig.title", systemImage: "location.viewfinder")
                }
                .accessibilityIdentifier("projectEdit.feVisitConfig")
            }
        }
    }
}
