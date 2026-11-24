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
            Button(action: onTapCompose) {
                HStack {
                    Image(systemName: "square.and.pencil")
                        .foregroundStyle(CYColor.brand)
                    Text(verbatim: AccountPublishGapCopy.ownComposerPlaceholder)
                        .cyText(.body)
                        .foregroundStyle(CYColor.textSecondary)
                    Spacer()
                }
            }
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
    @Binding public var selectedLookID: String
    public let onOpenCastEditor: () -> Void

    public init(
        castEnabled: Binding<Bool>,
        castMembers: [TopicCastMemberDraft],
        selectedLookID: Binding<String>,
        onOpenCastEditor: @escaping () -> Void
    ) {
        self._castEnabled = castEnabled
        self.castMembers = castMembers
        self._selectedLookID = selectedLookID
        self.onOpenCastEditor = onOpenCastEditor
    }

    public var body: some View {
        Group {
            Section {
                Toggle("启用角色", isOn: $castEnabled)
                    .cyText(.body)
                if castEnabled {
                    Button(action: onOpenCastEditor) {
                        HStack {
                            Text(verbatim: "角色列表")
                                .cyText(.body)
                                .foregroundStyle(CYColor.textPrimary)
                            Spacer()
                            Text(verbatim: "\(castMembers.count) 位")
                                .cyText(.meta)
                                .foregroundStyle(CYColor.textSecondary)
                            Image(systemName: "chevron.right")
                                .cyText(.meta)
                                .foregroundStyle(CYColor.textSecondary)
                        }
                    }
                }
            } header: {
                Text(verbatim: "角色").cyText(.sectionTitle)
            }

            Section {
                Picker(TopicLookStyleCopy.paletteTitle, selection: $selectedLookID) {
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

    public var body: some View {
        Section {
            switch state {
            case .loading:
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            case .error(let msg):
                CYEmptyState(systemImage: "exclamationmark.triangle", verbatimTitle: TeamGapCopy.applicantsLoadFailed, verbatimSubtitle: msg, action: onRetry)
            case .ready(let items):
                if items.isEmpty {
                    CYEmptyState(systemImage: "person.2", verbatimTitle: TeamGapCopy.applicantsEmpty)
                } else {
                    ForEach(items) { item in
                        HStack(spacing: CYSpacing.sm) {
                            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                                Text(verbatim: item.nickname).cyText(.cardTitle)
                                if let message = item.message, !message.isEmpty {
                                    Text(verbatim: message).cyText(.meta).foregroundStyle(CYColor.textSecondary)
                                }
                            }
                            Spacer()
                            Button(TeamGapCopy.reject) {
                                let memberID = String(item.userID)
                                let targetID = String(teamID)
                                Task {
                                    let outcome = await AccountPublishContractLane.handleApplicant(memberID: memberID, teamID: targetID, approved: false)
                                    if outcome != .failed { onReject(item) }
                                }
                            }
                                .buttonStyle(CYPillButtonStyle(style: .secondary, fullWidth: false, compact: true))
                            Button(TeamGapCopy.approve) {
                                let memberID = String(item.userID)
                                let targetID = String(teamID)
                                Task {
                                    let outcome = await AccountPublishContractLane.handleApplicant(memberID: memberID, teamID: targetID, approved: true)
                                    if outcome != .failed { onApprove(item) }
                                }
                            }
                                .buttonStyle(CYPillButtonStyle(style: .primary, fullWidth: false, compact: true))
                        }
                    }
                }
            }
        } header: {
            Text(verbatim: TeamGapCopy.applicantsTitle).cyText(.sectionTitle)
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
