import SwiftUI

@MainActor final class ClubSessionQuickStartModel: ObservableObject {
    struct Permit: Equatable { let context: ClubSessionQuickStartContext; let visibility: UUID }
    enum Phase: Equatable { case idle, loading, ready, failed, denied, topicUnavailable }
    @Published private(set) var phase: Phase = .idle
    @Published private(set) var topics: ClubSessionQuickStartTopics?
    @Published private(set) var target: ClubSessionQuickStartTarget?
    private var bound: ClubSessionQuickStartContext?
    private var loaded: ClubSessionQuickStartContext?
    private var visibility: UUID?
    private var generation = UUID()
    private var snapshotID = UUID()
    func bind(_ context: ClubSessionQuickStartContext) {
        guard bound != context else { return }; bound = context; visibility = nil; generation = UUID()
    }
    func activate(_ context: ClubSessionQuickStartContext) -> Permit? {
        guard bound == context, context.canRead, !Task.isCancelled else { return nil }
        if visibility == nil { visibility = UUID(); generation = UUID(); clear(); phase = .idle }
        return permit(in: context)
    }
    func permit(in context: ClubSessionQuickStartContext) -> Permit? {
        guard bound == context, context.canRead, let visibility else { return nil }; return .init(context: context, visibility: visibility)
    }
    private func accepts(_ p: Permit) -> Bool { bound == p.context && visibility == p.visibility && p.context.canRead }
    private func clear() { loaded = nil; topics = nil; target = nil; snapshotID = UUID() }
    func leave(_ context: ClubSessionQuickStartContext) {
        guard bound == context else { return }; visibility = nil; generation = UUID(); clear(); phase = .idle
    }
    func accepted(_ context: ClubSessionQuickStartContext, reader: any ClubReading, access: any ClubGovernanceAccess, viewerRevision: UInt64) -> ClubSessionQuickStartTopics? {
        guard permit(in: context) != nil, loaded == context, [.ready, .topicUnavailable].contains(phase),
              context.matches(reader: reader, access: access, viewerRevision: viewerRevision) else { return nil }; return topics
    }
    func isCurrent(_ value: ClubSessionQuickStartTarget, context: ClubSessionQuickStartContext, reader: any ClubReading, access: any ClubGovernanceAccess, viewerRevision: UInt64) -> Bool {
        target == value && value.isCurrent(topics: accepted(context, reader: reader, access: access, viewerRevision: viewerRevision), context: context, snapshotID: snapshotID)
    }
    /// Selecting re-reads both ownership and manageable topics. Nothing here prepares or sends a command.
    @discardableResult func read(_ p: Permit, selecting topicID: Int? = nil, reader: any ClubReading, access: any ClubGovernanceAccess, viewerRevision: @escaping () -> UInt64, isCurrent: @escaping () -> Bool = { true }) async -> ClubSessionQuickStartTarget? {
        guard isCurrent(), accepts(p), p.context.matches(reader: reader, access: access, viewerRevision: viewerRevision()), !Task.isCancelled else { return nil }
        generation = UUID(); let request = generation
        clear(); phase = .loading
        let current = { [self] in isCurrent() && accepts(p) && generation == request && !Task.isCancelled && p.context.matches(reader: reader, access: access, viewerRevision: viewerRevision()) }
        defer { if accepts(p), generation == request, phase == .loading { phase = .idle } }
        do {
            let club = try await reader.clubDetail(id: p.context.clubID, isCurrent: current)
            guard current() else { return nil }
            guard club.id == p.context.clubID, club.isOwner else { phase = .denied; return nil }
            let snapshot = try await access.read(.eventTopics, scope: .init(clubID: p.context.clubID), options: [:]) {
                guard current() else { throw CancellationError() }
            }
            guard current() else { return nil }
            let rows = try ClubSessionQuickStartTopics(context: p.context, snapshot: snapshot)
            guard current() else { return nil }
            loaded = p.context; topics = rows
            if let topicID {
                guard let selected = rows.target(topicID: topicID, context: p.context, snapshotID: snapshotID) else { phase = .topicUnavailable; return nil }
                target = selected
            }
            phase = .ready; return target
        } catch {
            guard current() else { return nil }; clear(); phase = .failed; return nil
        }
    }
}

@MainActor struct ClubSessionQuickStartEntry<Reader: ClubReading & ObservableObject>: View {
    let club: ClubRecord
    @ObservedObject var reader: Reader
    let governance: ClubGovernanceContext
    var body: some View {
        let scope = ClubSessionQuickStartContext(club: club, reader: reader, access: governance.access, viewerRevision: governance.viewerRevision)
        if scope.canRead {
            NavigationLink {
                ClubSessionQuickStartView(club: club, reader: reader, governance: governance)
                    .environment(\.clubEnrollmentProfile, governance.enrollmentProfile)
                    .environment(\.clubOwnerRefundCoordinator, governance.ownerRefund)
                    .environment(\.clubOpsTimeFactory, governance.opsTimeFactory)
                    .environment(\.clubCustomerTopics, governance.customerTopics)
                    .environment(\.clubStoryTemplates, governance.storyTemplates)
                    .environment(\.clubTerminalSessions, governance.terminalSessions)
                    .environment(\.clubOwnerFunds, governance.ownerFunds)
            } label: {
                Label("club.sessionStart.title", systemImage: "calendar.badge.plus")
            }
            .accessibilityIdentifier("club.sessionStart.entry")
            .accessibilityLabel(Text("club.sessionStart.title"))
        }
    }
}

@MainActor struct ClubSessionQuickStartView<Reader: ClubReading & ObservableObject>: View {
    let club: ClubRecord
    @ObservedObject var reader: Reader
    let governance: ClubGovernanceContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model = ClubSessionQuickStartModel()
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var creation = ClubSeriesCreationReturn()
    @State private var hostVisible = false
    private struct ReadTrigger: Equatable {
        let context: ClubSessionQuickStartContext
        let visible: Bool
        let active: Bool
    }
    @State private var pendingSelection: UUID?
    private var context: ClubSessionQuickStartContext { .init(club: club, reader: reader, access: governance.access, viewerRevision: governance.viewerRevision) }
    private func accepted(_ scope: ClubSessionQuickStartContext) -> ClubSessionQuickStartTopics? {
        model.accepted(scope, reader: reader, access: governance.access, viewerRevision: governance.viewerRevision)
    }
    var body: some View {
        let scope = context
        let _ = model.bind(scope)
        List {
            Section {
                ClubCloud14Banner(seed: sessionBannerSeed, symbol: "calendar.badge.plus", imageURL: ClubCloud14HTTPS.url(club.cover))
                    .listRowInsets(EdgeInsets())
                Text(verbatim: shown(club.name)).font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                LabeledContent {
                    Text(verbatim: String(scope.clubID)).monospacedDigit()
                } label: {
                    Label("club.ops.clubID", systemImage: "number")
                }
            } footer: {
                Text("club.sessionStart.hint")
            }
            if !scope.canRead || model.phase == .denied {
                Section {
                    Label("club.sessionStart.ownerRequired", systemImage: "lock")
                        .foregroundStyle(.orange)
                        .accessibilityIdentifier("club.sessionStart.denied")
                }
            } else {
                sessionActions(scope)
            }
        }
        .navigationTitle(Text("club.sessionStart.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("action.cancel") { pendingSelection = nil; creation.retire(); model.leave(scope); dismiss() }.accessibilityIdentifier("club.sessionStart.cancel") } }
        .onAppear { hostVisible = true; finishCreationReturn() }
        .task(id: ReadTrigger(context: scope, visible: hostVisible, active: scenePhase == .active)) {
            guard hostVisible, scenePhase == .active else { return }
            if creation.holdsSource, creation.isBound(context: scope.topicsContext, access: governance.access) { return }
            pendingSelection = nil
            guard let permit = model.activate(scope) else { return }
            await model.read(permit, reader: reader, access: governance.access, viewerRevision: { governance.viewerRevision },
                isCurrent: { hostVisible && scenePhase == .active && context == scope })
        }
        .onChange(of: scope) { _, _ in creation.retire(); pendingSelection = nil }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { creation.retire(); pendingSelection = nil; model.leave(scope) }
        }
        .onDisappear {
            hostVisible = false; pendingSelection = nil
            if !creation.holdsSource { model.leave(scope) }
        }
        .background {
            if let item = creation.item {
                ClubSeriesCreationPresentationOwner(item: item, owner: creation,
                    source: { creationSource(item) }, active: { scenePhase == .active },
                    access: governance.access, coordinator: governance.coordinator,
                    didDismiss: finishCreationReturn).id(item.id)
            }
            if let target = creation.destination {
                ClubCreatedSeriesDestinationOwner(target: target, owner: creation,
                    current: { creation.destinationIsCurrent(target, context: context.topicsContext, access: governance.access) &&
                        context.matches(reader: reader, access: governance.access, viewerRevision: governance.viewerRevision) },
                    access: governance.access, coordinator: governance.coordinator).id(target.id)
            }
        }
        .cyDomainScreen(.player)
    }
    private var sessionBannerSeed: String {
        let name = club.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "club-\(club.id)" : name
    }
    private func shown(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "—" : trimmed
    }
    @ViewBuilder private func sessionActions(_ scope: ClubSessionQuickStartContext) -> some View {
        Section {
            if model.phase == .loading { sessionLoading }
            if model.phase == .failed {
                Label("club.sessionStart.failed", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                    .accessibilityIdentifier("club.sessionStart.failed")
            }
            if model.phase == .topicUnavailable {
                Label("club.sessionStart.topicUnavailable", systemImage: "calendar.badge.exclamationmark")
                    .foregroundStyle(.orange)
            }
            sessionReload(scope)
        }
        if let topics = accepted(scope) { topicChoices(topics, scope) }
    }
    private var sessionLoading: some View {
        ProgressView { Text("club.loading") }
            .frame(maxWidth: .infinity)
            .accessibilityIdentifier("club.sessionStart.loading")
    }
    private func sessionReload(_ scope: ClubSessionQuickStartContext) -> some View {
        Button { reload(scope) } label: {
            Label(LocalizedStringKey(model.phase == .failed ? "action.retry" : "club.refresh"), systemImage: "arrow.clockwise")
        }
        .disabled(model.phase == .loading || pendingSelection != nil || creation.holdsSource || model.permit(in: scope) == nil)
        .accessibilityIdentifier("club.sessionStart.reload")
    }
    @ViewBuilder private func topicChoices(_ topics: ClubSessionQuickStartTopics, _ scope: ClubSessionQuickStartContext) -> some View {
        Section {
            if topics.rows.isEmpty {
                ContentUnavailableView {
                    Label {
                        Text("club.sessionStart.empty").accessibilityIdentifier("club.sessionStart.empty")
                    } icon: {
                        Image(systemName: "calendar")
                    }
                }
            }
            ForEach(topics.rows) { topic in
                Button { choose(topic.id, scope: scope) } label: { topicRow(topic, scope) }
                    .tint(.primary)
                    .disabled(pendingSelection != nil || creation.holdsSource)
                    .accessibilityIdentifier("club.sessionStart.topic.\(topic.id)")
            }
        } header: {
            Text("club.sessionStart.chooseTopic")
        }
    }
    private func topicRow(_ topic: ClubSessionQuickStartTopic, _ scope: ClubSessionQuickStartContext) -> some View {
        let name = topic.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return HStack {
            VStack(alignment: .leading, spacing: 6) {
                if name.isEmpty {
                    Label("club.sessionStart.unnamedTopic", systemImage: "flag")
                } else {
                    Label(name, systemImage: "flag")
                }
                Group {
                    LabeledContent("club.gov.field.topicId") { Text(verbatim: String(topic.id)).monospacedDigit() }
                    Label(LocalizedStringKey(topic.originKey(currentClubID: scope.clubID)), systemImage: "person.2")
                    if let date = topic.startDate {
                        LabeledContent("club.sessionStart.startDate") { Text(verbatim: date).monospacedDigit() }
                    }
                    if let date = topic.endDate {
                        LabeledContent("club.sessionStart.endDate") { Text(verbatim: date).monospacedDigit() }
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
    private func creationSource(_ item: ClubSeriesCreationReturn.Item) -> ClubSeriesCreationReturn.Source? {
        guard case .quickStart(let target) = item.source.proof, current(target) else { return nil }
        return .quickStart(target, access: governance.access)
    }
    private func finishCreationReturn() {
        guard let item = creation.item else { return }
        Task { @MainActor in
            guard !Task.isCancelled, hostVisible, scenePhase == .active, creation.item?.id == item.id else { return }
            creation.consume(source: creationSource(item), visible: hostVisible, active: scenePhase == .active)
        }
    }
    private func current(_ value: ClubSessionQuickStartTarget) -> Bool {
        model.isCurrent(value, context: context, reader: reader, access: governance.access, viewerRevision: governance.viewerRevision)
    }
    private func reload(_ scope: ClubSessionQuickStartContext) {
        guard hostVisible, scenePhase == .active, !creation.holdsSource, context == scope, scope.matches(reader: reader, access: governance.access, viewerRevision: governance.viewerRevision), let permit = model.permit(in: scope) else { return }
        Task { await model.read(permit, reader: reader, access: governance.access, viewerRevision: { governance.viewerRevision },
            isCurrent: { hostVisible && scenePhase == .active && !creation.holdsSource && context == scope }) }
    }
    private func choose(_ topicID: Int, scope: ClubSessionQuickStartContext) {
        guard hostVisible, scenePhase == .active, !creation.holdsSource, pendingSelection == nil, context == scope, accepted(scope)?.rows.contains(where: { $0.id == topicID }) == true,
              let permit = model.permit(in: scope) else { return }
        let ticket = UUID(); pendingSelection = ticket
        Task {
            let selected = await model.read(permit, selecting: topicID, reader: reader, access: governance.access, viewerRevision: { governance.viewerRevision },
                isCurrent: { hostVisible && scenePhase == .active && pendingSelection == ticket && context == scope })
            guard pendingSelection == ticket else { return }; pendingSelection = nil
            guard let selected, !creation.holdsSource, current(selected) else { return }
            creation.open(.quickStart(selected, access: governance.access), visible: hostVisible, active: scenePhase == .active)
        }
    }
}

private struct ClubCloud14Banner: View {
    let seed: String
    var symbol: String? = nil
    var imageURL: URL? = nil
    var body: some View {
        Color.clear
            .aspectRatio(2.4, contentMode: .fit)
            .overlay {
                CYCoverArt(seed: seed, symbol: symbol)
                if let imageURL {
                    AsyncImage(url: imageURL) { phase in
                        if let image = phase.image { image.resizable().scaledToFill() }
                    }
                }
            }
            .clipped()
            .accessibilityHidden(true)
    }
}

private enum ClubCloud14HTTPS {
    static func url(_ raw: String?) -> URL? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty,
              let url = URL(string: raw), url.scheme?.lowercased() == "https" else { return nil }
        return url
    }
}
