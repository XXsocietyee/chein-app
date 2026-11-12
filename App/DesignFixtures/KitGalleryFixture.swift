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
                if domain == .player { KitNightLightSection() }
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

/// "Night light" (wave 3 B1): foil on seals and a pass under gyro (DEBUG `--uitesting-fake-tilt` sweeps roll in the
/// simulator), night glass over a lantern-lit ground, and the glow recipe. Reduce Motion shows the static highlight.
private struct KitNightLightSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.lg) {
            Text(verbatim: "NIGHT LIGHT")
                .font(.footnote.weight(.semibold)).kerning(0.6)
                .foregroundStyle(CYNight.lantern)
            HStack(spacing: CYSpacing.lg) {
                ForEach(0..<3, id: \.self) { i in
                    StampSeal(size: 96, stamped: true)
                        .frame(width: 96, height: 96)
                        .background(Circle().fill(CYNight.ink1))
                        .cyFoil(in: Circle())
                        .accessibilityIdentifier("kit.nightlight.seal.\(i)")
                }
            }
            .frame(maxWidth: .infinity)
            pass
            glassOverLight
        }
        .padding(CYSpacing.lg)
        .background(RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous).fill(CYNight.ink0))
        .accessibilityIdentifier("kit.nightlight")
    }

    private var pass: some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            Text(verbatim: "NIGHT MARKET PASS").font(.footnote.weight(.semibold)).kerning(0.6).foregroundStyle(.white.opacity(0.6))
            Text(verbatim: "Lantern Walk").font(.system(.title, design: .rounded).weight(.heavy)).foregroundStyle(.white)
            Spacer(minLength: 0)
            Text(verbatim: "No. 0042 · Admit one").font(.footnote.monospacedDigit()).foregroundStyle(.white.opacity(0.7))
        }
        .padding(CYSpacing.lg)
        .frame(maxWidth: .infinity, minHeight: 148, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous).fill(CYNight.ink2))
        .cyFoil(cornerRadius: CYRadius.lg)
        .accessibilityIdentifier("kit.nightlight.pass")
    }

    private var glassOverLight: some View {
        ZStack {
            LinearGradient(colors: [CYNight.indigo, CYNight.ink0], startPoint: .top, endPoint: .bottom)
            Circle().fill(CYNight.glow(radius: 60)).frame(width: 190, height: 190).offset(x: 70, y: 10)
            Circle().fill(CYNight.lanternHot).frame(width: 14, height: 14).offset(x: 70, y: 10)
            Text(verbatim: "Night glass")
                .font(.body.weight(.semibold)).foregroundStyle(.white)
                .padding(.horizontal, CYSpacing.lg).padding(.vertical, CYSpacing.md)
                .cyNightGlass(in: Capsule())
                .offset(x: -50, y: 0)
        }
        .frame(height: 120)
        .clipShape(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
        .accessibilityIdentifier("kit.nightlight.glass")
    }
}
#endif
