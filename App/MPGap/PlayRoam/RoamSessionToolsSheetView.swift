import SwiftUI

/// `ROAM-9a/9b`: in-session roam 更多 tools (MP pages/roam/index.wxml roam-settings scene), as a system `Form` sheet.
/// - 附近正在走的人: rows from `POST /api/roam/nearby-runners` (pages/roam/index.js:2827-2842). ROAM-r11-4: a row opens
///   the runner (`openRunner`, :2905) with 打个招呼 (`POST /api/im/start`, then the chat) and 看 TA 的漫游 (TA 的主页).
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
    /// ROAM-r11-5: mid-session 附近的人位置分享 (MP pages/roam/index.js:5593-5616). Returns the server-confirmed value,
    /// nil when it did not change. Nil hides the switch (fixtures, signed out).
    var onSetPresence: (@MainActor (Bool) async -> Bool?)? = nil
    @State private var presenceSubmitting = false
    @State private var presenceConsentShown = false
    @State private var presenceFailed = false
    /// ROAM-r11-6: 清空本机缓存 (MP pages/roam/index.js:5637-5651). Nil hides the row.
    var onClearLocal: (@MainActor () -> Bool)? = nil
    @Environment(\.socialRoamCapabilities) private var capabilities
    @State private var clearAsk = false
    @State private var clearResult: LocalizedStringKey?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.roamRunnerActions) private var runnerActions

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
                        ForEach(runners) { runner in
                            if let runnerActions {
                                NavigationLink { RoamRunnerDetailView(runner: runner, actions: runnerActions) } label: { runnerRow(runner) }
                            } else {
                                runnerRow(runner)
                            }
                        }
                    }
                } header: {
                    Text("roamTools.runners.section")
                }
                if let onSetPresence {
                    presenceSection(onSetPresence)
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

                if let onClearLocal {
                    Section {
                        Button("roamTools.clearCache", role: .destructive) { clearAsk = true }
                            .accessibilityIdentifier("roamTools.clearCache")
                        if let clearResult {
                            Text(clearResult).font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    .confirmationDialog("roamTools.clearCache.confirmTitle", isPresented: $clearAsk, titleVisibility: .visible) {
                        Button("roamTools.clearCache.confirmAction", role: .destructive) { Task { await clearLocal(onClearLocal) } }
                    } message: {
                        Text("roamTools.clearCache.confirmMessage")
                    }
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

    private func presenceSection(_ apply: @escaping @MainActor (Bool) async -> Bool?) -> some View {
        Section {
            Toggle(isOn: Binding(get: { presenceEnabled }, set: { on in
                if on { presenceConsentShown = true } else { Task { await submit(false, apply) } }
            })) {
                Text(presenceSubmitting ? LocalizedStringKey("roamTools.presence.updating") : LocalizedStringKey("roamTools.presence.title"))
            }
            .disabled(presenceSubmitting)
            .accessibilityIdentifier("roamTools.presence")
            if presenceFailed {
                Text("roamTools.presence.failed").font(.footnote).foregroundStyle(.red)
            }
        }
        .confirmationDialog("roamTools.presence.consentTitle", isPresented: $presenceConsentShown, titleVisibility: .visible) {
            Button("roamTools.presence.agree") { Task { await submit(true, apply) } }
            Button("roamTools.presence.notNow", role: .cancel) {}
        } message: {
            Text("roamTools.presence.disclosure")
        }
    }

    /// MP order: keep the revoke mark first, wipe the local copy, then revoke shared footprint links.
    private func clearLocal(_ clear: @MainActor () -> Bool) async {
        if let capabilities { RoamShareRevokePending.mark(true, accountID: capabilities.accountID) }
        guard clear() else { clearResult = "roamTools.clearCache.failed"; return }
        guard let capabilities else { clearResult = "roamTools.clearCache.done"; return }
        let revoked = await RoamPlayerExtrasService(client: capabilities.client).revokeShareSnapshots()
        if revoked { RoamShareRevokePending.mark(false, accountID: capabilities.accountID) }
        clearResult = revoked ? "roamTools.clearCache.done" : "roamTools.clearCache.revokeLater"
    }

    private func submit(_ visible: Bool, _ apply: @MainActor (Bool) async -> Bool?) async {
        guard !presenceSubmitting else { return }
        presenceSubmitting = true; presenceFailed = false
        let saved = await apply(visible)
        presenceSubmitting = false
        presenceFailed = saved == nil
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
