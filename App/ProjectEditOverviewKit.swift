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

/// `主题详情` card: cover 44×58 r8, the topic name, and one status line (red dot + 还有 N 项未填, or 已填完).
struct ProjectEditTopicCard: View {
    let name: String
    let cover: String
    let missing: Int
    let action: () -> Void
    private var palette: CYDomainPalette { CYDomainPalette(.topicEditor) }
    @ScaledMetric(relativeTo: .body) private var coverWidth: CGFloat = 44

    var body: some View {
        Button(action: action) {
            HStack(spacing: CYSpacing.md) {
                CYCachedAsyncImage(cover.isEmpty ? nil : cover, role: .cover)
                    .frame(width: coverWidth, height: coverWidth * 58 / 44)
                    .clipShape(RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous))
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
                    .foregroundStyle(palette.textPrimary)
                    .lineLimit(2)
                    HStack(spacing: 6) {
                        if missing > 0 {
                            Circle().fill(palette.danger).frame(width: 6, height: 6).accessibilityHidden(true)
                            Text("editor.topic.missing \(missing)", tableName: OpsR3Text.table)
                                .foregroundStyle(palette.danger)
                        } else {
                            OpsR3Text.text("editor.topic.complete").foregroundStyle(palette.textTertiary)
                        }
                    }
                    .font(.footnote)
                }
                Spacer(minLength: CYSpacing.xs)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(palette.textTertiary)
                    .frame(width: CYSpacing.minTouchTarget, height: CYSpacing.minTouchTarget)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, CYSpacing.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.cyPressable)
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

/// `Topic/Chapter Card` label: eyebrow 第 N 章, the name, one meta line, and a red dot when the chapter blocks
/// publishing. The whole card opens the chapter; ⋯ and the handle sit beside it in the row.
struct ProjectEditChapterCardLabel: View {
    let ordinal: Int
    let chapter: ProjectEditChapter
    var blocked = false
    private var palette: CYDomainPalette { CYDomainPalette(.topicEditor) }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text("editor.chapter.ordinal \(ordinal)", tableName: OpsR3Text.table)
                    .font(.footnote.weight(.semibold).monospacedDigit())
                    .foregroundStyle(palette.textTertiary)
                if blocked {
                    Circle().fill(palette.danger).frame(width: 6, height: 6)
                        .accessibilityLabel(OpsR3Text.text("editor.chapter.blocked"))
                }
            }
            ProjectEditName(value: chapter.name, fallback: "projectEdit.untitledChapter")
                .font(.headline)
                .foregroundStyle(palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            meta
                .font(.footnote)
                .foregroundStyle(chapter.nodes.isEmpty && (chapter.blocks ?? []).isEmpty ? palette.textTertiary : palette.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, CYSpacing.xs)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var meta: some View {
        let blocks = chapter.blocks?.count ?? 0
        if chapter.nodes.isEmpty && blocks == 0 {
            OpsR3Text.text("editor.chapter.empty")
        } else if blocks > 0 {
            Text("editor.chapter.metaStory \(chapter.nodes.count) \(blocks)", tableName: OpsR3Text.table)
        } else {
            Text("editor.chapter.meta \(chapter.nodes.count)", tableName: OpsR3Text.table)
        }
    }
}

/// 地图 view of the 创作页 (Figma 237:32444): every node with usable coordinates as a pin; the selected pin grows to
/// 1.15 and a node card sits at the bottom with 编辑节点. Nodes without coordinates are counted under the map.
struct ProjectEditNodeMap<Destination: View>: View {
    struct Pin: Identifiable, Equatable {
        let id: String
        let chapterID: String
        let ordinal: Int
        let name: String
        let address: String
        let coordinate: CLLocationCoordinate2D
        static func == (lhs: Pin, rhs: Pin) -> Bool { lhs.id == rhs.id }
    }
    let chapters: [ProjectEditChapter]
    @ViewBuilder let destination: (_ chapterID: String, _ nodeID: String) -> Destination
    @State private var selection: String?
    @State private var position: MapCameraPosition = .automatic
    @QuestifyReduceMotion private var reduceMotion
    private var palette: CYDomainPalette { CYDomainPalette(.topicEditor) }

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
            ZStack(alignment: .bottom) {
                Map(position: $position, selection: $selection) {
                    ForEach(pins) { pin in
                        Annotation(pin.name.isEmpty ? "—" : pin.name, coordinate: pin.coordinate, anchor: .bottom) {
                            pinView(pin, selected: selection == pin.id)
                        }
                        .tag(pin.id)
                        .annotationTitles(.hidden)
                    }
                }
                .mapStyle(.standard(emphasis: .muted, pointsOfInterest: .excludingAll))
                .mapControls { MapCompass() }
                .frame(height: 420)
                .clipShape(RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous))
                .overlay {
                    if pins.isEmpty {
                        VStack(spacing: CYSpacing.xs) {
                            Image(systemName: "mappin.slash").font(.title3).accessibilityHidden(true)
                            OpsR3Text.text("editor.map.empty.title").font(.headline)
                            OpsR3Text.text("editor.map.empty.message").font(.footnote).multilineTextAlignment(.center)
                        }
                        .foregroundStyle(palette.textSecondary)
                        .padding(CYSpacing.lg)
                        .background(RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous).fill(palette.bgElevated))
                        .padding(CYSpacing.lg)
                        .accessibilityElement(children: .combine)
                    }
                }
                if let pin = pins.first(where: { $0.id == selection }) {
                    nodeCard(pin)
                        .padding(CYSpacing.sm)
                        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(CYMotion.resolve(CYMotion.standard, reduceMotion: reduceMotion), value: selection)
            .sensoryFeedback(.selection, trigger: selection)
            if unplaced > 0 {
                Text("editor.map.unplaced \(unplaced)", tableName: OpsR3Text.table)
                    .font(.footnote)
                    .foregroundStyle(palette.textSecondary)
            }
        }
        .accessibilityIdentifier("projectEdit.map")
    }

    private func pinView(_ pin: Pin, selected: Bool) -> some View {
        Text(verbatim: "\(pin.ordinal)")
            .font(.footnote.weight(.bold).monospacedDigit())
            .foregroundStyle(selected ? palette.actionPrimaryFg : palette.textPrimary)
            .frame(width: 30, height: 30)
            .background(Circle().fill(selected ? palette.actionPrimaryBg : palette.bgElevated))
            .overlay(Circle().strokeBorder(palette.actionPrimaryBg, lineWidth: 1.5))
            .scaleEffect(selected && !reduceMotion ? 1.15 : 1)
            .animation(CYMotion.resolve(CYMotion.release, reduceMotion: reduceMotion), value: selected)
            .frame(width: CYSpacing.minTouchTarget, height: CYSpacing.minTouchTarget)
            .contentShape(Rectangle())
            .accessibilityLabel(Text(verbatim: "\(pin.ordinal) \(pin.name)"))
            .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    private func nodeCard(_ pin: Pin) -> some View {
        HStack(spacing: CYSpacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                ProjectEditName(value: pin.name, fallback: "projectEdit.untitledNode")
                    .font(.headline).foregroundStyle(palette.textPrimary)
                if !pin.address.isEmpty {
                    Text(verbatim: pin.address).font(.footnote).foregroundStyle(palette.textSecondary).lineLimit(1)
                }
            }
            Spacer(minLength: CYSpacing.xs)
            NavigationLink { destination(pin.chapterID, pin.id) } label: {
                OpsR3Text.text("editor.map.editNode")
            }
            .buttonStyle(CYPillButtonStyle(style: .primary, fullWidth: false, compact: true))
            .accessibilityIdentifier("projectEdit.map.editNode")
        }
        .padding(CYSpacing.md)
        .background(RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous).fill(palette.bgElevated))
        .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
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
