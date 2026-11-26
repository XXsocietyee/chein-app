import SwiftUI

/// Mount hook for `ClubDetailView` (管理 tab) — `CLB-G04` (可对接的活动 + 我的合作) & `CLB-G03` (活动导演台).
public struct ClubGapCoopPoolSection: View {
    public let state: ClubCoopPoolLoadState
    public let pendingTopicID: Int?
    public let onRetry: () -> Void
    public let onApply: (_ topicID: Int, _ topicName: String, _ message: String) -> Void
    public let onOpenApplication: (_ applyID: Int) -> Void
    public let onOpenMyCoop: () -> Void

    @State private var applyingItem: ClubCoopPoolCardItem?
    @State private var applyMessage: String = ""

    public init(
        state: ClubCoopPoolLoadState,
        pendingTopicID: Int? = nil,
        onRetry: @escaping () -> Void,
        onApply: @escaping (_ topicID: Int, _ topicName: String, _ message: String) -> Void,
        onOpenApplication: @escaping (_ applyID: Int) -> Void,
        onOpenMyCoop: @escaping () -> Void
    ) {
        self.state = state
        self.pendingTopicID = pendingTopicID
        self.onRetry = onRetry
        self.onApply = onApply
        self.onOpenApplication = onOpenApplication
        self.onOpenMyCoop = onOpenMyCoop
    }

    public var body: some View {
        Section {
            Button(action: onOpenMyCoop) {
                HStack {
                    Text(verbatim: ClubCoopPoolCopy.myCoopTitle)
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
            }
            content
        } header: {
            Text(verbatim: ClubCoopPoolCopy.sectionTitle)
        }
        .cySheet(item: $applyingItem) { item in
            NavigationStack {
                Form {
                    Section {
                        TextField(ClubCoopPoolCopy.applyPlaceholder, text: $applyMessage, axis: .vertical)
                            .lineLimit(3...6)
                    }
                }
                .cyPageTitle(verbatim: ClubCoopPoolCopy.applyModalTitle(topicName: item.name))
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("common.cancel") { applyingItem = nil }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(ClubCoopPoolCopy.submitApply) {
                            let msg = applyMessage.trimmingCharacters(in: .whitespacesAndNewlines)
                            onApply(item.topicID, item.name, msg)
                            applyMessage = ""
                            applyingItem = nil
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .idle, .loading:
            ProgressView()
                .frame(maxWidth: .infinity)
        case .permission(let reason):
            ContentUnavailableView("club.coopPool.permissionTitle", systemImage: "lock", description: Text(verbatim: reason))
        case .error(let reason):
            // The former empty state took `onRetry` without an action title, so it drew no button; pull to refresh retries.
            ContentUnavailableView(ClubCoopPoolCopy.loadFailed, systemImage: "exclamationmark.triangle", description: Text(verbatim: reason))
        case .ready(let items):
            if items.isEmpty {
                ContentUnavailableView(ClubCoopPoolCopy.emptyTitle, systemImage: "tray")
            } else {
                ForEach(items) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(verbatim: item.name)
                                .font(.headline)
                            Spacer()
                            Text(verbatim: item.stateText)
                                .font(.subheadline)
                                .foregroundStyle(item.isTaken ? Color.secondary : Color.accentColor)
                        }
                        if let nick = item.merchantNick, !nick.isEmpty {
                            Text("club.coopPool.publishedBy \(nick)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        if let subtitle = item.subtitle, !subtitle.isEmpty {
                            Text(verbatim: subtitle)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        HStack {
                            if let deadline = item.deadlineText, !deadline.isEmpty {
                                Text(verbatim: deadline)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if item.canApply {
                                let isBusy = pendingTopicID == item.topicID
                                Button(isBusy ? ClubCoopPoolCopy.submittingButton : ClubCoopPoolCopy.applyButton) {
                                    applyMessage = ""
                                    applyingItem = item
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                                .disabled(isBusy)
                            } else if let applyID = item.applyID {
                                Button(ClubCoopPoolCopy.viewApplicationButton) {
                                    onOpenApplication(applyID)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                    }
                    .opacity(item.isTaken ? 0.65 : 1.0)
                }
            }
        }
    }
}

/// Mount hook for `ClubDetailView` (概览 tab) — `CLB-G08`: 4-avatar strip + "+N" overflow pill.
public struct ClubGapMemberAvatarStrip: View {
    public struct AvatarItem: Identifiable, Sendable {
        public let id: String
        public let name: String
        public let url: URL?
        /// CLB-r9-detail-01: the member to open; nil or 0 keeps the tap on 查看全部成员.
        public let memberID: Int?
        /// MP `buildMemberStrip`: 主理人 for the owner, 管理员 for role 1, else none.
        public let roleKey: String?

        public init(id: String, name: String, url: URL?, memberID: Int? = nil, roleKey: String? = nil) {
            self.id = id
            self.name = name
            self.url = url
            self.memberID = memberID
            self.roleKey = roleKey
        }
    }

    public let avatars: [AvatarItem]
    public let totalCount: Int
    public let onTapAll: () -> Void
    /// CLB-r9-detail-01 (MP detail wxml:266-277 `goMemberProfile`): nil sends every tap to 查看全部成员.
    public var onTapMember: ((Int) -> Void)? = nil

    public init(avatars: [AvatarItem], totalCount: Int, onTapAll: @escaping () -> Void) {
        self.avatars = avatars
        self.totalCount = totalCount
        self.onTapAll = onTapAll
    }

    /// CLB-r9-detail-01: the per-member tap.
    public func memberTap(_ action: ((Int) -> Void)?) -> Self {
        var copy = self
        copy.onTapMember = action
        return copy
    }

    /// MP `buildMemberStrip` (detail js:375-388): four members with name and role under each, then a 「+N」 slot.
    public var body: some View {
        HStack(alignment: .top) {
            ForEach(Array(avatars.prefix(4))) { item in
                Button {
                    if let memberID = item.memberID, memberID > 0, let onTapMember { onTapMember(memberID) } else { onTapAll() }
                } label: {
                    VStack {
                        CYAvatarView(url: item.url, name: item.name, size: .sm)
                        Text(verbatim: item.name.isEmpty ? "—" : item.name)
                            .font(.caption)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        if let roleKey = item.roleKey {
                            Text(LocalizedStringKey(roleKey))
                                .font(.caption)
                                .foregroundStyle(.tint)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderless)
                .accessibilityIdentifier("club.detail.memberStrip.\(item.id)")
            }
            let overflow = max(0, totalCount - min(avatars.count, 4))
            if overflow > 0 {
                Button(action: onTapAll) {
                    VStack {
                        Image(systemName: "person.3")
                            .imageScale(.large)
                            .foregroundStyle(.secondary)
                        Text(verbatim: "+\(overflow)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(Text("club.strip.all \(totalCount)"))
                .accessibilityIdentifier("club.detail.memberStrip.more")
            }
        }
    }
}

public struct ClubGapSettingsSheet: View {
    public let clubName: String
    public let canGovern: Bool
    public let onEditClub: () -> Void
    public let onTransferOwner: () -> Void
    public let onDissolveClub: () -> Void
    /// CLB-r7-A-06 (MP detail wxml:690-760): 客户与项目 rows (查看客户 · 报名名册 · 活动运营 · 角色与权限); nil hides a row.
    public var onCustomers: (() -> Void)? = nil
    public var onEnroll: (() -> Void)? = nil
    public var onEventOps: (() -> Void)? = nil
    public var onRoles: (() -> Void)? = nil
    /// CLB-r7-A-06 counts (MP detail wxml:697-797): 「N 人」/「暂时读不到」, 「N 个团」, 「N 已委派」; nil or 0 hides each.
    public var customerCountText: String? = nil
    public var topicCount: Int? = nil
    public var delegatedRoleCount: Int = 0
    /// CLB-r11-detail-01 (MP detail wxml:863-871): owner-only 经营 · 俱乐部分润; nil hides the section.
    public var onClubFinance: (() -> Void)? = nil
    public var settledAmountText: String? = nil

    @Environment(\.dismiss) private var dismiss

    public init(
        clubName: String,
        canGovern: Bool,
        onEditClub: @escaping () -> Void,
        onTransferOwner: @escaping () -> Void,
        onDissolveClub: @escaping () -> Void
    ) {
        self.clubName = clubName
        self.canGovern = canGovern
        self.onEditClub = onEditClub
        self.onTransferOwner = onTransferOwner
        self.onDissolveClub = onDissolveClub
    }

    public var body: some View {
        NavigationStack {
            List {
                if onCustomers != nil || onEnroll != nil || onEventOps != nil || onRoles != nil {
                    Section {
                        // CLB-r9-detail-03 (MP detail wxml:690-797): catalog keys, counts as the trailing value.
                        settingsRow("club.settings.customers", onCustomers, count: customerCountText.map { Text(verbatim: $0) })
                        settingsRow("club.settings.enroll", onEnroll, count: topicCountText)
                        settingsRow("club.settings.eventOps", onEventOps)
                        settingsRow("club.settings.roles", onRoles, count: delegatedRoleCount > 0 ? Text("club.settings.delegated \(delegatedRoleCount)") : nil)
                    } header: {
                        Text("club.settings.customersSection")
                    }
                }
                if let onClubFinance {
                    Section {
                        Button {
                            dismiss()
                            onClubFinance()
                        } label: {
                            LabeledContent("club.settings.clubFinance") {
                                if let settledAmountText { Text(verbatim: settledAmountText) }
                            }
                        }
                        .accessibilityIdentifier("club.settings.clubFinance")
                    } header: {
                        Text("club.settings.businessSection")
                    }
                }
                if canGovern {
                    Section {
                        Button("club.settings.editClub") {
                            dismiss()
                            onEditClub()
                        }
                    }
                    Section {
                        Button("club.settings.transferOwner") {
                            dismiss()
                            onTransferOwner()
                        }
                        Button("club.settings.dissolve", role: .destructive) {
                            dismiss()
                            onDissolveClub()
                        }
                    } header: {
                        Text("club.settings.danger")
                    } footer: {
                        Text("club.settings.dissolveFooter")
                    }
                }
            }
            .navigationTitle(Text("club.settings.title"))
            .navigationBarTitleDisplayMode(.inline)
            .accessibilityIdentifier("club.settings.sheet")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.close") { dismiss() }
                }
            }
        }
    }

    /// Supplies the 客户与项目 rows; each closure is the host's route (nil leaves the row out).
    public func clubTools(customers: (() -> Void)?, enroll: (() -> Void)?, eventOps: (() -> Void)?, roles: (() -> Void)?) -> Self {
        var copy = self
        copy.onCustomers = customers; copy.onEnroll = enroll; copy.onEventOps = eventOps; copy.onRoles = roles
        return copy
    }

    /// The counts beside 查看客户 · 报名名册 · 角色与权限 (MP loadSettingsCounts js:3579-3601; access.delegatedRoleCount js:2488).
    public func clubToolCounts(customers: String?, topics: Int?, delegatedRoles: Int) -> Self {
        var copy = self
        copy.customerCountText = customers; copy.topicCount = topics; copy.delegatedRoleCount = delegatedRoles
        return copy
    }

    /// CLB-r11-detail-01: 经营 · 俱乐部分润 and its amount text (MP loadSettingsCounts js:3587-3604).
    public func clubFinance(_ action: (() -> Void)?, amount: String?) -> Self {
        var copy = self
        copy.onClubFinance = action; copy.settledAmountText = amount
        return copy
    }

    /// 「N 个团」 beside 报名名册; nil or 0 hides it.
    private var topicCountText: Text? {
        guard let topicCount, topicCount > 0 else { return nil }
        return Text("club.settings.topicCount \(topicCount)")
    }

    @ViewBuilder private func settingsRow(_ title: LocalizedStringKey, _ action: (() -> Void)?, count: Text? = nil) -> some View {
        if let action {
            Button {
                dismiss()
                action()
            } label: {
                LabeledContent {
                    if let count { count }
                } label: {
                    Text(title).foregroundStyle(.primary)
                }
            }
        }
    }
}
