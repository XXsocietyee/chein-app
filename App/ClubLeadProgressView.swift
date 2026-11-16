import SwiftUI

@MainActor final class ClubLeadProgressReadModel: ObservableObject {
    struct Permit: Equatable { let context: ClubLeadProgressContext; let visibility: UUID }
    enum Phase: Equatable { case idle, loading, ready, failed, denied }
    @Published private(set) var phase: Phase = .idle
    @Published private(set) var snapshot: ClubLeadProgressSnapshot?
    private var bound: ClubLeadProgressContext?
    private var loaded: ClubLeadProgressContext?
    private var visibility: UUID?
    private var generation = UUID()
    func bind(_ context: ClubLeadProgressContext) {
        guard bound != context else { return }; bound = context; visibility = nil; generation = UUID()
    }
    func activate(_ context: ClubLeadProgressContext) -> Permit? {
        guard bound == context, context.canRead, !Task.isCancelled else { return nil }
        if visibility == nil { visibility = UUID(); generation = UUID(); loaded = nil; snapshot = nil; phase = .idle }
        return permit(in: context)
    }
    func permit(in context: ClubLeadProgressContext) -> Permit? {
        guard bound == context, context.canRead, let visibility else { return nil }; return .init(context: context, visibility: visibility)
    }
    private func accepts(_ permit: Permit) -> Bool { bound == permit.context && visibility == permit.visibility && permit.context.canRead }
    func accepted(_ context: ClubLeadProgressContext, clubReader: any ClubReading, reader: any CoopFlowReading, access: any ClubGovernanceAccess, projects: any CreatorContentReading) -> ClubLeadProgressSnapshot? {
        guard permit(in: context) != nil, loaded == context, phase == .ready,
              context.matches(clubReader: clubReader, reader: reader, access: access, projects: projects) else { return nil }; return snapshot
    }
    func leave(_ context: ClubLeadProgressContext) {
        guard bound == context else { return }; visibility = nil; generation = UUID(); loaded = nil; snapshot = nil; phase = .idle
    }
    func load(_ permit: Permit, clubReader: any ClubReading, reader: any CoopFlowReading, access: any ClubGovernanceAccess, projects: any CreatorContentReading) async {
        guard accepts(permit), permit.context.matches(clubReader: clubReader, reader: reader, access: access, projects: projects), !Task.isCancelled else { return }
        generation = UUID(); let request = generation
        snapshot = nil; loaded = nil; phase = .loading
        let current = { [self] in
            accepts(permit) && generation == request && !Task.isCancelled && permit.context.matches(clubReader: clubReader, reader: reader, access: access, projects: projects)
        }
        defer { if generation == request, accepts(permit), phase == .loading { phase = .idle } }
        do {
            let freshClub = try await clubReader.clubDetail(id: permit.context.feedback.clubID, isCurrent: current)
            guard current() else { return }
            guard freshClub.id == permit.context.feedback.clubID, freshClub.isOwner else { phase = .denied; return }
            let topics = try await access.read(.topics, scope: .init(clubID: permit.context.feedback.clubID), options: [:]) {
                guard current() else { throw CancellationError() }
            }
            guard current(), permit.context.feedback.topicsContext.accepts(topics) else { throw CancellationError() }
            let invitations = try await reader.read(.invitations, isCurrent: current)
            guard current() else { return }
            let page = try await projects.projects(query: .init(type: "all", state: "all", ownerType: "club"))
            guard current() else { return }
            let projected = try ClubLeadProgressSnapshot(context: permit.context, topics: topics, invitations: invitations, projects: page)
            guard current() else { return }
            loaded = permit.context; snapshot = projected; phase = .ready
        } catch {
            guard current() else { return }; phase = .failed
        }
    }
}

@MainActor struct ClubLeadProgressEntry<ClubReader: ClubReading & ObservableObject>: View {
    let club: ClubRecord
    @ObservedObject var clubReader: ClubReader
    let reader: any CoopFlowReading
    let access: any ClubGovernanceAccess
    let projects: any CreatorContentReading
    var destinations = ClubLeadPrimaryDestinations()
    var body: some View {
        let context = ClubLeadProgressContext(club: club, clubReader: clubReader, reader: reader, access: access, projects: projects)
        if context.canRead {
            Section {
                NavigationLink {
                    ClubLeadProgressView(club: club, clubReader: clubReader, reader: reader, access: access, projects: projects, destinations: destinations)
                } label: {
                    CYListRow("club.leadProgress.title", trailing: .chevron) { CYRowIcon(systemImage: "list.bullet.indent") }
                }
                    .accessibilityIdentifier("club.leadProgress.entry")
            }
        }
    }
}

@MainActor struct ClubLeadProgressView<ClubReader: ClubReading & ObservableObject>: View {
    let club: ClubRecord
    @ObservedObject var clubReader: ClubReader
    let reader: any CoopFlowReading
    let access: any ClubGovernanceAccess
    let projects: any CreatorContentReading
    var destinations = ClubLeadPrimaryDestinations()
    @StateObject private var model = ClubLeadProgressReadModel()
    @State private var expanded = false
    private var context: ClubLeadProgressContext { .init(club: club, clubReader: clubReader, reader: reader, access: access, projects: projects) }
    var body: some View {
        let scope = context
        let _ = model.bind(scope)
        List {
            Section {
                CYHeroHeader("club.leadProgress.title")
            }
            .listRowInsets(EdgeInsets(top: CYSpacing.sm, leading: CYSpacing.pageHorizontal, bottom: CYSpacing.md, trailing: CYSpacing.pageHorizontal))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            if !scope.canRead || model.phase == .denied {
                CYEmptyState(systemImage: "person.crop.circle.badge.exclamationmark", "club.leadProgress.ownerRequired", messageIdentifier: "club.leadProgress.denied")
            }
            else {
                if model.phase == .loading {
                    CYSkeleton()
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(Text("club.leadProgress.loading"))
                        .accessibilityIdentifier("club.leadProgress.loading")
                }
                if model.phase == .failed {
                    CYEmptyState(systemImage: "exclamationmark.triangle", "club.leadProgress.failed", messageIdentifier: "club.leadProgress.failed", kind: .failure)
                }
                if let snapshot = model.accepted(scope, clubReader: clubReader, reader: reader, access: access, projects: projects) {
                    Section {
                        CYStatusChip(LocalizedStringKey(snapshot.stage.titleKey), tone: .neutral, systemImage: "flag")
                            .accessibilityIdentifier("club.leadProgress.stage")
                        if snapshot.hasPartialProjects {
                            CYStatusChip("club.leadProgress.partial", tone: .warning, systemImage: "exclamationmark.triangle")
                                .accessibilityIdentifier("club.leadProgress.partial")
                        }
                        countRow("club.leadProgress.topicCount", snapshot.topicCount, symbol: "map")
                        countRow("club.leadProgress.sentCount", snapshot.sentCount, symbol: "paperplane")
                        countRow("club.leadProgress.pendingCount", snapshot.pendingCount, symbol: "clock")
                    }
                    if !snapshot.nodes.isEmpty {
                        Section {
                            DisclosureGroup("club.leadProgress.timeline", isExpanded: $expanded) {
                                ForEach(snapshot.nodes) { node in
                                    VStack(alignment: .leading, spacing: CYSpacing.sm) {
                                        CYListRow(LocalizedStringKey(node.titleKey), meta: LocalizedStringKey(node.stateKey), trailing: .none) {
                                            CYRowIcon(systemImage: node.state == .done ? "checkmark.circle" : node.state == .doing ? "record.circle" : "circle")
                                        }
                                        if node.id == 1, let time = snapshot.invitationTimeText {
                                            LabeledContent("club.leadProgress.invitationTime", value: time)
                                        }
                                    }.accessibilityElement(children: .combine)
                                        .accessibilityIdentifier("club.leadProgress.node.\(node.id)")
                                }
                            }.accessibilityIdentifier("club.leadProgress.toggle")
                        }
                    }
                }
                ClubLeadPrimaryActionSection(context: scope,
                    snapshot: model.accepted(scope, clubReader: clubReader, reader: reader, access: access, projects: projects),
                    destinations: destinations,
                    isCurrent: { context == scope && scope.matches(clubReader: clubReader, reader: reader, access: access, projects: projects) },
                    refresh: {
                        guard context == scope, let permit = model.permit(in: scope) else { return nil }
                        await model.load(permit, clubReader: clubReader, reader: reader, access: access, projects: projects)
                        return model.accepted(scope, clubReader: clubReader, reader: reader, access: access, projects: projects)
                    }, onReturn: { reload(scope) })
                Button(LocalizedStringKey(model.phase == .failed ? "action.retry" : "club.refresh")) { reload(scope) }
                    .buttonStyle(CYPillButtonStyle(style: leadActionVisible(scope) ? .secondary : .primary, fullWidth: true))
                    .disabled(model.phase == .loading || model.permit(in: scope) == nil)
                    .accessibilityIdentifier("club.leadProgress.reload")
            }
        }
        .listStyle(.plain)
        .cyGroupedSurface()
        .cyHeroScreen()
        .task(id: scope) {
            guard let permit = model.activate(scope) else { return }
            await model.load(permit, clubReader: clubReader, reader: reader, access: access, projects: projects)
        }
        .onChange(of: scope) { _, _ in expanded = false }
        .onDisappear { model.leave(scope) }
    }
    /// Counts are projected integers. A real 0 stays 0; this reader has no unknown count.
    private func countRow(_ title: LocalizedStringKey, _ count: Int, symbol: String) -> some View {
        CYListRow(title, trailing: .value(String(count))) { CYRowIcon(systemImage: symbol) }
    }
    private func leadActionVisible(_ scope: ClubLeadProgressContext) -> Bool {
        guard let snapshot = model.accepted(scope, clubReader: clubReader, reader: reader, access: access, projects: projects) else { return false }
        return ClubLeadPrimaryAction(stage: snapshot.stage) != nil
    }
    private func reload(_ scope: ClubLeadProgressContext) {
        guard context == scope, scope.matches(clubReader: clubReader, reader: reader, access: access, projects: projects), let permit = model.permit(in: scope) else { return }
        Task { await model.load(permit, clubReader: clubReader, reader: reader, access: access, projects: projects) }
    }
}
