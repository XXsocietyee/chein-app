#if DEBUG
import SwiftUI

/// Gallery of every kit component (synthetic data). `--design-fixture kit` (player/dark) or `kit-merchant` (light).
struct KitGalleryFixture: View {
    let domain: ThemeDomain
    var lower = false

    var body: some View {
        gallery
            .themeDomain(domain)
            .cyDomainPageBackground()
            .themeDomain(domain)
    }

    private var gallery: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CYSpacing.xxl) {
                if !lower {
                CYHeroHeader("Find your next quest", subtitle: "Synthetic kit gallery — debug only.")
                VStack(spacing: CYSpacing.md) {
                    CYPillButton("Continue", action: {})
                    CYPillButton("Continue with phone", style: .secondary, systemImage: "phone", action: {})
                    CYPillButton("Skip for now", style: .tertiary, action: {})
                }
                CYSectionHeader("Nearby", subtitle: "Image cards", actionTitle: "See all", action: {})
                CYImageCard("Night Market Quest", meta: "0.8 km · Open until 23:00")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: CYSpacing.md) {
                        CYImageCard("Lantern Walk", meta: "1.2 km", style: .shelf)
                        CYImageCard("Harbour Trail", meta: "2.4 km", style: .shelf)
                    }
                }
                } else {
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
                CYSectionHeader("Loading")
                CYSkeleton()
                CYSectionHeader("Empty / error")
                CYEmptyState(systemImage: "ticket", "No tickets yet", actionTitle: "Browse quests", action: {})
                CYErrorState(onRetry: {})
                }
            }
            .padding(.horizontal, CYSpacing.pageHorizontal)
            .padding(.vertical, CYSpacing.lg)
        }
    }
}
#endif
