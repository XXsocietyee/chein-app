import SwiftUI

/// `ROAM-9a/9b`: in-session roam 更多 tools (MP pages/roam/index.wxml roam-settings scene), as a system `Form` sheet.
/// - 附近正在走的人: rows from `POST /api/roam/nearby-runners` (pages/roam/index.js:2827-2842). There is no greet
///   request in the MP, so there is no greet button.
/// - 迷雾: `RoamFogPreference` (`roam_fog_off`, stored true = fog off).
/// - 地图样式: `FreeMapKind` (`cy_map_kind`: 白 / 黑 / 纸本 / 2077), not the MapKit standard / satellite picker.
/// - 减少动态效果: `PlayReducedMotionPreference` (writes `play_reduced_motion` and legacy `roam_reduced_motion`,
///   pages/roam/index.js:880).
struct RoamSessionToolsSheetView: View {
    let runners: [RoamNearbyRunner]
    /// MP `presenceVisible`: runners are read only while the walker shares presence.
    let presenceEnabled: Bool
    @Binding var fogOn: Bool
    @Binding var mapKind: FreeMapKind
    @Binding var reduceMotion: Bool
    var onOpenLocationSettings: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if !presenceEnabled {
                        Text("roamTools.runners.needPresence").foregroundStyle(.secondary)
                    } else if runners.isEmpty {
                        Text("roamTools.runners.empty").foregroundStyle(.secondary)
                            .accessibilityIdentifier("roamTools.runners.empty")
                    } else {
                        ForEach(runners) { runner in runnerRow(runner) }
                    }
                } header: {
                    Text("roamTools.runners.section")
                }

                Section("roamTools.map.section") {
                    Toggle("roamTools.fog", isOn: $fogOn)
                        .accessibilityIdentifier("roamTools.fog")
                    Picker("roamTools.mapStyle", selection: $mapKind) {
                        ForEach(FreeMapKind.allCases, id: \.self) { kind in
                            Text(LocalizedStringKey("roamTools.mapKind." + kind.rawValue)).tag(kind)
                        }
                    }
                    .accessibilityIdentifier("roamTools.mapKind")
                    Toggle("roamTools.reduceMotion", isOn: $reduceMotion)
                        .accessibilityIdentifier("roamTools.reduceMotion")
                }

                if let onOpenLocationSettings {
                    Section("roamTools.permissions.section") {
                        Button("roamTools.locationSettings", action: onOpenLocationSettings)
                    }
                }
            }
            .navigationTitle(Text("roamTools.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("action.done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .accessibilityIdentifier("roamTools.sheet")
    }

    /// MP f-multi card row: initial / avatar, nickname, walking time and own 地盘 %.
    private func runnerRow(_ runner: RoamNearbyRunner) -> some View {
        HStack(spacing: CYSpacing.md) {
            ZStack {
                Circle().fill(CYColor.brandSoft)
                Text(verbatim: runner.initial).cyText(.bodyMedium).foregroundStyle(CYColor.textPrimary)
                if let avatar = runner.avatarURL {
                    BoundedMediaThumbnail(url: avatar) { Color.clear }.clipShape(Circle())
                }
            }
            .frame(width: 36, height: 36)
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                Text(verbatim: runner.nickname).cyText(.bodyMedium)
                HStack(spacing: CYSpacing.sm) {
                    if !runner.elapsedLabel.isEmpty {
                        Text(verbatim: runner.elapsedLabel).cyText(.meta, monospacedDigit: true)
                    }
                    if let explore = runner.explorePercent {
                        Text("roamTools.runners.explore \(explore)").cyText(.meta, monospacedDigit: true)
                    }
                }
                .foregroundStyle(CYColor.textSecondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("roamTools.runner.\(runner.id)")
    }
}
