import SwiftUI

/// S11 arrive-and-punch sheet (Maps "Arrived" card plus the Wallet scan pattern), opened from the
/// peek, the next-stop row, the banner inside 50 m, or a leg row.
///
/// Behaviour is the existing one:
/// - 我已到达 is `PlayArrivalService.arrive` (the same service `PlayArrivalControl` uses), so the start
///   GPS lock (300 m, accuracy relax ≤ 200 m) and the server decision are unchanged.
/// - The local lock row is display only. It never blocks or sends anything by itself.
/// - P-057: a scan stop scans in place (VisionKit `DataScannerViewController` via `NativeQRScanner`) and
///   submits through the same review → confirm → `submit` path as the stop page (`/checkin`).
/// - Photo and answer still open the existing stop page: the system camera / photo picker are presented by the
///   play runtime root, which cannot present over the run sheets.
@MainActor struct CityOrientationPunchSheet: View {
    @Bindable var model: PlayExperienceCoordinator
    let nodeID: Int
    @ObservedObject var location: CityOrientationLocationObserver
    /// Opens the existing stop page (`PlayExperienceNodeView`): photo, scan and answer capture live there.
    let onOpenTask: (Int) -> Void
    /// The next control point after a punch, or a replacement offered by an arrival refusal.
    let onNext: (Int) -> Void
    @State private var arrival: PlayArrivalService?
    /// P-057: the in-sheet scanner, the pending review it produced, and why a scan was refused.
    @State private var scanning = false
    @State private var review: PlayCompletionReview?
    @State private var confirmReview = false
    @State private var refusal: PlayReviewRefusal?
    /// The code the scanner returned; reviewed once the scanner has finished dismissing.
    @State private var scannedCode: String?
    /// This sheet submitted a scan, so the coordinator's next issue is shown here.
    @State private var submittedHere = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    private var node: PlayNode? { model.snapshot?.visibleNodes.first { $0.id == nodeID } }
    private var done: Bool {
        guard let snapshot = model.snapshot, let node else { return false }
        return snapshot.isDone(node)
    }
    private var distance: Double? { location.distance(toLatitude: node?.latitude, longitude: node?.longitude) }
    /// Scan stops capture in this sheet; every other task keeps the stop page.
    private var scansInPlace: Bool {
        guard let snapshot = model.snapshot, let node else { return false }
        let task = PlayNodeTask.resolve(mode: snapshot.result.mode, node: node)
        return task == .scan || task == .merchantScan
    }
    private var nextNodeID: Int? {
        guard let snapshot = model.snapshot, let next = PlayTaskSummaryPresentation(snapshot: snapshot).currentNodeID,
              next != nodeID else { return nil }
        return next
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(Text(verbatim: node?.name ?? "#\(nodeID)"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("nativeR2.city.close") { dismiss() }
                            .accessibilityIdentifier("nativeR2.city.punch.close")
                    }
                }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear {
            if arrival == nil { arrival = PlayArrivalService(runtime: model, location: RuntimeNativeLocationProvider(enabled: true)) }
        }
        .onDisappear { arrival?.cancel(); if review != nil { model.cancelReview(); review = nil } }
        .sensoryFeedback(.success, trigger: done) { old, new in !old && new }
        .onChange(of: done) { old, new in
            // P-054: the punch is announced, not only shown.
            if !old, new { AccessibilityNotification.Announcement(appLocalized("nativeR2.city.punch.done", locale: locale)).post() }
        }
        .cySheet(isPresented: $scanning, onDismiss: {
            if let code = scannedCode { scannedCode = nil; prepareScan(code) }
        }) {
            NativeQRScanner { code in
                scannedCode = code
                scanning = false
            }
        }
        .confirmationDialog(Text("playx.review"), isPresented: $confirmReview, titleVisibility: .visible) {
            Button("playx.submit") {
                guard let pending = review else { return }
                review = nil // consumed before the dialog's own dismissal
                submittedHere = true
                Task { await model.submit(pending) }
            }
            .accessibilityIdentifier("playx.confirm")
            Button("playx.cancel", role: .cancel) { model.cancelReview(); review = nil }
        } message: {
            Text("playx.review.detail")
        }
        .onChange(of: confirmReview) { _, visible in
            if !visible, review != nil { model.cancelReview(); review = nil }
        }
        .sensoryFeedback(.error, trigger: model.arrivalFailure?.nodeID) { _, new in NativeR2Flags.motion && new == nodeID }
        .sensoryFeedback(.error, trigger: refusal) { _, new in new != nil }
        .accessibilityIdentifier("nativeR2.city.punch")
    }

    @ViewBuilder private var content: some View {
        if let snapshot = model.snapshot, let node {
            if snapshot.isLocked(node) {
                ContentUnavailableView {
                    Label("nativeR2.city.punch.locked", systemImage: "lock")
                } description: {
                    if let reason = snapshot.lockReason(node) { Text(verbatim: reason) }
                }
            } else {
                List {
                    if let hook = (node.hookText ?? node.address)?.trimmingCharacters(in: .whitespacesAndNewlines), !hook.isEmpty {
                        Section { Text(verbatim: hook).foregroundStyle(.secondary) }
                    }
                    arrivalSection(snapshot: snapshot, node: node)
                    if let failure = model.arrivalFailure, failure.nodeID == nodeID, !done {
                        PlayArrivalFailureSection(failure: failure,
                                                  onScan: { onOpenTask(nodeID) },
                                                  onRefresh: { Task { await model.load() } },
                                                  onOpenNode: onNext)
                    }
                    if let reason = refusal, !done {
                        Section { PlayReviewRefusalRow(refusal: reason, identifier: "nativeR2.city.punch.refusal") }
                    }
                    if submittedHere, !done, model.phase != .submitting, let issue = model.issue {
                        Section { PlayExperienceIssueView(issue: issue) }
                    }
                    taskSection(snapshot: snapshot, node: node)
                }
                .safeAreaInset(edge: .bottom, spacing: 0) { bottomActions }
            }
        } else {
            ContentUnavailableView("nativeR2.city.punch.missing", systemImage: "mappin.slash")
        }
    }

    // MARK: arrival lock

    @ViewBuilder private func arrivalSection(snapshot: PlaySnapshot, node: PlayNode) -> some View {
        let offer = arrival?.offer(for: nodeID)
        Section {
            if done {
                Label("nativeR2.city.punch.done", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.green)
                    .nativeR2BounceOnAppear()
                    .accessibilityIdentifier("nativeR2.city.punch.done")
            } else {
                LabeledContent("nativeR2.city.punch.distance") {
                    Text(verbatim: CityOrientationFormat.distance(distance)).monospacedDigit()
                }
                if let accuracy = location.fix?.accuracyMeters {
                    LabeledContent("nativeR2.city.punch.accuracy") {
                        Text(verbatim: "±\(Int(accuracy.rounded())) m").monospacedDigit()
                    }
                }
                LabeledContent("nativeR2.city.punch.lock") {
                    Text(LocalizedStringKey(lockKey(offer: offer)))
                }
                .accessibilityIdentifier("nativeR2.city.punch.lock")
                if let arrival { arrivalPhaseRows(arrival) }
            }
        } header: {
            Text("nativeR2.city.punch.arrival")
        } footer: {
            if !done {
                if offer == .start {
                    Text(location.access == .denied ? "nativeR2.city.punch.locationOff" : "nativeR2.city.punch.startFooter")
                } else if offer == .stationTap {
                    Text("playArrival.station.hint")
                }
            }
        }
    }

    /// Display only: what the existing arrival rule would say about the last fix.
    private func lockKey(offer: PlayArrivalService.Kind?) -> String {
        switch offer {
        case .start?:
            guard let fix = location.fix, let distance else {
                return location.access == .denied ? "nativeR2.city.lock.locationOff" : "nativeR2.city.lock.noFix"
            }
            switch PlayArrivalPolicy.start(distanceMeters: distance, accuracyMeters: fix.accuracyMeters) {
            case .pass: return "nativeR2.city.lock.pass"
            case .tooFar: return "nativeR2.city.lock.tooFar"
            case .accuracyLow: return "nativeR2.city.lock.accuracyLow"
            }
        case .stationTap?, .freeVisit?: return "nativeR2.city.lock.station"
        case nil: return "nativeR2.city.lock.task"
        }
    }

    /// The same phase copy as `PlayArrivalControl`.
    @ViewBuilder private func arrivalPhaseRows(_ arrival: PlayArrivalService) -> some View {
        switch arrival.phase {
        case .locating: ProgressView("playArrival.locating")
        case .submitting: ProgressView("playArrival.submitting")
        case .succeeded: Label("playArrival.succeeded", systemImage: "checkmark.circle")
        case .rejected(let rejection):
            if let message = rejection.message, !message.isEmpty {
                Label { Text(verbatim: message) } icon: { Image(systemName: "exclamationmark.triangle") }
            } else {
                Label { Text(LocalizedStringKey(rejection.reason.localizationKey)) } icon: { Image(systemName: "exclamationmark.triangle") }
            }
            if let distance = rejection.distanceMeters { Text("playArrival.distance \(distance)").foregroundStyle(.secondary) }
        case .unknown:
            Text("playArrival.unknown")
            Button("playArrival.reread") { Task { await arrival.reread() } }
        case .unavailable: Text("playArrival.unavailable")
        case .locationUnavailable: Text("playArrival.location.unavailable")
        case .idle: EmptyView()
        }
    }

    // MARK: task

    @ViewBuilder private func taskSection(snapshot: PlaySnapshot, node: PlayNode) -> some View {
        let task = PlayNodeTask.resolve(mode: snapshot.result.mode, node: node)
        Section {
            LabeledContent("nativeR2.city.punch.requirement") {
                Text(LocalizedStringKey("playx.task." + task.rawValue))
            }
            if let requirement = node.photoRequirement?.trimmingCharacters(in: .whitespacesAndNewlines), !requirement.isEmpty {
                Text(verbatim: requirement).foregroundStyle(.secondary)
            }
            if !done {
                if node.validationMethod == 2 {
                    Button { onOpenTask(nodeID) } label: { Label("nativeR2.city.punch.photo", systemImage: "camera") }
                        .accessibilityIdentifier("nativeR2.city.punch.photo")
                } else if scansInPlace {
                    Button { startScan() } label: { Label("nativeR2.city.punch.scanTask", systemImage: "qrcode.viewfinder") }
                        .disabled(model.phase == .submitting)
                        .accessibilityIdentifier("nativeR2.city.punch.task")
                    if model.phase == .submitting { ProgressView("nativeR2.city.punch.submitting") }
                } else if task != .arrive {
                    Button { onOpenTask(nodeID) } label: { Label("nativeR2.city.punch.task", systemImage: "list.bullet.clipboard") }
                        .accessibilityIdentifier("nativeR2.city.punch.task")
                }
            } else {
                Button { onOpenTask(nodeID) } label: { Label("referenceTask.open", systemImage: "doc.text") }
                    .accessibilityIdentifier("nativeR2.city.punch.open")
            }
        } header: {
            Text("nativeR2.city.punch.taskHeader")
        }
    }

    // MARK: scan in place (P-057)

    /// The stop page's `prepare`: the coordinator reviews the evidence (nothing is sent), then the confirm dialog
    /// submits it. A refusal shows its reason in the sheet and as an error haptic.
    private func startScan() {
        refusal = nil
        submittedHere = false
        scanning = true
    }
    private func prepareScan(_ code: String) {
        let evidence = PlayCompletionEvidence.scan(code)
        do {
            review = try model.review(nodeID: nodeID, evidence: evidence, context: model.interactionContext)
            refusal = nil
            confirmReview = true
        } catch {
            refusal = model.reviewRefusal(nodeID: nodeID, evidence: evidence) ?? PlayReviewRefusal(error: error)
        }
    }

    // MARK: actions

    private var bottomActions: some View {
        VStack(spacing: 8) {
            if done {
                if let next = nextNodeID {
                    Button { onNext(next) } label: {
                        Label("nativeR2.city.punch.next", systemImage: "arrow.right").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("nativeR2.city.punch.next")
                }
            } else {
                if let arrival, arrival.offer(for: nodeID) != nil {
                    Button { Task { await arrival.arrive(nodeID: nodeID, context: model.interactionContext) } } label: {
                        Group {
                            if arrival.isBusy { ProgressView() } else { Label("playArrival.action", systemImage: "location.fill") }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(arrival.isBusy || arrival.phase == .unknown || arrival.phase == .succeeded)
                    .accessibilityIdentifier("playArrival.action")
                }
                // Scan is the fallback everywhere (location is only required for the start). Scan stops scan here.
                Button { if scansInPlace { startScan() } else { onOpenTask(nodeID) } } label: {
                    Label("nativeR2.city.punch.scan", systemImage: "qrcode.viewfinder").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(scansInPlace && model.phase == .submitting)
                .accessibilityIdentifier("nativeR2.city.punch.scan")
            }
        }
        .controlSize(.large)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }
}

/// The control point whose punch sheet is open.
struct CityOrientationPunchTarget: Identifiable, Hashable {
    let id: Int
}
