import SwiftUI

/// Owns the whole contextual read/choice/report lifetime; writes remain in the original coordinator.
@MainActor final class ClubActivityReportFlow: ObservableObject {
    let source: ClubActivityReportSource
    let reader: any ClubReading
    let access: any ClubGovernanceAccess
    private let sourceIsCurrent: () -> Bool
    private let namespace: String
    private let readerID: ObjectIdentifier
    @Published private(set) var choices: [ClubActivityReportChoice] = []
    @Published private(set) var target: ClubActivityReportTarget?
    @Published private(set) var loading = false
    @Published private(set) var failure: ClubGovernanceFailure?
    private var active = true
    private var generation: UInt64 = 0
    init(source: ClubActivityReportSource, reader: any ClubReading, access: any ClubGovernanceAccess,
         sourceIsCurrent: @escaping () -> Bool) {
        self.source = source; self.reader = reader; self.access = access; self.sourceIsCurrent = sourceIsCurrent
        namespace = access.storageNamespace; readerID = ObjectIdentifier(reader)
    }
    var isCurrent: Bool {
        active && sourceIsCurrent() && reader.isClubConfigured && access.isConfigured &&
        source.context.identity == reader.clubIdentity && source.context.identity == access.identity &&
        source.context.accessIdentity == ObjectIdentifier(access) && readerID == ObjectIdentifier(reader) &&
        source.context.authorizationGeneration == access.authorizationGeneration && namespace == access.storageNamespace
    }
    func close() { active = false; generation &+= 1; choices = []; target = nil; loading = false; failure = nil }
    private func readCurrent(_ revision: UInt64) async throws -> [ClubActivityReportChoice] {
        func check() throws {
            guard isCurrent, generation == revision, !Task.isCancelled else { throw CancellationError() }
        }
        try check()
        let club = try await reader.clubDetail(id: source.context.scope.clubID ?? 0, isCurrent: { [self] in
            isCurrent && generation == revision && !Task.isCancelled
        })
        try check()
        guard club.id == source.context.scope.clubID, club.canSeeMembers else { throw ClubGovernanceFailure.forbidden }
        // Re-read list membership and author as well as the public topic response.
        let topics = try await access.read(.topics, scope: source.context.scope, options: [:], check: check)
        try check()
        guard source.matches(club: club, snapshot: topics) else { throw ClubGovernanceFailure.targetChanged }
        let topic = try await access.read(.topicOverview, scope: source.scope, options: [:], check: check)
        try check()
        return try source.activities(topic)
    }
    func load() async {
        guard isCurrent, !loading, target == nil else { return }
        generation &+= 1; let revision = generation; loading = true; choices = []; failure = nil
        defer { if generation == revision { loading = false } }
        do {
            let rows = try await readCurrent(revision)
            guard isCurrent, generation == revision else { return }
            choices = rows
            if rows.count == 1 { target = .init(source: source, choice: rows[0], choices: rows) }
        } catch { fail(error, revision: revision) }
    }
    func select(_ choice: ClubActivityReportChoice) async {
        guard isCurrent, !loading, target == nil, choices.contains(choice), choices.filter({ $0.id == choice.id }).count == 1 else { return }
        generation &+= 1; let revision = generation; loading = true; choices = []; failure = nil
        defer { if generation == revision { loading = false } }
        do {
            let rows = try await readCurrent(revision)
            guard isCurrent, generation == revision else { return }
            guard let selected = rows.first(where: { $0.id == choice.id }) else { throw ClubGovernanceFailure.targetChanged }
            choices = rows; target = .init(source: source, choice: selected, choices: rows)
        } catch { fail(error, revision: revision) }
    }
    /// Called before each original review and confirmation. A failed read never grants permission.
    func validate(_ expected: ClubActivityReportTarget) async throws {
        guard isCurrent, !loading, target == expected else { throw ClubGovernanceFailure.targetChanged }
        generation &+= 1; let revision = generation; loading = true
        defer { if generation == revision { loading = false } }
        do {
            let rows = try await readCurrent(revision)
            guard isCurrent, generation == revision, target == expected,
                  rows.filter({ $0.id == expected.choice.id }).count == 1,
                  rows.first(where: { $0.id == expected.choice.id }) == expected.choice else { throw ClubGovernanceFailure.targetChanged }
            choices = rows; failure = nil
        } catch {
            fail(error, revision: revision)
            throw error
        }
    }
    private func fail(_ error: Error, revision: UInt64) {
        guard active, generation == revision else { return }
        choices = []; failure = error as? ClubGovernanceFailure ?? .targetChanged
        // Keep immutable report draft on transient preflight failure; it cannot submit until revalidation succeeds.
        if !isCurrent { close() }
    }
}

@MainActor struct ClubActivityReportView: View {
    @ObservedObject var flow: ClubActivityReportFlow
    let coordinator: ClubGovernanceCoordinator
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.cyPalette) private var palette
    var body: some View {
        Group {
            if !flow.isCurrent { changedScreen }
            else if let target = flow.target { targetScreen(target) }
            else { choiceScreen }
        }
        .cyDomainPageBackground()
        .task { await flow.load() }
        .onChange(of: flow.isCurrent) { _, current in if !current { close() } }
        .onChange(of: scenePhase) { _, phase in if phase != .active { close() } }
        .onDisappear { flow.close(); coordinator.cancelReview() }
        .accessibilityIdentifier("club.activityReport.flow")
        .cyDomainScreen(.player)
    }
    private var changedScreen: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CYSpacing.lg) {
                CYHeroHeader("club.activityReport.title")
                Text("club.gov.changed")
                    .cyText(.body)
                    .foregroundStyle(palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, CYSpacing.pageHorizontal)
            .padding(.vertical, CYSpacing.lg)
        }
    }
    private func targetScreen(_ target: ClubActivityReportTarget) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: CYSpacing.lg) {
                CYHeroHeader("club.activityReport.title")
                VStack(alignment: .leading, spacing: CYSpacing.sm) {
                    Text("club.activityReport.target")
                        .cyText(.meta)
                        .foregroundStyle(palette.textSecondary)
                    choiceTitle(target.choice.name)
                        .cyText(.cardTitle)
                        .foregroundStyle(palette.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let when = schedule(target.choice.startDate, target.choice.startTime) {
                        Text(verbatim: when)
                            .cyText(.bodyCompact)
                            .foregroundStyle(palette.textSecondary)
                            .monospacedDigit()
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text("club.activityReport.platformHint")
                        .cyText(.meta)
                        .foregroundStyle(palette.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .cyDomainCard(radius: CYRadius.card, padding: CYSpacing.lg)
                .accessibilityElement(children: .combine)
            }
            .padding(.horizontal, CYSpacing.pageHorizontal)
            .padding(.top, CYSpacing.lg)
            ClubGovernanceCommandForm(route: .init(operation: .report, scope: target.scope,
                seed: target.seed.merging(ClubGovernanceReportPort.displayName(target.choice.name).map { ["targetName": ClubGovernanceValue.string($0)] } ?? [:]) { current, _ in current }),
                identity: target.source.context.identity, access: flow.access, coordinator: coordinator,
                validateTarget: { try await flow.validate(target) })
                .id(target.id)
        }
        .cyHeroScreen()
    }
    private var choiceScreen: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CYSpacing.lg) {
                CYHeroHeader("club.activityReport.title", subtitle: "club.activityReport.chooseHint")
                if flow.loading && flow.choices.isEmpty && flow.failure == nil {
                    CYSkeleton().accessibilityLabel(Text("club.loading"))
                }
                if let failure = flow.failure {
                    CYEmptyState(
                        systemImage: "exclamationmark.triangle",
                        LocalizedStringKey(failure.localizationKey),
                        actionTitle: "club.activityReport.retry",
                        actionStyle: .primary,
                        kind: .failure
                    ) { Task { await flow.load() } }
                }
                if !flow.loading && flow.failure == nil && flow.choices.isEmpty {
                    CYEmptyState(
                        systemImage: "flag",
                        "club.activityReport.empty",
                        actionTitle: "club.activityReport.retry",
                        actionStyle: .primary
                    ) { Task { await flow.load() } }
                }
                ForEach(flow.choices) { choice in
                    Button { Task { await flow.select(choice) } } label: { choiceRow(choice) }
                        .buttonStyle(.cyPressable)
                        .disabled(flow.loading)
                        .accessibilityIdentifier("club.activityReport.choose.\(choice.id)")
                }
                if flow.failure == nil && (!flow.choices.isEmpty || flow.loading) {
                    CYPillButton("club.activityReport.retry", style: .secondary) { Task { await flow.load() } }
                        .disabled(flow.loading)
                }
            }
            .padding(.horizontal, CYSpacing.pageHorizontal)
            .padding(.vertical, CYSpacing.lg)
        }
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("action.cancel") { dismiss() } } }
    }
    private func choiceRow(_ choice: ClubActivityReportChoice) -> some View {
        HStack(alignment: .center, spacing: CYSpacing.md) {
            CYRowIcon(systemImage: "flag")
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                choiceTitle(choice.name)
                    .cyText(.cardTitle)
                    .foregroundStyle(palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                if let when = schedule(choice.startDate, choice.startTime) {
                    Text(verbatim: when)
                        .cyText(.meta)
                        .foregroundStyle(palette.textTertiary)
                        .monospacedDigit()
                        .fixedSize(horizontal: false, vertical: true)
                }
                LabeledContent("club.gov.field.activityId") {
                    Text(verbatim: String(choice.id)).monospacedDigit()
                }
                .cyText(.meta)
                .foregroundStyle(palette.textSecondary)
            }
            Spacer(minLength: CYSpacing.sm)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(palette.textTertiary)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget, alignment: .leading)
        .cyDomainCard(radius: CYRadius.card, padding: CYSpacing.lg)
        .accessibilityElement(children: .combine)
    }
    @ViewBuilder private func choiceTitle(_ name: String?) -> some View {
        if let name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Text(verbatim: name)
        } else {
            Text("club.activityReport.unnamed")
        }
    }
    private func schedule(_ date: String?, _ time: String?) -> String? {
        let parts = [date, time].compactMap { value -> String? in
            guard let value else { return nil }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
    private func close() { flow.close(); coordinator.cancelReview(); dismiss() }
}

/// Stable calendar ownership, separate from lazy rows and from sheet-cover visibility.
@MainActor final class ClubActivityReportPresentation: ObservableObject {
    struct Host: Equatable {
        let context: ClubGovernanceReadContext
        let readerID: ObjectIdentifier?
        let club: ClubRecord?
    }
    struct Item: Identifiable {
        let id: UUID
        let host: Host
        let flow: ClubActivityReportFlow
    }
    struct ReadTicket {
        let id: UUID
        let host: Host
        let revision: UInt64
    }
    @Published private(set) var presented: Item?
    @Published private(set) var requested = false
    private(set) var visible = false
    private var active = false
    private var bound: Host?
    private var pendingReturn: Host?
    private var revision: UInt64 = 0
    private var scheduledRead: UUID?
    @discardableResult func bind(_ host: Host, active: Bool) -> Bool {
        guard bound != host || self.active != active else { return false }
        let cancelled = cancel()
        bound = host; self.active = active
        return cancelled
    }
    @discardableResult func appear(_ host: Host, active: Bool) -> Bool {
        let cancelled = bind(host, active: active); visible = true
        return cancelled
    }
    func disappear() {
        visible = false; revision &+= 1; scheduledRead = nil
        // A sheet can cover this parent. Keep its exact item until dismissal,
        // but no hidden parent is allowed to consume a return or start a read.
    }
    func canOpen(_ host: Host) -> Bool {
        visible && active && bound == host && presented == nil && pendingReturn == nil && scheduledRead == nil
    }
    func open(_ flow: ClubActivityReportFlow, host: Host) -> Bool {
        guard canOpen(host) else { flow.close(); return false }
        presented = .init(id: flow.source.id, host: host, flow: flow); requested = true
        return true
    }
    func isPresenting(_ sourceID: UUID, host: Host) -> Bool {
        active && bound == host && presented?.id == sourceID && requested
    }
    func isCurrent(_ item: Item) -> Bool {
        isPresenting(item.id, host: item.host) && item.flow.isCurrent
    }
    func requestDismiss(_ id: UUID) {
        guard let item = presented, item.id == id else { return }
        requested = false; item.flow.close()
    }
    /// The caller may cancel the matching review only when this returns true.
    @discardableResult func dismissed(_ id: UUID) -> Bool {
        guard let item = presented, item.id == id else { return false }
        item.flow.close(); presented = nil; requested = false
        pendingReturn = active && bound == item.host ? item.host : nil
        return true
    }
    @discardableResult func cancel() -> Bool {
        let hadItem = presented != nil
        presented?.flow.close(); presented = nil; requested = false; pendingReturn = nil
        revision &+= 1; scheduledRead = nil
        return hadItem
    }
    var hasPendingReturn: Bool { pendingReturn != nil }
    func beginRead(_ host: Host, returning: Bool = false) -> ReadTicket? {
        guard visible, active, bound == host, presented == nil, scheduledRead == nil,
              !returning || pendingReturn == host else { return nil }
        pendingReturn = nil
        let ticket = ReadTicket(id: UUID(), host: host, revision: revision)
        scheduledRead = ticket.id; return ticket
    }
    func canRead(_ ticket: ReadTicket) -> Bool {
        visible && active && bound == ticket.host && revision == ticket.revision && scheduledRead == ticket.id && presented == nil
    }
    func endRead(_ ticket: ReadTicket) { if scheduledRead == ticket.id { scheduledRead = nil } }
}

/// An onDismiss callback always carries the concrete item UUID, never an initial nil capture.
@MainActor struct ClubActivityReportSheetOwner: View {
    let item: ClubActivityReportPresentation.Item
    @ObservedObject var presentation: ClubActivityReportPresentation
    let coordinator: ClubGovernanceCoordinator
    let dismissed: (UUID) -> Void
    var presentationBinding: Binding<Bool> {
        Binding(get: { presentation.isCurrent(item) }, set: { shown in
            if !shown { presentation.requestDismiss(item.id) }
        })
    }
    var body: some View {
        Color.clear.sheet(isPresented: presentationBinding, onDismiss: { dismissed(item.id) }) { Group {
            NavigationStack { ClubActivityReportView(flow: item.flow, coordinator: coordinator) }
        }.cySheet(detents: [.large])
        }
    }
}
