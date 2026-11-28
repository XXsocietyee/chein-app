import SwiftUI
import CoreLocation

/// `ROAM-9a/9b`: in-session roam 更多 drawer (MP pages/roam/index.wxml roam-more → roam-rules / roam-settings), as a system sheet.
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
    /// MP f-multi 「你」 row: the walker's own 地盘 % (local reading, clamped 0…99). Nil hides the row (fixtures).
    var ownExplorePercent: Int? = nil
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
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var locationStatus: CLAuthorizationStatus = .notDetermined

    var body: some View {
        // MP pages/roam/index.wxml roam-more (owner P-31): the drawer holds only 附近正在走的人 / 玩法说明 / 设置.
        NavigationStack {
            List {
                NavigationLink {
                    runnersList
                } label: {
                    LabeledContent {
                        if presenceEnabled, !runners.isEmpty { Text(runners.count, format: .number).monospacedDigit() }
                    } label: {
                        Label("roamTools.runners.section", systemImage: "person.2")
                    }
                }
                .accessibilityIdentifier("roamTools.more.runners")
                NavigationLink {
                    RoamLiveHowToView()
                } label: {
                    Label("roamTools.more.howto", systemImage: "info.circle")
                }
                .accessibilityIdentifier("roam.live.rules")
                NavigationLink {
                    settingsForm
                } label: {
                    Label("roamTools.more.settings", systemImage: "gearshape")
                }
                .accessibilityIdentifier("roamTools.more.settings")
            }
            .navigationTitle(Text("roamTools.more.title"))
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

    /// MP 附近正在走的人 (`openNearestRunner`): the runners read while the walker shares presence.
    private var runnersList: some View {
        List {
            if !presenceEnabled {
                Text("roamTools.runners.needPresence").foregroundStyle(.secondary)
            } else if runners.isEmpty {
                ContentUnavailableView("roamTools.runners.empty", systemImage: "figure.walk")
                    .accessibilityIdentifier("roamTools.runners.empty")
            } else {
                // MP f-multi: 「这片街区有 N 个人在点亮」 counts the walker too; 「你」 leads with the local 地盘 %.
                Section {
                    if let ownExplorePercent {
                        ownRow(max(0, min(99, ownExplorePercent)))
                    }
                } header: {
                    Text("roamTools.runners.lighting \(runners.count + (ownExplorePercent == nil ? 0 : 1))")
                        .accessibilityIdentifier("roamTools.runners.lighting")
                }
                ForEach(runners) { runner in
                    if let runnerActions {
                        NavigationLink { RoamRunnerDetailView(runner: runner, actions: runnerActions) } label: { runnerRow(runner) }
                    } else {
                        runnerRow(runner)
                    }
                }
            }
        }
        .navigationTitle(Text("roamTools.runners.section"))
        .navigationBarTitleDisplayMode(.inline)
    }

    /// MP roam-settings, rows in MP order: 迷雾 → 地图样式 → 减少动态效果 → 附近的人位置分享 → 位置权限 → 后台持续定位 →
    /// 到点提醒 → 清空本机缓存. The three location rows follow the system permission and open Settings (MP
    /// `openRoamLocationSetting`); they are values, not switches.
    private var settingsForm: some View {
        Form {
            Section {
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
            if let onSetPresence {
                presenceSection(onSetPresence)
            }
            Section {
                locationRow("roamTools.location.permission", on: locationAllowed, identifier: "roamTools.location.permission")
                locationRow("roamTools.location.background", on: locationStatus == .authorizedAlways, identifier: "roamTools.location.background")
                locationRow("roamTools.location.arrival", on: locationAllowed, identifier: "roamTools.location.arrival")
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
                    Button("roamTools.clearCache.keep", role: .cancel) {}
                } message: {
                    Text("roamTools.clearCache.confirmMessage")
                }
            }
        }
        .navigationTitle(Text("roamTools.more.settings"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { locationStatus = CLLocationManager().authorizationStatus }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { locationStatus = CLLocationManager().authorizationStatus }
        }
    }

    private var locationAllowed: Bool {
        locationStatus == .authorizedWhenInUse || locationStatus == .authorizedAlways
    }

    private func locationRow(_ title: LocalizedStringKey, on: Bool, identifier: String) -> some View {
        Button {
            if let onOpenLocationSettings {
                onOpenLocationSettings()
            } else if let url = URL(string: UIApplication.openSettingsURLString) {
                openURL(url)
            }
        } label: {
            LabeledContent(title) {
                Text(on ? LocalizedStringKey("roamTools.value.on") : LocalizedStringKey("roamTools.value.off"))
            }
        }
        .foregroundStyle(.primary)
        .accessibilityIdentifier(identifier)
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
                Text("roamTools.presence.failed").font(.footnote).foregroundStyle(CYColor.dangerText)
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
    private func ownRow(_ percent: Int) -> some View {
        HStack(spacing: CYSpacing.md) {
            ZStack {
                Circle().fill(CYColor.brandSoft)
                Image(systemName: "person.fill").foregroundStyle(CYColor.textPrimary)
            }
            .frame(width: 36, height: 36)
            .accessibilityHidden(true)
            Text("roamTools.runners.you").cyText(.bodyMedium)
            Spacer(minLength: CYSpacing.sm)
            Text("roamTools.runners.explore \(percent)").cyText(.meta, monospacedDigit: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("roamTools.runners.you")
    }

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

/// MP pages/roam/index.wxml roam-rules (原型 howtoScreen): 怎么玩 — one lede, three rows, one footnote.
/// The reveal radius is the one the session uses (MP `REVEAL_M` = 55, `RoamLiveSessionController` reveal grid).
struct RoamLiveHowToView: View {
    static let revealMeters = 55

    var body: some View {
        List {
            Section {
                Text("roam.howto.lede")
                    .font(.headline)
                howToRow(Text("roam.howto.reveal \(Self.revealMeters)"), detail: "roam.howto.revealDetail", systemImage: "figure.walk")
                howToRow(Text("roam.howto.photo"), detail: "roam.howto.photoDetail", systemImage: "camera")
                howToRow(Text("roam.howto.colors"), detail: "roam.howto.colorsDetail", systemImage: "person.2")
            } footer: {
                Text("roam.howto.mini")
            }
        }
        .navigationTitle(Text("roam.howto.title"))
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("roam.live.howto")
    }

    private func howToRow(_ title: Text, detail: LocalizedStringKey, systemImage: String) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                title.font(.body)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: systemImage).foregroundStyle(.tint)
        }
        .accessibilityElement(children: .combine)
    }
}
