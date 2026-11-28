import SwiftUI

/// Route ownership is independent of fetched rows. Disappearance purges data, not the link host.
@MainActor final class NativeFriendDirectoryNavigation: ObservableObject {
    let flow: NativeFriendDirectoryFlow
    @Published var selection: NativeFriendDirectoryDetailModel? {
        didSet { if oldValue !== selection { oldValue?.retire() } }
    }
    init(_ flow: NativeFriendDirectoryFlow) {
        self.flow = flow
        flow.onChange = { [weak self] in
            guard let self else { return }
            if !self.flow.isCurrent { self.selection = nil }
            self.objectWillChange.send()
        }
    }
    func open(_ item: NativeFriendItem) {
        guard flow.isCurrent, !flow.busy, flow.phase == .ready, flow.items.contains(item), selection == nil else { return }
        let destination = NativeFriendDirectoryDetailModel(flow.makeDetail(peerID: item.peerID))
        destination.onRetired = { [weak self, weak destination] in
            if self?.selection === destination { self?.selection = nil }
        }
        selection = destination
    }
}
@MainActor struct NativeFriendDirectoryView: View {
    @Environment(\.locale) private var locale
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var model: NativeFriendDirectoryNavigation
    let metadataFactory: ((NativeFriendItem) -> NativeFriendMetadataFlow)?
    let removalFactory: ((NativeFriendItem?) -> NativeFriendRemovalFlow)?
    let publicProfile: ((Int, @escaping () -> Bool) -> AnyView)?
    let conversation: (Int) -> AnyView
    let progressCard: ((NativeFriendItem, @escaping () -> Bool) -> AnyView)?
    init(flow: NativeFriendDirectoryFlow, navigation: NativeFriendDirectoryNavigation? = nil, metadataFactory: ((NativeFriendItem) -> NativeFriendMetadataFlow)? = nil,
         removalFactory: ((NativeFriendItem?) -> NativeFriendRemovalFlow)? = nil, publicProfile: ((Int, @escaping () -> Bool) -> AnyView)? = nil, progressCard: ((NativeFriendItem, @escaping () -> Bool) -> AnyView)? = nil, conversation: @escaping (Int) -> AnyView) {
        _model = StateObject(wrappedValue: navigation ?? NativeFriendDirectoryNavigation(flow)); self.metadataFactory = metadataFactory
        self.removalFactory = removalFactory; self.publicProfile = publicProfile; self.progressCard = progressCard; self.conversation = conversation
    }
    private var flow: NativeFriendDirectoryFlow { model.flow }
    private var filterActive: Bool { flow.filter.groupID != nil || flow.filter.starredOnly }
    var body: some View {
        List {
            Section {
                Picker(localized("friendDirectory.partition"), selection: Binding(get: { flow.filter.section }, set: { value in
                    var filter = flow.filter; filter.section = value; Task { await flow.select(filter) }
                })) {
                    ForEach(NativeFriendDirectorySection.allCases, id: \.self) { section in
                        text("friendDirectory." + section.rawValue).tag(section)
                    }
                }
                .cyAdaptiveSegmented().labelsHidden()
                .accessibilityIdentifier("friendDirectory.partition")
            }
            if flow.busy {
                Section {
                    ProgressView { Text("cloud31.loading.friends") }
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("friendDirectory.loading")
                }
            }
            if flow.phase == .closed {
                Section { Label(localized("friendDirectory.closed"), systemImage: "lock").foregroundStyle(.secondary) }
            }
            if let issue = flow.issue {
                Section {
                    ContentUnavailableView {
                        Label(localized(issue), systemImage: "exclamationmark.triangle")
                    } actions: {
                        Button(localized(flow.paginationFailed ? "friendDirectory.retryPage" : "friendDirectory.refresh")) { Task { await flow.retry() } }
                            .buttonStyle(.bordered)
                            .disabled(flow.busy)
                    }
                    .accessibilityIdentifier("friendDirectory.issue")
                }
            }
            Section {
                if flow.phase == .ready && flow.items.isEmpty {
                    ContentUnavailableView {
                        Label { text("friendDirectory.empty") } icon: { Image(systemName: "person.2") }
                    }
                    .accessibilityIdentifier("friendDirectory.empty")
                }
                ForEach(flow.items) { item in
                    Button { model.open(item) } label: {
                        LabeledContent {
                            if item.starred == 1 {
                                Image(systemName: "star.fill")
                                    .foregroundStyle(CYColor.ratingStar)
                                    .accessibilityLabel(Text("friendMeta.starred", tableName: "NativeFriendMetadata"))
                            }
                        } label: {
                            Label {
                                VStack(alignment: .leading) {
                                    Text(verbatim: friendName(item)).foregroundStyle(.primary)
                                    if let remark = remarkLine(item) { Text(verbatim: remark).font(.subheadline).foregroundStyle(.secondary) }
                                }
                            } icon: {
                                Image(systemName: "person.crop.circle.fill").foregroundStyle(.secondary)
                            }
                        }
                    }.disabled(flow.busy).accessibilityIdentifier("friendDirectory.peer.\(item.peerID)")
                }
                if flow.nextCursor != nil {
                    Button { Task { await flow.loadMore() } } label: { text("friendDirectory.more") }
                        .disabled(flow.busy).accessibilityIdentifier("friendDirectory.more")
                }
            } header: {
                Text(verbatim: sectionHeading)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(localized("friendDirectory.title"))
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("friendDirectory.home")
        .task { await flow.load() }
        .refreshable { await flow.load() }
        .onDisappear { flow.invalidate() }
        .onChange(of: scenePhase) { _, value in
            switch value {
            case .active:
                if model.selection == nil { Task { await flow.load() } }
            case .background:
                flow.invalidate()
            case .inactive:
                break
            @unknown default:
                break
            }
        }
        // Always hosted outside ForEach: clearing the parent's rows cannot remove this destination.
        // Before toolbar, so iOS 27 keeps this modifier inside the NavigationStack instead of marking it misplaced.
        .navigationDestination(isPresented: detailBinding) {
            if let detail = model.selection {
                NativeFriendDirectoryDetailView(model: detail, metadataFactory: metadataFactory,
                    removalFactory: removalFactory, publicProfile: publicProfile, progressCard: progressCard, conversation: conversation).id(detail.id)
            }
        }
        // A second push (metadata, profile) during the detail transition is dropped by UIKit.
        .animation(nil, value: model.selection?.id)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Picker(localized("friendDirectory.group"), selection: Binding(get: { flow.filter.groupID }, set: { value in
                        var filter = flow.filter; filter.groupID = value; Task { await flow.select(filter) }
                    })) {
                        text("friendDirectory.allGroups").tag(Int64?.none)
                        ForEach(flow.groups) { group in
                            Text(verbatim: group.isDefault == 1 ? localized("friendDirectory.defaultGroup") : (group.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "—" : group.name)).tag(Optional(group.id ?? 0))
                        }
                    }.accessibilityIdentifier("friendDirectory.group")
                    Toggle(isOn: Binding(get: { flow.filter.starredOnly }, set: { value in
                        var filter = flow.filter; filter.starredOnly = value; Task { await flow.select(filter) }
                    })) { text("friendDirectory.starredOnly") }.accessibilityIdentifier("friendDirectory.starredOnly")
                } label: {
                    Label { text("d7.friendDirectory.filter") } icon: {
                        Image(systemName: filterActive ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    }
                }.disabled(flow.busy)
            }
        }
    }
    /// A stored count stays as written, including 0. A missing count is unknown.
    private var sectionHeading: String {
        let name = localized("friendDirectory." + flow.filter.section.rawValue)
        if let count = flow.counts[flow.filter.section.rawValue] { return "\(name) · \(count)" }
        return "\(name) · —"
    }
    private func friendName(_ item: NativeFriendItem) -> String {
        let name = item.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "—" : name
    }
    /// Remark shown with the original nickname so a renamed friend stays recognisable.
    private func remarkLine(_ item: NativeFriendItem) -> String? {
        guard let remark = item.friendRemark, !remark.isEmpty, !item.nickname.isEmpty, remark != item.nickname else { return nil }
        return item.nickname
    }
    private var detailBinding: Binding<Bool> {
        let captured = model.selection
        return Binding(get: { model.selection != nil }, set: { presented in
            if !presented, model.selection === captured { model.selection = nil }
        })
    }
    private func localized(_ key: String) -> String { String(localized: LocalizedStringResource(String.LocalizationValue(stringLiteral: key), table: "NativeFriendDirectory", locale: locale)) }
    private func text(_ key: String) -> Text { Text(LocalizedStringKey(key), tableName: "NativeFriendDirectory") }
}

@MainActor final class NativeFriendDirectoryDetailModel: ObservableObject, Identifiable {
    struct ProfileRoute: Equatable, Identifiable {
        let id = UUID()
        let memberID: Int
    }
    @MainActor enum Child {
        case metadata(NativeFriendMetadataFlow, String)
        case removal(NativeFriendRemovalFlow)
        case profile(ProfileRoute)
        case conversation(Int)
        func invalidate() {
            switch self {
            case .metadata(let flow, _): flow.invalidate()
            case .removal(let flow): flow.invalidate()
            case .profile, .conversation: break
            }
        }
    }
    let id = UUID()
    let flow: NativeFriendDirectoryDetailFlow
    var onRetired: (() -> Void)?
    @Published var child: Child? { didSet { routeGeneration &+= 1; oldValue?.invalidate() } }
    private var retiring = false
    private(set) var routeGeneration: UInt64 = 0
    init(_ flow: NativeFriendDirectoryDetailFlow) {
        self.flow = flow
        flow.onChange = { [weak self] in
            guard let self else { return }
            if !self.flow.isCurrent { self.retire(); self.onRetired?() }
            self.objectWillChange.send()
        }
    }
    func openMetadata(using factory: (NativeFriendItem) -> NativeFriendMetadataFlow) {
        guard flow.canOpen, let item = flow.detail?.item, item.peerID == flow.peerID, child == nil else { return }
        child = .metadata(factory(item), item.nickname)
    }
    func openRemoval(using factory: (NativeFriendItem?) -> NativeFriendRemovalFlow) {
        guard flow.canOpen, let item = flow.detail?.item, item.peerID == flow.peerID, child == nil else { return }
        child = .removal(factory(item))
    }
    func openProfile() async {
        guard child == nil, flow.canOpen else { return }
        let stamp = routeGeneration
        guard let item = await flow.currentFriend(), !Task.isCancelled,
              stamp == routeGeneration, child == nil, flow.isCurrent,
              item.peerID == flow.peerID, let memberID = Int(exactly: item.peerID) else { return }
        child = .profile(.init(memberID: memberID))
    }
    func owns(_ profile: ProfileRoute) -> Bool {
        guard flow.isCurrent, case .profile(let current)? = child else { return false }
        return current == profile
    }
    func openConversation() async {
        guard child == nil, flow.canOpen else { return }
        let stamp = routeGeneration
        guard let id = await flow.existingConversation(), !Task.isCancelled,
              stamp == routeGeneration, child == nil, flow.isCurrent else { return }
        child = .conversation(id)
    }
    func closeChild(generation: UInt64) {
        guard generation == routeGeneration else { return }
        child = nil
    }
    func retire() {
        guard !retiring else { return }; retiring = true
        child = nil; flow.invalidate(); retiring = false
    }
}
@MainActor private struct NativeFriendDirectoryDetailView: View {
    @Environment(\.locale) private var locale
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var model: NativeFriendDirectoryDetailModel
    let metadataFactory: ((NativeFriendItem) -> NativeFriendMetadataFlow)?
    let removalFactory: ((NativeFriendItem?) -> NativeFriendRemovalFlow)?
    let publicProfile: ((Int, @escaping () -> Bool) -> AnyView)?
    let conversation: (Int) -> AnyView
    let progressCard: ((NativeFriendItem, @escaping () -> Bool) -> AnyView)?
    init(model: NativeFriendDirectoryDetailModel, metadataFactory: ((NativeFriendItem) -> NativeFriendMetadataFlow)?,
         removalFactory: ((NativeFriendItem?) -> NativeFriendRemovalFlow)?, publicProfile: ((Int, @escaping () -> Bool) -> AnyView)?, progressCard: ((NativeFriendItem, @escaping () -> Bool) -> AnyView)?, conversation: @escaping (Int) -> AnyView) {
        _model = StateObject(wrappedValue: model); self.metadataFactory = metadataFactory
        self.removalFactory = removalFactory; self.publicProfile = publicProfile; self.progressCard = progressCard; self.conversation = conversation
    }
    private var flow: NativeFriendDirectoryDetailFlow { model.flow }
    var body: some View {
        // The push lives on this group, not on the List. Purging the detail snapshot rebuilds
        // the List, and a destination attached to that List is deinited mid-push (idle → failed).
        Group { detailList }
            .navigationDestination(isPresented: childBinding) {
                Group {
                    if let child = model.child {
                        switch child {
                        case .metadata(let metadata, let nickname): NativeFriendMetadataView(flow: metadata, nickname: nickname)
                        case .removal(let removal): NativeFriendRemovalView(flow: removal)
                        case .profile(let profile):
                            if let publicProfile { publicProfile(profile.memberID, { model.owns(profile) }).id(profile.id) }
                        case .conversation(let id): conversation(id)
                        }
                    }
                }
                .cyPushedChrome()
            }
    }
    private var detailList: some View {
        List {
            Section {
                if let item = flow.detail?.item {
                    let name = item.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
                    Label {
                        VStack(alignment: .leading) {
                            Text(verbatim: name.isEmpty ? "—" : name)
                                .font(.title2.bold())
                                .accessibilityIdentifier("friendDirectory.detailName")
                                .accessibilityAddTraits(.isHeader)
                            Text(verbatim: localized("friendDirectory.detail")).font(.subheadline).foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "person.crop.circle.fill").font(.largeTitle).foregroundStyle(.secondary)
                    }
                } else if flow.busy {
                    ProgressView { Text("cloud31.loading.friends") }
                        .frame(maxWidth: .infinity)
                }
                if let detail = flow.detail {
                    if detail.conversationID != nil {
                        Button { Task { await model.openConversation() } } label: { Label("d7.friendProfile.message", systemImage: "message.fill") }
                            .disabled(!flow.canOpen).accessibilityIdentifier("friendDirectory.chat")
                    }
                    if publicProfile != nil {
                        Button { Task { await model.openProfile() } } label: { Label("d7.friendProfile.profile", systemImage: "person.text.rectangle") }
                            .disabled(!flow.canOpen).accessibilityIdentifier("friendDirectory.profile")
                    }
                    if let metadataFactory {
                        Button { model.openMetadata(using: metadataFactory) } label: { Label("d7.friendProfile.settings", systemImage: "slider.horizontal.3") }
                            .disabled(!flow.canOpen).accessibilityIdentifier("friendDirectory.metadata")
                    }
                }
            }
            if let issue = flow.issue {
                Section {
                    ContentUnavailableView {
                        Label(localized(issue), systemImage: "exclamationmark.triangle")
                    } actions: {
                        Button(localized("friendDirectory.refresh")) { Task { await flow.load() } }
                            .buttonStyle(.bordered)
                            .disabled(flow.busy)
                    }
                    .accessibilityIdentifier("friendDirectory.detailIssue")
                }
            }
            if let detail = flow.detail {
                let item = detail.item
                Section {
                    LabeledContent {
                        Label(localized(item.starred == 1 ? "friendDirectory.starred" : "friendDirectory.notStarred"),
                              systemImage: item.starred == 1 ? "star.fill" : "star")
                            .foregroundStyle(item.starred == 1 ? CYColor.warningText : Color.secondary)
                    } label: { Text("friendMeta.starred", tableName: "NativeFriendMetadata") }
                }
                if let progressCard, flow.canOpen {
                    progressCard(item, { flow.isCurrent && flow.canOpen && flow.detail?.item.peerID == item.peerID && flow.detail?.item.version == item.version })
                }
                if let removalFactory {
                    Section {
                        Button(role: .destructive) { model.openRemoval(using: removalFactory) } label: {
                            Text("friendRemoval.title", tableName: "NativeFriendRemoval")
                        }
                            .disabled(!flow.canOpen).accessibilityIdentifier("friendDirectory.remove")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("friendDirectory.detail")
        .task { await flow.load() }
        .refreshable { await flow.load() }
        .onDisappear { flow.invalidate() }
        .onChange(of: scenePhase) { _, value in
            switch value {
            case .active:
                if model.child == nil { Task { await flow.load() } }
            case .background:
                model.retire()
            case .inactive:
                // Navigation transitions report inactive. That must not pop the child.
                break
            @unknown default:
                break
            }
        }
    }
    private var childBinding: Binding<Bool> {
        let captured = model.routeGeneration
        return Binding(get: { model.child != nil }, set: { presented in
            if !presented { model.closeChild(generation: captured) }
        })
    }
    private func localized(_ key: String) -> String { String(localized: LocalizedStringResource(String.LocalizationValue(stringLiteral: key), table: "NativeFriendDirectory", locale: locale)) }
    private func text(_ key: String) -> Text { Text(LocalizedStringKey(key), tableName: "NativeFriendDirectory") }
}
