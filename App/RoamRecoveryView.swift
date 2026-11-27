import SwiftUI
import Observation

@MainActor struct RoamRecoveryView: View {
    let reader: any RoamExperienceReading
    @Environment(\.scenePhase) private var scenePhase
    @State private var presentation: RoamRecoveryPresentation
    init(reader: any RoamExperienceReading) {
        self.reader = reader; _presentation = State(initialValue: RoamRecoveryPresentation(reader: reader))
    }
    var body: some View {
        let recover = presentation.recoveryAction()
        let coordinator = presentation.coordinator
        List {
            Section {
                RoamExperienceNotice(offline: reader.isOfflineExample)
                Text("roam.experience.recoveryHint").font(.subheadline)
                TextField("roam.experience.sessionID", text: $presentation.sessionID)
                    .keyboardType(.numberPad).textInputAutocapitalization(.never).autocorrectionDisabled()
                    .accessibilityIdentifier("roam.experience.recovery.id")
                CYPillButton("roam.experience.checkSession") { recover() }
                    .listRowBackground(Color.clear)
                    .disabled(!presentation.canRead)
                    .accessibilityIdentifier("roam.experience.recovery.check")
                if reader.identity == nil { Text("roam.signInRequired") }
                else if !reader.isConfigured { Text("roam.notConfigured") }
            }
            Section {
                if presentation.loading { CYSkeleton(label: "roam.loading") }
                else {
                    switch coordinator.phase {
                    case .idle, .loading: EmptyView()
                    case .active:
                        CYStatusChip("roam.experience.sessionActive", tone: .info, systemImage: "pause.circle")
                        Text("roam.experience.activeHint").cyText(.meta)
                    case .notFound:
                        CYStatusChip("roam.experience.sessionNotFound", tone: .neutral, systemImage: "questionmark.circle")
                    case .incomplete:
                        CYStatusChip("roam.experience.settlementIncomplete", tone: .warning, systemImage: "clock.badge.exclamationmark")
                        Text("roam.experience.incompleteHint").cyText(.meta)
                    case .finished:
                        CYStatusChip("roam.experience.settled", tone: .success, systemImage: "checkmark.seal")
                        if let result = coordinator.fact?.result {
                            if let xp = result.totalXp { LabeledContent("roam.experience.xp", value: String(xp)) }
                            if let tiles = result.newTiles { LabeledContent("roam.experience.newTiles", value: String(tiles)) }
                            if let places = result.newPois { LabeledContent("roam.experience.newPlaces", value: String(places)) }
                            if let shops = result.sessionShops { LabeledContent("roam.experience.shops", value: String(shops)) }
                            if let medal = result.medal, !medal.isEmpty { Label { Text(verbatim: medal) } icon: { Image(systemName: "medal") } }
                            if let medal = result.shopMedal { Text(verbatim: medal.name) }
                        }
                        Text("roam.experience.recoveryNoTrack").cyText(.meta).foregroundStyle(.secondary)
                    case .failed:
                        if let error = coordinator.error { RoamExperienceIssue(error: error) { recover() } }
                    }
                }
            }.accessibilityIdentifier("roam.experience.recovery.result")
        }.cyGroupedSurface().navigationTitle("roam.experience.recovery").navigationBarTitleDisplayMode(.inline)
            .onAppear { presentation.setForeground(scenePhase == .active); presentation.setVisible(true) }
            .onChange(of: scenePhase) { _, value in presentation.setForeground(value == .active) }
            .onChange(of: presentation.readScope) { _, _ in presentation.reset() }
            .onChange(of: reader.identity) { _, _ in presentation.reset() }
            .onDisappear { presentation.setVisible(false) }
            // Same as the hub (73a06a74f): iOS 27 only exposes a screen-level identifier on an accessibility container.
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("roam.experience.recovery")
        .cyDomainScreen(.player)
    }
}

/// Each explicit read belongs to one visible input and current reader scope.
@MainActor @Observable final class RoamRecoveryPresentation {
    let reader: any RoamExperienceReading
    let coordinator: RoamRecoveryCoordinator
    var sessionID = "" { didSet { if oldValue != sessionID { reset() } } }
    private(set) var loading = false
    private(set) var visible = false
    private var isPresented = false
    private var isForeground = true
    private var revision = UUID()
    private var task: Task<Void, Never>?
    init(reader: any RoamExperienceReading) {
        self.reader = reader; coordinator = RoamRecoveryCoordinator(reader: reader)
    }
    var readScope: UUID? { (reader as? RoamSessionFactReader)?.scope }
    var canRead: Bool {
        guard let id = Int(sessionID), id > 0, String(id) == sessionID else { return false }
        return visible && !loading && reader.identity != nil && reader.isConfigured
    }
    func setVisible(_ value: Bool) {
        isPresented = value; updateVisibility()
    }
    func setForeground(_ value: Bool) {
        isForeground = value; updateVisibility()
    }
    private func updateVisibility() {
        let value = isPresented && isForeground
        guard visible != value else { return }
        visible = value; reset()
    }
    func reset() {
        revision = UUID(); task?.cancel(); task = nil
        loading = false; coordinator.reset()
    }
    func recoveryAction() -> () -> Void {
        let offered = revision, input = sessionID, identity = reader.identity, scope = readScope
        return { [weak self] in
            guard let self, self.revision == offered, self.sessionID == input,
                  self.reader.identity == identity, self.readScope == scope, self.canRead,
                  let id = Int(input) else { return }
            self.revision = UUID(); let operation = self.revision
            self.loading = true
            self.task = Task { [weak self] in
                guard let self, self.revision == operation else { return }
                guard self.visible, self.reader.identity == identity, self.readScope == scope,
                      self.reader.isConfigured, !Task.isCancelled else { self.reset(); return }
                await self.coordinator.recover(.sessionID(id))
                guard self.revision == operation else { return }
                guard self.visible, self.reader.identity == identity, self.readScope == scope,
                      self.reader.isConfigured, !Task.isCancelled else { self.reset(); return }
                self.loading = false; self.task = nil; self.revision = UUID()
            }
        }
    }
}
