import SwiftUI

private func ncmText(_ key: String) -> Text { Text(LocalizedStringKey(key), tableName: "NativeChannelManagement") }

/// Looks up a NativeChannelManagement string in the view's locale (String(localized:) alone ignores it).
private func ncmString(_ key: String, locale: Locale) -> String {
    ncmString(key, locale: locale, table: "NativeChannelManagement")
}

private func ncmString(_ key: String, locale: Locale, table: String) -> String {
    String(localized: LocalizedStringResource(String.LocalizationValue(key), table: table, locale: locale))
}

private func ncmHeader(_ key: String) -> some View {
    Text(LocalizedStringKey(key), tableName: "NativeChannelManagement")
}

private func ncmServerHeader(_ name: String) -> some View {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    return Text(verbatim: trimmed.isEmpty ? "—" : trimmed)
}

/// Settings-style row label. `chevron` is for rows that are Buttons driving a push or sheet (NavigationLink adds its own).
@ViewBuilder
private func ncmPageRow(_ key: String, systemImage: String, locale: Locale, table: String = "NativeChannelManagement", chevron: Bool = false) -> some View {
    if chevron {
        LabeledContent {
            ncmChevron()
        } label: {
            Label { Text(verbatim: ncmString(key, locale: locale, table: table)).foregroundStyle(.primary) } icon: { Image(systemName: systemImage) }
        }
    } else {
        Label { Text(verbatim: ncmString(key, locale: locale, table: table)).foregroundStyle(.primary) } icon: { Image(systemName: systemImage) }
    }
}

private func ncmChevron() -> some View {
    Image(systemName: "chevron.right")
        .font(.footnote.weight(.semibold))
        .foregroundStyle(.tertiary)
        .accessibilityHidden(true)
}

private func ncmLoading() -> some View {
    ProgressView { Text("cy.state.loading") }
        .frame(maxWidth: .infinity)
}

/// Optional destinations reuse the host's existing message consumer and original 8's Webhook UI.
/// No conversation is synthesized from a channel id here. The host must provide a real mapping.
@MainActor struct NativeChannelManagementDestinations {
    var conversation: ((NativeChannelManagementChannel) -> AnyView)? = nil
    var contextConversation: ((any NativeChannelManagementIntegrationContextProviding, NativeChannelManagementID, Binding<Bool>) -> AnyView)? = nil
    var notifications: ((any NativeChannelManagementIntegrationContextProviding, NativeChannelManagementID) -> AnyView)? = nil
    var webhook: (@MainActor (NativeWebhookScope) throws -> NativeWebhookCoordinator)? = nil
    var progress: ((NativeChannelManagementID, any NativeChannelManagementIntegrationContextProviding) -> AnyView)? = nil
    var contextProgress: ((NativeChannelManagementID, any NativeChannelManagementIntegrationContextProviding, Binding<Bool>) -> AnyView)? = nil
    var progressPrivacy: ((any NativeChannelManagementIntegrationContextProviding, NativeChannelManagementID) -> AnyView)? = nil
    var audit: ((any NativeChannelManagementIntegrationContextProviding, NativeChannelManagementID) -> AnyView)? = nil
    var lifecycleAudit: ((any NativeChannelManagementIntegrationContextProviding, NativeChannelManagementID) -> AnyView)? = nil
    var personalState: ((any NativeChannelManagementIntegrationContextProviding, NativeChannelManagementID) -> AnyView)? = nil
    var roles: ((any NativeChannelManagementIntegrationContextProviding, NativeChannelManagementID) -> AnyView)? = nil
    var moderation: ((any NativeChannelManagementIntegrationContextProviding, NativeChannelManagementID) -> AnyView)? = nil
    var friendInvites: ((any NativeChannelManagementIntegrationContextProviding, NativeChannelManagementID) -> AnyView)? = nil
    var onboarding: ((NativeChannelManagementCoordinator, Binding<Bool>) -> AnyView)? = nil
    var welcome: ((NativeChannelManagementCoordinator, Binding<Bool>) -> AnyView)? = nil
    var friendMembers: ((any NativeChannelManagementIntegrationContextProviding, NativeChannelManagementID) -> AnyView)? = nil
}

/// Space home: space name, channels grouped by category, then the space's own pages.
@MainActor struct NativeChannelManagementDirectoryView: View {
    let model: NativeChannelManagementCoordinator
    var destinations = NativeChannelManagementDestinations()
    var parentRouteIsActive: () -> Bool = { false }
    var spaceName: String? = nil
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.locale) private var locale
    @StateObject private var selection = NativeChannelManagementSelectionState<NativeChannelManagementID>()
    @StateObject private var onboardingRoute = NativeChannelManagementRouteState()
    @StateObject private var welcomeRoute = NativeChannelManagementRouteState()
    @State private var creates = false
    var body: some View {
        let onboardingVisit = childRoute(onboardingRoute)
        let welcomeVisit = childRoute(welcomeRoute)
        Group {
            if model.isCurrent {
                List {
                    spaceNameSection
                    if model.busy { ncmLoading() }
                    NativeChannelManagementIssueView(issue: model.issue)
                    NativeChannelManagementRecoveryView(model: model)
                    NativeChannelManagementOutcomeView(outcome: model.outcome)
                    if let directory = model.directory {
                        if directory.channels.isEmpty {
                            Section { ContentUnavailableView { Label { ncmText("empty") } icon: { Image(systemName: "number.square") } } }
                        }
                        if !directory.ungrouped.isEmpty {
                            Section { ForEach(directory.ungrouped) { row in channelRow(row) } }
                        }
                        ForEach(directory.groups) { group in
                            Section { ForEach(group.channels) { row in channelRow(row) } } header: { ncmServerHeader(group.category.name) }
                        }
                    } else if !model.busy {
                        Section {
                            ContentUnavailableView {
                                Label { ncmText("d7.channelManage.loadFailed") } icon: { Image(systemName: "exclamationmark.triangle") }
                            } actions: {
                                Button { Task { await model.loadDirectory() } } label: { ncmText("refresh") }
                                    .buttonStyle(.bordered)
                                    .accessibilityLabel(ncmText("refresh"))
                            }
                        }
                    }
                    if destinations.onboarding != nil || destinations.welcome != nil {
                        Section {
                            if let onboarding = destinations.onboarding {
                                NavigationLink(isActive: onboardingVisit) { onboarding(model, onboardingVisit).id(onboardingRoute.visitID) } label: {
                                    ncmPageRow("d7.channelManage.onboarding", systemImage: "list.bullet.clipboard", locale: locale)
                                }
                                .accessibilityLabel(ncmText("d7.channelManage.onboarding"))
                            }
                            if let welcome = destinations.welcome {
                                NavigationLink(isActive: welcomeVisit) { welcome(model, welcomeVisit).id(welcomeRoute.visitID) } label: {
                                    ncmPageRow("d7.channelManage.welcome", systemImage: "signpost.right", locale: locale)
                                }
                                .accessibilityLabel(ncmText("d7.channelManage.welcome"))
                            }
                        }
                    }
                    if model.managerInventoryConfirmed && model.managementInventory.contains(where: { $0.kind == 0 && $0.status < 2 }) {
                        Section { ForEach(model.managementInventory.filter { $0.kind == 0 && $0.status < 2 }) { row in
                            Button { selection.selected = row.id } label: {
                                LabeledContent {
                                    ncmChevron()
                                } label: {
                                    Label { Text(verbatim: row.name).foregroundStyle(.primary) } icon: { Image(systemName: "folder") }
                                }
                            }
                            .accessibilityLabel(Text(verbatim: shown(row.name)))
                        } } header: { ncmHeader("manageCategories") }
                    }
                    if !model.managementInventory.filter({ $0.status == 3 }).isEmpty {
                        Section { ForEach(model.managementInventory.filter { $0.status == 3 }) { row in
                            NavigationLink { NativeChannelManagementEditorView(model: model, channel: row) } label: {
                                Label {
                                    VStack(alignment: .leading) {
                                        Text(verbatim: row.name)
                                        Text(verbatim: ncmString("pendingDeletion", locale: locale)).font(.subheadline).foregroundStyle(.secondary)
                                    }
                                } icon: { Image(systemName: "clock.arrow.circlepath") }
                            }
                            .accessibilityLabel(Text(verbatim: "\(shown(row.name)), \(ncmString("pendingDeletion", locale: locale))"))
                        } } header: { ncmHeader("recoveryChannels") }
                    }
                }
                .listStyle(.insetGrouped)
                .cyText(.body)
                .refreshable { await model.loadDirectory() }
                .toolbar {
                    if model.canCreate {
                        ToolbarItem(placement: .primaryAction) {
                            Button { creates = true } label: { Label { ncmText("create") } icon: { Image(systemName: "plus") } }
                                .disabled(model.busy)
                                .accessibilityIdentifier("ncm.create")
                                .accessibilityLabel(ncmText("create"))
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Toggle(isOn: Binding(get: { model.showingOwnHidden }, set: { value in Task { await model.loadDirectory(showOwnHidden: value) } })) {
                                ncmText("d7.channelManage.showHidden")
                            }
                            .disabled(model.busy)
                        } label: { Label { ncmText("d7.channelManage.more") } icon: { Image(systemName: "ellipsis.circle") } }
                        .accessibilityLabel(ncmText("d7.channelManage.more"))
                    }
                }
            } else {
                NativeChannelManagementUnavailableView()
            }
        }
        .nativeChannelFlowPage()
        .navigationTitle(ncmText("directory"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: selection.binding) { id in
            let visit = selection.route(for: id, parentCurrent: parentRouteIsActive)
            let owner = model
            NativeChannelManagementDetailView(model: owner, channelID: id, destinations: destinations,
                parentRouteIsActive: { [weak owner] in visit.wrappedValue && owner?.isCurrent == true })
                .id(selection.visitID)
        }
        .cySheet(isPresented: $creates) {
            NavigationStack { NativeChannelManagementEditorView(model: model, channel: nil) }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .task {
            // Receipt recovery does not depend on a successful current directory read.
            model.restoreOriginal()
            await model.loadDirectory()
        }
        .task {
            // Also retires a retained off-screen view after expiry, logout or configuration replacement.
            while !Task.isCancelled && !model.retired {
                model.synchronizeIdentity()
                do { try await Task.sleep(nanoseconds: 500_000_000) } catch { return }
            }
        }
        .onChange(of: scenePhase) { _, value in if value != .active { model.retire() } }
    }
    /// The space's own name, shown once at the top like a Settings header row.
    @ViewBuilder private var spaceNameSection: some View {
        if let spaceName {
            let trimmed = spaceName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                Section {
                    Label(trimmed, systemImage: "person.3")
                        .font(.headline)
                }
            }
        }
    }
    private func childRoute(_ state: NativeChannelManagementRouteState) -> Binding<Bool> {
        let parent = parentRouteIsActive, owner = model
        return NativeChannelManagementRouteState.child(state.binding, parentCurrent: { [weak owner] in
            parent() && owner?.isCurrent == true
        })
    }
    private func channelRow(_ row: NativeChannelManagementChannel) -> some View {
        Button { selection.selected = row.id } label: {
            LabeledContent {
                ncmChevron()
            } label: {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: row.name).foregroundStyle(.primary)
                        if row.status == 1 || row.visibility == 2 {
                            HStack(spacing: 8) {
                                if row.status == 1 {
                                    Label(ncmString("d7.channelManage.archivedShort", locale: locale), systemImage: "archivebox")
                                }
                                if row.visibility == 2 {
                                    Label(ncmString("private", locale: locale), systemImage: "lock")
                                }
                            }
                            .labelStyle(.titleAndIcon)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        }
                    }
                } icon: { Image(systemName: row.kind == 2 ? "megaphone" : "number") }
            }
        }
        .accessibilityLabel(Text(verbatim: channelLabel(row)))
        .accessibilityIdentifier("ncm.channel.\(row.id)")
    }
    private func channelLabel(_ row: NativeChannelManagementChannel) -> String {
        var parts = [shown(row.name)]
        if row.status == 1 { parts.append(ncmString("d7.channelManage.archivedShort", locale: locale)) }
        if row.visibility == 2 { parts.append(ncmString("private", locale: locale)) }
        return parts.joined(separator: ", ")
    }
    private func shown(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "—" : trimmed
    }
}

/// Channel page: facts first, then the channel's pushed pages, each gated by the server permissions below.
@MainActor struct NativeChannelManagementDetailView: View {
    let model: NativeChannelManagementCoordinator
    let channelID: NativeChannelManagementID
    let destinations: NativeChannelManagementDestinations
    let parentRouteIsActive: () -> Bool
    @Environment(\.locale) private var locale
    @StateObject private var messagesRoute = NativeChannelManagementRouteState()
    @StateObject private var webhookRoute = NativeChannelManagementRouteState()
    private var messageRouteBinding: Binding<Bool> {
        NativeChannelManagementRouteState.child(messagesRoute.binding, parentCurrent: parentRouteIsActive)
    }
    private var webhookRouteBinding: Binding<Bool> {
        NativeChannelManagementRouteState.child(webhookRoute.binding, parentCurrent: parentRouteIsActive)
    }
    @StateObject private var progressRoute = NativeChannelManagementRouteState()
    private var progressRouteBinding: Binding<Bool> {
        let owner = model, parent = parentRouteIsActive
        return NativeChannelManagementRouteState.child(progressRoute.binding, parentCurrent: { [weak owner] in
            parent() && owner?.isCurrent == true
        })
    }
    var body: some View {
        let messageVisit = messageRouteBinding
        let webhookVisit = webhookRouteBinding
        let progressVisit = progressRouteBinding
        Group {
            if model.isCurrent {
                Form {
                    if model.busy { ncmLoading() }
                    NativeChannelManagementIssueView(issue: model.issue)
                    NativeChannelManagementRecoveryView(model: model)
                    NativeChannelManagementOutcomeView(outcome: model.outcome)
                    if let row = model.detail, row.id == channelID {
                        Section {
                            if let topic = row.topic, !topic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text(verbatim: topic)
                                    .fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
                            }
                            statusFact(row)
                            LabeledContent { Text(verbatim: ncmString(row.visibility == 2 ? "private" : "public", locale: locale)) } label: { ncmText("visibility") }
                            slowmodeFact(row)
                            LabeledContent { Text(verbatim: memberValue(row)) } label: { ncmText("members") }
                        }
                        // Chat and channel activity.
                        Section {
                            if row.kind != 0, let conversation = destinations.contextConversation {
                                NavigationLink(isActive: messageVisit) { conversation(model.service, row.id, messageVisit).id(messagesRoute.visitID) } label: {
                                    ncmPageRow("messages", systemImage: "bubble.left.and.bubble.right", locale: locale)
                                }
                                .accessibilityLabel(ncmText("messages"))
                            } else if let conversation = destinations.conversation, row.kind != 0 {
                                NavigationLink { conversation(row) } label: {
                                    ncmPageRow("messages", systemImage: "bubble.left.and.bubble.right", locale: locale)
                                }
                                .accessibilityLabel(ncmText("messages"))
                            }
                            if row.kind != 0, row.scope.guildKind == 1, (destinations.contextProgress != nil || destinations.progress != nil) {
                                Button { progressVisit.wrappedValue = true } label: {
                                    ncmPageRow("title", systemImage: "chart.bar", locale: locale, table: "NativeChannelProgress", chevron: true)
                                }
                                .accessibilityIdentifier("ncm.progressEntry")
                                .accessibilityLabel(Text(verbatim: ncmString("title", locale: locale, table: "NativeChannelProgress")))
                            }
                        }
                        // People and safety.
                        Section {
                            if row.kind != 0, row.status == 0, row.permissionNames.contains("VIEW_CHANNEL"), let friends = destinations.friendMembers {
                                NavigationLink { friends(model.service, row.id) } label: {
                                    ncmPageRow("d7.channelManage.members", systemImage: "person.2", locale: locale)
                                }
                                .accessibilityLabel(ncmText("d7.channelManage.members"))
                            }
                            if row.scope.guildKind == 1, row.permissionNames.contains("MANAGE_ROLE"), let roles = destinations.roles {
                                NavigationLink { roles(model.service, row.id) } label: {
                                    ncmPageRow("d7.channelManage.roles", systemImage: "person.badge.key", locale: locale)
                                }
                                .accessibilityIdentifier("ncm.originalRoleEntry")
                                .accessibilityLabel(ncmText("d7.channelManage.roles"))
                            }
                            if row.scope.guildKind == 1, !row.permissionNames.isDisjoint(with: ["VIEW_AUDIT", "TIMEOUT_MEMBER", "KICK_MEMBER", "BAN_MEMBER"]),
                               let moderation = destinations.moderation {
                                NavigationLink { moderation(model.service, row.id) } label: {
                                    ncmPageRow("d7.channelManage.moderation", systemImage: "hand.raised", locale: locale)
                                }
                                .accessibilityIdentifier("ncm.originalModerationEntry")
                                .accessibilityLabel(ncmText("d7.channelManage.moderation"))
                            }
                            if row.scope.guildKind == 1, row.permissionNames.contains("VIEW_AUDIT"), let audit = destinations.audit {
                                NavigationLink { audit(model.service, row.id) } label: {
                                    ncmPageRow("d7.channelManage.auditLog", systemImage: "list.bullet.rectangle", locale: locale)
                                }
                                .accessibilityIdentifier("ncm.originalAuditEntry")
                                .accessibilityLabel(ncmText("d7.channelManage.auditLog"))
                            }
                            if row.scope.guildKind == 1, row.permissionNames.contains("VIEW_AUDIT"), let lifecycle = destinations.lifecycleAudit {
                                NavigationLink { lifecycle(model.service, row.id) } label: {
                                    ncmPageRow("d7.channelManage.history", systemImage: "clock.arrow.circlepath", locale: locale)
                                }
                                .accessibilityLabel(ncmText("d7.channelManage.history"))
                            }
                        }
                        // Your own settings and invites.
                        Section {
                            if let notifications = destinations.notifications {
                                NavigationLink { notifications(model.service, row.id) } label: {
                                    ncmPageRow("notification.channel.title", systemImage: "bell.badge", locale: locale, table: "NativeChannelNotification")
                                }
                                .accessibilityIdentifier("notification.channel.entry")
                                .accessibilityLabel(Text(verbatim: ncmString("notification.channel.title", locale: locale, table: "NativeChannelNotification")))
                            }
                            if let personalState = destinations.personalState {
                                NavigationLink { personalState(model.service, row.id) } label: {
                                    ncmPageRow("d7.channelManage.hideMute", systemImage: "eye.slash", locale: locale)
                                }
                                .accessibilityLabel(ncmText("d7.channelManage.hideMute"))
                            }
                            if row.kind != 0, row.status == 0, [1, 3].contains(row.scope.guildKind),
                               row.permissionNames.isSuperset(of: ["VIEW_CHANNEL", "MANAGE_CHANNEL"]), let invites = destinations.friendInvites {
                                NavigationLink { invites(model.service, row.id) } label: {
                                    ncmPageRow("d7.channelManage.invite", systemImage: "person.badge.plus", locale: locale)
                                }
                                .accessibilityLabel(ncmText("d7.channelManage.invite"))
                            }
                        }
                        // Channel administration.
                        Section {
                            if row.canManage {
                                NavigationLink { NativeChannelManagementEditorView(model: model, channel: row) } label: {
                                    ncmPageRow("settings", systemImage: "gearshape", locale: locale)
                                }
                                .accessibilityLabel(ncmText("settings"))
                            }
                            if row.canManagePermissions {
                                NavigationLink { NativeChannelManagementPermissionsView(model: model, channelID: row.id) } label: {
                                    ncmPageRow("permissions", systemImage: "lock.shield", locale: locale)
                                }
                                .accessibilityLabel(ncmText("permissions"))
                            }
                            if row.kind != 0, row.status == 0, row.scope.guildKind == 1,
                               row.permissionNames.isSuperset(of: ["VIEW_CHANNEL", "MANAGE_PROGRESS"]), let privacy = destinations.progressPrivacy {
                                NavigationLink { privacy(model.service, row.id) } label: {
                                    ncmPageRow("d7.channelManage.progressPrivacy", systemImage: "eye", locale: locale)
                                }
                                .accessibilityIdentifier("ncm.aggregatePrivacyEntry")
                                .accessibilityLabel(ncmText("d7.channelManage.progressPrivacy"))
                            }
                            if row.scope.guildKind == 1, row.permissionNames.isSuperset(of: ["VIEW_CHANNEL", "READ_HISTORY", "MANAGE_WEBHOOKS"]),
                               destinations.webhook != nil {
                                Button { webhookVisit.wrappedValue = true } label: {
                                    ncmPageRow("d7.channelManage.webhooks", systemImage: "point.3.connected.trianglepath.dotted", locale: locale, chevron: true)
                                }
                                .accessibilityIdentifier("ncm.webhookEntry")
                                .accessibilityLabel(ncmText("d7.channelManage.webhooks"))
                            }
                        }
                    } else if !model.busy {
                        Section {
                            ContentUnavailableView {
                                Label { ncmText("d7.channelManage.channelLoadFailed") } icon: { Image(systemName: "exclamationmark.triangle") }
                            } actions: {
                                Button { Task { await model.loadDetail(channelID) } } label: { ncmText("refresh") }
                                    .buttonStyle(.bordered)
                                    .accessibilityLabel(ncmText("refresh"))
                            }
                        }
                    }
                }
                .formStyle(.grouped)
                .cyText(.body)
                .refreshable { await model.loadDetail(channelID) }
            } else {
                NativeChannelManagementUnavailableView()
            }
        }
        .nativeChannelFlowPage()
        .navigationTitle(detailTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: channelID) { await model.loadDetail(channelID) }
        .cySheet(isPresented: progressVisit) {
            Group {
                if let progress = destinations.contextProgress {
                    progress(channelID, model.service, progressVisit).id(progressRoute.visitID)
                } else if let progress = destinations.progress { progress(channelID, model.service) }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .cySheet(isPresented: webhookVisit) {
            NativeChannelManagementWebhookEntry(channels: model.service, channelID: channelID, makeCoordinator: destinations.webhook,
                parentRouteIsActive: { webhookVisit.wrappedValue })
                .id(webhookRoute.visitID)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }
    private var detailTitle: Text {
        if model.detail?.id == channelID {
            return Text(verbatim: shown(model.detail?.name ?? ""))
        }
        return ncmText("detail")
    }
    private func statusFact(_ row: NativeChannelManagementChannel) -> some View {
        let key = row.status == 1 ? "d7.channelManage.archivedShort" : "active"
        return LabeledContent {
            Label {
                Text(verbatim: ncmString(key, locale: locale))
            } icon: {
                Image(systemName: row.status == 1 ? "archivebox" : "checkmark.circle.fill")
                    .foregroundStyle(row.status == 1 ? Color.orange : Color.green)
            }
        } label: { ncmText("status") }
        .accessibilityElement(children: .combine)
    }
    /// Zero slowmode is off. A missing value (-1 on inventory rows) is unknown, not zero.
    private func slowmodeFact(_ row: NativeChannelManagementChannel) -> some View {
        let value: String
        if row.slowmodeSeconds > 0 {
            value = Duration.seconds(row.slowmodeSeconds).formatted(.units(allowed: [.hours, .minutes, .seconds], width: .abbreviated))
        } else if row.slowmodeSeconds == 0 {
            value = ncmString("d7.channelManage.off", locale: locale)
        } else {
            value = "—"
        }
        return LabeledContent { Text(verbatim: value) } label: { ncmText("slowmode") }
    }
    /// Nil member count is unknown. A real 0 stays 0.
    private func memberValue(_ row: NativeChannelManagementChannel) -> String {
        guard let count = row.memberCount else { return "—" }
        return row.memberCountCapped ? "\(count)+" : "\(count)"
    }
    private func shown(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "—" : trimmed
    }
}

@MainActor struct NativeChannelManagementEditorView: View {
    let model: NativeChannelManagementCoordinator
    let channel: NativeChannelManagementChannel?
    @Environment(\.dismiss) private var dismiss
    @State private var draft: NativeChannelManagementDraft
    @State private var reason = ""
    @State private var localIssue: NativeChannelManagementError?
    @State private var reviews = false
    init(model: NativeChannelManagementCoordinator, channel: NativeChannelManagementChannel?) {
        self.model = model; self.channel = channel
        _draft = State(initialValue: channel.map(NativeChannelManagementDraft.init(channel:)) ?? .init())
    }
    var body: some View {
        Group {
            if model.isCurrent {
                Form {
                    if model.busy { ncmLoading() }
                    NativeChannelManagementIssueView(issue: localIssue ?? model.issue)
                    Section {
                        TextField(text: $draft.name, prompt: ncmText("name")) { ncmText("name") }
                        TextField(text: $draft.topic, prompt: ncmText("topic"), axis: .vertical) { ncmText("topic") }.lineLimit(3...6)
                        LabeledContent {
                            TextField(value: $draft.slowmodeSeconds, format: .number, prompt: Text(verbatim: "0")) { ncmText("d7.channelManage.slowmodeSeconds") }
                                .keyboardType(.numberPad).multilineTextAlignment(.trailing)
                                .cyText(.numericBody)
                        } label: { ncmText("d7.channelManage.slowmodeSeconds") }
                        Picker(selection: $draft.visibility) { ncmText("public").tag(1); ncmText("private").tag(2) } label: { ncmText("visibility") }
                        if channel == nil {
                            Picker(selection: $draft.kind) { ncmText("textChannel").tag(1); ncmText("announcement").tag(2); ncmText("category").tag(0) } label: { ncmText("kind") }
                            if draft.kind != 0 {
                                Picker(selection: $draft.parentID) {
                                    ncmText("ungrouped").tag("0")
                                    ForEach(model.managementInventory.filter { $0.kind == 0 && $0.status == 0 }) { Text($0.name).tag($0.id.rawValue) }
                                } label: { ncmText("category") }
                            }
                        }
                    }.disabled(channel.map({ $0.status != 0 }) ?? false)
                    if let channel, let purge = channel.purgeAt {
                        Section { LabeledContent { Text(verbatim: shown(purge)) } label: { ncmText("purgeAt") } }
                    }
                    Section { TextField(text: $reason, prompt: ncmText("reason"), axis: .vertical) { ncmText("reason") }.lineLimit(2...4) }
                    if channel == nil || channel?.status == 0 {
                        Section {
                            Button { prepareEdit() } label: { ncmText("review") }
                                .disabled(model.busy || model.pending != nil)
                                .accessibilityIdentifier("ncm.reviewEdit")
                                .accessibilityLabel(ncmText("review"))
                        }
                    }
                    if let channel {
                        // Lifecycle actions sit apart from saving; delete stays red.
                        Section {
                            if channel.status == 0 { action("archive", operation: .archive, channel: channel) }
                            if channel.status == 1 && channel.archiveReason == "manual" { action("unarchive", operation: .unarchive, channel: channel) }
                            if channel.status == 3 && channel.recoverable { action("restore", operation: .restore, channel: channel) }
                        }
                        if channel.canDelete {
                            Section { action("delete", operation: .delete, channel: channel, destructive: true) }
                        }
                    }
                }
                .formStyle(.grouped)
                .cyText(.body)
                .disabled(model.busy)
            } else {
                NativeChannelManagementUnavailableView()
            }
        }
        .nativeChannelFlowPage()
        .navigationTitle(ncmText(channel == nil ? "create" : "settings"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button { dismiss() } label: { ncmText("close") } } }
        .cySheet(isPresented: $reviews) {
            NavigationStack { NativeChannelManagementReviewView(model: model) }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .onChange(of: draft.kind) { _, kind in if kind == 0 { draft.parentID = "0" } }
    }
    private func shown(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "—" : trimmed
    }
    private func prepareEdit() {
        do {
            let intent: NativeChannelManagementIntent
            if let channel { intent = try .edit(channel: channel, draft: draft, reason: reason) }
            else { intent = try .create(scope: model.scope, draft: draft, reason: reason) }
            try model.prepare(intent); localIssue = nil; reviews = true
        } catch { localIssue = (error as? NativeChannelManagementError) ?? .invalidDraft }
    }
    @ViewBuilder private func action(_ key: String, operation: NativeChannelManagementIntent.Operation,
                        channel: NativeChannelManagementChannel, destructive: Bool = false) -> some View {
        if destructive {
            Button(role: .destructive) { prepareLifecycle(operation, channel: channel) } label: { ncmText(key) }
                .disabled(model.busy || model.pending != nil)
                .accessibilityLabel(ncmText(key))
        } else {
            Button { prepareLifecycle(operation, channel: channel) } label: { ncmText(key) }
                .disabled(model.busy || model.pending != nil)
                .accessibilityLabel(ncmText(key))
        }
    }
    private func prepareLifecycle(_ operation: NativeChannelManagementIntent.Operation, channel: NativeChannelManagementChannel) {
        do {
            let intent: NativeChannelManagementIntent
            if operation == .restore {
                guard let inventory = model.managementInventoryEvidence else { throw NativeChannelManagementError.forbidden }
                let current = try inventory.restorableChannel(channel.id)
                guard current.scope == channel.scope, current.version == channel.version else { throw NativeChannelManagementError.versionConflict }
                intent = try .restore(channelID: channel.id, inventory: inventory, reason: reason)
            } else { intent = try .lifecycle(operation, channel: channel, reason: reason) }
            try model.prepare(intent); localIssue = nil; reviews = true
        }
        catch { localIssue = (error as? NativeChannelManagementError) ?? .invalidDraft }
    }
}

/// Review sheet: what will change, then one confirm action.
@MainActor struct NativeChannelManagementReviewView: View {
    let model: NativeChannelManagementCoordinator
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    var body: some View {
        Form {
            NativeChannelManagementIssueView(issue: model.issue)
            if model.isCurrent, let intent = model.prepared {
                Section {
                    ncmText("operation.\(intent.operation.rawValue)").font(.headline)
                        .fixedSize(horizontal: false, vertical: true)
                    if let type = intent.targetType, let target = intent.targetID {
                        LabeledContent { Text(verbatim: type == 1 ? ncmString("everyone", locale: locale) : roleName(target)) } label: { ncmText("permissionTarget") }
                    }
                    ForEach(intent.fields.keys.sorted(), id: \.self) { key in
                        LabeledContent { Text(verbatim: display(intent.fields[key], key: key)) } label: { ncmText("field.\(key)") }
                    }
                    LabeledContent { Text(verbatim: shown(intent.reason)) } label: { ncmText("d7.channelManage.reasonLabel") }
                }
                if intent.isPermissionChange && !model.permissionWritesAvailable {
                    Section { ncmText("permissionSubmissionUnavailable").foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
                }
                Section {
                    if intent.operation == .delete {
                        Button(role: .destructive) {
                            Task { await model.submitPrepared(); if model.prepared == nil { dismiss() } }
                        } label: { ncmText("confirm") }
                        .disabled(!model.canSubmitPrepared)
                        .accessibilityIdentifier("ncm.confirmOriginal")
                        .accessibilityLabel(ncmText("confirm"))
                    } else {
                        Button {
                            Task { await model.submitPrepared(); if model.prepared == nil { dismiss() } }
                        } label: { ncmText("confirm") }
                        .disabled(!model.canSubmitPrepared)
                        .accessibilityIdentifier("ncm.confirmOriginal")
                        .accessibilityLabel(ncmText("confirm"))
                    }
                }
            } else {
                Section {
                    ContentUnavailableView { Label { ncmText("refreshRequired") } icon: { Image(systemName: "arrow.clockwise") } }
                }
            }
        }
        .formStyle(.grouped)
        .nativeChannelFlowPage()
        .navigationTitle(ncmText("review"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button { model.cancelPreparation(); dismiss() } label: { ncmText("cancel") } } }
        .interactiveDismissDisabled(model.busy)
        .onDisappear { if !model.busy { model.cancelPreparation() } }
    }
    /// Role overrides name the server's role; a missing name shows "—" rather than a raw number.
    private func roleName(_ id: String) -> String {
        model.roles.first { $0.id.rawValue == id }?.name ?? "—"
    }
    private func shown(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "—" : trimmed
    }
    private func display(_ value: NativeChannelManagementJSON?, key: String) -> String {
        if case .some(.integer(let number)) = value {
            if key == "visibility" { return ncmString(number == 2 ? "private" : "public", locale: locale) }
            if key == "kind" { return ncmString(number == 0 ? "category" : (number == 2 ? "announcement" : "textChannel"), locale: locale) }
            if key == "archived" { return ncmString(number == 1 ? "archive" : "unarchive", locale: locale) }
        }
        if case .some(.string(let text)) = value {
            if key == "parent_id" { return text == "0" ? ncmString("ungrouped", locale: locale) : (model.managementInventory.first { $0.id.rawValue == text }?.name ?? "—") }
            if (key == "allow_bits" || key == "deny_bits"), let bits = UInt64(text.dropFirst(2), radix: 16) {
                let names = NativeChannelManagementCapability.allCases.filter { bits & $0.bit != 0 }.map { ncmString("capability.\($0.rawValue)", locale: locale) }
                return names.isEmpty ? ncmString("none", locale: locale) : names.joined(separator: ", ")
            }
        }
        switch value { case .some(.string(let text)): return text; case .some(.integer(let n)): return String(n); case .some(.null): return ncmString("clearValue", locale: locale); case nil: return "—" }
    }
}

/// A change whose result is not yet confirmed: check it, or retry it when the server allows.
@MainActor struct NativeChannelManagementRecoveryView: View {
    let model: NativeChannelManagementCoordinator
    var body: some View {
        if model.isCurrent, model.pending != nil {
            Section {
                Label { ncmText("originalPending") } icon: { Image(systemName: "clock.arrow.circlepath").foregroundStyle(.orange) }
                Button { Task { await model.recoverOriginal() } } label: { ncmText("queryOriginal") }
                    .disabled(model.busy)
                    .accessibilityLabel(ncmText("queryOriginal"))
                if model.canResendOriginal {
                    Button { Task { await model.resendOriginal() } } label: { ncmText("retryOriginal") }
                        .disabled(model.busy)
                        .accessibilityLabel(ncmText("retryOriginal"))
                }
            }
        }
    }
}

@MainActor struct NativeChannelManagementOutcomeView: View {
    let outcome: NativeChannelManagementOriginalOutcome?
    var body: some View {
        if let outcome {
            Section {
                switch outcome {
                case .applied(let result):
                    note(ncmText("applied"), symbol: "checkmark.circle.fill", tint: .green)
                    if let name = result.name {
                        Text(verbatim: shown(name))
                            .font(.headline)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                case .appliedRedacted: note(ncmText("appliedRedacted"), symbol: "checkmark.circle.fill", tint: .green)
                case .pending: note(ncmText("originalPending"), symbol: "clock.arrow.circlepath", tint: .orange)
                case .notFound: note(ncmText("notFoundUnknown"), symbol: "questionmark.circle", tint: .secondary)
                }
            }
        }
    }
    private func note(_ text: Text, symbol: String, tint: Color) -> some View {
        Label { text } icon: { Image(systemName: symbol).foregroundStyle(tint) }
    }
    private func shown(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "—" : trimmed
    }
}

@MainActor struct NativeChannelManagementUnavailableView: View {
    var body: some View {
        ContentUnavailableView {
            Label { Text("unavailable", tableName: "NativeChannelManagement") } icon: { Image(systemName: "lock.shield") }
        } description: {
            Text("entryUnavailable", tableName: "NativeChannelManagement")
        }
    }
}

@MainActor struct NativeChannelManagementIssueView: View {
    let issue: NativeChannelManagementError?
    var body: some View {
        if let issue {
            Label { ncmText(key(issue)) } icon: { Image(systemName: "exclamationmark.circle").foregroundStyle(.orange) }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("ncm.issue")
        }
    }
    private func key(_ issue: NativeChannelManagementError) -> String {
        switch issue {
        case .unavailable, .forbidden: return "unavailable"
        case .changedIdentity: return "refreshRequired"
        case .invalidDraft: return "invalidDraft"
        case .versionConflict: return "versionConflict"
        case .pendingOriginal: return "originalPending"
        case .storageUnavailable: return "storageUnavailable"
        case .permissionCASUnavailable: return "permissionSubmissionUnavailable"
        case .invalidSource, .outcomeUnknown: return "outcomeUnknown"
        case .rejected(let code):
            switch code {
            case "CHANNEL_NAME_DUPLICATE", "CHANNEL_NAME_TAKEN_BY_RESTORE": return "duplicateName"
            case "CHANNEL_VERSION_CONFLICT": return "versionConflict"
            case "CHANNEL_UNDELETABLE", "CHANNEL_ARCHIVE_IMMUTABLE": return "protectedChannel"
            case "PERMISSION_DENIED", "CHANNEL_NOT_VISIBLE", "CHANNEL_ACCESS_DENIED", "GUILD_MEMBER_REQUIRED": return "unavailable"
            default: return "rejected"
            }
        }
    }
}
