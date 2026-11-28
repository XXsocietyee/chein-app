import SwiftUI

/// A local read owner. Old retry/refresh callbacks are fenced before they can clear
/// a newer snapshot; the existing access layer still performs OWNER preflight.
@MainActor final class ClubStatsOverviewReadModel: ObservableObject {
    struct Permit: Equatable {
        let context: ClubGovernanceReadContext
        let visibility: UUID
    }
    @Published private(set) var snapshot: ClubStatsOverview?
    @Published private(set) var failure: ClubGovernanceFailure?
    @Published private(set) var loading = false
    private var loadedContext: ClubGovernanceReadContext?
    private var boundContext: ClubGovernanceReadContext?
    private var visibility: UUID?
    private var generation = UUID()

    /// No published mutation during body evaluation. Old callbacks are retired
    /// immediately, before SwiftUI runs the replacement task.
    func bind(_ context: ClubGovernanceReadContext) {
        guard boundContext != context else { return }
        boundContext = context; visibility = nil; generation = UUID()
    }
    func activate(_ context: ClubGovernanceReadContext) -> Permit? {
        guard !Task.isCancelled, boundContext == context else { return nil }
        if visibility == nil {
            visibility = UUID(); generation = UUID()
            snapshot = nil; loadedContext = nil; failure = nil; loading = false
        }
        return permit(in: context)
    }
    func permit(in context: ClubGovernanceReadContext) -> Permit? {
        guard boundContext == context, let visibility else { return nil }
        return .init(context: context, visibility: visibility)
    }
    func leave(_ context: ClubGovernanceReadContext) {
        guard boundContext == context else { return }
        visibility = nil; generation = UUID(); snapshot = nil; loadedContext = nil; failure = nil; loading = false
    }
    private func accepts(_ permit: Permit) -> Bool {
        boundContext == permit.context && visibility == permit.visibility
    }
    private func live(_ expected: ClubGovernanceReadContext, access: any ClubGovernanceAccess) -> Bool {
        expected.operation == .stats && (expected.scope.clubID ?? 0) > 0 &&
            (expected.identity?.accountID ?? 0) > 0 && access.isConfigured &&
            expected.identity == access.identity && expected.authorizationGeneration == access.authorizationGeneration &&
            expected.accessIdentity == ObjectIdentifier(access)
    }
    func accepted(_ context: ClubGovernanceReadContext, access: any ClubGovernanceAccess) -> ClubStatsOverview? {
        guard permit(in: context) != nil, loadedContext == context, live(context, access: access) else { return nil }
        return snapshot
    }
    func load(_ permit: Permit, access: any ClubGovernanceAccess) async {
        guard accepts(permit), !Task.isCancelled else { return }
        // Check mutable identity before touching current state as well as dispatch.
        guard live(permit.context, access: access) else {
            snapshot = nil; loadedContext = nil; loading = false
            failure = access.identity?.isSignedIn == true ? .notConfigured : .signedOut
            return
        }
        generation = UUID(); let request = generation
        snapshot = nil; loadedContext = nil; failure = nil; loading = true
        defer { if generation == request && accepts(permit) { loading = false } }
        func check() throws {
            guard accepts(permit), generation == request, live(permit.context, access: access), !Task.isCancelled else {
                throw CancellationError()
            }
        }
        do {
            try check()
            let source = try await access.read(.stats, scope: permit.context.scope, options: [:], check: check)
            try check()
            let overview = try ClubStatsOverview(snapshot: source, context: permit.context)
            loadedContext = permit.context; snapshot = overview
        } catch {
            guard accepts(permit), generation == request, live(permit.context, access: access), !Task.isCancelled else { return }
            failure = error as? ClubGovernanceFailure ?? .malformed
        }
    }
}

@MainActor struct ClubStatsOverviewView: View {
    let clubID: Int
    let identity: ClubReadIdentity
    let governance: ClubGovernanceContext
    @StateObject private var model = ClubStatsOverviewReadModel()
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private var context: ClubGovernanceReadContext {
        .init(operation: .stats, scope: .init(clubID: clubID), identity: identity,
              viewerRevision: governance.viewerRevision, authorizationGeneration: governance.access.authorizationGeneration,
              accessIdentity: ObjectIdentifier(governance.access))
    }
    private var reloadTitle: LocalizedStringKey {
        model.failure == nil ? LocalizedStringKey("club.gov.refresh") : LocalizedStringKey("action.retry")
    }
    var body: some View {
        let expected = context
        let _ = model.bind(expected)
        let permit = model.permit(in: expected)
        List {
            if model.loading || permit == nil {
                ProgressView { Text("club.loading") }
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("club.statsOverview.loading")
            }
            if permit != nil, let failure = model.failure {
                ContentUnavailableView {
                    Label {
                        Text(LocalizedStringKey(failure.localizationKey))
                            .accessibilityIdentifier("club.statsOverview.error")
                    } icon: {
                        Image(systemName: "exclamationmark.triangle")
                    }
                }
            }
            if let overview = model.accepted(expected, access: governance.access) {
                summary(overview)
                Section {
                    if overview.projects.isEmpty {
                        ContentUnavailableView {
                            Label {
                                Text("club.statsOverview.empty")
                                    .accessibilityIdentifier("club.statsOverview.empty")
                            } icon: {
                                Image(systemName: "square.stack.3d.up")
                            }
                        }
                    }
                    ForEach(overview.projects) { project in
                        projectCard(project)
                    }
                } header: {
                    Text("club.statsOverview.projects")
                } footer: {
                    if overview.hasMoreProjects {
                        Text("club.statsOverview.firstFive")
                    }
                }
            }
            Section {
                Button {
                    guard let permit else { return }
                    Task { await model.load(permit, access: governance.access) }
                } label: {
                    Label(reloadTitle, systemImage: "arrow.clockwise")
                }
                .disabled(model.loading || permit == nil)
                .accessibilityIdentifier("club.statsOverview.reload")
            }
        }
        .cyPageTitle("club.statsOverview.title")
        .task(id: expected) {
            guard let permit = model.activate(expected) else { return }
            await model.load(permit, access: governance.access)
        }
        .refreshable {
            guard let permit else { return }
            await model.load(permit, access: governance.access)
        }
        .onDisappear { model.leave(expected) }
    }
    private func summary(_ overview: ClubStatsOverview) -> some View {
        Section {
            let columns = Array(repeating: GridItem(.flexible(), alignment: .leading), count: dynamicTypeSize.isAccessibilitySize ? 1 : 2)
            LazyVGrid(columns: columns, alignment: .leading, spacing: CYSpacing.lg) {
                metric("club.statsOverview.topicCount", systemImage: "square.stack") { count(overview.topicCount) }
                metric("club.statsOverview.participants", systemImage: "person.2") { count(overview.participants) }
                metric("club.statsOverview.completed", systemImage: "checkmark.circle") { count(overview.completed) }
                metric("club.statsOverview.rate", systemImage: "percent") { rate(overview.completion) }
            }.accessibilityIdentifier("club.statsOverview.summary")
        } footer: {
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                Text("club.statsOverview.scope")
                Text("club.statsOverview.rateScope")
            }
        }
    }
    private func projectCard(_ project: ClubStatsProject) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            Label {
                projectTitle(project)
            } icon: {
                Image(systemName: "flag.checkered")
            }
            countRow("club.statsOverview.participants", project.participants, systemImage: "person.2")
            countRow("club.statsOverview.completed", project.completed, systemImage: "checkmark.circle")
            rateRow(project.completion)
        }
        .padding(.vertical, CYSpacing.xs)
        .accessibilityIdentifier("club.statsOverview.project.\(project.id)")
    }
    @ViewBuilder private func projectTitle(_ project: ClubStatsProject) -> some View {
        Group {
            if let name = project.name, !name.isEmpty { Text(verbatim: name) }
            else if project.name == nil { Text("club.statsOverview.unnamed") }
            else { Text(verbatim: "—").accessibilityLabel(Text("club.statsOverview.unnamed")) }
        }
        .font(.headline)
        .fixedSize(horizontal: false, vertical: true)
    }
    private func countRow(_ title: LocalizedStringKey, _ value: Int?, systemImage: String) -> some View {
        LabeledContent { Text(verbatim: countText(value)).monospacedDigit() } label: { Label(title, systemImage: systemImage) }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(countLabel(title, value))
    }
    private func rateRow(_ value: ClubStatsCompletion) -> some View {
        LabeledContent { Text(verbatim: rateText(value)).monospacedDigit() } label: { Label("club.statsOverview.rate", systemImage: "percent") }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(rateLabel(value))
    }
    private func metric<Value: View>(_ title: LocalizedStringKey, systemImage: String, @ViewBuilder value: () -> Value) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            value()
                .cyText(.numericTitle)
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
    }
    @ViewBuilder private func count(_ value: Int?) -> some View {
        if let value { Text(value, format: .number) }
        else { Text(verbatim: "—").accessibilityLabel(Text("club.statsOverview.unknown")) }
    }
    @ViewBuilder private func rate(_ value: ClubStatsCompletion) -> some View {
        switch value {
        case .percentage(let sourcePercentage):
            // Unit conversion for the standard percent formatter, not a new denominator.
            Text(sourcePercentage / 100, format: .percent.precision(.fractionLength(1)))
        case .noParticipants:
            Text(verbatim: "—").accessibilityLabel(Text("club.statsOverview.noParticipants"))
        case .unknown:
            Text(verbatim: "—").accessibilityLabel(Text("club.statsOverview.unknown"))
        }
    }
    private func countText(_ value: Int?) -> String { value?.formatted(.number) ?? "—" }
    private func countLabel(_ title: LocalizedStringKey, _ value: Int?) -> Text {
        if let value { return Text(title) + Text(verbatim: " ") + Text(value, format: .number) }
        return Text(title) + Text(verbatim: " ") + Text("club.statsOverview.unknown")
    }
    private func rateText(_ value: ClubStatsCompletion) -> String {
        switch value {
        case .percentage(let sourcePercentage):
            return (sourcePercentage / 100).formatted(.percent.precision(.fractionLength(1)))
        case .noParticipants, .unknown:
            return "—"
        }
    }
    private func rateLabel(_ value: ClubStatsCompletion) -> Text {
        switch value {
        case .percentage(let sourcePercentage):
            return Text("club.statsOverview.rate") + Text(verbatim: " ") + Text(sourcePercentage / 100, format: .percent.precision(.fractionLength(1)))
        case .noParticipants:
            return Text("club.statsOverview.rate") + Text(verbatim: " ") + Text("club.statsOverview.noParticipants")
        case .unknown:
            return Text("club.statsOverview.rate") + Text(verbatim: " ") + Text("club.statsOverview.unknown")
        }
    }
}
