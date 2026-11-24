import SwiftUI

/// Explicit source-only current snapshot host, not a navigation/action permission or geodetic renderer.
@MainActor struct CityCurrentSnapshotView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.locale) private var locale
    @EnvironmentObject private var session: AppSession
    @Bindable var model: CityCurrentSnapshotPresentation
    var body: some View {
        Group {
            if model.isCurrent, session.currentRuntimeDependencyContext == model.captured {
                content
            } else {
                CYEmptyState(systemImage: "person.crop.circle.badge.xmark", "当前地图不可用")
            }
        }
        .navigationTitle("城市地图快照").navigationBarTitleDisplayMode(.inline)
        .task { await model.open() }
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
            List {
                Section {
                    Text(snapshot.board.title).cyText(.cardTitle)
                    Text("当前读取结果，不提供导航或游戏操作。")
                    Text("坐标系：\(snapshot.datum)")
                }
                Section("点位") {
                    if snapshot.points.isEmpty { Text("当前范围暂无点位") }
                    ForEach(snapshot.points, id: \.pointId) { point in
                        Button { model.selectPoint(point.pointId) } label: {
                            VStack(alignment: .leading) {
                                Text(point.title)
                                Text(point.pointId).cyText(.meta)
                            }
                        }.accessibilityIdentifier("city.currentSnapshot.point.\(point.pointId)")
                    }
                }
                if let point = model.selectedPoint {
                    Section("点位详情") {
                        Text(point.title)
                        Text("状态：\(availability(point.availability))")
                        Text("归属：\(ownership(point.ownership))")
                        Text("坐标系：\(point.datum)")
                        Text("纬度：\(NSDecimalNumber(decimal: point.latitude).stringValue)")
                        Text("经度：\(NSDecimalNumber(decimal: point.longitude).stringValue)")
                        Button("关闭详情") { model.selectPoint(nil) }
                    }
                }
                Section { refreshButton }
            }.cyGroupedSurface()
        } else if model.phase == .loading {
            ProgressView("正在读取地图")
        } else {
            CYStateLayout(
                kind: .failure,
                title: Text(model.phase == .expired ? "citySnapshot.expired" : "citySnapshot.unloaded"),
                detail: Text("重新读取当前范围，不会提交任何游戏操作。"),
                primary: (!model.isRetired && scenePhase == .active) ? (title: "重新读取", action: { _ = Task { await model.open() } }) : nil,
                primaryStyle: .secondary,
                primaryIdentifier: "city.currentSnapshot.refresh"
            )
        }
    }
    private var refreshButton: some View {
        Button("重新读取") { Task { await model.open() } }
            .disabled(scenePhase != .active)
            .accessibilityIdentifier("city.currentSnapshot.refresh")
    }
    private func availability(_ value: String) -> String {
        switch value { case "AVAILABLE": appLocalized("可用", locale: locale); case "PAUSED": appLocalized("已暂停", locale: locale); default: appLocalized("不可用", locale: locale) }
    }
    private func ownership(_ value: String) -> String {
        switch value {
        case "UNOWNED": appLocalized("尚无归属", locale: locale)
        case "OUR_TEAM": appLocalized("本队", locale: locale)
        case "OTHER_TEAM": appLocalized("其他队伍", locale: locale)
        case "RETAINED_REVIEW": appLocalized("保留审核", locale: locale)
        default: appLocalized("尚未核定", locale: locale)
        }
    }
}
