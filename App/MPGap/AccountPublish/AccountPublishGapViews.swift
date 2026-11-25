import SwiftUI

/// Mount hook for `ProfileAuthorPostsSection` (`AP-G01`):
/// Own-profile post composer (`有什么新鲜好玩的分享吗？`) & join date (`加入时间`).
public struct AccountGapOwnProfileComposerRow: View {
    public let joinDateText: String?
    public let onTapCompose: () -> Void

    public init(joinDateText: String? = nil, onTapCompose: @escaping () -> Void) {
        self.joinDateText = joinDateText
        self.onTapCompose = onTapCompose
    }

    public var body: some View {
        Group {
            // r8 A1-01 (MP cyp wxml:262-275): own-profile prompt that opens the post composer.
            Button(action: onTapCompose) {
                HStack(spacing: CYSpacing.sm) {
                    MPAsset.FeatureIcon.iconPen
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .accessibilityHidden(true)
                    Text("fixr8.profile.composerPlaceholder")
                        .cyText(.body)
                        .foregroundStyle(CYColor.textSecondary)
                    Spacer()
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .accessibilityIdentifier("profile.ownComposer")
            if let joinDateText, !joinDateText.isEmpty {
                LabeledContent(AccountPublishGapCopy.joinDatePrefix, value: joinDateText)
                    .cyText(.meta)
            }
        }
    }
}

/// Mount hook for `SocialPublicProfileView` (`AP-G02`):
/// Merchant viewer `发起合作` bottom action bar.
public struct SocialPublicProfileGapCoopBar: View {
    public let onInitiateCoop: () -> Void

    public init(onInitiateCoop: @escaping () -> Void) {
        self.onInitiateCoop = onInitiateCoop
    }

    public var body: some View {
        HStack {
            Button(AccountPublishGapCopy.initiateCoop, action: onInitiateCoop)
                .buttonStyle(CYPillButtonStyle(style: .primary, fullWidth: true))
        }
        .padding(.horizontal, CYSpacing.lg)
        .padding(.vertical, CYSpacing.sm)
    }
}

/// Mount hook for `ProjectEditView` (`AP-G10`):
/// Cast (`角色`) editor summary & look/theme style (`画面风格`) selector.
public struct ProjectEditGapCastAndLookSection: View {
    @Binding public var castEnabled: Bool
    public let castMembers: [TopicCastMemberDraft]
    /// nil hides the look row (r8: the 画面风格 picker is mounted on its own, see `ProjectEditLookHost`).
    public let selectedLookID: Binding<String>?
    public let onOpenCastEditor: () -> Void

    public init(
        castEnabled: Binding<Bool>,
        castMembers: [TopicCastMemberDraft],
        selectedLookID: Binding<String>?,
        onOpenCastEditor: @escaping () -> Void
    ) {
        self._castEnabled = castEnabled
        self.castMembers = castMembers
        self.selectedLookID = selectedLookID
        self.onOpenCastEditor = onOpenCastEditor
    }

    public var body: some View {
        Group {
            // r8 C-F5 (MP fabu wxml:172-187): one card, 角色 + stacked faces + 「N 位」 + switch; the row opens the list.
            Section {
                Toggle(isOn: $castEnabled) {
                    Text("fixr8.cast.title").cyText(.body)
                }
                .accessibilityIdentifier("projectEdit.cast.switch")
                if castEnabled {
                    Button(action: onOpenCastEditor) {
                        HStack(spacing: CYSpacing.sm) {
                            Text("fixr8.cast.list").cyText(.body).foregroundStyle(CYColor.textPrimary)
                            Spacer()
                            if !castMembers.isEmpty {
                                Text("fixr8.cast.count \(castMembers.count)")
                                    .cyText(.meta).foregroundStyle(CYColor.textSecondary)
                            }
                            Image(systemName: "chevron.right")
                                .cyText(.meta).foregroundStyle(CYColor.textSecondary)
                                .accessibilityHidden(true)
                        }
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .accessibilityLabel(Text("fixr8.cast.open"))
                    .accessibilityIdentifier("projectEdit.cast.open")
                }
            } header: {
                Text("fixr8.cast.title").cyText(.sectionTitle)
            }

            if let selectedLookID {
                Section {
                    Picker(TopicLookStyleCopy.paletteTitle, selection: selectedLookID) {
                        ForEach(TopicLookStyleCopy.presets, id: \.id) { preset in
                            Text(verbatim: preset.name).tag(preset.id)
                        }
                    }
                    .cyText(.body)
                } header: {
                    Text(verbatim: TopicLookStyleCopy.sectionTitle).cyText(.sectionTitle)
                }
            }
        }
    }
}

/// Mount hook for `SquareDetailView` (`AP-G14`):
/// Feed play card (`可直接开局的模板` + `看看模板` + `试玩`) and unified bookmark button.
public struct SquareDetailGapPlayCardSection: View {
    public let templateTitle: String
    public let isBookmarked: Bool
    public let onRemixTemplate: () -> Void
    public let onTryPlay: () -> Void
    public let onToggleBookmark: () -> Void

    public init(
        templateTitle: String,
        isBookmarked: Bool,
        onRemixTemplate: @escaping () -> Void,
        onTryPlay: @escaping () -> Void,
        onToggleBookmark: @escaping () -> Void
    ) {
        self.templateTitle = templateTitle
        self.isBookmarked = isBookmarked
        self.onRemixTemplate = onRemixTemplate
        self.onTryPlay = onTryPlay
        self.onToggleBookmark = onToggleBookmark
    }

    public var body: some View {
        Section {
            VStack(alignment: .leading, spacing: CYSpacing.sm) {
                CYStatusChip(verbatim: AccountPublishGapCopy.playableTemplateBadge, tone: .info)
                Text(verbatim: templateTitle)
                    .cyText(.cardTitle)
                    .foregroundStyle(CYColor.textPrimary)
                HStack(spacing: CYSpacing.sm) {
                    Button(AccountPublishGapCopy.viewTemplateRemix, action: onRemixTemplate)
                        .buttonStyle(CYPillButtonStyle(style: .secondary, fullWidth: false, compact: true))
                    Button(AccountPublishGapCopy.tryPlay, action: onTryPlay)
                        .buttonStyle(CYPillButtonStyle(style: .primary, fullWidth: false, compact: true))
                }
            }
            .padding(.vertical, CYSpacing.xs)

            Button(action: onToggleBookmark) {
                HStack(spacing: CYSpacing.xs) {
                    (isBookmarked ? MPAsset.FeatureIcon.iconStarFilled : MPAsset.FeatureIcon.iconStarOutline)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                    Text(verbatim: isBookmarked ? AccountPublishGapCopy.bookmarkRemove : AccountPublishGapCopy.bookmarkAdd)
                        .cyText(.body)
                }
            }
        }
    }
}

/// Mount hook for `TeamHomeView` (`AP-G15`):
/// Leader `入队申请` section with loading / retry / empty / approve-reject pills.
public struct TeamDetailGapApplicantsSection: View {
    public enum LoadState: Equatable {
        case loading
        case error(String)
        case ready([TeamApplicantItem])
    }

    public let state: LoadState
    public let teamID: Int
    public let onRetry: () -> Void
    public let onReject: (TeamApplicantItem) -> Void
    public let onApprove: (TeamApplicantItem) -> Void

    public init(
        state: LoadState,
        teamID: Int = 0,
        onRetry: @escaping () -> Void,
        onReject: @escaping (TeamApplicantItem) -> Void,
        onApprove: @escaping (TeamApplicantItem) -> Void
    ) {
        self.state = state
        self.teamID = teamID
        self.onRetry = onRetry
        self.onReject = onReject
        self.onApprove = onApprove
    }

    @State private var rejecting: TeamApplicantItem?
    @State private var handlingID: Int?
    @State private var commandNotice: String?

    public var body: some View {
        // r8 C-D2 (MP team/detail wxml:76-95): 入队申请 · N, skeleton, inline error + 重试, 暂无申请,
        // rows with avatar (d_profile default), name, message, 拒绝 (danger confirm) and 同意.
        Section {
            switch state {
            case .loading:
                CYLoadingState("fixr8.team.applicants.loading", messageIdentifier: "team.applicants.loading")
            case .error(let msg):
                CYEmptyState(systemImage: "exclamationmark.triangle", "fixr8.team.applicants.loadFailed",
                             detailVerbatim: msg.isEmpty ? nil : msg, actionTitle: "重试",
                             actionIdentifier: "team.applicants.retry", action: onRetry)
            case .ready(let items):
                CYCard(padding: CYSpacing.md) {
                    VStack(spacing: 0) {
                        if items.isEmpty {
                            Text("fixr8.team.applicants.empty")
                                .cyText(.meta).foregroundStyle(CYColor.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            applicantRow(item)
                            if index < items.count - 1 { Divider().overlay(CYColor.borderSubtle) }
                        }
                        if let commandNotice, !commandNotice.isEmpty {
                            Text(verbatim: commandNotice)
                                .cyText(.meta).foregroundStyle(CYColor.dangerText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .accessibilityAddTraits(.updatesFrequently)
                        }
                    }
                }
            }
        } header: {
            Group {
                if case .ready(let items) = state, !items.isEmpty {
                    Text("fixr8.team.applicants.titleCount \(items.count)")
                } else {
                    Text("fixr8.team.applicants.title")
                }
            }
            .cyText(.sectionTitle).foregroundStyle(CYColor.textPrimary).accessibilityAddTraits(.isHeader)
        }
        .confirmationDialog(Text("fixr8.team.applicants.rejectTitle \(rejecting?.nickname ?? "")"),
                            isPresented: Binding(get: { rejecting != nil }, set: { if !$0 { rejecting = nil } }),
                            titleVisibility: .visible, presenting: rejecting) { item in
            Button("fixr8.team.applicants.rejectConfirm", role: .destructive) { handle(item, approved: false) }
            Button("common.cancel", role: .cancel) { rejecting = nil }
        } message: { _ in
            Text("fixr8.team.applicants.rejectMessage")
        }
    }

    @ViewBuilder private func applicantRow(_ item: TeamApplicantItem) -> some View {
        HStack(spacing: CYSpacing.sm) {
            applicantAvatar(item.avatarURL)
            VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                Text(verbatim: item.nickname).cyText(.cardTitle).foregroundStyle(CYColor.textPrimary)
                if let message = item.message, !message.isEmpty {
                    Text(verbatim: message).cyText(.meta).foregroundStyle(CYColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: CYSpacing.xs)
            Button("fixr8.team.applicants.reject") { rejecting = item }
                .buttonStyle(CYPillButtonStyle(style: .secondary, fullWidth: false, compact: true))
                .frame(minHeight: 44)
                .accessibilityLabel(Text("fixr8.team.applicants.rejectA11y \(item.nickname)"))
                .accessibilityIdentifier("team.applicants.reject.\(item.userID)")
            Button("fixr8.team.applicants.approve") { handle(item, approved: true) }
                .buttonStyle(CYPillButtonStyle(style: .primary, fullWidth: false, compact: true))
                .frame(minHeight: 44)
                .accessibilityLabel(Text("fixr8.team.applicants.approveA11y \(item.nickname)"))
                .accessibilityIdentifier("team.applicants.approve.\(item.userID)")
        }
        .disabled(handlingID != nil)
        .padding(.vertical, CYSpacing.xs)
    }

    @ViewBuilder private func applicantAvatar(_ raw: String?) -> some View {
        Group {
            if let raw, let url = URL(string: raw), url.scheme == "https" {
                AsyncImage(url: url) { phase in
                    if let image = phase.image { image.resizable().scaledToFill() }
                    else { MPAsset.AvatarDefault.dProfile.resizable().scaledToFill() }
                }
            } else {
                MPAsset.AvatarDefault.dProfile.resizable().scaledToFill()
            }
        }
        .frame(width: 32, height: 32)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }

    private func handle(_ item: TeamApplicantItem, approved: Bool) {
        guard handlingID == nil, teamID > 0 else { return }
        rejecting = nil
        handlingID = item.userID
        let memberID = String(item.userID)
        let targetID = String(teamID)
        Task {
            let outcome = await AccountPublishContractLane.handleApplicant(memberID: memberID, teamID: targetID, approved: approved)
            handlingID = nil
            if case .sent(let receipt) = outcome {
                commandNotice = receipt?.rejectNotice
                if approved { onApprove(item) } else { onReject(item) }
            } else {
                onRetry()
            }
        }
    }
}

/// Mount hook for `TeamPageParityViews` (`AP-G16`):
/// Manual join-code entry (`?entry=code`) & proactive `去买这一场的票` CTA.
public struct TeamJoinGapManualCodeSection: View {
    @Binding public var code: String
    public let errorText: String?
    public let showsBuyTicketCTA: Bool
    public let onSubmitCode: () -> Void
    public let onBuyTicket: () -> Void

    public init(
        code: Binding<String>,
        errorText: String? = nil,
        showsBuyTicketCTA: Bool = false,
        onSubmitCode: @escaping () -> Void,
        onBuyTicket: @escaping () -> Void
    ) {
        self._code = code
        self.errorText = errorText
        self.showsBuyTicketCTA = showsBuyTicketCTA
        self.onSubmitCode = onSubmitCode
        self.onBuyTicket = onBuyTicket
    }

    public var body: some View {
        Section {
            TextField(TeamGapCopy.joinCodePlaceholder, text: $code)
                .cyText(.body)
                .onChange(of: code) { _, newValue in
                    if newValue.count > TeamGapCopy.maxJoinCodeLength {
                        code = String(newValue.prefix(TeamGapCopy.maxJoinCodeLength))
                    }
                }
            if let errorText, !errorText.isEmpty {
                Text(verbatim: errorText)
                    .cyText(.meta)
                    .foregroundStyle(CYColor.dangerText)
            }
            Button(TeamGapCopy.nextStep, action: onSubmitCode)
                .buttonStyle(CYPillButtonStyle(style: .primary, fullWidth: true))
                .disabled(code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            if showsBuyTicketCTA {
                Button(TeamGapCopy.buyTicketCTA, action: onBuyTicket)
                    .buttonStyle(CYPillButtonStyle(style: .secondary, fullWidth: true))
            }
        } header: {
            Text(verbatim: TeamGapCopy.joinCodeLabel).cyText(.sectionTitle)
        }
    }
}

/// Production session installed by `SessionRootView`. Design fixtures leave it unset and keep their old senders.
@MainActor enum AccountPublishContractLane {
    enum HandleOutcome: Equatable {
        case unavailable
        case sent(AccountPublishMPContract.TeamHandleReceipt?)
        case failed
    }

    private static weak var session: AppSession?

    static func install(_ session: AppSession) { self.session = session }

    static var isInstalled: Bool { session != nil }

    static var baseURL: URL? { session?.regionalConfiguration?.apiConfiguration?.baseURL }

    static var token: String? {
        session?.token.flatMap { AuthRequestBuilder.isValidToken($0) ? $0 : nil }
    }

    static var memberID: String? {
        session?.account.flatMap { $0.id > 0 ? String($0.id) : nil }
    }

    static var transport: (any HTTPTransport)? { session?.runtimeHTTPTransport }

    static func send(_ request: URLRequest) async throws -> (Data, Int) {
        guard let transport else { throw APIError.invalidRequest }
        return try await transport.send(request)
    }

    static func userInfo() async throws -> (Data, Int) {
        guard let baseURL, let memberID else { throw APIError.invalidRequest }
        let request = try AccountPublishMPContract.userInfoRequest(baseURL: baseURL, memberID: memberID, token: token)
        return try await send(request)
    }

    static func profileEditor() async -> AccountPublishMPContract.ProfileEditor? {
        guard isInstalled, let (data, _) = try? await userInfo() else { return nil }
        return AccountPublishMPContract.profileEditor(from: data)
    }

    @discardableResult
    static func handleApplicant(memberID: String, teamID: String, approved: Bool) async -> HandleOutcome {
        guard isInstalled, let baseURL else { return .unavailable }
        let requestID = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        guard let request = try? AccountPublishMPContract.teamHandleRequest(
            baseURL: baseURL, memberID: memberID, approved: approved, targetID: teamID, requestID: requestID, token: token
        ) else { return .failed }
        do {
            let (data, status) = try await send(request)
            guard (200..<300).contains(status) else { return .failed }
            return .sent(AccountPublishMPContract.teamHandleReceipt(from: data))
        } catch {
            return .failed
        }
    }
}
