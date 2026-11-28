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
    /// START-r11-1: 换个方式开局 sheet and the 桌面完成 confirmation (MP pages/play/utils/run-start-mode.js:57-79).
    @State private var startModesShown = false
    @State private var deskConfirmShown = false
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
    private var nextNode: PlayNode? {
        guard let id = nextNodeID else { return nil }
        return model.snapshot?.visibleNodes.first { $0.id == id }
    }
    private var nextDistance: Double? { location.distance(toLatitude: nextNode?.latitude, longitude: nextNode?.longitude) }
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
        .sensoryFeedback(.success, trigger: done, condition: CYHapticTransition.turnedOn)
        .onChange(of: done) { old, new in
            // P-054: the punch is announced, not only shown.
            if !old, new { AccessibilityNotification.Announcement(appLocalized("nativeR2.city.punch.done", locale: locale)).post() }
            if !old, new { MotionR2Checklist.shared.mark(.punch) } // motion r2 R10
        }
        .motionR2EdgeGlow(when: done) // motion r2 R8
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
        .sensoryFeedback(.error, trigger: NativeR2Flags.motion && model.arrivalFailure?.nodeID == nodeID, condition: CYHapticTransition.turnedOn)
        .sensoryFeedback(.error, trigger: refusal, condition: CYHapticTransition.isSet)
        .modifier(CityOrientationStartModeDialogs(arrival: arrival, model: model, nodeID: nodeID,
                                                  startModesShown: $startModesShown, deskConfirmShown: $deskConfirmShown))
        .accessibilityIdentifier("nativeR2.city.punch")
    }

    /// START-r11-1: after a refused start (too far / no fix) the MP offers 换个方式 (pages/play/index.js:7601-7604).
    private var offersStartModes: Bool {
        guard let arrival, arrival.startChoices(for: nodeID) != nil else { return false }
        switch arrival.phase {
        case .rejected, .locationUnavailable: return true
        default: return false
        }
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
                    stationHeader(snapshot: snapshot, node: node)
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

    // MARK: station header (mp-journey r3)

    /// MP pages/play/index.wxml section C, top to bottom: cover (station → chapter → route fallback chain) with the
    /// 第 N 站 tag and a done stamp, then meta line (address), description, and the place facts (distance · hours).
    /// The station name stays the navigation title.
    @ViewBuilder private func stationHeader(snapshot: PlaySnapshot, node: PlayNode) -> some View {
        Section {
            PlayStationArtwork(image: PlayStationImageResolver.station(for: node, in: snapshot.result), title: node.name ?? "")
                .overlay(alignment: .topLeading) {
                    if let stop = node.sortID, stop > 0, stop < 100 {
                        Text("u10.template.stopNo \(stop)")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, CYSpacing.sm).padding(.vertical, CYSpacing.xxs)
                            .background(.regularMaterial, in: Capsule())
                            .padding(CYSpacing.sm)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if done {
                        Image(systemName: "checkmark.circle.fill").font(.title2).symbolRenderingMode(.multicolor)
                            .padding(CYSpacing.sm).accessibilityHidden(true)
                    }
                }
                .listRowInsets(EdgeInsets())
                .accessibilityIdentifier("nativeR2.city.punch.cover")
            if let meta = (node.hookText ?? node.address)?.trimmingCharacters(in: .whitespacesAndNewlines), !meta.isEmpty {
                Text(verbatim: meta).font(.subheadline).foregroundStyle(.secondary)
            }
            if snapshot.isStoryLocked(node) == false, let body = node.description?.trimmingCharacters(in: .whitespacesAndNewlines), !body.isEmpty {
                Text(verbatim: body).font(.body).fixedSize(horizontal: false, vertical: true)
            }
            if let distance {
                LabeledContent {
                    Text(verbatim: PlayHUDGeometry.distanceText(distance, chinese: locale.language.languageCode?.identifier == "zh"))
                        .monospacedDigit()
                } label: { Text("nativeR2.city.metric.distance") }
            }
            if let hours = node.businessTime?.trimmingCharacters(in: .whitespacesAndNewlines), !hours.isEmpty {
                LabeledContent { Text(verbatim: hours) } label: { Text("creator.family.timeWindow") }
            }
        }
    }

    // MARK: arrival lock

    @ViewBuilder private func arrivalSection(snapshot: PlaySnapshot, node: PlayNode) -> some View {
        let offer = arrival?.offer(for: nodeID)
        Section {
            if done {
                // comp-r1 C6 arrival confirmation (MP index.wxml:1104-1110 这一关你已通关 → 前往下一站).
                CityOrientationArrivalCard(doneCount: snapshot.visibleNodes.filter { snapshot.isDone($0) }.count,
                                           total: snapshot.visibleNodes.count,
                                           nextName: nextNode?.name, nextMeters: nextDistance)
            } else {
                LabeledContent("nativeR2.city.punch.distance") {
                    Text(verbatim: CityOrientationFormat.distance(distance, locale: locale)).monospacedDigit()
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
                if offersStartModes {
                    Button("playStart.modes.action") { startModesShown = true }
                        .accessibilityIdentifier("nativeR2.city.punch.startModes")
                }
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

    /// Motion r2 R16: the same three entries as the plain rows below (photo task, scan in place, task page).
    private func captureActions(task: PlayNodeTask, node: PlayNode) -> [MotionR2CaptureAction] {
        var actions: [MotionR2CaptureAction] = []
        if node.validationMethod == 2 {
            actions.append(MotionR2CaptureAction(id: "camera", titleKey: "motion2.capture.camera", systemImage: "camera") { onOpenTask(nodeID) })
        }
        if scansInPlace, model.phase != .submitting {
            actions.append(MotionR2CaptureAction(id: "scan", titleKey: "motion2.capture.scan", systemImage: "qrcode.viewfinder") { startScan() })
        }
        if task != .arrive || actions.isEmpty {
            actions.append(MotionR2CaptureAction(id: "task", titleKey: "motion2.capture.task", systemImage: "list.bullet.clipboard") { onOpenTask(nodeID) })
        }
        return actions
    }

    @ViewBuilder private func taskSection(snapshot: PlaySnapshot, node: PlayNode) -> some View {
        let task = PlayNodeTask.resolve(mode: snapshot.result.mode, node: node)
        Section {
            LabeledContent("nativeR2.city.punch.requirement") {
                Text(LocalizedStringKey("playx.task." + task.rawValue))
            }
            if let requirement = node.photoRequirement?.trimmingCharacters(in: .whitespacesAndNewlines), !requirement.isEmpty {
                Text(verbatim: requirement).foregroundStyle(.secondary)
            }
            if !done, NativeR2Flags.motion2 {
                // Motion r2 R16: the capture actions this stop accepts, in one expanding bar.
                MotionR2CaptureMenu(actions: captureActions(task: task, node: node))
                if model.phase == .submitting { ProgressView("nativeR2.city.punch.submitting") }
            } else if !done {
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
                        Label("nativeR2.city.punch.goNext", systemImage: "arrow.right").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("nativeR2.city.punch.next")
                }
            } else {
                if let arrival, arrival.offer(for: nodeID) != nil {
                    Button { Task { await arrival.arrive(nodeID: nodeID, context: model.interactionContext) } } label: {
                        CYBusyLabel(busy: arrival.isBusy) { Label("playArrival.action", systemImage: "location.fill") }
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

/// START-r11-1 (CG-ALL-11): 换个方式开局. One row per alt station (改在「X」开局), then 桌面完成 with its note.
/// The choice rides on the run's first `/api/play/arrive` (`startMode` / `altStationId`).
/// MP pages/play/utils/run-start-mode.js:28-31, :67-79; play-help.wxml:70.
@MainActor struct CityOrientationStartModeDialogs: ViewModifier {
    let arrival: PlayArrivalService?
    let model: PlayExperienceCoordinator
    let nodeID: Int
    @Binding var startModesShown: Bool
    @Binding var deskConfirmShown: Bool

    private var stations: [PlayAltStation] { arrival?.startChoices(for: nodeID) ?? [] }

    func body(content: Content) -> some View {
        content
            .confirmationDialog(Text("playStart.modes.action"), isPresented: $startModesShown, titleVisibility: .visible) {
                startButtons
            }
            .alert(Text("playStart.modes.desk"), isPresented: $deskConfirmShown) {
                Button("playStart.modes.deskStart") { start(try? PlayRunStartRequest(mode: .desk)) }
                    .accessibilityIdentifier("nativeR2.city.punch.deskStart")
                Button("playStart.modes.deskCancel", role: .cancel) {}
            } message: {
                Text("playStart.modes.deskNote")
            }
    }

    @ViewBuilder private var startButtons: some View {
        ForEach(stations) { station in
            Button {
                start(try? PlayRunStartRequest(mode: .alt, altStationID: station.id, offered: stations))
            } label: {
                Text("playStart.modes.alt \(station.name ?? "")")
            }
        }
        Button("playStart.modes.desk") { deskConfirmShown = true }
            .accessibilityIdentifier("nativeR2.city.punch.desk")
        Button("playx.cancel", role: .cancel) {}
    }

    private func start(_ request: PlayRunStartRequest?) {
        guard let arrival, let request else { return }
        let context = model.interactionContext
        Task { await arrival.arrive(nodeID: nodeID, context: context, start: request) }
    }
}
