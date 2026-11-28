import SwiftUI

@MainActor struct CooperationBrowserView: View {
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let reader: any CooperationReading
    var onClose:(()->Void)? = nil
    var peerReader: (any CoopFlowReading)? = nil
    /// Source `?scope=MERCHANT`; forwarded to the chapter owner leg and the new-invitation route.
    var operationScope: String? = nil
    /// Existing public topic screen. Nil keeps the topic reference and does not navigate.
    var topicDestination: ((Int) -> AnyView)? = nil
    @State private var direction: CooperationDirection
    /// MC8-30-1 (coop/list index.js:163-172): `?topicId=` seeds the 只看「X」的协作 filter once the inbox loads.
    private let initialTopicID: Int?
    @State private var seededInitialTopic = false
    /// Parity coop/list P1: false when pushed onto an existing stack (no nested NavigationStack / double bar).
    private let embedsNavigationStack: Bool
    init(reader: any CooperationReading, onClose: (() -> Void)? = nil, peerReader: (any CoopFlowReading)? = nil,
         operationScope: String? = nil, initialDirection: CooperationDirection = .received,
         topicDestination: ((Int) -> AnyView)? = nil, embedsNavigationStack: Bool = true, initialTopicID: Int? = nil) {
        self.initialTopicID = initialTopicID
        self.reader = reader; self.onClose = onClose; self.peerReader = peerReader; self.operationScope = operationScope
        self.topicDestination = topicDestination; self.embedsNavigationStack = embedsNavigationStack
        _direction = State(initialValue: initialDirection)
    }
    @State private var topicFilter: CooperationInboxTopicFilter?
    /// Parity coop/list P0: the row's two-button `inv-acts` open the reviewed submit page (X1) as a sheet.
    @State private var rowAction: CoopListRowAction?
    @State private var composingInvite = false
    /// MP coop/list wxml:84-87 `.inv-acts`: a pending received card answers in place (拒绝 / 接受合作) through the
    /// same reviewed handle editor as the detail page.
    @State private var listHandle: CoopListHandle?
    /// MC8-30-4 / MC8-30-5: 回邀约 / 发邀约 open the new-invitation page with the recipient and topic fixed.
    @State private var invitePreset: CoopListInvitePreset?
    @Environment(\.cooperationTopicNearbyDestination) private var topicNearbyDestination
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
                    }.cyAdaptiveSegmented().accessibilityIdentifier("cooperation.direction")
                    NavigationLink {
                        CooperationPoolView(reader: reader)
                            .cyPushedChrome(domain: .merchant)
                    } label: {
                        CYListRow("cooperation.pool.title", trailing: .none) { CYRowIcon(systemImage: "rectangle.stack") }
                    }
                    .accessibilityIdentifier("cooperation.pool.open")
                    // MP coop/list wxml:178,262: 去发起邀请 is only the empty state's action (no standing row).
                }
                topicFilterSection(snapshot)
                    .onAppear { seedInitialTopic(snapshot) }
                if let peerReader {
                    CoopChapterApplicationSection(reader: peerReader, direction: direction, operationScope: operationScope,
                                                  topicDestination: topicDestination)
                }
                if snapshot.isPartial {
                    Label("cooperation.partial", systemImage: "exclamationmark.triangle")
                        .cyText(.meta)
                        .foregroundStyle(CYColor.warningText)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("cooperation.partial")
                }
                if inboxAllEmpty(snapshot) {
                    // MC8-30-11 (wxml:178,262): one empty state for the whole box instead of one per section.
                    Section {
                        CYEmptyState(systemImage: "tray", direction == .received ? "merchantCoop.list.allEmpty.received" : "merchantCoop.list.allEmpty.sent",
                                     actionTitle: peerReader != nil && listPage.showsNewInvite ? "merchantCoop.list.allEmpty.compose" : nil,
                                     actionIdentifier: "cooperation.list.allEmpty.compose",
                                     action: { composingInvite = true })
                            .listRowBackground(Color.clear)
                            .accessibilityIdentifier("cooperation.list.allEmpty")
                    }
                } else {
                invitationSection(snapshot.invitations, direction: snapshot.direction)
                    .accessibilityValue(Text(verbatim: listPage.invitationCountText))
                applicationSection(snapshot.applications, direction: snapshot.direction, sentInvites: { () -> [CooperationInvite] in if case .content(let list) = snapshot.invitations { return list.sent }; return [] }())
                    .accessibilityValue(Text(verbatim: listPage.applicationCountText))
                if let registrations = snapshot.registrations { registrationSection(registrations) }
                }
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
            .environment(\.cooperationListIssues, true)
            .cyDomainScreen(.merchant)
            .onChange(of: reader.scope) { _, _ in topicFilter = nil }
            .onChange(of: ObjectIdentifier(reader)) { _, _ in topicFilter = nil }
            .onChange(of: reader.isAuthenticated) { _, _ in topicFilter = nil }
            .toolbar { if let onClose { ToolbarItem(placement:.cancellationAction) { Button("action.close",action:onClose) } } }
            .navigationDestination(isPresented: Binding(get: { invitePreset != nil }, set: { if !$0 { invitePreset = nil } })) {
                if let peerReader, let invitePreset {
                    CoopFlowNewInvitationView(reader: peerReader, operationScope: operationScope,
                                              lockedTarget: invitePreset.target, initialTopicID: invitePreset.topicID)
                        .cyPushedChrome(domain: .merchant)
                        .environment(\.coopInviteSent, { direction = .sent; self.invitePreset = nil })
                }
            }
            .navigationDestination(isPresented: $composingInvite) {
                if let peerReader {
                    CoopFlowNewInvitationView(reader: peerReader, operationScope: operationScope)
                        .cyPushedChrome(domain: .merchant)
                        .environment(\.coopInviteSent, { direction = .sent; composingInvite = false })
                }
            }
            .navigationDestination(item: $listHandle) { item in
                CoopFlowHandleEditor(inviteID: item.inviteID, action: item.action, currentStatus: 0,
                                     supplyStationID: item.stationID, supplyStationName: item.stationName,
                                     flowReader: item.stationID == nil ? nil : peerReader)
                    .cyPushedChrome(domain: .merchant)
            }
            .cySheet(item: $rowAction) { action in
                Group {
                    NavigationStack { CoopFlowRequestPreview(operation: action.operation) }
                }
                .presentationDetents([.large]).presentationDragIndicator(.visible)
            }
    }
    /// MC8-30-11: every inbox section loaded and empty, with no topic filter. Failures keep their own sections.
    private func inboxAllEmpty(_ inbox: CooperationInbox) -> Bool {
        guard selectedTopicID == nil, case .content(let invites) = inbox.invitations, invites.rows(inbox.direction).isEmpty,
              case .content(let applications) = inbox.applications, applications.isEmpty else { return false }
        guard let registrations = inbox.registrations else { return true }
        if case .content(let page) = registrations { return page.rows.isEmpty }
        return false
    }
    /// Applies the deep-link topic once, only when that topic is among the loaded inbox's options.
    private func seedInitialTopic(_ inbox: CooperationInbox) {
        guard !seededInitialTopic, let initialTopicID, topicFilter == nil,
              reader.isConfigured, reader.isAuthenticated else { return }
        seededInitialTopic = true
        topicFilter = CooperationInboxTopicFilter(topicID: initialTopicID, inbox: inbox, owner: ObjectIdentifier(reader), scope: reader.scope)
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
                        if let name = option.name { Text(verbatim: name).tag(option.id) }
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
    /// One row at standard sizes; at accessibility sizes the same views stack leading (same order), so status chips and
    /// the 拒绝 / 接受合作 pair never squeeze or clip (a11y-dt r3).
    private func axStack<Content: View>(alignment: VerticalAlignment, @ViewBuilder content: () -> Content) -> some View {
        let layout: AnyLayout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: CYSpacing.sm))
            : AnyLayout(HStackLayout(alignment: alignment, spacing: CYSpacing.sm))
        return layout { content() }
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
                        inviteDetail(row, direction: direction)
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
                                    // AX sizes (a11y-dt r3): status above "From X" instead of both squeezed into one line.
                                    axStack(alignment: .center) {
                                        CooperationStatus(key: row.statusKey, symbol: row.status == 0 ? "clock" : row.status == 1 ? "checkmark.circle" : row.status == 2 ? "xmark.circle" : "circle")
                                        if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: CYSpacing.sm) }
                                        HStack(spacing: CYSpacing.xs) {
                                            Text(LocalizedStringKey(direction == .received ? "cooperation.detail.from" : "cooperation.detail.to"))
                                            CooperationName(name: row.partner?.name).lineLimit(2).truncationMode(.tail).fixedSize(horizontal: false, vertical: true)
                                        }.cyText(.label).foregroundStyle(CYColor.textTertiary)
                                    }
                                    CooperationInviteCardDetails(view: CooperationInvitePresentation(invite: row, direction: direction))
                                }
                            }
                            // One compact meta line (created time). MP cards never show the raw topic number.
                            let created: String? = row.createTime.flatMap { time -> String? in
                                switch time {
                                case .text(let text): return text
                                case .milliseconds: return time.date?.formatted(.dateTime.year().month().day().hour().minute().locale(locale))
                                }
                            }
                            let meta = created ?? ""
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
                    .contextMenu {
                        // MC7-30-5: MP `copyPartnerPhone` on a card whose contact is released. Local-only, expiring copy.
                        if case .visible = CooperationInvitePresentation(invite: row, direction: direction).contact,
                           let phone = row.partner?.phone?.trimmingCharacters(in: .whitespacesAndNewlines), !phone.isEmpty {
                            Button { LocalPasteboard.copy(phone) } label: { Label("merchantCoop.list.copyPhone", systemImage: "doc.on.doc") }
                                .accessibilityIdentifier("cooperation.invite.copyPhone.\(row.id)")
                        }
                    }
                    .accessibilityAction(named: Text("merchantCoop.list.copyPhone")) {
                        if case .visible = CooperationInvitePresentation(invite: row, direction: direction).contact,
                           let phone = row.partner?.phone?.trimmingCharacters(in: .whitespacesAndNewlines), !phone.isEmpty { LocalPasteboard.copy(phone) }
                    }
                    if direction == .received, case .decide = CooperationInvitePresentation(invite: row, direction: direction).footer {
                        // MP wxml:84-87: 拒绝 (secondary) then 接受合作 (the card's one solid action).
                        axStack(alignment: .center) {
                            Button("cooperation.detail.reject") { listHandle = CoopListHandle(row: row, action: .reject) }
                                .buttonStyle(.bordered)
                                .accessibilityIdentifier("cooperation.invite.received.reject.\(row.id).\(index)")
                            Button("cooperation.detail.accept") { listHandle = CoopListHandle(row: row, action: .accept) }
                                .buttonStyle(.borderedProminent)
                                .accessibilityIdentifier("cooperation.invite.received.accept.\(row.id).\(index)")
                        }
                        .controlSize(.regular)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    if direction == .received, row.status == 1, !row.legacyReadonly {
                        // MP wxml:92-95: an accepted received card offers 查看合作 (secondary) under the card.
                        NavigationLink {
                            inviteDetail(row, direction: direction)
                        } label: {
                            Text("mpr3.coop.list.viewCooperation")
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .accessibilityIdentifier("cooperation.invite.received.view.\(row.id).\(index)")
                    }
                    if direction == .sent, case .withdraw = CooperationInvitePresentation(invite: row, direction: direction).footer {
                        // MP wxml:222-224: a pending sent card offers 撤回邀约 (secondary only).
                        Button("cooperation.detail.withdraw") { listHandle = CoopListHandle(row: row, action: .cancel) }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .accessibilityIdentifier("cooperation.invite.sent.withdraw.\(row.id).\(index)")
                    }
                    // MC8-30-6 (wxml:225-227 `goInviteOthers`): a declined sent invite offers 再邀别人 → 找商家 for that topic.
                    if direction == .sent, row.status == 2, !row.legacyReadonly, let topic = row.topicId, topic > 0, let topicNearbyDestination {
                        NavigationLink {
                            topicNearbyDestination(CoopNearbyTopicContext(topicID: topic, topicName: row.topicName ?? ""))
                        } label: {
                            Label("merchantCoop.list.inviteOthers", systemImage: "person.badge.plus")
                                .frame(minHeight: CYSpacing.minTouchTarget)
                        }
                        .accessibilityIdentifier("cooperation.invite.inviteOthers.\(row.id).\(index)")
                    }
                }
            }
        }
    }
    /// One destination for the card and its 查看合作 button (MP `goInviteDetail` with the current box).
    private func inviteDetail(_ row: CooperationInvite, direction: CooperationDirection) -> some View {
        CooperationInviteDetailView(key: CooperationInviteKey(id: row.id, direction: direction), reader: reader, peerReader: peerReader)
            .environment(\.cooperationProjectDestination, topicDestination)
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
                                // MC8-30-4 (wxml:117-123 `replyApplyInvite`): 回邀约 = a formal invite with terms to that club.
                                if let club = row.clubId, club > 0 {
                                    CYPillButton("merchantCoop.list.apply.replyInvite") {
                                        invitePreset = .init(target: CoopInviteLockedTarget(type: CoopFlowTargetKind.club.rawValue, toID: club, name: row.clubName ?? ""),
                                                             topicID: row.topicId)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                    .buttonStyle(.borderless)
                                    .accessibilityIdentifier("cooperation.list.apply.replyInvite.\(row.applyId)")
                                }
                            } else {
                                CoopListRowActions(secondary: ("cooperation.list.apply.withdraw", .withdraw(topicID: row.topicId)),
                                                   primary: nil, identifier: "cooperation.list.withdraw.\(row.topicId)") { rowAction = .init(operation: $0) }
                            }
                        }
                        // MC7-30-12 (MP coop/list wxml:257-259): the club answered this application with an invite (status 3),
                        // which lands in 收到的 — one tap switches the segment there.
                        if direction == .sent, row.status == 3 {
                            Button { self.direction = .received } label: {
                                Text("merchantCoop.list.apply.goReceived").frame(minHeight: CYSpacing.minTouchTarget)
                            }
                            .buttonStyle(.bordered)
                            .accessibilityLabel(Text("merchantCoop.list.apply.goReceived.a11y"))
                            .accessibilityIdentifier("cooperation.list.apply.goReceived.\(row.topicId)")
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
                            CoopListRowActions(secondary: ("cooperation.list.registration.reject", .reject(registrationID: row.id, scope: operationScope)),
                                               primary: ("cooperation.list.registration.confirm", .confirm(registrationID: row.id, scope: operationScope)),
                                               identifier: "cooperation.list.registration.\(row.id)") { rowAction = .init(operation: $0) }
                        }
                        // MC8-30-5 (wxml:145-151 `goTermsInvite`): a confirmed registration can get its invite with terms,
                        // merchant target locked. The MP also hides it once an invite exists (`inviteState`, not decoded yet).
                        if peerReader != nil, row.auditStatus == 1, let member = row.memberId, member > 0, let topic = row.topicId, topic > 0 {
                            CYPillButton("merchantCoop.list.registration.invite") {
                                invitePreset = .init(target: CoopInviteLockedTarget(type: CoopFlowTargetKind.merchant.rawValue, toID: member, name: row.merchantName ?? ""),
                                                     topicID: topic)
                            }
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .buttonStyle(.borderless)
                            .accessibilityIdentifier("cooperation.list.registration.invite.\(row.id)")
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

/// Image parity: the MP has no default cover art here. A missing or failed cover is the plain `.inv-cover`
/// box (`--cy-bg-card-2`), not generated art.
struct CoopCoverPlaceholder: View {
    var body: some View { Rectangle().fill(CYColor.bgRaised) }
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
                        else { CoopCoverPlaceholder() }
                    }
                } else {
                    CoopCoverPlaceholder()
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
                    else { CoopCoverPlaceholder() }
                }
            } else {
                CoopCoverPlaceholder()
            }
        }
        .frame(width: side, height: side)
        .clipShape(RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous))
        .accessibilityHidden(true)
    }
}

struct CoopListHandle: Hashable {
    let inviteID: Int
    let action: CoopFlowHandle
    let stationID: Int?
    let stationName: String?
    init(row: CooperationInvite, action: CoopFlowHandle) {
        inviteID = row.id; self.action = action
        stationID = action == .accept ? row.supplyStationId : nil
        stationName = action == .accept && row.supplyStationId != nil ? row.supplyStationName : nil
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
