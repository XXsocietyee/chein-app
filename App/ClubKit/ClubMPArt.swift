import SwiftUI

// fix/r3-club-b round 2: mini-program artwork on the club ops pages (badges, check-in detail, join requests,
// customers, settlement, payout receiver). Owner MP-asset rule: brand/feature art, avatar defaults and
// empty-state illustrations are the MP files (`MPAsset`); system-control glyphs stay SF Symbols.

/// Avatar with the MP default face. The MP pages that write `{{item.avatar || '/images/d_profile.png'}}`
/// (badges picker, check-in detail, join requests) show `images/d_profile.png` when there is no photo, not
/// an initial. `cy-avatar` with a name shows the initial and falls back to the same file only with no name,
/// so `usesDefaultFace: false` keeps the monogram whenever a name exists.
struct ClubMPAvatar: View {
    var url: URL?
    var name: String
    var size: CYAvatarSize = .md
    var usesDefaultFace = true
    @ScaledMetric(relativeTo: .body) private var scaleFactor: CGFloat = 1.0

    private var httpsURL: URL? {
        guard let url, url.scheme?.lowercased() == "https" else { return nil }
        return url
    }

    private var showsDefaultFace: Bool {
        httpsURL == nil && (usesDefaultFace || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    var body: some View {
        if showsDefaultFace {
            // Same clamp as `CYAvatarView`, so rows keep one avatar size at every Dynamic Type step.
            let side = size.rawValue * min(max(scaleFactor, 0.85), 1.35)
            MPAsset.AvatarDefault.dProfile
                .resizable()
                .scaledToFill()
                .frame(width: side, height: side)
                .clipShape(Circle())
                .accessibilityHidden(true)
        } else {
            CYAvatarView(url: httpsURL, name: name, size: size)
        }
    }
}

/// `cy-empty kind="empty"`: the MP two-layer illustration (`empty_state_bg.svg` + `empty_state_figure.svg`)
/// above the title, on the system `ContentUnavailableView`. Other kinds (no-permission, error, missing-param)
/// use a line glyph in the MP too, so they stay on `CYEmptyState`.
struct ClubMPEmptyState: View {
    let title: Text
    var detail: Text? = nil
    var messageIdentifier: String? = nil
    @ScaledMetric(relativeTo: .title) private var artSide: CGFloat = 120

    var body: some View {
        ContentUnavailableView {
            VStack(spacing: CYSpacing.md) {
                ZStack {
                    MPAsset.EmptyState.emptyStateBg.resizable().scaledToFit()
                    MPAsset.EmptyState.emptyStateFigure.resizable().scaledToFit()
                }
                .frame(width: artSide, height: artSide)
                .accessibilityHidden(true)
                title
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
            }
        } description: {
            if let detail { detail }
        }
        .accessibilityElement(children: .contain)
        .ifLet(messageIdentifier) { $0.accessibilityIdentifier($1) }
    }
}

/// Owner decision 9 (11-24): money reads with two decimals (¥12.50) through the one shared formatter,
/// `MoneyDisplay`. Server amount text is formatted lexically (no Double round trip). A leading ¥ or sign is
/// kept; anything that is not a plain decimal amount (「待核验」, 「—」, 「¥1,200」) is shown as sent.
enum ClubMoneyText {
    static func display(_ raw: String) -> String {
        var body = raw.trimmingCharacters(in: .whitespaces)
        var sign = ""
        if body.hasPrefix("-") || body.hasPrefix("+") { sign = String(body.removeFirst()) }
        var hadYuan = false
        if body.hasPrefix("¥") || body.hasPrefix("￥") { body.removeFirst(); hadYuan = true }
        guard body.range(of: #"^[0-9]+(?:\.[0-9]+)?$"#, options: .regularExpression) != nil else { return raw }
        return sign + (hadYuan ? "¥" : "") + MoneyDisplay.text(body)
    }

    /// Fact keys on the governance pages whose value is a money amount.
    static let amountKeys: Set<String> = [
        "settledAmountText", "amountText", "originalAmountText", "executedAdjustmentText",
        "netAmountText", "paidAmountText", "amount",
    ]
}
