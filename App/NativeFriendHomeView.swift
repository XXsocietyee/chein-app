import SwiftUI

/// Normal user entry, not an audit hub. Its injected service independently retains closed production grants.
@MainActor struct NativeFriendHomeView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var model: NativeFriendHomeNavigation
    let conversation: (Int) -> AnyView
    let publicProfile: ((Int, @escaping () -> Bool) -> AnyView)?
    let progressCard: ((NativeFriendItem, @escaping () -> Bool) -> AnyView)?
    let directoryFactory: (() -> NativeFriendDirectoryFlow)?
    let metadataFactory: ((NativeFriendItem) -> NativeFriendMetadataFlow)?
    let groupsFactory: (() -> NativeFriendMetadataFlow)?
    let removalFactory: ((NativeFriendItem?) -> NativeFriendRemovalFlow)?
    let blacklistFactory: (() -> NativeBlacklistFlow)?
    @State private var peer = ""
    @State private var message = ""
    @State private var addingFriend = false
    @State private var queuedPeer: Int64?
    init(flow: NativeFriendFlow, navigation: NativeFriendHomeNavigation? = nil, directoryFactory: (() -> NativeFriendDirectoryFlow)? = nil, metadataFactory: ((NativeFriendItem) -> NativeFriendMetadataFlow)? = nil, groupsFactory: (() -> NativeFriendMetadataFlow)? = nil, removalFactory: ((NativeFriendItem?) -> NativeFriendRemovalFlow)? = nil, blacklistFactory: (() -> NativeBlacklistFlow)? = nil, publicProfile: ((Int, @escaping () -> Bool) -> AnyView)? = nil, progressCard: ((NativeFriendItem, @escaping () -> Bool) -> AnyView)? = nil, conversation: @escaping (Int) -> AnyView) {
        _model = StateObject(wrappedValue: navigation ?? NativeFriendHomeNavigation(flow)); self.conversation = conversation; self.directoryFactory = directoryFactory; self.metadataFactory = metadataFactory; self.groupsFactory = groupsFactory; self.removalFactory = removalFactory; self.blacklistFactory = blacklistFactory; self.publicProfile = publicProfile; self.progressCard = progressCard
    }
    private var flow: NativeFriendFlow { model.flow }
    private var canSendRequest: Bool {
        flow.canWrite && Int64(peer).map { $0 > 0 } == true && !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && message.unicodeScalars.count <= 60
    }
    var body: some View {
        List {
            if directoryFactory != nil || groupsFactory != nil || blacklistFactory != nil || removalFactory != nil {
                Section {
                    if let directoryFactory {
                        NavigationLink {
                            NativeFriendDirectoryView(flow: directoryFactory(), metadataFactory: metadataFactory,
                                removalFactory: removalFactory, publicProfile: publicProfile, progressCard: progressCard, conversation: conversation)
                        } label: {
                            Label(tableString("friendDirectory.title", table: "NativeFriendDirectory"), systemImage: "person.crop.rectangle.stack")
                        }
                        .accessibilityIdentifier("friendDirectory.entry")
                    }
                    if let groupsFactory {
                        Button { model.openGroups(using:groupsFactory) } label: {
                            Label(tableString("friendMeta.recoveryEntry", table: "NativeFriendMetadata"), systemImage: "folder")
                        }
                        .accessibilityIdentifier("friendMeta.recoveryEntry")
                    }
                    if let blacklistFactory {
                        Button { model.openBlacklist(using: blacklistFactory) } label: {
                            Label(tableString("blacklist.title", table: "NativeBlacklist"), systemImage: "hand.raised")
                        }
                        .accessibilityIdentifier("blacklist.entry")
                    }
                    if let removalFactory {
                        NavigationLink {
                            NativeFriendRemovalView(flow: removalFactory(nil), onResolved: { Task { await flow.load() } })
                        } label: {
                            Label(tableString("friendRemoval.recoveryEntry", table: "NativeFriendRemoval"), systemImage: "person.badge.clock")
                        }
                        .accessibilityIdentifier("friendRemoval.recoveryEntry")
                    }
                }
            }
            if flow.phase == .closed {
                Section { status(localized("friend.closed"), tint: .secondary, systemImage: "lock") }
                    .accessibilityIdentifier("friend.closed")
            }
            if flow.busy {
                Section {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("friend.loading")
                        .accessibilityLabel(Text("cloud31.loading.friends"))
                }
            }
            if let issue = flow.issue {
                Section {
                    ContentUnavailableView {
                        Label { Text(LocalizedStringKey(issue), tableName: "NativeFriend") } icon: { Image(systemName: "exclamationmark.triangle") }
                    }
                }
            }
            if flow.pending != nil {
                Section {
                    status(localized("friend.unknown"), tint: .orange, systemImage: "questionmark.circle")
                    if !flow.isCurrent { status(localized("friend.closed"), tint: .secondary, systemImage: "lock") }
                    Button { Task { await flow.recover() } } label: { Label(localized("friend.recover"), systemImage: "arrow.clockwise") }
                        .disabled(!flow.canRecover).accessibilityIdentifier("friend.recover")
                    Button { Task { await flow.retryOriginal() } } label: { text("friend.retryOriginal") }
                        .disabled(!flow.canRetryOriginal).accessibilityIdentifier("friend.retryOriginal")
                }
            }
            if let relationship = flow.relationship {
                Section {
                    if let review = flow.lastReview {
                        status(localized("friend.review." + review.state.rawValue), tint: reviewTone(review.state), systemImage: "clock")
                    } else {
                        status(localized(stateKey(relationship.state)), tint: relationTone(relationship.state), systemImage: "person")
                            .accessibilityIdentifier("friend.relationship")
                    }
                } header: { Text(verbatim: localized("friend.result")) }
            }
            if !flow.incoming.isEmpty {
                Section {
                    ForEach(flow.incoming) { item in
                        VStack(alignment: .leading) {
                            row(item)
                            HStack {
                                action("friend.accept", .accept, item)
                                action("friend.reject", .reject, item)
                            }
                        }
                    }
                } header: { Text("d7.friends.received \(flow.incoming.count)", tableName: "NativeFriend") }
            }
            if !flow.outgoing.isEmpty || flow.requestCursor != nil {
                Section {
                    ForEach(flow.outgoing) { item in
                        let stacked = dynamicTypeSize.isAccessibilitySize
                        let layout = stacked
                            ? AnyLayout(VStackLayout(alignment: .leading))
                            : AnyLayout(HStackLayout(alignment: .center))
                        layout {
                            row(item)
                            action("friend.withdraw", .cancel, item)
                        }
                    }
                    if flow.requestCursor != nil {
                        Button { Task { await flow.loadMore(requests: true) } } label: { text("friend.more") }.disabled(flow.busy)
                    }
                } header: { Text("d7.friends.sent \(flow.outgoing.count)", tableName: "NativeFriend") }
            }
            if !flow.reviews.isEmpty {
                Section {
                    ForEach(flow.reviews) { review in
                        let stacked = dynamicTypeSize.isAccessibilitySize
                        let layout = stacked
                            ? AnyLayout(VStackLayout(alignment: .leading))
                            : AnyLayout(HStackLayout(alignment: .firstTextBaseline))
                        layout {
                            VStack(alignment: .leading) {
                                Text(verbatim: review.message)
                                    .fixedSize(horizontal: false, vertical: true)
                                status(localized("friend.review." + review.state.rawValue), tint: reviewTone(review.state), systemImage: "clock")
                                    .font(.subheadline)
                            }
                            if review.state == .pending {
                                if !stacked { Spacer(minLength: 0) }
                                Button { flow.reviewCancellation(review) } label: { text("friend.withdraw") }
                                    .buttonStyle(.borderless)
                                    .disabled(!flow.canWrite)
                            }
                        }
                        .accessibilityIdentifier("friend.review.\(review.id)")
                    }
                    if flow.reviewCursor != nil { Button { Task { await flow.loadMoreReviews() } } label: { text("friend.more") }.disabled(flow.busy) }
                } header: { Text(verbatim: localized("friend.review.title")) }
            }
            if flow.phase == .ready && flow.friends.isEmpty {
                Section {
                    ContentUnavailableView {
                        Label { Text("friend.emptyFriends", tableName: "NativeFriend") } icon: { Image(systemName: "person.2") }
                    } actions: {
                        Button { addingFriend = true } label: {
                            Label { Text("friend.new", tableName: "NativeFriend") } icon: { Image(systemName: "person.badge.plus") }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!flow.canWrite)
                    }
                }
            } else if flow.groups.isEmpty {
                Section { friendRows(flow.friends) } header: { Text(verbatim: localized("friend.friends")) }
            } else {
                ForEach(flow.groups) { group in
                    let members = flow.friends.filter { group.isDefault == 1 ? $0.groupID == nil : $0.groupID == group.id }
                    if !members.isEmpty {
                        Section {
                            friendRows(members)
                        } header: {
                            if group.isDefault == 1 {
                                Text(verbatim: localized("friend.defaultGroup"))
                            } else {
                                let name = group.name.trimmingCharacters(in: .whitespacesAndNewlines)
                                Text(verbatim: name.isEmpty ? "—" : name)
                            }
                        }
                    }
                }
            }
            if flow.friendCursor != nil {
                Button { Task { await flow.loadMore(requests:false) } } label: { text("friend.more") }.disabled(flow.busy)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(Text("friend.title", tableName: "NativeFriend"))
        .accessibilityIdentifier("friend.home")
        .task { await flow.load() }
        .refreshable { await flow.load() }
        .onDisappear { peer = ""; message = ""; flow.invalidate() }
        .onChange(of: scenePhase) { _, value in
            if value == .active { if model.child == nil { Task { await flow.load() } } }
            else { peer = ""; message = ""; addingFriend = false; model.suspend() }
        }
        .onChange(of: flow.isCurrent) { _, current in if !current { peer = ""; message = ""; addingFriend = false } }
        // The destination is not owned by a fetched row and survives its parent's onDisappear purge.
        // It has to sit inside the NavigationStack, before toolbar: on iOS 27 a destination after toolbar is
        // reported as a misplaced navigationDestination(isPresented:) and never pushes.
        .navigationDestination(isPresented: Binding(get: { model.child != nil }, set: { if !$0 { model.child = nil } })) {
            Group { if let child = model.child {
                switch child {
                case .blacklist(let blacklist): NativeBlacklistView(flow: blacklist)
                case .groups(let groups): NativeFriendMetadataView(flow:groups,nickname:"",onApplied:{ Task { await flow.load() } })
                case .metadata(let metadata, let nickname):
                    if flow.isCurrent { NativeFriendMetadataView(flow: metadata, nickname: nickname, onApplied: { Task { await flow.load() } }) }
                case .removal(let removal):
                    if flow.isCurrent { NativeFriendRemovalView(flow: removal, onResolved: { Task { await flow.load() } }) }
                case .conversation(let id):
                    if flow.isCurrent { conversation(id) }
                }
            } }
            // A covered parent in a NavigationStack no longer receives its own scenePhase change on iOS 26+/27, so the
            // visible destination observes the phase itself and suspends (pops + purges) the owner destination.
            .modifier(NativeFriendDestinationSuspension(suspend: { model.suspend() }))
        }
        // The request is reviewed only after this sheet closes, so the confirmation sheet never stacks on it.
        .cySheet(isPresented: $addingFriend, onDismiss: {
            guard let id = queuedPeer else { return }
            queuedPeer = nil
            flow.reviewRequest(peerID: id, message: message)
        }) {
            NavigationStack {
                Form {
                    Section {
                        TextField(localized("friend.peer"), text: $peer).keyboardType(.numberPad)
                            .accessibilityIdentifier("friend.peer")
                        TextField(localized("friend.message"), text: $message, axis: .vertical)
                            .submitLabel(.send)
                            .accessibilityIdentifier("friend.message")
                    }
                }
                .formStyle(.grouped)
                .navigationTitle(Text("friend.new", tableName: "NativeFriend"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button {
                            guard let id = Int64(peer) else { return }
                            queuedPeer = id; addingFriend = false
                        } label: {
                            Label(localized("friend.apply"), systemImage: "paperplane.fill")
                        }
                        .disabled(!canSendRequest)
                        .accessibilityIdentifier("friend.apply")
                    }
                }
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .cySheet(isPresented: Binding(get: { flow.actionReview != nil }, set: { if !$0 { flow.cancelReview() } })) {
            if let review = flow.actionReview {
                NavigationStack {
                    Form {
                        Section {
                            if review.displayName.isEmpty {
                                LabeledContent(localized("friend.peer"), value: String(review.command.peerID))
                                    .accessibilityIdentifier("friend.confirmPeer")
                            } else {
                                Text(verbatim: review.displayName)
                                    .font(.headline)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .accessibilityIdentifier("friend.confirmPeer")
                            }
                            if !review.message.isEmpty {
                                Text(verbatim: review.message)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .accessibilityIdentifier("friend.confirmMessage")
                            }
                        }
                        Section {
                            Button {
                                Task { await flow.confirmReview(expected: review) }
                            } label: {
                                Label(localized("friend.confirmContinue"), systemImage: "checkmark.circle")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .disabled(!flow.canWrite)
                            .accessibilityIdentifier("friend.confirmContinue")
                        }
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                    }
                    .formStyle(.grouped)
                    .navigationTitle(Text(verbatim: localized("friend.confirm." + review.command.action.rawValue)))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button { flow.cancelReview() } label: { text("friend.confirmCancel") }
                                .accessibilityIdentifier("friend.confirmCancel")
                        }
                    }
                }
                .accessibilityIdentifier("friend.confirmation")
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
        .toolbar {
            if flow.phase != .closed {
                ToolbarItem(placement: .primaryAction) {
                    Button { addingFriend = true } label: {
                        Label { text("friend.new") } icon: { Image(systemName: "person.badge.plus") }
                    }.accessibilityIdentifier("friend.add")
                }
            }
        }
    }
    private func localized(_ key: String) -> String {
        String(localized: LocalizedStringResource(String.LocalizationValue(stringLiteral: key), table: "NativeFriend", locale: locale))
    }
    private func tableString(_ key: String, table: String) -> String {
        String(localized: LocalizedStringResource(String.LocalizationValue(stringLiteral: key), table: table, locale: locale))
    }
    private func text(_ key: String) -> Text { Text(LocalizedStringKey(key), tableName: "NativeFriend") }
    @ViewBuilder private func friendRows(_ items: [NativeFriendItem]) -> some View {
        ForEach(items) { item in
            HStack(spacing: CYSpacing.md) {
                Button { Task { await model.openConversation(item) } } label: {
                    row(item).contentShape(Rectangle())
                }
                    .buttonStyle(.borderless).foregroundStyle(.primary)
                    .disabled(flow.busy).accessibilityIdentifier("friend.chat.\(item.peerID)")
                if let metadataFactory {
                    Button { model.openMetadata(item,using:metadataFactory) } label: {
                        Image(systemName: "info.circle")
                            .accessibilityLabel(Text("friendMeta.title", tableName: "NativeFriendMetadata"))
                    }
                        .buttonStyle(.borderless)
                        .disabled(flow.busy).accessibilityIdentifier("friendMeta.entry.\(item.peerID)")
                }
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                if let removalFactory {
                    Button { model.openRemoval(item,using:removalFactory) } label: {
                        Label { Text("friendRemoval.title", tableName: "NativeFriendRemoval") } icon: { Image(systemName: "person.badge.minus") }
                    }
                        .tint(.red)
                        .disabled(flow.busy).accessibilityIdentifier("friendRemoval.entry.\(item.peerID)")
                }
            }
        }
    }
    private func row(_ item: NativeFriendItem) -> some View {
        let name = item.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let meta: String? = (item.state != .friend && !item.message.isEmpty) ? item.message : nil
        return HStack {
            Label {
                VStack(alignment: .leading) {
                    Text(verbatim: name.isEmpty ? "—" : name)
                    if let meta {
                        Text(verbatim: meta)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            } icon: {
                Image(systemName: "person.crop.circle.fill")
                    .accessibilityHidden(true)
            }
            if item.starred == 1 {
                Spacer(minLength: 0)
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
                    .accessibilityLabel(Text("friendMeta.starred", tableName: "NativeFriendMetadata"))
            }
        }
        .accessibilityIdentifier("friend.row.\(item.peerID)")
    }
    private func action(_ key: String, _ kind: NativeFriendAction, _ item: NativeFriendItem) -> some View {
        return Button { flow.reviewAction(kind, item: item) } label: { Text(verbatim: localized(key)) }
        .buttonStyle(.bordered)
        .tint(kind == .reject ? Color.red : (kind == .accept ? Color.accentColor : Color.secondary))
        .disabled(!flow.canWrite)
        .accessibilityIdentifier("friend.\(kind.rawValue).\(item.peerID)")
    }
    private func stateKey(_ state: NativeFriendRelation) -> String {
        switch state { case .none: return "friend.none"; case .friend: return "friend.accepted"; case .pendingIncoming: return "friend.incomingState"; case .pendingOutgoing: return "friend.outgoingState" }
    }
    private func status(_ title: String, tint: Color, systemImage: String) -> some View {
        Label(title, systemImage: systemImage).foregroundStyle(tint)
    }
    private func relationTone(_ state: NativeFriendRelation) -> Color {
        switch state { case .friend: return .green; case .none: return .secondary; case .pendingIncoming, .pendingOutgoing: return .accentColor }
    }
    private func reviewTone(_ state: NativeFriendReviewState) -> Color {
        switch state {
        case .applied: return .green
        case .rejected, .cancelled, .expired, .invalidated: return .red
        case .pending: return .orange
        }
    }
}

/// Background/inactive while a friend destination is pushed: the covered home cannot see the change itself.
private struct NativeFriendDestinationSuspension: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    let suspend: () -> Void
    func body(content: Content) -> some View {
        content.onChange(of: scenePhase) { _, value in if value != .active { suspend() } }
    }
}
