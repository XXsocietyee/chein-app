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
    @StateObject private var model = ClubProjectLaunchModel()
    @State private var presented: ClubProjectEditorPresentation?
    private var context: ClubProjectLaunchContext { .init(club: club, reader: session, editorContextID: session.projectEditorContextID) }
    var body: some View {
        let scope = context
        List {
            Section {
                ClubCloud14Banner(seed: clubBannerSeed, symbol: "map", imageURL: ClubCloud14HTTPS.url(club.cover))
                    .listRowInsets(EdgeInsets())
                Text(verbatim: shown(club.name))
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                LabeledContent {
                    Text(verbatim: String(club.id)).monospacedDigit()
                } label: {
                    Label("club.ops.clubID", systemImage: "number")
                }
            } footer: {
                Text("club.projectLaunch.localHint")
            }
            if !scope.canRead || model.phase == .denied {
                Section {
                    Label("club.projectLaunch.ownerRequired", systemImage: "lock")
                        .foregroundStyle(CYColor.warningText)
                }
            } else {
                launchActions(scope)
            }
        }
        .navigationTitle(Text("club.projectLaunch.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("action.cancel") { model.leave(); dismiss() }.accessibilityIdentifier("club.projectLaunch.cancel") } }
        .task(id: scope) {
            guard !Task.isCancelled else { return }
            presented = nil
            guard let permit = model.activate(scope) else { return }
            await model.read(permit, reader: session, editorContextID: { session.projectEditorContextID })
        }
        .onChange(of: scope) { _, _ in presented = nil }
        .onDisappear { presented = nil; model.leave() }
        .cySheet(item: $presented, onDismiss: { reload(scope) }) { selection in
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
        if model.phase == .loading || model.phase == .failed || model.phase == .editorUnavailable {
            Section {
                if model.phase == .loading { launchLoading }
                if model.phase == .failed {
                    Label("club.projectLaunch.failed", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(CYColor.dangerText)
                }
                if model.phase == .editorUnavailable {
                    Label("club.projectLaunch.editorUnavailable", systemImage: "square.and.pencil")
                        .foregroundStyle(CYColor.warningText)
                }
            }
        }
        if model.phase == .ready && model.target == nil {
            Section {
                modeButton(.city, "club.projectLaunch.city", "map", scope)
                modeButton(.freeExplore, "club.projectLaunch.freeExplore", "figure.walk", scope)
            } header: {
                Text("club.projectLaunch.chooseMode")
            }
        }
        Section {
            reloadButton(scope)
        }
    }
    private var launchLoading: some View {
        ProgressView { Text("club.loading") }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
    }
    private func modeButton(_ product: ProjectEditProduct, _ title: LocalizedStringKey, _ symbol: String, _ scope: ClubProjectLaunchContext) -> some View {
        let identifier = product == .city ? "club.projectLaunch.city" : "club.projectLaunch.freeExplore"
        return Button { choose(product, scope: scope) } label: {
            Label(title, systemImage: symbol)
        }
        .accessibilityLabel(Text(title))
        .accessibilityIdentifier(identifier)
    }
    private func reloadButton(_ scope: ClubProjectLaunchContext) -> some View {
        Button { reload(scope) } label: {
            Label(LocalizedStringKey(model.phase == .failed ? "action.retry" : "club.refresh"), systemImage: "arrow.clockwise")
        }
        .disabled(model.phase == .loading || presented != nil || model.permit(in: scope) == nil)
        .accessibilityIdentifier("club.projectLaunch.reload")
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

/// Slim generated cover for a screen that has no photo; the first row of the first section.
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

#if DEBUG
#Preview("Project launch banner · player") {
    List { Section { ClubCloud14Banner(seed: "preview-club", symbol: "map").listRowInsets(EdgeInsets()) } }
        .themeDomain(.player)
}
#Preview("Project launch banner · merchant") {
    List { Section { ClubCloud14Banner(seed: "preview-club", symbol: "map").listRowInsets(EdgeInsets()) } }
        .themeDomain(.merchant)
}
#endif
