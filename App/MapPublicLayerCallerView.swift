import SwiftUI

private struct MapPublicLayerCallerKey: EnvironmentKey {
    static let defaultValue: MapPublicLayerCaller? = nil
}
extension EnvironmentValues {
    var mapPublicLayerCaller: MapPublicLayerCaller? {
        get { self[MapPublicLayerCallerKey.self] }
        set { self[MapPublicLayerCallerKey.self] = newValue }
    }
}

/// Bilingual copy for strings that are not in a catalog yet. Keys match `docs/release/ui-strings-cloud-21.json`.
enum Cloud21Copy {
    static func phrase(key: String, en: String, zh: String, locale: Locale) -> String {
        guard !key.isEmpty else { return en }
        let code = locale.language.languageCode?.identifier ?? locale.identifier
        return code.hasPrefix("zh") ? zh : en
    }
}

/// Bbox is typed. The caller turns its center into the manual area. No device fix.
@MainActor struct MapPublicLayerCallerView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.locale) private var locale
    let caller: MapPublicLayerCaller
    @State private var minLat = ""
    @State private var maxLat = ""
    @State private var minLng = ""
    @State private var maxLng = ""
    @State private var layers = "roam_poi,store,activity"
    @State private var limit = "50"

    var body: some View {
        let theme = MapVisualHostBridge.resolveTheme(systemIsDark: colorScheme == .dark)
        let projected = (try? caller.project(theme: theme)) ?? []
        let showEmpty = caller.session != nil && caller.ready.isEmpty && caller.failure == nil && !caller.loading && caller.detail == nil
        List {
            CYHeroHeader(verbatim: phrase("cloud21.map.publicLayers", "Public layers", "公开图层")).e1HeroRow()
            Section {
                field("mapPublic.minLat", "cloud21.mapPublic.minLat", "Minimum latitude", "最小纬度", $minLat, digits: true)
                field("mapPublic.maxLat", "cloud21.mapPublic.maxLat", "Maximum latitude", "最大纬度", $maxLat, digits: true)
                field("mapPublic.minLng", "cloud21.mapPublic.minLng", "Minimum longitude", "最小经度", $minLng, digits: true)
                field("mapPublic.maxLng", "cloud21.mapPublic.maxLng", "Maximum longitude", "最大经度", $maxLng, digits: true)
                field("mapPublic.layers", "cloud21.mapPublic.layers", "Layers", "图层", $layers, digits: false)
                field("mapPublic.limit", "cloud21.mapPublic.limit", "Limit", "数量上限", $limit, digits: true)
                CYPillButton(verbatim: phrase("cloud21.mapPublic.load", "Load", "加载"), systemImage: "arrow.down.circle") { Task { await load() } }
                    .e1ActionRow()
                    .disabled(caller.loading || caller.accountID == nil)
                    .accessibilityIdentifier("mapPublic.load")
                    .accessibilityLabel(Text(verbatim: phrase("cloud21.mapPublic.load", "Load", "加载")))
                if caller.session?.complete == false {
                    CYPillButton(verbatim: phrase("cloud21.mapPublic.next", "Next", "下一页"), style: .secondary, systemImage: "arrow.right") { Task { await caller.nextPage() } }
                        .e1ActionRow()
                        .disabled(caller.loading)
                        .accessibilityIdentifier("mapPublic.next")
                        .accessibilityLabel(Text(verbatim: phrase("cloud21.mapPublic.next", "Next", "下一页")))
                }
            }
            if caller.loading {
                Section {
                    CYSkeleton()
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(Text(verbatim: phrase("cloud21.mapPublic.loading", "Loading places", "正在加载地点")))
                }
            }
            if let failure = caller.failure {
                Section {
                    CYStatusChip(verbatim: failure.rawValue.isEmpty ? "—" : failure.rawValue, tone: .danger, systemImage: "exclamationmark.triangle")
                        .accessibilityIdentifier("mapPublic.failure")
                }
            }
            if showEmpty {
                Section {
                    CYStateLayout(
                        kind: .search,
                        title: Text(verbatim: phrase("cloud21.mapPublic.empty", "Nothing in this area yet.", "这个范围里还没有地点。"))
                    )
                }
            }
            if !caller.ready.isEmpty {
                Section {
                    ForEach(caller.ready, id: \.key) { item in
                        resultRow(item, title: projected.first { $0.key == item.key }?.title ?? item.title)
                    }
                }
            }
            if let detail = caller.detail {
                Section {
                    Text(verbatim: shown(detail.text))
                        .cyText(.body)
                        .foregroundStyle(CYColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("mapPublic.detailText")
                    CYPillButton(verbatim: phrase("cloud21.mapPublic.return", "Return", "返回"), style: .secondary) { Task { await caller.returned() } }
                        .e1ActionRow()
                        .accessibilityIdentifier("mapPublic.return")
                        .accessibilityLabel(Text(verbatim: phrase("cloud21.mapPublic.return", "Return", "返回")))
                }
            }
        }
        .listStyle(.insetGrouped)
        .cyGroupedSurface()
        .cyHeroScreen()
        .themeDomain(.player)
        .onDisappear { caller.abandon() }
    }

    private func resultRow(_ item: MapLayerItem, title: String) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            CYListRow(verbatim: shown(title), meta: item.key.type.rawValue, trailing: .none) {
                CYCoverArt(seed: item.key.id + item.title, symbol: item.state.symbolName, showsDebugLabel: false)
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous))
                    .accessibilityHidden(true)
            }
            MapCoreEntryText.state(item.state)
                .cyText(.meta)
                .foregroundStyle(CYColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if MapPublicLayerCaller.detail(for: item) != nil {
                CYPillButton(verbatim: phrase("cloud21.mapPublic.detail", "Detail", "详情"), style: .tertiary, fullWidth: false) { Task { await caller.openDetail(item) } }
                    .accessibilityIdentifier("mapPublic.detail.\(item.key.type.rawValue).\(item.key.id)")
                    .accessibilityLabel(Text(verbatim: phrase("cloud21.mapPublic.detail", "Detail", "详情")))
            }
        }
        .accessibilityIdentifier("mapPublic.row.\(item.key.type.rawValue).\(item.key.id)")
    }

    private func field(_ id: String, _ key: String, _ en: String, _ zh: String, _ value: Binding<String>, digits: Bool) -> some View {
        let title = phrase(key, en, zh)
        return TextField(text: value) { Text(verbatim: title) }
            .cyText(.body)
            .modifier(Cloud21DigitStyle(enabled: digits))
            .textFieldStyle(.plain)
            .frame(minHeight: CYSpacing.minTouchTarget)
            .accessibilityIdentifier(id)
            .accessibilityLabel(Text(verbatim: title))
    }

    private func phrase(_ key: String, _ en: String, _ zh: String) -> String {
        Cloud21Copy.phrase(key: key, en: en, zh: zh, locale: locale)
    }
    private func shown(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "—" : trimmed
    }

    private func load() async {
        guard let viewer = caller.accountID, let limit = Int(limit) else { return }
        let names = layers.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        await caller.submit(.init(viewerID: viewer, minLat: minLat, maxLat: maxLat, minLng: minLng, maxLng: maxLng, layers: names, limit: limit))
    }
}

private struct Cloud21DigitStyle: ViewModifier {
    let enabled: Bool
    @ViewBuilder func body(content: Content) -> some View {
        if enabled { content.monospacedDigit() } else { content }
    }
}
