import SwiftUI

/// Navigation destination owns preparation/review. Only the actual camera is full-screen;
/// closing it returns to this destination with no synthetic scan or success callback.
@MainActor struct RoamPosterScanView: View {
    let node: RoamNodeDetail
    var coordinator: RoamPosterCoordinator? = nil
    var cameraEnabled = false
    var voucherDestination: (() -> AnyView)? = nil
    @Environment(\.scenePhase) private var scenePhase
    private enum Focus: Hashable { case scan, status }
    @AccessibilityFocusState private var focusedControl: Focus?
    @State private var scanGeneration = 0
    @State private var purposeAccepted = false
    @State private var showingScanner = false
    @State private var revision = 0
    @State private var work: Task<Void, Never>?
    private var availability: RoamPosterAvailability { .init(node: node) }
    var body: some View {
        let _ = revision
        Form {
            Section {
                Text(verbatim: node.name).cyText(.cardTitle).accessibilityAddTraits(.isHeader)
                Text("media.poster.purpose")
                if availability != .available { Text(LocalizedStringKey(availabilityKey)) }
                if !cameraEnabled || coordinator?.available != true { Label("media.poster.disabled", systemImage: "lock.shield") }
            }
            if let coordinator {
                Section {
                    Group {
                        if isBusy { ProgressView(LocalizedStringKey("media.poster.phase." + phaseKey(coordinator.phase))).frame(maxWidth: .infinity) }
                        else { Text(LocalizedStringKey("media.poster.phase." + phaseKey(coordinator.phase))) }
                    }.accessibilityFocused($focusedControl, equals: .status)
                }
                if coordinator.phase == .review {
                    CYPillButton("media.poster.confirm") { run { await coordinator.submit() } }
                        .listRowBackground(Color.clear).accessibilityIdentifier("media.poster.confirm")
                }
                if coordinator.phase == .needsRedemption || availability == .needsRedemption {
                    NavigationLink("roam.experience.voucher") {
                        if let voucherDestination { voucherDestination() } else { AnyView(RoamVoucherEntryView()) }
                    }
                }
            }
            Section {
                Toggle("media.poster.consent", isOn: $purposeAccepted).tint(.green).disabled(isBusy || showingScanner)
                CYPillButton("media.poster.scan") { scanGeneration += 1; showingScanner = true }
                    .listRowBackground(Color.clear)
                    .disabled(!purposeAccepted || !cameraEnabled || coordinator?.available != true || availability != .available || !canScan)
                    .accessibilityIdentifier("media.poster.scan")
                    .accessibilityFocused($focusedControl, equals: .scan)
            }
        }.cyGroupedSurface().navigationTitle("media.poster.title").navigationBarTitleDisplayMode(.inline)
            .cyFullScreenCover(isPresented: $showingScanner, onDismiss: {
                guard scenePhase == .active, cameraEnabled else { return }
                focusedControl = canScan ? .scan : .status
            }) {
                if cameraEnabled, let coordinator {
                    let ticket = scanGeneration
                    NativeQRScanner { code in
                        guard ticket == scanGeneration, scenePhase == .active,
                              cameraEnabled, purposeAccepted, coordinator.available else { return }
                        showingScanner = false
                        run { await coordinator.scanned(code, purposeAccepted: purposeAccepted) }
                    }
                }
            }
            .onAppear { coordinator?.changed = { revision += 1 } }
            .onDisappear { if !showingScanner { work?.cancel(); work = nil; coordinator?.cancel(); coordinator?.changed = nil } }
            .onChange(of: scenePhase) { _, phase in if phase == .background { invalidateScan() } }
            .onChange(of: cameraEnabled) { _, enabled in if !enabled { invalidateScan() } }
            .onChange(of: coordinator?.available) { _, available in if available == false { invalidateScan() } }
        .cyDomainScreen(.player)
    }
    private var isBusy: Bool {
        guard let phase = coordinator?.phase else { return false }
        return phase == .locating || phase == .preflighting || phase == .submitting
    }
    private func invalidateScan() {
        let shouldCancel = showingScanner || isBusy || coordinator?.phase == .review
        scanGeneration += 1; showingScanner = false; focusedControl = nil
        work?.cancel(); work = nil
        if shouldCancel { coordinator?.cancel() }
    }
    private var canScan: Bool { coordinator?.phase == .ready || coordinator?.phase == .failed }
    private var availabilityKey: String {
        switch availability {
        case .available: return "media.poster.ready"
        case .offline: return "roam.notPublished"
        case .completed: return "roam.completed"
        case .needsRedemption: return "media.poster.phase.needsRedemption"
        case .unsupported: return "media.poster.unsupported"
        }
    }
    private func phaseKey(_ phase: RoamPosterCoordinator.Phase) -> String {
        switch phase {
        case .ready: return "ready"
        case .locating: return "locating"
        case .review: return "review"
        case .preflighting: return "preflighting"
        case .submitting: return "submitting"
        case .unknown: return "unknown"
        case .completed: return "completed"
        case .needsRedemption: return "needsRedemption"
        case .unavailable: return "unavailable"
        case .failed: return "failed"
        }
    }
    private func run(_ action: @escaping @MainActor () async -> Void) { work?.cancel(); work = Task { await action(); revision += 1 } }
}
