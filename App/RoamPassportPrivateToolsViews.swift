import SwiftUI

/// Mini-program subpackageTools/capsule, exploration-goals and exploration-export.
/// Owner-only private records: every write is explicitly reviewed, keeps its request ID for readback
/// or exact retry, and is refused unless a reviewed write approval exists (none in production today).

/// 探索目标 / 时光胶囊 passport tiles (pages/roam `passport.tiles`, NEW since 2026-10-14).
@MainActor struct RoamPassportPrivateLinks: View {
    let tools: (any RoamPrivateToolsServing)?
    private let initialScope: RoamPrivatePageScope?
    private let initialConfigured: Bool?
    private let initialWrites: Bool?
    @EnvironmentObject private var navigation: RoamPassportPrivateNavigation
    init(tools: (any RoamPrivateToolsServing)?) {
        self.tools = tools
        self.initialScope = tools.map { RoamPrivatePageScope($0) }
        self.initialConfigured = tools?.isConfigured
        self.initialWrites = tools?.allowsWrites
        RoamHostedScopeTracker.shared.observePrivate(tools)
    }
    var body: some View {
        let _ = (initialScope, initialConfigured, initialWrites)
        NavigationLink { RoamExplorationGoalsView(tools: tools) } label: {
            RoamPassportTileLabel(title: "roam.goals.title", subtitle: "roam.goals.tile", systemImage: "flag")
                .background {
                    if navigation.openedLink == nil {
                        RoamHostedAccessibilityAnchor(
                            identifier: "roam.goals.open",
                            action: { navigation.openedLink = RoamPassportOpenedLink(kind: .goals) }
                        )
                    }
                }
        }.accessibilityIdentifier("roam.goals.open")
        NavigationLink { RoamCapsuleView(tools: tools) } label: {
            RoamPassportTileLabel(title: "roam.capsule.title", subtitle: "roam.capsule.tile", systemImage: "clock")
                .background {
                    if navigation.openedLink == nil {
                        RoamHostedAccessibilityAnchor(
                            identifier: "roam.capsule.open",
                            action: { navigation.openedLink = RoamPassportOpenedLink(kind: .capsule) }
                        )
                    }
                }
        }
        .accessibilityIdentifier("roam.capsule.open")
        .onAppear { navigation.openedLink = nil }
    }
}

/// The goals and capsule pushes. `navigationDestination(item:)` on a row inside the List
/// collapses that section into one cramped line, so the destination lives on the List.
@MainActor private final class RoamPassportPrivateNavigation: ObservableObject {
    @Published var openedLink: RoamPassportOpenedLink?
}

private struct RoamPassportOpenedLink: Identifiable, Hashable {
    let id = UUID()
    let kind: RoamPassportPrivateLinkKind
}

private enum RoamPassportPrivateLinkKind: Hashable { case goals, capsule }

extension View {
    /// Hoist the private-link push onto the List or NavigationStack. Do not call this from a row.
    func roamPassportPrivateDestinations(tools: (any RoamPrivateToolsServing)?) -> some View {
        modifier(RoamPassportPrivateDestinationModifier(tools: tools))
    }
}

private struct RoamPassportPrivateDestinationModifier: ViewModifier {
    let tools: (any RoamPrivateToolsServing)?
    @StateObject private var navigation = RoamPassportPrivateNavigation()
    private var openedLink: Binding<RoamPassportOpenedLink?> {
        Binding(get: { navigation.openedLink }, set: { navigation.openedLink = $0 })
    }
    func body(content: Content) -> some View {
        content
            .environmentObject(navigation)
            .navigationDestination(item: openedLink) { item in
                switch item.kind {
                case .goals:
                    RoamExplorationGoalsView(tools: tools)
                case .capsule:
                    RoamCapsuleView(tools: tools)
                }
            }
    }
}

private struct RoamPassportTileLabel: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let systemImage: String
    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title)
                    Text("roam.private.new").cyText(.caption, weight: .bold).padding(.horizontal, 6).padding(.vertical, 1)
                        .background(Color.accentColor.opacity(0.15), in: Capsule())
                }
                Text(subtitle).cyText(.meta).foregroundStyle(.secondary)
            }
        } icon: { Image(systemName: systemImage) }
    }
}

struct RoamPrivateIssueView: View {
    let issue: RoamPrivateToolIssue
    var retry: (() -> Void)? = nil
    var dismiss: (() -> Void)? = nil
    private var text: Text {
        switch issue {
        case .signInRequired: return Text("roam.signInRequired")
        case .notConfigured: return Text("roam.notConfigured")
        case .readFailed: return Text("roam.private.readFailed")
        case .changedContext: return Text("roam.private.changedContext")
        case .writesDisabled: return Text("roam.private.writesDisabled")
        case .outcomeUnknown: return Text("roam.private.outcomeUnknown")
        case .rejected(let message): return message.map { Text(verbatim: $0) } ?? Text("roam.private.rejected")
        case .invalidDraft: return Text("roam.private.invalidDraft")
        case .pendingFirst: return Text("roam.private.pendingFirst")
        case .expired: return Text("roam.export.expired")
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label { text } icon: { Image(systemName: "exclamationmark.circle") }
            HStack {
                if let retry, issue != .signInRequired, issue != .notConfigured {
                    Button("action.retry", action: retry).buttonStyle(.borderless).accessibilityIdentifier("roam.private.retry")
                }
                if let dismiss { Button("roam.private.dismiss", action: dismiss).buttonStyle(.borderless).accessibilityIdentifier("roam.private.dismiss") }
            }
        }.accessibilityElement(children: .contain).accessibilityIdentifier("roam.private.issue")
    }
}

/// Shanghai calendar-day bridge for DatePicker values.
enum RoamShanghaiPicker {
    static let timeZone = TimeZone(secondsFromGMT: RoamShanghaiCalendar.offsetSeconds)!
    static func date(_ text: String) -> Date {
        let day = RoamShanghaiCalendar.parseDate(text) ?? 0
        return Date(timeIntervalSince1970: TimeInterval(day * RoamShanghaiCalendar.dayMilliseconds / 1000 + 4 * 3600))
    }
    static func text(_ date: Date) -> String { RoamShanghaiCalendar.dateText(dayNumber: RoamShanghaiCalendar.dayNumber(now: date)) }
}

/// A page instance is tied to the actual reader and exact local scope, not just an account number.
struct RoamPrivatePageScope: Hashable {
    let reader: ObjectIdentifier
    let storageKey: String?
    let epoch: UInt64?
    let readScope: UUID?
    @MainActor init(_ tools: any RoamPrivateToolsServing) {
        reader = ObjectIdentifier(tools)
        let identity = tools.identity
        storageKey = identity?.scope.storageKey; epoch = identity?.epoch
        readScope = (tools as? RoamPrivateToolsSessionReader)?.readScope
    }
}

/// UI lifetime only. Pending payloads and durable request IDs remain in the original reader.
/// Issued writer/receipt work is never stored in the cancellable ordinary-read task.
@MainActor final class RoamPrivatePageOwner: ObservableObject {
    private let tools: any RoamPrivateToolsServing
    private let scope: RoamPrivatePageScope
    @Published private(set) var active = false
    @Published private(set) var foreground = false
    @Published private(set) var settlementInFlight = false
    @Published private(set) var readInFlight = false
    private var mounted = false
    private var ticket = UUID()
    private var actionRevision = UUID()
    private var readTask: Task<Void, Never>?
    private var currentReadID: UUID?
    init(tools: any RoamPrivateToolsServing) { self.tools = tools; scope = .init(tools) }
    var isPresented: Bool { active && scope == RoamPrivatePageScope(tools) && tools.identity != nil && tools.isConfigured }
    var acceptsInput: Bool { isPresented && foreground }
    func appear(foreground: Bool) -> Bool { mounted = true; return activate(foreground: foreground) }
    func activate(foreground: Bool) -> Bool {
        self.foreground = foreground
        guard mounted, foreground, !active, tools.identity != nil,
              scope == RoamPrivatePageScope(tools), tools.isConfigured else { return false }
        active = true; ticket = UUID(); return true
    }
    // A system interruption is not departure, but a previously queued action cannot start afterward.
    func inactive() { foreground = false; actionRevision = UUID() }
    func retire(leaving: Bool = false) {
        if leaving { mounted = false }
        active = false; foreground = false; ticket = UUID(); actionRevision = UUID()
        readTask?.cancel(); readTask = nil; currentReadID = nil; readInFlight = false
        // Only the original operation may finish settlementInFlight. Never cancel/retry it here.
    }
    private func accepts(_ offered: UUID) -> Bool { acceptsInput && ticket == offered }
    func read(_ work: @escaping @MainActor () async -> Void) {
        let offered = ticket, action = actionRevision
        readTask = Task { [self] in
            guard accepts(offered), action == actionRevision else { return }
            await readNow(work)
        }
    }
    func readNow(_ work: @MainActor () async -> Void) async {
        let offered = ticket
        guard accepts(offered), !settlementInFlight, !readInFlight, !Task.isCancelled else { return }
        let readID = UUID(); currentReadID = readID
        readInFlight = true; await work()
        // Inactive retires queued actions without cancelling an already-issued ordinary read.
        // Only this same read can release its busy state, never a replacement read.
        guard currentReadID == readID else { return }
        currentReadID = nil; readInFlight = false
    }
    func settle<Value>(write: Bool, _ work: @escaping @MainActor () async -> Value,
                       refresh: @escaping @MainActor () async -> Void,
                       finished: @escaping @MainActor (Value) -> Void = { _ in }) {
        let offered = ticket, action = actionRevision
        Task { [self] in
            guard accepts(offered), action == actionRevision, !settlementInFlight, !readInFlight, !Task.isCancelled,
                  !write || tools.allowsWrites else { return }
            settlementInFlight = true
            let result = await work()
            settlementInFlight = false
            if isPresented && ticket == offered { finished(result) }
            // Foreground return during settlement waits for it, then reads metadata only.
            else if acceptsInput { read(refresh) }
        }
    }
}

// MARK: 时光胶囊

@MainActor struct RoamCapsuleView: View {
    let tools: (any RoamPrivateToolsServing)?
    private let initialScope: RoamPrivatePageScope?
    private let initialConfigured: Bool?
    private let initialWrites: Bool?
    @ObservedObject private var scopeTracker = RoamHostedScopeTracker.shared
    init(tools: (any RoamPrivateToolsServing)?) {
        self.tools = tools
        self.initialScope = tools.map { RoamPrivatePageScope($0) }
        self.initialConfigured = tools?.isConfigured
        self.initialWrites = tools?.allowsWrites
        RoamHostedScopeTracker.shared.observePrivate(tools)
    }
    var body: some View {
        let _ = (scopeTracker.tick, initialScope, initialConfigured, initialWrites)
        let _ = RoamHostedScopeTracker.shared.observePrivate(tools)
        Group {
            if let tools {
                let scope = RoamPrivatePageScope(tools)
                RoamCapsuleContent(tools: tools, isConfigured: tools.isConfigured, allowsWrites: tools.allowsWrites).id(scope)
            } else {
                List { RoamPrivateIssueView(issue: .notConfigured) }.cyGroupedSurface()
                    .background { RoamHostedAccessibilityGroup(items: [RoamHostedAccessibilityItem(identifier: "roam.private.issue")]) }
                    .accessibilityIdentifier("roam.capsule.screen")
            }
        }.cyPageTitle("roam.capsule.title")
        .cyDomainScreen(.player)
    }
}

@MainActor private struct RoamCapsuleContent: View {
    let tools: any RoamPrivateToolsServing
    let isConfigured: Bool
    let allowsWrites: Bool
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.offlineWriteSession) private var offlineWriteSession
    @StateObject private var page: RoamPrivatePageOwner
    @State private var model: RoamCapsuleCoordinator
    @State private var composing = false
    @State private var text = ""
    @State private var unlockDate = ""
    @State private var custom = false
    @State private var lockedTip = false
    init(tools: any RoamPrivateToolsServing, isConfigured: Bool, allowsWrites: Bool) {
        self.tools = tools
        self.isConfigured = isConfigured
        self.allowsWrites = allowsWrites
        _page = StateObject(wrappedValue: RoamPrivatePageOwner(tools: tools))
        _model = State(initialValue: RoamCapsuleCoordinator(tools: tools))
    }
    private var options: [RoamCapsuleUnlockOption] { RoamCapsuleUnlockOption.options(now: tools.now) }
    private func presetKey(_ preset: RoamCapsuleUnlockOption.Preset) -> LocalizedStringKey {
        switch preset { case .month: return "roam.capsule.unlock.month"; case .halfYear: return "roam.capsule.unlock.halfYear"; case .year: return "roam.capsule.unlock.year" }
    }
    private var showsList: Bool { model.opened == nil && !model.deleted }
    var body: some View {
        List {
            if page.isPresented {
            CYScreenOfflineWriteSection(
                routes: ["/api/capsules/create"],
                session: offlineWriteSession.session
            )
            if tools.isOfflineExample { Section { RoamExperienceNotice(offline: true) } }
            if let issue = model.issue {
                Section { RoamPrivateIssueView(issue: issue, retry: issue == .outcomeUnknown ? nil : { page.read { await model.load() } }) }
            }
            // Reads are approved but the write route is not: say so instead of silently hiding the compose button.
            if tools.identity != nil, tools.isConfigured, !tools.allowsWrites, model.pending == nil, model.pendingRequestID == nil {
                Section { Label("roam.capsule.writeUnavailable", systemImage: "lock").cyText(.bodyCompact).foregroundStyle(.secondary) }
                    .accessibilityIdentifier("roam.capsule.writeUnavailable")
            }
            if model.pending != nil || model.pendingRequestID != nil {
                Section {
                    Text("roam.capsule.pending").accessibilityIdentifier("roam.capsule.pending")
                    Button("roam.capsule.verify") { page.settle(write: false, { await model.verifyPending() }, refresh: { await model.load() }) }
                        .disabled(model.isBusy).accessibilityIdentifier("roam.capsule.verify")
                    // A restored lock has only the original request ID. Checking that
                    // receipt is the only action; the body is never rebuilt in order to resend.
                    if model.pending != nil {
                        Button("roam.capsule.retryOriginal") {
                            page.settle(write: true, {
                                await SessionOfflineSyncModel.shared.performWriteOptIn(
                                    environmentSession: offlineWriteSession.session,
                                    routes: ["/api/capsules/create"]
                                ) {
                                    await model.retryPending()
                                }
                            }, refresh: { await model.load() })
                        }
                            .disabled(model.isBusy || !model.canWrite).accessibilityIdentifier("roam.capsule.retryOriginal")
                    }
                }
            }
            if let opened = model.opened {
                Section {
                    Text("roam.capsule.openedMeta \(opened.unlockDateText ?? "—") \(opened.createdDateText ?? "—")").cyText(.meta).foregroundStyle(.secondary)
                    Text(verbatim: capsuleText(opened.body)).cyText(.body).textSelection(.enabled).accessibilityIdentifier("roam.capsule.body")
                    if let photo = opened.photoURL, let url = URL(string: photo), url.scheme == "https" {
                        AsyncImage(url: url) { image in image.resizable().scaledToFit() } placeholder: { CYSkeleton() }
                            .accessibilityLabel(Text("roam.capsule.photo"))
                    }
                    Button("roam.capsule.keep") { page.read { await model.closeOpened() } }.accessibilityIdentifier("roam.capsule.keep")
                    if model.canWrite {
                        Button("roam.capsule.delete", role: .destructive) { guard page.acceptsInput, !page.settlementInFlight else { return }; model.prepareDelete() }.accessibilityIdentifier("roam.capsule.delete")
                    }
                }.accessibilityIdentifier("roam.capsule.opened")
            }
            if model.deleted {
                Section {
                    Text("roam.capsule.deleted").accessibilityIdentifier("roam.capsule.deleted")
                    Button("roam.capsule.backToList") { page.read { await model.closeOpened() } }.accessibilityIdentifier("roam.capsule.backToList")
                }
            }
            if composing { composer }
            if showsList { list }
            } else if scenePhase == .active && (tools.identity == nil || !tools.isConfigured) {
                Section { RoamPrivateIssueView(issue: tools.identity == nil ? .signInRequired : .notConfigured) }
            }
        }.cyGroupedSurface()
        .disabled(!page.acceptsInput || page.settlementInFlight)
        .privacySensitive()
        .toolbar {
            // Writing is only offered when it can be saved.
            if page.acceptsInput && !composing && tools.allowsWrites {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { startComposing() } label: { Image(systemName: "plus") }
                        .accessibilityLabel(Text("roam.capsule.write")).accessibilityIdentifier("roam.capsule.write")
                }
            }
        }
        .onAppear { activate(appearing: true) }
        .refreshable { await page.readNow { await model.load() } }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { retire() }
            else if phase == .active { activate() }
            else { page.inactive() }
        }
        .onChange(of: isConfigured) { _, configured in
            if configured { activate() } else { retire() }
        }
        .onChange(of: tools.isConfigured) { _, configured in
            if configured { activate() } else { retire() }
        }
        .onDisappear { retire(leaving: true) }
        .alert("roam.capsule.lockedTip", isPresented: $lockedTip) { Button("roam.private.ok", role: .cancel) {} }
        .confirmationDialog("roam.capsule.confirmTitle", isPresented: Binding(get: { model.review != nil }, set: { if !$0 { model.cancelReview() } }), titleVisibility: .visible) {
            Button("roam.capsule.seal") {
                page.settle(write: true, {
                    await SessionOfflineSyncModel.shared.performWriteOptIn(
                        environmentSession: offlineWriteSession.session,
                        routes: ["/api/capsules/create"]
                    ) {
                        await model.confirmCreate()
                    }
                }, refresh: { await model.load() }) { saved in if saved { composing = false; text = "" } }
            }
                .accessibilityIdentifier("roam.capsule.confirmSeal")
            Button("roam.private.notNow", role: .cancel) { model.cancelReview() }
        } message: { Text("roam.capsule.confirmMessage \(capsuleText(model.review?.unlockDate))") }
        .confirmationDialog("roam.capsule.deleteTitle", isPresented: Binding(get: { model.deleteReview != nil }, set: { if !$0 { model.cancelDelete() } }), titleVisibility: .visible) {
            Button("roam.capsule.delete", role: .destructive) { page.settle(write: true, { await model.confirmDelete() }, refresh: { await model.load() }) }
                .accessibilityIdentifier("roam.capsule.confirmDelete")
            Button("roam.private.notNow", role: .cancel) { model.cancelDelete() }
        } message: { Text("roam.capsule.deleteMessage") }
        .background { RoamHostedAccessibilityGroup(items: capsuleAccessibilityItems) }
        .accessibilityIdentifier("roam.capsule.screen")
    }
    private var capsuleAccessibilityItems: [RoamHostedAccessibilityItem] {
        let _ = (isConfigured, allowsWrites)
        var items: [RoamHostedAccessibilityItem] = []
        if page.isPresented {
            if let issue = model.issue {
                items.append(RoamHostedAccessibilityItem(identifier: "roam.private.issue"))
                if issue != .outcomeUnknown, issue != .signInRequired, issue != .notConfigured {
                    items.append(
                        RoamHostedAccessibilityItem(
                            identifier: "roam.private.retry",
                            action: { page.read { await model.load() } }
                        )
                    )
                }
            }
            if model.pending != nil || model.pendingRequestID != nil {
                items.append(RoamHostedAccessibilityItem(identifier: "roam.capsule.pending"))
                if !model.isBusy {
                    items.append(
                        RoamHostedAccessibilityItem(
                            identifier: "roam.capsule.verify",
                            action: { page.settle(write: false, { await model.verifyPending() }, refresh: { await model.load() }) }
                        )
                    )
                }
                if model.pending != nil {
                    items.append(
                        RoamHostedAccessibilityItem(
                            identifier: "roam.capsule.retryOriginal",
                            isEnabled: !model.isBusy && model.canWrite,
                            action: { page.settle(write: true, { await model.retryPending() }, refresh: { await model.load() }) }
                        )
                    )
                }
            }
            if model.opened != nil {
                items.append(RoamHostedAccessibilityItem(identifier: "roam.capsule.body"))
            }
            if composing {
                items.append(RoamHostedAccessibilityItem(identifier: "roam.capsule.text"))
            }
            if showsList {
                if let openItem = model.items.first(where: { $0.state == .open }) {
                    items.append(
                        RoamHostedAccessibilityItem(
                            identifier: "roam.capsule.row.open",
                            action: { page.read { await model.open(openItem) } }
                        )
                    )
                }
                if !model.isBusy && model.items.isEmpty && model.phase == .ready {
                    items.append(RoamHostedAccessibilityItem(identifier: "roam.capsule.empty"))
                }
                if model.hasMore && !model.isBusy {
                    items.append(
                        RoamHostedAccessibilityItem(
                            identifier: "roam.capsule.more",
                            action: { page.read { await model.load(more: true) } }
                        )
                    )
                }
            }
            if page.acceptsInput && !page.settlementInFlight && !model.isBusy && !composing && tools.allowsWrites {
                items.append(
                    RoamHostedAccessibilityItem(
                        identifier: "roam.capsule.write",
                        action: { startComposing() }
                    )
                )
            }
        } else if scenePhase == .active && (tools.identity == nil || !tools.isConfigured) {
            items.append(RoamHostedAccessibilityItem(identifier: "roam.private.issue"))
        }
        return items
    }
    private func activate(appearing: Bool = false) {
        let started = appearing ? page.appear(foreground: scenePhase == .active) : page.activate(foreground: scenePhase == .active)
        if started { model.resume(); page.read { await model.load() } }
    }
    private func retire(leaving: Bool = false) {
        page.retire(leaving: leaving); model.suspend()
        text = ""; composing = false; lockedTip = false
    }
    private func capsuleText(_ value: String?) -> String {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "—" : trimmed
    }
    private func startComposing() {
        guard page.acceptsInput, !page.settlementInFlight, !model.isBusy else { return }
        if unlockDate.isEmpty { unlockDate = options[2].date }
        composing = true
    }
    @ViewBuilder private var composer: some View {
        Section {
            TextField("roam.capsule.placeholder", text: $text, axis: .vertical)
                .lineLimit(4...12).disabled(model.isBusy || model.pending != nil)
                .onChange(of: text) { _, value in if value.utf16.count > RoamCapsuleDraft.bodyLimit { text = String(value.utf16.prefix(RoamCapsuleDraft.bodyLimit)) ?? value } }
                .accessibilityIdentifier("roam.capsule.text")
            Text("roam.capsule.count \(text.utf16.count)").cyText(.meta).foregroundStyle(.secondary).monospacedDigit()
        } header: { Text("roam.capsule.bodyLabel") }
        Section {
            LabeledContent("roam.capsule.unlockLabel") { Text(verbatim: unlockDate).monospacedDigit() }
                .accessibilityIdentifier("roam.capsule.unlockDate")
            HStack {
                ForEach(options) { option in
                    Button { unlockDate = option.date; custom = false } label: { Text(presetKey(option.preset)) }
                        .buttonStyle(.bordered).tint(!custom && unlockDate == option.date ? Color.accentColor : Color.secondary)
                        .accessibilityAddTraits(!custom && unlockDate == option.date ? .isSelected : [])
                        .accessibilityIdentifier("roam.capsule.unlock.\(option.preset.rawValue)")
                }
            }.disabled(model.isBusy)
            DatePicker("roam.capsule.unlockCustom", selection: Binding(get: { RoamShanghaiPicker.date(unlockDate.isEmpty ? options[2].date : unlockDate) },
                                                                      set: { unlockDate = RoamShanghaiPicker.text($0); custom = true }),
                       in: RoamShanghaiPicker.date(RoamCapsuleUnlockOption.minimumDate(now: tools.now))..., displayedComponents: .date)
                .environment(\.timeZone, RoamShanghaiPicker.timeZone).disabled(model.isBusy)
                .accessibilityIdentifier("roam.capsule.unlockCustom")
        }
        Section {
            Button("roam.capsule.seal") { guard page.acceptsInput, !page.settlementInFlight else { return }; model.prepareCreate(body: text, unlockDate: unlockDate) }
                .buttonStyle(.questifyPrimary)
                .disabled(model.isBusy || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || unlockDate.isEmpty || model.pending != nil || !model.canWrite)
                .accessibilityIdentifier("roam.capsule.seal")
            Button("roam.capsule.later") { composing = false }.disabled(model.isBusy).accessibilityIdentifier("roam.capsule.later")
        } footer: { Text("roam.capsule.photoUnavailable") }
    }
    @ViewBuilder private var list: some View {
        Section {
            if model.isBusy && model.items.isEmpty { CYSkeleton().accessibilityLabel(Text("roam.private.loading")) }
            ForEach(model.items) { item in
                if item.state == .open {
                    Button { page.read { await model.open(item) } } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("roam.capsule.openReady \(item.createdDateText ?? "—")").cyText(.meta).foregroundStyle(.tint)
                            Text("roam.capsule.openIt").cyText(.cardTitle)
                        }
                    }.accessibilityIdentifier("roam.capsule.row.open")
                } else {
                    Button { lockedTip = true } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("roam.capsule.writtenOn \(item.createdDateText ?? "—")").cyText(.meta).foregroundStyle(.secondary)
                            Text("roam.capsule.daysLeft \(item.daysLeft(now: tools.now))").cyText(.sheetTitle).monospacedDigit()
                            Text("roam.capsule.unlocksOn \(item.unlockDateText ?? "—")").cyText(.meta).foregroundStyle(.secondary)
                        }.accessibilityElement(children: .combine)
                    }.buttonStyle(.plain).accessibilityIdentifier("roam.capsule.row.locked")
                }
            }
            if !model.isBusy && model.items.isEmpty && model.phase == .ready {
                Text("roam.capsule.empty").foregroundStyle(.secondary).accessibilityIdentifier("roam.capsule.empty")
            }
            if model.hasMore && !model.isBusy {
                Button("roam.tools.loadMore") { page.read { await model.load(more: true) } }.accessibilityIdentifier("roam.capsule.more")
            }
        } header: {
            HStack { Text("roam.capsule.mine"); Spacer(); if !model.items.isEmpty { Text("roam.capsule.count.items \(model.items.count)") } }
        }
    }
}

// MARK: 探索目标

@MainActor struct RoamExplorationGoalsView: View {
    let tools: (any RoamPrivateToolsServing)?
    private let initialScope: RoamPrivatePageScope?
    private let initialConfigured: Bool?
    private let initialWrites: Bool?
    @ObservedObject private var scopeTracker = RoamHostedScopeTracker.shared
    init(tools: (any RoamPrivateToolsServing)?) {
        self.tools = tools
        self.initialScope = tools.map { RoamPrivatePageScope($0) }
        self.initialConfigured = tools?.isConfigured
        self.initialWrites = tools?.allowsWrites
        RoamHostedScopeTracker.shared.observePrivate(tools)
    }
    var body: some View {
        let _ = (scopeTracker.tick, initialScope, initialConfigured, initialWrites)
        let _ = RoamHostedScopeTracker.shared.observePrivate(tools)
        Group {
            if let tools {
                let scope = RoamPrivatePageScope(tools)
                RoamGoalsContent(tools: tools, isConfigured: tools.isConfigured, allowsWrites: tools.allowsWrites).id(scope)
            } else {
                List { RoamPrivateIssueView(issue: .notConfigured) }.cyGroupedSurface()
                    .background { RoamHostedAccessibilityGroup(items: [RoamHostedAccessibilityItem(identifier: "roam.private.issue")]) }
                    .accessibilityIdentifier("roam.goals.screen")
            }
        }
        .cyPageTitle("roam.goals.title")
        .cyDomainScreen(.player)
    }
}

extension RoamGoalMetric {
    var titleKey: LocalizedStringKey { self == .distinctRoutes ? "roam.goals.metric.routes" : "roam.goals.metric.days" }
}
extension RoamGoalState {
    var titleKey: LocalizedStringKey {
        switch self {
        case .active: return "roam.goals.state.active"; case .scheduled: return "roam.goals.state.scheduled"
        case .achieved: return "roam.goals.state.achieved"; case .ended: return "roam.goals.state.ended"; case .cancelled: return "roam.goals.state.cancelled"
        }
    }
}

@MainActor private struct RoamGoalsContent: View {
    let tools: any RoamPrivateToolsServing
    let isConfigured: Bool
    let allowsWrites: Bool
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.offlineWriteSession) private var offlineWriteSession
    @StateObject private var page: RoamPrivatePageOwner
    @State private var model: RoamGoalsCoordinator
    @State private var creating = false
    @State private var metric: RoamGoalMetric = .distinctRoutes
    @State private var target = 5
    @State private var period: RoamGoalPeriod.Kind = .month
    @State private var startDate = ""
    @State private var endDate = ""
    init(tools: any RoamPrivateToolsServing, isConfigured: Bool, allowsWrites: Bool) {
        self.tools = tools
        self.isConfigured = isConfigured
        self.allowsWrites = allowsWrites
        _page = StateObject(wrappedValue: RoamPrivatePageOwner(tools: tools))
        _model = State(initialValue: RoamGoalsCoordinator(tools: tools))
    }
    private func periodKey(_ kind: RoamGoalPeriod.Kind) -> LocalizedStringKey {
        switch kind { case .week: return "roam.goals.period.week"; case .month: return "roam.goals.period.month"; case .thirtyDays: return "roam.goals.period.thirty" }
    }
    private func amountText(_ metric: RoamGoalMetric, _ value: Int) -> Text {
        metric == .distinctRoutes ? Text("roam.goals.unit.routes \(value)") : Text("roam.goals.unit.days \(value)")
    }
    /// MP list row: `progress + " / " + target` when the count arrived, otherwise target and unit only.
    private func goalCount(_ row: RoamExplorationGoal) -> Text {
        if let progress = row.progress {
            return Text(verbatim: "\(progress) / ") + amountText(row.metric, row.target)
        }
        return amountText(row.metric, row.target)
    }
    var body: some View {
        List {
            if page.isPresented {
            CYScreenOfflineWriteSection(
                routes: ["/api/exploration-goals/create"],
                session: offlineWriteSession.session
            )
            if tools.isOfflineExample { Section { RoamExperienceNotice(offline: true) } }
            if let issue = model.issue, !(creating && (issue == .invalidDraft || isRejection(issue))) {
                Section { RoamPrivateIssueView(issue: issue, retry: issue == .outcomeUnknown ? nil : { page.read { await model.load() } }) }
            }
            if model.pending != nil || model.pendingRequestID != nil {
                Section {
                    Text("roam.goals.pending").accessibilityIdentifier("roam.goals.pending")
                    Button("roam.goals.verify") { page.settle(write: false, { await model.verifyPending() }, refresh: { await model.load() }) }
                        .disabled(model.isBusy).accessibilityIdentifier("roam.goals.verify")
                    // Restored lock: receipt check only. No draft means no resend.
                    if model.pending != nil {
                        Button("roam.goals.retryOriginal") {
                            page.settle(write: true, {
                                await SessionOfflineSyncModel.shared.performWriteOptIn(
                                    environmentSession: offlineWriteSession.session,
                                    routes: ["/api/exploration-goals/create"]
                                ) {
                                    await model.retryPending()
                                }
                            }, refresh: { await model.load() })
                        }
                            .disabled(model.isBusy || !model.canWrite).accessibilityIdentifier("roam.goals.retryOriginal")
                    }
                }
            }
            if let detail = model.detail { detailSection(detail) }
            if creating { form }
            Section {
                if model.isBusy && model.rows.isEmpty { ProgressView().frame(maxWidth: .infinity).accessibilityLabel(Text("roam.private.loading")) }  // N-TOOLS (r10)
                ForEach(model.rows) { row in
                    Button { page.read { await model.open(row.id) } } label: {
                        VStack(alignment: .leading, spacing: CYSpacing.xs) {
                            HStack {
                                goalCount(row).cyText(.cardTitle).monospacedDigit()
                                Spacer()
                                CYStatusChip(row.state.titleKey, tone: row.state == .achieved ? .success : .neutral)
                            }
                            if let percent = row.knownPercent {
                                ProgressView(value: Double(percent), total: 100)
                            }
                            (Text(verbatim: "\(row.startDate) – \(row.endDateExclusive) · ") + Text(row.metric.titleKey)).cyText(.caption).foregroundStyle(CYColor.textSecondary)
                        }.accessibilityElement(children: .combine)
                    }.buttonStyle(.plain).accessibilityIdentifier("roam.goals.row")
                }
                if !model.isBusy && model.rows.isEmpty && model.phase == .ready {
                    // TGOALS-1: the standard empty state (owner V3-28), with 新目标 when writes are open.
                    let canCreate = page.acceptsInput && !creating && tools.allowsWrites
                    CYEmptyState(systemImage: "tray", "roam.goals.empty", messageIdentifier: "roam.goals.empty",
                                 actionTitle: canCreate ? "roam.goals.new" : nil, actionIdentifier: "roam.goals.emptyNew",
                                 action: canCreate ? { startCreating() } : nil)
                }
                if model.hasMore && !model.isBusy {
                    Button("roam.tools.loadMore") { page.read { await model.load(more: true) } }
                        .accessibilityLabel(Text("roam.goals.more.a11y")).accessibilityIdentifier("roam.goals.more")
                }
            } header: {
                HStack { Text("roam.goals.mine"); Spacer(); if !model.rows.isEmpty { Text("roam.goals.count \(model.rows.count)") } }
            }
            } else if scenePhase == .active && (tools.identity == nil || !tools.isConfigured) {
                Section { RoamPrivateIssueView(issue: tools.identity == nil ? .signInRequired : .notConfigured) }
            }
        }.cyGroupedSurface()
        .disabled(!page.acceptsInput || page.settlementInFlight)
        .privacySensitive()
        .toolbar {
            if page.acceptsInput && !creating && tools.allowsWrites {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { startCreating() } label: { Image(systemName: "plus") }
                        .accessibilityLabel(Text("roam.goals.new")).accessibilityIdentifier("roam.goals.new")
                }
            }
        }
        .onAppear { activate(appearing: true) }
        .refreshable { await page.readNow { await model.load() } }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { retire() }
            else if phase == .active { activate() }
            else { page.inactive() }
        }
        .onChange(of: isConfigured) { _, configured in
            if configured { activate() } else { retire() }
        }
        .onChange(of: tools.isConfigured) { _, configured in
            if configured { activate() } else { retire() }
        }
        .onDisappear { retire(leaving: true) }
        .confirmationDialog("roam.goals.confirmTitle", isPresented: Binding(get: { model.review != nil }, set: { if !$0 { model.cancelCreateReview() } }), titleVisibility: .visible) {
            Button("roam.goals.create") {
                page.settle(write: true, {
                    await SessionOfflineSyncModel.shared.performWriteOptIn(
                        environmentSession: offlineWriteSession.session,
                        routes: ["/api/exploration-goals/create"]
                    ) {
                        await model.confirmCreate()
                    }
                }, refresh: { await model.load() }) { saved in if saved { creating = false } }
            }.accessibilityIdentifier("roam.goals.confirmCreate")
            Button("roam.private.notNow", role: .cancel) { model.cancelCreateReview() }
        } message: {
            if let review = model.review { amountText(review.metric, review.target) + Text(verbatim: " · \(review.startDate) – \(review.endDateExclusive)") }
        }
        .confirmationDialog("roam.goals.cancelTitle", isPresented: Binding(get: { model.cancelReview != nil }, set: { if !$0 { model.keepGoal() } }), titleVisibility: .visible) {
            Button("roam.goals.cancelGoal", role: .destructive) { page.settle(write: true, { await model.confirmCancel() }, refresh: { await model.load() }) }.accessibilityIdentifier("roam.goals.confirmCancel")
            Button("roam.goals.keep", role: .cancel) { model.keepGoal() }
        } message: { Text("roam.goals.cancelMessage") }
        .background { RoamHostedAccessibilityGroup(items: goalsAccessibilityItems) }
        .accessibilityIdentifier("roam.goals.screen")
    }
    private var goalsAccessibilityItems: [RoamHostedAccessibilityItem] {
        let _ = (isConfigured, allowsWrites)
        var items: [RoamHostedAccessibilityItem] = []
        if page.isPresented {
            if let issue = model.issue, !(creating && (issue == .invalidDraft || isRejection(issue))) {
                items.append(RoamHostedAccessibilityItem(identifier: "roam.private.issue"))
                if issue != .outcomeUnknown, issue != .signInRequired, issue != .notConfigured {
                    items.append(
                        RoamHostedAccessibilityItem(
                            identifier: "roam.private.retry",
                            action: { page.read { await model.load() } }
                        )
                    )
                }
            }
            if model.detail != nil {
                items.append(RoamHostedAccessibilityItem(identifier: "roam.goals.detail"))
            }
            if creating {
                items.append(RoamHostedAccessibilityItem(identifier: "roam.goals.metricPicker"))
            }
            if let first = model.rows.first {
                items.append(
                    RoamHostedAccessibilityItem(
                        identifier: "roam.goals.row",
                        action: { page.read { await model.open(first.id) } }
                    )
                )
            }
            if !model.isBusy && model.rows.isEmpty && model.phase == .ready {
                items.append(RoamHostedAccessibilityItem(identifier: "roam.goals.empty"))
            }
            if model.hasMore && !model.isBusy {
                items.append(
                    RoamHostedAccessibilityItem(
                        identifier: "roam.goals.more",
                        action: { page.read { await model.load(more: true) } }
                    )
                )
            }
            if page.acceptsInput && !page.settlementInFlight && !model.isBusy && !creating && tools.allowsWrites {
                items.append(
                    RoamHostedAccessibilityItem(
                        identifier: "roam.goals.new",
                        action: { startCreating() }
                    )
                )
            }
        } else if scenePhase == .active && (tools.identity == nil || !tools.isConfigured) {
            items.append(RoamHostedAccessibilityItem(identifier: "roam.private.issue"))
        }
        return items
    }
    private func activate(appearing: Bool = false) {
        let started = appearing ? page.appear(foreground: scenePhase == .active) : page.activate(foreground: scenePhase == .active)
        if started { model.resume(); page.read { await model.load() } }
    }
    private func retire(leaving: Bool = false) {
        page.retire(leaving: leaving); model.suspend()
        if leaving { creating = false; startDate = ""; endDate = "" }
    }
    private func isRejection(_ issue: RoamPrivateToolIssue) -> Bool { if case .rejected = issue { return true }; return false }
    private func usePeriod(_ kind: RoamGoalPeriod.Kind) {
        guard let value = model.periods.first(where: { $0.kind == kind }) else { return }
        period = kind; startDate = value.startDate; endDate = value.endDateExclusive
    }
    private func startCreating() { guard page.acceptsInput, !page.settlementInFlight, !model.isBusy else { return }; usePeriod(period); model.dismissIssue(); creating = true }
    @ViewBuilder private func detailSection(_ detail: RoamExplorationGoal) -> some View {
        Section {
            (Text(detail.metric.titleKey) + Text(verbatim: " · ") + Text(detail.state.titleKey)).cyText(.meta).foregroundStyle(.secondary)
            (Text(verbatim: "\(detail.progress ?? 0)").cyText(.dataXL) + Text(verbatim: " / \(detail.target)").cyText(.sheetTitle))
                .monospacedDigit().accessibilityIdentifier("roam.goals.detail.progress")
            ProgressView(value: Double(detail.percent), total: 100).accessibilityLabel(Text(detail.metric.titleKey))
            Text("roam.goals.range \(detail.startDate) \(detail.endDateExclusive)").cyText(.meta).foregroundStyle(.secondary)
            Button("roam.goals.collapse") { model.closeDetail() }.accessibilityIdentifier("roam.goals.collapse")
            if detail.state.isCancellable && model.canWrite {
                Button("roam.goals.cancelThis", role: .destructive) { guard page.acceptsInput, !page.settlementInFlight else { return }; model.prepareCancel() }.accessibilityIdentifier("roam.goals.cancelThis")
            }
        }.accessibilityIdentifier("roam.goals.detail")
    }
    @ViewBuilder private var form: some View {
        Section {
            Picker("roam.goals.metric", selection: $metric) {
                ForEach(RoamGoalMetric.allCases) { Text($0.titleKey).tag($0) }
            }.pickerStyle(.segmented).accessibilityIdentifier("roam.goals.metricPicker")
            Stepper(value: $target, in: 1...100) { amountText(metric, target).monospacedDigit() }
                .accessibilityIdentifier("roam.goals.target")
        }.disabled(model.isBusy || model.pending != nil)
        Section {
            Picker("roam.goals.period", selection: Binding(get: { period }, set: { usePeriod($0) })) {
                ForEach(RoamGoalPeriod.Kind.allCases, id: \.self) { Text(periodKey($0)).tag($0) }
            }.pickerStyle(.segmented).accessibilityIdentifier("roam.goals.periodPicker")
            DatePicker("roam.goals.start", selection: Binding(get: { RoamShanghaiPicker.date(startDate) }, set: { startDate = RoamShanghaiPicker.text($0) }),
                       in: RoamShanghaiPicker.date(model.today)..., displayedComponents: .date)
                .environment(\.timeZone, RoamShanghaiPicker.timeZone).accessibilityIdentifier("roam.goals.startDate")
            DatePicker("roam.goals.end", selection: Binding(get: { RoamShanghaiPicker.date(endDate) }, set: { endDate = RoamShanghaiPicker.text($0) }),
                       in: RoamShanghaiPicker.date(startDate)..., displayedComponents: .date)
                .environment(\.timeZone, RoamShanghaiPicker.timeZone).accessibilityIdentifier("roam.goals.endDate")
        } header: { Text("roam.goals.period") }
            .disabled(model.isBusy || model.pending != nil)
        if let issue = model.issue, issue == .invalidDraft || isRejection(issue) {
            // Refusals stay on the form: adjust and create again; the same payload is never resent.
            Section { RoamPrivateIssueView(issue: issue, dismiss: { model.dismissIssue() }) }
        }
        Section {
            Button("roam.goals.create") { guard page.acceptsInput, !page.settlementInFlight else { return }; model.prepareCreate(metric: metric, target: target, startDate: startDate, endDateExclusive: endDate) }
                .disabled(model.isBusy || model.pending != nil || !model.canWrite).accessibilityIdentifier("roam.goals.create")
            Button("roam.goals.later") { creating = false; model.dismissIssue() }.disabled(model.isBusy).accessibilityIdentifier("roam.goals.later")
        }
    }
}
