import SwiftUI

// CYStateView (e4): the one layout for empty, offline and server-error states (ux-strategy 4.2).
// Glyph 44 · title 20 semibold · body 15 secondary · one pill · optional text link. Always inside the content area.
// Tone rules live in `CYStateTone` so they can be checked, not just remembered. Presentation only: the view never
// invents data (no sample rows, no placeholder counts) and shows unknown values as an em dash, never 0.

// MARK: - Tone rules

enum CYStateTone {
    /// Phrases the voice guide forbids in a state's title, body or buttons.
    static let banned: [String] = [
        "unavailable", "暂不可用", "sorry", "please", "successfully", "oops", "抱歉", "请稍后", "请求失败", "网络连接失败", "暂无数据", "no data",
    ]

    /// Returns the rule each offending string breaks. Empty = the copy is on tone.
    static func violations(in strings: [String]) -> [String] {
        var found: [String] = []
        for text in strings {
            let lower = text.lowercased()
            for phrase in banned where lower.contains(phrase) { found.append("banned phrase \"\(phrase)\" in \"\(text)\"") }
            if text.contains("!") || text.contains("！") { found.append("exclamation mark in \"\(text)\"") }
        }
        return found
    }
}

// MARK: - Content

/// The copy + glyph for one state. A value type so fixtures and callers can inspect it without a view.
struct CYStateContent: Equatable {
    enum Kind: Equatable { case empty, offline, server }

    var kind: Kind
    var glyph: String
    var title: String
    var body: String
    var primaryTitle: String?
    var linkTitle: String?

    var allStrings: [String] { [title, body, primaryTitle, linkTitle].compactMap { $0 } }

    /// Offline: "You're offline". Retry is the one pill; cached content stays reachable, so the body says so.
    static func offline(locale: Locale) -> CYStateContent {
        let c = CYKitCopy(locale: locale)
        return CYStateContent(
            kind: .offline, glyph: "wifi.slash",
            title: c("You're offline", "你离线了"),
            body: c("Your map and lit tiles are here; new content waits for the network.", "地图和已点亮的格子还在；新内容等网络回来"),
            primaryTitle: c("Retry", "重试"), linkTitle: nil
        )
    }

    /// Server: "Something broke on our side". Never "unavailable".
    static func server(locale: Locale) -> CYStateContent {
        let c = CYKitCopy(locale: locale)
        return CYStateContent(
            kind: .server, glyph: "exclamationmark.circle",
            title: c("Something broke on our side", "这边出了点问题"),
            body: c("We've logged it. Try again.", "已经记下来了，再试一次"),
            primaryTitle: c("Retry", "重试"), linkTitle: nil
        )
    }

    /// Empty: the caller owns the words (they differ per screen) and must give the next action.
    static func empty(glyph: String = "tray", title: String, body: String, actionTitle: String, linkTitle: String? = nil) -> CYStateContent {
        CYStateContent(kind: .empty, glyph: glyph, title: title, body: body, primaryTitle: actionTitle, linkTitle: linkTitle)
    }
}

// MARK: - View

struct CYStateView: View {
    let content: CYStateContent
    var primaryStyle: CYPillStyle = .primary
    var onPrimary: (() -> Void)?
    var onLink: (() -> Void)?
    /// Inline sections (a failed rail on an otherwise live screen) use the tighter spacing.
    var compact = false
    @Environment(\.cyPalette) private var palette
    @ScaledMetric(relativeTo: .title2) private var glyphSize: CGFloat = 44

    private var identifierKind: String {
        switch content.kind {
        case .empty: "empty"
        case .offline: "offline"
        case .server: "server"
        }
    }

    var body: some View {
        VStack(spacing: compact ? CYSpacing.sm : CYSpacing.md) {
            Image(systemName: content.glyph)
                .font(.system(size: glyphSize, weight: .regular))
                .foregroundStyle(palette.textTertiary)
                .accessibilityHidden(true)
            Text(verbatim: content.title)
                .font(.system(.title3, design: .default).weight(.semibold))
                .foregroundStyle(palette.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(verbatim: content.body)
                .font(CYTypography.body)
                .foregroundStyle(palette.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if let title = content.primaryTitle, let onPrimary {
                CYPillButton(verbatim: title, style: primaryStyle, fullWidth: false, action: onPrimary)
                    .padding(.top, CYSpacing.sm)
                    .accessibilityIdentifier("cy.state.\(identifierKind).action")
            }
            if let title = content.linkTitle, let onLink {
                CYPillButton(verbatim: title, style: .tertiary, fullWidth: false, action: onLink)
                    .accessibilityIdentifier("cy.state.\(identifierKind).link")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, compact ? CYSpacing.xl : CYSpacing.xxxl)
        .padding(.horizontal, CYSpacing.xxl)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("cy.state.\(identifierKind)")
    }
}

extension CYStateView {
    /// Offline in the caller's locale.
    static func offline(locale: Locale, compact: Bool = false, onRetry: @escaping () -> Void) -> CYStateView {
        CYStateView(content: .offline(locale: locale), onPrimary: onRetry, compact: compact)
    }

    static func server(locale: Locale, compact: Bool = false, onRetry: @escaping () -> Void) -> CYStateView {
        CYStateView(content: .server(locale: locale), onPrimary: onRetry, compact: compact)
    }
}

#Preview("State · offline") {
    CYStateView.offline(locale: Locale(identifier: "en")) {}
        .frame(maxHeight: .infinity)
        .cyDomainPageBackground()
        .themeDomain(.player)
}
#Preview("State · server zh") {
    CYStateView.server(locale: Locale(identifier: "zh-Hans")) {}
        .frame(maxHeight: .infinity)
        .cyDomainPageBackground()
        .themeDomain(.player)
}
