import SwiftUI

/// Normal user entry, not an audit hub. Its injected service independently retains closed production grants.
@MainActor struct NativeFriendHomeView: View {
    @Environment(\.themeDomain) private var domain
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
            CYHeroHeader(verbatim: localized("friend.title")).listRowBackground(Color.clear).listRowSeparator(.hidden)
            if directoryFactory != nil || groupsFactory != nil || blacklistFactory != nil || removalFactory != nil {
                Section {
                    if let directoryFactory {
                        NavigationLink {
                            NativeFriendDirectoryView(flow: directoryFactory(), metadataFactory: metadataFactory,
                                removalFactory: removalFactory, publicProfile: publicProfile, progressCard: progressCard, conversation: conversation)
                        } label: { entryLabel(Text("friendDirectory.title", tableName: "NativeFriendDirectory"), systemImage: "person.crop.rectangle.stack") }
                            .accessibilityIdentifier("friendDirectory.entry")
                    }
                    if let groupsFactory {
                        Button { model.openGroups(using:groupsFactory) } label: { entryButtonLabel(Text("friendMeta.recoveryEntry", tableName: "NativeFriendMetadata"), systemImage: "folder") }
                            .accessibilityIdentifier("friendMeta.recoveryEntry")
                    }
                    if let blacklistFactory {
                        Button { model.openBlacklist(using: blacklistFactory) } label: { entryButtonLabel(Text("blacklist.title", tableName: "NativeBlacklist"), systemImage: "hand.raised") }
                            .accessibilityIdentifier("blacklist.entry")
                    }
                    if let removalFactory {
                        NavigationLink {
                            NativeFriendRemovalView(flow: removalFactory(nil), onResolved: { Task { await flow.load() } })
                        } label: { entryLabel(Text("friendRemoval.recoveryEntry", tableName: "NativeFriendRemoval"), systemImage: "person.badge.clock") }
                            .accessibilityIdentifier("friendRemoval.recoveryEntry")
                    }
                }
            }
            if flow.phase == .closed {
                Section { CYStatusChip(verbatim: localized("friend.closed"), tone: .neutral, systemImage: "lock") }.accessibilityIdentifier("friend.closed")
            }
            if flow.busy { ProgressView().frame(maxWidth: .infinity).accessibilityIdentifier("friend.loading") }
            if let issue = flow.issue {
                Section { CYStatusChip(verbatim: localized(issue), tone: .warning, systemImage: "exclamationmark.triangle") }
            }
            if flow.pending != nil {
                Section {
                    CYStatusChip(verbatim: localized("friend.unknown"), tone: .warning, systemImage: "questionmark.circle")
                    if !flow.isCurrent { CYStatusChip(verbatim: localized("friend.closed"), tone: .neutral, systemImage: "lock") }
                    CYPillButton(verbatim: localized("friend.recover")) { Task { await flow.recover() } }
                        .disabled(!flow.canRecover).accessibilityIdentifier("friend.recover")
                    CYPillButton(verbatim: localized("friend.retryOriginal"), style: .secondary) { Task { await flow.retryOriginal() } }
                        .disabled(!flow.canRetryOriginal).accessibilityIdentifier("friend.retryOriginal")
                }
            }
            if let relationship = flow.relationship {
                Section {
                    if let review = flow.lastReview { text("friend.review." + review.state.rawValue) }
                    else { text(stateKey(relationship.state)).accessibilityIdentifier("friend.relationship") }
                } header: { text("friend.result") }
            }
            if !flow.incoming.isEmpty {
                Section {
                    ForEach(flow.incoming) { item in
                        let responseLayout = dynamicTypeSize.isAccessibilitySize
                            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Theme.Space.s3))
                            : AnyLayout(HStackLayout(spacing: Theme.Space.s3))
                        VStack(alignment: .leading, spacing: Theme.Space.s2) {
                            row(item)
                            responseLayout {
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
                        HStack { row(item); Spacer(); action("friend.withdraw", .cancel, item) }
                    }
                    if flow.requestCursor != nil {
                        CYPillButton(verbatim: localized("friend.more"), style: .tertiary) { Task { await flow.loadMore(requests: true) } }.disabled(flow.busy)
                    }
                } header: { Text("d7.friends.sent \(flow.outgoing.count)", tableName: "NativeFriend") }
            }
            if !flow.reviews.isEmpty {
                Section {
                    ForEach(flow.reviews) { review in
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: Theme.Space.s1) {
                                Text(verbatim: review.message).fixedSize(horizontal: false, vertical: true)
                                text("friend.review." + review.state.rawValue).font(CYTypography.meta).foregroundStyle(CYColor.textTertiary)
                            }
                            Spacer()
                            if review.state == .pending {
                                CYPillButton(verbatim: localized("friend.withdraw"), style: .secondary, fullWidth: false) { flow.reviewCancellation(review) }
                                    .disabled(!flow.canWrite)
                            }
                        }.accessibilityIdentifier("friend.review.\(review.id)")
                    }
                    if flow.reviewCursor != nil { CYPillButton(verbatim: localized("friend.more"), style: .tertiary) { Task { await flow.loadMoreReviews() } }.disabled(flow.busy) }
                } header: { text("friend.review.title") }
            }
            if flow.phase == .ready && flow.friends.isEmpty {
                Section {
                    CYEmptyState(systemImage: "person.2", "friend.emptyFriends", tableName: "NativeFriend")
                    CYPillButton(verbatim: localized("friend.new")) { addingFriend = true }.disabled(!flow.canWrite)
                }
            } else if flow.groups.isEmpty {
                Section { friendRows(flow.friends) } header: { text("friend.friends") }
            } else {
                ForEach(flow.groups) { group in
                    let members = flow.friends.filter { group.isDefault == 1 ? $0.groupID == nil : $0.groupID == group.id }
                    if !members.isEmpty {
                        Section {
                            friendRows(members)
                        } header: {
                            if group.isDefault == 1 { text("friend.defaultGroup") } else { Text(verbatim:group.name) }
                        }
                    }
                }
            }
            if flow.friendCursor != nil {
                CYPillButton(verbatim: localized("friend.more"), style: .tertiary) { Task { await flow.loadMore(requests:false) } }.disabled(flow.busy)
            }
        }
        .listStyle(.insetGrouped)
        .font(Theme.Font.body)
        .cyGroupedSurface()
        .cyHeroScreen()
        .accessibilityIdentifier("friend.home")
        .task { await flow.load() }
        .refreshable { await flow.load() }
        .onDisappear { peer = ""; message = ""; flow.invalidate() }
        .onChange(of: scenePhase) { _, value in
            if value == .active { if model.child == nil { Task { await flow.load() } } }
            else { peer = ""; message = ""; addingFriend = false; model.suspend() }
        }
        .onChange(of: flow.isCurrent) { _, current in if !current { peer = ""; message = ""; addingFriend = false } }
        .toolbar {
            if flow.phase != .closed {
                ToolbarItem(placement: .primaryAction) {
                    Button { addingFriend = true } label: {
                        Label { text("friend.new") } icon: { Image(systemName: "person.badge.plus") }
                    }.accessibilityIdentifier("friend.add")
                }
            }
        }
        // The destination is not owned by a fetched row and survives its parent's onDisappear purge.
        .navigationDestination(isPresented: Binding(get: { model.child != nil }, set: { if !$0 { model.child = nil } })) {
            if let child = model.child {
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
            }
        }
        // The request is reviewed only after this sheet closes, so the confirmation sheet never stacks on it.
        .sheet(isPresented: $addingFriend, onDismiss: {
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
                            .accessibilityIdentifier("friend.message")
                    }
                }
                .formStyle(.grouped)
                .cyGroupedSurface()
                .navigationTitle(localized("friend.new"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button {
                            guard let id = Int64(peer) else { return }
                            queuedPeer = id; addingFriend = false
                        } label: { text("friend.apply") }
                            .disabled(!canSendRequest)
                            .accessibilityIdentifier("friend.apply")
                    }
                }
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: Binding(get: { flow.actionReview != nil }, set: { if !$0 { flow.cancelReview() } })) {
            if let review = flow.actionReview {
                NavigationStack {
                    Form {
                        Section {
                            if review.displayName.isEmpty {
                                LabeledContent { Text(verbatim: String(review.command.peerID)) } label: { text("friend.peer") }
                                    .accessibilityIdentifier("friend.confirmPeer")
                            } else {
                                Text(verbatim: review.displayName).font(Theme.Font.sectionTitle).accessibilityIdentifier("friend.confirmPeer")
                            }
                            if !review.message.isEmpty {
                                Text(verbatim: review.message).accessibilityIdentifier("friend.confirmMessage")
                            }
                        }
                    }
                    .formStyle(.grouped)
                    .font(Theme.Font.body)
                    .cyGroupedSurface()
                    .navigationTitle(localized("friend.confirm." + review.command.action.rawValue))
                    .navigationBarTitleDisplayMode(.inline)
                    .accessibilityIdentifier("friend.confirmation")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button { flow.cancelReview() } label: { text("friend.confirmCancel") }
                                .accessibilityIdentifier("friend.confirmCancel")
                        }
                    }
                    .questifyBottomAction {
                        Button { Task { await flow.confirmReview(expected: review) } } label: { text("friend.confirmContinue") }
                            .disabled(!flow.canWrite).accessibilityIdentifier("friend.confirmContinue")
                    }
                }
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            }
        }
        .tint(Theme.Color.accent(in: domain))
    }
    private func localized(_ key: String) -> String {
        String(localized: LocalizedStringResource(String.LocalizationValue(stringLiteral: key), table: "NativeFriend", locale: locale))
    }
    private func text(_ key: String) -> Text { Text(LocalizedStringKey(key), tableName: "NativeFriend") }
    @ViewBuilder private func friendRows(_ items: [NativeFriendItem]) -> some View {
        ForEach(items) { item in
            HStack(spacing: Theme.Space.s3) {
                Button { Task { await model.openConversation(item) } } label: {
                    HStack { row(item); Spacer(minLength: 0) }.frame(minHeight: 44).contentShape(Rectangle())
                }
                    .buttonStyle(.borderless).foregroundStyle(.primary)
                    .disabled(flow.busy).accessibilityIdentifier("friend.chat.\(item.peerID)")
                if let metadataFactory {
                    Button { model.openMetadata(item,using:metadataFactory) } label: {
                        Image(systemName: "info.circle").accessibilityLabel(Text("friendMeta.title",tableName:"NativeFriendMetadata"))
                    }
                        .buttonStyle(.borderless)
                        .disabled(flow.busy).accessibilityIdentifier("friendMeta.entry.\(item.peerID)")
                }
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                if let removalFactory {
                    Button { model.openRemoval(item,using:removalFactory) } label: {
                        Label { Text("friendRemoval.title",tableName:"NativeFriendRemoval") } icon: { Image(systemName: "person.badge.minus") }
                    }
                        .tint(.red)
                        .disabled(flow.busy).accessibilityIdentifier("friendRemoval.entry.\(item.peerID)")
                }
            }
        }
    }
    private func row(_ item: NativeFriendItem) -> some View {
        HStack(spacing: Theme.Space.s3) {
            E3Avatar(seed: item.displayName.isEmpty ? String(item.peerID) : item.displayName, size: 40).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Theme.Space.s1) {
                HStack(spacing: Theme.Space.s1) {
                    Text(verbatim: item.displayName.isEmpty ? "—" : item.displayName).font(CYTypography.cardTitle).foregroundStyle(CYColor.textPrimary).fixedSize(horizontal: false, vertical: true)
                    if item.starred == 1 { Image(systemName: "star.fill").font(Theme.Font.label).foregroundStyle(CYColor.warningText).accessibilityLabel(Text("friendMeta.starred", tableName: "NativeFriendMetadata")) }
                }
                if item.state != .friend && !item.message.isEmpty { Text(verbatim: item.message).font(CYTypography.meta).fixedSize(horizontal: false, vertical: true).foregroundStyle(CYColor.textTertiary) }
            }
        }.accessibilityIdentifier("friend.row.\(item.peerID)")
    }
    private func entryLabel(_ title: Text, systemImage: String) -> some View {
        HStack(spacing: CYSpacing.md) {
            CYRowIcon(systemImage: systemImage)
            title.font(CYTypography.cardTitle).foregroundStyle(CYColor.textPrimary)
        }.frame(minHeight: CYSpacing.minTouchTarget)
    }
    private func entryButtonLabel(_ title: Text, systemImage: String) -> some View {
        HStack {
            CYRowIcon(systemImage: systemImage)
            title.font(CYTypography.cardTitle).foregroundStyle(CYColor.textPrimary)
            Spacer()
            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(CYColor.textTertiary).accessibilityHidden(true)
        }
    }
    private func action(_ key: String, _ action: NativeFriendAction, _ item: NativeFriendItem) -> some View {
        CYPillButton(verbatim: localized(key), style: .secondary, fullWidth: false) { flow.reviewAction(action, item: item) }
            .disabled(!flow.canWrite)
            .accessibilityIdentifier("friend.\(action.rawValue).\(item.peerID)")
    }
    private func stateKey(_ state: NativeFriendRelation) -> String {
        switch state { case .none: return "friend.none"; case .friend: return "friend.accepted"; case .pendingIncoming: return "friend.incomingState"; case .pendingOutgoing: return "friend.outgoingState" }
    }
}
