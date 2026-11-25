import SwiftUI

@MainActor struct CooperationBrowserView: View {
    @Environment(\.locale) private var locale
    let reader: any CooperationReading
    var onClose:(()->Void)? = nil
    var peerReader: (any CoopFlowReading)? = nil
    /// Source `?scope=MERCHANT`; forwarded to the chapter owner leg and the new-invitation route.
    var operationScope: String? = nil
    /// Existing public topic screen. Nil keeps the topic reference and does not navigate.
    var topicDestination: ((Int) -> AnyView)? = nil
    @State private var direction: CooperationDirection
    /// Parity coop/list P1: false when pushed onto an existing stack (no nested NavigationStack / double bar).
    private let embedsNavigationStack: Bool
    init(reader: any CooperationReading, onClose: (() -> Void)? = nil, peerReader: (any CoopFlowReading)? = nil,
         operationScope: String? = nil, initialDirection: CooperationDirection = .received,
         topicDestination: ((Int) -> AnyView)? = nil, embedsNavigationStack: Bool = true) {
        self.reader = reader; self.onClose = onClose; self.peerReader = peerReader; self.operationScope = operationScope
        self.topicDestination = topicDestination; self.embedsNavigationStack = embedsNavigationStack
        _direction = State(initialValue: initialDirection)
    }
    @State private var topicFilter: CooperationInboxTopicFilter?
    /// Parity coop/list P0: the row's two-button `inv-acts` open the reviewed submit page (X1) as a sheet.
    @State private var rowAction: CoopListRowAction?
    @State private var composingInvite = false
    private var selectedTopicID: Int? {
        guard reader.isConfigured, reader.isAuthenticated else { return nil }
        return topicFilter?.selectedTopic(owner: ObjectIdentifier(reader), scope: reader.scope)
    }
    var body: some View {
        Group {
            if embedsNavigationStack { NavigationStack { page } } else { page }
        }
        .id(CooperationProjectNavigationHost(scope: reader.scope, authenticated: reader.isAuthenticated, reader: ObjectIdentifier(reader)))
    }
    private var page: some View {
            CooperationReadScreen(reader: reader, resource: "inbox.\(direction.rawValue)", operation: { try await reader.inbox(direction: direction) }) { snapshot in
                let listPage = CoopListPageCoordinator.project(direction: direction, canRead: reader.isConfigured && reader.isAuthenticated,
                                                               inbox: .success(snapshot), canComposeInvite: peerReader != nil, canReadFlowLegs: peerReader != nil)
                Section {
                    Picker("cooperation.direction", selection: $direction) {
                        Text("cooperation.received").tag(CooperationDirection.received)
                        Text("cooperation.sent").tag(CooperationDirection.sent)
                    }.pickerStyle(.segmented).accessibilityIdentifier("cooperation.direction")
                    NavigationLink {
                        CooperationPoolView(reader: reader)
                            .cyPushedChrome(domain: .merchant)
                    } label: {
                        CYListRow("cooperation.pool.title", trailing: .none) { CYRowIcon(systemImage: "rectangle.stack") }
                    }
                    .accessibilityIdentifier("cooperation.pool.open")
                    if let peerReader, listPage.showsNewInvite {
                        // flows-g2 108: programmatic push so a sent invite can pop back here on 我发出的 (MP redirectTo ?tab=sent).
                        Button { composingInvite = true } label: {
                            CYListRow("cooperation.list.newInvite", trailing: .chevron) { CYRowIcon(systemImage: "plus.circle") }
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("cooperation.list.newInvite")
                    }
                }
                topicFilterSection(snapshot)
                if let peerReader { CoopChapterApplicationSection(reader: peerReader, direction: direction, operationScope: operationScope) }
                if snapshot.isPartial {
                    Label("cooperation.partial", systemImage: "exclamationmark.triangle")
                        .cyText(.meta)
                        .foregroundStyle(CYColor.warningText)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("cooperation.partial")
                }
                invitationSection(snapshot.invitations, direction: snapshot.direction)
                    .accessibilityValue(Text(verbatim: listPage.invitationCountText))
                applicationSection(snapshot.applications, direction: snapshot.direction, sentInvites: { () -> [CooperationInvite] in if case .content(let list) = snapshot.invitations { return list.sent }; return [] }())
                    .accessibilityValue(Text(verbatim: listPage.applicationCountText))
                if let registrations = snapshot.registrations { registrationSection(registrations) }
                if direction == .received, let peerReader { CoopOfficialInviteSection(reader: peerReader) }
                Section { CooperationReadOnlyNotice() }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                CYHeroHeader("cooperation.title")
                    .padding(.horizontal, CYSpacing.pageHorizontal)
                    .padding(.top, CYSpacing.sm)
                    .padding(.bottom, CYSpacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(CYColor.bgPage)
            }
            .cyHeroScreen()
            .cyDomainScreen(.merchant)
            .onChange(of: reader.scope) { _, _ in topicFilter = nil }
            .onChange(of: ObjectIdentifier(reader)) { _, _ in topicFilter = nil }
            .onChange(of: reader.isAuthenticated) { _, _ in topicFilter = nil }
            .toolbar { if let onClose { ToolbarItem(placement:.cancellationAction) { Button("action.close",action:onClose) } } }
            .navigationDestination(isPresented: $composingInvite) {
                if let peerReader {
                    CoopFlowNewInvitationView(reader: peerReader, operationScope: operationScope)
                        .cyPushedChrome(domain: .merchant)
                        .environment(\.coopInviteSent, { direction = .sent; composingInvite = false })
                }
            }
            .sheet(item: $rowAction) { action in
                Group {
                    NavigationStack { CoopFlowRequestPreview(operation: action.operation) }
                }
                .presentationDetents([.large]).presentationDragIndicator(.visible)
            }
    }
    @ViewBuilder private func topicFilterSection(_ inbox: CooperationInbox) -> some View {
        let owner = ObjectIdentifier(reader)
        let scope = reader.scope
        let selected = selectedTopicID
        let options = CooperationInboxTopicFilter.options(in: inbox)
        if !options.isEmpty || selected != nil {
            Section("cooperation.topicFilter.title") {
                Picker("cooperation.topicFilter.choose", selection: Binding(
                    get: { selectedTopicID ?? 0 },
                    set: { id in
                        guard reader.isConfigured, reader.isAuthenticated,
                              ObjectIdentifier(reader) == owner, reader.scope == scope else { return }
                        if id == 0 { topicFilter = nil }
                        else if let next = CooperationInboxTopicFilter(topicID: id, inbox: inbox, owner: owner, scope: scope) { topicFilter = next }
                    })) {
                    Text("cooperation.topicFilter.all").tag(0)
                    ForEach(options) { option in
                        if let name = option.name { Text(verbatim: name + " #" + String(option.id)).tag(option.id) }
                        else { Text(verbatim: "#" + String(option.id)).tag(option.id) }
                    }
                    if let selected, !options.contains(where: { $0.id == selected }) {
                        Text(verbatim: "#" + String(selected)).tag(selected)
                    }
                }.pickerStyle(.menu).accessibilityIdentifier("cooperation.topicFilter.choose")
                    .frame(minHeight: CYSpacing.minTouchTarget)
                    .fixedSize(horizontal: false, vertical: true)
                Text("cooperation.topicFilter.loadedOnly").cyText(.meta).foregroundStyle(CYColor.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                if selected != nil {
                    Button("cooperation.topicFilter.clear") {
                        guard ObjectIdentifier(reader) == owner, reader.scope == scope else { return }
                        topicFilter = nil
                    }
                    .frame(minHeight: CYSpacing.minTouchTarget)
                    .accessibilityIdentifier("cooperation.topicFilter.clear")
                }
            }
        }
    }
    @ViewBuilder private func invitationSection(_ state: CooperationSection<CooperationInvites>, direction: CooperationDirection) -> some View {
        Section("cooperation.invitations") {
            switch state {
            case .failure(let issue): CooperationIssueView(issue: issue)
            case .content(let list):
                let rows = CooperationInboxTopicFilter.visibleRows(list.rows(direction), topicID: selectedTopicID, topic: { $0.topicId })
                if rows.isEmpty {
                    CYEmptyState(systemImage: "tray", selectedTopicID == nil ? "cooperation.invitations.empty" : "cooperation.topicFilter.empty")
                        .listRowBackground(Color.clear)
                }
                // Ordinal identities preserve duplicate server IDs without merging unrelated entries.
                ForEach(rows, id: \.offset) { index, row in
                    NavigationLink {
                        CooperationInviteDetailView(key: CooperationInviteKey(id: row.id, direction: direction), reader: reader, peerReader: peerReader)
                            .environment(\.cooperationProjectDestination, topicDestination)
                    } label: {
                        // Mini `.inv`: row 1 status badge + peer ("来自/发给 X"), row 2 title/sub, row 3 terms, then meta.
                        VStack(alignment: .leading, spacing: CYSpacing.md) {
                            if index == 0 {
                                CoopCloudCoverBanner(url: TemplateBrowserPort.coverURL(row.coverURL), seed: coopCoverSeed(row.topicName, fallback: "invite-\(row.id)"))
                                    .accessibilityHidden(true)
                            }
                            HStack(alignment: .top, spacing: CYSpacing.md) {
                                if index != 0 {
                                    CoopCloudCoverThumb(url: TemplateBrowserPort.coverURL(row.coverURL), seed: coopCoverSeed(row.topicName, fallback: "invite-\(row.id)"))
                                        .accessibilityHidden(true)
                                }
                                VStack(alignment: .leading, spacing: CYSpacing.sm) {
                                    HStack(alignment: .center, spacing: CYSpacing.sm) {
                                        CooperationStatus(key: row.statusKey, symbol: row.status == 0 ? "clock" : row.status == 1 ? "checkmark.circle" : row.status == 2 ? "xmark.circle" : "circle")
                                        Spacer(minLength: CYSpacing.sm)
                                        HStack(spacing: CYSpacing.xs) {
                                            Text(LocalizedStringKey(direction == .received ? "cooperation.detail.from" : "cooperation.detail.to"))
                                            CooperationName(name: row.partner?.name).lineLimit(2).truncationMode(.tail).fixedSize(horizontal: false, vertical: true)
                                        }.cyText(.label).foregroundStyle(CYColor.textTertiary)
                                    }
                                    CooperationInviteCardDetails(view: CooperationInvitePresentation(invite: row, direction: direction))
                                }
                            }
                            // One compact meta line (topic · created) instead of two tall inset rows.
                            let created: String? = row.createTime.flatMap { time -> String? in
                                switch time {
                                case .text(let text): return text
                                case .milliseconds: return time.date?.formatted(.dateTime.year().month().day().hour().minute().locale(locale))
                                }
                            }
                            let meta = [row.topicId.map { "#\($0)" }, created].compactMap { $0 }.joined(separator: " · ")
                            if !meta.isEmpty {
                                Text(verbatim: meta)
                                    .cyText(.meta)
                                    .foregroundStyle(CYColor.textTertiary)
                                    .monospacedDigit()
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }.padding(.vertical, CYSpacing.xs)
                        .opacity((row.status ?? 0) >= 3 ? 0.6 : 1)
                        .accessibilityElement(children: .combine)
                        .accessibilityAddTraits(.isButton)
                    }.accessibilityIdentifier("cooperation.invite.\(direction.rawValue).\(row.id).\(index)")
                }
            }
        }
    }
    @ViewBuilder private func applicationSection(_ state: CooperationSection<[CooperationApplication]>, direction: CooperationDirection, sentInvites: [CooperationInvite] = []) -> some View {
        Section("cooperation.applications") {
            switch state {
            case .failure(let issue): CooperationIssueView(issue: issue)
            case .content(let rows):
                let visible = CooperationInboxTopicFilter.visibleRows(rows, topicID: selectedTopicID, topic: { $0.topicId })
                if visible.isEmpty {
                    CYEmptyState(systemImage: "tray", selectedTopicID == nil ? "cooperation.applications.empty" : "cooperation.topicFilter.empty")
                        .listRowBackground(Color.clear)
                }
                ForEach(visible, id: \.offset) { _, row in
                    VStack(alignment: .leading, spacing: CYSpacing.md) {
                        let replied = direction == .received ? CooperationRepliedApplication(application: row, sent: sentInvites) : nil
                        // Mini `.inv-top` then `.inv-title`: badge first, topic title second.
                        HStack(alignment: .top, spacing: CYSpacing.md) {
                            CYRowIcon(systemImage: "person.2")
                            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                                CooperationStatus(key: replied?.statusKey ?? row.statusKey)
                                CooperationName(name: row.topicName, fallback: "cooperation.unnamedTopic")
                                    .cyText(.cardTitle)
                                    .foregroundStyle(CYColor.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityAddTraits(.isStaticText)
                        CooperationField(key: direction == .received ? "cooperation.fromClub" : "cooperation.toMerchant", value: direction == .received ? row.clubName : row.merchantNick)
                        CooperationTopicReference(id: row.topicId)
                        CooperationTimeField(key: "cooperation.start", value: row.startDate)
                        if let message = row.message, !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            CooperationField(key: "cooperation.message", value: message)
                        } else { Text("cooperation.application.intent").cyText(.meta).foregroundStyle(CYColor.textTertiary) }
                        if direction == .received { CooperationCandidateLink(topicID: row.topicId, reader: reader) }
                        // MP inv-acts: received + pending → 拒绝 (pool/decline); sent + pending → 撤回申请 (pool/withdraw).
                        if peerReader != nil, row.status == 0 {
                            if direction == .received {
                                CoopListRowActions(secondary: ("cooperation.list.apply.decline", .decline(applyID: row.applyId, scope: row.scope)),
                                                   primary: nil, identifier: "cooperation.list.apply.\(row.applyId)") { rowAction = .init(operation: $0) }
                            } else {
                                CoopListRowActions(secondary: ("cooperation.list.apply.withdraw", .withdraw(topicID: row.topicId)),
                                                   primary: nil, identifier: "cooperation.list.withdraw.\(row.topicId)") { rowAction = .init(operation: $0) }
                            }
                        }
                        if let linked = replied?.linkedInviteID {
                            NavigationLink { CooperationInviteDetailView(key: CooperationInviteKey(id: linked, direction: .sent), reader: reader, peerReader: peerReader)
                                .environment(\.cooperationProjectDestination, topicDestination) } label: {
                                CYListRow("cooperation.list.apply.viewCooperation", trailing: .none) { CYRowIcon(systemImage: "arrow.right.circle") }
                            }.accessibilityIdentifier("cooperation.list.apply.linked.\(linked)")
                        }
                    }.padding(.vertical, CYSpacing.xs)
                }
            }
        }
    }
    @ViewBuilder private func registrationSection(_ state: CooperationSection<CooperationRegistrations>) -> some View {
        Section("cooperation.registrations") {
            switch state {
            case .failure(let issue): CooperationIssueView(issue: issue)
            case .content(let page):
                let visible = CooperationInboxTopicFilter.visibleRows(page.rows, topicID: selectedTopicID, topic: { $0.topicId })
                if visible.isEmpty {
                    CYEmptyState(systemImage: "bag", selectedTopicID == nil ? "cooperation.registrations.empty" : "cooperation.topicFilter.empty")
                        .listRowBackground(Color.clear)
                }
                ForEach(visible, id: \.offset) { _, row in
                    VStack(alignment: .leading, spacing: CYSpacing.md) {
                        HStack(alignment: .top, spacing: CYSpacing.md) {
                            CYRowIcon(systemImage: "bag")
                            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                                CooperationStatus(key: row.statusKey)
                                CooperationName(name: row.merchantName, fallback: "cooperation.unnamedMerchant")
                                    .cyText(.cardTitle)
                                    .foregroundStyle(CYColor.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityAddTraits(.isStaticText)
                        if let member = row.memberId { CooperationField(key: "cooperation.merchant", value: "#\(member)") }
                        CooperationField(key: "cooperation.topic", value: row.topicName)
                        CooperationField(key: "cooperation.location", value: row.addressName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? row.addressName : row.address)
                        CooperationField(key: "cooperation.about", value: row.merchantMeta)
                        if let topic = row.topicId {
                            CooperationTopicReference(id: topic)
                            CooperationCandidateLink(topicID: topic, reader: reader)
                        }
                        // MP inv-acts: a pending registration (audit 0) → 确认占槽 (candidates/confirm), 婉拒 secondary.
                        if peerReader != nil, row.auditStatus == 0 {
                            CoopListRowActions(secondary: ("cooperation.list.registration.reject", .reject(registrationID: row.id)),
                                               primary: ("cooperation.list.registration.confirm", .confirm(registrationID: row.id)),
                                               identifier: "cooperation.list.registration.\(row.id)") { rowAction = .init(operation: $0) }
                        }
                    }.padding(.vertical, CYSpacing.xs)
                }
                if page.hasMore == true {
                    Text("cooperation.registrations.more").cyText(.meta).foregroundStyle(CYColor.textTertiary)
                        .accessibilityIdentifier("cooperation.registrations.more")
                }
            }
        }
    }
}

func coopCoverSeed(_ name: String?, fallback: String) -> String {
    if let name = name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty { return name }
    return fallback
}

struct CoopCloudCoverBanner: View {
    let url: URL?
    let seed: String
    var body: some View {
        Color.clear
            .aspectRatio(16.0 / 10.0, contentMode: .fit)
            .overlay {
                if let url {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image { image.resizable().scaledToFill() }
                        else { CYCoverArt(seed: seed) }
                    }
                } else {
                    CYCoverArt(seed: seed)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous))
            .accessibilityHidden(true)
    }
}

struct CoopCloudCoverThumb: View {
    let url: URL?
    let seed: String
    @ScaledMetric(relativeTo: .body) private var side: CGFloat = 56
    var body: some View {
        Group {
            if let url {
                AsyncImage(url: url) { phase in
                    if let image = phase.image { image.resizable().scaledToFill() }
                    else { CYCoverArt(seed: seed) }
                }
            } else {
                CYCoverArt(seed: seed)
            }
        }
        .frame(width: side, height: side)
        .clipShape(RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous))
        .accessibilityHidden(true)
    }
}

struct CoopListRowAction: Identifiable {
    let id = UUID()
    let operation: CoopFlowMutation
}

/// Source coop/list `.inv-acts`: at most one secondary and one primary per card (MR-35).
struct CoopListRowActions: View {
    let secondary: (LocalizedStringKey, CoopFlowMutation)?
    let primary: (LocalizedStringKey, CoopFlowMutation)?
    let identifier: String
    let open: (CoopFlowMutation) -> Void
    var body: some View {
        HStack(spacing: CYSpacing.sm) {
            if let secondary {
                CYPillButton(secondary.0, style: .secondary) { open(secondary.1) }
                    .accessibilityIdentifier(identifier + ".secondary")
            }
            if let primary {
                CYPillButton(primary.0) { open(primary.1) }
                    .accessibilityIdentifier(identifier + ".primary")
            }
        }
        .buttonStyle(.borderless)
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
}
