import SwiftUI

/// Reform plan v9 §20 map-as-entry hub, §12.2 legend and §21 sharing explainer.
/// Presentation only: existing entries call back to the host; pending entries stay disabled.
/// Nothing here requests location permission, reads a fix or calls a sharing endpoint.
struct MapCoreEntryHubView: View {
    let manifest: MapVisualStyleManifest
    let onOpen: (MapCoreEntry) -> Void
    var publicLayers: MapPublicLayerCaller? = nil
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var showsSharingExplainer = false
    init(manifest: MapVisualStyleManifest = .candidate, onOpen: @escaping (MapCoreEntry) -> Void, publicLayers: MapPublicLayerCaller? = nil) {
        self.manifest = manifest; self.onOpen = onOpen; self.publicLayers = publicLayers
    }
    private var appearance: MapAppearance { .resolve(systemIsDark: colorScheme == .dark) }

    var body: some View {
        List {
            Section {
                ForEach(MapCoreEntry.allCases, id: \.self) { entry in
                    Button { onOpen(entry) } label: { entryLabel(entry) }
                        .disabled(entry.availability != .existing)
                        .accessibilityIdentifier("mapCore.entry.\(entry.rawValue)")
                }
            } header: {
                Text("mapCore.entries.title", tableName: "MapCoreEntry").sectionHeading()
            } footer: {
                Text("mapCore.entries.footer", tableName: "MapCoreEntry")
                    .cyText(.meta)
                    .foregroundStyle(CYColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let publicLayers {
                Section {
                    NavigationLink { MapPublicLayerCallerView(caller: publicLayers) } label: {
                        CYListRow(verbatim: Cloud21Copy.phrase(key: "cloud21.map.publicLayers", en: "Public layers", zh: "公开图层", locale: locale), trailing: .none) {
                            CYRowIcon(systemImage: "square.3.layers.3d")
                        }
                    }
                    .accessibilityIdentifier("mapPublic.entry")
                }
            }

            Section {
                ForEach(MapMarkerVisualState.allCases, id: \.self) { state in
                    legendRow(state)
                }
            } header: {
                Text("mapCore.legend.title", tableName: "MapCoreEntry").sectionHeading()
            } footer: {
                VStack(alignment: .leading, spacing: CYSpacing.xs) {
                    Text("mapCore.legend.footer", tableName: "MapCoreEntry")
                        .cyText(.meta)
                        .foregroundStyle(CYColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if manifest.approval == .candidate {
                        Text("mapCore.legend.candidate", tableName: "MapCoreEntry")
                            .cyText(.meta)
                            .foregroundStyle(CYColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("mapCore.legend.candidate")
                    }
                }
            }

            Section {
                LabeledContent {
                    Text("mapCore.share.off", tableName: "MapCoreEntry")
                        .cyText(.numericBody)
                        .foregroundStyle(CYColor.textPrimary)
                } label: {
                    Text("mapCore.share.status", tableName: "MapCoreEntry")
                        .cyText(.body)
                        .foregroundStyle(CYColor.textPrimary)
                }
                .accessibilityIdentifier("mapCore.share.status")
                Text("mapCore.share.permissionIsNotSharing", tableName: "MapCoreEntry")
                    .cyText(.meta)
                    .foregroundStyle(CYColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                CYPillButton("mapCore.share.explain", style: .secondary, tableName: "MapCoreEntry") { showsSharingExplainer = true }
                    .e1ActionRow()
                    .accessibilityIdentifier("mapCore.share.explain")
            } header: {
                Text("mapCore.share.title", tableName: "MapCoreEntry").sectionHeading()
            }
        }
        .listStyle(.insetGrouped)
        .cyGroupedSurface()
        .navigationTitle(Text("mapCore.title", tableName: "MapCoreEntry"))
        .navigationBarTitleDisplayMode(.inline)
        .themeDomain(.player)
        .cySheet(isPresented: $showsSharingExplainer) { Group {
            NavigationStack { LocationShareExplainerView() }
        }.cySheet() }
    }

    private func entryLabel(_ entry: MapCoreEntry) -> some View {
        let open = entry.availability == .existing
        return Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: CYSpacing.sm) {
                    titleBlock(entry, open: open)
                }
            } else {
                HStack(alignment: .center, spacing: CYSpacing.md) {
                    CYRowIcon(systemImage: entry.symbolName)
                    titleBlock(entry, open: open)
                    Spacer(minLength: CYSpacing.sm)
                    if open {
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(CYColor.textSecondary)
                            .accessibilityHidden(true)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func titleBlock(_ entry: MapCoreEntry, open: Bool) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.xxs) {
            MapCoreEntryText.title(entry)
                .cyText(.cardTitle)
                .foregroundStyle(CYColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .firstTextBaseline, spacing: CYSpacing.xs) {
                Image(systemName: open ? "checkmark.circle" : "clock")
                    .cyText(.meta)
                    .foregroundStyle(CYColor.textSecondary)
                    .accessibilityHidden(true)
                MapCoreEntryText.availability(entry.availability)
                    .cyText(.meta)
                    .foregroundStyle(CYColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func legendRow(_ state: MapMarkerVisualState) -> some View {
        HStack(alignment: .center, spacing: CYSpacing.md) {
            Image(systemName: state.symbolName)
                .font(.body.weight(.semibold))
                .foregroundStyle(CYColor.textPrimary)
                .frame(width: 40, height: 40)
                .background(RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous).fill(CYColor.bgRaised))
                .overlay(RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous).stroke(swatch(for: state), lineWidth: state.strokeWidth))
                .accessibilityHidden(true)
            MapCoreEntryText.state(state)
                .cyText(.cardTitle)
                .foregroundStyle(CYColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: CYSpacing.sm)
        }
        .frame(minHeight: CYSpacing.minTouchTarget)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("mapCore.legend.\(state.rawValue)")
    }

    private func swatch(for state: MapMarkerVisualState) -> Color {
        let role: MapSemanticRole = [.completed, .locked, .unavailable].contains(state) ? .completedUnavailable : .currentTargetRoute
        let token = manifest.color(role, appearance)
        return Color(red: token.red, green: token.green, blue: token.blue, opacity: token.opacity)
    }
}

private extension Text {
    func sectionHeading() -> some View {
        cyText(.sectionTitle)
            .foregroundStyle(CYColor.textPrimary)
            .textCase(nil)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Explains every disclosure the future consent needs (W13.5). Start stays disabled while
/// `LocationShareFeature.preciseGrantEnabled` is false; acknowledgements are kept in memory only.
struct LocationShareExplainerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft = LocationShareDraft()
    var body: some View {
        Form {
            Section {
                ForEach(LocationShareDisclosure.allCases, id: \.self) { item in
                    Toggle(isOn: Binding(get: { draft.acknowledged.contains(item) }, set: { if $0 { draft.acknowledge(item) } else { draft.withdraw(item) } })) {
                        MapCoreEntryText.disclosure(item)
                            .cyText(.body)
                            .foregroundStyle(CYColor.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityIdentifier("mapCore.share.disclosure.\(item.rawValue)")
                }
            } footer: {
                Text("mapCore.share.disclosureFooter", tableName: "MapCoreEntry")
                    .cyText(.meta)
                    .foregroundStyle(CYColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Section {
                CYPillButton("mapCore.share.start", tableName: "MapCoreEntry") {}
                    .e1ActionRow()
                    .disabled(true)
                    .accessibilityIdentifier("mapCore.share.start")
                Text("mapCore.share.unavailable", tableName: "MapCoreEntry")
                    .cyText(.meta)
                    .foregroundStyle(CYColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("mapCore.share.unavailable")
            }
        }
        .cyGroupedSurface()
        .navigationTitle(Text("mapCore.share.title", tableName: "MapCoreEntry"))
        .navigationBarTitleDisplayMode(.inline)
        .themeDomain(.player)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button { dismiss() } label: { Text("mapCore.close", tableName: "MapCoreEntry") }.accessibilityIdentifier("mapCore.share.close")
            }
        }
    }
}

/// Literal catalog keys only, so the structural checker can verify every key in the table.
enum MapCoreEntryText {
    static func title(_ entry: MapCoreEntry) -> Text {
        switch entry {
        case .cityOrienteering: Text("mapCore.entry.cityOrienteering", tableName: "MapCoreEntry")
        case .freeExploration: Text("mapCore.entry.freeExploration", tableName: "MapCoreEntry")
        case .merchantSideQuests: Text("mapCore.entry.merchantSideQuests", tableName: "MapCoreEntry")
        case .placeInfo: Text("mapCore.entry.placeInfo", tableName: "MapCoreEntry")
        case .personalFog: Text("mapCore.entry.personalFog", tableName: "MapCoreEntry")
        case .sharedLocation: Text("mapCore.entry.sharedLocation", tableName: "MapCoreEntry")
        case .cityOperation: Text("mapCore.entry.cityOperation", tableName: "MapCoreEntry")
        }
    }
    static func availability(_ value: MapCoreEntry.Availability) -> Text {
        switch value {
        case .existing: Text("mapCore.availability.existing", tableName: "MapCoreEntry")
        case .pendingBackend: Text("mapCore.availability.pendingBackend", tableName: "MapCoreEntry")
        case .pendingDecision: Text("mapCore.availability.pendingDecision", tableName: "MapCoreEntry")
        }
    }
    static func state(_ state: MapMarkerVisualState) -> Text {
        switch state {
        case .standard: Text("mapCore.state.standard", tableName: "MapCoreEntry")
        case .interactive: Text("mapCore.state.interactive", tableName: "MapCoreEntry")
        case .selected: Text("mapCore.state.selected", tableName: "MapCoreEntry")
        case .active: Text("mapCore.state.active", tableName: "MapCoreEntry")
        case .completed: Text("mapCore.state.completed", tableName: "MapCoreEntry")
        case .locked: Text("mapCore.state.locked", tableName: "MapCoreEntry")
        case .unavailable: Text("mapCore.state.unavailable", tableName: "MapCoreEntry")
        case .inReview: Text("mapCore.state.inReview", tableName: "MapCoreEntry")
        }
    }
    static func disclosure(_ item: LocationShareDisclosure) -> Text {
        switch item {
        case .audience: Text("mapCore.disclosure.audience", tableName: "MapCoreEntry")
        case .precision: Text("mapCore.disclosure.precision", tableName: "MapCoreEntry")
        case .duration: Text("mapCore.disclosure.duration", tableName: "MapCoreEntry")
        case .foregroundOnly: Text("mapCore.disclosure.foregroundOnly", tableName: "MapCoreEntry")
        case .stopAnytime: Text("mapCore.disclosure.stopAnytime", tableName: "MapCoreEntry")
        case .alreadySeenCannotBeRecalled: Text("mapCore.disclosure.alreadySeen", tableName: "MapCoreEntry")
        }
    }
}

#if DEBUG
/// Offline fixture: synthetic host callbacks only; no session, reader, location or network.
struct MapCoreEntryFixtureHost: View {
    @State private var opened: MapCoreEntry?
    var body: some View {
        NavigationStack {
            MapCoreEntryHubView { opened = $0 }
                .safeAreaInset(edge: .bottom) {
                    Text(verbatim: opened?.rawValue ?? "none")
                        .font(.caption.monospaced()).padding(8)
                        .accessibilityIdentifier("mapCore.fixture.opened")
                }
        }
        .modifier(AccessibilityFixtureOptions())
    }
}
#endif
