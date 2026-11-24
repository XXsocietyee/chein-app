import SwiftUI

/// `MKT-7-1` / `MKT-7-3`: Free-explore bundle receipt view, unit status/validity rows, and `售后记录`.
public struct FreeExploreBundleReceiptView: View {
    public let summary: FreeExploreReceiptSummary
    public var onReserveUnit: (FreeExploreBundleUnitItem) -> Void = { _ in }
    public var onSwapMerchant: (FreeExploreBundleUnitItem) -> Void = { _ in }

    public init(
        summary: FreeExploreReceiptSummary,
        onReserveUnit: @escaping (FreeExploreBundleUnitItem) -> Void = { _ in },
        onSwapMerchant: @escaping (FreeExploreBundleUnitItem) -> Void = { _ in }
    ) {
        self.summary = summary
        self.onReserveUnit = onReserveUnit
        self.onSwapMerchant = onSwapMerchant
    }

    public var body: some View {
        List {
            Section {
                LabeledContent("bundle.receipt.orderNo", value: summary.registrationNo)
                    .cyText(.bodyCompact)
                LabeledContent("bundle.receipt.payment", value: summary.paymentText)
                    .cyText(.bodyCompact)
                LabeledContent("bundle.receipt.registration", value: summary.registrationText)
                    .cyText(.bodyCompact)
            }

            if !summary.units.isEmpty {
                Section("bundle.units.title") {
                    ForEach(summary.units) { unit in
                        VStack(alignment: .leading, spacing: CYSpacing.xs) {
                            HStack {
                                Text("\(unit.chapterName) · \(unit.statusText)")
                                    .cyText(.cardTitle)
                                Spacer()
                            }
                            if let content = unit.content, !content.isEmpty {
                                Text(content)
                                    .cyText(.bodyCompact)
                                    .foregroundStyle(CYColor.textSecondary)
                            }
                            Text("有效期至 \(unit.validTo)")
                                .cyText(.meta, monospacedDigit: true)
                                .foregroundStyle(CYColor.textSecondary)
                            if unit.canReserve || unit.canSwapMerchant {
                                HStack(spacing: CYSpacing.sm) {
                                    if unit.canReserve {
                                        Button("bundle.unit.reserve") { onReserveUnit(unit) }
                                            .buttonStyle(.bordered)
                                    }
                                    if unit.canSwapMerchant {
                                        Button("bundle.unit.swap") { onSwapMerchant(unit) }
                                            .buttonStyle(.bordered)
                                    }
                                }
                                .padding(.top, CYSpacing.xs)
                            }
                        }
                        .padding(.vertical, CYSpacing.xs)
                    }
                }
            }

            if !summary.exitCases.isEmpty {
                Section("bundle.exitCases.title") {
                    ForEach(summary.exitCases) { item in
                        Text(item.text)
                            .cyText(.bodyCompact)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .cyPageTitle("bundle.receipt.title")
    }
}
