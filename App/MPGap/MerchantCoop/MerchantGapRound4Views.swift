import SwiftUI
#if canImport(MapKit)
import MapKit
#endif

/// Mount hook for `MerchantLedgerBatchDetailView` (`MC7-08-2`):
/// `打款凭证 {payVoucherNo}` + copy button.
public struct MerchantGapBatchVoucherRow: View {
    public let payVoucherNo: String
    public let onCopy: (String) -> Void

    public init(payVoucherNo: String, onCopy: @escaping (String) -> Void) {
        self.payVoucherNo = payVoucherNo
        self.onCopy = onCopy
    }

    public var body: some View {
        if !payVoucherNo.isEmpty {
            HStack {
                Text(verbatim: "\(MerchantRound4Copy.payoutVoucherPrefix) \(payVoucherNo)")
                    .cyText(.body)
                    .foregroundStyle(CYColor.textPrimary)
                Spacer()
                Button("复制") {
                    onCopy(payVoucherNo)
                }
                .buttonStyle(CYPillButtonStyle(style: .secondary, fullWidth: false, compact: true))
            }
        }
    }
}

/// Mount hook for `MerchantMarketingView` (`MC7-11-2`):
/// Store avatar/logo + daily heat grid with axis + 俱乐部合作 pool cards.
public struct MerchantGapAIInsightExtraSection: View {
    public let storeName: String
    public let storeLogoURL: URL?
    public let heatCells: [MerchantAIInsightDailyHeatCell]
    public let axisFromLabel: String
    public let poolCards: [ClubCoopPoolCardItem]
    public let onOpenCoopPool: () -> Void

    public init(
        storeName: String,
        storeLogoURL: URL?,
        heatCells: [MerchantAIInsightDailyHeatCell],
        axisFromLabel: String,
        poolCards: [ClubCoopPoolCardItem],
        onOpenCoopPool: @escaping () -> Void
    ) {
        self.storeName = storeName
        self.storeLogoURL = storeLogoURL
        self.heatCells = heatCells
        self.axisFromLabel = axisFromLabel
        self.poolCards = poolCards
        self.onOpenCoopPool = onOpenCoopPool
    }

    public var body: some View {
        Group {
            Section {
                HStack(spacing: CYSpacing.md) {
                    if let storeLogoURL {
                        CYAvatarView(url: storeLogoURL, name: storeName, size: .lg)
                    } else {
                        MPAsset.AvatarDefault.dProfile
                            .resizable()
                            .scaledToFill()
                            .frame(width: 56, height: 56)
                            .clipShape(Circle())
                    }
                    VStack(alignment: .leading, spacing: CYSpacing.xs) {
                        Text(verbatim: storeName.isEmpty ? "我的门店" : storeName)
                            .cyText(.cardTitle)
                            .foregroundStyle(CYColor.textPrimary)
                        Text(verbatim: MerchantAIInsightCopy.pageTitle)
                            .cyText(.meta)
                            .foregroundStyle(CYColor.textSecondary)
                    }
                }
            }

            if !heatCells.isEmpty {
                Section {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: CYSpacing.xs), count: 7), spacing: CYSpacing.xs) {
                        ForEach(heatCells) { cell in
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(cell.level > 0 ? CYColor.brand.opacity(min(1.0, 0.25 + Double(cell.level) * 0.2)) : CYColor.bgSurfaceSubtle)
                                .frame(height: 18)
                                .accessibilityLabel("\(cell.date) \(cell.count)")
                        }
                    }
                    HStack {
                        Text(verbatim: axisFromLabel).cyText(.meta).foregroundStyle(CYColor.textSecondary)
                        Spacer()
                        Text(verbatim: MerchantRound4Copy.heatAxisToday).cyText(.meta).foregroundStyle(CYColor.textSecondary)
                    }
                } header: {
                    Text(verbatim: "每日热力").cyText(.sectionTitle)
                }
            }

            if !poolCards.isEmpty {
                Section {
                    ForEach(poolCards) { card in
                        Button(action: onOpenCoopPool) {
                            HStack {
                                VStack(alignment: .leading, spacing: CYSpacing.xs) {
                                    Text(verbatim: card.name).cyText(.cardTitle).foregroundStyle(CYColor.textPrimary)
                                    if let sub = card.subtitle, !sub.isEmpty {
                                        Text(verbatim: sub).cyText(.meta).foregroundStyle(CYColor.textSecondary)
                                    }
                                }
                                Spacer()
                                CYStatusChip(verbatim: card.stateText, tone: card.isTaken ? .neutral : .info)
                            }
                        }
                    }
                } header: {
                    Text(verbatim: MerchantRound4Copy.clubPoolSectionTitle).cyText(.sectionTitle)
                }
            }
        }
    }
}

/// Mount hook for `MerchantOperationsViews` (`MC7-20-1` & `MC7-22-1`):
/// Inactive identity `ContentUnavailableView` for gallery & coop-setting + silent refresh banner.
public struct MerchantGapDecorInactiveEmptyView: View {
    public let title: String
    public let onGoOnboarding: () -> Void

    public init(title: String, onGoOnboarding: @escaping () -> Void) {
        self.title = title
        self.onGoOnboarding = onGoOnboarding
    }

    public var body: some View {
        ContentUnavailableView {
            VStack(spacing: CYSpacing.sm) {
                MPAsset.FeatureIcon.iconShop
                    .resizable()
                    .scaledToFit()
                    .frame(width: 36, height: 36)
                Text(verbatim: title).cyText(.cardTitle)
            }
        } actions: {
            Button(MerchantRemainingGapCopy.goOnboardingCTA, action: onGoOnboarding)
                .buttonStyle(CYPillButtonStyle(style: .primary, fullWidth: false))
        }
    }
}

/// Mount hook for `MerchantCityNodeHubView` (`MC7-24-6`) & `MerchantCityNodeCreateView` (`MC7-25-4`):
/// Selectable monospaced `codeText` fallback & MapKit preview button for picked address.
public struct MerchantGapCityNodePosterAndMapViews: View {
    public let codeText: String
    public let addressTitle: String
    public let latitude: Double?
    public let longitude: Double?

    public init(codeText: String, addressTitle: String, latitude: Double? = nil, longitude: Double? = nil) {
        self.codeText = codeText
        self.addressTitle = addressTitle
        self.latitude = latitude
        self.longitude = longitude
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            if !codeText.isEmpty {
                Text(verbatim: codeText)
                    .cyText(.numericBody)
                    .textSelection(.enabled)
                    .foregroundStyle(CYColor.textPrimary)
            }
            if !addressTitle.isEmpty {
                Button(action: openMap) {
                    HStack(spacing: CYSpacing.xs) {
                        MPAsset.FeatureIcon.pin
                            .resizable()
                            .scaledToFit()
                            .frame(width: 16, height: 16)
                        Text(verbatim: addressTitle).cyText(.body)
                    }
                }
            }
        }
    }

    private func openMap() {
        #if canImport(MapKit)
        guard let latitude, let longitude, latitude.isFinite, longitude.isFinite else { return }
        let item = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude)))
        item.name = addressTitle
        item.openInMaps()
        #endif
    }
}

/// Mount hook for `CooperationBrowserView` (`MC7-30-9`..`MC7-30-12`) & `CooperationInviteActionSections` (`MC7-32-6`):
/// Coop list actions (`回邀约`, `发邀约`, `再邀别人`, `去收到的确认`) & TEST-only `去缴纳保证金`.
public struct CoopGapListAndDepositActionsView: View {
    public let showsReplyInvite: Bool
    public let showsSendInvite: Bool
    public let showsInviteOthers: Bool
    public let showsGoReceivedConfirm: Bool
    public let showsPayDeposit: Bool
    public let allowsMoneyWrite: Bool
    public let onReplyInvite: () -> Void
    public let onSendInvite: () -> Void
    public let onInviteOthers: () -> Void
    public let onGoReceivedConfirm: () -> Void
    public let onPayDeposit: () -> Void

    public init(
        showsReplyInvite: Bool = false,
        showsSendInvite: Bool = false,
        showsInviteOthers: Bool = false,
        showsGoReceivedConfirm: Bool = false,
        showsPayDeposit: Bool = false,
        allowsMoneyWrite: Bool = false,
        onReplyInvite: @escaping () -> Void = {},
        onSendInvite: @escaping () -> Void = {},
        onInviteOthers: @escaping () -> Void = {},
        onGoReceivedConfirm: @escaping () -> Void = {},
        onPayDeposit: @escaping () -> Void = {}
    ) {
        self.showsReplyInvite = showsReplyInvite
        self.showsSendInvite = showsSendInvite
        self.showsInviteOthers = showsInviteOthers
        self.showsGoReceivedConfirm = showsGoReceivedConfirm
        self.showsPayDeposit = showsPayDeposit
        self.allowsMoneyWrite = allowsMoneyWrite
        self.onReplyInvite = onReplyInvite
        self.onSendInvite = onSendInvite
        self.onInviteOthers = onInviteOthers
        self.onGoReceivedConfirm = onGoReceivedConfirm
        self.onPayDeposit = onPayDeposit
    }

    public var body: some View {
        HStack(spacing: CYSpacing.sm) {
            if showsReplyInvite {
                Button(CoopListGapCopy.replyInvite, action: onReplyInvite)
                    .buttonStyle(CYPillButtonStyle(style: .primary, fullWidth: false, compact: true))
            }
            if showsSendInvite {
                Button("发邀约", action: onSendInvite)
                    .buttonStyle(CYPillButtonStyle(style: .primary, fullWidth: false, compact: true))
            }
            if showsInviteOthers {
                Button(CoopListGapCopy.inviteOthers, action: onInviteOthers)
                    .buttonStyle(CYPillButtonStyle(style: .secondary, fullWidth: false, compact: true))
            }
            if showsGoReceivedConfirm {
                Button(CoopListGapCopy.goReceivedConfirm, action: onGoReceivedConfirm)
                    .buttonStyle(CYPillButtonStyle(style: .secondary, fullWidth: false, compact: true))
            }
            if showsPayDeposit && allowsMoneyWrite {
                Button(MerchantRound4Copy.depositPayButton, action: onPayDeposit)
                    .buttonStyle(CYPillButtonStyle(style: .primary, fullWidth: false, compact: true))
            }
        }
    }
}

/// Mount hook for `CooperationContextualViews` (`MC7-31-3`, `MC7-31-4`, `MC7-31-6`, `MC7-31-7`, `MC7-31-9`):
/// Locked topic/target rows, empty topic CTA, single-select supply station, and terms-rejected CTA.
public struct CoopGapInvitePresetsSection: View {
    public let lockedTopicTitle: String?
    public let lockedTarget: CoopInviteLockedTarget?
    public let hasTopics: Bool
    public let stations: [CoopSupplyStation]
    @Binding public var selectedStationID: Int?
    public let showsFixTermsCTA: Bool
    public let onPublishTopic: () -> Void
    public let onFixTerms: () -> Void

    public init(
        lockedTopicTitle: String? = nil,
        lockedTarget: CoopInviteLockedTarget? = nil,
        hasTopics: Bool = true,
        stations: [CoopSupplyStation] = [],
        selectedStationID: Binding<Int?> = .constant(nil),
        showsFixTermsCTA: Bool = false,
        onPublishTopic: @escaping () -> Void = {},
        onFixTerms: @escaping () -> Void = {}
    ) {
        self.lockedTopicTitle = lockedTopicTitle
        self.lockedTarget = lockedTarget
        self.hasTopics = hasTopics
        self.stations = stations
        self._selectedStationID = selectedStationID
        self.showsFixTermsCTA = showsFixTermsCTA
        self.onPublishTopic = onPublishTopic
        self.onFixTerms = onFixTerms
    }

    public var body: some View {
        Group {
            if let lockedTopicTitle, !lockedTopicTitle.isEmpty {
                Section {
                    HStack {
                        Text(verbatim: lockedTopicTitle).cyText(.body)
                        Spacer()
                        CYStatusChip(verbatim: MerchantRound4Copy.targetLockedChip, tone: .neutral)
                    }
                } header: {
                    Text(verbatim: "关联主题").cyText(.sectionTitle)
                }
            } else if !hasTopics {
                Section {
                    CYEmptyState(
                        systemImage: "sparkles",
                        LocalizedStringKey(MerchantRound4Copy.emptyTopicsTitle),
                        actionTitle: LocalizedStringKey(MerchantRound4Copy.publishTopicFirst),
                        action: onPublishTopic
                    )
                }
            }

            if let lockedTarget {
                Section {
                    HStack {
                        Text(verbatim: lockedTarget.name).cyText(.body)
                        Spacer()
                        CYStatusChip(verbatim: MerchantRound4Copy.targetLockedChip, tone: .neutral)
                    }
                } header: {
                    Text(verbatim: "合作对象").cyText(.sectionTitle)
                }
            }

            if !stations.isEmpty {
                Section {
                    ForEach(stations) { station in
                        Button {
                            selectedStationID = station.id
                        } label: {
                            HStack {
                                Text(verbatim: station.name).cyText(.body).foregroundStyle(CYColor.textPrimary)
                                Spacer()
                                if selectedStationID == station.id {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(CYColor.brand)
                                }
                            }
                        }
                    }
                } header: {
                    Text(verbatim: CoopListGapCopy.supplyStationHeader).cyText(.sectionTitle)
                }
            }

            if showsFixTermsCTA {
                Section {
                    Button(MerchantRound4Copy.fixTermsCTA, action: onFixTerms)
                        .cyText(.body)
                        .foregroundStyle(CYColor.brand)
                }
            }
        }
    }
}
