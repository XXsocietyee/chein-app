import SwiftUI
import UIKit

@MainActor final class ActivityTemplateSelectionOwner: ObservableObject {
    struct Creation: Identifiable, Equatable { let id = UUID(); let visit: UUID }
    enum Status: String { case idle, loading, ready, empty, failed, unavailable }
    @Published private(set) var open = false
    @Published private(set) var rows: [ActivityTemplateChoice] = []
    @Published private(set) var selected: ActivityTemplateChoice?
    @Published private(set) var status: Status = .idle
    @Published private(set) var keyword = ""
    @Published private(set) var creation: Creation?
    @Published private var creationPresented = false
    @Published private(set) var readID = UUID()
    private var visit = UUID()
    var actionID: UUID { visit }
    private var bound: ActivityTemplateSelectionTarget?
    private var target: ActivityTemplateSelectionTarget?
    private var service: PublishingService?
    private var visible = false
    private var covered = false
    private var active = true
    private var pendingDismiss: Creation?
    private var needsRead = false
    func bind(session: PublishingSession?, draftID: UUID, draft: ActivityPublishDraft) {
        let next = session.flatMap { try? ActivityTemplateSelectionTarget(session: $0, draftID: draftID, draft: draft) }
        if bound != next { retire(); bound = next }
    }
    func parentAppeared() { visible = true; covered = false; if needsRead && open && active && pendingDismiss == nil { readID = UUID() } }
    func parentDisappeared(departing: Bool, coveredByPresentation: Bool) {
        guard !departing, coveredByPresentation, active, open, creation != nil || pendingDismiss != nil else { disappear(); return }
        visible = false; covered = true
    }
    func disappear() { visible = false; covered = false; retire() }
    func setActive(_ value: Bool) { active = value; if !value { retire() } }
    private var current: Bool { open && active && (visible || covered) && target != nil && target == bound && (service == nil || service?.currentSession == target?.session) }
    var canApply: Bool { current && visible && creation == nil && pendingDismiss == nil && status == .ready && selected?.availability == .available }
    func begin(service: PublishingService?, expected: UUID, allowed: Bool) {
        guard allowed, expected == visit, visible, active, !open, let bound else { return }
        visit = UUID(); target = bound; self.service = service; open = true; keyword = ""; requestRead(expected: visit)
    }
    func close(_ expected: UUID) { guard expected == visit else { return }; retire() }
    private func retire() {
        visit = UUID(); readID = UUID(); open = false; creationPresented = false; creation = nil; pendingDismiss = nil; needsRead = false
        rows = []; selected = nil; status = .idle; keyword = ""; target = nil; service = nil; covered = false
    }
    func keywordBinding() -> Binding<String> {
        let stamp = visit
        return .init(get: { [weak self] in guard let self, self.current, self.visit == stamp else { return "" }; return self.keyword },
            set: { [weak self] value in
                guard let self, self.current, self.visible, self.creation == nil, self.visit == stamp else { return }
                self.keyword = value; self.selected = nil; self.status = .idle; self.needsRead = false; self.readID = UUID()
            })
    }
    func requestRead(expected: UUID) {
        guard expected == visit, current, visible, creation == nil, pendingDismiss == nil else { return }
        selected = nil; status = .loading; needsRead = true; readID = UUID()
    }
    func read(_ requestID: UUID) async {
        guard !Task.isCancelled, requestID == readID, current, visible, creation == nil, pendingDismiss == nil, needsRead, let target else { return }
        needsRead = false; let stamp = visit; let query = keyword
        selected = nil; status = .loading
        guard let service, service.currentSession == target.session else { status = .unavailable; return }
        do {
            let value = try await service.read(.templates(keyword: query, scope: ""), session: target.session)
            guard !Task.isCancelled, current, visible, creation == nil, stamp == visit, requestID == readID,
                  service.currentSession == target.session else { return }
            rows = try ActivityTemplateChoice.page(value); status = rows.isEmpty ? .empty : .ready
        } catch {
            guard !Task.isCancelled, current, visible, creation == nil, stamp == visit, requestID == readID else { return }
            // Cached labels may remain visible, but a failed fresh read never approves a selection.
            selected = nil; status = .failed
        }
    }
    func select(_ row: ActivityTemplateChoice, expected: UUID) {
        guard expected == visit, current, visible, creation == nil, status == .ready,
              rows.contains(row), row.availability == .available else { return }
        selected = selected == row ? nil : row
    }
    @discardableResult func apply(expected: UUID, draft: Binding<ActivityPublishDraft>, session: PublishingSession?, draftID: UUID, allowed: Bool) -> Bool {
        guard expected == visit, allowed, canApply, let target, let selected, rows.contains(selected),
              let next = try? target.applying(selected, session: session, draftID: draftID, draft: draft.wrappedValue) else { return false }
        retire(); draft.wrappedValue = next; return true
    }
    func create(expected: UUID, available: Bool) {
        guard available, expected == visit, current, visible, creation == nil, pendingDismiss == nil else { return }
        selected = nil; readID = UUID(); needsRead = false; creationPresented = true; creation = .init(visit: visit)
    }
    func currentCreation(_ value: Creation) -> Bool { current && creationPresented && visit == value.visit && creation == value }
    func creationBinding(_ value: Creation) -> Binding<Creation?> {
        .init(get: { [weak self] in self?.currentCreation(value) == true ? value : nil },
              set: { [weak self] next in if next == nil { self?.closeCreation(value) } })
    }
    func closeCreation(_ value: Creation) {
        guard currentCreation(value) else { return }; creationPresented = false; pendingDismiss = value; selected = nil; rows = []; status = .idle
    }
    func creationDismissed(_ value: Creation) {
        guard current, visit == value.visit, creation == value, !creationPresented, pendingDismiss == value else { return }
        creation = nil; pendingDismiss = nil; needsRead = true
        if visible { readID = UUID() }
    }
}

@MainActor struct ActivityTemplateSelectionSection: View {
    @ObservedObject var owner: ActivityTemplateSelectionOwner
    let apply: (UUID) -> Bool
    let createAvailable: Bool
    var body: some View {
        let stamp = owner.actionID
        Section {
            // A search field inside a Form section (`.searchable` belongs to a whole navigation page, not one section).
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary).accessibilityHidden(true)
                TextField(text: owner.keywordBinding()) { Text("search", tableName: "ActivityTemplateSelection") }
                    .submitLabel(.search)
                    .autocorrectionDisabled()
                    .onSubmit { owner.requestRead(expected: stamp) }.accessibilityIdentifier("activityTemplate.search")
            }
            Button { owner.requestRead(expected: stamp) } label: {
                Label { Text("search", tableName: "ActivityTemplateSelection") } icon: { Image(systemName: "magnifyingglass") }
            }
            PublishingStatusRow(title: Text(LocalizedStringKey("status." + owner.status.rawValue), tableName: "ActivityTemplateSelection"),
                symbol: owner.status == .empty ? "tray" : owner.status == .failed ? "exclamationmark.triangle" : "info.circle",
                isError: owner.status == .failed)
                .accessibilityIdentifier("activityTemplate.status")
            if owner.status == .loading { ProgressView().frame(maxWidth: .infinity) }
            ForEach(owner.rows) { row in
                let isSelected = owner.selected == row
                Button { owner.select(row, expected: stamp) } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.title).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
                            ActivityTemplateChoiceMeta(row: row)
                            if row.availability != .available {
                                Text(LocalizedStringKey(row.availability.rawValue), tableName: "ActivityTemplateSelection")
                                    .font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        Spacer(minLength: 8)
                        // Settings-style selection: a checkmark on the chosen row.
                        if isSelected {
                            Image(systemName: "checkmark")
                                .fontWeight(.semibold)
                                .foregroundStyle(.tint)
                                .accessibilityHidden(true)
                        }
                    }
                    .contentShape(Rectangle())
                }
                    .disabled(owner.status != .ready || row.availability != .available)
                    .accessibilityIdentifier("activityTemplate.row.\(row.id.rawValue)")
                    .accessibilityValue(isSelected ? Text("publishModes.selected") : Text("publishModes.notSelected"))
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
            Button { _ = apply(stamp) } label: { Text("apply", tableName: "ActivityTemplateSelection") }
                .disabled(!owner.canApply).accessibilityIdentifier("activityTemplate.apply")
            Button { owner.create(expected: stamp, available: createAvailable) } label: { Text("create", tableName: "ActivityTemplateSelection") }
                .disabled(!createAvailable).accessibilityIdentifier("activityTemplate.create")
            PublishingStatusRow(title: Text("creationNotice", tableName: "ActivityTemplateSelection"))
            Button { owner.close(stamp) } label: { Text("cancel", tableName: "ActivityTemplateSelection") }
                .accessibilityIdentifier("activityTemplate.cancel")
        } header: { Text("title", tableName: "ActivityTemplateSelection") }
    }
}

#if DEBUG
extension ActivityTemplateSelectionOwner {
    /// Design fixtures only: synthetic rows so the selection list can be shot without a service.
    func designPreviewRows(_ rows: [ActivityTemplateChoice], selected: Int?) {
        self.rows = rows; self.status = .ready
        self.selected = selected.flatMap { rows.indices.contains($0) ? rows[$0] : nil }
    }
}
#endif

/// Only a concrete creation occurrence mounts a sheet. Late dismissal cannot consume a newer one.
@MainActor struct ActivityTemplateCreationPresenter: View {
    @ObservedObject var owner: ActivityTemplateSelectionOwner
    let original: ActivityTemplateSelectionOwner.Creation
    @StateObject private var contentOwner: ActivityTemplateCreationContent
    init(owner: ActivityTemplateSelectionOwner, original: ActivityTemplateSelectionOwner.Creation, content: @escaping () -> AnyView) {
        self.owner = owner; self.original = original
        _contentOwner = StateObject(wrappedValue: ActivityTemplateCreationContent(content: content))
    }
    var body: some View {
        Color.clear.frame(width: 0, height: 0)
            .sheet(item: owner.creationBinding(original), onDismiss: { owner.creationDismissed(original) }) { offered in Group {
                NavigationStack {
                    if owner.currentCreation(offered) {
                        contentOwner.view.toolbar { ToolbarItem(placement: .cancellationAction) {
                            Button { owner.closeCreation(offered) } label: { Text("return", tableName: "ActivityTemplateSelection") }
                                .accessibilityIdentifier("activityTemplate.creation.return")
                        } }
                    }
                }
            }.cySheet(detents: [.large]) }
    }
}

@MainActor private final class ActivityTemplateCreationContent: ObservableObject {
    let view: AnyView
    init(content: () -> AnyView) { view = content() }
}

/// The real UIKit parent distinguishes modal coverage from leaving the activity hierarchy.
@MainActor struct ActivityTemplateSelectionLifetimeAnchor: UIViewControllerRepresentable {
    let owner: ActivityTemplateSelectionOwner
    func makeUIViewController(context: Context) -> ActivityTemplateSelectionLifetimeController { .init(owner: owner) }
    func updateUIViewController(_ controller: ActivityTemplateSelectionLifetimeController, context: Context) {}
    static func dismantleUIViewController(_ controller: ActivityTemplateSelectionLifetimeController, coordinator: ()) { controller.owner?.disappear() }
}
@MainActor final class ActivityTemplateSelectionLifetimeController: UIViewController {
    weak var owner: ActivityTemplateSelectionOwner?
    private var departing = false
    init(owner: ActivityTemplateSelectionOwner) { self.owner = owner; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { return nil }
    private var ancestry: [UIViewController] {
        var result: [UIViewController] = [], next: UIViewController? = self
        while let value = next { result.append(value); next = value.parent }; return result
    }
    override func viewDidAppear(_ animated: Bool) { super.viewDidAppear(animated); departing = false; owner?.parentAppeared() }
    override func viewWillDisappear(_ animated: Bool) { super.viewWillDisappear(animated); departing = ancestry.contains { $0.isMovingFromParent || $0.isBeingDismissed } }
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated); let source = ancestry
        let presented = source.contains { $0.presentedViewController != nil }
        let leaving = departing || source.contains { $0.isMovingFromParent || $0.isBeingDismissed } || parent == nil
        owner?.parentDisappeared(departing: leaving, coveredByPresentation: presented)
    }
}

/// MP publish/activity template row `.david_mbxi` (wxml:254-257): 人数 with `d_mbico1`, then 「N分钟」 with `d_mbico2`
/// only when the duration is positive. Nothing is drawn when the server row has neither.
struct ActivityTemplateChoiceMeta: View {
    let row: ActivityTemplateChoice
    @ScaledMetric(relativeTo: .caption) private var icon: CGFloat = 14

    private var players: String? {
        let value = row.raw["players"]?.text ?? row.raw["players"]?.integer.map(String.init)
        return value.flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
    }
    private var minutes: Int? { row.raw["duration"]?.integer.flatMap { $0 > 0 ? $0 : nil } }

    var body: some View {
        if players != nil || minutes != nil {
            HStack(spacing: 12) {
                if let players {
                    Label { Text(verbatim: players) } icon: { MPAsset.FeatureIcon.dMbico1.resizable().scaledToFit().frame(width: icon, height: icon) }
                }
                if let minutes {
                    Label { Text("fixr3.activity.templateMinutes \(minutes)") } icon: { MPAsset.FeatureIcon.dMbico2.resizable().scaledToFit().frame(width: icon, height: icon) }
                }
            }
            .labelStyle(.titleAndIcon)
            .font(.footnote).foregroundStyle(.secondary)
            .accessibilityElement(children: .combine)
        }
    }
}
