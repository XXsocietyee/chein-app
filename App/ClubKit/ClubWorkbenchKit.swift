import SwiftUI
#if canImport(QuestifyCore)
import QuestifyCore
#endif

// r4 · 主理人工作台 (Figma `170:1744`, MC-28): 现在要做 first with its one primary, then the three numbers that matter
// (待审批 · 待核销 · 本周场次) as tappable tiles, then the existing project and management rows below in the 管理 tab.
// Copy lives in `Resources/ClubR4.xcstrings`.

enum ClubR4Text {
    static let table = "ClubR4"
    static func text(_ key: String) -> Text { Text(LocalizedStringKey(key), tableName: table) }
    static func string(_ key: String, locale: Locale) -> String {
        String(localized: LocalizedStringResource(String.LocalizationValue(key), table: table, locale: locale))
    }
}

/// What the workbench knows. Only 待审批 is read today (`pendingJoinRequestCount` on `/api/club/detail`);
/// 待核销 and 本周场次 have no client read yet, so they stay nil and show "—" (owner rule: never 0 for unknown).
struct ClubWorkbenchSummary: Equatable {
    var pendingApprovals: Int?
    var pendingCheckins: Int? = nil
    var sessionsThisWeek: Int? = nil

    static let unknownMark = "—"

    enum Now: Equatable {
        /// N join requests wait for the organiser: the card's one primary is 去审批.
        case approvals(Int)
        /// The count is read and is zero: a quiet line, no button.
        case clear
        /// Nothing is read: the card is left out (the tiles still say "—").
        case unknown
    }

    var now: Now {
        guard let pendingApprovals, pendingApprovals >= 0 else { return .unknown }
        return pendingApprovals > 0 ? .approvals(pendingApprovals) : .clear
    }

    static func display(_ value: Int?) -> String {
        guard let value, value >= 0 else { return unknownMark }
        return String(value)
    }

    init(club: ClubRecord) {
        pendingApprovals = club.pendingJoinRequestCount
    }

    init(pendingApprovals: Int?, pendingCheckins: Int? = nil, sessionsThisWeek: Int? = nil) {
        self.pendingApprovals = pendingApprovals
        self.pendingCheckins = pendingCheckins
        self.sessionsThisWeek = sessionsThisWeek
    }
}

/// The workbench head of the 管理 tab: the Now card (when something is known) and the three tiles.
/// Each element is its own list row so its button is the only tap target in that row.
struct ClubWorkbenchSection: View {
    let summary: ClubWorkbenchSummary
    /// Owner-stage Now card. Nil keeps the approvals headline.
    var ownerStage: ClubOwnerStageResolution? = nil
    /// Opens 入会申请 (nil when the viewer has no management context: the tile and the card stay visible, not tappable).
    let onApprovals: (() -> Void)?
    /// 待核销 and 本周场次 live on the 活动 tab (sessions, 核销). Hidden when the count is unknown.
    let onEvents: () -> Void

    var body: some View {
        Section {
            if summary.now != .unknown || ownerStage != nil {
                ClubWorkbenchNowCard(now: summary.now, ownerStage: ownerStage, onApprove: onApprovals)
                    .listRowInsets(Self.insets)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            HStack(spacing: CYSpacing.sm) {
                ClubWorkbenchTile(titleKey: "r4club.tile.approvals", value: summary.pendingApprovals,
                                  identifier: "club.workbench.tile.approvals", action: onApprovals)
                if summary.pendingCheckins != nil {
                    ClubWorkbenchTile(titleKey: "r4club.tile.checkins", value: summary.pendingCheckins,
                                      identifier: "club.workbench.tile.checkins", action: onEvents)
                }
                if summary.sessionsThisWeek != nil {
                    ClubWorkbenchTile(titleKey: "r4club.tile.sessions", value: summary.sessionsThisWeek,
                                      identifier: "club.workbench.tile.sessions", action: onEvents)
                }
            }
            .listRowInsets(Self.insets)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }

    private static let insets = EdgeInsets(top: CYSpacing.xs, leading: CYSpacing.pageHorizontal,
                                           bottom: CYSpacing.xs, trailing: CYSpacing.pageHorizontal)
}

/// Club/Now Card: eyebrow 现在要做 with a status dot, one line, and at most one primary.
struct ClubWorkbenchNowCard: View {
    let now: ClubWorkbenchSummary.Now
    var ownerStage: ClubOwnerStageResolution? = nil
    let onApprove: (() -> Void)?
    @State private var pulsing = false
    @Environment(\.locale) private var locale
    @Environment(\.cyPalette) private var palette
    @QuestifyReduceMotion private var reduceMotion

    /// A resolved owner stage is the one line. It does not add a second primary beside 去处理.
    private var showsOwnerStage: Bool { ownerStage != nil }

    private var actionable: Bool {
        if showsOwnerStage { return false }
        if case .approvals = now { return true }
        return false
    }

    private var headline: String {
        if let ownerStage { return ownerStage.label }
        switch now {
        case .approvals(let count):
            return String(format: ClubR4Text.string("r4club.now.approvals", locale: locale), count)
        case .clear, .unknown:
            return ClubR4Text.string("r4club.now.clear", locale: locale)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            HStack(spacing: CYSpacing.sm) {
                Circle()
                    .fill(actionable ? palette.warning : palette.textTertiary)
                    .frame(width: 8, height: 8)
                    .scaleEffect(pulsing ? 1.6 : 1)
                    .accessibilityHidden(true)
                ClubR4Text.text("r4club.now.title")
                    .cyText(.label)
                    .foregroundStyle(palette.textSecondary)
            }
            Text(verbatim: headline)
                .cyText(.cardTitle)
                .foregroundStyle(palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("club.workbench.now.headline")
            if let hint = ownerStage?.hint, !hint.isEmpty {
                Text(verbatim: hint)
                    .cyText(.body)
                    .foregroundStyle(palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("club.workbench.now.hint")
            }
            if actionable, let onApprove {
                Button(action: onApprove) {
                    ClubR4Text.text("r4club.now.approve")
                }
                .buttonStyle(.cyPrimary(fullWidth: true))
                .accessibilityIdentifier("club.workbench.now.approve")
            }
        }
        .padding(CYSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: CYRadius.card, style: .continuous).fill(palette.bgElevated))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("club.workbench.now")
        // MC-28: the dot pulses once on appear (600 ms), never in a loop; Reduce Motion keeps it still.
        .task(id: now) {
            guard actionable, !reduceMotion else { return }
            withAnimation(.easeOut(duration: 0.3)) { pulsing = true }
            try? await Task.sleep(for: .milliseconds(300))
            withAnimation(.easeIn(duration: 0.3)) { pulsing = false }
        }
    }
}

/// Player/Stat Tile: one number (or "—") over its label; the whole tile is the 44 pt+ target.
struct ClubWorkbenchTile: View {
    let titleKey: String
    let value: Int?
    let identifier: String
    let action: (() -> Void)?
    @Environment(\.locale) private var locale
    @Environment(\.cyPalette) private var palette
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Button { action?() } label: {
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                Text(verbatim: ClubWorkbenchSummary.display(value))
                    .font(typeSize.isAccessibilitySize ? CYTypography.numericBody : CYTypography.dataXL)
                    .monospacedDigit()
                    .foregroundStyle(value == nil ? palette.textTertiary : palette.textPrimary)
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                ClubR4Text.text(titleKey)
                    .cyText(.meta)
                    .foregroundStyle(palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(CYSpacing.md)
            .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: CYRadius.card, style: .continuous).fill(palette.bgElevated))
            .contentShape(RoundedRectangle(cornerRadius: CYRadius.card, style: .continuous))
        }
        .buttonStyle(.cyPressable)
        .allowsHitTesting(action != nil)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: ClubR4Text.string(titleKey, locale: locale)))
        .accessibilityValue(Text(verbatim: value == nil
            ? ClubR4Text.string("r4club.tile.unknown", locale: locale)
            : ClubWorkbenchSummary.display(value)))
        .accessibilityAddTraits(action == nil ? [] : .isButton)
        .accessibilityIdentifier(identifier)
    }
}

/// Club/Header second half (MC-22, `204:24899` Member / Manager): 邀请朋友加入 as the header's full-width secondary.
/// Clubs have no invite link or invite API, so it shares the same text invitation as 成员 › 邀请成员 (OpsR3 copy).
struct ClubHeaderInviteButton: View {
    let clubName: String
    @Environment(\.locale) private var locale

    var body: some View {
        ShareLink(item: String(format: OpsR3Text.string("r3club.invite.message", locale: locale), clubName)) {
            Label { ClubR4Text.text("r4club.header.invite") } icon: { Image(systemName: "person.badge.plus") }
        }
        .buttonStyle(.cySecondary(fullWidth: true))
        .accessibilityHint(OpsR3Text.text("r3club.invite.hint"))
        .accessibilityIdentifier("club.detail.inviteFriends")
    }
}

/// Share in the navigation bar (a glass circle on iOS 26+ bars): the club detail path from `ClubShareLink`.
/// CLB-detail-30 (fix-r3-club-a round 3, re-applied on the wired path): the path travels as an in-app
/// `chein://mp/…` link (`ClubShareURL`) with the MP invitation as its message, so the receiver can open it.
struct ClubHeaderShareButton: View {
    let clubID: Int
    var clubName: String? = nil
    @Environment(\.locale) private var locale

    private var message: String? {
        guard let clubName, !clubName.isEmpty else { return nil }
        return String(format: OpsR3Text.string("r3club.invite.message", locale: locale), clubName)
    }

    var body: some View {
        if let link = ClubShareLink.club(id: clubID) {
            Group {
                if let url = ClubShareURL.url(link) {
                    if let message { ShareLink(item: url, message: Text(verbatim: message)) { glyph } }
                    else { ShareLink(item: url) { glyph } }
                } else {
                    ShareLink(item: link.path) { glyph }
                }
            }
            .accessibilityLabel(ClubR4Text.text("r4club.header.share"))
            .accessibilityIdentifier("club.detail.share")
        }
    }

    private var glyph: some View {
        Image(systemName: "square.and.arrow.up")
            .accessibilityHidden(true)
            .frame(minWidth: CYSpacing.minTouchTarget, minHeight: CYSpacing.minTouchTarget)
            .contentShape(Rectangle())
    }
}

/// Handbook dates (`full-member-club.md` §2): 「11月22日 周六」, never `2026-11-22`. The source sends a calendar day
/// (`yyyy-MM-dd`), so it is read and shown in UTC to keep the same day; anything else is returned unchanged.
enum ClubR4Date {
    static func day(_ raw: String, locale: Locale) -> String {
        let parts = raw.split(separator: "-").compactMap { Int($0) }
        guard raw.count == 10, parts.count == 3, let utc = TimeZone(identifier: "UTC") else { return raw }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utc
        guard let date = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])) else { return raw }
        var style = Date.FormatStyle.dateTime.month(.abbreviated).day().weekday(.abbreviated).locale(locale)
        style.timeZone = utc
        return date.formatted(style)
    }
}
