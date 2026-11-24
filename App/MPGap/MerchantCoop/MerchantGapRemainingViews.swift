import SwiftUI

/// Mount hook for `MerchantHomeView` (`MC-G01`):
/// Workbench project cards showing upcoming runs & 待核销 counts.
public struct MerchantGapWorkbenchProjectCardsSection: View {
    public let cards: [MerchantWorkbenchProjectCard]
    public let onSelectProject: (Int) -> Void

    public init(cards: [MerchantWorkbenchProjectCard], onSelectProject: @escaping (Int) -> Void) {
        self.cards = cards
        self.onSelectProject = onSelectProject
    }

    public var body: some View {
        if !cards.isEmpty {
            Section {
                ForEach(cards) { card in
                    Button {
                        onSelectProject(card.id)
                    } label: {
                        VStack(alignment: .leading, spacing: CYSpacing.xs) {
                            HStack {
                                Text(verbatim: card.title).cyText(.cardTitle).foregroundStyle(CYColor.textPrimary)
                                Spacer()
                                if let role = card.roleLabel, !role.isEmpty {
                                    CYStatusChip(verbatim: role, tone: .neutral)
                                }
                            }
                            HStack(spacing: CYSpacing.md) {
                                Text(verbatim: "近期场次 \(card.upcomingRunsCount)").cyText(.meta).foregroundStyle(CYColor.textSecondary)
                                Text(verbatim: "待核销 \(card.pendingVerifyCount)").cyText(.meta).foregroundStyle(CYColor.brand)
                            }
                        }
                    }
                }
            } header: {
                Text(verbatim: "参与的项目").cyText(.sectionTitle)
            }
        }
    }
}

/// Mount hook for `MerchantOnboardingView` (`MC-G02`):
/// Intro view (`把你的店放进玩家的路线里`), `认领已有门店` sheet, and owned-club handover card.
public struct MerchantGapOnboardingIntroView: View {
    public let ownedClubs: [MerchantOwnedClubHandoverItem]
    public let onStartForm: () -> Void
    public let onSubmitClaim: (MerchantOnboardingClaimRequest) -> Void
    public let onTransferClub: (Int) -> Void

    @State private var showClaimSheet = false
    @State private var claimDraft = MerchantOnboardingClaimRequest()

    public init(
        ownedClubs: [MerchantOwnedClubHandoverItem] = [],
        onStartForm: @escaping () -> Void,
        onSubmitClaim: @escaping (MerchantOnboardingClaimRequest) -> Void,
        onTransferClub: @escaping (Int) -> Void
    ) {
        self.ownedClubs = ownedClubs
        self.onStartForm = onStartForm
        self.onSubmitClaim = onSubmitClaim
        self.onTransferClub = onTransferClub
    }

    public var body: some View {
        List {
            if !ownedClubs.isEmpty {
                Section {
                    VStack(alignment: .leading, spacing: CYSpacing.xs) {
                        Text(verbatim: MerchantRemainingGapCopy.clubTransferTitle).cyText(.cardTitle)
                        Text(verbatim: MerchantRemainingGapCopy.clubTransferSub).cyText(.meta).foregroundStyle(CYColor.textSecondary)
                    }
                    ForEach(ownedClubs) { club in
                        HStack {
                            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                                Text(verbatim: club.name).cyText(.body)
                                CYStatusChip(verbatim: club.statusText, tone: .neutral)
                            }
                            Spacer()
                            if club.canTransfer {
                                Button(MerchantRemainingGapCopy.goTransfer) { onTransferClub(club.id) }
                                    .buttonStyle(CYPillButtonStyle(style: .secondary, fullWidth: false, compact: true))
                            }
                        }
                    }
                } header: {
                    Text(verbatim: MerchantRemainingGapCopy.clubTransferHeader).cyText(.sectionTitle)
                }
            }

            Section {
                VStack(alignment: .leading, spacing: CYSpacing.md) {
                    Text(verbatim: MerchantRemainingGapCopy.introTitle)
                        .cyText(.sectionTitle)
                        .foregroundStyle(CYColor.textPrimary)
                    Button(MerchantRemainingGapCopy.startOnboarding, action: onStartForm)
                        .buttonStyle(CYPillButtonStyle(style: .primary, fullWidth: true))
                    Button(MerchantRemainingGapCopy.claimExistingStore) {
                        showClaimSheet = true
                    }
                    .cyText(.meta)
                    .foregroundStyle(CYColor.brand)
                }
                .padding(.vertical, CYSpacing.sm)
            }
        }
        .sheet(isPresented: $showClaimSheet) {
            NavigationStack {
                Form {
                    TextField("门店名称", text: $claimDraft.storeName).cyText(.body)
                    TextField("联系电话", text: $claimDraft.contactPhone).cyText(.body)
                    TextField("补充说明", text: $claimDraft.note, axis: .vertical).cyText(.body)
                }
                .cyPageTitle(verbatim: "认领已有门店")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") { showClaimSheet = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("提交认领") {
                            onSubmitClaim(claimDraft)
                            showClaimSheet = false
                        }
                        .disabled(claimDraft.storeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
    }
}

/// Mount hook for `MerchantOperationsEditor` / `MerchantOperationsViews` (`MC-G10`, `MC-G11`):
/// Contact/WeChat/QR/Address fields + `看公开主页` + `联系运营开通`, and onboarding empty state.
public struct MerchantGapDecorContactSection: View {
    @Binding public var draft: MerchantDecorContactDraft
    public let onPickQR: () -> Void
    public let onPickAddress: () -> Void
    public let onPreviewPublicHome: () -> Void
    public let onContactOps: () -> Void

    public init(
        draft: Binding<MerchantDecorContactDraft>,
        onPickQR: @escaping () -> Void,
        onPickAddress: @escaping () -> Void,
        onPreviewPublicHome: @escaping () -> Void,
        onContactOps: @escaping () -> Void
    ) {
        self._draft = draft
        self.onPickQR = onPickQR
        self.onPickAddress = onPickAddress
        self.onPreviewPublicHome = onPreviewPublicHome
        self.onContactOps = onContactOps
    }

    public var body: some View {
        Group {
            Section {
                TextField(MerchantRemainingGapCopy.contactPhoneLabel, text: $draft.contactPhone).cyText(.body)
                TextField(MerchantRemainingGapCopy.wechatLabel, text: $draft.wechatID).cyText(.body)
                Button(MerchantRemainingGapCopy.qrLabel, action: onPickQR).cyText(.body)
                Button(action: onPickAddress) {
                    LabeledContent(MerchantRemainingGapCopy.addressLabel, value: draft.address.isEmpty ? "去地图选点" : draft.address)
                        .cyText(.body)
                }
                if let featured = draft.featuredTopicName, !featured.isEmpty {
                    LabeledContent("招牌主推", value: featured).cyText(.body)
                }
            }
            Section {
                Button(MerchantRemainingGapCopy.previewPublicHome, action: onPreviewPublicHome).cyText(.body)
                Button(MerchantRemainingGapCopy.contactOpsOpen, action: onContactOps).cyText(.body)
            }
        }
    }
}

/// Mount hook for `CoopRelationDiscoveryView` (`MC-G14`) & `MerchantOperatorRosterSections` (`MC-G15`):
/// Relation `帖子` feed + composer bar, and pending team invite acceptance row.
public struct CoopGapRelationFeedAndTeamInviteSection: View {
    public let posts: [MerchantRelationFeedItem]
    public let isRefreshing: Bool
    public let pendingInvite: MerchantPendingTeamInvite?
    public let onComposePost: () -> Void
    public let onAcceptInvite: (Int) -> Void

    public init(
        posts: [MerchantRelationFeedItem],
        isRefreshing: Bool = false,
        pendingInvite: MerchantPendingTeamInvite? = nil,
        onComposePost: @escaping () -> Void,
        onAcceptInvite: @escaping (Int) -> Void
    ) {
        self.posts = posts
        self.isRefreshing = isRefreshing
        self.pendingInvite = pendingInvite
        self.onComposePost = onComposePost
        self.onAcceptInvite = onAcceptInvite
    }

    public var body: some View {
        Group {
            if let invite = pendingInvite {
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: CYSpacing.xs) {
                            Text(verbatim: "\(MerchantRemainingGapCopy.pendingTeamInviteTitle) · \(invite.merchantName)")
                                .cyText(.cardTitle)
                            Text(verbatim: invite.roleName).cyText(.meta).foregroundStyle(CYColor.textSecondary)
                        }
                        Spacer()
                        Button(MerchantRemainingGapCopy.acceptTeamInvite) {
                            onAcceptInvite(invite.id)
                        }
                        .buttonStyle(CYPillButtonStyle(style: .primary, fullWidth: false, compact: true))
                    }
                }
            }

            Section {
                Button(action: onComposePost) {
                    Label(MerchantRemainingGapCopy.composePost, systemImage: "square.and.pencil")
                        .cyText(.body)
                }
                if isRefreshing {
                    Text(verbatim: MerchantRemainingGapCopy.refreshingRelation)
                        .cyText(.meta)
                        .foregroundStyle(CYColor.textSecondary)
                }
                ForEach(posts) { post in
                    VStack(alignment: .leading, spacing: CYSpacing.xs) {
                        Text(verbatim: post.authorName).cyText(.cardTitle)
                        Text(verbatim: post.content).cyText(.body)
                    }
                    .padding(.vertical, CYSpacing.xs)
                }
            } header: {
                Text(verbatim: MerchantRemainingGapCopy.relationTabPosts).cyText(.sectionTitle)
            }
        }
    }
}
