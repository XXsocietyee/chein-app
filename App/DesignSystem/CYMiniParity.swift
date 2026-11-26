import SwiftUI

// UI-F08: small shared pieces that mirror recurring mini-program card anatomy
// (`pages/coop/list` `.inv-badge` / `.inv-peer` / `.deposit-due`, `pages/coop/invite-detail` `.hd`).
// Presentation only. Colours come from CYColor tokens; type from CYTypography.

/// Tone of a status pill, matching mini-program `.inv-badge--pending / --accepted / --rejected / --muted`.
public enum CYMiniBadgeTone: Sendable {
    case pending, accepted, rejected, muted

    var foreground: Color {
        switch self {
        case .pending: return CYColor.warningText
        case .accepted: return CYColor.successText
        case .rejected: return CYColor.dangerText
        case .muted: return CYColor.textTertiary
        }
    }
    var background: Color {
        switch self {
        case .pending: return CYColor.warningSoft
        case .accepted: return CYColor.successSoft
        case .rejected: return CYColor.dangerSoft
        case .muted: return CYColor.bgSurfaceSubtle
        }
    }
}

/// Capsule status pill with an optional SF Symbol (mini `.inv-badge`: 40rpx tall, pill radius, label type).
public struct CYMiniBadge: View {
    private let title: Text
    private let systemImage: String?
    private let tone: CYMiniBadgeTone

    public init(_ title: Text, tone: CYMiniBadgeTone, systemImage: String? = nil) {
        self.title = title
        self.tone = tone
        self.systemImage = systemImage
    }

    public var body: some View {
        HStack(spacing: CYSpacing.xs) {
            if let systemImage { Image(systemName: systemImage).imageScale(.small).accessibilityHidden(true) }
            title.cyText(.label)
        }
        .foregroundStyle(tone.foreground)
        .padding(.horizontal, CYSpacing.md)
        .padding(.vertical, CYSpacing.xs)
        .background(Capsule().fill(tone.background))
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// Red-on-soft-red strip for money still owed (mini `.deposit-due`).
public struct CYMiniDueStrip<Content: View>: View {
    private let content: Content
    public init(@ViewBuilder content: () -> Content) { self.content = content() }
    public var body: some View {
        content
            .cyText(.label, weight: .semibold)
            .foregroundStyle(CYColor.dangerText)
            .padding(.horizontal, CYSpacing.md)
            .padding(.vertical, CYSpacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous).fill(CYColor.dangerSoft))
    }
}

public extension View {
    /// Player-dark list screen in the mini-program rhythm: page background, elevated grouped cards,
    /// 12pt between cards. Uses only system List behaviour (no custom chrome).
    func cyMiniListScreen() -> some View {
        // Native r2: the system grouped list background and section spacing.
        self
    }

    /// Elevated card background for a List row/section (mini `.inv` / `.card`: bg-card, radius 16).
    func cyMiniCardRow() -> some View {
        // Native r2: the system grouped cell background.
        listRowBackground(Color(uiColor: .secondarySystemGroupedBackground))
    }
}
