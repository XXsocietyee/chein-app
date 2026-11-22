import SwiftUI

struct MerchantLedgerNetSummary: View {
    let presentation: MerchantLedgerNetPresentation
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s2) {
            Text("merchant.business.field.personalArrivedThisMonthNet")
                .font(.subheadline).foregroundStyle(.secondary)
            if let amount = presentation.amount {
                Text(verbatim: amount).cyText(.pageTitle).monospacedDigit()
            } else {
                Text("merchant.business.amountPending")
                    .cyText(.sectionTitle).foregroundStyle(.secondary)
            }
            Text(LocalizedStringKey(presentation.titleKey))
                .cyText(.bodyCompact).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.vertical, Theme.Space.s2)
        .accessibilityElement(children: .combine)
    }
}

struct MerchantLedgerRefundPreviewSections<Row: View, More: View>: View {
    let preview: MerchantLedgerRefundPreview
    let row: (MerchantBusinessRecord) -> Row
    let more: (MerchantAftercareBucket) -> More
    var body: some View {
        Section("merchant.refundPreview.title") {
            Text("merchant.refundPreview.boundary").cyText(.bodyCompact).foregroundStyle(.secondary)
            if !preview.included { Text("merchant.refundPreview.notIncluded") }
            if preview.loading { ProgressView("merchant.loading") }
        }
        ForEach(preview.pages) { page in
            Section(LocalizedStringKey("merchant.business.bucket." + page.bucket.rawValue)) {
                if page.failed { Text("merchant.refundPreview.failed").foregroundStyle(.secondary) }
                else {
                    if page.rows.isEmpty { Text("merchant.refundPreview.empty") }
                    ForEach(page.rows, id: \.id) { value in
                        row(value).id(page.rowIdentity(value))
                    }
                    if page.hasMore { Text("merchant.refundPreview.moreAvailable").cyText(.bodyCompact) }
                }
                more(page.bucket)
            }
        }
    }
}
