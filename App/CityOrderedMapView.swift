import SwiftUI

/// Explicit source-only ordered snapshot host, not a navigation/action permission or geodetic renderer.
@MainActor struct CityOrderedMapView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var session: AppSession
    @Bindable var model: CityOrderedMapPresentation
    var body: some View {
        Group {
            if model.isCurrent, session.currentRuntimeDependencyContext == model.captured {
                content
            } else {
                CYEmptyState(systemImage: "person.crop.circle.badge.xmark", "当前地图不可用")
            }
        }
        .navigationTitle("城市地图更新").navigationBarTitleDisplayMode(.inline)
        .task { if scenePhase == .active { await model.open() } }
        .task {
            while !Task.isCancelled {
                model.synchronize()
                do { try await Task.sleep(for: .milliseconds(250)) } catch { break }
            }
        }
        .onChange(of: session.currentRuntimeDependencyContext) { _, context in
            if context != model.captured { model.retire() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { model.close() }
            // Foreground return requires an explicit fresh read, never redisplays cached content.
        }
        .onDisappear { model.close() }
    }
    @ViewBuilder private var content: some View {
        if let snapshot = model.snapshot {
            CityOrderedMapContent(snapshot: snapshot, selected: model.selectedPoint, select: { model.selectPoint($0) },
                                  refresh: { Task { await model.open() } }, canRefresh: scenePhase == .active)
        } else if model.phase == .loading {
            ProgressView("正在读取地图")
        } else {
            CYStateLayout(
                kind: .failure,
                title: Text(model.phase == .expired ? "citySnapshot.expired" : "citySnapshot.unloaded"),
                detail: Text("重新读取当前范围，不会提交任何游戏操作。"),
                primary: (!model.isRetired && scenePhase == .active) ? (title: "重新读取", action: { _ = Task { await model.open() } }) : nil,
                primaryStyle: .secondary,
                primaryIdentifier: "city.orderedMap.refresh"
            )
        }
    }
    private var refreshButton: some View {
        Button("重新读取") { Task { await model.open() } }
            .disabled(scenePhase != .active)
            .accessibilityIdentifier("city.orderedMap.refresh")
    }
}

/// Ordered stops as a route: numbered nodes on a connector line, availability chip per stop, selected stop opens an inline detail card.
struct CityOrderedMapContent: View {
    let snapshot: CityCurrentSnapshot
    let selected: CityCurrentSnapshot.Point?
    let select: (String?) -> Void
    let refresh: () -> Void
    let canRefresh: Bool
    /// a11y-dt r3: the stop number grows with Dynamic Type instead of clipping in a fixed 28 pt circle.
    @ScaledMetric(relativeTo: .footnote) private var stopBadge: CGFloat = 28
    var body: some View {
        CYCardPage {
            CYArtCoverHeader(title: Text("城市地图更新"), subtitle: Text(verbatim: snapshot.board.title), symbol: "map.fill", seed: "ordered") {
                HStack(spacing: CYSpacing.sm) {
                    CYStatusChip("\(snapshot.points.count) 个点位", systemImage: "mappin.and.ellipse")
                    CYStatusChip(verbatim: snapshot.datum)
                }
            }
        } content: {
            CYNoteBanner(text: Text("当前读取结果，不提供导航或游戏操作。"), symbol: "info.circle")
            if snapshot.points.isEmpty {
                CYEmptyState(systemImage: "mappin.slash", "当前范围暂无点位")
            } else {
                CYInfoCard(title: Text("点位"), symbol: "point.topleft.down.to.point.bottomright.curvepath.fill") {
                    VStack(spacing: 0) {
                        ForEach(Array(snapshot.points.enumerated()), id: \.element.pointId) { index, point in
                            stop(index, point, last: index == snapshot.points.count - 1)
                        }
                    }
                }
            }
            if let point = selected {
                CYInfoCard(title: Text(verbatim: point.title), symbol: "scope") {
                    HStack(spacing: CYSpacing.sm) {
                        CYStatusChip(verbatim: availability(point.availability), tone: point.availability == "AVAILABLE" ? .success : .neutral)
                        CYStatusChip(verbatim: ownership(point.ownership), tone: point.mine ? .info : .neutral)
                    }
                    CYFactRow(label: Text("纬度"), value: NSDecimalNumber(decimal: point.latitude).stringValue)
                    CYFactRow(label: Text("经度"), value: NSDecimalNumber(decimal: point.longitude).stringValue)
                    CYFactRow(label: Text("坐标系"), value: point.datum)
                    CYPillButton("关闭详情", style: .tertiary) { select(nil) }
                }
            }
            CYPillButton("重新读取", style: .secondary, systemImage: "arrow.clockwise", action: refresh)
                .disabled(!canRefresh).accessibilityIdentifier("city.orderedMap.refresh")
        }
    }
    private func stop(_ index: Int, _ point: CityCurrentSnapshot.Point, last: Bool) -> some View {
        let on = selected?.pointId == point.pointId
        return Button { select(on ? nil : point.pointId) } label: {
            HStack(alignment: .top, spacing: CYSpacing.md) {
                VStack(spacing: 0) {
                    Text(verbatim: "\(index + 1)").cyText(.meta, weight: .bold).foregroundStyle(on ? CYColor.textInverse : CYColor.textPrimary)
                        .frame(width: stopBadge, height: stopBadge).background(on ? CYColor.textPrimary : CYColor.bgRaised, in: Circle())
                    if !last { Rectangle().fill(CYColor.bgRaised).frame(width: 2).frame(maxHeight: .infinity) }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: point.title).cyText(.bodyMedium).foregroundStyle(CYColor.textPrimary).multilineTextAlignment(.leading)
                    Text(verbatim: availability(point.availability) + " · " + ownership(point.ownership)).cyText(.meta).foregroundStyle(CYColor.textSecondary)
                }.padding(.bottom, last ? 0 : CYSpacing.lg)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(CYColor.textTertiary).accessibilityHidden(true)
            }
            .frame(minHeight: 44).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(on ? .isSelected : [])
        .accessibilityIdentifier("city.orderedMap.point.\(point.pointId)")
    }
    private func availability(_ value: String) -> String {
        switch value { case "AVAILABLE": "可用"; case "PAUSED": "已暂停"; default: "不可用" }
    }
    private func ownership(_ value: String) -> String {
        switch value {
        case "UNOWNED": "尚无归属"
        case "OUR_TEAM": "本队"
        case "OTHER_TEAM": "其他队伍"
        case "RETAINED_REVIEW": "保留审核"
        default: "尚未核定"
        }
    }
}
