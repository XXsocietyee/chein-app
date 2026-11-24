import SwiftUI

@MainActor final class ClubProjectLaunchModel: ObservableObject {
    struct Permit: Equatable { let context: ClubProjectLaunchContext; let visibility: UUID }
    enum Phase: Equatable { case idle, loading, ready, failed, denied, editorUnavailable }
    @Published private(set) var phase: Phase = .idle
    @Published private(set) var target: ClubProjectLaunchTarget?
    private var bound: ClubProjectLaunchContext?
    private var visibility: UUID?
    private var generation = UUID()
    func activate(_ context: ClubProjectLaunchContext) -> Permit? {
        guard !Task.isCancelled else { return nil }
        guard context.canRead else { leave(); return nil }
        if bound != context || visibility == nil { bound = context; visibility = UUID(); generation = UUID(); target = nil; phase = .idle }
        return permit(in: context)
    }
    func permit(in context: ClubProjectLaunchContext) -> Permit? {
        guard bound == context, context.canRead, let visibility else { return nil }; return .init(context: context, visibility: visibility)
    }
    func leave() { visibility = nil; generation = UUID(); target = nil; phase = .idle }
    private func accepts(_ p: Permit) -> Bool { bound == p.context && visibility == p.visibility && p.context.canRead }
    func isCurrent(_ value: ClubProjectLaunchTarget, context: ClubProjectLaunchContext, reader: any ClubReading, editorContextID: String) -> Bool {
        target == value && value.context == context && permit(in: context) != nil && context.matches(reader: reader, editorContextID: editorContextID)
    }
    func unavailable(_ value: ClubProjectLaunchTarget) {
        guard target == value else { return }; target = nil; phase = .editorUnavailable
    }
    /// Both initial entry and every mode choice re-read ownership; choosing never sends a project.
    @discardableResult func read(_ p: Permit, product: ProjectEditProduct? = nil, reader: any ClubReading, editorContextID: @escaping () -> String) async -> ClubProjectLaunchTarget? {
        guard accepts(p), p.context.matches(reader: reader, editorContextID: editorContextID()), !Task.isCancelled else { return nil }
        generation = UUID(); let request = generation
        target = nil; phase = .loading
        let current = { [self] in accepts(p) && generation == request && !Task.isCancelled && p.context.matches(reader: reader, editorContextID: editorContextID()) }
        defer { if accepts(p), generation == request, phase == .loading { phase = .idle } }
        do {
            let club = try await reader.clubDetail(id: p.context.clubID, isCurrent: current)
            guard current() else { return nil }
            guard club.id == p.context.clubID, club.isOwner else { phase = .denied; return nil }
            if let product { target = try .init(context: p.context, product: product) }
            phase = .ready; return target
        } catch {
            guard current() else { return nil }; phase = .failed; return nil
        }
    }
}

@MainActor struct ClubProjectEditorPresentation: Identifiable {
    let target: ClubProjectLaunchTarget
    let coordinator: ProjectEditCoordinator
    let session: ProjectEditSession
    var id: UUID { target.id }
    init?(target: ClubProjectLaunchTarget, coordinator: ProjectEditCoordinator) {
        guard let session = coordinator.session, target.matches(projectSession: session) else { return nil }
        self.target = target; self.coordinator = coordinator; self.session = session
    }
    var hasCurrentSession: Bool { coordinator.session == session && target.matches(projectSession: session) }
}

@MainActor struct SessionClubProjectLaunchView: View {
    @ObservedObject var session: AppSession
    let club: ClubRecord
    @Environment(\.dismiss) private var dismiss
    @Environment(\.cyPalette) private var palette
    @StateObject private var model = ClubProjectLaunchModel()
    @State private var presented: ClubProjectEditorPresentation?
    private var context: ClubProjectLaunchContext { .init(club: club, reader: session, editorContextID: session.projectEditorContextID) }
    var body: some View {
        let scope = context
        List {
            Section {
                CYHeroHeader("club.projectLaunch.title") {
                    ClubCloud14Banner(seed: clubBannerSeed, symbol: "map", imageURL: ClubCloud14HTTPS.url(club.cover))
                }
                .listRowBackground(Color.clear).listRowSeparator(.hidden)
                Text("club.projectLaunch.localHint")
                    .cyText(.body).foregroundStyle(palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(verbatim: shown(club.name))
                    .cyText(.cardTitle).foregroundStyle(palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                CYListRow("club.ops.clubID", trailing: .value(String(club.id))) { CYRowIcon(systemImage: "number") }
            }
            if !scope.canRead || model.phase == .denied {
                CYStatusChip("club.projectLaunch.ownerRequired", tone: .warning, systemImage: "lock")
            } else {
                launchActions(scope)
            }
        }
        .scrollContentBackground(.hidden).cyDomainPageBackground()
        .cyGroupedSurface()
        .cyHeroScreen()
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("action.cancel") { model.leave(); dismiss() }.accessibilityIdentifier("club.projectLaunch.cancel") } }
        .task(id: scope) {
            guard !Task.isCancelled else { return }
            presented = nil
            guard let permit = model.activate(scope) else { return }
            await model.read(permit, reader: session, editorContextID: { session.projectEditorContextID })
        }
        .onChange(of: scope) { _, _ in presented = nil }
        .onDisappear { presented = nil; model.leave() }
        .sheet(item: $presented, onDismiss: { reload(scope) }) { selection in
            NavigationStack {
                Group {
                    if current(selection) {
                        // The existing editor retains all local restore/discard, review and submission gates.
                        ProjectEditView(coordinator: selection.coordinator, sessionRevision: session.sessionRevision, seed: selection.target.seed)
                            .id(selection.id)
                    } else { Color.clear }
                }
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("club.gov.close") { presented = nil } } }
                .onChange(of: current(selection), initial: true) { _, valid in if !valid { presented = nil } }
            }
        }
    }
    private var clubBannerSeed: String {
        let name = club.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "club-\(club.id)" : name
    }
    private func shown(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "—" : trimmed
    }
    @ViewBuilder private func launchActions(_ scope: ClubProjectLaunchContext) -> some View {
        Section {
            if model.phase == .loading { launchLoading }
            if model.phase == .failed {
                CYStatusChip("club.projectLaunch.failed", tone: .danger, systemImage: "exclamationmark.triangle")
            }
            if model.phase == .editorUnavailable {
                CYStatusChip("club.projectLaunch.editorUnavailable", tone: .warning, systemImage: "square.and.pencil")
            }
            if model.phase == .ready && model.target == nil {
                CYSectionHeader("club.projectLaunch.chooseMode")
                    .listRowBackground(Color.clear).listRowSeparator(.hidden)
                modeButton(.city, "club.projectLaunch.city", "map", scope)
                modeButton(.freeExplore, "club.projectLaunch.freeExplore", "figure.walk", scope)
            }
            reloadButton(scope)
        }
    }
    private var launchLoading: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            CYSkeleton().accessibilityHidden(true)
            Text("club.loading").cyText(.meta).foregroundStyle(palette.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }
    private func modeButton(_ product: ProjectEditProduct, _ title: LocalizedStringKey, _ symbol: String, _ scope: ClubProjectLaunchContext) -> some View {
        let identifier = product == .city ? "club.projectLaunch.city" : "club.projectLaunch.freeExplore"
        return Button { choose(product, scope: scope) } label: {
            CYListRow(title, trailing: .chevron) { CYRowIcon(systemImage: symbol) }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(title))
        .accessibilityIdentifier(identifier)
    }
    private func reloadButton(_ scope: ClubProjectLaunchContext) -> some View {
        CYPillButton(
            LocalizedStringKey(model.phase == .failed ? "action.retry" : "club.refresh"),
            style: model.phase == .failed ? .primary : .secondary,
            systemImage: "arrow.clockwise"
        ) { reload(scope) }
        .disabled(model.phase == .loading || presented != nil || model.permit(in: scope) == nil)
        .accessibilityIdentifier("club.projectLaunch.reload")
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }
    private func current(_ selection: ClubProjectEditorPresentation) -> Bool {
        selection.hasCurrentSession && model.isCurrent(selection.target, context: context, reader: session, editorContextID: session.projectEditorContextID)
    }
    private func reload(_ scope: ClubProjectLaunchContext) {
        guard context == scope, scope.matches(reader: session, editorContextID: session.projectEditorContextID), let permit = model.permit(in: scope) else { return }
        Task { await model.read(permit, reader: session, editorContextID: { session.projectEditorContextID }) }
    }
    private func choose(_ product: ProjectEditProduct, scope: ClubProjectLaunchContext) {
        guard presented == nil, model.phase == .ready, model.target == nil, context == scope, let permit = model.permit(in: scope) else { return }
        Task {
            guard let target = await model.read(permit, product: product, reader: session, editorContextID: { session.projectEditorContextID }),
                  presented == nil, model.isCurrent(target, context: context, reader: session, editorContextID: session.projectEditorContextID) else { return }
            let coordinator = session.projectEditor(product: target.seed.product)
            guard let selection = ClubProjectEditorPresentation(target: target, coordinator: coordinator), current(selection) else { model.unavailable(target); return }
            presented = selection
        }
    }
}

/// Slim generated cover for a screen that has no photo. Text sits below it in `CYHeroHeader`.
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
            .clipShape(RoundedRectangle(cornerRadius: CYRadius.card, style: .continuous))
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

#if DEBUG
#Preview("Project launch hero · player") {
    CYHeroHeader("club.projectLaunch.title") { ClubCloud14Banner(seed: "preview-club", symbol: "map") }
        .padding(CYSpacing.pageHorizontal)
        .frame(maxHeight: .infinity, alignment: .top)
        .cyDomainPageBackground()
        .themeDomain(.player)
}
#Preview("Project launch hero · merchant") {
    CYHeroHeader("club.projectLaunch.title") { ClubCloud14Banner(seed: "preview-club", symbol: "map") }
        .padding(CYSpacing.pageHorizontal)
        .frame(maxHeight: .infinity, alignment: .top)
        .cyDomainPageBackground()
        .themeDomain(.merchant)
}
#endif
