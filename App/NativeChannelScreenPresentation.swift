import SwiftUI

/// S04 presentation only. All state, identity, journal and navigation ownership stays with callers.
/// A screen that shows its title in `CYHeroHeader` calls `cyHeroScreen()` itself. This modifier does not
/// clear a title, so callers that still use the bar keep it.
private struct NativeChannelScreenPresentation: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .cyText(.body)
            .environment(\.defaultMinListRowHeight, CYSpacing.minTouchTarget)
            .cyGroupedSurface()
            .navigationBarTitleDisplayMode(.inline)
            .transaction { transaction in
                // Kit press springs stay inside the components. Anything else degrades to a cross-fade.
                if reduceMotion, transaction.animation != nil {
                    transaction.animation = CYMotion.reduced
                }
            }
    }
}

/// The style itself supplies the primary colours and button font for the root's theme.
/// One primary pill per screen; Reduce Motion is handled by `CYPillButtonStyle`.
private struct NativeChannelPrimaryAction: ViewModifier {
    func body(content: Content) -> some View {
        content
            .buttonStyle(CYPillButtonStyle(style: .primary, fullWidth: false))
            .fixedSize(horizontal: false, vertical: true)
            .frame(minHeight: CYSpacing.minTouchTarget)
    }
}

private struct NativeChannelInlineNotice: ViewModifier {
    let systemImage: String
    @Environment(\.cyPalette) private var palette

    func body(content: Content) -> some View {
        HStack(alignment: .top, spacing: CYSpacing.sm) {
            Image(systemName: systemImage)
                .foregroundStyle(palette.textSecondary)
                .accessibilityHidden(true)
            content
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .cyText(.body)
        .foregroundStyle(palette.textPrimary)
        .padding(CYSpacing.pageHorizontal)
        .background(palette.bgElevated, in: RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

extension View {
    func nativeChannelScreen() -> some View { modifier(NativeChannelScreenPresentation()) }
    func nativeChannelPrimaryAction() -> some View { modifier(NativeChannelPrimaryAction()) }
    func nativeChannelNotice(systemImage: String) -> some View { modifier(NativeChannelInlineNotice(systemImage: systemImage)) }
}

/// Section title for keys that live in a string table. `CYSectionHeader` reads the default catalog only.
struct NativeChannelSectionTitle: View {
    let key: String
    var tableName: String = "NativeChannelProgress"

    var body: some View {
        Text(LocalizedStringKey(key), tableName: tableName)
            .cyText(.sectionTitle)
            .foregroundStyle(CYColor.textPrimary)
            .textCase(nil)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Wide generated cover for a hero illustration. Height follows width, not a fixed text line.
struct NativeChannelCoverBanner: View {
    let seed: String
    var symbol: String? = nil

    var body: some View {
        Color.clear
            .aspectRatio(16.0 / 7.0, contentMode: .fit)
            .overlay {
                CYCoverArt(seed: seed, symbol: symbol, showsDebugLabel: false)
            }
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous))
            .accessibilityHidden(true)
    }
}

enum NativeChannelProgressCopy {
    static func text(_ key: String) -> String {
        String(localized: LocalizedStringResource(
            String.LocalizationValue(stringLiteral: key),
            table: "NativeChannelProgress"
        ))
    }
}
