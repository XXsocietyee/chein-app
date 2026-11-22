import SwiftUI

struct CityPlayerValueSourceSelection: Identifiable { let id = UUID(); let visit: CityPlayerValueVisit }

@MainActor struct CityPlayerValueNodeHost: View {
    let visit: CityPlayerValueVisit
    let factory: (CityPlayerValueVisit) -> CityPlayerValueNodeRuntime?
    @State private var runtime: CityPlayerValueNodeRuntime?
    @State private var resolved = false
    var body: some View {
        Group {
            if let runtime { CityPlayerValueNodeView(runtime: runtime) }
            else { CityPlayerValueSourceUnavailable() }
        }
        .task { guard !resolved else { return }; resolved = true; runtime = factory(visit) }
        .themeDomain(.player)
        .cyAnimation(value: runtime != nil)
    }
}

/// Shown when the source runtime is missing or retired. One hero title; the scan screen is not on stage.
@MainActor private struct CityPlayerValueSourceUnavailable: View {
    @Environment(\.cyPalette) private var palette
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CYSpacing.lg) {
                CYHeroHeader(
                    "cityValue.sourceAction",
                    subtitle: "cityValue.sourceDisabled",
                    tableName: "CityValue"
                ) {
                    Image(systemName: "location.slash")
                        .font(.largeTitle)
                        .foregroundStyle(palette.textSecondary)
                        .accessibilityHidden(true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, CYSpacing.pageHorizontal)
            .padding(.vertical, CYSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .cyDomainPageBackground()
    }
}

@MainActor struct CityPlayerValueNodeView: View {
    let runtime: CityPlayerValueNodeRuntime
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.cyPalette) private var palette
    @QuestifyReduceMotion private var reduceMotion
    @State private var node: RoamNodeDetail?
    @State private var poster: RoamPosterCoordinator?
    @State private var failed = false
    @State private var loading = false
    @State private var work: Task<Void, Never>?
    @State private var generation = UUID()
    var body: some View {
        Group {
            if !runtime.isCurrent { CityPlayerValueSourceUnavailable() }
            else if let node, let poster {
                loaded(node: node, poster: poster)
            } else {
                pending
            }
        }
        .task { start(recover: false) }
        .onDisappear { stop() }
        .onChange(of: scenePhase) { _, value in if value != .active { stop() } }
        .accessibilityIdentifier("cityValue.source")
        .themeDomain(.player)
        .cyDomainPageBackground()
    }

    /// Poster scan owns the bar title (`media.poster.title`). The only solid action in this chrome is recover.
    @ViewBuilder private func loaded(node: RoamNodeDetail, poster: RoamPosterCoordinator) -> some View {
        RoamPosterScanView(node: node, coordinator: poster, cameraEnabled: runtime.cameraEnabled,
            voucherDestination: { AnyView(VerificationCodeView(model: runtime.voucher(), title: node.name)) })
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(alignment: .leading, spacing: CYSpacing.md) {
                    if failed {
                        CYNoteBanner(
                            text: Text("cityValue.sourceReadFailed", tableName: "CityValue"),
                            symbol: "exclamationmark.triangle",
                            tone: .warning
                        )
                    }
                    CYPillButton(
                        "cityValue.recoverSource",
                        style: .primary,
                        systemImage: "arrow.clockwise",
                        tableName: "CityValue"
                    ) {
                        begin(recover: true)
                    }
                    .disabled(loading)
                    .accessibilityIdentifier("cityValue.recoverSource")
                    .accessibilityLabel(Text("cityValue.recoverSource", tableName: "CityValue"))
                    Text("cityValue.sourceNoSuccessClaim", tableName: "CityValue")
                        .cyText(.meta)
                        .foregroundStyle(palette.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, CYSpacing.pageHorizontal)
                .padding(.vertical, CYSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(palette.bgElevated)
                .cyAnimation(value: failed)
            }
    }

    private var pending: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CYSpacing.lg) {
                CYHeroHeader("cityValue.sourceAction", tableName: "CityValue")
                if loading {
                    CYSkeleton()
                        .accessibilityLabel(Text("cityValue.refresh", tableName: "CityValue"))
                }
                if failed {
                    CYNoteBanner(
                        text: Text("cityValue.sourceReadFailed", tableName: "CityValue"),
                        symbol: "exclamationmark.triangle",
                        tone: .warning
                    )
                }
                CYPillButton(
                    "cityValue.refresh",
                    style: .primary,
                    systemImage: "arrow.clockwise",
                    tableName: "CityValue"
                ) {
                    begin(recover: false)
                }
                .disabled(loading)
                .accessibilityLabel(Text("cityValue.refresh", tableName: "CityValue"))
            }
            .padding(.horizontal, CYSpacing.pageHorizontal)
            .padding(.vertical, CYSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .cyAnimation(value: loading)
        .cyAnimation(value: failed)
    }

    private func begin(recover: Bool) {
        guard !loading, scenePhase == .active, runtime.isCurrent else { return }
        if !reduceMotion { CYHaptics.impactMedium.play() }
        start(recover: recover)
    }
    private func start(recover: Bool) {
        guard !loading, scenePhase == .active, runtime.isCurrent else { return }
        let ticket = generation; loading = true; failed = false
        work = Task {
            do {
                let value: RoamNodeDetail
                if recover { value = try await runtime.recoverCompletion() } else { value = try await runtime.detail() }
                guard ticket == generation, !Task.isCancelled, runtime.isCurrent else { return }
                poster?.cancel(); node = value; poster = try runtime.poster(node: value); loading = false
            } catch { if ticket == generation, !Task.isCancelled { loading = false; failed = true } }
        }
    }
    private func stop() { generation = UUID(); work?.cancel(); work = nil; loading = false; poster?.cancel(); runtime.stop() }
}
