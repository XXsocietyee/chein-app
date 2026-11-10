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
    init(reader: any CooperationReading, onClose: (() -> Void)? = nil, peerReader: (any CoopFlowReading)? = nil,
         operationScope: String? = nil, initialDirection: CooperationDirection = .received,
         topicDestination: ((Int) -> AnyView)? = nil) {
        self.reader = reader; self.onClose = onClose; self.peerReader = peerReader; self.operationScope = operationScope
        self.topicDestination = topicDestination
        _direction = State(initialValue: initialDirection)
    }
    @State private var topicFilter: CooperationInboxTopicFilter?
    private var selectedTopicID: Int? {
        guard reader.isConfigured, reader.isAuthenticated else { return nil }
        return topicFilter?.selectedTopic(owner: ObjectIdentifier(reader), scope: reader.scope)
    }
    var body: some View {
        NavigationStack {
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
                    } label: { Label("cooperation.pool.title", systemImage: "rectangle.stack") }
                        .accessibilityIdentifier("cooperation.pool.open")
                    if let peerReader, listPage.showsNewInvite {
                        NavigationLink { CoopFlowNewInvitationView(reader: peerReader, operationScope: operationScope) } label: {
                            Label("cooperation.list.newInvite", systemImage: "plus.circle")
                        }.accessibilityIdentifier("cooperation.list.newInvite")
                    }
                }
                topicFilterSection(snapshot)
                if let peerReader { CoopChapterApplicationSection(reader: peerReader, direction: direction, operationScope: operationScope) }
                if snapshot.isPartial {
                    Label("cooperation.partial", systemImage: "exclamationmark.triangle").font(CYTypography.meta).foregroundStyle(CYColor.warningText)
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
            .appNavigationTitle("cooperation.title")
            .onChange(of: reader.scope) { _, _ in topicFilter = nil }
            .onChange(of: ObjectIdentifier(reader)) { _, _ in topicFilter = nil }
            .onChange(of: reader.isAuthenticated) { _, _ in topicFilter = nil }
            .toolbar { if let onClose { ToolbarItem(placement:.cancellationAction) { Button("action.close",action:onClose) } } }
        }
        .id(CooperationProjectNavigationHost(scope: reader.scope, authenticated: reader.isAuthenticated, reader: ObjectIdentifier(reader)))
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
                    .fixedSize(horizontal: false, vertical: true)
                Text("cooperation.topicFilter.loadedOnly").font(CYTypography.meta).foregroundStyle(CYColor.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                if selected != nil {
                    Button("cooperation.topicFilter.clear") {
                        guard ObjectIdentifier(reader) == owner, reader.scope == scope else { return }
                        topicFilter = nil
                    }.accessibilityIdentifier("cooperation.topicFilter.clear")
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
                if rows.isEmpty { Text(selectedTopicID == nil ? "cooperation.invitations.empty" : "cooperation.topicFilter.empty").font(CYTypography.body).foregroundStyle(CYColor.textTertiary) }
                // Ordinal identities preserve duplicate server IDs without merging unrelated entries.
                ForEach(rows, id: \.offset) { index, row in
                    NavigationLink {
                        CooperationInviteDetailView(key: CooperationInviteKey(id: row.id, direction: direction), reader: reader, peerReader: peerReader)
                            .environment(\.cooperationProjectDestination, topicDestination)
                    } label: {
                        // Mini `.inv`: row 1 status badge + peer ("来自/发给 X"), row 2 title/sub, row 3 terms, then meta.
                        VStack(alignment: .leading, spacing: CYSpacing.md) {
                            HStack(alignment: .center, spacing: CYSpacing.sm) {
                                CooperationStatus(key: row.statusKey, symbol: row.status == 0 ? "clock" : row.status == 1 ? "checkmark.circle" : row.status == 2 ? "xmark.circle" : "circle")
                                Spacer(minLength: CYSpacing.sm)
                                HStack(spacing: CYSpacing.xs) {
                                    Text(LocalizedStringKey(direction == .received ? "cooperation.detail.from" : "cooperation.detail.to"))
                                    CooperationName(name: row.partner?.name).lineLimit(1).truncationMode(.tail)
                                }.font(CYTypography.label).foregroundStyle(CYColor.textTertiary)
                            }
                            CooperationInviteCardDetails(view: CooperationInvitePresentation(invite: row, direction: direction))
                            // One compact meta line (topic · created) instead of two tall inset rows.
                            let created: String? = row.createTime.flatMap { time -> String? in
                                switch time {
                                case .text(let text): return text
                                case .milliseconds: return time.date?.formatted(.dateTime.year().month().day().hour().minute().locale(locale))
                                }
                            }
                            let meta = [row.topicId.map { "#\($0)" }, created].compactMap { $0 }.joined(separator: " · ")
                            if !meta.isEmpty { Text(verbatim: meta).font(CYTypography.meta).foregroundStyle(CYColor.textTertiary).monospacedDigit() }
                        }.padding(.vertical, CYSpacing.xs)
                        .opacity((row.status ?? 0) >= 3 ? 0.6 : 1)
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
                if visible.isEmpty { Text(selectedTopicID == nil ? "cooperation.applications.empty" : "cooperation.topicFilter.empty").foregroundStyle(.secondary) }
                ForEach(visible, id: \.offset) { _, row in
                    VStack(alignment: .leading, spacing: CYSpacing.md) {
                        let replied = direction == .received ? CooperationRepliedApplication(application: row, sent: sentInvites) : nil
                        // Mini `.inv-top` then `.inv-title`: badge first, topic title second.
                        CooperationStatus(key: replied?.statusKey ?? row.statusKey)
                        CooperationName(name: row.topicName, fallback: "cooperation.unnamedTopic").font(CYTypography.cardTitle).foregroundStyle(CYColor.textPrimary)
                        CooperationField(key: direction == .received ? "cooperation.fromClub" : "cooperation.toMerchant", value: direction == .received ? row.clubName : row.merchantNick)
                        CooperationTopicReference(id: row.topicId)
                        CooperationTimeField(key: "cooperation.start", value: row.startDate)
                        if let message = row.message, !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            CooperationField(key: "cooperation.message", value: message)
                        } else { Text("cooperation.application.intent").font(CYTypography.meta).foregroundStyle(CYColor.textTertiary) }
                        if direction == .received { CooperationCandidateLink(topicID: row.topicId, reader: reader) }
                        if let linked = replied?.linkedInviteID {
                            NavigationLink { CooperationInviteDetailView(key: CooperationInviteKey(id: linked, direction: .sent), reader: reader, peerReader: peerReader)
                                .environment(\.cooperationProjectDestination, topicDestination) } label: {
                                Text("cooperation.list.apply.viewCooperation")
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
                if visible.isEmpty { Text(selectedTopicID == nil ? "cooperation.registrations.empty" : "cooperation.topicFilter.empty").foregroundStyle(.secondary) }
                ForEach(visible, id: \.offset) { _, row in
                    VStack(alignment: .leading, spacing: CYSpacing.md) {
                        CooperationStatus(key: row.statusKey)
                        CooperationName(name: row.merchantName, fallback: "cooperation.unnamedMerchant").font(CYTypography.cardTitle).foregroundStyle(CYColor.textPrimary)
                        if let member = row.memberId { CooperationField(key: "cooperation.merchant", value: "#\(member)") }
                        CooperationField(key: "cooperation.topic", value: row.topicName)
                        CooperationField(key: "cooperation.location", value: row.addressName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? row.addressName : row.address)
                        CooperationField(key: "cooperation.about", value: row.merchantMeta)
                        if let topic = row.topicId {
                            CooperationTopicReference(id: topic)
                            CooperationCandidateLink(topicID: topic, reader: reader)
                        }
                    }.padding(.vertical, 4)
                }
                if page.hasMore == true {
                    Text("cooperation.registrations.more").font(CYTypography.meta).foregroundStyle(CYColor.textTertiary)
                        .accessibilityIdentifier("cooperation.registrations.more")
                }
            }
        }
    }
}
