import SwiftUI

/// `ROAM-9`: In-session roam `更多` tools sheet (`附近正在走的人`, fog toggle, map style,
/// reduce motion, presence sharing, clear local cache).
public struct RoamSessionToolsSheetView: View {
    public let runners: [RoamNearbyRunner]
    @Binding public var fogEnabled: Bool
    @Binding public var mapStyle: RoamMapStyleOption
    @Binding public var reduceMotionOverride: Bool
    @Binding public var presenceSharing: Bool

    public var onGreetRunner: (RoamNearbyRunner) -> Void = { _ in }
    public var onOpenLocationSettings: () -> Void = {}
    public var onClearLocalCache: () -> Void = {}
    public var onClose: () -> Void = {}

    @State private var showClearConfirm = false

    public init(
        runners: [RoamNearbyRunner] = [],
        fogEnabled: Binding<Bool> = .constant(true),
        mapStyle: Binding<RoamMapStyleOption> = .constant(.standard),
        reduceMotionOverride: Binding<Bool> = .constant(false),
        presenceSharing: Binding<Bool> = .constant(false),
        onGreetRunner: @escaping (RoamNearbyRunner) -> Void = { _ in },
        onOpenLocationSettings: @escaping () -> Void = {},
        onClearLocalCache: @escaping () -> Void = {},
        onClose: @escaping () -> Void = {}
    ) {
        self.runners = runners
        self._fogEnabled = fogEnabled
        self._mapStyle = mapStyle
        self._reduceMotionOverride = reduceMotionOverride
        self._presenceSharing = presenceSharing
        self.onGreetRunner = onGreetRunner
        self.onOpenLocationSettings = onOpenLocationSettings
        self.onClearLocalCache = onClearLocalCache
        self.onClose = onClose
    }

    public var body: some View {
        VStack(spacing: 0) {
            CYSheetHeader(title: Text("roamTools.title"), style: .player, onClose: onClose)
            Form {
                if !runners.isEmpty {
                    Section("roamTools.runners.section") {
                        ForEach(runners) { runner in
                            HStack {
                                VStack(alignment: .leading, spacing: CYSpacing.xs) {
                                    Text(runner.nickname)
                                        .cyText(.bodyMedium)
                                    if let dist = runner.distanceMeters {
                                        Text("距离约 \(dist) 米")
                                            .cyText(.meta, monospacedDigit: true)
                                            .foregroundStyle(CYColor.textSecondary)
                                    }
                                }
                                Spacer()
                                Button(runner.greeted ? "roamTools.runners.greeted" : "roamTools.runners.greet") {
                                    onGreetRunner(runner)
                                }
                                .buttonStyle(.bordered)
                                .disabled(runner.greeted)
                            }
                        }
                    }
                }

                Section("roamTools.map.section") {
                    Toggle("roamTools.fog", isOn: $fogEnabled)
                    Picker("roamTools.mapStyle", selection: $mapStyle) {
                        ForEach(RoamMapStyleOption.allCases) { opt in
                            Text(opt.title).tag(opt)
                        }
                    }
                    Toggle("roamTools.reduceMotion", isOn: $reduceMotionOverride)
                    Toggle("roamTools.presenceSharing", isOn: $presenceSharing)
                }

                Section("roamTools.permissions.section") {
                    Button("roamTools.locationSettings", action: onOpenLocationSettings)
                }

                Section {
                    Button("roamTools.clearCache", role: .destructive) {
                        showClearConfirm = true
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .confirmationDialog("roamTools.clearCache.confirmTitle", isPresented: $showClearConfirm, titleVisibility: .visible) {
            Button("roamTools.clearCache.confirmAction", role: .destructive, action: onClearLocalCache)
            Button("common.cancel", role: .cancel) {}
        } message: {
            Text("roamTools.clearCache.confirmMessage")
        }
    }
}
