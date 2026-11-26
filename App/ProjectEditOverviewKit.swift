import MapKit
import SwiftUI

// Code r3 · C1 创作页 (Figma 237:31646, verify-r1 3.4): the parts of the topic editor's first screen.
// The save chip + 列表 / 地图 row, the 主题详情 card, chapter cards, the node map, and the undo toast that is the
// editor's one delete rule. Copy lives in the `OpsR3` string table.

/// Localized text in the `OpsR3` string table (code r3 · ops worker).
enum OpsR3Text {
    static let table = "OpsR3"
    static func text(_ key: String) -> Text { Text(LocalizedStringKey(key), tableName: table) }
    static func string(_ key: String, locale: Locale) -> String {
        String(localized: LocalizedStringResource(String.LocalizationValue(key), table: table, locale: locale))
    }
}

/// 列表 / 地图 on the 创作页 (Figma 237:31646 · 237:32444).
enum ProjectEditCanvas: String, CaseIterable, Identifiable {
    case list, map
    var id: String { rawValue }
    var key: String { "editor.canvas." + rawValue }
}

/// The row under the nav bar: the save chip leading, the 列表 / 地图 control trailing (150 pt).
struct ProjectEditOverviewBar: View {
    let saveState: EditorSaveState
    var saveDetail: Text? = nil
    @Binding var canvas: ProjectEditCanvas
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack(spacing: CYSpacing.sm) {
            EditorSaveChip(state: saveState, detail: saveDetail)
            Spacer(minLength: CYSpacing.sm)
            Picker(selection: $canvas) {
                ForEach(ProjectEditCanvas.allCases) { item in
                    OpsR3Text.text(item.key).tag(item)
                }
            } label: { OpsR3Text.text("editor.canvas.label") }
            .pickerStyle(.segmented)
            .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : 150)
            .accessibilityIdentifier("projectEdit.canvas")
        }
        .sensoryFeedback(.selection, trigger: canvas)
    }
}

/// `主题详情` row: cover thumbnail, the topic name, and one status line (还有 N 项未填, or 已填完).
struct ProjectEditTopicCard: View {
    let name: String
    let cover: String
    let missing: Int
    let action: () -> Void
    @ScaledMetric(relativeTo: .body) private var coverWidth: CGFloat = 44

    var body: some View {
        Button(action: action) {
            HStack {
                CYCachedAsyncImage(cover.isEmpty ? nil : cover, role: .cover)
                    .frame(width: coverWidth, height: coverWidth * 58 / 44)
                    .clipped()
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Group {
                        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            OpsR3Text.text("editor.topic.untitled")
                        } else {
                            Text(verbatim: name)
                        }
                    }
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    if missing > 0 {
                        Label { Text("editor.topic.missing \(missing)", tableName: OpsR3Text.table) }
                            icon: { Image(systemName: "exclamationmark.circle.fill") }
                            .font(.subheadline)
                            .foregroundStyle(.red)
                    } else {
                        OpsR3Text.text("editor.topic.complete").font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("projectEdit.topicCard")
    }

    /// The topic-detail fields this card counts: name, description, cover, categories, start and end.
    static func missingCount(_ draft: ProjectEditDraft) -> Int {
        let blank: (String) -> Bool = { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        return [blank(draft.name), blank(draft.description), blank(draft.imgUrl), draft.categoryIDs.isEmpty,
                blank(draft.startDate), blank(draft.endDate)].filter { $0 }.count
    }
}

/// 地图 view of the 创作页 (Figma 237:32444): every node with usable coordinates as a system `Marker`; selecting one
/// opens the Apple Maps-style place sheet with 编辑节点. Nodes without coordinates are counted under the map.
struct ProjectEditNodeMap<Destination: View>: View {
    struct Pin: Identifiable, Hashable {
        let id: String
        let chapterID: String
        let ordinal: Int
        let name: String
        let address: String
        let coordinate: CLLocationCoordinate2D
        static func == (lhs: Pin, rhs: Pin) -> Bool { lhs.id == rhs.id }
        func hash(into hasher: inout Hasher) { hasher.combine(id) }
    }
    let chapters: [ProjectEditChapter]
    /// r4 (`237:32444`): `false` in the Form is a still preview (no pan, no pins to tap, so a drag over it scrolls the
    /// page) that opens the full-bleed page; `true` is that page: edge to edge under the bars, every gesture on.
    var fullBleed: Bool = false
    @ViewBuilder let destination: (_ chapterID: String, _ nodeID: String) -> Destination
    @State private var selection: String?
    @State private var editing: Pin?
    @State private var position: MapCameraPosition = .automatic

    private var pins: [Pin] {
        var ordinal = 0
        return chapters.flatMap { chapter in
            chapter.nodes.compactMap { node -> Pin? in
                ordinal += 1
                guard node.hasUsableCoordinates, let lon = Double(node.longitude), let lat = Double(node.latitude) else { return nil }
                return Pin(id: node.id, chapterID: chapter.id, ordinal: ordinal, name: node.name, address: node.address,
                           coordinate: .init(latitude: lat, longitude: lon))
            }
        }
    }
    private var unplaced: Int { chapters.reduce(0) { $0 + $1.nodes.count } - pins.count }

    var body: some View {
        let pins = pins
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            Map(position: $position, interactionModes: fullBleed ? .all : [], selection: fullBleed ? $selection : .constant(nil)) {
                ForEach(pins) { pin in
                    Marker(pin.name.isEmpty ? "—" : pin.name, monogram: Text(verbatim: "\(pin.ordinal)"), coordinate: pin.coordinate)
                        .tag(pin.id)
                }
            }
            .mapStyle(.standard(emphasis: .muted, pointsOfInterest: .excludingAll))
            .onAppear { position = Self.camera(for: pins) }
            .mapControls { if fullBleed { MapCompass(); MapScaleView() } }
            .frame(maxWidth: .infinity)
            .frame(height: fullBleed ? nil : 220)
            .frame(maxHeight: fullBleed ? .infinity : nil)
            .ignoresSafeArea(.container, edges: fullBleed ? [.top, .bottom] : [])
            .overlay {
                if pins.isEmpty {
                    ContentUnavailableView {
                        Label { OpsR3Text.text("editor.map.empty.title") } icon: { Image(systemName: "mappin.slash") }
                    } description: {
                        OpsR3Text.text("editor.map.empty.message")
                    }
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if !fullBleed, !pins.isEmpty {
                    // The preview's one action: opens the full-bleed page (the label names it).
                    NavigationLink { ProjectEditNodeMapPage(chapters: chapters, destination: destination) } label: {
                        Label { OpsR3Text.text("editor.map.open") } icon: { Image(systemName: "arrow.up.left.and.arrow.down.right") }
                    }
                    .buttonStyle(.bordered)
                    .padding(CYSpacing.sm)
                    .accessibilityIdentifier("projectEdit.map.open")
                }
            }
            .sensoryFeedback(.selection, trigger: selection)
            .sheet(isPresented: Binding(get: { fullBleed && pins.contains { $0.id == selection } },
                                        set: { if !$0 { selection = nil } })) {
                if let pin = pins.first(where: { $0.id == selection }) {
                    nodeSheet(pin)
                        .presentationDetents([.height(180), .medium])
                        .presentationBackgroundInteraction(.enabled(upThrough: .height(180)))
                }
            }
            .navigationDestination(item: $editing) { pin in destination(pin.chapterID, pin.id) }
            if unplaced > 0 {
                Text("editor.map.unplaced \(unplaced)", tableName: OpsR3Text.table)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, fullBleed ? CYSpacing.lg : 0)
            }
        }
        .accessibilityIdentifier(Self.identifier(fullBleed: fullBleed))
    }

    /// Not localization keys: the preview's and the page's accessibility identifiers.
    static func identifier(fullBleed: Bool) -> String {
        let suffix = fullBleed ? "mapPage" : "map"
        return "projectEdit." + suffix
    }

    /// A region that holds every pin with a margin; a single pin gets a street-level span instead of the closest zoom.
    static func camera(for pins: [Pin]) -> MapCameraPosition {
        guard let first = pins.first else { return .automatic }
        var minLat = first.coordinate.latitude, maxLat = minLat, minLon = first.coordinate.longitude, maxLon = minLon
        for pin in pins {
            minLat = min(minLat, pin.coordinate.latitude); maxLat = max(maxLat, pin.coordinate.latitude)
            minLon = min(minLon, pin.coordinate.longitude); maxLon = max(maxLon, pin.coordinate.longitude)
        }
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2)
        let span = MKCoordinateSpan(latitudeDelta: max(0.012, (maxLat - minLat) * 1.6), longitudeDelta: max(0.012, (maxLon - minLon) * 1.6))
        return .region(MKCoordinateRegion(center: center, span: span))
    }

    /// Apple Maps place sheet: name, address, and the one 编辑节点 action (pushes the node editor on this stack).
    private func nodeSheet(_ pin: Pin) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            ProjectEditName(value: pin.name, fallback: "projectEdit.untitledNode")
                .font(.title3.weight(.semibold))
            if !pin.address.isEmpty {
                Text(verbatim: pin.address).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
            }
            Button { editing = pin; selection = nil } label: {
                OpsR3Text.text("editor.map.editNode").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityIdentifier("projectEdit.map.editNode")
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The full-bleed 地图 page (`237:32444`): the map runs under the navigation bar and to the bottom edge; the system back
/// returns to the Form, the inline title is 地图, and the node card with 编辑节点 floats above the home indicator.
struct ProjectEditNodeMapPage<Destination: View>: View {
    let chapters: [ProjectEditChapter]
    @ViewBuilder let destination: (_ chapterID: String, _ nodeID: String) -> Destination

    var body: some View {
        ProjectEditNodeMap(chapters: chapters, fullBleed: true, destination: destination)
            .navigationTitle(OpsR3Text.text("editor.map.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
    }
}

/// The editor's one delete rule (verify-r1 3.4, Figma 237:67919 / 237:68146): a delete happens at once and leaves a
/// toast with 撤销 for five seconds. The same undo is registered with the window's `UndoManager`, so shake to undo
/// and ⌘Z work too. Only a delete that takes nodes or story with it asks first, once.
@MainActor final class ProjectEditUndoCenter: ObservableObject {
    @Published var toast: EditorToastRequest?
    private weak var undoManager: UndoManager?

    func attach(_ manager: UndoManager?) { undoManager = manager }

    /// Records one undoable delete. `restore` puts the previous state back and reports whether it could.
    func recordDelete(message: String, actionName: String, restore: @escaping @MainActor () -> Bool) {
        let manager = undoManager
        manager?.registerUndo(withTarget: self) { center in
            MainActor.assumeIsolated { _ = restore(); center.toast = nil }
        }
        manager?.setActionName(actionName)
        toast = EditorToastRequest(message: message, icon: .none, undoTitle: nil, onUndo: { [weak manager] in
            if let manager, manager.canUndo { manager.undo() } else { _ = restore() }
        })
    }
}
