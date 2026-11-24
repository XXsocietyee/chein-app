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
            Section {
                CYHeroHeader(verbatim: localized("friend.title")) {
                    CYCoverArt(seed: "friend-home", symbol: "person.2.fill", showsDebugLabel: false, cornerRadius: CYRadius.lg)
                        .frame(maxWidth: .infinity)
                        .frame(height: 120)
                        .accessibilityHidden(true)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
            if directoryFactory != nil || groupsFactory != nil || blacklistFactory != nil || removalFactory != nil {
                Section {
                    if let directoryFactory {
                        NavigationLink {
                            NativeFriendDirectoryView(flow: directoryFactory(), metadataFactory: metadataFactory,
                                removalFactory: removalFactory, publicProfile: publicProfile, progressCard: progressCard, conversation: conversation)
                        } label: {
                            CYListRow(verbatim: tableString("friendDirectory.title", table: "NativeFriendDirectory"), trailing: .none) {
                                CYRowIcon(systemImage: "person.crop.rectangle.stack")
                            }
                        }
                        .accessibilityIdentifier("friendDirectory.entry")
                    }
                    if let groupsFactory {
                        Button { model.openGroups(using:groupsFactory) } label: {
                            CYListRow(verbatim: tableString("friendMeta.recoveryEntry", table: "NativeFriendMetadata"), trailing: .chevron) {
                                CYRowIcon(systemImage: "folder")
                            }
                        }
                        .accessibilityIdentifier("friendMeta.recoveryEntry")
                    }
                    if let blacklistFactory {
                        Button { model.openBlacklist(using: blacklistFactory) } label: {
                            CYListRow(verbatim: tableString("blacklist.title", table: "NativeBlacklist"), trailing: .chevron) {
                                CYRowIcon(systemImage: "hand.raised")
                            }
                        }
                        .accessibilityIdentifier("blacklist.entry")
                    }
                    if let removalFactory {
                        NavigationLink {
                            NativeFriendRemovalView(flow: removalFactory(nil), onResolved: { Task { await flow.load() } })
                        } label: {
                            CYListRow(verbatim: tableString("friendRemoval.recoveryEntry", table: "NativeFriendRemoval"), trailing: .none) {
                                CYRowIcon(systemImage: "person.badge.clock")
                            }
                        }
                        .accessibilityIdentifier("friendRemoval.recoveryEntry")
                    }
                }
            }
            if flow.phase == .closed {
                Section { CYStatusChip(verbatim: localized("friend.closed"), tone: .neutral, systemImage: "lock") }
                    .accessibilityIdentifier("friend.closed")
            }
            if flow.busy {
                Section {
                    CYSkeleton()
                        .accessibilityIdentifier("friend.loading")
                        .accessibilityLabel(Text("cloud31.loading.friends"))
                }
            }
            if let issue = flow.issue {
                Section { CYEmptyState(systemImage: "exclamationmark.triangle", LocalizedStringKey(issue), tableName: "NativeFriend", kind: .failure) }
            }
            if flow.pending != nil {
                Section {
                    CYStatusChip(verbatim: localized("friend.unknown"), tone: .warning, systemImage: "questionmark.circle")
                    if !flow.isCurrent { CYStatusChip(verbatim: localized("friend.closed"), tone: .neutral, systemImage: "lock") }
                    CYPillButton(verbatim: localized("friend.recover"), style: .secondary, systemImage: "arrow.clockwise") { Task { await flow.recover() } }
                        .disabled(!flow.canRecover).accessibilityIdentifier("friend.recover")
                    CYPillButton(verbatim: localized("friend.retryOriginal"), style: .tertiary) { Task { await flow.retryOriginal() } }
                        .disabled(!flow.canRetryOriginal).accessibilityIdentifier("friend.retryOriginal")
                }
            }
            if let relationship = flow.relationship {
                Section {
                    if let review = flow.lastReview {
                        CYStatusChip(verbatim: localized("friend.review." + review.state.rawValue), tone: reviewTone(review.state), systemImage: "clock")
                    } else {
                        CYStatusChip(verbatim: localized(stateKey(relationship.state)), tone: relationTone(relationship.state), systemImage: "person")
                            .accessibilityIdentifier("friend.relationship")
                    }
                } header: { CYSectionHeader(LocalizedStringKey(localized("friend.result"))) }
            }
            if !flow.incoming.isEmpty {
                Section {
                    ForEach(flow.incoming) { item in
                        VStack(alignment: .leading, spacing: CYSpacing.md) {
                            row(item)
                            action("friend.accept", .accept, item)
                            action("friend.reject", .reject, item)
                        }
                    }
                } header: { Text("d7.friends.received \(flow.incoming.count)", tableName: "NativeFriend") }
            }
            if !flow.outgoing.isEmpty || flow.requestCursor != nil {
                Section {
                    ForEach(flow.outgoing) { item in
                        let stacked = dynamicTypeSize.isAccessibilitySize
                        let layout = stacked
                            ? AnyLayout(VStackLayout(alignment: .leading, spacing: CYSpacing.md))
                            : AnyLayout(HStackLayout(alignment: .center, spacing: CYSpacing.md))
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
                            ? AnyLayout(VStackLayout(alignment: .leading, spacing: CYSpacing.md))
                            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: CYSpacing.md))
                        layout {
                            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                                Text(verbatim: review.message)
                                    .cyText(.body)
                                    .foregroundStyle(CYColor.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                                CYStatusChip(verbatim: localized("friend.review." + review.state.rawValue), tone: reviewTone(review.state), systemImage: "clock")
                            }
                            if review.state == .pending {
                                CYPillButton(verbatim: localized("friend.withdraw"), style: .tertiary, fullWidth: stacked) {
                                    flow.reviewCancellation(review)
                                }
                                .disabled(!flow.canWrite)
                            }
                        }
                        .accessibilityIdentifier("friend.review.\(review.id)")
                    }
                    if flow.reviewCursor != nil { Button { Task { await flow.loadMoreReviews() } } label: { text("friend.more") }.disabled(flow.busy) }
                } header: { CYSectionHeader(LocalizedStringKey(localized("friend.review.title"))) }
            }
            if flow.phase == .ready && flow.friends.isEmpty {
                Section {
                    CYEmptyState(systemImage: "person.2", "friend.emptyFriends", tableName: "NativeFriend")
                    CYPillButton("friend.new", systemImage: "person.badge.plus", tableName: "NativeFriend") { addingFriend = true }
                        .disabled(!flow.canWrite)
                }
            } else if flow.groups.isEmpty {
                Section { friendRows(flow.friends) } header: { CYSectionHeader(LocalizedStringKey(localized("friend.friends"))) }
            } else {
                ForEach(flow.groups) { group in
                    let members = flow.friends.filter { group.isDefault == 1 ? $0.groupID == nil : $0.groupID == group.id }
                    if !members.isEmpty {
                        Section {
                            friendRows(members)
                        } header: {
                            if group.isDefault == 1 {
                                CYSectionHeader(LocalizedStringKey(localized("friend.defaultGroup")))
                            } else {
                                let name = group.name.trimmingCharacters(in: .whitespacesAndNewlines)
                                CYSectionHeader(LocalizedStringKey(name.isEmpty ? "—" : name))
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
        .cyText(.body)
        .cyGroupedSurface()
        .cyHeroScreen()
        .cyAnimation(value: flow.phase)
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
                        CYHeroHeader(verbatim: localized("friend.new"))
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets())
                    }
                    Section {
                        TextField(localized("friend.peer"), text: $peer).keyboardType(.numberPad)
                            .accessibilityIdentifier("friend.peer")
                        TextField(localized("friend.message"), text: $message, axis: .vertical)
                            .accessibilityIdentifier("friend.message")
                        CYPillButton(verbatim: localized("friend.apply"), systemImage: "paperplane.fill") {
                            guard let id = Int64(peer) else { return }
                            queuedPeer = id; addingFriend = false
                        }
                        .disabled(!canSendRequest)
                        .accessibilityIdentifier("friend.apply")
                    }
                }
                .formStyle(.grouped)
                .cyGroupedSurface()
                .cyHeroScreen()
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: Binding(get: { flow.actionReview != nil }, set: { if !$0 { flow.cancelReview() } })) {
            if let review = flow.actionReview {
                CYSheetContainer(
                    title: localized("friend.confirm." + review.command.action.rawValue),
                    onClose: { flow.cancelReview() }
                ) {
                    VStack(alignment: .leading, spacing: CYSpacing.md) {
                        VStack(alignment: .leading, spacing: CYSpacing.xs) {
                            if review.displayName.isEmpty {
                                CYListRow(verbatim: localized("friend.peer"), trailing: .value(String(review.command.peerID)))
                                    .accessibilityIdentifier("friend.confirmPeer")
                            } else {
                                Text(verbatim: review.displayName)
                                    .cyText(.cardTitle)
                                    .foregroundStyle(CYColor.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .accessibilityIdentifier("friend.confirmPeer")
                            }
                            if !review.message.isEmpty {
                                Text(verbatim: review.message)
                                    .cyText(.body)
                                    .foregroundStyle(CYColor.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .accessibilityIdentifier("friend.confirmMessage")
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(CYSpacing.md)
                        .background(CYColor.sheetCard, in: RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous))

                        Button {
                            Task { await flow.confirmReview(expected: review) }
                        } label: {
                            Label(localized("friend.confirmContinue"), systemImage: "checkmark.circle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(CYPrimaryButtonStyle(isFullWidth: true))
                        .disabled(!flow.canWrite)
                        .accessibilityIdentifier("friend.confirmContinue")

                        Button { flow.cancelReview() } label: {
                            text("friend.confirmCancel")
                        }
                        .buttonStyle(CYSecondaryButtonStyle(isFullWidth: true))
                        .accessibilityIdentifier("friend.confirmCancel")
                    }
                }
                .accessibilityIdentifier("friend.confirmation")
                .cyDomainSheet(detents: [.half, .full])
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
                    row(item).frame(minHeight: CYSpacing.minTouchTarget).contentShape(Rectangle())
                }
                    .buttonStyle(.borderless).foregroundStyle(.primary)
                    .disabled(flow.busy).accessibilityIdentifier("friend.chat.\(item.peerID)")
                if let metadataFactory {
                    Button { model.openMetadata(item,using:metadataFactory) } label: {
                        Image(systemName: "info.circle")
                            .frame(minWidth: CYSpacing.minTouchTarget, minHeight: CYSpacing.minTouchTarget)
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
        return CYListRow(verbatim: name.isEmpty ? "—" : name, meta: meta, trailing: .none) {
            HStack(spacing: CYSpacing.sm) {
                CYCoverArt(seed: name.isEmpty ? String(item.peerID) : name, symbol: "person.fill", showsDebugLabel: false, cornerRadius: CYRadius.lg)
                    .frame(width: 40, height: 40)
                    .accessibilityHidden(true)
                if item.starred == 1 {
                    Image(systemName: "star.fill")
                        .cyText(.caption)
                        .foregroundStyle(CYColor.warningText)
                        .accessibilityLabel(Text("friendMeta.starred", tableName: "NativeFriendMetadata"))
                }
            }
        }
        .accessibilityIdentifier("friend.row.\(item.peerID)")
    }
    private func action(_ key: String, _ kind: NativeFriendAction, _ item: NativeFriendItem) -> some View {
        let fills = dynamicTypeSize.isAccessibilitySize || kind == .accept || kind == .reject
        return CYPillButton(verbatim: localized(key), style: kind == .accept ? .secondary : .tertiary, fullWidth: fills) {
            flow.reviewAction(kind, item: item)
        }
        .disabled(!flow.canWrite)
        .accessibilityIdentifier("friend.\(kind.rawValue).\(item.peerID)")
    }
    private func stateKey(_ state: NativeFriendRelation) -> String {
        switch state { case .none: return "friend.none"; case .friend: return "friend.accepted"; case .pendingIncoming: return "friend.incomingState"; case .pendingOutgoing: return "friend.outgoingState" }
    }
    private func relationTone(_ state: NativeFriendRelation) -> CYStatusTone {
        switch state { case .friend: return .success; case .none: return .neutral; case .pendingIncoming, .pendingOutgoing: return .info }
    }
    private func reviewTone(_ state: NativeFriendReviewState) -> CYStatusTone {
        switch state {
        case .applied: return .success
        case .rejected, .cancelled, .expired, .invalidated: return .danger
        case .pending: return .warning
        }
    }
}
