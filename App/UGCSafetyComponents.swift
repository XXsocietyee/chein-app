import SwiftUI

private struct UGCSafetyContextEnvironmentKey: EnvironmentKey {
    static let defaultValue: UGCSafetyContext? = nil
}

private struct UGCSafetySubjectIDEnvironmentKey: EnvironmentKey {
    static let defaultValue: Int? = nil
}

extension EnvironmentValues {
    var ugcSafetyContext: UGCSafetyContext? {
        get { self[UGCSafetyContextEnvironmentKey.self] }
        set { self[UGCSafetyContextEnvironmentKey.self] = newValue }
    }

    var ugcSafetySubjectID: Int? {
        get { self[UGCSafetySubjectIDEnvironmentKey.self] }
        set { self[UGCSafetySubjectIDEnvironmentKey.self] = newValue }
    }
}

/// Identifies a single UGC item or author for presenting `UGCReportSheet` or a block confirmation.
struct UGCReportPresentationTarget: Identifiable, Hashable {
    let id: String
    let target: UGCSafetyReportTarget
    let subjectTitle: String?
    let authorMemberID: Int?
    let authorName: String?
    let clubID: Int?

    init(
        target: UGCSafetyReportTarget,
        subjectTitle: String? = nil,
        authorMemberID: Int? = nil,
        authorName: String? = nil,
        clubID: Int? = nil
    ) {
        self.id = "\(target.routePath)::\(target.hashValue)::\(authorMemberID ?? 0)::\(authorName ?? "")"
        self.target = target
        self.subjectTitle = subjectTitle
        self.authorMemberID = authorMemberID
        self.authorName = authorName
        self.clubID = clubID
    }
}

/// App-level safety coordinator binding `UGCContentSafetyServing`, `UGCBlockedUsersStore`,
/// and `ChannelBlockedUsersStoring` to the current signed-in session.
@MainActor
final class UGCSafetyContext {
    let blockedStore: UGCBlockedUsersStore
    let channelBlockedStore: (any ChannelBlockedUsersStoring)?
    private let serviceProvider: () -> (any UGCContentSafetyServing)?
    private let tokenProvider: () -> String?
    private let accountIDProvider: () -> Int?
    private let realmProvider: () -> String

    init(
        blockedStore: UGCBlockedUsersStore,
        channelBlockedStore: (any ChannelBlockedUsersStoring)? = nil,
        serviceProvider: @escaping () -> (any UGCContentSafetyServing)?,
        tokenProvider: @escaping () -> String?,
        accountIDProvider: @escaping () -> Int?,
        realmProvider: @escaping () -> String
    ) {
        self.blockedStore = blockedStore
        self.channelBlockedStore = channelBlockedStore
        self.serviceProvider = serviceProvider
        self.tokenProvider = tokenProvider
        self.accountIDProvider = accountIDProvider
        self.realmProvider = realmProvider
        blockedStore.configureScope(accountID: accountIDProvider(), realm: realmProvider())
    }

    var viewerMemberID: Int? {
        accountIDProvider()
    }

    func canActOnAuthor(memberID: Int?) -> Bool {
        guard let memberID, memberID > 0 else { return true }
        guard let viewer = viewerMemberID, viewer > 0 else { return true }
        return memberID != viewer
    }

    func isBlocked(memberID: Int?, authorName: String? = nil) -> Bool {
        blockedStore.configureScope(accountID: accountIDProvider(), realm: realmProvider())
        return blockedStore.isBlocked(memberID: memberID, authorName: authorName)
    }

    func syncBlockedUsersIfNeeded() async {
        await blockedStore.syncFromServerIfNeeded(
            accountID: accountIDProvider(),
            realm: realmProvider(),
            token: tokenProvider(),
            service: serviceProvider()
        )
    }

    func loadCapabilities() async -> UGCContentSafetyCapabilities {
        guard let service = serviceProvider() else {
            return UGCContentSafetyCapabilities(
                policyVersion: UGCReportReasonOption.fallbackPolicyVersion,
                reasons: UGCReportReasonOption.fallbackTaxonomy
            )
        }
        do {
            return try await service.fetchCapabilities(token: tokenProvider() ?? "")
        } catch {
            return UGCContentSafetyCapabilities(
                policyVersion: UGCReportReasonOption.fallbackPolicyVersion,
                reasons: UGCReportReasonOption.fallbackTaxonomy
            )
        }
    }

    func submitReport(
        target: UGCSafetyReportTarget,
        reason: UGCReportReasonOption,
        details: String,
        policyVersion: String
    ) async throws -> String? {
        guard let service = serviceProvider(), let token = tokenProvider() else {
            throw UGCContentSafetyError.signedOut
        }
        return try await service.submitReport(
            target: target,
            reason: reason,
            details: details,
            policyVersion: policyVersion,
            token: token
        )
    }

    func blockUser(memberID: Int?, authorName: String?, clubID: Int? = nil) async throws {
        blockedStore.configureScope(accountID: accountIDProvider(), realm: realmProvider())
        try await blockedStore.block(
            memberID: memberID,
            authorName: authorName,
            clubID: clubID,
            channelStore: channelBlockedStore,
            token: tokenProvider(),
            service: serviceProvider()
        )
    }

    func unblockUser(memberID: Int?, authorName: String?, clubID: Int? = nil) async throws {
        blockedStore.configureScope(accountID: accountIDProvider(), realm: realmProvider())
        try await blockedStore.unblock(
            memberID: memberID,
            authorName: authorName,
            clubID: clubID,
            channelStore: channelBlockedStore,
            token: tokenProvider(),
            service: serviceProvider()
        )
    }

    func precheckContent(_ text: String, scene: String) async -> UGCPrecheckResult {
        guard let service = serviceProvider(), let token = tokenProvider() else {
            return UGCPrecheckResult(allowed: true, message: nil)
        }
        do {
            return try await service.precheckContent(text: text, scene: scene, token: token)
        } catch {
            return UGCPrecheckResult(allowed: true, message: nil)
        }
    }
}

/// Filters content belonging to any blocked `memberID` or `authorName` reactively across feeds,
/// comments, chats, and reviews without requiring boilerplate observation at every call site.
struct UGCBlockedFilterContainer<Content: View, BlockedPlaceholder: View>: View {
    @Environment(\.ugcSafetyContext) private var safety
    private let memberID: Int?
    private let authorName: String?
    private let content: () -> Content
    private let blockedPlaceholder: () -> BlockedPlaceholder

    init(
        memberID: Int? = nil,
        authorName: String? = nil,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder blockedPlaceholder: @escaping () -> BlockedPlaceholder = { EmptyView() }
    ) {
        self.memberID = memberID
        self.authorName = authorName
        self.content = content
        self.blockedPlaceholder = blockedPlaceholder
    }

    var body: some View {
        if let safety {
            UGCBlockedObservedGate(
                store: safety.blockedStore,
                memberID: memberID,
                authorName: authorName,
                content: content,
                blockedPlaceholder: blockedPlaceholder
            )
            .task {
                await safety.syncBlockedUsersIfNeeded()
            }
        } else {
            content()
        }
    }
}

private struct UGCBlockedObservedGate<Content: View, BlockedPlaceholder: View>: View {
    @ObservedObject var store: UGCBlockedUsersStore
    let memberID: Int?
    let authorName: String?
    let content: () -> Content
    let blockedPlaceholder: () -> BlockedPlaceholder

    var body: some View {
        if store.isBlocked(memberID: memberID, authorName: authorName) {
            blockedPlaceholder()
        } else {
            content()
        }
    }
}

/// Compact banner shown when a user opens a blocked author's profile or wants to unblock a hidden item.
struct UGCBlockedNoticeBanner: View {
    @Environment(\.ugcSafetyContext) private var safety
    let messageKey: LocalizedStringKey
    let memberID: Int?
    let authorName: String?
    let clubID: Int?

    @State private var busy = false

    init(
        messageKey: LocalizedStringKey = "ugc.safety.blockedBanner.hidden",
        memberID: Int? = nil,
        authorName: String? = nil,
        clubID: Int? = nil
    ) {
        self.messageKey = messageKey
        self.memberID = memberID
        self.authorName = authorName
        self.clubID = clubID
    }

    var body: some View {
        HStack(spacing: CYSpacing.sm) {
            Image(systemName: "hand.raised.slash")
                .accessibilityHidden(true).foregroundStyle(CYColor.warningText)
            Text(messageKey, tableName: "UGCSafety")
                .cyText(.meta)
                .foregroundStyle(CYColor.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            if memberID != nil || authorName != nil {
                Button {
                    Task {
                        busy = true
                        defer { busy = false }
                        try? await safety?.unblockUser(memberID: memberID, authorName: authorName, clubID: clubID)
                    }
                } label: {
                    Text("ugc.safety.action.unblock", tableName: "UGCSafety")
                        .cyText(.caption)
                }
                .disabled(busy)
                .accessibilityLabel(Text("ugc.safety.action.unblock", tableName: "UGCSafety"))
                .accessibilityIdentifier("ugc.safety.unblockButton")
            }
        }
        .padding(CYSpacing.md)
        .background(CYColor.warningSoft, in: RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("ugc.safety.blockedBanner")
    }
}

/// CY-compliant reporting modal using mini-program taxonomy (`/api/v1/community/capabilities`),
/// optional user blocking (`/api/im/block`), and published support/safety contact navigation.
@MainActor
struct UGCReportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.ugcSafetyContext) private var safety

    let presentation: UGCReportPresentationTarget
    var onBlocked: (() -> Void)? = nil
    var onSubmitted: (() -> Void)? = nil

    @State private var capabilities: UGCContentSafetyCapabilities?
    @State private var loading = false
    @State private var selectedReason: UGCReportReasonOption?
    @State private var details = ""
    @State private var alsoBlockAuthor = false
    @State private var submitting = false
    @State private var errorKey: LocalizedStringKey?
    @State private var serverErrorMessage: String?
    @State private var completedMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CYSpacing.lg) {
                    CYHeroHeader(
                        "ugc.safety.sheet.title",
                        subtitle: "ugc.safety.sheet.subtitle",
                        tableName: "UGCSafety"
                    ) {
                        Image(systemName: "shield.lefthalf.filled")
                            .accessibilityHidden(true)
                            .cyText(.pageTitle)
                            .foregroundStyle(CYColor.brand)
                            .accessibilityHidden(true)
                    }

                    if let subject = presentation.subjectTitle, !subject.isEmpty {
                        CYStatusChip(verbatim: subject, tone: .neutral, systemImage: "doc.text")
                    }

                    if completedMessage != nil {
                        completedSection
                    } else {
                        formSection
                    }

                    Divider()

                    NavigationLink {
                        SettingsSupportSafetyView()
                    } label: {
                        HStack(spacing: CYSpacing.sm) {
                            Image(systemName: "headphones")
                                .foregroundStyle(CYColor.brand)
                            Text("ugc.safety.action.contactSupport", tableName: "UGCSafety")
                                .cyText(.label)
                                .foregroundStyle(CYColor.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .cyText(.caption)
                                .foregroundStyle(CYColor.textTertiary)
                        }
                        .padding(CYSpacing.md)
                        .background(CYColor.bgSurfaceSubtle, in: RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("ugc.safety.action.contactSupport", tableName: "UGCSafety"))
                    .accessibilityIdentifier("ugc.safety.contactSupportLink")
                }
                .padding(.horizontal, CYSpacing.pageHorizontal)
                .padding(.vertical, CYSpacing.lg)
            }
            .background(CYColor.bgPage)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text("ugc.safety.close", tableName: "UGCSafety")
                    }
                    .accessibilityLabel(Text("ugc.safety.close", tableName: "UGCSafety"))
                    .accessibilityIdentifier("ugc.safety.close")
                }
            }
            .task {
                await reloadCapabilities()
            }
        }
    }

    @ViewBuilder
    private var completedSection: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            CYEmptyState(
                systemImage: "checkmark.shield.fill",
                "ugc.safety.submitted.title",
                tableName: "UGCSafety",
                detail: "ugc.safety.submitted.subtitle",
                detailVerbatim: completedMessage?.isEmpty == false ? completedMessage : nil
            )
            CYPillButton("ugc.safety.close", style: .primary, tableName: "UGCSafety") {
                dismiss()
            }
        }
    }

    @ViewBuilder
    private var formSection: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            Text("ugc.safety.reasonHeader", tableName: "UGCSafety")
                .cyText(.sectionTitle)
                .foregroundStyle(CYColor.textPrimary)

            if loading && capabilities == nil {
                CYSkeleton()
            } else if let reasons = capabilities?.reasons, !reasons.isEmpty {
                VStack(spacing: CYSpacing.sm) {
                    ForEach(reasons) { reason in
                        reasonRow(reason)
                    }
                }
            } else {
                CYEmptyState(
                    systemImage: "exclamationmark.triangle",
                    "ugc.safety.error.submitFailed",
                    tableName: "UGCSafety",
                    actionTitle: "ugc.safety.retry"
                ) {
                    Task { await reloadCapabilities() }
                }
            }

            if selectedReason?.isEmergency == true {
                HStack(alignment: .top, spacing: CYSpacing.sm) {
                    Image(systemName: "exclamationmark.shield.fill")
                        .accessibilityHidden(true).foregroundStyle(CYColor.dangerText)
                    Text("ugc.safety.emergencyHint", tableName: "UGCSafety")
                        .cyText(.meta)
                        .foregroundStyle(CYColor.dangerText)
                }
                .padding(CYSpacing.md)
                .background(CYColor.dangerSoft, in: RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous))
            }

            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                Text("ugc.safety.detailsHeader", tableName: "UGCSafety")
                    .cyText(.label)
                    .foregroundStyle(CYColor.textPrimary)
                TextField(
                    "",
                    text: $details,
                    prompt: Text("ugc.safety.detailsPlaceholder", tableName: "UGCSafety"),
                    axis: .vertical
                )
                .lineLimit(3...6)
                .padding(CYSpacing.md)
                .background(CYColor.bgSurface, in: RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous)
                        .stroke(CYColor.borderSubtle, lineWidth: 1)
                )
            }

            if canOfferBlock {
                Toggle(isOn: $alsoBlockAuthor) {
                    Text("ugc.safety.alsoBlockUser", tableName: "UGCSafety")
                        .cyText(.bodyCompact)
                        .foregroundStyle(CYColor.textPrimary)
                }
                .tint(CYColor.brand)
                .accessibilityIdentifier("ugc.safety.alsoBlock")
            }

            if let serverErrorMessage, !serverErrorMessage.isEmpty {
                Text(verbatim: serverErrorMessage)
                    .cyText(.meta)
                    .foregroundStyle(CYColor.dangerText)
            } else if let errorKey {
                Text(errorKey, tableName: "UGCSafety")
                    .cyText(.meta)
                    .foregroundStyle(CYColor.dangerText)
            }

            CYPillButton(
                "ugc.safety.submit",
                style: .primary,
                systemImage: "paperplane.fill",
                tableName: "UGCSafety"
            ) {
                Task { await submit() }
            }
            .disabled(submitting || selectedReason == nil)
            .accessibilityLabel(Text("ugc.safety.submit", tableName: "UGCSafety"))
            .accessibilityIdentifier("ugc.safety.submitReportButton")

            Text("ugc.safety.moderation.footer", tableName: "UGCSafety")
                .cyText(.caption)
                .foregroundStyle(CYColor.textTertiary)
                .accessibilityIdentifier("ugc.safety.moderation.notice")
        }
    }

    private var canOfferBlock: Bool {
        let hasAuthor = (presentation.authorMemberID ?? 0) > 0 || (presentation.authorName?.isEmpty == false)
        return hasAuthor && (safety?.canActOnAuthor(memberID: presentation.authorMemberID) ?? true)
    }

    @ViewBuilder
    private func reasonRow(_ reason: UGCReportReasonOption) -> some View {
        let isSelected = selectedReason == reason
        Button {
            selectedReason = reason
        } label: {
            HStack(spacing: CYSpacing.sm) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? CYColor.brand : CYColor.textTertiary)
                Text(verbatim: reason.label)
                    .cyText(.body)
                    .foregroundStyle(CYColor.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if reason.isEmergency {
                    CYStatusChip("ugc.safety.status.urgent", tone: .danger, systemImage: "bolt.fill")
                }
            }
            .padding(CYSpacing.md)
            .background(
                isSelected ? CYColor.brandSoft : CYColor.bgSurface,
                in: RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous)
                    .stroke(isSelected ? CYColor.brand : CYColor.borderSubtle, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: reason.label))
        .accessibilityIdentifier("ugc.safety.reason.\(reason.code)")
    }

    private func reloadCapabilities() async {
        loading = true
        defer { loading = false }
        let loaded = await safety?.loadCapabilities() ?? UGCContentSafetyCapabilities(
            policyVersion: UGCReportReasonOption.fallbackPolicyVersion,
            reasons: UGCReportReasonOption.fallbackTaxonomy
        )
        capabilities = loaded
        if selectedReason == nil {
            selectedReason = loaded.reasons.first
        }
    }

    private func submit() async {
        guard let selectedReason, !submitting else { return }
        guard let safety else {
            errorKey = "ugc.safety.error.signedOut"
            return
        }
        submitting = true
        errorKey = nil
        serverErrorMessage = nil
        defer { submitting = false }

        do {
            let policyVersion = capabilities?.policyVersion ?? UGCReportReasonOption.fallbackPolicyVersion
            let msg = try await safety.submitReport(
                target: presentation.target,
                reason: selectedReason,
                details: details,
                policyVersion: policyVersion
            )
            if alsoBlockAuthor {
                try? await safety.blockUser(
                    memberID: presentation.authorMemberID,
                    authorName: presentation.authorName,
                    clubID: presentation.clubID
                )
                onBlocked?()
            }
            completedMessage = msg ?? ""
            onSubmitted?()
        } catch UGCContentSafetyError.signedOut {
            errorKey = "ugc.safety.error.signedOut"
        } catch UGCContentSafetyError.serverRejected(let msg) {
            if let msg, !msg.isEmpty {
                serverErrorMessage = msg
            } else {
                errorKey = "ugc.safety.error.submitFailed"
            }
        } catch {
            errorKey = "ugc.safety.error.submitFailed"
        }
    }
}

/// Reusable toolbar or inline `Menu` exposing Report Content, Block/Unblock User, and Support Contact.
@MainActor
struct UGCSafetyMenuButton: View {
    @Environment(\.ugcSafetyContext) private var safety

    let presentation: UGCReportPresentationTarget
    var compactLabel: Bool = false
    var onBlocked: (() -> Void)? = nil

    @State private var reportPresented: UGCReportPresentationTarget?
    @State private var confirmBlock = false
    @State private var showSupport = false
    @State private var feedbackMessage: LocalizedStringKey?
    @State private var showFeedback = false

    private var hasBlockTarget: Bool {
        (presentation.authorMemberID ?? 0) > 0 || (presentation.authorName?.isEmpty == false)
    }

    private var canBlockAuthor: Bool {
        hasBlockTarget && (safety?.canActOnAuthor(memberID: presentation.authorMemberID) ?? true)
    }

    private var currentlyBlocked: Bool {
        safety?.isBlocked(memberID: presentation.authorMemberID, authorName: presentation.authorName) ?? false
    }

    var body: some View {
        Menu {
            Button {
                reportPresented = presentation
            } label: {
                Label {
                    Text("ugc.safety.action.report", tableName: "UGCSafety")
                } icon: {
                    Image(systemName: "flag")
                }
            }
            .accessibilityLabel(Text("ugc.safety.action.report", tableName: "UGCSafety"))
            .accessibilityIdentifier("ugc.safety.menu.report")

            if canBlockAuthor {
                if currentlyBlocked {
                    Button {
                        Task { await toggleBlock(unblock: true) }
                    } label: {
                        Label {
                            Text("ugc.safety.action.unblock", tableName: "UGCSafety")
                        } icon: {
                            Image(systemName: "hand.raised.slash")
                        }
                    }
                    .accessibilityLabel(Text("ugc.safety.action.unblock", tableName: "UGCSafety"))
                    .accessibilityIdentifier("ugc.safety.menu.unblock")
                } else {
                    Button(role: .destructive) {
                        confirmBlock = true
                    } label: {
                        Label {
                            Text("ugc.safety.action.block", tableName: "UGCSafety")
                        } icon: {
                            Image(systemName: "hand.raised")
                        }
                    }
                    .accessibilityLabel(Text("ugc.safety.action.block", tableName: "UGCSafety"))
                    .accessibilityIdentifier("ugc.safety.menu.block")
                }
            }

            Divider()

            Button {
                showSupport = true
            } label: {
                Label {
                    Text("ugc.safety.action.contactSupport", tableName: "UGCSafety")
                } icon: {
                    Image(systemName: "headphones")
                }
            }
            .accessibilityLabel(Text("ugc.safety.action.contactSupport", tableName: "UGCSafety"))
            .accessibilityIdentifier("ugc.safety.menu.contactSupport")
        } label: {
            if compactLabel {
                Image(systemName: "shield")
                    .cyText(.meta)
                    .foregroundStyle(CYColor.textSecondary)
                    .frame(minWidth: CYSpacing.xl, minHeight: CYSpacing.xl)
            } else {
                Label {
                    Text("ugc.safety.action.report", tableName: "UGCSafety")
                } icon: {
                    Image(systemName: "flag")
                }
            }
        }
        .accessibilityLabel(Text("ugc.safety.menu.accessibility", tableName: "UGCSafety"))
        .sheet(item: $reportPresented) { item in
            UGCReportSheet(presentation: item, onBlocked: onBlocked)
        }
        .sheet(isPresented: $showSupport) {
            NavigationStack {
                SettingsSupportSafetyView()
            }
        }
        .alert(Text("ugc.safety.block.confirmTitle", tableName: "UGCSafety"), isPresented: $confirmBlock) {
            Button(role: .cancel) { } label: {
                Text("ugc.safety.block.cancel", tableName: "UGCSafety")
            }
            .accessibilityLabel(Text("ugc.safety.block.cancel", tableName: "UGCSafety"))
            .accessibilityIdentifier("ugc.safety.block.cancel")
            Button(role: .destructive) {
                Task { await toggleBlock(unblock: false) }
            } label: {
                Text("ugc.safety.block.confirmButton", tableName: "UGCSafety")
            }
            .accessibilityLabel(Text("ugc.safety.block.confirmButton", tableName: "UGCSafety"))
            .accessibilityIdentifier("ugc.safety.block.confirm")
        } message: {
            Text("ugc.safety.block.confirmMessage", tableName: "UGCSafety")
        }
        .alert(Text("ugc.safety.sheet.title", tableName: "UGCSafety"), isPresented: $showFeedback) {
            Button(role: .cancel) { } label: {
                Text("ugc.safety.close", tableName: "UGCSafety")
            }
        } message: {
            if let feedbackMessage {
                Text(feedbackMessage, tableName: "UGCSafety")
            }
        }
    }

    private func toggleBlock(unblock: Bool) async {
        guard let safety else {
            feedbackMessage = "ugc.safety.error.signedOut"
            showFeedback = true
            return
        }
        do {
            if unblock {
                try await safety.unblockUser(
                    memberID: presentation.authorMemberID,
                    authorName: presentation.authorName,
                    clubID: presentation.clubID
                )
                feedbackMessage = "ugc.safety.unblock.done"
            } else {
                try await safety.blockUser(
                    memberID: presentation.authorMemberID,
                    authorName: presentation.authorName,
                    clubID: presentation.clubID
                )
                feedbackMessage = "ugc.safety.block.done"
                onBlocked?()
            }
            showFeedback = true
        } catch UGCContentSafetyError.signedOut {
            feedbackMessage = "ugc.safety.error.signedOut"
            showFeedback = true
        } catch {
            feedbackMessage = "ugc.safety.error.submitFailed"
            showFeedback = true
        }
    }
}

/// Inline safety footer designed for UGC cards, review rows, member badges, and sections
/// (such as `ActivityReviewsSection` and `TopicReviewsContent`) without leaking interactive UI
/// tokens into contract-locked presentation files.
@MainActor
struct UGCReviewSafetyFooter: View {
    @Environment(\.ugcSafetyContext) private var safety

    let target: UGCSafetyReportTarget
    let subjectTitle: String?
    let authorMemberID: Int?
    let authorName: String?
    let clubID: Int?

    @State private var reportPresented: UGCReportPresentationTarget?
    @State private var confirmBlock = false

    init(
        target: UGCSafetyReportTarget,
        subjectTitle: String? = nil,
        authorMemberID: Int? = nil,
        authorName: String? = nil,
        clubID: Int? = nil
    ) {
        self.target = target
        self.subjectTitle = subjectTitle
        self.authorMemberID = authorMemberID
        self.authorName = authorName
        self.clubID = clubID
    }

    private var canBlock: Bool {
        let hasTarget = (authorMemberID ?? 0) > 0 || (authorName?.isEmpty == false)
        return hasTarget && (safety?.canActOnAuthor(memberID: authorMemberID) ?? true)
    }

    var body: some View {
        HStack(spacing: CYSpacing.md) {
            Button {
                reportPresented = UGCReportPresentationTarget(
                    target: target,
                    subjectTitle: subjectTitle,
                    authorMemberID: authorMemberID,
                    authorName: authorName,
                    clubID: clubID
                )
            } label: {
                Label {
                    Text("ugc.safety.action.report", tableName: "UGCSafety")
                } icon: {
                    Image(systemName: "flag")
                }
                .cyText(.caption)
                .foregroundStyle(CYColor.textSecondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("ugc.safety.action.report", tableName: "UGCSafety"))
            .accessibilityIdentifier("ugc.safety.footer.report")

            if canBlock {
                Button(role: .destructive) {
                    confirmBlock = true
                } label: {
                    Label {
                        Text("ugc.safety.action.block", tableName: "UGCSafety")
                    } icon: {
                        Image(systemName: "hand.raised")
                    }
                    .cyText(.caption)
                    .foregroundStyle(CYColor.dangerText)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("ugc.safety.action.block", tableName: "UGCSafety"))
                .accessibilityIdentifier("ugc.safety.footer.block")
            }
        }
        .sheet(item: $reportPresented) { item in
            UGCReportSheet(presentation: item)
        }
        .alert(Text("ugc.safety.block.confirmTitle", tableName: "UGCSafety"), isPresented: $confirmBlock) {
            Button(role: .cancel) { } label: {
                Text("ugc.safety.block.cancel", tableName: "UGCSafety")
            }
            .accessibilityLabel(Text("ugc.safety.block.cancel", tableName: "UGCSafety"))
            .accessibilityIdentifier("ugc.safety.block.cancel")
            Button(role: .destructive) {
                Task {
                    try? await safety?.blockUser(memberID: authorMemberID, authorName: authorName, clubID: clubID)
                }
            } label: {
                Text("ugc.safety.block.confirmButton", tableName: "UGCSafety")
            }
            .accessibilityLabel(Text("ugc.safety.block.confirmButton", tableName: "UGCSafety"))
            .accessibilityIdentifier("ugc.safety.block.confirm")
        } message: {
            Text("ugc.safety.block.confirmMessage", tableName: "UGCSafety")
        }
    }
}

/// Public profile / member safety card showing Report User, Block / Unblock User,
/// blocked status banner, and Community Rules & Contact link.
@MainActor
struct UGCProfileSafetyActionsSection: View {
    @Environment(\.ugcSafetyContext) private var safety
    let memberID: Int
    let displayName: String?

    @State private var reportPresented: UGCReportPresentationTarget?
    @State private var confirmBlock = false
    @State private var statusMessageKey: LocalizedStringKey?

    private var isSelf: Bool {
        guard let viewer = safety?.viewerMemberID, viewer > 0 else { return false }
        return viewer == memberID
    }

    var body: some View {
        if !isSelf, memberID > 0 {
            if let safety {
                ObservedProfileSafetyContent(
                    store: safety.blockedStore,
                    memberID: memberID,
                    displayName: displayName
                ) { isBlocked in
                    actionsBody(isBlocked: isBlocked)
                }
            } else {
                actionsBody(isBlocked: false)
            }
        }
    }

    @ViewBuilder
    private func actionsBody(isBlocked: Bool) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            if isBlocked {
                UGCBlockedNoticeBanner(
                    messageKey: "ugc.safety.blockedBanner.profile",
                    memberID: memberID,
                    authorName: displayName
                )
            }
            HStack(spacing: CYSpacing.sm) {
                CYPillButton(
                    "ugc.safety.action.reportUser",
                    style: .secondary,
                    systemImage: "flag",
                    fullWidth: true,
                    compact: true,
                    tableName: "UGCSafety"
                ) {
                    reportPresented = UGCReportPresentationTarget(
                        target: .member(memberID: memberID),
                        subjectTitle: displayName,
                        authorMemberID: memberID,
                        authorName: displayName
                    )
                }
                .accessibilityLabel(Text("ugc.safety.action.reportUser", tableName: "UGCSafety"))
                .accessibilityIdentifier("ugc.profile.reportButton")

                CYPillButton(
                    isBlocked ? "ugc.safety.action.unblock" : "ugc.safety.action.block",
                    style: .secondary,
                    systemImage: isBlocked ? "hand.raised.slash" : "hand.raised",
                    fullWidth: true,
                    compact: true,
                    tableName: "UGCSafety"
                ) {
                    if isBlocked {
                        Task { await unblockNow() }
                    } else {
                        confirmBlock = true
                    }
                }
                .accessibilityLabel(Text(isBlocked ? "ugc.safety.action.unblock" : "ugc.safety.action.block", tableName: "UGCSafety"))
                .accessibilityIdentifier("ugc.profile.blockButton")
            }

            if let statusMessageKey {
                Text(statusMessageKey, tableName: "UGCSafety")
                    .cyText(.caption)
                    .foregroundStyle(CYColor.textSecondary)
            }
        }
        .sheet(item: $reportPresented) { item in
            UGCReportSheet(presentation: item)
        }
        .alert(Text("ugc.safety.block.confirmTitle", tableName: "UGCSafety"), isPresented: $confirmBlock) {
            Button(role: .cancel) { } label: {
                Text("ugc.safety.block.cancel", tableName: "UGCSafety")
            }
            .accessibilityLabel(Text("ugc.safety.block.cancel", tableName: "UGCSafety"))
            .accessibilityIdentifier("ugc.safety.block.cancel")
            Button(role: .destructive) {
                Task { await blockNow() }
            } label: {
                Text("ugc.safety.block.confirmButton", tableName: "UGCSafety")
            }
            .accessibilityLabel(Text("ugc.safety.block.confirmButton", tableName: "UGCSafety"))
            .accessibilityIdentifier("ugc.safety.block.confirm")
        } message: {
            Text("ugc.safety.block.confirmMessage", tableName: "UGCSafety")
        }
    }

    private func blockNow() async {
        guard let safety else { statusMessageKey = "ugc.safety.error.signedOut"; return }
        do {
            try await safety.blockUser(memberID: memberID, authorName: displayName)
            statusMessageKey = "ugc.safety.block.done"
        } catch {
            statusMessageKey = "ugc.safety.error.submitFailed"
        }
    }

    private func unblockNow() async {
        guard let safety else { statusMessageKey = "ugc.safety.error.signedOut"; return }
        do {
            try await safety.unblockUser(memberID: memberID, authorName: displayName)
            statusMessageKey = "ugc.safety.unblock.done"
        } catch {
            statusMessageKey = "ugc.safety.error.submitFailed"
        }
    }
}

private struct ObservedProfileSafetyContent<Content: View>: View {
    @ObservedObject var store: UGCBlockedUsersStore
    let memberID: Int
    let displayName: String?
    @ViewBuilder let content: (Bool) -> Content

    var body: some View {
        content(store.isBlocked(memberID: memberID, authorName: displayName))
    }
}
