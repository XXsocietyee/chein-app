import SwiftUI

/// Source pages/merchant/customer/index.wxml row: name, tier badge (pending in warning), "备注" badge,
/// "lastAction · relative time" and the latest note. Phone/contact stays in the existing contact entry.
struct MerchantCustomerRowLabel: View {
    let row: MerchantCustomerListParity.Row
    let identifier: String
    /// MC7-14-11 (customer/index.wxml:71): 44 pt avatar, MP default-avatar fallback.
    var avatarURL: URL? = nil
    var body: some View {
        HStack(alignment: .top, spacing: CYSpacing.sm) {
        // Round 2 MP asset: no avatar → /images/d_profile.png (customer/index.wxml:71).
        MerchantMPAvatar(url: avatarURL, size: 44)
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            HStack(spacing: CYSpacing.s1_5) {
                Text(verbatim: row.name ?? MerchantOpsCopy.text("merchantOps.customer.unnamed"))
                    .cyText(.cardTitle)
                    .foregroundStyle(CYColor.textPrimary)
                if let tier = row.tierKey {
                    CYStatusChip(verbatim: MerchantOpsCopy.text(tier), tone: row.tierUrgent ? .warning : .neutral)
                }
                if row.latestNote != nil {
                    CYStatusChip(verbatim: MerchantOpsCopy.text("merchantOps.customer.noteBadge"), tone: .neutral)
                }
            }
            let action = [row.lastAction, row.relative.map(Self.relative)].compactMap { $0 }.joined(separator: " · ")
            if !action.isEmpty { Text(verbatim: action).cyText(.meta).foregroundStyle(CYColor.textSecondary) }
            if let note = row.latestNote { Text(verbatim: note).cyText(.meta).foregroundStyle(CYColor.textSecondary).lineLimit(2) }
        }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
    }
    static func relative(_ value: MerchantCustomerListParity.Relative) -> String {
        switch value {
        case .today: return MerchantOpsCopy.text("merchantOps.customer.relative.today")
        case .yesterday: return MerchantOpsCopy.text("merchantOps.customer.relative.yesterday")
        case .days(let n): return MerchantOpsCopy.text("merchantOps.customer.relative.days %lld", n)
        case .months(let n): return MerchantOpsCopy.text("merchantOps.customer.relative.months %lld", n)
        case .years(let n): return MerchantOpsCopy.text("merchantOps.customer.relative.years %lld", n)
        }
    }
}

/// Source customer hero subtitle and list footer.
struct MerchantCustomerListHero: View {
    let summary: MerchantCustomerListParity.Summary?
    var body: some View {
        Group {
            switch summary {
            case .totalWithMonthly(let total, let monthly): Text(verbatim: MerchantOpsCopy.text("merchantOps.customer.summary.monthly %lld %lld", total, monthly))
            case .total(let total): Text(verbatim: MerchantOpsCopy.text("merchantOps.customer.summary.total %lld", total))
            case nil: Text(verbatim: MerchantOpsCopy.text("merchantOps.customer.summary.unavailable"))
            }
        }.cyText(.meta).monospacedDigit().foregroundStyle(CYColor.textSecondary).accessibilityIdentifier("merchantOps.customer.summary")
    }
}
struct MerchantCustomerListFooter: View {
    let total: Int
    var body: some View {
        Text(verbatim: MerchantOpsCopy.text("merchantOps.customer.footer %lld", total))
            .cyText(.meta)
            .monospacedDigit()
            .foregroundStyle(CYColor.textSecondary)
            .frame(maxWidth: .infinity)
            .accessibilityIdentifier("merchantOps.customer.footer")
    }
}

#Preview("MerchantCustomerListFooter · light") {
    MerchantCustomerListFooter(total: 128).padding().preferredColorScheme(.light)
}
#Preview("MerchantCustomerListFooter · dark sanity") {
    MerchantCustomerListFooter(total: 128).padding().preferredColorScheme(.dark)
}

/// Source customer/detail identity line: "最近互动 M月D日" or "尚无互动记录".
struct MerchantCustomerIdentityLine: View {
    let lastInteraction: Date?
    var body: some View {
        Group {
            if let day = MerchantCustomerListParity.identityDay(lastInteraction) {
                Text(verbatim: MerchantOpsCopy.text("merchantOps.customer.identity.recent %lld %lld", day.month, day.day))
            } else { Text(verbatim: MerchantOpsCopy.text("merchantOps.customer.identity.none")) }
        }.cyText(.meta).foregroundStyle(CYColor.textSecondary).accessibilityIdentifier("merchantOps.customer.identity")
    }
}

struct MerchantCustomerNoteEditorAccessory: View {
    let text: String
    var onClear: () -> Void = {}
    var body: some View {
        HStack {
            Text("merchant.customer.noteVisibility")
                .cyText(.meta)
                .foregroundStyle(CYColor.textSecondary)
            Spacer()
            Text(verbatim: MerchantCustomerListParity.noteCounterText(text))
                .cyText(.meta, monospacedDigit: true)
                .foregroundStyle(CYColor.textSecondary)
                .accessibilityIdentifier("merchantOps.customer.noteCounter")
            if !text.isEmpty {
                Button(action: onClear) {
                    Text(verbatim: "×")
                }
                .accessibilityIdentifier("merchantOps.customer.noteClear")
            }
        }
    }
}
