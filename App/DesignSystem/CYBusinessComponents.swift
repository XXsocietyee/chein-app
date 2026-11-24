import SwiftUI

// MARK: - 1. Activity Feed Card (248pt cover card + bottom scrim + dual CTAs)

/// Primary activity discovery card (`248pt` tall, `CYRadius.xxl` 22pt radius, dark bottom scrim `0 -> 0.55 -> 0.92`,
/// `#30383D` fallback when artwork is absent, capability pill, rare trophy pill, dual pill CTAs).
public struct CYActivityFeedCard: View {
    private let title: String
    private let subtitle: String
    private let imageURL: URL?
    private let capabilityTag: String?
    private let rareTrophyCount: Int?
    private let primaryTitle: String
    private let secondaryTitle: String
    private let onPrimary: () -> Void
    private let onSecondary: () -> Void

    @Environment(\.cyPalette) private var palette
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        title: String,
        subtitle: String,
        imageURL: URL? = nil,
        capabilityTag: String? = "可直接开局的模板",
        rareTrophyCount: Int? = nil,
        primaryTitle: String = "开始游玩",
        secondaryTitle: String = "查看详情",
        onPrimary: @escaping () -> Void,
        onSecondary: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.imageURL = imageURL
        self.capabilityTag = capabilityTag
        self.rareTrophyCount = rareTrophyCount
        self.primaryTitle = primaryTitle
        self.secondaryTitle = secondaryTitle
        self.onPrimary = onPrimary
        self.onSecondary = onSecondary
    }

    struct Tokens {
        let coverFallback: Color
        let onCoverFgDim: Color
        let photoCardFg: Color
        let photoCardMuted: Color
        let photoCardGlass: Color
        let photoCardAction: Color
        let rare: Color
        let cardShadowColor: Color
        let cornerRadius: CGFloat
        let minHeight: CGFloat
    }

    static func tokens(in palette: CYDomainPalette) -> Tokens {
        Tokens(
            coverFallback: palette.coverFallback,
            onCoverFgDim: palette.onCoverFgDim,
            photoCardFg: palette.photoCardFg,
            photoCardMuted: palette.photoCardMuted,
            photoCardGlass: palette.photoCardGlass,
            photoCardAction: palette.photoCardAction,
            rare: palette.rare,
            cardShadowColor: palette.cardShadowColor,
            cornerRadius: CYRadius.xxl,
            minHeight: 248
        )
    }

    public var body: some View {
        let tokens = Self.tokens(in: palette)
        let shape = RoundedRectangle(cornerRadius: tokens.cornerRadius, style: .continuous)
        ZStack(alignment: .bottomLeading) {
            coverLayer
                .frame(maxWidth: .infinity)
                .frame(minHeight: typeSize.isAccessibilitySize ? 280 : tokens.minHeight, maxHeight: typeSize.isAccessibilitySize ? nil : tokens.minHeight)

            scrimOverlay

            VStack(alignment: .leading, spacing: CYSpacing.md) {
                topBadges
                Spacer(minLength: CYSpacing.lg)
                bottomContent
            }
            .padding(CYSpacing.lg)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: tokens.minHeight)
        .clipShape(shape)
        .shadow(color: tokens.cardShadowColor, radius: 10, x: 0, y: 4)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var coverLayer: some View {
        if let imageURL {
            AsyncImage(url: imageURL) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    fallbackCover
                }
            }
        } else {
            fallbackCover
        }
    }

    private var fallbackCover: some View {
        ZStack {
            palette.coverFallback
            Image(systemName: "map.fill")
                .font(.system(size: 56, weight: .regular))
                .foregroundStyle(palette.onCoverFgDim.opacity(0.28))
                .accessibilityHidden(true)
        }
    }

    private var scrimOverlay: some View {
        LinearGradient(
            stops: [
                .init(color: Color.black.opacity(0), location: 0.0),
                .init(color: Color.black.opacity(0.55), location: 0.56),
                .init(color: Color.black.opacity(0.92), location: 1.0),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .allowsHitTesting(false)
    }

    private var topBadges: some View {
        HStack(spacing: CYSpacing.sm) {
            if let capabilityTag, !capabilityTag.isEmpty {
                Text(verbatim: capabilityTag)
                    .cyText(.micro)
                    .foregroundStyle(palette.photoCardFg)
                    .padding(.horizontal, 9)
                    .frame(minHeight: 22)
                    .background(Capsule(style: .continuous).fill(palette.photoCardGlass))
            }
            Spacer(minLength: CYSpacing.sm)
            if let rareTrophyCount {
                HStack(spacing: CYSpacing.xs) {
                    Image(systemName: "star.fill")
                        .font(.system(.caption, weight: .bold))
                        .foregroundStyle(palette.rare)
                    Text(verbatim: "\(rareTrophyCount)")
                        .cyText(.micro, weight: .bold, monospacedDigit: true)
                        .foregroundStyle(palette.photoCardFg)
                }
                .padding(.horizontal, 9)
                .frame(minHeight: 22)
                .background(Capsule(style: .continuous).fill(palette.photoCardGlass))
                .accessibilityLabel(Text(verbatim: "Rare \(rareTrophyCount)"))
            }
        }
    }

    private var bottomContent: some View {
        VStack(alignment: .leading, spacing: CYSpacing.s2_5) {
            Text(verbatim: title)
                .cyText(.sheetTitle)
                .foregroundStyle(palette.photoCardFg)
                .lineLimit(typeSize.isAccessibilitySize ? 3 : 2)
                .fixedSize(horizontal: false, vertical: true)

            Text(verbatim: subtitle)
                .cyText(.caption, monospacedDigit: true)
                .foregroundStyle(palette.photoCardMuted)
                .lineLimit(typeSize.isAccessibilitySize ? 2 : 1)

            HStack(spacing: CYSpacing.s2_5) {
                Button(action: onPrimary) {
                    Text(verbatim: primaryTitle)
                        .cyText(.meta, weight: .bold)
                        .foregroundStyle(palette.photoCardAction)
                        .padding(.horizontal, CYSpacing.lg)
                        .frame(minHeight: 34)
                        .background(Capsule(style: .continuous).fill(palette.photoCardFg))
                        .frame(minHeight: CYSpacing.minTouchTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button(action: onSecondary) {
                    Text(verbatim: secondaryTitle)
                        .cyText(.meta, weight: .semibold)
                        .foregroundStyle(palette.photoCardFg)
                        .padding(.horizontal, CYSpacing.lg)
                        .frame(minHeight: 34)
                        .background(Capsule(style: .continuous).fill(palette.photoCardGlass))
                        .frame(minHeight: CYSpacing.minTouchTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: title)
        }
    }
}

// MARK: - 2. Route Node (vertical timeline rail + distance/ETA + check-in method + merchant perk)

public enum CYRouteArrivalRequirement: Sendable, Hashable {
    case gps
    case qr
    case photo
    case neutral(String)

    var label: String {
        switch self {
        case .gps: return "GPS 到达"
        case .qr: return "扫码打卡"
        case .photo: return "拍照核验"
        case .neutral(let text): return text
        }
    }

    var systemImage: String {
        switch self {
        case .gps: return "location.fill"
        case .qr: return "qrcode.viewfinder"
        case .photo: return "camera.fill"
        case .neutral: return "flag.fill"
        }
    }
}

public enum CYRouteNodeCompletion: Sendable, Hashable {
    case upcoming
    case current
    case completed
    case locked
}

/// Vertical route node cell with rail, index/status badge, tabular distance & ETA, requirement pill, and optional perk row.
public struct CYRouteNodeRow: View {
    private let index: Int
    private let title: String
    private let distanceAndETA: String?
    private let requirement: CYRouteArrivalRequirement
    private let completion: CYRouteNodeCompletion
    private let isFirst: Bool
    private let isLast: Bool
    private let perkTitle: String?
    private let perkActionTitle: String?
    private let onPerkTap: (() -> Void)?

    @Environment(\.cyPalette) private var palette

    public init(
        index: Int,
        title: String,
        distanceAndETA: String? = nil,
        requirement: CYRouteArrivalRequirement = .gps,
        completion: CYRouteNodeCompletion = .upcoming,
        isFirst: Bool = false,
        isLast: Bool = false,
        perkTitle: String? = nil,
        perkActionTitle: String? = "领取",
        onPerkTap: (() -> Void)? = nil
    ) {
        self.index = index
        self.title = title
        self.distanceAndETA = distanceAndETA
        self.requirement = requirement
        self.completion = completion
        self.isFirst = isFirst
        self.isLast = isLast
        self.perkTitle = perkTitle
        self.perkActionTitle = perkActionTitle
        self.onPerkTap = onPerkTap
    }

    public var body: some View {
        let tokens = Self.tokens(for: completion, in: palette)
        HStack(alignment: .top, spacing: CYSpacing.md) {
            railColumn
            VStack(alignment: .leading, spacing: CYSpacing.sm) {
                HStack(alignment: .top, spacing: CYSpacing.sm) {
                    VStack(alignment: .leading, spacing: CYSpacing.xs) {
                        Text(verbatim: title)
                            .cyText(.cardTitle)
                            .foregroundStyle(tokens.titleColor)
                        if let distanceAndETA {
                            Text(verbatim: distanceAndETA)
                                .cyText(.meta, monospacedDigit: true)
                                .foregroundStyle(palette.textTertiary)
                        }
                    }
                    Spacer(minLength: CYSpacing.sm)
                    CYStatusChip(
                        verbatim: requirement.label,
                        tone: tokens.badgeTone,
                        systemImage: requirement.systemImage
                    )
                }

                if let perkTitle {
                    HStack(spacing: CYSpacing.sm) {
                        Image(systemName: "ticket.fill")
                            .font(CYTypography.caption)
                            .foregroundStyle(palette.rare)
                            .accessibilityHidden(true)
                        Text(verbatim: perkTitle)
                            .cyText(.meta)
                            .foregroundStyle(palette.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if let onPerkTap, let perkActionTitle {
                            Button(action: onPerkTap) {
                                Text(verbatim: perkActionTitle)
                                    .cyText(.caption, weight: .semibold)
                                    .foregroundStyle(tokens.perkActionColor)
                                    .padding(.horizontal, CYSpacing.md)
                                    .frame(minHeight: CYSpacing.minTouchTarget)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, CYSpacing.md)
                    .padding(.vertical, CYSpacing.xs)
                    .background(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous).fill(tokens.perkBackground))
                }
            }
            .padding(.bottom, isLast ? 0 : CYSpacing.lg)
        }
    }

    struct Tokens {
        let titleColor: Color
        let badgeTone: CYStatusTone
        let nodeFill: Color
        let nodeGlyphColor: Color
        let railColor: Color
        let perkBackground: Color
        let perkActionColor: Color
    }

    static func tokens(for completion: CYRouteNodeCompletion, in palette: CYDomainPalette) -> Tokens {
        let badgeTone: CYStatusTone = switch completion {
        case .completed: .success
        case .current: .info
        case .upcoming, .locked: .neutral
        }
        let nodeFill: Color = switch completion {
        case .completed, .current: palette.actionPrimaryBg
        case .upcoming, .locked: palette.bgRaised
        }
        let nodeGlyphColor: Color = switch completion {
        case .completed: palette.textInverse
        case .locked: palette.textDisabled
        case .current: palette.actionPrimaryFg
        case .upcoming: palette.textPrimary
        }
        return Tokens(
            titleColor: completion == .locked ? palette.textDisabled : palette.textPrimary,
            badgeTone: badgeTone,
            nodeFill: nodeFill,
            nodeGlyphColor: nodeGlyphColor,
            railColor: completion == .completed ? palette.textPrimary : palette.borderStrong,
            perkBackground: palette.bgRaised,
            perkActionColor: palette.actionPrimaryBg
        )
    }

    private var badgeTone: CYStatusTone { Self.tokens(for: completion, in: palette).badgeTone }

    private var railColumn: some View {
        let tokens = Self.tokens(for: completion, in: palette)
        return VStack(spacing: 0) {
            Rectangle()
                .fill(isFirst ? Color.clear : tokens.railColor)
                .frame(width: 2, height: 8)
            ZStack {
                Circle()
                    .fill(tokens.nodeFill)
                    .frame(width: 28, height: 28)
                switch completion {
                case .completed:
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(tokens.nodeGlyphColor)
                case .locked:
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(tokens.nodeGlyphColor)
                case .current, .upcoming:
                    Text(verbatim: "\(index)")
                        .cyText(.caption, weight: .bold, monospacedDigit: true)
                        .foregroundStyle(tokens.nodeGlyphColor)
                }
            }
            Rectangle()
                .fill(isLast ? Color.clear : tokens.railColor)
                .frame(width: 2)
                .frame(maxHeight: .infinity)
        }
        .frame(width: 28)
    }
}

// MARK: - 3. Task Status (all 6 required states with text, icon, action, and recovery)

public enum CYTaskStatusState {
    case locked(requirement: String, prereqTitle: String? = nil, onOpenPrereq: (() -> Void)? = nil)
    case available(methodLabel: String, ctaTitle: String = "开始打卡", onStart: () -> Void)
    case submitting(requestId: String)
    case completed(receiptNo: String, completedAt: String, onViewReceipt: (() -> Void)? = nil)
    case retryableFailure(
        requestId: String,
        detail: String,
        onQueryOriginalReceipt: () -> Void,
        onRetry: () -> Void
    )
    case offlineAwaitingSync(
        draftId: String,
        savedAt: String,
        onSyncNow: () -> Void,
        onViewDraft: () -> Void
    )
}

/// Complete 6-state interactive task submission status card honoring Chengyin recovery & idempotency rules.
public struct CYTaskStatusCard: View {
    private let title: String
    private let state: CYTaskStatusState

    @Environment(\.cyPalette) private var palette

    public init(title: String, state: CYTaskStatusState) {
        self.title = title
        self.state = state
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            header
            detailBody
            actionRow
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cyDomainCard()
    }

    public struct Tokens {
        public let iconName: String
        public let iconColor: Color
        public let detailForeground: Color
        public let badgeTitle: String
        let badgeTone: CYStatusTone
        public let badgeIcon: String
    }

    static func tokens(for state: CYTaskStatusState, in palette: CYDomainPalette) -> Tokens {
        switch state {
        case .locked:
            return Tokens(
                iconName: "lock.fill",
                iconColor: palette.textDisabled,
                detailForeground: palette.textTertiary,
                badgeTitle: "未解锁",
                badgeTone: .neutral,
                badgeIcon: "lock"
            )
        case .available:
            return Tokens(
                iconName: "location.circle.fill",
                iconColor: palette.textPrimary,
                detailForeground: palette.textSecondary,
                badgeTitle: "可打卡",
                badgeTone: .info,
                badgeIcon: "sparkles"
            )
        case .submitting:
            return Tokens(
                iconName: "arrow.triangle.2.circlepath.circle.fill",
                iconColor: palette.info,
                detailForeground: palette.textSecondary,
                badgeTitle: "提交中",
                badgeTone: .info,
                badgeIcon: "clock"
            )
        case .completed:
            return Tokens(
                iconName: "checkmark.seal.fill",
                iconColor: palette.success,
                detailForeground: palette.textSecondary,
                badgeTitle: "已完成",
                badgeTone: .success,
                badgeIcon: "checkmark"
            )
        case .retryableFailure:
            return Tokens(
                iconName: "exclamationmark.triangle.fill",
                iconColor: palette.danger,
                detailForeground: palette.danger,
                badgeTitle: "失败可重试",
                badgeTone: .danger,
                badgeIcon: "arrow.clockwise"
            )
        case .offlineAwaitingSync:
            return Tokens(
                iconName: "icloud.and.arrow.up.fill",
                iconColor: palette.warning,
                detailForeground: palette.warning,
                badgeTitle: "待同步",
                badgeTone: .warning,
                badgeIcon: "wifi.slash"
            )
        }
    }

    private var header: some View {
        let tokens = Self.tokens(for: state, in: palette)
        return HStack(spacing: CYSpacing.sm) {
            Image(systemName: tokens.iconName)
                .font(.system(.callout, weight: .semibold))
                .foregroundStyle(tokens.iconColor)
                .accessibilityHidden(true)

            Text(verbatim: title)
                .cyText(.cardTitle)
                .foregroundStyle(palette.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            CYStatusChip(verbatim: tokens.badgeTitle, tone: tokens.badgeTone, systemImage: tokens.badgeIcon)
        }
    }

    @ViewBuilder
    private var detailBody: some View {
        let tokens = Self.tokens(for: state, in: palette)
        switch state {
        case .locked(let requirement, _, _):
            Text(verbatim: requirement)
                .cyText(.meta)
                .foregroundStyle(tokens.detailForeground)
        case .available(let methodLabel, _, _):
            Text(verbatim: "核验方式：\(methodLabel)")
                .cyText(.meta)
                .foregroundStyle(tokens.detailForeground)
        case .submitting(let requestId):
            HStack(spacing: CYSpacing.sm) {
                CYButtonSpinner(tint: palette.info)
                Text(verbatim: "正在上传凭证并防重锁定 · 请求号 \(requestId)")
                    .cyText(.meta, monospacedDigit: true)
                    .foregroundStyle(tokens.detailForeground)
            }
        case .completed(let receiptNo, let completedAt, _):
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                Text(verbatim: "核验通过 · \(completedAt)")
                    .cyText(.meta, monospacedDigit: true)
                    .foregroundStyle(tokens.detailForeground)
                Text(verbatim: "回执编号 \(receiptNo)")
                    .cyText(.caption, monospacedDigit: true)
                    .foregroundStyle(palette.textTertiary)
            }
        case .retryableFailure(let requestId, let detail, _, _):
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                Text(verbatim: detail)
                    .cyText(.meta)
                    .foregroundStyle(tokens.detailForeground)
                Text(verbatim: "保留幂等号 \(requestId)，请先查询原回执或安全重试。")
                    .cyText(.caption, monospacedDigit: true)
                    .foregroundStyle(palette.textTertiary)
            }
        case .offlineAwaitingSync(let draftId, let savedAt, _, _):
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                Text(verbatim: "网络离线，答案未丢失（保存于 \(savedAt)），切勿显示为已完成。")
                    .cyText(.meta)
                    .foregroundStyle(tokens.detailForeground)
                Text(verbatim: "本地草稿 \(draftId)")
                    .cyText(.caption, monospacedDigit: true)
                    .foregroundStyle(palette.textTertiary)
            }
        }
    }

    @ViewBuilder
    private var actionRow: some View {
        switch state {
        case .locked(_, let prereqTitle, let onOpenPrereq):
            if let prereqTitle, let onOpenPrereq {
                Button(action: onOpenPrereq) {
                    Text(verbatim: prereqTitle)
                }
                .buttonStyle(CYSecondaryButtonStyle(isFullWidth: true, size: .sm))
            }
        case .available(_, let ctaTitle, let onStart):
            Button(action: onStart) {
                Text(verbatim: ctaTitle)
            }
            .buttonStyle(CYPrimaryButtonStyle(isFullWidth: true, size: .md))
        case .submitting:
            Button(action: {}) {
                Text(verbatim: "提交中")
            }
            .buttonStyle(CYPrimaryButtonStyle(isFullWidth: true, size: .md, isLoading: true))
            .disabled(true)
        case .completed(_, _, let onViewReceipt):
            if let onViewReceipt {
                Button(action: onViewReceipt) {
                    Text(verbatim: "查看回执")
                }
                .buttonStyle(CYSecondaryButtonStyle(isFullWidth: true, size: .sm))
            }
        case .retryableFailure(_, _, let onQueryOriginalReceipt, let onRetry):
            HStack(spacing: CYSpacing.md) {
                Button(action: onQueryOriginalReceipt) {
                    Text(verbatim: "查询原回执")
                }
                .buttonStyle(CYSecondaryButtonStyle(isFullWidth: true, size: .sm))

                Button(action: onRetry) {
                    Text(verbatim: "重试")
                }
                .buttonStyle(CYPrimaryButtonStyle(isFullWidth: true, size: .sm))
            }
        case .offlineAwaitingSync(_, _, let onSyncNow, let onViewDraft):
            HStack(spacing: CYSpacing.md) {
                Button(action: onViewDraft) {
                    Text(verbatim: "查看本地草稿")
                }
                .buttonStyle(CYSecondaryButtonStyle(isFullWidth: true, size: .sm))

                Button(action: onSyncNow) {
                    Text(verbatim: "立即同步")
                }
                .buttonStyle(CYPrimaryButtonStyle(isFullWidth: true, size: .sm))
            }
        }
    }

}

// MARK: - 4. Story Clue (`hintLadder` + free hint pool + explicit points-cost confirmation)

public struct CYStoryClueTier: Identifiable, Hashable {
    public let id: String
    public let level: Int
    public let title: String
    public let clueText: String?
    public let pointsCost: Int
    public let isUnlocked: Bool

    public init(id: String, level: Int, title: String, clueText: String?, pointsCost: Int, isUnlocked: Bool) {
        self.id = id
        self.level = level
        self.title = title
        self.clueText = clueText
        self.pointsCost = pointsCost
        self.isUnlocked = isUnlocked
    }
}

/// Tiered clue accordion with shared free-hint pool and explicit point-deduction warning before spending `积分`.
public struct CYStoryCluePanel: View {
    private let tiers: [CYStoryClueTier]
    private let freeHintsRemaining: Int?
    private let onUnlockTier: (CYStoryClueTier) -> Void

    @State private var expandedIds: Set<String> = []
    @State private var pendingCostTier: CYStoryClueTier?
    @Environment(\.cyPalette) private var palette

    public init(
        tiers: [CYStoryClueTier],
        freeHintsRemaining: Int?,
        onUnlockTier: @escaping (CYStoryClueTier) -> Void
    ) {
        self.tiers = tiers
        self.freeHintsRemaining = freeHintsRemaining
        self.onUnlockTier = onUnlockTier
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            HStack(spacing: CYSpacing.sm) {
                Text(verbatim: "线索阶梯")
                    .cyText(.sectionTitle)
                    .foregroundStyle(palette.textPrimary)
                Spacer(minLength: CYSpacing.sm)
                CYStatusChip(
                    verbatim: freeHintsRemaining.map { "免费提示剩余 \($0)" } ?? "免费提示 —",
                    tone: (freeHintsRemaining ?? 0) > 0 ? .info : .neutral,
                    systemImage: "lightbulb.fill"
                )
            }

            ForEach(tiers) { tier in
                tierRow(tier)
            }

            if let pending = pendingCostTier {
                VStack(alignment: .leading, spacing: CYSpacing.sm) {
                    Text(verbatim: "确认消耗 \(pending.pointsCost) 积分解锁「\(pending.title)」？已解锁线索可免费重看。")
                        .cyText(.meta, monospacedDigit: true)
                        .foregroundStyle(palette.textPrimary)
                    HStack(spacing: CYSpacing.md) {
                        Button(action: { pendingCostTier = nil }) {
                            Text(verbatim: "取消")
                        }
                        .buttonStyle(CYSecondaryButtonStyle(isFullWidth: true, size: .sm))

                        Button {
                            onUnlockTier(pending)
                            pendingCostTier = nil
                        } label: {
                            Text(verbatim: "确认消耗 \(pending.pointsCost) 积分")
                        }
                        .buttonStyle(CYPrimaryButtonStyle(isFullWidth: true, size: .sm))
                    }
                }
                .padding(CYSpacing.md)
                .background(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous).fill(palette.warningSoft))
            }
        }
        .cyDomainCard()
    }

    private func tierRow(_ tier: CYStoryClueTier) -> some View {
        let expanded = expandedIds.contains(tier.id)
        return VStack(alignment: .leading, spacing: CYSpacing.sm) {
            Button {
                if tier.isUnlocked {
                    if expanded { expandedIds.remove(tier.id) } else { expandedIds.insert(tier.id) }
                } else if (freeHintsRemaining ?? 0) > 0 || tier.pointsCost == 0 {
                    onUnlockTier(tier)
                } else {
                    pendingCostTier = tier
                }
            } label: {
                HStack(spacing: CYSpacing.sm) {
                    Text(verbatim: "L\(tier.level) · \(tier.title)")
                        .cyText(.label, weight: .semibold)
                        .foregroundStyle(palette.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if tier.isUnlocked {
                        CYStatusChip(verbatim: "已解锁 · 免费重看", tone: .success, systemImage: "lock.open")
                        Image(systemName: expanded ? "chevron.up" : "chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(palette.textTertiary)
                    } else if (freeHintsRemaining ?? 0) > 0 {
                        CYStatusChip(verbatim: "使用免费次数", tone: .info, systemImage: "sparkles")
                    } else {
                        CYStatusChip(verbatim: "\(tier.pointsCost) 积分解锁", tone: .warning, systemImage: "lock")
                    }
                }
                .frame(minHeight: CYSpacing.minTouchTarget)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if tier.isUnlocked && expanded, let clueText = tier.clueText {
                Text(verbatim: clueText)
                    .cyText(.bodyCompact)
                    .foregroundStyle(palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, CYSpacing.xs)
            }
        }
        .padding(.horizontal, CYSpacing.md)
        .background(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous).fill(palette.bgSurfaceSubtle))
    }
}

// MARK: - 5. Progress (tabular fraction + segmented bar + honest nil/failure state)

/// Honest progress bar & counter (`3 / 8`, never fakes `0%` when loading failed or `completed == nil`).
public struct CYProgressBar: View {
    private let title: String
    private let completed: Int?
    private let total: Int?
    private let loadFailed: Bool
    private let onRetry: (() -> Void)?

    @Environment(\.cyPalette) private var palette
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    public init(
        title: String,
        completed: Int?,
        total: Int?,
        loadFailed: Bool = false,
        onRetry: (() -> Void)? = nil
    ) {
        self.title = title
        self.completed = completed
        self.total = total
        self.loadFailed = loadFailed
        self.onRetry = onRetry
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            if dynamicTypeSize >= .xxLarge {
                VStack(alignment: .leading, spacing: CYSpacing.xs) {
                    progressTitle
                    progressCounter
                }
            } else {
                HStack {
                    progressTitle
                    Spacer(minLength: CYSpacing.sm)
                    progressCounter
                }
            }

            if loadFailed {
                CYInlineError("cy.progress.loadFailed", retryTitle: "cy.state.offline.retry", onRetry: onRetry)
            } else if let total, total > 0 {
                HStack(spacing: CYSpacing.xs) {
                    ForEach(0..<total, id: \.self) { index in
                        let isDone = (completed ?? -1) > index
                        Capsule(style: .continuous)
                            .fill(isDone ? palette.textPrimary : palette.bgStrong)
                            .frame(height: 4)
                    }
                }
            } else {
                Capsule(style: .continuous)
                    .fill(palette.bgStrong)
                    .frame(height: 4)
            }
        }
        .cyDomainCard()
        .accessibilityElement(children: .combine)
    }

    private var progressTitle: some View {
        Text(verbatim: title)
            .cyText(.label, weight: .semibold)
            .foregroundStyle(palette.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var progressCounter: some View {
        Text(verbatim: counterText)
            .cyText(.meta, weight: .semibold, monospacedDigit: true)
            .foregroundStyle(loadFailed ? palette.danger : palette.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var counterText: String {
        if loadFailed { return "— / —" }
        guard let completed, let total else { return "—" }
        return "\(completed) / \(total)"
    }
}

// MARK: - 6. Registration Summary (slot + stepper + right-aligned tabular price breakdown)

public struct CYRegistrationSlot: Identifiable, Hashable {
    public let id: String
    public let label: String
    public let seatsLeftText: String
    public let isAvailable: Bool

    public init(id: String, label: String, seatsLeftText: String, isAvailable: Bool = true) {
        self.id = id
        self.label = label
        self.seatsLeftText = seatsLeftText
        self.isAvailable = isAvailable
    }
}

/// Session slot selector, attendee stepper, and `.setly_li` right-aligned tabular fee summary.
public struct CYRegistrationSummaryCard: View {
    private let slots: [CYRegistrationSlot]
    @Binding private var selectedSlotID: String
    @Binding private var attendeeCount: Int
    private let minAttendees: Int
    private let maxAttendees: Int
    private let originalAmountText: String?
    private let discountText: String?
    private let totalAmountText: String
    private let ctaTitle: String
    private let isServerReady: Bool
    private let blockingReason: String?
    private let onSubmit: () -> Void

    @Environment(\.cyPalette) private var palette

    public init(
        slots: [CYRegistrationSlot],
        selectedSlotID: Binding<String>,
        attendeeCount: Binding<Int>,
        minAttendees: Int = 1,
        maxAttendees: Int = 6,
        originalAmountText: String? = nil,
        discountText: String? = nil,
        totalAmountText: String,
        ctaTitle: String = "确认报名",
        isServerReady: Bool = true,
        blockingReason: String? = nil,
        onSubmit: @escaping () -> Void
    ) {
        self.slots = slots
        self._selectedSlotID = selectedSlotID
        self._attendeeCount = attendeeCount
        self.minAttendees = minAttendees
        self.maxAttendees = maxAttendees
        self.originalAmountText = originalAmountText
        self.discountText = discountText
        self.totalAmountText = totalAmountText
        self.ctaTitle = ctaTitle
        self.isServerReady = isServerReady
        self.blockingReason = blockingReason
        self.onSubmit = onSubmit
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.lg) {
            VStack(alignment: .leading, spacing: CYSpacing.sm) {
                Text(verbatim: "选择场次")
                    .cyText(.caption, weight: .semibold)
                    .foregroundStyle(palette.textSecondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: CYSpacing.sm) {
                        ForEach(slots) { slot in
                            CYFilterChip(
                                verbatim: "\(slot.label) (\(slot.seatsLeftText))",
                                isSelected: slot.id == selectedSlotID
                            ) {
                                if slot.isAvailable { selectedSlotID = slot.id }
                            }
                            .opacity(slot.isAvailable ? 1 : 0.45)
                            .disabled(!slot.isAvailable)
                        }
                    }
                }
            }

            HStack {
                Text(verbatim: "参与人数")
                    .cyText(.cardTitle)
                    .foregroundStyle(palette.textPrimary)
                Spacer()
                HStack(spacing: CYSpacing.md) {
                    stepperButton(symbol: "minus", disabled: attendeeCount <= minAttendees) {
                        if attendeeCount > minAttendees { attendeeCount -= 1 }
                    }
                    Text(verbatim: "\(attendeeCount)")
                        .cyText(.numericBody, weight: .bold)
                        .foregroundStyle(palette.textPrimary)
                        .frame(minWidth: 24)
                    stepperButton(symbol: "plus", disabled: attendeeCount >= maxAttendees) {
                        if attendeeCount < maxAttendees { attendeeCount += 1 }
                    }
                }
            }

            Rectangle()
                .fill(palette.borderSubtle)
                .frame(height: 0.5)

            VStack(alignment: .trailing, spacing: CYSpacing.xs) {
                if let originalAmountText {
                    HStack {
                        Text(verbatim: "原价")
                            .cyText(.meta)
                            .foregroundStyle(palette.textTertiary)
                        Spacer()
                        Text(verbatim: originalAmountText)
                            .cyText(.meta, monospacedDigit: true)
                            .strikethrough()
                            .foregroundStyle(palette.textTertiary)
                    }
                }
                if let discountText {
                    HStack {
                        Text(verbatim: "早鸟/组队优惠")
                            .cyText(.meta)
                            .foregroundStyle(palette.success)
                        Spacer()
                        Text(verbatim: discountText)
                            .cyText(.meta, monospacedDigit: true)
                            .foregroundStyle(palette.success)
                    }
                }
                HStack(alignment: .firstTextBaseline) {
                    Text(verbatim: "实付合计")
                        .cyText(.cardTitle)
                        .foregroundStyle(palette.textPrimary)
                    Spacer()
                    Text(verbatim: totalAmountText)
                        .cyText(.dataXL)
                        .foregroundStyle(palette.textPrimary)
                }
            }

            if let blockingReason, !isServerReady {
                CYInlineError(verbatim: blockingReason, retryTitle: nil, onRetry: nil)
            }

            Button(action: onSubmit) {
                Text(verbatim: ctaTitle)
            }
            .buttonStyle(CYPrimaryButtonStyle(isFullWidth: true, size: .md, isPill: true))
            .disabled(!isServerReady)
        }
        .cyDomainCard()
    }

    private func stepperButton(symbol: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(disabled ? palette.textDisabled : palette.textPrimary)
                .frame(width: 32, height: 32)
                .background(Circle().fill(palette.bgSurfaceSubtle))
                .frame(width: CYSpacing.minTouchTarget, height: CYSpacing.minTouchTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }
}

// MARK: - 7. Team Row (`PENDING / CLAIMED / EXPIRED / REVOKED`, `expiresAt`, gated actions)

public enum CYTeamSeatStatus: String, Sendable, Hashable {
    case pending = "PENDING"
    case claimed = "CLAIMED"
    case expired = "EXPIRED"
    case revoked = "REVOKED"

    var label: String {
        switch self {
        case .pending: return "待领取"
        case .claimed: return "已占位"
        case .expired: return "已过期"
        case .revoked: return "已撤回"
        }
    }

    var tone: CYStatusTone {
        switch self {
        case .pending: return .warning
        case .claimed: return .success
        case .expired: return .neutral
        case .revoked: return .danger
        }
    }
}

/// Multi-person seat row: Seat 1 buyer vs Seats 2..N companions with per-slot status, expiry & capability-gated actions.
public struct CYTeamMemberRow: View {
    private let seatNumber: Int
    private let occupantName: String?
    private let isBuyer: Bool
    private let status: CYTeamSeatStatus
    private let expiresAtText: String?
    private let issuedInviteToken: String?
    private let canRevoke: Bool
    private let canRelease: Bool
    private let onRevoke: (() -> Void)?
    private let onRelease: (() -> Void)?

    @Environment(\.cyPalette) private var palette

    public init(
        seatNumber: Int,
        occupantName: String?,
        isBuyer: Bool = false,
        status: CYTeamSeatStatus,
        expiresAtText: String? = nil,
        issuedInviteToken: String? = nil,
        canRevoke: Bool = false,
        canRelease: Bool = false,
        onRevoke: (() -> Void)? = nil,
        onRelease: (() -> Void)? = nil
    ) {
        self.seatNumber = seatNumber
        self.occupantName = occupantName
        self.isBuyer = isBuyer
        self.status = status
        self.expiresAtText = expiresAtText
        self.issuedInviteToken = issuedInviteToken
        self.canRevoke = canRevoke
        self.canRelease = canRelease
        self.onRevoke = onRevoke
        self.onRelease = onRelease
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            HStack(spacing: CYSpacing.md) {
                Text(verbatim: "S\(seatNumber)")
                    .cyText(.caption, weight: .bold, monospacedDigit: true)
                    .foregroundStyle(isBuyer ? palette.actionPrimaryFg : palette.textPrimary)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(isBuyer ? palette.actionPrimaryBg : palette.bgRaised))

                VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                    HStack(spacing: CYSpacing.xs) {
                        Text(verbatim: occupantName?.isEmpty == false ? (occupantName ?? "—") : (isBuyer ? "购票人" : "待成员领取"))
                            .cyText(.cardTitle)
                            .foregroundStyle(palette.textPrimary)
                        if isBuyer {
                            CYStatusChip(verbatim: "购票人", tone: .info)
                        }
                    }
                    if let expiresAtText {
                        Text(verbatim: "过期时间 \(expiresAtText)")
                            .cyText(.micro, monospacedDigit: true)
                            .foregroundStyle(palette.textTertiary)
                    }
                }
                Spacer(minLength: CYSpacing.sm)
                CYStatusChip(verbatim: status.label, tone: status.tone)
            }

            if let issuedInviteToken, !issuedInviteToken.isEmpty {
                Text(verbatim: "一次性邀请码：\(issuedInviteToken)")
                    .cyText(.micro, monospacedDigit: true)
                    .foregroundStyle(palette.textSecondary)
                    .padding(.horizontal, CYSpacing.md)
                    .padding(.vertical, CYSpacing.xs)
                    .background(RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous).fill(palette.bgSurfaceSubtle))
            }

            if (status == .pending && canRevoke && onRevoke != nil) || (status == .claimed && canRelease && onRelease != nil && !isBuyer) {
                HStack(spacing: CYSpacing.sm) {
                    Spacer()
                    if status == .pending && canRevoke, let onRevoke {
                        Button(action: onRevoke) {
                            Text(verbatim: "撤回名额")
                        }
                        .buttonStyle(CYSecondaryButtonStyle(isFullWidth: false, size: .sm))
                    }
                    if status == .claimed && canRelease && !isBuyer, let onRelease {
                        Button(action: onRelease) {
                            Text(verbatim: "释放席位")
                        }
                        .buttonStyle(CYSecondaryButtonStyle(isFullWidth: false, size: .sm))
                    }
                }
            }
        }
        .cyDomainCard()
    }
}

// MARK: - 8. Publish Status (`基本信息 · 活动内容 · 票务与合作` + save status + review gate)

public enum CYPublishSaveState {
    case savedDraft(updatedAt: String)
    case unsavedChanges
    case saveFailed(reason: String, onRetry: () -> Void)
}

public struct CYPublishValidationIssue: Identifiable, Hashable {
    public let id: String
    public let stepIndex: Int
    public let message: String

    public init(id: String, stepIndex: Int, message: String) {
        self.id = id
        self.stepIndex = stepIndex
        self.message = message
    }
}

/// 3-step publishing status bar with persistent save badge, error-step routing, and single review gate.
public struct CYPublishStatusBar: View {
    public static let defaultStepTitles = ["基本信息", "活动内容", "票务与合作"]

    private let stepTitles: [String]
    private let currentStep: Int
    private let saveState: CYPublishSaveState
    private let issues: [CYPublishValidationIssue]
    private let isSubmittingReview: Bool
    private let onSelectStep: (Int) -> Void
    private let onSubmitReview: () -> Void
    /// verify-r1 N-02: a page that already has a submit action in its bottom bar hides this one.
    private let showsSubmitButton: Bool

    @Environment(\.cyPalette) private var palette
    @Environment(\.dynamicTypeSize) private var typeSize

    public init(
        stepTitles: [String] = CYPublishStatusBar.defaultStepTitles,
        currentStep: Int,
        saveState: CYPublishSaveState,
        issues: [CYPublishValidationIssue] = [],
        isSubmittingReview: Bool = false,
        showsSubmitButton: Bool = true,
        onSelectStep: @escaping (Int) -> Void,
        onSubmitReview: @escaping () -> Void
    ) {
        self.showsSubmitButton = showsSubmitButton
        self.stepTitles = stepTitles
        self.currentStep = currentStep
        self.saveState = saveState
        self.issues = issues
        self.isSubmittingReview = isSubmittingReview
        self.onSelectStep = onSelectStep
        self.onSubmitReview = onSubmitReview
    }

    private var publishTitle: some View {
        Text(verbatim: "发布状态")
            .cyText(.sectionTitle)
            .foregroundStyle(palette.textPrimary)
            .cyWrapText()
    }

    private var stepButtons: some View {
        ForEach(Array(stepTitles.enumerated()), id: \.offset) { index, title in
            let hasIssue = issues.contains { $0.stepIndex == index }
            let isActive = index == currentStep
            Button {
                onSelectStep(index)
            } label: {
                HStack(spacing: CYSpacing.xs) {
                    Text(verbatim: "\(index + 1).\(title)")
                        .font(CYTypography.caption.weight(isActive ? .bold : .medium))
                        .cyWrapText(alignment: .center)
                    if hasIssue {
                        Circle()
                            .fill(palette.danger)
                            .frame(width: 6, height: 6)
                    }
                }
                .foregroundStyle(isActive ? palette.actionPrimaryFg : palette.textSecondary)
                .padding(.horizontal, CYSpacing.md)
                .frame(maxWidth: .infinity, minHeight: 36)
                .background(
                    RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous)
                        .fill(isActive ? palette.actionPrimaryBg : palette.bgSurfaceSubtle)
                )
                .frame(minHeight: CYSpacing.minTouchTarget)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private var canSubmitReview: Bool {
        if case .savedDraft = saveState {
            return issues.isEmpty && !isSubmittingReview
        }
        return false
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            Group {
                if typeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: CYSpacing.xs) { publishTitle; saveBadge }
                } else {
                    HStack(spacing: CYSpacing.sm) { publishTitle; Spacer(); saveBadge }
                }
            }

            Group {
                if typeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: CYSpacing.sm) { stepButtons }
                } else {
                    HStack(spacing: CYSpacing.sm) { stepButtons }
                }
            }

            if case .saveFailed(let reason, let onRetry) = saveState {
                CYInlineError(verbatim: reason, onRetry: onRetry)
            }

            if !issues.isEmpty {
                VStack(alignment: .leading, spacing: CYSpacing.xs) {
                    ForEach(issues) { issue in
                        Button {
                            onSelectStep(issue.stepIndex)
                        } label: {
                            HStack(spacing: CYSpacing.xs) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .font(CYTypography.micro)
                                    .foregroundStyle(palette.danger)
                                Text(verbatim: "第 \(issue.stepIndex + 1) 步：\(issue.message)")
                                    .cyText(.micro)
                                    .foregroundStyle(palette.danger)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Image(systemName: "arrow.up.right")
                                    .font(CYTypography.micro)
                                    .foregroundStyle(palette.textTertiary)
                            }
                            .frame(minHeight: 32)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(CYSpacing.sm)
                .background(RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous).fill(palette.dangerSoft))
            }

            if showsSubmitButton {
                Button(action: onSubmitReview) {
                    Text(verbatim: "提交审核")
                }
                .buttonStyle(CYPrimaryButtonStyle(isFullWidth: true, size: .md, isLoading: isSubmittingReview, isPill: true))
                .disabled(!canSubmitReview)
            }
        }
        .cyDomainCard()
    }

    @ViewBuilder
    private var saveBadge: some View {
        switch saveState {
        case .savedDraft(let updatedAt):
            CYStatusChip(verbatim: "草稿已保存 \(updatedAt)", tone: .success, systemImage: "checkmark.circle")
        case .unsavedChanges:
            CYStatusChip(verbatim: "有未保存修改", tone: .warning, systemImage: "pencil.circle")
        case .saveFailed:
            CYStatusChip(verbatim: "保存失败", tone: .danger, systemImage: "exclamationmark.triangle")
        }
    }
}
