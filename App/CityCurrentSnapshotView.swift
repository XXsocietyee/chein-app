import SwiftUI

/// Explicit source-only current snapshot host, not a navigation/action permission or geodetic renderer.
@MainActor struct CityCurrentSnapshotView: View {
    @Environment(\.scenePhase) private var scenePhase
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
        .navigationTitle("城市地图快照")
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
                    Text(snapshot.board.title).font(.headline)
                    Text("当前读取结果，不提供导航或游戏操作。")
                    Text("坐标系：\(snapshot.datum)")
                }
                Section("点位") {
                    if snapshot.points.isEmpty { Text("当前范围暂无点位") }
                    ForEach(snapshot.points, id: \.pointId) { point in
                        Button { model.selectPoint(point.pointId) } label: {
                            VStack(alignment: .leading) {
                                Text(point.title)
                                Text(point.pointId).font(.caption)
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
            VStack(spacing: 16) {
                ContentUnavailableView(model.phase == .expired ? "地图快照已过期" : "地图暂不可用",
                    systemImage: "map", description: Text("重新读取当前范围，不会提交任何游戏操作。"))
                if !model.isRetired { refreshButton }
            }
        }
    }
    private var refreshButton: some View {
        Button("重新读取") { Task { await model.open() } }
            .disabled(scenePhase != .active)
            .accessibilityIdentifier("city.currentSnapshot.refresh")
    }
    private func availability(_ value: String) -> String {
        switch value { case "AVAILABLE": String(localized: "可用"); case "PAUSED": String(localized: "已暂停"); default: String(localized: "不可用") }
    }
    private func ownership(_ value: String) -> String {
        switch value {
        case "UNOWNED": String(localized: "尚无归属")
        case "OUR_TEAM": String(localized: "本队")
        case "OTHER_TEAM": String(localized: "其他队伍")
        case "RETAINED_REVIEW": String(localized: "保留审核")
        default: String(localized: "尚未核定")
        }
    }
}
