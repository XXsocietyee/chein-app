import SwiftUI

/// Mount hook for `MerchantEngagementViews` / `MerchantBusinessViews` (`MC-G08`):
/// Export task banner (`生成中` / `已就绪 N 行` / `下载失败` / `已过期`).
public struct MerchantGapExportTaskBanner: View {
    public let state: MerchantCustomerExportBannerState
    public let onDownload: () -> Void
    public let onRetry: () -> Void

    public init(
        state: MerchantCustomerExportBannerState,
        onDownload: @escaping () -> Void,
        onRetry: @escaping () -> Void
    ) {
        self.state = state
        self.onDownload = onDownload
        self.onRetry = onRetry
    }

    public var body: some View {
        if state != .idle {
            Section {
                HStack {
                    Text(verbatim: state.title)
                        .cyText(.body)
                        .foregroundStyle(CYColor.textPrimary)
                    Spacer()
                    switch state {
                    case .ready:
                        Button("下载并打开", action: onDownload)
                            .buttonStyle(CYPillButtonStyle(style: .primary, fullWidth: false, compact: true))
                    case .downloadFailed, .expired, .failed:
                        Button("重新查询", action: onRetry)
                            .buttonStyle(CYPillButtonStyle(style: .secondary, fullWidth: false, compact: true))
                    case .generating:
                        ProgressView()
                    case .idle:
                        EmptyView()
                    }
                }
            }
        }
    }
}

/// Mount hook for `MerchantAftercareProgressView` (`MC-G09`):
/// Manual refund case detail (`工单编号`, `由平台处理`) + tappable `联系平台客服`.
public struct MerchantGapManualAftercareSection: View {
    public let manualCase: MerchantManualAftercareCase?
    public let onContactSupport: () -> Void

    public init(manualCase: MerchantManualAftercareCase?, onContactSupport: @escaping () -> Void) {
        self.manualCase = manualCase
        self.onContactSupport = onContactSupport
    }

    public var body: some View {
        Section {
            if let manualCase {
                LabeledContent(MerchantAftercareManualCopy.caseNoPrefix, value: manualCase.caseNo)
                    .cyText(.body)
                LabeledContent("当前状态", value: manualCase.statusText)
                    .cyText(.body)
                if let amountText = manualCase.amountText, !amountText.isEmpty {
                    LabeledContent("金额", value: amountText)
                        .cyText(.body)
                }
                Text(verbatim: MerchantAftercareManualCopy.platformHandled)
                    .cyText(.meta)
                    .foregroundStyle(CYColor.textSecondary)
            }
            Button(MerchantAftercareManualCopy.contactSupport, action: onContactSupport)
                .cyText(.body)
        }
    }
}

/// Mount hook for `MerchantStoreCharacterView` (`MC-G12`):
/// First-visit 4-step intro sheet.
public struct MerchantGapAINPCIntroSheet: View {
    @State private var stepIndex = 0
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        NavigationStack {
            VStack(spacing: CYSpacing.lg) {
                Spacer()
                let step = MerchantAINPCIntroCopy.steps[stepIndex]
                Text(verbatim: step.title)
                    .cyText(.sectionTitle)
                    .foregroundStyle(CYColor.textPrimary)
                    .multilineTextAlignment(.center)
                Text(verbatim: step.detail)
                    .cyText(.body)
                    .foregroundStyle(CYColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, CYSpacing.lg)
                Spacer()
                HStack(spacing: CYSpacing.md) {
                    if stepIndex > 0 {
                        Button(MerchantAINPCIntroCopy.prevStep) {
                            stepIndex -= 1
                        }
                        .buttonStyle(CYPillButtonStyle(style: .secondary, fullWidth: true))
                    }
                    if stepIndex < MerchantAINPCIntroCopy.steps.count - 1 {
                        Button(MerchantAINPCIntroCopy.nextStep) {
                            stepIndex += 1
                        }
                        .buttonStyle(CYPillButtonStyle(style: .primary, fullWidth: true))
                    } else {
                        Button(MerchantAINPCIntroCopy.gotIt) {
                            dismiss()
                        }
                        .buttonStyle(CYPillButtonStyle(style: .primary, fullWidth: true))
                    }
                }
                .padding(.horizontal, CYSpacing.lg)
                .padding(.bottom, CYSpacing.lg)
            }
            .cyPageTitle(verbatim: "AI 店铺角色引导")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(MerchantAINPCIntroCopy.skip) { dismiss() }
                }
            }
        }
    }
}

/// Mount hook for `CoopFlowNewInvitationView` (`MC-G17`):
/// Required `核销据点` multi-select picker per selected merchant.
public struct CoopGapSupplyStationPickerSection: View {
    public let stations: [CoopSupplyStation]
    @Binding public var selectedIDs: Set<Int>

    public init(stations: [CoopSupplyStation], selectedIDs: Binding<Set<Int>>) {
        self.stations = stations
        self._selectedIDs = selectedIDs
    }

    public var body: some View {
        Section {
            if stations.isEmpty {
                CYEmptyState(systemImage: "mappin.slash", verbatimTitle: "暂无可选核销据点")
            } else {
                ForEach(stations) { station in
                    let isSelected = selectedIDs.contains(station.id)
                    Button {
                        if isSelected {
                            selectedIDs.remove(station.id)
                        } else {
                            selectedIDs.insert(station.id)
                        }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                                Text(verbatim: station.name)
                                    .cyText(.body)
                                    .foregroundStyle(CYColor.textPrimary)
                                if let address = station.address, !address.isEmpty {
                                    Text(verbatim: address)
                                        .cyText(.meta)
                                        .foregroundStyle(CYColor.textSecondary)
                                }
                            }
                            Spacer()
                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(CYColor.brand)
                            }
                        }
                    }
                }
            }
        } header: {
            Text(verbatim: CoopListGapCopy.supplyStationHeader).cyText(.sectionTitle)
        }
    }
}

/// Mount hook for `CooperationNearbyView` (`MC-G18`):
/// Chapter replacement (选择补位操作) sheet.
public struct CoopGapNearbyReplacementSheet: View {
    public let merchants: [CoopInvitableMerchant]
    public let onInvite: (CoopInvitableMerchant) -> Void
    @Environment(\.dismiss) private var dismiss

    public init(merchants: [CoopInvitableMerchant], onInvite: @escaping (CoopInvitableMerchant) -> Void) {
        self.merchants = merchants
        self.onInvite = onInvite
    }

    public var body: some View {
        NavigationStack {
            List {
                if merchants.isEmpty {
                    CYEmptyState(systemImage: "storefront", verbatimTitle: "暂无可邀请补位的商家")
                } else {
                    ForEach(merchants) { merchant in
                        HStack {
                            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                                Text(verbatim: merchant.name).cyText(.cardTitle)
                                if let address = merchant.address, !address.isEmpty {
                                    Text(verbatim: address).cyText(.meta).foregroundStyle(CYColor.textSecondary)
                                }
                            }
                            Spacer()
                            Button("邀请补位") {
                                onInvite(merchant)
                                dismiss()
                            }
                            .buttonStyle(CYPillButtonStyle(style: .primary, fullWidth: false, compact: true))
                        }
                    }
                }
            }
            .cyPageTitle(verbatim: CoopListGapCopy.nearbyReplacementTitle)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
}
