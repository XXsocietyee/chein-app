import SwiftUI

/// Mount hook for `MerchantAIInsightView` (`MC-G07`):
/// Window switch (`近7天`/`近30天`/`近90天`), 客源主题 bars, 经营解读, and 经营优化 cards.
public struct MerchantGapAIInsightDashboardSection: View {
    @Binding public var selectedWindow: MerchantAIInsightWindow
    @Binding public var selectedMetric: MerchantAIInsightMetricKind
    public let storeName: String
    public let windowLabel: String
    public let sources: [MerchantAIInsightSourceItem]
    public let opportunityText: String?
    public let problemText: String?
    public let lowSample: Bool
    public let growTips: [MerchantAIInsightGrowTip]
    public let onSelectGrowTip: (MerchantAIInsightGrowTip.Key) -> Void

    public init(
        selectedWindow: Binding<MerchantAIInsightWindow>,
        selectedMetric: Binding<MerchantAIInsightMetricKind>,
        storeName: String,
        windowLabel: String,
        sources: [MerchantAIInsightSourceItem],
        opportunityText: String? = nil,
        problemText: String? = nil,
        lowSample: Bool = false,
        growTips: [MerchantAIInsightGrowTip],
        onSelectGrowTip: @escaping (MerchantAIInsightGrowTip.Key) -> Void
    ) {
        self._selectedWindow = selectedWindow
        self._selectedMetric = selectedMetric
        self.storeName = storeName
        self.windowLabel = windowLabel
        self.sources = sources
        self.opportunityText = opportunityText
        self.problemText = problemText
        self.lowSample = lowSample
        self.growTips = growTips
        self.onSelectGrowTip = onSelectGrowTip
    }

    public var body: some View {
        Group {
            Section {
                Picker("统计周期", selection: $selectedWindow) {
                    ForEach(MerchantAIInsightWindow.allCases) { window in
                        Text(verbatim: window.title).tag(window)
                    }
                }
                .pickerStyle(.segmented)

                Picker("核心指标", selection: $selectedMetric) {
                    ForEach(MerchantAIInsightMetricKind.allCases) { metric in
                        Text(verbatim: metric.label).tag(metric)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                if !storeName.isEmpty {
                    Text(verbatim: "你好，\(storeName)").cyText(.sectionTitle)
                }
            }

            if !sources.isEmpty {
                Section {
                    ForEach(Array(sources.enumerated()), id: \.offset) { _, source in
                        VStack(alignment: .leading, spacing: CYSpacing.xs) {
                            HStack {
                                Text(verbatim: source.name)
                                    .cyText(.body)
                                    .foregroundStyle(CYColor.textPrimary)
                                Spacer()
                                Text(verbatim: "\(source.count) 次 · \(source.pct)")
                                    .cyText(.meta)
                                    .foregroundStyle(CYColor.textSecondary)
                            }
                            ProgressView(value: min(max(source.widthPercent / 100.0, 0), 1))
                        }
                        .padding(.vertical, CYSpacing.xs)
                    }
                } header: {
                    HStack {
                        Text(verbatim: MerchantAIInsightCopy.sourceSectionTitle).cyText(.sectionTitle)
                        Spacer()
                        Text(verbatim: windowLabel).cyText(.meta).foregroundStyle(CYColor.textSecondary)
                    }
                }
            }

            if (opportunityText != nil && !(opportunityText ?? "").isEmpty) || (problemText != nil && !(problemText ?? "").isEmpty) {
                Section {
                    if let opportunityText, !opportunityText.isEmpty {
                        VStack(alignment: .leading, spacing: CYSpacing.xs) {
                            CYStatusChip(verbatim: MerchantAIInsightCopy.opportunityTag, tone: .success)
                            Text(verbatim: opportunityText).cyText(.body)
                        }
                        .padding(.vertical, CYSpacing.xs)
                    }
                    if let problemText, !problemText.isEmpty {
                        VStack(alignment: .leading, spacing: CYSpacing.xs) {
                            CYStatusChip(verbatim: MerchantAIInsightCopy.problemTag, tone: .warning)
                            Text(verbatim: problemText).cyText(.body)
                        }
                        .padding(.vertical, CYSpacing.xs)
                    }
                } header: {
                    Text(verbatim: MerchantAIInsightCopy.aiSectionTitle).cyText(.sectionTitle)
                } footer: {
                    if lowSample {
                        Text(verbatim: MerchantAIInsightCopy.lowSampleNote).cyText(.meta)
                    }
                }
            }

            if !growTips.isEmpty {
                Section {
                    ForEach(growTips) { tip in
                        Button {
                            onSelectGrowTip(tip.key)
                        } label: {
                            HStack(spacing: CYSpacing.sm) {
                                growTipCover(for: tip.key)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 44, height: 44)
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                VStack(alignment: .leading, spacing: CYSpacing.xs) {
                                    Text(verbatim: tip.title)
                                        .cyText(.cardTitle)
                                        .foregroundStyle(CYColor.textPrimary)
                                    Text(verbatim: tip.subtitle)
                                        .cyText(.meta)
                                        .foregroundStyle(CYColor.textSecondary)
                                }
                                Spacer()
                                CYStatusChip(verbatim: tip.cta, tone: .info)
                            }
                        }
                    }
                } header: {
                    Text(verbatim: MerchantAIInsightCopy.growSectionTitle).cyText(.sectionTitle)
                }
            }
        }
    }

    private func growTipCover(for key: MerchantAIInsightGrowTip.Key) -> (Image) {
        switch key {
        case .coop: return MPAsset.BannerCover.treasureHunter
        case .citynode: return MPAsset.BannerCover.flavorTour
        case .coupon: return MPAsset.BannerCover.midlifeDay
        case .aiNpc: return MPAsset.BannerCover.oldMovie
        }
    }
}
