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
        let resource = CYKitCopy(locale: locale).resourceLocale
        return CYStateContent(
            kind: .offline, glyph: "wifi.slash",
            title: appLocalized("cy.kit.offline.title", locale: resource),
            body: appLocalized("cy.kit.offline.body", locale: resource),
            primaryTitle: appLocalized("cy.kit.offline.retry", locale: resource), linkTitle: nil
        )
    }

    /// Server: "Something broke on our side". Never "unavailable".
    static func server(locale: Locale) -> CYStateContent {
        let resource = CYKitCopy(locale: locale).resourceLocale
        return CYStateContent(
            kind: .server, glyph: "exclamationmark.circle",
            title: appLocalized("cy.kit.server.title", locale: resource),
            body: appLocalized("cy.kit.server.body", locale: resource),
            primaryTitle: appLocalized("cy.kit.offline.retry", locale: resource), linkTitle: nil
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

    private var identifierKind: String {
        switch content.kind {
        case .empty: "empty"
        case .offline: "offline"
        case .server: "server"
        }
    }

    var body: some View {
        // Native iOS restyle r1: the system `ContentUnavailableView` with a retry `Button`.
        ContentUnavailableView {
            Label {
                Text(verbatim: content.title)
            } icon: {
                Image(systemName: content.glyph)
                    .foregroundStyle(palette.textTertiary)
            }
        } description: {
            Text(verbatim: content.body)
        } actions: {
            if let title = content.primaryTitle, let onPrimary {
                CYStateActionButton(style: primaryStyle, action: onPrimary) { Text(verbatim: title) }
                    .accessibilityIdentifier("cy.state.\(identifierKind).action")
            }
            if let title = content.linkTitle, let onLink {
                CYStateActionButton(style: .tertiary, action: onLink) { Text(verbatim: title) }
                    .accessibilityIdentifier("cy.state.\(identifierKind).link")
            }
        }
        .padding(.vertical, compact ? 0 : CYSpacing.lg)
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
