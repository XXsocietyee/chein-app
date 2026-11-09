#if DEBUG
import SwiftUI

/// Gallery of every kit component (synthetic data). `--design-fixture kit` (player/dark) or `kit-merchant` (light).
struct KitGalleryFixture: View {
    let domain: ThemeDomain

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CYSpacing.xxl) {
                CYHeroHeader("Find your next quest", subtitle: "Synthetic kit gallery — debug only.")
                VStack(spacing: CYSpacing.md) {
                    CYPillButton("Continue", action: {})
                    CYPillButton("Continue with phone", style: .secondary, systemImage: "phone", action: {})
                    CYPillButton("Skip for now", style: .tertiary, action: {})
                }
                CYSectionHeader("Nearby", subtitle: "Image cards", actionTitle: "See all", action: {})
                CYImageCard("Night Market Quest", meta: "0.8 km · Open until 23:00")
                CYSectionHeader("Account")
                VStack(spacing: CYSpacing.md) {
                    CYListRow("Wallet", meta: "Balance and coupons", trailing: .valueChevron("¥128.50"), card: true) { CYRowIcon(systemImage: "creditcard") }
                    CYListRow("Orders", meta: "Unknown total", trailing: .value("—"), card: true) { CYRowIcon(systemImage: "bag") }
                }
                HStack(spacing: CYSpacing.sm) {
                    CYStatusChip("Pending")
                    CYStatusChip("Paid", tone: .success, systemImage: "checkmark")
                    CYStatusChip("Expiring", tone: .warning)
                    CYStatusChip("Refunded", tone: .danger)
                }
                CYSectionHeader("States")
                CYEmptyState(systemImage: "ticket", "No tickets yet", actionTitle: "Browse quests", action: {})
                CYErrorState(onRetry: {})
                CYSkeleton()
            }
            .padding(.horizontal, CYSpacing.pageHorizontal)
            .padding(.vertical, CYSpacing.lg)
        }
        .cyDomainPageBackground()
        .themeDomain(domain)
    }
}
#endif
