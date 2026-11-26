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
        .sheet(item: $applyingItem) { item in
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
                        Button("取消") { applyingItem = nil }
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
            ContentUnavailableView("暂不能看可对接的活动", systemImage: "lock", description: Text(verbatim: reason))
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
                            Text(verbatim: "\(nick) 发布")
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

        public init(id: String, name: String, url: URL?) {
            self.id = id
            self.name = name
            self.url = url
        }
    }

    public let avatars: [AvatarItem]
    public let totalCount: Int
    public let onTapAll: () -> Void

    public init(avatars: [AvatarItem], totalCount: Int, onTapAll: @escaping () -> Void) {
        self.avatars = avatars
        self.totalCount = totalCount
        self.onTapAll = onTapAll
    }

    public var body: some View {
        Button(action: onTapAll) {
            HStack(spacing: 8) {
                ForEach(Array(avatars.prefix(4))) { item in
                    CYAvatarView(url: item.url, name: item.name, size: .sm)
                }
                let overflow = max(0, totalCount - min(avatars.count, 4))
                if overflow > 0 {
                    Text(verbatim: "+\(overflow)")
                        .font(.subheadline)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("查看全部 \(totalCount) 位成员")
    }
}

/// Mount hook for `ClubDetailView` — `CLB-G06` (俱乐部设置 sheet) & `CLB-G19` (改为转让主理人).
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
                        settingsRow("查看客户", onCustomers, count: customerCountText)
                        settingsRow("报名名册", onEnroll, count: (topicCount ?? 0) > 0 ? "\(topicCount ?? 0) 个团" : nil)
                        settingsRow("活动运营", onEventOps)
                        settingsRow("角色与权限", onRoles, count: delegatedRoleCount > 0 ? "\(delegatedRoleCount) 已委派" : nil)
                    } header: {
                        Text(verbatim: "客户与项目")
                    }
                }
                if canGovern {
                    Section {
                        Button("编辑俱乐部资料") {
                            dismiss()
                            onEditClub()
                        }
                    }
                    Section {
                        Button("改为转让主理人") {
                            dismiss()
                            onTransferOwner()
                        }
                        Button("解散俱乐部", role: .destructive) {
                            dismiss()
                            onDissolveClub()
                        }
                    } header: {
                        Text(verbatim: "危险操作")
                    } footer: {
                        Text(verbatim: "成员将失去俱乐部与群聊入口，已报名不会自动退款。")
                    }
                }
            }
            .cyPageTitle(verbatim: "俱乐部设置")
            .accessibilityIdentifier("club.settings.sheet")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
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

    @ViewBuilder private func settingsRow(_ title: String, _ action: (() -> Void)?, count: String? = nil) -> some View {
        if let action {
            Button {
                dismiss()
                action()
            } label: {
                HStack {
                    Text(verbatim: title).foregroundStyle(.primary)
                    Spacer()
                    if let count { Text(verbatim: count).foregroundStyle(.secondary) }
                    Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
                .contentShape(Rectangle())
            }
        }
    }
}
