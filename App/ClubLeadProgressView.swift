import SwiftUI

/// Maps reads the lead-progress page already makes into `ClubOwnerStageMachine`. Not a new Core type.
enum ClubOwnerStageNow {
    static func resolve(club: ClubRecord, topics: ClubGovernanceSnapshot, invitations: CoopFlowJSON, projects: CreatorContentProjectPage) -> ClubOwnerStageResolution? {
        guard club.id > 0 else { return nil }
        if club.canGovern, !club.isOwner {
            return ClubOwnerStageMachine.resolve(.init(isOwner: false, canGovern: true, clubID: club.id, topicState: "ready"))
        }
        guard club.isOwner else { return nil }
        if (try? ClubGovernanceValidation.validate(topics.value, operation: .topics, scope: topics.scope)) == nil {
            return ClubOwnerStageMachine.resolve(.init(isOwner: true, canGovern: club.canGovern, clubID: club.id, topicState: "error"))
        }
        let rows = topics.value.array ?? []
        var stageTopics: [ClubOwnerStageTopic] = []
        for row in rows {
            guard let id = row["id"].int, id > 0 else { continue }
            stageTopics.append(.init(
                id: id,
                productType: row["productType"].int,
                mode: row["mode"].int,
                lifecycle: row["lifecycle"].int,
                saleReviewPending: row["saleReviewPending"].bool == true,
                name: row["name"].string ?? row["title"].string ?? "",
                uncontractedStations: (row["uncontractedStations"].array ?? []).compactMap(\.string)
            ))
        }
        let stageProjects = projects.rows.compactMap { row -> ClubOwnerStageProject? in
            guard let clubID = row.clubID, clubID > 0 else { return nil }
            return .init(clubID: clubID, acceptStatus: row.acceptStatus ?? "", bizType: row.bizType, state: row.state ?? "")
        }
        var sent: [ClubOwnerStageInvite] = []
        for raw in invitations["sent"].rows ?? [] {
            if let topicID = raw["topicId"].integer ?? raw["topicID"].integer, topicID > 0, let status = raw["status"].integer {
                sent.append(.init(topicID: topicID, status: status))
            }
        }
        var messages: [ClubOwnerStageMessage] = []
        for raw in invitations["received"].rows ?? [] {
            messages.append(.init(
                status: raw["status"].integer ?? -1,
                toType: raw["toType"].text ?? "",
                toID: raw["toId"].integer ?? raw["toID"].integer ?? 0,
                topicID: raw["topicId"].integer ?? raw["topicID"].integer
            ))
        }
        return ClubOwnerStageMachine.resolve(.init(
            isOwner: true, canGovern: club.canGovern, clubID: club.id, topicState: "ready",
            ownerProjectState: projects.isTruncated ? "partial" : "ready", inviteFeedbackState: "ready",
            topics: stageTopics, manageTopicIDs: Set(stageTopics.map(\.id)),
            projects: stageProjects, sentInvites: sent, messages: messages
        ))
    }
}

@MainActor final class ClubLeadProgressReadModel: ObservableObject {
    struct Permit: Equatable { let context: ClubLeadProgressContext; let visibility: UUID }
    enum Phase: Equatable { case idle, loading, ready, failed, denied }
    @Published private(set) var phase: Phase = .idle
    @Published private(set) var snapshot: ClubLeadProgressSnapshot?
    @Published private(set) var ownerStage: ClubOwnerStageResolution?
    private var bound: ClubLeadProgressContext?
    private var loaded: ClubLeadProgressContext?
    private var visibility: UUID?
    private var generation = UUID()
    func bind(_ context: ClubLeadProgressContext) {
        guard bound != context else { return }; bound = context; visibility = nil; generation = UUID()
    }
    func activate(_ context: ClubLeadProgressContext) -> Permit? {
        guard bound == context, context.canRead, !Task.isCancelled else { return nil }
        if visibility == nil { visibility = UUID(); generation = UUID(); loaded = nil; snapshot = nil; ownerStage = nil; phase = .idle }
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
        guard bound == context else { return }; visibility = nil; generation = UUID(); loaded = nil; snapshot = nil; ownerStage = nil; phase = .idle
    }
    func load(_ permit: Permit, clubReader: any ClubReading, reader: any CoopFlowReading, access: any ClubGovernanceAccess, projects: any CreatorContentReading) async {
        guard accepts(permit), permit.context.matches(clubReader: clubReader, reader: reader, access: access, projects: projects), !Task.isCancelled else { return }
        generation = UUID(); let request = generation
        snapshot = nil; loaded = nil; ownerStage = nil; phase = .loading
        let current = { [self] in
            accepts(permit) && generation == request && !Task.isCancelled && permit.context.matches(clubReader: clubReader, reader: reader, access: access, projects: projects)
        }
        defer { if generation == request, accepts(permit), phase == .loading { phase = .idle } }
        do {
            let freshClub = try await clubReader.clubDetail(id: permit.context.feedback.clubID, isCurrent: current)
            guard current() else { return }
            guard freshClub.id == permit.context.feedback.clubID, freshClub.isOwner else { ownerStage = nil; phase = .denied; return }
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
            ownerStage = ClubOwnerStageNow.resolve(club: freshClub, topics: topics, invitations: invitations, projects: page)
            loaded = permit.context; snapshot = projected; phase = .ready
        } catch {
            guard current() else { return }; ownerStage = nil; phase = .failed
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
                    Label("club.leadProgress.title", systemImage: "list.bullet.indent")
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
            if !scope.canRead || model.phase == .denied {
                ContentUnavailableView {
                    Label { Text("club.leadProgress.ownerRequired").accessibilityIdentifier("club.leadProgress.denied") } icon: { Image(systemName: "person.crop.circle.badge.exclamationmark") }
                }
            }
            else {
                if model.phase == .loading {
                    ProgressView { Text("club.leadProgress.loading") }
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("club.leadProgress.loading")
                }
                if model.phase == .failed {
                    ContentUnavailableView {
                        Label { Text("club.leadProgress.failed").accessibilityIdentifier("club.leadProgress.failed") } icon: { Image(systemName: "exclamationmark.triangle") }
                    }
                }
                if let snapshot = model.accepted(scope, clubReader: clubReader, reader: reader, access: access, projects: projects) {
                    Section {
                        Label(LocalizedStringKey(snapshot.stage.titleKey), systemImage: "flag")
                            .accessibilityIdentifier("club.leadProgress.stage")
                        if snapshot.hasPartialProjects {
                            Label("club.leadProgress.partial", systemImage: "exclamationmark.triangle")
                                .foregroundStyle(CYColor.warningText)
                                .accessibilityIdentifier("club.leadProgress.partial")
                        }
                        countRow("club.leadProgress.topicCount", snapshot.topicCount, symbol: "map")
                        countRow("club.leadProgress.sentCount", snapshot.sentCount, symbol: "paperplane")
                        countRow("club.leadProgress.pendingCount", snapshot.pendingCount, symbol: "clock")
                    }
                    if !snapshot.nodes.isEmpty {
                        Section {
                            DisclosureGroup(isExpanded: $expanded) {
                                ForEach(snapshot.nodes) { node in
                                    VStack(alignment: .leading, spacing: CYSpacing.sm) {
                                        Label {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(LocalizedStringKey(node.titleKey))
                                                nodeDescription(node.id, snapshot).font(.subheadline).foregroundStyle(.secondary)
                                                Text(LocalizedStringKey(node.stateKey)).font(.footnote).foregroundStyle(.secondary)
                                            }
                                        } icon: {
                                            Image(systemName: node.state == .done ? "checkmark.circle" : node.state == .doing ? "record.circle" : "circle")
                                        }
                                        if node.id == 1, let time = snapshot.invitationTimeText {
                                            LabeledContent("club.leadProgress.invitationTime", value: time)
                                        }
                                    }.accessibilityElement(children: .combine)
                                        .accessibilityIdentifier("club.leadProgress.node.\(node.id)")
                                }
                            } label: {
                                timelineSummary(snapshot)
                            }.accessibilityIdentifier("club.leadProgress.toggle")
                        }
                    }
                }
                ClubLeadPrimaryActionSection(context: scope,
                    snapshot: model.accepted(scope, clubReader: clubReader, reader: reader, access: access, projects: projects),
                    ownerStage: model.accepted(scope, clubReader: clubReader, reader: reader, access: access, projects: projects) == nil ? nil : model.ownerStage,
                    destinations: destinations,
                    isCurrent: { context == scope && scope.matches(clubReader: clubReader, reader: reader, access: access, projects: projects) },
                    refresh: {
                        guard context == scope, let permit = model.permit(in: scope) else { return nil }
                        await model.load(permit, clubReader: clubReader, reader: reader, access: access, projects: projects)
                        return model.accepted(scope, clubReader: clubReader, reader: reader, access: access, projects: projects)
                    }, onReturn: { reload(scope) })
                Button(LocalizedStringKey(model.phase == .failed ? "action.retry" : "club.refresh")) { reload(scope) }
                    .disabled(model.phase == .loading || model.permit(in: scope) == nil)
                    .accessibilityIdentifier("club.leadProgress.reload")
            }
        }
        .cyPageTitle("club.leadProgress.title")
        .task(id: scope) {
            guard let permit = model.activate(scope) else { return }
            await model.load(permit, clubReader: clubReader, reader: reader, access: access, projects: projects)
        }
        .onChange(of: scope) { _, _ in expanded = false }
        .onDisappear { model.leave(scope) }
    }
    /// Counts are projected integers. A real 0 stays 0; this reader has no unknown count.
    private func countRow(_ title: LocalizedStringKey, _ count: Int, symbol: String) -> some View {
        LabeledContent {
            Text(verbatim: String(count)).monospacedDigit()
        } label: {
            Label(title, systemImage: symbol)
        }
    }
    /// MP `buildLeadTimeline` summary 「带队进度 · 当前站」 on the collapsed row.
    private func timelineSummary(_ snapshot: ClubLeadProgressSnapshot) -> Text {
        guard let key = snapshot.currentStationKey else { return Text("club.leadProgress.timeline") }
        let station = String(localized: String.LocalizationValue(key))
        return Text("club.leadProgress.summary \(station)")
    }
    /// MP `buildLeadTimeline` descs, one per station (pages/club/detail/index.js:1569-1574).
    private func nodeDescription(_ id: Int, _ snapshot: ClubLeadProgressSnapshot) -> Text {
        switch id {
        case 0: return snapshot.topicCount > 0 ? Text("club.leadProgress.desc.published \(snapshot.topicCount)") : Text("club.leadProgress.desc.publishFirst")
        case 1: return snapshot.sentCount > 0 ? Text("club.leadProgress.desc.sent \(snapshot.sentCount)") : Text("club.leadProgress.desc.chooseTopic")
        case 2: return snapshot.pendingCount > 0 ? Text("club.leadProgress.desc.waiting \(snapshot.pendingCount)") : Text("club.leadProgress.desc.waitHere")
        default: return Text("club.leadProgress.desc.accepted")
        }
    }
    private func reload(_ scope: ClubLeadProgressContext) {
        guard context == scope, scope.matches(clubReader: clubReader, reader: reader, access: access, projects: projects), let permit = model.permit(in: scope) else { return }
        Task { await model.load(permit, clubReader: clubReader, reader: reader, access: access, projects: projects) }
    }
}
