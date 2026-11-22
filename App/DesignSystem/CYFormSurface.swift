import SwiftUI

/// Player-dark grouped surface for Form/List screens (UI-F09).
/// Native grouped rows already resolve to the dark elevated tone in the player shell; this only pins the
/// page behind them to `CYColor.bgPage` so settings-style screens share the mini-program page ground.
public extension View {
    func cyGroupedSurface() -> some View {
        scrollContentBackground(.hidden)
            .background(CYColor.bgPage.ignoresSafeArea())
    }

    /// Long-form document ground (agreement / privacy text): page background, no list chrome.
    func cyDocumentSurface() -> some View {
        background(CYColor.bgPage.ignoresSafeArea())
    }
}

/// Mini-program `.sz-attribution`-style footer title helper kept token-only for reuse by settings screens.
public struct CYDocumentHeading: View {
    private let text: String
    public init(verbatim text: String) { self.text = text }
    public var body: some View {
        Text(verbatim: text)
            .cyText(.cardTitle)
            .foregroundStyle(CYColor.textPrimary)
            .accessibilityAddTraits(.isHeader)
    }
}
